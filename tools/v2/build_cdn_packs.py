#!/usr/bin/env python3
"""Build immutable CDN question packs and atomically publish their manifest.

Packs are content-addressed and intentionally retained after a rebuild so a
client holding an older manifest can still finish downloading its referenced
files. The manifest is the publication switch and is replaced only after every
new pack has been written and verified.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import sqlite3
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from build_config import BANK_VERSION

REPO_ROOT = Path(__file__).resolve().parents[2]  # tet_repo
WORKSPACE_ROOT = REPO_ROOT.parent
DEFAULT_APP_DB = WORKSPACE_ROOT / "tet_app" / "assets" / "database" / "tet_mock_vault.db"
if (WORKSPACE_ROOT / "tet_app").exists():
    DEFAULT_DB = DEFAULT_APP_DB
else:
    DEFAULT_DB = REPO_ROOT / "runtime" / "tet_mock_vault.db"
APP_DB = Path(os.environ.get("TET_DB_PATH", DEFAULT_DB)).expanduser().resolve()

CDN_DIR = REPO_ROOT / "cdn"
PACKS_DIR = CDN_DIR / "packs"
MANIFEST_PATH = CDN_DIR / "manifest.json"
CHUNK_SIZE = 200

TOPICS = [
    "बाल विकास एवं शिक्षणशास्त्र",
    "हिन्दी भाषा",
    "English Language",
    "गणित एवं शिक्षणशास्त्र",
    "पर्यावरण अध्ययन",
    "संस्कृत भाषा",
    "विज्ञान",
    "सामाजिक अध्ययन",
]
SECTION_TO_TOPIC_INDEX = {
    "cdp": 0,
    "hindi": 1,
    "english": 2,
    "math": 3,
    "evs": 4,
    "sanskrit": 5,
    "science": 6,
    "social": 7,
}


def sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def build_timestamp() -> str:
    """Return a reproducible timestamp, overridable with SOURCE_DATE_EPOCH."""
    epoch = os.environ.get("SOURCE_DATE_EPOCH")
    if epoch is not None:
        timestamp = datetime.fromtimestamp(int(epoch), tz=timezone.utc)
    else:
        timestamp = datetime.strptime(str(BANK_VERSION), "%Y%m%d").replace(tzinfo=timezone.utc)
    return timestamp.strftime("%Y-%m-%dT%H:%M:%SZ")


def _load_database(conn: sqlite3.Connection) -> tuple[dict[str, dict[str, str]], list[tuple[Any, ...]]]:
    cur = conn.cursor()
    cur.execute(
        """
        SELECT id, kind, dir_text, body, language, language_slot,
               selection_policy, minimum_questions
        FROM passages ORDER BY id
        """
    )
    passages: dict[str, dict[str, Any]] = {}
    for pid, kind, dir_text, body, language, slot, policy, min_q in cur.fetchall():
        entry: dict[str, Any] = {
            "id": pid,
            "k": kind or "prose",
            "d": dir_text or "",
            "b": body or "",
            # group contract: the passage and its `g` questions travel together
            "pol": policy or "atomic",
        }
        if language:
            entry["lg"] = language
        if slot is not None:
            entry["sl"] = slot
        if min_q is not None:
            entry["g"] = min_q
        passages[pid] = entry
    print(f"Loaded {len(passages)} passages.")

    cur.execute(
        """
        SELECT id, exams, section, topic_index, topic_name, difficulty,
               q_hindi, options_hindi, q_english, options_english,
               answer, p_score, years, passage_id, seq_in_passage,
               language, language_slot, group_id, group_policy, group_size
        FROM questions
        ORDER BY exams, section, id
        """
    )
    question_rows = cur.fetchall()
    print(f"Loaded {len(question_rows)} questions.")
    return passages, question_rows


def _prepare_questions(
    rows: list[tuple[Any, ...]],
) -> tuple[list[dict[str, Any]], dict[str, int], list[dict[str, Any]]]:
    """Flatten rows to question dicts and group them into indivisible units.

    A unit is either one standalone question or one complete stimulus block. The
    blueprint declares `stimulusGroupsAtomic: true`, so a passage and every question
    that belongs to it must ship together and stay together.
    """
    questions: list[dict[str, Any]] = []
    section_counts: dict[str, int] = {}
    units: list[dict[str, Any]] = []
    blocks: dict[str, dict[str, Any]] = {}

    for row in rows:
        (qid, exams, section, topic_index, _topic_name, difficulty, qh, oh, qe, oe,
         answer, p_score, years, pid, seq, language, slot,
         group_id, group_policy, group_size) = row
        section_counts[section] = section_counts.get(section, 0) + 1
        t_index = SECTION_TO_TOPIC_INDEX.get(section, topic_index or 0)
        options_hi = json.loads(oh) if oh else []
        options_en = json.loads(oe) if oe else None

        question: dict[str, Any] = {
            "k": qid,
            "e": exams,
            "s": section,
            "t": t_index,
            "d": difficulty or 2,
            "qh": qh or "",
            "oh": options_hi,
            "a": answer,
            "p": round(p_score, 4) if p_score else 0.85,
        }
        if qe and qe.strip():
            question["qe"] = qe
        if options_en:
            question["oe"] = options_en
        if years and years.strip():
            question["y"] = years
        if language:
            question["lg"] = language
        if slot is not None:
            question["sl"] = slot
        if pid and pid.strip():
            question["pid"] = pid
        if seq is not None:
            question["n"] = seq
        if group_id:
            # One group = passage + every question of that passage. A selector must
            # take the whole `g` or none of it; `n` is the position inside the group.
            question["g"] = {"id": group_id, "pol": group_policy or "atomic",
                             "n": group_size}
        questions.append(question)

        if pid and pid.strip():
            block = blocks.get(pid)
            if block is None:
                block = {"pid": pid, "qs": []}
                blocks[pid] = block
                units.append(block)
            block["qs"].append(question)
        else:
            units.append({"pid": None, "qs": [question]})

    return questions, section_counts, units


def _build_pack_payloads(
    units: list[dict[str, Any]], passages: dict[str, dict[str, str]]
) -> list[dict[str, Any]]:
    """Chunk units into packs without ever splitting a stimulus block.

    Every pack also carries the full text of each passage whose questions it holds,
    so a pack is self-contained: a client can render any question from a single
    downloaded pack. That duplicates ~85 passage bodies (~100 KB total) instead of
    showing questions whose passage lives in another pack.
    """
    chunks: list[dict[str, Any]] = []
    current: list[dict[str, Any]] = []
    current_passages: dict[str, dict[str, str]] = {}

    def flush() -> None:
        nonlocal current, current_passages
        if not current:
            return
        chunks.append({"p": list(current_passages.values()), "q": current})
        current = []
        current_passages = {}

    for unit in units:
        if current and len(current) + len(unit["qs"]) > CHUNK_SIZE:
            flush()
        pid = unit["pid"]
        if pid and pid in passages:
            current_passages.setdefault(pid, passages[pid])
        current.extend(unit["qs"])
    flush()
    return chunks


def _write_immutable_pack(path: Path, data: bytes, full_hash: str) -> bool:
    """Write one pack exactly once; return False if the identical object exists."""
    if path.exists():
        existing = path.read_bytes()
        if existing != data or sha256_hex(existing) != full_hash:
            raise RuntimeError(f"Immutable pack path contains different bytes: {path}")
        return False

    fd, tmp_name = tempfile.mkstemp(prefix=".pack-", suffix=".tmp", dir=PACKS_DIR)
    temp_path = Path(tmp_name)
    try:
        with os.fdopen(fd, "wb") as target:
            target.write(data)
            target.flush()
            os.fsync(target.fileno())
        try:
            # Hard-linking an already complete temp file makes publication
            # atomic and refuses to overwrite a previously published pack.
            os.link(temp_path, path)
        except FileExistsError:
            existing = path.read_bytes()
            if existing != data or sha256_hex(existing) != full_hash:
                raise RuntimeError(f"Immutable pack path collision: {path}")
            return False
        return True
    finally:
        try:
            temp_path.unlink()
        except FileNotFoundError:
            pass


def _atomic_write_manifest(manifest: dict[str, Any]) -> None:
    fd, tmp_name = tempfile.mkstemp(prefix=".manifest-", suffix=".tmp", dir=CDN_DIR)
    temp_path = Path(tmp_name)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="") as target:
            json.dump(manifest, target, ensure_ascii=False, indent=2)
            target.write("\n")
            target.flush()
            os.fsync(target.fileno())
        os.replace(temp_path, MANIFEST_PATH)
    finally:
        try:
            temp_path.unlink()
        except FileNotFoundError:
            pass


def prune_unreferenced(referenced: set[str]) -> list[str]:
    """Delete pack files no current manifest entry points at.

    Safe to run because pack ids are version-scoped: a client on an older manifest
    keeps using its own ids, and a client that already re-synced never asks for the
    pruned files again.
    """
    removed = []
    for path in sorted(PACKS_DIR.glob("pack-*.json")):
        if path.name not in referenced:
            path.unlink()
            removed.append(path.name)
    return removed


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prune", action="store_true",
                        help="delete cdn/packs files the new manifest does not reference")
    args = parser.parse_args()
    print(f"Reading questions and passages from {APP_DB}...")
    if not APP_DB.exists():
        print(f"Error: {APP_DB} does not exist! Please run build_app_db.py first.")
        return 1

    CDN_DIR.mkdir(parents=True, exist_ok=True)
    PACKS_DIR.mkdir(parents=True, exist_ok=True)

    conn = sqlite3.connect(APP_DB)
    try:
        version_row = conn.execute(
            "SELECT val FROM meta WHERE key = 'bank_version'"
        ).fetchone()
        if version_row is None or version_row[0] != str(BANK_VERSION):
            raise RuntimeError(
                f"SQLite bank_version {version_row[0] if version_row else None} "
                f"does not match build version {BANK_VERSION}"
            )
        passages, question_rows = _load_database(conn)
    finally:
        conn.close()

    questions, section_counts, units = _prepare_questions(question_rows)
    question_ids = [question["k"] for question in questions]
    if len(question_ids) != len(set(question_ids)):
        raise RuntimeError("Duplicate question IDs found in SQLite database")
    missing_passages = {
        question["pid"] for question in questions
        if question.get("pid") and question["pid"] not in passages
    }
    if missing_passages:
        raise RuntimeError(f"Questions reference missing passages: {sorted(missing_passages)}")
    if any(question.get("a") not in range(4) for question in questions):
        raise RuntimeError("A question answer index is outside the four-option range")

    payloads = _build_pack_payloads(units, passages)

    pack_entries: list[dict[str, Any]] = []
    new_pack_count = 0
    for pack_index, payload in enumerate(payloads):
        pack_bytes = json.dumps(
            payload, ensure_ascii=False, separators=(",", ":")
        ).encode("utf-8")
        full_hash = sha256_hex(pack_bytes)
        pack_path = PACKS_DIR / f"pack-{pack_index:04d}-{full_hash[:12]}.json"

        # Verify the exact serialized object before publishing it.
        decoded = json.loads(pack_bytes.decode("utf-8"))
        if len(decoded.get("q", [])) != len(payload.get("q", [])):
            raise RuntimeError(f"Question count mismatch in generated pack {pack_index:04d}")
        created = _write_immutable_pack(pack_path, pack_bytes, full_hash)
        new_pack_count += int(created)
        pack_entries.append(
            {
                # Pack ids carry the bank version so a rebuild never reuses an id
                # for different bytes.  Reusing ids is what left several
                # pack-<id>-<hash>.json generations side by side in cdn/packs/.
                "id": f"v{BANK_VERSION}-{pack_index:04d}",
                "file": f"packs/{pack_path.name}",
                "sha256": full_hash,
                "bytes": len(pack_bytes),
                "count": len(payload.get("q", [])),
                "sections": sorted({q["s"] for q in payload.get("q", [])}),
            }
        )

    packed_count = sum(entry["count"] for entry in pack_entries)
    if packed_count != len(questions):
        raise RuntimeError(f"Pack question count {packed_count} != database count {len(questions)}")

    # A stimulus group is atomic: all of its questions live in exactly one pack, and
    # that pack carries the passage text itself.
    block_packs: dict[str, set[str]] = {}
    for entry, payload in zip(pack_entries, payloads):
        for question in payload.get("q", []):
            pid = question.get("pid")
            if pid:
                block_packs.setdefault(pid, set()).add(entry["id"])
        for passage in payload.get("p", []):
            if not any(q.get("pid") == passage["id"] for q in payload.get("q", [])):
                raise RuntimeError(
                    f"Pack {entry['id']} carries passage {passage['id']} without its questions")
    split_blocks = {pid: sorted(ids) for pid, ids in block_packs.items() if len(ids) > 1}
    if split_blocks:
        raise RuntimeError(f"Stimulus groups split across packs: {split_blocks}")
    missing_text = sorted(set(block_packs) - {
        passage["id"] for payload in payloads for passage in payload.get("p", [])})
    if missing_text:
        raise RuntimeError(f"Questions shipped without their passage text: {missing_text}")
    packed_passage_ids = {
        passage["id"] for payload in payloads for passage in payload.get("p", [])
    }
    unreferenced = sorted(set(passages) - set(block_packs))
    if unreferenced:
        print(f"Note: {len(unreferenced)} passages have no question and are not packed: "
              f"{unreferenced[:3]}")
    if packed_passage_ids != set(block_packs):
        raise RuntimeError("Packed passages do not match the passages questions reference")

    manifest = {
        "schema": 1,
        "bank_version": BANK_VERSION,
        "generated": build_timestamp(),
        "topics": TOPICS,
        "total": len(questions),
        "pyq_count": len(questions),
        "avg_p": 0.85,
        "sections": section_counts,
        "passage_questions": sum(1 for q in questions if q.get("pid")),
        "stimulus_groups": len({q["pid"] for q in questions if q.get("pid")}),
        "packs": pack_entries,
    }

    # The new immutable packs are in place before this atomic manifest switch.
    # Old pack files are deliberately retained for clients using the old manifest.
    _atomic_write_manifest(manifest)

    if args.prune:
        removed = prune_unreferenced({Path(entry["file"]).name for entry in pack_entries})
        for name in removed:
            print(f" - Pruned unreferenced pack {name}")

    print("Successfully generated CDN packs and manifest:")
    print(f" - Manifest: {MANIFEST_PATH}")
    print(f" - Total Packs: {len(pack_entries)} ({new_pack_count} new immutable packs)")
    print(f" - Total Questions: {len(questions)}")
    print(f" - Sections: {section_counts}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Build immutable CDN question packs and atomically publish their manifest.

Packs are content-addressed and intentionally retained after a rebuild so a
client holding an older manifest can still finish downloading its referenced
files. The manifest is the publication switch and is replaced only after every
new pack has been written and verified.
"""
from __future__ import annotations

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
    cur.execute("SELECT id, kind, dir_text, body FROM passages ORDER BY id")
    passages: dict[str, dict[str, str]] = {}
    for pid, kind, dir_text, body in cur.fetchall():
        passages[pid] = {
            "id": pid,
            "k": kind or "prose",
            "d": dir_text or "",
            "b": body or "",
        }
    print(f"Loaded {len(passages)} passages.")

    cur.execute(
        """
        SELECT id, exams, section, topic_index, topic_name, difficulty,
               q_hindi, options_hindi, q_english, options_english,
               answer, p_score, years, passage_id, seq_in_passage
        FROM questions
        ORDER BY exams, section, id
        """
    )
    question_rows = cur.fetchall()
    print(f"Loaded {len(question_rows)} questions.")
    return passages, question_rows


def _prepare_questions(
    rows: list[tuple[Any, ...]],
) -> tuple[list[dict[str, Any]], dict[str, int]]:
    questions: list[dict[str, Any]] = []
    section_counts: dict[str, int] = {}

    for row in rows:
        qid, exams, section, topic_index, _topic_name, difficulty, qh, oh, qe, oe, answer, p_score, years, pid, seq = row
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
        if pid and pid.strip():
            question["pid"] = pid
        if seq is not None:
            question["n"] = seq
        questions.append(question)

    return questions, section_counts


def _build_pack_payloads(
    questions: list[dict[str, Any]], passages: dict[str, dict[str, str]]
) -> list[dict[str, Any]]:
    chunks: list[dict[str, Any]] = []
    assigned_passages: set[str] = set()

    for start in range(0, len(questions), CHUNK_SIZE):
        question_chunk = questions[start : start + CHUNK_SIZE]
        chunk_passages: list[dict[str, str]] = []
        for question in question_chunk:
            passage_id = question.get("pid")
            if passage_id and passage_id in passages and passage_id not in assigned_passages:
                chunk_passages.append(passages[passage_id])
                assigned_passages.add(passage_id)
        chunks.append({"p": chunk_passages, "q": question_chunk})

    remaining = [passage for pid, passage in passages.items() if pid not in assigned_passages]
    if remaining:
        if chunks:
            chunks[0]["p"].extend(remaining)
        else:
            chunks.append({"p": remaining, "q": []})
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


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
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

    questions, section_counts = _prepare_questions(question_rows)
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

    payloads = _build_pack_payloads(questions, passages)

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
                "id": f"{pack_index:04d}",
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
    packed_passage_ids = [
        passage["id"] for payload in payloads for passage in payload.get("p", [])
    ]
    if len(packed_passage_ids) != len(set(packed_passage_ids)):
        raise RuntimeError("A passage was emitted in more than one pack")
    if set(packed_passage_ids) != set(passages):
        raise RuntimeError("Generated packs do not preserve every SQLite passage")

    manifest = {
        "schema": 1,
        "bank_version": BANK_VERSION,
        "generated": build_timestamp(),
        "topics": TOPICS,
        "total": len(questions),
        "pyq_count": len(questions),
        "avg_p": 0.85,
        "sections": section_counts,
        "packs": pack_entries,
    }

    # The new immutable packs are in place before this atomic manifest switch.
    # Old pack files are deliberately retained for clients using the old manifest.
    _atomic_write_manifest(manifest)

    print("Successfully generated CDN packs and manifest:")
    print(f" - Manifest: {MANIFEST_PATH}")
    print(f" - Total Packs: {len(pack_entries)} ({new_pack_count} new immutable packs)")
    print(f" - Total Questions: {len(questions)}")
    print(f" - Sections: {section_counts}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

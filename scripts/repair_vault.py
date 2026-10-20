#!/usr/bin/env python3
"""Repair the bundled SQLite vault and the Git-backed CDN source packs.

The repair is deliberately idempotent.  It fixes the known corrupted
UTET Paper-I passage, restores its comprehension questions, detaches
standalone grammar questions that were accidentally shown with reading
passages, and re-aligns paper metadata.

Run from the repository root:

    python scripts/repair_vault.py

Afterwards run:

    python scripts/validate_vault.py
"""

from __future__ import annotations

import hashlib
import json
import sqlite3
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DB_PATH = ROOT / "assets" / "database" / "tet_mock_vault.db"
CDN_DIR = ROOT / "cdn"
PACK_DIR = CDN_DIR / "packs"

CORRUPT_PASSAGE_ID = "utet-p1-set-c__stim_061"
CLEAN_DIRECTION = "निम्नलिखित गद्यांश को पढ़कर प्रश्नों के उत्तर दीजिए।"

# The English questions that actually belong to "The last great war" passage.
COMPREHENSION_MAP = {
    "c831e600eb0b79b8": 1,  # What was the impact of the last great war...
    "c27c380ae72953b4": 2,  # What did Tagore articulate...
    "8fa85f18511f9f2e": 3,  # What was the stance of Indian Intelligentsia...
    "2b19231183dc5f29": 4,  # Find words meaning disgust/disappointment
    "7998ee518e47fa78": 5,  # Which statement is true?
}

# Correct option indices (A=0).  The source extractor kept the official
# answer letter while re-ordering options, so these five keys had drifted.
COMPREHENSION_ANSWERS = {
    "c831e600eb0b79b8": 1,
    "c27c380ae72953b4": 1,
    "8fa85f18511f9f2e": 3,
    "2b19231183dc5f29": 2,
    "7998ee518e47fa78": 1,
}

GRAMMAR_ANSWER_FIXES = {
    "bf282c92c0146a34": 3,  # By the next month ... have completed
    "6481a19579f98188": 3,  # In the Middle Ages ... couldn't
    "c1e417281426450c": 2,  # Kate is ill ... has to
}

# Additional key corrections found while rebuilding the missing figures.
# For 42585dbbc302b422 the figure supplies ∠A = 50° and ∠B : ∠C = 2 : 3,
# so ∠B = 52° (option B), not 65°.
GENERAL_ANSWER_FIXES = {
    "42585dbbc302b422": 1,
}

QUESTION_TEXT_FIXES = {
    "8635839d93b24272": {
        "qh": "निम्नलिखित चित्र में x का मान है:",
        "qe": "In the following figure, the value of x is:",
    },
    "240502e5a4f70e25": {
        "qh": "दिए गए चित्र में ABCD और PQRS दोनों समांतर चतुर्भुज हैं। θ का मान होगा —",
        "qe": "In the given figure, both ABCD and PQRS are parallelograms. The value of θ will be —",
    },
}

OPTION_FIGURE_FIXES = {
    "ctet-p1-2018-pyq_q056": (
        ["चित्र A", "चित्र B", "चित्र C", "चित्र D"],
        ["Figure A", "Figure B", "Figure C", "Figure D"],
    ),
    "ctet-p1-2018-pyq_q058": (
        ["चित्र A", "चित्र B", "चित्र C", "चित्र D"],
        ["Figure A", "Figure B", "Figure C", "Figure D"],
    ),
}

# Independent grammar / spelling / tense items which were incorrectly
# rendered underneath a reading passage.
DETACH_QUESTION_IDS = {
    # Grammar items that were grouped under the "last great war" passage.
    "33d37d1cf677481b",
    "bf282c92c0146a34",
    "6481a19579f98188",
    "c1e417281426450c",
    "c946dc4b1f841370",
    # CTET official PYQ papers
    "ctet-p1-2020-pyq_q134",
    "ctet-p1-2021-pyq_q128",
    "ctet-p1-2021-pyq_q135",
    # Generated CTET language mocks: the last three items are grammar,
    # not comprehension questions for the poem above them.
    "ctet-p1-mock-02_q130",
    "ctet-p1-mock-02_q131",
    "ctet-p1-mock-02_q132",
    "ctet-p1-mock-07_q130",
    "ctet-p1-mock-07_q131",
    "ctet-p1-mock-07_q132",
    "ctet-p1-mock-08_q130",
    "ctet-p1-mock-08_q131",
    "ctet-p1-mock-08_q132",
    "ctet-p1-mock-09_q130",
    "ctet-p1-mock-09_q131",
    "ctet-p1-mock-09_q132",
}


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def write_json(path: Path, value: object) -> None:
    path.write_text(
        json.dumps(value, ensure_ascii=False, separators=(",", ":")) + "\n",
        encoding="utf-8",
    )


def write_pretty_json(path: Path, value: object) -> None:
    """Keep the human-reviewed manifest readable in Git diffs."""
    path.write_text(
        json.dumps(value, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def clean_corrupt_body(body: str) -> str:
    """Remove the Sanskrit sections appended by a bad source merge."""
    for marker in ("\n### C1.", "\n### C2.", "\nC1. संस्कृत", "\nC2. संस्कृत"):
        if marker in body:
            body = body.split(marker, 1)[0]
    return body.rstrip()


def repair_packs() -> dict[str, dict]:
    """Repair every JSON pack. Returns metadata keyed by the new file name."""
    pack_files = sorted(PACK_DIR.glob("pack-*.json"))
    if not pack_files:
        raise SystemExit("No CDN packs found")

    # Load all packs once, then operate on the in-memory documents so a
    # question may live in any pack.
    docs: dict[Path, dict] = {}
    for path in pack_files:
        docs[path] = json.loads(path.read_text(encoding="utf-8"))

    clean_body = None
    for path, doc in docs.items():
        for passage in doc.get("p", []):
            if passage.get("id") == CORRUPT_PASSAGE_ID:
                clean_body = clean_corrupt_body(passage.get("b", ""))
                break
        if clean_body:
            break
    if not clean_body:
        raise SystemExit(f"Corrupt passage {CORRUPT_PASSAGE_ID} was not found")

    # Do not keep the Sanskrit instructions in the clean English passage.
    clean_body = clean_body.replace("### C1. संस्कृत गद्यांश — राष्ट्रपति", "")
    clean_body = clean_body.replace("### C2. संस्कृत गद्यांश — साधु", "").strip()

    changed_pack_paths: list[tuple[Path, dict]] = []

    for path, doc in docs.items():
        changed = False

        for passage in doc.get("p", []):
            if passage.get("id") == CORRUPT_PASSAGE_ID:
                if passage.get("d") != CLEAN_DIRECTION or passage.get("b") != clean_body:
                    passage["d"] = CLEAN_DIRECTION
                    passage["b"] = clean_body
                    changed = True

        for question in doc.get("q", []):
            qid = question.get("k")

            if qid in DETACH_QUESTION_IDS:
                if "pid" in question or "n" in question:
                    question.pop("pid", None)
                    question.pop("n", None)
                    changed = True

            if qid in COMPREHENSION_MAP:
                seq = COMPREHENSION_MAP[qid]
                answer = COMPREHENSION_ANSWERS[qid]
                if question.get("pid") != CORRUPT_PASSAGE_ID or question.get("n") != seq:
                    question["pid"] = CORRUPT_PASSAGE_ID
                    question["n"] = seq
                    changed = True
                if question.get("a") != answer:
                    question["a"] = answer
                    changed = True

            if qid in GRAMMAR_ANSWER_FIXES and question.get("a") != GRAMMAR_ANSWER_FIXES[qid]:
                question["a"] = GRAMMAR_ANSWER_FIXES[qid]
                changed = True

            if qid in GENERAL_ANSWER_FIXES and question.get("a") != GENERAL_ANSWER_FIXES[qid]:
                question["a"] = GENERAL_ANSWER_FIXES[qid]
                changed = True

            if qid in QUESTION_TEXT_FIXES:
                for key, value in QUESTION_TEXT_FIXES[qid].items():
                    if question.get(key) != value:
                        question[key] = value
                        changed = True

            if qid in OPTION_FIGURE_FIXES:
                options_hi, options_en = OPTION_FIGURE_FIXES[qid]
                if question.get("oh") != options_hi:
                    question["oh"] = options_hi
                    changed = True
                if question.get("oe") != options_en:
                    question["oe"] = options_en
                    changed = True

        if changed:
            changed_pack_paths.append((path, doc))

    # Re-index every passage after detaching questions.  The sequence values
    # are displayed to candidates, so a gap (e.g. 1,2,3,4,5,7) is visible.
    by_passage: dict[str, list[dict]] = {}
    for doc in docs.values():
        for question in doc.get("q", []):
            pid = question.get("pid")
            if pid:
                by_passage.setdefault(pid, []).append(question)
    for pid, questions in by_passage.items():
        questions.sort(key=lambda q: (q.get("n") is None, q.get("n") or 0, q.get("k", "")))
        for index, question in enumerate(questions, start=1):
            if question.get("n") != index:
                question["n"] = index
                # Locate the owning pack and mark it dirty.
                for path, doc in docs.items():
                    if question in doc.get("q", []):
                        if (path, doc) not in changed_pack_paths:
                            changed_pack_paths.append((path, doc))
                        break

    if not changed_pack_paths:
        print("CDN packs already repaired; nothing to rename.")
        return {}

    # A pack file name embeds its SHA-256 prefix.  Rewrite changed packs with
    # their new content hash so the manifest and Git history stay honest.
    new_manifest_entries: dict[str, dict] = {}
    for old_path, doc in changed_pack_paths:
        payload = json.dumps(doc, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        digest = sha256_bytes(payload)
        index = old_path.name.split("-")[1]
        new_name = f"pack-{index}-{digest[:12]}.json"
        new_path = PACK_DIR / new_name
        if old_path == new_path:
            old_path.write_bytes(payload)
        else:
            new_path.write_bytes(payload)
            if old_path.exists():
                old_path.unlink()
        # The caller patches manifest entries by pack index.
        new_manifest_entries[index] = {
            "file": f"packs/{new_name}",
            "sha256": digest,
            "bytes": len(payload),
            "count": len(doc.get("q", [])),
            "sections": sorted(
                {
                    q.get("s", "")
                    for q in doc.get("q", [])
                    if q.get("s")
                }
            ),
        }
        print(f"rewrote {old_path.name} -> {new_name}")

    return new_manifest_entries


def reindex_passage(conn: sqlite3.Connection, passage_id: str) -> None:
    ids = [
        row[0]
        for row in conn.execute(
            "SELECT id FROM questions WHERE passage_id = ? ORDER BY seq_in_passage, id",
            (passage_id,),
        )
    ]
    for index, qid in enumerate(ids, start=1):
        conn.execute(
            "UPDATE questions SET seq_in_passage = ? WHERE id = ?",
            (index, qid),
        )


def repair_database() -> None:
    conn = sqlite3.connect(DB_PATH)
    try:
        conn.execute("BEGIN")

        row = conn.execute(
            "SELECT body FROM passages WHERE id = ?", (CORRUPT_PASSAGE_ID,)
        ).fetchone()
        if row is None:
            raise SystemExit(f"Corrupt passage {CORRUPT_PASSAGE_ID} is missing from SQLite")
        clean_body = clean_corrupt_body(row[0])
        conn.execute(
            "UPDATE passages SET body = ?, dir_text = ?, kind = 'prose' WHERE id = ?",
            (clean_body, CLEAN_DIRECTION, CORRUPT_PASSAGE_ID),
        )

        # Detach standalone grammar items and re-index their former passages.
        affected_passages: set[str] = set()
        for qid in DETACH_QUESTION_IDS:
            found = conn.execute(
                "SELECT passage_id FROM questions WHERE id = ?", (qid,)
            ).fetchone()
            if found and found[0]:
                affected_passages.add(found[0])
            conn.execute(
                "UPDATE questions SET passage_id = NULL, seq_in_passage = NULL WHERE id = ?",
                (qid,),
            )
        for passage_id in affected_passages:
            reindex_passage(conn, passage_id)

        # Attach the five actual comprehension questions.
        for qid, seq in COMPREHENSION_MAP.items():
            conn.execute(
                "UPDATE questions SET passage_id = ?, seq_in_passage = ?, answer = ? WHERE id = ?",
                (CORRUPT_PASSAGE_ID, seq, COMPREHENSION_ANSWERS[qid], qid),
            )
        for qid, answer in GRAMMAR_ANSWER_FIXES.items():
            conn.execute("UPDATE questions SET answer = ? WHERE id = ?", (answer, qid))

        for qid, answer in GENERAL_ANSWER_FIXES.items():
            conn.execute("UPDATE questions SET answer = ? WHERE id = ?", (answer, qid))

        for qid, texts in QUESTION_TEXT_FIXES.items():
            conn.execute(
                "UPDATE questions SET q_hindi = ?, q_english = ? WHERE id = ?",
                (texts["qh"], texts["qe"], qid),
            )
        for qid, (options_hi, options_en) in OPTION_FIGURE_FIXES.items():
            conn.execute(
                "UPDATE questions SET options_hindi = ?, options_english = ? WHERE id = ?",
                (
                    json.dumps(options_hi, ensure_ascii=False, separators=(",", ":")),
                    json.dumps(options_en, ensure_ascii=False, separators=(",", ":")),
                    qid,
                ),
            )

        # Every Paper-2 form carries both optional streams (210 appearance
        # rows), but a candidate only attempts 150 questions.  The visible
        # total must therefore be 150, not 210.
        conn.execute("UPDATE paper_forms SET total_questions = 150 WHERE total_questions <> 150")

        conn.commit()
        print("SQLite vault repaired")
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def repair_papers_json() -> None:
    path = CDN_DIR / "papers.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    changed = False
    if data.get("version") != 2026102019:
        data["version"] = 2026102019
        changed = True
    for form in data.get("forms", []):
        if form.get("total_questions") != 150:
            form["total_questions"] = 150
            changed = True
    if changed:
        write_json(path, data)
        print("papers.json paper totals/version normalised")


def update_manifest(new_pack_entries: dict[str, dict]) -> None:
    manifest_path = CDN_DIR / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))

    for pack in manifest.get("packs", []):
        old_file = pack.get("file", "")
        index = Path(old_file).name.split("-")[1] if "-" in Path(old_file).name else ""
        replacement = new_pack_entries.get(index)
        if replacement:
            pack.update(replacement)
            pack["id"] = f"{index}-{replacement['sha256'][:12]}"

    papers_path = CDN_DIR / "papers.json"
    papers_bytes = papers_path.read_bytes()
    manifest["papers_file"] = {
        "file": "papers.json",
        "sha256": sha256_bytes(papers_bytes),
        "bytes": len(papers_bytes),
        "forms_count": len(json.loads(papers_bytes)["forms"]),
        "appearances_count": len(json.loads(papers_bytes)["appearances"]),
    }

    manifest["bank_version"] = 2026102019
    manifest["bank_version_str"] = "20261020_master_vault_clean_v19"
    manifest["generated"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    write_pretty_json(manifest_path, manifest)
    print("manifest.json updated to v19")

    # Store the new version and download signature in the bundled vault so
    # the app does not immediately re-download the same data.
    signature = ";".join(
        f"{pack.get('file', '')}_{pack.get('sha256', '')}"
        for pack in manifest.get("packs", [])
    )
    conn = sqlite3.connect(DB_PATH)
    try:
        conn.execute("BEGIN")
        for key, value in (
            ("bank_version", "2026102019"),
            ("packs_signature", signature),
            ("last_synced", datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")),
        ):
            conn.execute(
                "INSERT INTO meta(key, val) VALUES(?, ?) "
                "ON CONFLICT(key) DO UPDATE SET val = excluded.val",
                (key, value),
            )
        conn.commit()
    finally:
        conn.close()


def main() -> None:
    if not DB_PATH.exists():
        raise SystemExit(f"Database not found: {DB_PATH}")
    changed_packs = repair_packs()
    repair_papers_json()
    repair_database()
    update_manifest(changed_packs)
    print("Repair complete. Run: python scripts/validate_vault.py")


if __name__ == "__main__":
    main()

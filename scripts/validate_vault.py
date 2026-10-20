#!/usr/bin/env python3
"""Validate the bundled SQLite vault and the Git-backed CDN packs.

Usage:
    python scripts/validate_vault.py
    python scripts/validate_vault.py --strict

The normal run prints warnings for data that is intentionally recoverable
(e.g. a figure that still needs an asset).  ``--strict`` turns warnings into
failures and is the mode used before a release commit.
"""

from __future__ import annotations

import argparse
import collections
import hashlib
import json
import re
import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DB_PATH = ROOT / "assets" / "database" / "tet_mock_vault.db"
CDN_DIR = ROOT / "cdn"
PACK_DIR = CDN_DIR / "packs"

DEVANAGARI = re.compile(r"[\u0900-\u097F]")
LATIN = re.compile(r"[A-Za-z]")
FIGURE_PLACEHOLDER = re.compile(r"\[FIGURE NOT AVAILABLE IN SOURCE BANK[^\]]*\]", re.I)
EMBEDDED_HEADING = re.compile(r"(?m)^\s*#{2,}\s+\S")
GENERIC_INCOMPLETE = re.compile(
    r"(?:lorem ipsum|TODO|TBD|\[\s*\]|answer key|click here)", re.I
)


class Report:
    def __init__(self) -> None:
        self.errors: list[str] = []
        self.warnings: list[str] = []

    def error(self, message: str) -> None:
        self.errors.append(message)

    def warn(self, message: str) -> None:
        self.warnings.append(message)

    def require(self, condition: bool, message: str) -> bool:
        if not condition:
            self.error(message)
        return condition


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def normalized_text(value: str) -> str:
    return re.sub(r"\s+", " ", value or "").strip().lower()


def validate_db(report: Report) -> dict:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    stats: dict = {}

    tables = {
        row[0]
        for row in conn.execute("SELECT name FROM sqlite_master WHERE type = 'table'")
    }
    required_tables = {"questions", "passages", "paper_forms", "appearances", "meta"}
    report.require(required_tables <= tables, f"Missing tables: {sorted(required_tables - tables)}")

    question_count = conn.execute("SELECT COUNT(*) FROM questions").fetchone()[0]
    passage_count = conn.execute("SELECT COUNT(*) FROM passages").fetchone()[0]
    form_count = conn.execute("SELECT COUNT(*) FROM paper_forms").fetchone()[0]
    appearance_count = conn.execute("SELECT COUNT(*) FROM appearances").fetchone()[0]
    stats.update(
        questions=question_count,
        passages=passage_count,
        forms=form_count,
        appearances=appearance_count,
    )
    report.require(question_count == 9720, f"Unexpected question count: {question_count}")
    report.require(passage_count == 181, f"Unexpected passage count: {passage_count}")
    report.require(form_count == 62, f"Unexpected paper form count: {form_count}")
    report.require(appearance_count == 9720, f"Unexpected appearance count: {appearance_count}")

    duplicate_questions = conn.execute(
        "SELECT id, COUNT(*) AS n FROM questions GROUP BY id HAVING n > 1"
    ).fetchall()
    report.require(not duplicate_questions, f"Duplicate question ids: {len(duplicate_questions)}")

    duplicate_passages = conn.execute(
        "SELECT id, COUNT(*) AS n FROM passages GROUP BY id HAVING n > 1"
    ).fetchall()
    report.require(not duplicate_passages, f"Duplicate passage ids: {len(duplicate_passages)}")

    # Question integrity
    bad_options = 0
    bad_answers = 0
    empty_stems = 0
    for row in conn.execute("SELECT * FROM questions"):
        try:
            options = json.loads(row["options_hindi"] or "[]")
        except json.JSONDecodeError:
            options = []
        if not isinstance(options, list) or len(options) != 4 or any(
            not str(option).strip() for option in options
        ):
            bad_options += 1
        answer = row["answer"]
        if not isinstance(answer, int) or answer < 0 or answer > 3:
            bad_answers += 1
        if not (row["q_hindi"] or "").strip():
            empty_stems += 1
    report.require(bad_options == 0, f"Questions with invalid 4-option sets: {bad_options}")
    report.require(bad_answers == 0, f"Questions with invalid answer index: {bad_answers}")
    report.require(empty_stems == 0, f"Questions with empty Hindi stem: {empty_stems}")

    # Passages and mappings
    passage_rows = conn.execute("SELECT * FROM passages ORDER BY id").fetchall()
    orphan_questions = conn.execute(
        "SELECT COUNT(*) FROM questions WHERE passage_id IS NOT NULL "
        "AND passage_id <> '' AND passage_id NOT IN (SELECT id FROM passages)"
    ).fetchone()[0]
    report.require(orphan_questions == 0, f"Questions referencing missing passages: {orphan_questions}")

    zero_question_passages = []
    sequence_problems = []
    mixed_passages = []
    embedded_headings = []
    figure_passages = []
    normalized_bodies: dict[str, list[str]] = collections.defaultdict(list)

    for passage in passage_rows:
        pid = passage["id"]
        body = passage["body"] or ""
        questions = conn.execute(
            "SELECT seq_in_passage FROM questions WHERE passage_id = ? ORDER BY seq_in_passage",
            (pid,),
        ).fetchall()
        if not questions:
            zero_question_passages.append(pid)
        sequences = [row[0] for row in questions]
        if sequences != list(range(1, len(sequences) + 1)):
            sequence_problems.append((pid, sequences))

        if len(DEVANAGARI.findall(body)) > 20 and len(LATIN.findall(body)) > 20:
            mixed_passages.append(pid)
        if EMBEDDED_HEADING.search(body):
            embedded_headings.append(pid)
        if FIGURE_PLACEHOLDER.search(body):
            figure_passages.append(pid)
        normalized_bodies[normalized_text(body)].append(pid)

    report.require(not zero_question_passages, f"Passages without questions: {zero_question_passages}")
    report.require(not sequence_problems, f"Non-contiguous passage sequences: {sequence_problems}")
    report.require(not mixed_passages, f"Passages mixing scripts: {mixed_passages}")
    report.require(not embedded_headings, f"Passages containing markdown headings: {embedded_headings}")
    if figure_passages:
        report.warn(f"Passages containing missing figure placeholders: {figure_passages}")

    # Re-using the same source passage in more than one form is intentional
    # (e.g. fullmock_p3 and the UTET set-c copy).  Identical text is therefore
    # not treated as corruption; mixed scripts and embedded headings are.

    # Known repaired cluster
    corrupt = conn.execute(
        "SELECT body FROM passages WHERE id = 'utet-p1-set-c__stim_061'"
    ).fetchone()
    report.require(corrupt is not None, "Repaired UTET passage is missing")
    if corrupt:
        report.require("###" not in corrupt["body"], "Repaired UTET passage still contains headings")
        report.require(
            "राष्ट्रपति" not in corrupt["body"] and "साधु" not in corrupt["body"],
            "Repaired UTET passage still contains appended Sanskrit text",
        )
        attached = conn.execute(
            "SELECT COUNT(*) FROM questions WHERE passage_id = 'utet-p1-set-c__stim_061'"
        ).fetchone()[0]
        report.require(attached == 5, f"Repaired UTET passage has {attached} questions, expected 5")

    # Paper forms / appearances
    forms = conn.execute("SELECT * FROM paper_forms ORDER BY id").fetchall()
    for form in forms:
        stream_counts = {
            row["section"]: row["n"]
            for row in conn.execute(
                "SELECT section, COUNT(*) AS n FROM appearances "
                "WHERE paper_form_id = ? GROUP BY section",
                (form["id"],),
            )
        }
        streams = [
            stream
            for stream in ("math_science", "social_studies")
            if stream_counts.get(stream, 0)
        ]
        if form["paper"] == 2 and len(streams) == 2:
            # UTET-style form carrying both optional streams.  Only one is
            # attempted, so 210 rows are stored but 150 are shown.
            expected = 210
        else:
            # Paper-1, or a CTET stream-specific Paper-2 mock.
            expected = 150
        actual = conn.execute(
            "SELECT COUNT(*) FROM appearances WHERE paper_form_id = ?", (form["id"],)
        ).fetchone()[0]
        report.require(
            actual == expected,
            f"Form {form['id']} has {actual} appearances, expected {expected}",
        )
        report.require(
            form["total_questions"] == 150,
            f"Form {form['id']} exposes total_questions={form['total_questions']}, expected 150",
        )
        missing = conn.execute(
            "SELECT COUNT(*) FROM appearances a "
            "LEFT JOIN questions q ON q.id = a.question_id "
            "WHERE a.paper_form_id = ? AND q.id IS NULL",
            (form["id"],),
        ).fetchone()[0]
        report.require(missing == 0, f"Form {form['id']} has {missing} missing questions")

        if form["paper"] == 2:
            for stream in streams:
                if stream_counts.get(stream, 0) != 60:
                    report.error(
                        f"Form {form['id']} stream {stream} has {stream_counts.get(stream, 0)} rows"
                    )
            # For a stream-specific form, loading must not remove the only
            # available stream.  For a dual-stream form, the unselected stream
            # must be filtered out and exactly 150 questions must remain.
            if len(streams) == 2:
                for chosen, other in (
                    ("math_science", "social_studies"),
                    ("social_studies", "math_science"),
                ):
                    visible = conn.execute(
                        "SELECT COUNT(*) FROM appearances WHERE paper_form_id = ? "
                        "AND (section IS NULL OR section <> ?)",
                        (form["id"], other),
                    ).fetchone()[0]
                    report.require(
                        visible == 150,
                        f"Form {form['id']} filtered stream {chosen} shows {visible} questions",
                    )
            else:
                report.require(
                    len(streams) == 1,
                    f"Form {form['id']} has no optional Paper-2 stream",
                )

    # Questions in appearances must be unique per form and cover the bank
    form_question_duplicates = conn.execute(
        "SELECT paper_form_id, question_id, COUNT(*) AS n FROM appearances "
        "GROUP BY paper_form_id, question_id HAVING n > 1"
    ).fetchall()
    report.require(
        not form_question_duplicates,
        f"Forms repeat questions: {len(form_question_duplicates)}",
    )

    # Missing figure placeholders in question/option text
    placeholder_questions = []
    for row in conn.execute("SELECT id, q_hindi, q_english, options_hindi, options_english FROM questions"):
        text = " ".join(
            str(row[key] or "")
            for key in ("q_hindi", "q_english", "options_hindi", "options_english")
        )
        if FIGURE_PLACEHOLDER.search(text):
            placeholder_questions.append(row["id"])
    if placeholder_questions:
        report.warn(
            f"Questions with unresolved figure placeholders ({len(placeholder_questions)}): "
            f"{placeholder_questions[:20]}"
        )

    # Known figure repairs must survive future regenerations.
    expected_figure_questions = {
        "42585dbbc302b422": 1,  # ∠A = 50°, ∠B : ∠C = 2 : 3  =>  ∠B = 52°
        "8635839d93b24272": 0,
        "240502e5a4f70e25": 2,
        "ctet-p1-2018-pyq_q056": 1,
        "ctet-p1-2018-pyq_q058": 0,
    }
    for qid, expected_answer in expected_figure_questions.items():
        row = conn.execute(
            "SELECT answer FROM questions WHERE id = ?",
            (qid,),
        ).fetchone()
        report.require(row is not None, f"Figure question missing: {qid}")
        if row is not None:
            report.require(
                row["answer"] == expected_answer,
                f"Figure question {qid} answer is {row['answer']}, expected {expected_answer}",
            )
    for qid in ("ctet-p1-2018-pyq_q056", "ctet-p1-2018-pyq_q058"):
        row = conn.execute(
            "SELECT options_hindi FROM questions WHERE id = ?",
            (qid,),
        ).fetchone()
        if row is not None:
            report.require(
                json.loads(row["options_hindi"]) == ["चित्र A", "चित्र B", "चित्र C", "चित्र D"],
                f"Figure options were not normalised for {qid}",
            )

    # Locate the repaired grammar detachments
    still_attached = conn.execute(
        "SELECT id FROM questions WHERE id IN ("
        "'ctet-p1-2020-pyq_q134','ctet-p1-2021-pyq_q128','ctet-p1-2021-pyq_q135'"
        ") AND passage_id IS NOT NULL"
    ).fetchall()
    report.require(not still_attached, f"Standalone grammar questions still attached: {still_attached}")

    conn.close()
    return stats


def validate_cdn(report: Report) -> None:
    manifest_path = CDN_DIR / "manifest.json"
    papers_path = CDN_DIR / "papers.json"
    report.require(manifest_path.exists(), "CDN manifest is missing")
    report.require(papers_path.exists(), "CDN papers.json is missing")
    if not manifest_path.exists() or not papers_path.exists():
        return

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    report.require(manifest.get("bank_version") == 2026102019, "CDN version is not v19")
    report.require(manifest.get("total") == 9720, "CDN question total is not 9720")

    pack_questions: dict[str, dict] = {}
    pack_passages: dict[str, dict] = {}
    pack_q_count = 0
    for pack in manifest.get("packs", []):
        path = CDN_DIR / pack["file"]
        if not report.require(path.exists(), f"Pack missing: {pack['file']}"):
            continue
        raw = path.read_bytes()
        report.require(
            hashlib.sha256(raw).hexdigest() == pack.get("sha256"),
            f"Pack hash mismatch: {pack['file']}",
        )
        report.require(len(raw) == pack.get("bytes"), f"Pack byte size mismatch: {pack['file']}")
        data = json.loads(raw)
        pack_q_count += len(data.get("q", []))
        report.require(
            len(data.get("q", [])) == pack.get("count"),
            f"Pack count mismatch: {pack['file']}",
        )
        for question in data.get("q", []):
            if question.get("k") in pack_questions:
                report.error(f"Duplicate question across packs: {question.get('k')}")
            pack_questions[question["k"]] = question
        for passage in data.get("p", []):
            pack_passages[passage["id"]] = passage

    report.require(pack_q_count == 9720, f"CDN packs contain {pack_q_count} questions")
    report.require(len(pack_questions) == 9720, f"CDN unique questions: {len(pack_questions)}")

    for qid in (
        "c831e600eb0b79b8",
        "c27c380ae72953b4",
        "8fa85f18511f9f2e",
        "2b19231183dc5f29",
        "7998ee518e47fa78",
    ):
        q = pack_questions.get(qid)
        report.require(q is not None, f"Comprehension question missing from CDN: {qid}")
        if q:
            report.require(q.get("pid") == "utet-p1-set-c__stim_061", f"Wrong CDN passage mapping: {qid}")

    for qid in (
        "33d37d1cf677481b",
        "bf282c92c0146a34",
        "6481a19579f98188",
        "c1e417281426450c",
        "c946dc4b1f841370",
    ):
        q = pack_questions.get(qid)
        if q:
            report.require("pid" not in q, f"Grammar item still mapped in CDN: {qid}")

    repaired_passage = pack_passages.get("utet-p1-set-c__stim_061")
    report.require(repaired_passage is not None, "Repaired passage missing from CDN packs")
    if repaired_passage:
        body = repaired_passage.get("b", "")
        report.require("###" not in body, "CDN passage still contains headings")
        report.require("राष्ट्रपति" not in body, "CDN passage still contains appended Sanskrit text")

    # papers.json / manifest cross-check
    papers = json.loads(papers_path.read_text(encoding="utf-8"))
    report.require(
        papers.get("version") == manifest.get("bank_version"),
        "papers.json version does not match manifest bank_version",
    )
    report.require(len(papers.get("forms", [])) == 62, "papers.json form count is not 62")
    report.require(len(papers.get("appearances", [])) == 9720, "papers.json appearance count is not 9720")
    for form in papers.get("forms", []):
        report.require(
            form.get("total_questions") == 150,
            f"papers.json form {form.get('id')} total is not 150",
        )
    papers_info = manifest.get("papers_file", {})
    report.require(
        papers_info.get("sha256") == sha256(papers_path),
        "manifest papers.json hash is stale",
    )

    # Compare pack questions to SQLite.  This catches a repaired pack which
    # never made it into the bundled asset database.
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    db_questions = {row["id"]: row for row in conn.execute("SELECT * FROM questions")}
    conn.close()
    report.require(
        set(db_questions) == set(pack_questions),
        "SQLite and CDN question id sets differ",
    )
    for qid, q in pack_questions.items():
        row = db_questions.get(qid)
        if row is None:
            continue
        if q.get("pid") != row["passage_id"] or q.get("n") != row["seq_in_passage"]:
            report.error(f"SQLite/CDN passage mapping differs for {qid}")
        if q.get("a") != row["answer"]:
            report.error(f"SQLite/CDN answer key differs for {qid}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args()

    report = Report()
    if not DB_PATH.exists():
        print(f"ERROR: database not found: {DB_PATH}")
        return 2
    stats = validate_db(report)
    validate_cdn(report)

    print("Vault statistics:")
    for key, value in stats.items():
        print(f"  {key:14s}: {value}")
    print(f"  cdn packs     : {len(list(PACK_DIR.glob('pack-*.json')))}")

    if report.warnings:
        print("\nWarnings:")
        for warning in report.warnings:
            print(f"  WARN  {warning}")

    if report.errors:
        print("\nErrors:")
        for error in report.errors:
            print(f"  FAIL  {error}")
        print(f"\nValidation failed with {len(report.errors)} error(s).")
        return 1

    if args.strict and report.warnings:
        print("\nStrict validation failed because warnings remain.")
        return 1

    print("\nValidation passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

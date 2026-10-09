#!/usr/bin/env python3
"""Regression tests for the bank-v2 -> SQLite -> CDN pack pipeline.

Each test pins one defect that made passage/poem questions disappear or scramble in
the app:

1. poems labelled as prose because the topic was guessed from the stimulus id string
2. `seq_in_passage` holding the paper question number instead of the position in the
   stimulus block
3. language slot (Language-I vs Language-II) dropped on the way to the app
4. stimulus groups split across two packs, so part of a passage's questions rendered
   without their passage
5. a pack carrying questions whose passage text lives in another pack
6. a manifest whose bank_version does not match the build config
"""
from __future__ import annotations

import json
import os
import sqlite3
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
ROOT = TOOLS.parent.parent
sys.path.insert(0, str(TOOLS))

from build_config import BANK_VERSION  # noqa: E402


def build_database(db_path: Path) -> sqlite3.Connection:
    env = dict(os.environ, TET_DB_PATH=str(db_path))
    result = subprocess.run(
        [sys.executable, str(TOOLS / "build_app_db.py")],
        cwd=str(TOOLS), env=env, capture_output=True, text=True,
    )
    if result.returncode != 0:
        raise AssertionError(f"build_app_db.py failed:\n{result.stdout}\n{result.stderr}")
    return sqlite3.connect(db_path)


import apply_stimulus_sources as A


class DatabaseTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls._tmp = tempfile.TemporaryDirectory(prefix="tet-db-test-")
        cls.db_path = Path(cls._tmp.name) / "tet_mock_vault.db"
        cls.conn = build_database(cls.db_path)

    @classmethod
    def tearDownClass(cls) -> None:
        cls.conn.close()
        cls._tmp.cleanup()

    def q(self, sql: str, params: tuple = ()) -> list:
        return self.conn.execute(sql, params).fetchall()

    def test_poem_questions_are_labelled_poem(self) -> None:
        """The stimulus `type` decides the topic, never the id string."""
        rows = self.q(
            """
            SELECT p.kind, q.topic_name, COUNT(*)
            FROM questions q JOIN passages p ON p.id = q.passage_id
            GROUP BY p.kind, q.topic_name
            """
        )
        mapping = {(kind, topic) for kind, topic, _ in rows}
        self.assertIn(("poem", "अपठित पद्यांश"), mapping)
        self.assertNotIn(("poem", "अपठित गद्यांश"), mapping)
        self.assertNotIn(("prose", "अपठित पद्यांश"), mapping)
        poems = self.q(
            "SELECT COUNT(*) FROM questions WHERE stimulus_kind = 'poem'")[0][0]
        self.assertGreater(poems, 100, "expected every poem question, not just one cycle")

    def test_seq_in_passage_is_the_position_inside_the_block(self) -> None:
        bad = self.q(
            """
            SELECT passage_id, COUNT(*) AS n, MIN(seq_in_passage), MAX(seq_in_passage)
            FROM questions WHERE passage_id IS NOT NULL
            GROUP BY passage_id
            HAVING MIN(seq_in_passage) <> 1 OR MAX(seq_in_passage) <> n
            """
        )
        self.assertEqual(bad, [], "seq_in_passage must run 1..N inside each block")

    def test_seq_matches_the_stimulus_minimum_question_count(self) -> None:
        bad = self.q(
            """
            SELECT p.id, p.minimum_questions, COUNT(q.id)
            FROM passages p LEFT JOIN questions q ON q.passage_id = p.id
            WHERE p.minimum_questions IS NOT NULL
            GROUP BY p.id
            HAVING COUNT(q.id) <> p.minimum_questions
            """
        )
        self.assertEqual(bad, [], "block size must match the stimulus minimumQuestions")

    def test_language_slot_survives_to_the_database(self) -> None:
        rows = dict(
            self.q(
                """
                SELECT section, COUNT(*) FROM questions
                WHERE section IN ('hindi', 'english', 'sanskrit')
                  AND language_slot IS NULL
                GROUP BY section
                """
            )
        )
        self.assertEqual(rows, {}, "language questions must carry language_slot")
        slots = {
            row[0]
            for row in self.q(
                "SELECT DISTINCT language_slot FROM questions "
                "WHERE section IN ('hindi', 'english', 'sanskrit')"
            )
        }
        self.assertEqual(slots, {1, 2})

    def test_every_group_is_complete_and_atomic(self) -> None:
        """group_id/group_size/group_policy describe a whole, indivisible block."""
        bad = self.q(
            """
            SELECT group_id, group_size, COUNT(*) FROM questions
            WHERE group_id IS NOT NULL
            GROUP BY group_id HAVING group_size <> COUNT(*)
            """
        )
        self.assertEqual(bad, [], "group_size must equal the number of members")
        policies = {row[0] for row in self.q(
            "SELECT DISTINCT group_policy FROM questions WHERE group_id IS NOT NULL")}
        self.assertEqual(policies, {"atomic"})
        mismatch = self.q(
            """
            SELECT COUNT(*) FROM questions q JOIN passages p ON p.id = q.group_id
            WHERE p.minimum_questions IS NOT NULL AND q.group_size <> p.minimum_questions
            """
        )[0][0]
        self.assertEqual(mismatch, 0)

    def test_a_group_never_spans_two_slots_or_languages(self) -> None:
        bad = self.q(
            """
            SELECT group_id, COUNT(DISTINCT IFNULL(language_slot, -1)),
                   COUNT(DISTINCT IFNULL(language, ''))
            FROM questions WHERE group_id IS NOT NULL
            GROUP BY group_id
            HAVING COUNT(DISTINCT IFNULL(language_slot, -1)) > 1
                OR COUNT(DISTINCT IFNULL(language, '')) > 1
            """
        )
        self.assertEqual(bad, [], "a passage cannot be shared across slots/languages")

    def test_no_orphan_passage_references(self) -> None:
        orphans = self.q(
            "SELECT COUNT(*) FROM questions q LEFT JOIN passages p ON p.id = q.passage_id "
            "WHERE q.passage_id IS NOT NULL AND p.id IS NULL"
        )[0][0]
        self.assertEqual(orphans, 0)


    def test_text_verified_only_for_passages_with_provenance(self) -> None:
        """Both importers wrote review.textVerified: True for every stimulus, including
        the placeholder bodies, so the flag said 'checked' for text nobody checked.
        Only a stimulus carrying sourceRef may be marked verified."""
        with_ref = 0
        for path in (ROOT / "bank-v2" / "exams").glob("**/stimuli.ndjson"):
            with open(path, encoding="utf-8") as fh:
                for line in fh:
                    if line.strip() and json.loads(line).get("sourceRef"):
                        with_ref += 1
        marked = self.q("SELECT COUNT(*) FROM passages WHERE review_text_verified = 1")[0][0]
        self.assertEqual(marked, with_ref,
                         "review_text_verified must come from provenance, not the importer")

class PackTests(unittest.TestCase):
    """Build packs from the freshly built database and check what a client receives."""

    @classmethod
    def setUpClass(cls) -> None:
        cls._tmp = tempfile.TemporaryDirectory(prefix="tet-pack-test-")
        root = Path(cls._tmp.name)
        cls.db_path = root / "runtime" / "tet_mock_vault.db"
        cls.db_path.parent.mkdir(parents=True, exist_ok=True)
        build_database(cls.db_path).close()
        env = dict(os.environ, TET_DB_PATH=str(cls.db_path))
        result = subprocess.run(
            [sys.executable, str(TOOLS / "build_cdn_packs.py")],
            cwd=str(TOOLS), env=env, capture_output=True, text=True,
        )
        if result.returncode != 0:
            raise AssertionError(f"build_cdn_packs.py failed:\n{result.stdout}\n{result.stderr}")
        cls.cdn = ROOT / "cdn"
        cls.manifest = json.loads((cls.cdn / "manifest.json").read_text(encoding="utf-8"))
        cls.packs = [
            json.loads((cls.cdn / entry["file"]).read_text(encoding="utf-8"))
            for entry in cls.manifest["packs"]
        ]

    @classmethod
    def tearDownClass(cls) -> None:
        cls._tmp.cleanup()

    def test_manifest_version_matches_build_config(self) -> None:
        self.assertEqual(self.manifest["bank_version"], BANK_VERSION)

    def test_stimulus_group_is_never_split_across_packs(self) -> None:
        seen: dict[str, set[int]] = {}
        for index, pack in enumerate(self.packs):
            for question in pack.get("q", []):
                pid = question.get("pid")
                if pid:
                    seen.setdefault(pid, set()).add(index)
        split = {pid: idx for pid, idx in seen.items() if len(idx) > 1}
        self.assertEqual(split, {}, "stimulusGroupsAtomic is violated")

    def test_every_pack_can_render_its_own_questions(self) -> None:
        for index, pack in enumerate(self.packs):
            local = {p["id"] for p in pack.get("p", [])}
            referenced = {q["pid"] for q in pack.get("q", []) if q.get("pid")}
            self.assertEqual(
                referenced - local, set(),
                f"pack {index} holds questions whose passage text is elsewhere")

    def test_pack_positions_run_from_one(self) -> None:
        for index, pack in enumerate(self.packs):
            by_block: dict[str, list[int]] = {}
            for question in pack.get("q", []):
                if question.get("pid"):
                    by_block.setdefault(question["pid"], []).append(question["n"])
            for pid, positions in by_block.items():
                self.assertEqual(
                    sorted(positions), list(range(1, len(positions) + 1)),
                    f"pack {index} block {pid} is not numbered 1..N")

    def test_question_and_pack_counts_agree(self) -> None:
        total = sum(len(pack.get("q", [])) for pack in self.packs)
        self.assertEqual(total, self.manifest["total"])
        self.assertEqual(
            sum(entry["count"] for entry in self.manifest["packs"]),
            self.manifest["total"])

    def test_group_contract_reaches_the_client(self) -> None:
        for index, pack in enumerate(self.packs):
            sizes: dict[str, int] = {}
            counts: dict[str, int] = {}
            for question in pack.get("q", []):
                group = question.get("g")
                if not group:
                    continue
                sizes[group["id"]] = group["n"]
                counts[group["id"]] = counts.get(group["id"], 0) + 1
                self.assertEqual(group["pol"], "atomic")
                self.assertTrue(question.get("pid"))
            for gid, size in sizes.items():
                self.assertEqual(
                    counts[gid], size,
                    f"pack {index} carries {counts[gid]} of {size} questions of group {gid}")
            local = {p["id"] for p in pack.get("p", [])}
            for gid in sizes:
                self.assertIn(gid, local,
                              f"pack {index} holds group {gid} without its passage")

    def test_language_slot_reaches_the_client(self) -> None:
        language_questions = [
            q for pack in self.packs for q in pack.get("q", [])
            if q["s"] in ("hindi", "english", "sanskrit")
        ]
        self.assertTrue(language_questions)
        missing = [q["k"] for q in language_questions if "sl" not in q]
        self.assertEqual(missing, [], "language slot missing from pack payload")


class AnswerKeyTests(unittest.TestCase):
    """The bank does not keep the paper's option order in every cycle, so an official
    key must be applied by option text. These tests pin that behaviour."""

    @staticmethod
    def _row(options: dict[str, str]) -> dict:
        return {"options": [{"id": k, "content": [{"text": {"en": v}}]}
                            for k, v in options.items()]}

    def test_key_option_text_finds_its_option_whatever_the_order(self) -> None:
        row = self._row({"a": "relative", "b": "neighbour", "c": "friend",
                         "d": "father-figure"})
        self.assertEqual(A.resolve_by_text(row, "father-figure"), ("d", 1))
        self.assertEqual(A.resolve_by_text(row, "neighbour"), ("b", 1))

    def test_option_text_matching_ignores_case_and_punctuation(self) -> None:
        row = self._row({"a": "Five times as strong."})
        self.assertEqual(A.resolve_by_text(row, "  five   TIMES as strong ")[0], "a")

    def test_unmatched_key_text_is_reported_not_guessed(self) -> None:
        row = self._row({"a": "relative", "b": "neighbour"})
        self.assertEqual(A.resolve_by_text(row, "banana"), (None, 0))

    def test_duplicate_option_text_is_ambiguous_not_picked(self) -> None:
        row = self._row({"a": "same", "b": "same"})
        self.assertEqual(A.resolve_by_text(row, "same"), (None, 2))

    def test_hindi_options_resolve_too(self) -> None:
        row = {"options": [{"id": "a", "content": [{"text": {"hi": "खाद्य संकट"}}]},
                           {"id": "b", "content": [{"text": {"hi": "जल संकट"}}]}]}
        self.assertEqual(A.resolve_by_text(row, "जल संकट"), ("b", 1))

    def test_2026_patriarch_answer_is_the_option_the_paper_calls_father_figure(self) -> None:
        """Regression: this question was once set to b ('neighbour') by applying the
        official key's option number 2 as a letter. The bank's order is shuffled."""
        bank = ROOT / "bank-v2" / "exams" / "ctet" / "paper-1" / "language-2" / "english"
        rows = [json.loads(l) for l in open(bank / "questions.ndjson", encoding="utf-8") if l.strip()]
        row = next(r for r in rows if r["id"] == "ctet-p1-2026-e-lang2-en-q132")
        want, hits = A.resolve_by_text(row, "father-figure")
        self.assertEqual(hits, 1)
        self.assertEqual(row["answer"]["optionId"], want)

    def test_every_cycle_answer_key_survives_loading(self) -> None:
        """Regression: sections were held in a flat dict keyed by section name, so a later
        cycle's source file silently overwrote an earlier one's key for the same section."""
        _e, _p, keys = A.load_sources(None)
        cycles = {t["source"] for group in keys.values() for t in group}
        self.assertIn("ctet-p1-2018-stimulus-sources", cycles)
        self.assertIn("ctet-p1-2024-stimulus-sources", cycles)
        # 2018 L1-English Q91 is d in its key; 2024 says a for the same section.
        tables = keys["language-1/english"]
        by_source = {t["source"]: t for t in tables}
        self.assertEqual(by_source["ctet-p1-2018-stimulus-sources"]["answers"]["91"], "d")
        self.assertEqual(by_source["ctet-p1-2024-stimulus-sources"]["answers"]["91"], "a")

    def test_appearance_official_option_id_matches_the_question_answer(self) -> None:
        """validate_structure.py fails on a disagreement, and it is a real defect: the
        appearance is what a mock paper scores against."""
        answers = {}
        for path in (ROOT / "bank-v2" / "exams").rglob("questions.ndjson"):
            for line in open(path, encoding="utf-8"):
                if line.strip():
                    row = json.loads(line)
                    answers[row["id"]] = (row.get("answer") or {}).get("optionId")
        bad = []
        for path in (ROOT / "bank-v2" / "paper-forms").rglob("appearances.ndjson"):
            for line in open(path, encoding="utf-8"):
                if not line.strip():
                    continue
                row = json.loads(line)
                if "officialOptionId" not in row:
                    continue
                if row["officialOptionId"] != answers.get(row.get("questionId")):
                    bad.append(row.get("id"))
        self.assertEqual(bad, [], "appearances score the old option")


if __name__ == "__main__":
    unittest.main(verbosity=2)

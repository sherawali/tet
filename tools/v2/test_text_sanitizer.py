#!/usr/bin/env python3
"""Regression tests for the deterministic V2 text sanitizer."""
from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from sanitize_bank import run as sanitize_bank_run
from text_sanitizer import (
    normalize_markdown_tables,
    sanitize_display_text,
    sanitize_option_text,
    sanitize_question_stem,
    sanitize_stimulus_text,
    strip_redundant_option_prefix,
)


class StemSanitizerTests(unittest.TestCase):
    def test_strips_supported_question_indices_after_markdown(self) -> None:
        self.assertEqual(sanitize_question_stem("**Q91.** Choose the answer."), "Choose the answer.")
        self.assertEqual(sanitize_question_stem("प्रश्न 12: निम्न में से चुनें"), "निम्न में से चुनें")
        self.assertEqual(sanitize_question_stem("Que. 4. Select one."), "Select one.")
        self.assertEqual(sanitize_question_stem("Question 7 - Choose."), "Choose.")

    def test_does_not_strip_numeric_stems_or_decimals(self) -> None:
        self.assertEqual(sanitize_question_stem("1 cm × 1 cm वाले वर्गों की संख्या?"), "1 cm × 1 cm वाले वर्गों की संख्या?")
        self.assertEqual(sanitize_question_stem("37.188 ÷ 3.6 का मान है"), "37.188 ÷ 3.6 का मान है")
        self.assertEqual(sanitize_question_stem("10.25 बजे घड़ी की सुइयाँ"), "10.25 बजे घड़ी की सुइयाँ")

    def test_removes_markup_and_normalizes_fill_gaps(self) -> None:
        result = sanitize_question_stem("**वाक्य:** रिक्त .......... और ________ भरें")
        self.assertEqual(result, "वाक्य: रिक्त [ ________ ] और [ ________ ] भरें")
        self.assertEqual(sanitize_question_stem(result), result)

    def test_removes_answer_leaks_but_keeps_ordinary_answer_prose(self) -> None:
        self.assertEqual(sanitize_question_stem("कौन-सा सही है? उत्तर: 1"), "कौन-सा सही है?")
        self.assertEqual(sanitize_question_stem("Choose a word which means the same."), "Choose a word which means the same.")
        self.assertEqual(sanitize_question_stem("Pick one. Ans: (b)"), "Pick one.")
        self.assertEqual(sanitize_question_stem("Pick one. (Correct)"), "Pick one.")

    def test_explanation_block_is_removed_only_as_a_separate_block(self) -> None:
        self.assertEqual(
            sanitize_question_stem("Choose the answer.\n\nExplanation: This is the answer."),
            "Choose the answer.",
        )
        assertion_reason = "Statement: Traits vary.\nExplanation: This is part of the item."
        self.assertEqual(sanitize_question_stem(assertion_reason), assertion_reason)

    def test_trailing_parenthesis_and_double_hyphen(self) -> None:
        self.assertEqual(sanitize_question_stem("Choose the option ("), "Choose the option")
        self.assertEqual(sanitize_question_stem("Choose one -- carefully."), "Choose one — carefully.")

    def test_markdown_table_normalization_preserves_cells(self) -> None:
        table = "| **Column I** | Column II |\n|:---:|---|\n| A | B |"
        self.assertEqual(
            normalize_markdown_tables(table),
            "| Column I | Column II |\n| --- | --- |\n| A | B |",
        )
        self.assertEqual(
            sanitize_question_stem("Match:\n" + table),
            "Match:\n| Column I | Column II |\n| --- | --- |\n| A | B |",
        )


class OptionAndStimulusTests(unittest.TestCase):
    def test_strips_only_matching_redundant_bubble_labels(self) -> None:
        self.assertEqual(strip_redundant_option_prefix("(A) Apple", "a", 0), "Apple")
        self.assertEqual(strip_redundant_option_prefix("2. Banana", "b", 1), "Banana")
        self.assertEqual(strip_redundant_option_prefix("(B) Banana", "a", 0), "(B) Banana")
        self.assertEqual(strip_redundant_option_prefix("A. S. Neill", "a", 0), "A. S. Neill")

    def test_preserves_semantic_parenthesized_references(self) -> None:
        self.assertEqual(
            sanitize_option_text("(A) is true but (R) is false.", "a", 0),
            "(A) is true but (R) is false.",
        )
        self.assertEqual(sanitize_option_text("(a) and (b)", "a", 0), "(a) and (b)")
        self.assertEqual(sanitize_option_text("(i) और (iv)", "a", 0), "(i) और (iv)")

    def test_stimulus_answer_key_is_removed_without_normalizing_prose_blanks(self) -> None:
        text = "Passage text.\n**✅ सही उत्तर / Correct Answer: (B)**\n---"
        self.assertEqual(sanitize_stimulus_text(text), "Passage text.")
        self.assertEqual(sanitize_stimulus_text("Keep this blank ________"), "Keep this blank ________")

    def test_display_cleaner_keeps_content_and_paragraphs(self) -> None:
        self.assertEqual(sanitize_display_text("**Bold**\nnext  line"), "Bold\nnext line")


class BankBatchTests(unittest.TestCase):
    def test_batch_is_atomic_in_dry_run_preserves_keys_and_is_idempotent(self) -> None:
        question = {
            "id": "sample-question",
            "prompt": [{"kind": "markdown", "text": {"en": "**Question 1:** Fill ________"}}],
            "options": [
                {"id": "a", "content": [{"text": {"en": "(A) Apple"}}]},
                {"id": "b", "content": [{"text": {"en": "Banana"}}]},
                {"id": "c", "content": [{"text": {"en": "Cherry"}}]},
                {"id": "d", "content": [{"text": {"en": "Date"}}]},
            ],
            "answer": {"kind": "single", "optionId": "b"},
        }
        with tempfile.TemporaryDirectory() as temporary_directory:
            bank = Path(temporary_directory)
            question_file = bank / "exams" / "sample" / "questions.ndjson"
            question_file.parent.mkdir(parents=True)
            original = json.dumps(question, ensure_ascii=False) + "\n"
            question_file.write_text(original, encoding="utf-8")
            source_file = bank / "sources" / "source.json"
            source_file.parent.mkdir(parents=True)
            source_file.write_text('{"id":"source","url":"https://example.test"}\n', encoding="utf-8")

            dry_stats, dry_plans = sanitize_bank_run(bank, dry_run=True)
            self.assertEqual(len(dry_plans), 1)
            self.assertEqual(question_file.read_text(encoding="utf-8"), original)
            self.assertEqual(dry_stats["questions_records_changed"], 1)

            sanitize_bank_run(bank)
            cleaned = json.loads(question_file.read_text(encoding="utf-8"))
            self.assertEqual(cleaned["id"], question["id"])
            self.assertEqual(cleaned["answer"], question["answer"])
            self.assertEqual([option["id"] for option in cleaned["options"]], ["a", "b", "c", "d"])
            self.assertEqual(cleaned["prompt"][0]["text"]["en"], "Fill [ ________ ]")
            self.assertEqual(cleaned["options"][0]["content"][0]["text"]["en"], "Apple")
            self.assertEqual(source_file.read_text(encoding="utf-8"), '{"id":"source","url":"https://example.test"}\n')

            repeat_stats, repeat_plans = sanitize_bank_run(bank, dry_run=True)
            self.assertEqual(repeat_stats["files_changed"], 0)
            self.assertEqual(repeat_plans, [])


if __name__ == "__main__":
    unittest.main()

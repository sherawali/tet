#!/usr/bin/env python3
"""Deep audit of the question DATA of the bundled vault.

Read-only.  Every defect is grouped by category and printed with the
offending question id.  The detection rules live in
``scripts/vault_data_rules.py`` and are shared with the repair script and
the validator, so all three tools always agree.

Usage:
    python scripts/audit_question_data.py
    python scripts/audit_question_data.py --json findings.json
"""

from __future__ import annotations

import argparse
import collections
import json
import re
import sqlite3
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from vault_content_fixes import (  # noqa: E402
    ANSWER_INDEX_FIXES,
    ENGLISH_OPTION_COPIES,
    ENGLISH_OPTION_FIXES,
    ENGLISH_STEM_FIXES,
    FOREIGN_EN_FAMILIES,
    ORPHAN_ORIGINAL_STEMS,
)
from vault_data_rules import (  # noqa: E402
    norm_lower,
    normalize_options,
    option_anchor_violation,
    option_text,
    stem_anchor_violation,
)

ROOT = Path(__file__).resolve().parents[1]
DB_PATH = ROOT / "assets" / "database" / "tet_mock_vault.db"

DEVANAGARI = re.compile(r"[\u0900-\u097F]")
LATIN = re.compile(r"[A-Za-z]")
MARKDOWN_BOLD = re.compile(r"\*\*")
MARKDOWN_HEADING = re.compile(r"(?m)^\s*#{1,6}\s")
PART_HEADER = re.compile(r"##\s*Part", re.I)
CORRUPT = re.compile(r"\?{3,}|\ufffd")
FIGURE_PLACEHOLDER = re.compile(r"\[FIGURE NOT AVAILABLE IN SOURCE BANK[^\]]*\]", re.I)
NUMBER_PREFIX = re.compile(r"^\s*(?:\d{1,3}\s*[\.\)]\s+\S|Q\.?\s*\d+\s*[\.\):]?\s+\S)")

# A stray option label is the label of *that* option in front of the text.
STRAY_LABEL = {
    0: re.compile(r"^\s*\(?\s*A\s*\)?\s*[\.\):\-]\s+"),
    1: re.compile(r"^\s*\(?\s*B\s*\)?\s*[\.\):\-]\s+"),
    2: re.compile(r"^\s*\(?\s*C\s*\)?\s*[\.\):\-]\s+"),
    3: re.compile(r"^\s*\(?\s*D\s*\)?\s*[\.\):\-]\s+"),
}

# Genuinely unresolved placeholders.  "उपरोक्त सभी" and "इनमें से कोई नहीं"
# are real exam options and are not listed here.  "Na" is the chemical symbol
# of sodium, so the not-available spellings are matched case sensitively.
PLACEHOLDER_OPTION = re.compile(
    r"^\s*(?:-{1,3}|—{1,3}|_|N/?A\b|\?+|\.{3,}|x{3,}|\*{1,2}|TODO|TBD)\s*$"
)

# An assertion / reason question numbers its statements (A) and (R); an
# option that starts with "(A) ..." is content there, not a stray label.
STATEMENT_QUESTION_HI = re.compile(
    r"\u0905\u092d\u093f\u0915\u0925\u0928|\u0915\u0925\u0928\s*\(\s*A\s*\)|"
    r"\u0915\u0925\u0928\s*\(\s*B\s*\)|Statement\s*\(\s*[AB]\s*\)",
    re.I,
)
STATEMENT_QUESTION_EN = re.compile(r"Assertion\s*\(\s*A\s*\)|Reason\s*\(\s*R\s*\)", re.I)

# A question that asks the candidate to pick the correct statements numbers
# them ("कथन-1", "Statement 2", ...).  There must be 2..4 of them.
NUMBERED_STATEMENT = re.compile(
    r"(?:statement|\u0915\u0925\u0928)\s*[-\u2013]?\s*(\d)", re.I
)


def stem_enumerates_labels(stem: str) -> bool:
    """True when the stem itself lists labelled statements (A), (B), (C)...

    Such a question prints code answers like "(B) and (C) are correct"; the
    label is part of the answer, not a stray option label.
    """
    return sum(1 for label in "ABCD" if f"({label})" in (stem or "")) >= 2

ASSERTION_HI = re.compile(r"\u0905\u092d\u093f\u0915\u0925\u0928")
REASON_HI = re.compile(r"\u0915\u093e\u0930\u0923|\u0924\u0930\u094d\u0915\s*\(\s*R\s*\)")
ASSERTION_EN = re.compile(r"assertion\s*\(\s*A\s*\)", re.I)
REASON_EN = re.compile(r"reason\s*\(\s*R\s*\)", re.I)
# A question *about* assertion-reason questions is not one itself.
ABOUT_ASSERTION = re.compile(
    r"\u0905\u092d\u093f\u0915\u0925\u0928-\u0924\u0930\u094d\u0915|Assertion-Reason questions",
    re.I,
)
MATCH_COLUMN = re.compile(
    r"(?:\u0915\u0949\u0932\u092d|Column)\s*['\u2019]?\s*([AB])", re.I
)
COLUMN_ITEM = re.compile(r"\(\s*(?:[1-9]|[a-d])\s*\)")
DIGIT_ITEM = re.compile(r"\(\s*[1-9]\s*\)")
LETTER_ITEM = re.compile(r"\(\s*[a-d]\s*\)")

STIMULUS_HI = re.compile(
    r"\u0909\u092a\u0930\u094d\u092f\u0941\u0915\u094d\u0924[^\n]{0,30}?"
    r"(?:\u0917\u0926\u094d\u092f\u093e\u0902\u0936|\u0915\u093e\u0935\u094d\u092f\u093e\u0902\u0936|"
    r"\u092a\u0926\u094d\u092f\u093e\u0902\u0936|\u092a\u0926)"
)
STIMULUS_EN = re.compile(
    r"\b(?:the|this)\s+(?:above|following|preceding|given|underlined)?\s*"
    r"(?:passage|poem|extract|stanza)\b"
    r"|\baccording to the (?:passage|poem|text)\b"
    r"|\bin the (?:above|following) (?:passage|poem|extract)\b",
    re.I,
)


def load_options(raw):
    try:
        value = json.loads(raw or "null")
    except (TypeError, ValueError):
        return None
    return value if isinstance(value, list) else None


def main() -> int:
    global DB_PATH

    parser = argparse.ArgumentParser()
    parser.add_argument("--json")
    parser.add_argument(
        "--db",
        default=str(DB_PATH),
        help="audit another vault (used for testing a candidate repair)",
    )
    args = parser.parse_args()
    DB_PATH = Path(args.db)

    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row

    findings: dict[str, list] = collections.defaultdict(list)

    def report(category: str, qid: str, detail: str) -> None:
        findings[category].append({"id": qid, "detail": detail})

    questions = list(conn.execute("SELECT * FROM questions"))
    by_id = {row["id"]: row for row in questions}
    passages = {row["id"]: row for row in conn.execute("SELECT * FROM passages")}
    passage_bodies = {
        pid: re.sub(r"\s+", " ", (row["body"] or "")).strip().lower()
        for pid, row in passages.items()
    }
    paragraph_prefix: dict[str, list[str]] = collections.defaultdict(list)
    for pid, row in passages.items():
        for paragraph in re.split(r"\n\s*\n", row["body"] or ""):
            paragraph = re.sub(r"\s+", " ", paragraph).strip()
            if len(paragraph) >= 120:
                paragraph_prefix[paragraph[:60].lower()].append(pid)

    # ---------------------------------------------------------- 1. answer keys
    for row in questions:
        qid = row["id"]
        answer = row["answer"]
        hindi_options = load_options(row["options_hindi"])
        english_options = load_options(row["options_english"])
        if answer is None or not isinstance(answer, int) or isinstance(answer, bool):
            report("answer_not_an_integer", qid, f"answer={answer!r}")
            continue
        if answer < 0 or answer > 3:
            report("answer_out_of_range", qid, f"answer={answer}")
            continue
        for label, options in (("hindi", hindi_options), ("english", english_options)):
            if options is None:
                continue
            if answer >= len(options):
                report("answer_points_nowhere", qid, f"{label} has {len(options)} options")
                continue
            text = str(options[answer])
            if not text.strip():
                report("answer_points_to_blank", qid, f"{label}[{answer}] is blank")
            elif PLACEHOLDER_OPTION.match(text.strip()):
                report("answer_points_to_placeholder", qid, f"{label}[{answer}]={text!r}")

    # ------------------------------------------------------------- 2. options
    for row in questions:
        qid = row["id"]
        stem_hi = row["q_hindi"] or ""
        stem_en = row["q_english"] or ""
        hindi_options = load_options(row["options_hindi"])
        english_options = load_options(row["options_english"])
        for label, options in (("hi", hindi_options), ("en", english_options)):
            if options is None:
                if label == "en" and (row["options_english"] or "").strip():
                    report("options_english_unparsable", qid, "not a JSON list")
                continue
            if label == "hi" and len(options) != 4:
                report("option_count_not_4", qid, f"{label} has {len(options)} options")
            seen: dict[str, int] = {}
            for index, option in enumerate(options):
                text = str(option)
                key = norm_lower(text)
                if not key:
                    report("empty_option", qid, f"{label}[{index}] is empty")
                    continue
                if MARKDOWN_BOLD.search(text):
                    report("option_has_markdown_bold", qid, f"{label}[{index}] contains '**'")
                if MARKDOWN_HEADING.search(text) or PART_HEADER.search(text):
                    report("option_has_heading", qid, f"{label}[{index}] contains a heading")
                if index in STRAY_LABEL and STRAY_LABEL[index].match(text):
                    if not (
                        STATEMENT_QUESTION_HI.search(stem_hi)
                        or STATEMENT_QUESTION_EN.search(stem_en)
                        or stem_enumerates_labels(stem_hi)
                        or stem_enumerates_labels(stem_en)
                    ):
                        report("option_has_letter_prefix", qid, f"{label}[{index}]={text[:60]!r}")
                if FIGURE_PLACEHOLDER.search(text):
                    report("option_has_figure_placeholder", qid, f"{label}[{index}]")
                if PLACEHOLDER_OPTION.match(text.strip()):
                    report("placeholder_option", qid, f"{label}[{index}]={text[:60]!r}")
                if key in seen:
                    report(
                        "duplicate_option",
                        qid,
                        f"{label}[{index}] == {label}[{seen[key]}] ({text[:60]!r})",
                    )
                else:
                    seen[key] = index
                stem_key = norm_lower(stem_hi if label == "hi" else stem_en)
                if stem_key and key == stem_key:
                    report("option_equals_stem", qid, f"{label}[{index}] is identical to the stem")
                low = re.sub(r"\s+", " ", text).strip().lower()
                for pid in paragraph_prefix.get(low[:60], []):
                    if low and low in passage_bodies[pid]:
                        report("option_contains_passage", qid, f"{label}[{index}] has passage {pid}")
                        break
        if hindi_options is not None and english_options is not None:
            if len(hindi_options) != len(english_options):
                report(
                    "option_count_mismatch",
                    qid,
                    f"hindi={len(hindi_options)} english={len(english_options)}",
                )
        if (row["q_english"] or "").strip() and english_options is None:
            report("english_stem_without_english_options", qid, "q_english set, options missing")
        if not (row["q_hindi"] or "").strip():
            report("empty_stem", qid, "q_hindi is empty")

    # --------------------------------------------------------------- 3. stems
    for row in questions:
        qid = row["id"]
        for label, text in (("hi", row["q_hindi"]), ("en", row["q_english"])):
            value = text or ""
            if not value.strip():
                continue
            if MARKDOWN_BOLD.search(value):
                report("stem_has_markdown_bold", qid, f"{label} contains '**'")
            if MARKDOWN_HEADING.search(value):
                report("stem_has_heading", qid, f"{label} contains a heading")
            if NUMBER_PREFIX.match(value):
                report("stem_has_numbering", qid, f"{label}={value[:60]!r}")
            if CORRUPT.search(value):
                report("stem_corrupt", qid, f"{label}={value[:80]!r}")
            if FIGURE_PLACEHOLDER.search(value):
                report("stem_has_figure_placeholder", qid, label)
        section = row["section"] or ""
        hindi = row["q_hindi"] or ""
        english = row["q_english"] or ""
        if section in {"lang1_hindi", "hindi", "hindi_2"}:
            if hindi.strip() and LATIN.search(hindi) and not DEVANAGARI.search(hindi):
                report("english_in_hindi_section", qid, f"{section}: {hindi[:70]!r}")
        if section in {"lang2_english", "english", "english_1"}:
            if hindi.strip() and DEVANAGARI.search(hindi) and not english.strip():
                report("devanagari_in_english_section", qid, f"{section}: {hindi[:70]!r}")

    # ------------------------------------------- 4. bilingual consistency
    for row in questions:
        qid = row["id"]
        hindi_options = load_options(row["options_hindi"]) or []
        english_options = load_options(row["options_english"]) or []
        stem_bad = stem_anchor_violation(row["q_hindi"] or "", row["q_english"] or "")
        if stem_bad:
            report(
                "foreign_english_stem",
                qid,
                f"missing anchor(s) {stem_bad} in {row['q_english']!r}",
            )
        option_bad = option_anchor_violation(hindi_options, english_options)
        if option_bad:
            report(
                "foreign_english_options",
                qid,
                "; ".join(f"[{index}] missing {anchors}" for index, anchors in option_bad),
            )

    # ------------------------------- 4b. english column shifted by a question
    # Two questions that print the same English stem and the same Hindi
    # options must print the same English options.  A different list means
    # that the English column of the source dump was shifted by one
    # question, so the candidate would see the options of another question.
    english_groups: dict[tuple, list] = collections.defaultdict(list)
    for row in questions:
        hindi_options = load_options(row["options_hindi"]) or []
        english_options = load_options(row["options_english"]) or []
        if not (row["q_english"] or "").strip():
            continue
        if len(hindi_options) != 4 or len(english_options) != 4:
            continue
        english_groups[
            (
                norm_lower(row["q_english"]),
                tuple(norm_lower(option) for option in hindi_options),
            )
        ].append(row)
    for key, members in english_groups.items():
        counts = collections.Counter(
            tuple(norm_lower(option) for option in load_options(member["options_english"]))
            for member in members
        )
        if len(counts) <= 1:
            continue
        ranked = counts.most_common()
        if ranked[0][1] == ranked[-1][1]:
            # Two equally common renderings of the same option list: a
            # wording variant, not a shifted column.
            continue
        for member in members:
            options = tuple(
                norm_lower(option) for option in load_options(member["options_english"])
            )
            if options != ranked[-1][0]:
                report(
                    "shifted_english_options",
                    member["id"],
                    f"{list(options)} instead of {list(ranked[-1][0])}",
                )

    # The curated english text must not drift away again.
    for qid, stem in ENGLISH_STEM_FIXES.items():
        row = by_id.get(qid)
        if row is not None and (row["q_english"] or "") != stem:
            report("curated_english_stem", qid, f"{row['q_english']!r}")
    for qid, donor_id in ENGLISH_OPTION_COPIES.items():
        row = by_id.get(qid)
        donor = by_id.get(donor_id)
        if row is None or donor is None:
            report("curated_english_options", qid, "question missing")
            continue
        if row["options_english"] != donor["options_english"]:
            report("curated_english_options", qid, "english option list drifted")
    for qid, options in ENGLISH_OPTION_FIXES.items():
        row = by_id.get(qid)
        if row is None:
            report("curated_english_options", qid, "question missing")
            continue
        if [str(value) for value in (load_options(row["options_english"]) or [])] != [
            str(value) for value in options
        ]:
            report("curated_english_options", qid, "english option list drifted")
    for qid, answer in ANSWER_INDEX_FIXES.items():
        row = by_id.get(qid)
        if row is not None and row["answer"] != answer:
            report("curated_answer_key", qid, f"answer={row['answer']}")

    # -------------------------------------------------------- 5. answer keys
    families: dict[tuple, list] = collections.defaultdict(list)
    for row in questions:
        options = load_options(row["options_hindi"]) or []
        families[(norm_lower(row["q_hindi"]), frozenset(normalize_options(options)))].append(row)
    for key, members in families.items():
        if len(members) < 2:
            continue
        semantics = {
            option_text(load_options(member["options_hindi"]), member["answer"])
            for member in members
        }
        semantics.discard("")
        if len(semantics) > 1:
            report(
                "conflicting_answer_key",
                members[0]["id"],
                "same question, different key: "
                + ", ".join(f"{m['id']}={m['answer']}" for m in members),
            )

    # ------------------------------------------------------ 6. question types
    for row in questions:
        qid = row["id"]
        hindi = row["q_hindi"] or ""
        english = row["q_english"] or ""
        if ASSERTION_HI.search(hindi) or ASSERTION_EN.search(english):
            if ABOUT_ASSERTION.search(hindi) or ABOUT_ASSERTION.search(english):
                continue
            has_assertion = bool(ASSERTION_HI.search(hindi) or ASSERTION_EN.search(english))
            has_reason = bool(REASON_HI.search(hindi) or REASON_EN.search(english))
            if not (has_assertion and has_reason):
                report("assertion_reason_incomplete", qid, "assertion or reason missing")
        text = hindi if DEVANAGARI.search(hindi) else english
        if MATCH_COLUMN.search(text):
            digits = len(DIGIT_ITEM.findall(text))
            letters = len(LETTER_ITEM.findall(text))
            if digits and letters and digits != letters:
                report(
                    "match_column_unbalanced",
                    qid,
                    f"column I has {digits} items, column II has {letters} items",
                )
        # A question that lists numbered statements must list 2..4 of them.
        statements = {int(number) for number in NUMBERED_STATEMENT.findall(text)}
        if statements and not (2 <= len(statements) <= 4):
            report(
                "multi_statement_count",
                qid,
                f"{len(statements)} numbered statements: {sorted(statements)}",
            )

    # A stem whose first characters were cut off is broken: the candidate
    # reads "n Maslow's theory ..." instead of "In Maslow's theory ...".
    # The truncation is detected by comparing the copies of one question.
    stem_families: dict[tuple, list] = collections.defaultdict(list)
    for row in questions:
        hindi_options = load_options(row["options_hindi"]) or []
        stem_families[
            (norm_lower(row["q_hindi"]), frozenset(normalize_options(hindi_options)))
        ].append(row)
    for members in stem_families.values():
        english_stems = {
            row["id"]: (row["q_english"] or "").strip() for row in members
        }
        for qid, stem in english_stems.items():
            if not stem:
                continue
            for other_id, other in english_stems.items():
                if other_id == qid or not other:
                    continue
                for cut in (1, 2, 3):
                    if len(other) > cut and other[cut:] == stem:
                        report(
                            "stem_truncated",
                            qid,
                            f"{stem[:60]!r} is {other[:cut]!r} + the rest of "
                            f"{other[:40]!r}",
                        )
                        break
                else:
                    continue
                break

    # ------------------------------------------------------------ 7. passages
    used = collections.Counter()
    for row in questions:
        pid = row["passage_id"]
        if pid:
            used[pid] += 1
            if pid not in passages:
                report("missing_passage", row["id"], f"passage {pid} does not exist")
    for pid in passages:
        if used.get(pid, 0) == 0:
            report("unused_passage", pid, "no question uses this passage")
    for row in questions:
        if row["passage_id"]:
            continue
        if STIMULUS_HI.search(row["q_hindi"] or "") or STIMULUS_EN.search(
            row["q_english"] or ""
        ):
            report("missing_stimulus", row["id"], "stem refers to a stimulus that is not attached")

    # ------------------------------------------- 8. papers, sections, repeats
    appearances = list(conn.execute("SELECT * FROM appearances"))
    per_paper: dict[str, list] = collections.defaultdict(list)
    for appearance in appearances:
        per_paper[appearance["paper_form_id"]].append(appearance)
        question = by_id.get(appearance["question_id"])
        if question is None:
            report("appearance_missing_question", appearance["id"], "question missing")
            continue
        if appearance["section"] != question["section"]:
            report(
                "appearance_section_mismatch",
                appearance["question_id"],
                f"paper {appearance['paper_form_id']} #{appearance['question_number']}: "
                f"{appearance['section']} != {question['section']}",
            )
    for form, rows in per_paper.items():
        groups: dict[tuple, list] = collections.defaultdict(list)
        for appearance in rows:
            question = by_id.get(appearance["question_id"])
            if question is None:
                continue
            groups[
                (norm_lower(question["q_hindi"]), question["passage_id"] or "")
            ].append(appearance)
        for key, group in groups.items():
            if len(group) > 1:
                report(
                    "duplicate_in_paper",
                    key[0][:70],
                    f"paper {form} prints it at "
                    f"{[g['question_number'] for g in group]}",
                )
        counts = collections.Counter(appearance["section"] for appearance in rows)
        declared = json.loads(
            conn.execute(
                "SELECT modules_json FROM paper_forms WHERE id = ?", (form,)
            ).fetchone()[0]
            or "[]"
        )
        for section in declared:
            if counts.get(section, 0) == 0:
                report(
                    "paper_section_without_questions",
                    form,
                    f"declares section {section} but prints no question of it",
                )

        # A paper must print the numbers 1..150 exactly once.  A Paper-2
        # form carries both optional streams, so the numbering is checked
        # for every stream the candidate can choose.
        sections = {appearance["section"] for appearance in rows}
        streams = sorted(sections & {"math_science", "social_studies"})
        for stream in streams or [None]:
            if stream is None:
                numbers = [appearance["question_number"] for appearance in rows]
            else:
                other = (
                    "social_studies" if stream == "math_science" else "math_science"
                )
                numbers = [
                    appearance["question_number"]
                    for appearance in rows
                    if appearance["section"] != other
                ]
            if sorted(numbers) != list(range(1, 151)):
                report(
                    "paper_numbering_incomplete",
                    form,
                    f"stream {stream}: {len(numbers)} questions, numbers "
                    f"{sorted(numbers)[:5]}..{sorted(numbers)[-5:]}",
                )
        # The two booklets of an exam must not print the same question
        # twice inside one paper.
        printed = collections.Counter(
            appearance["question_id"] for appearance in rows
        )
        for qid, count in printed.items():
            if count > 1:
                report(
                    "question_printed_twice",
                    qid,
                    f"paper {form} prints it {count} times",
                )

    conn.close()

    order = [
        "answer_not_an_integer", "answer_out_of_range", "answer_points_nowhere",
        "answer_points_to_blank", "answer_points_to_placeholder",
        "conflicting_answer_key", "option_count_not_4", "empty_option",
        "duplicate_option", "option_equals_stem", "option_has_markdown_bold",
        "option_has_heading", "option_has_letter_prefix", "option_has_figure_placeholder",
        "placeholder_option", "option_contains_passage", "option_count_mismatch",
        "options_english_unparsable", "english_stem_without_english_options",
        "empty_stem", "stem_has_markdown_bold", "stem_has_heading", "stem_has_numbering",
        "stem_corrupt", "stem_has_figure_placeholder", "stem_truncated",
        "english_in_hindi_section", "devanagari_in_english_section",
        "foreign_english_stem", "foreign_english_options",
        "shifted_english_options", "curated_english_stem",
        "curated_english_options", "curated_answer_key",
        "assertion_reason_incomplete", "match_column_unbalanced",
        "multi_statement_count", "missing_passage", "unused_passage",
        "missing_stimulus", "appearance_missing_question",
        "appearance_section_mismatch", "duplicate_in_paper",
        "question_printed_twice", "paper_section_without_questions",
        "paper_numbering_incomplete",
    ]
    total = 0
    print("=== findings ===")
    for key in order:
        items = findings.get(key, [])
        total += len(items)
        if not items:
            continue
        print(f"\n[{key}] : {len(items)}")
        for item in items[:12]:
            print(f"    {item['id']}  {item['detail']}")
        if len(items) > 12:
            print(f"    ... and {len(items) - 12} more")
    for key in sorted(set(findings) - set(order)):
        total += len(findings[key])
        print(f"\n[{key}] : {len(findings[key])}")
        for item in findings[key][:12]:
            print(f"    {item['id']}  {item['detail']}")
    print(f"\nTOTAL FINDINGS: {total}")

    if args.json:
        Path(args.json).write_text(
            json.dumps(dict(findings), ensure_ascii=False, indent=2), encoding="utf-8"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Find question options that have swallowed the next block's stimulus text.

`import_all_ctet.py` split the scanned paper into questions by looking for question
numbers. Where a stimulus begins on the same line as the last option of the previous
question, the whole passage ends up glued to that option. The result is an option that
reads like a paragraph instead of an answer, and a stimulus whose own body is a
placeholder even though its text is sitting in the bank one question earlier.

Two signals, either of which flags an option:

* it is far longer than its three siblings (a real option is short);
* it carries a question-range marker like "(100-105)", which only a stimulus block
  announces.

The instruction wording alone is deliberately NOT enough: "निर्देश" is an ordinary word
in Hindi pedagogy options ("निर्देशित पठन", "शिक्षार्थियों को निर्देश देना") and flagging
it produces mostly false positives. It only counts alongside a range marker or a long body.

This tool only reports. Nothing is rewritten: moving text out of an option and into a
stimulus needs a human to confirm where the passage starts.

Usage:
    python3 tools/v2/audit_option_leaks.py
    python3 tools/v2/audit_option_leaks.py --exam ctet --year 2026
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
EXAMS_DIR = os.path.join(ROOT, "bank-v2", "exams")

# Instructions that open a stimulus block, in the languages this bank carries.
INSTRUCTION = re.compile(
    r"(read the (?:extract|passage|poem)|directions?\s*[:\-]?\s*read"
    r"|answer the questions that follow|given below and answer"
    r"|निर्देश|गद्यांश|पद्यांश|कवितांश|नीचे दिए गए|पढ़िए|पढ़कर"
    r"|उत्तर दीजिए|उत्तर चुनिए)",
    re.IGNORECASE,
)
# "(100-105)" / "(121–129)" - the question range a stimulus block announces.
RANGE_MARK = re.compile(r"\(\s*\d{1,3}\s*[-\u2013\u2014]\s*\d{1,3}\s*\)")
# A long option is suspicious even without either marker.
LONG_OPTION = 220


def option_text(option: dict) -> str:
    for chunk in option.get("content", []):
        text = chunk.get("text") or {}
        for lang in ("en", "hi", "sa", "ur"):
            if text.get(lang):
                return text[lang]
        for value in text.values():
            if value:
                return value
    return ""


def question_paths(exam: str | None, year: str | None) -> list[str]:
    found = []
    for dirpath, _dirs, names in os.walk(EXAMS_DIR):
        if "questions.ndjson" not in names:
            continue
        rel = os.path.relpath(dirpath, EXAMS_DIR).replace(os.sep, "/")
        if exam and not rel.startswith(exam):
            continue
        found.append(os.path.join(dirpath, "questions.ndjson"))
    return sorted(found)


def scan(exam: str | None, year: str | None) -> tuple[list[dict], int]:
    leaks: list[dict] = []
    questions = 0
    for path in question_paths(exam, year):
        for line in open(path, encoding="utf-8"):
            if not line.strip():
                continue
            row = json.loads(line)
            if year and f"-{year}" not in row["id"]:
                continue
            questions += 1
            options = row.get("options") or []
            lengths = [len(option_text(o)) for o in options]
            if not lengths:
                continue
            median = sorted(lengths)[len(lengths) // 2]
            for option, length in zip(options, lengths):
                text = option_text(option)
                has_range = bool(RANGE_MARK.search(text))
                is_long = length >= LONG_OPTION and length > 2 * max(median, 1)
                reasons = []
                if has_range:
                    reasons.append("question-range marker")
                if is_long:
                    reasons.append(f"{length} chars vs median {median}")
                if not reasons:
                    # Wording alone is not evidence; keep the two signals above as the gate.
                    continue
                if INSTRUCTION.search(text):
                    reasons.append("stimulus instruction")
                leaks.append({
                    "id": row["id"],
                    "option": option["id"],
                    "reasons": reasons,
                    "stimulusId": row.get("stimulusId"),
                    "preview": text[:160].replace("\n", " "),
                })
    return leaks, questions


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--exam", help="exam id prefix, e.g. ctet")
    ap.add_argument("--year", help="cycle label as it appears in the question id, e.g. 2026")
    ap.add_argument("--json", action="store_true", help="emit machine-readable findings")
    args = ap.parse_args()

    leaks, questions = scan(args.exam, args.year)

    if args.json:
        json.dump({"scanned_questions": questions, "leaked_options": leaks},
                  sys.stdout, ensure_ascii=False, indent=2)
        print()
        return 0

    print(f"questions scanned : {questions}")
    print(f"leaked options    : {len(leaks)}")
    by_question = sorted({leak["id"] for leak in leaks})
    print(f"questions affected: {len(by_question)}")
    print()
    for leak in leaks:
        print(f"  {leak['id']} option {leak['option']} "
              f"[{', '.join(leak['reasons'])}]")
        print(f"      {leak['preview']}")
    print()
    if leaks:
        print("Reported, not repaired: moving this text into a stimulus needs a human to")
        print("confirm where the passage begins and which questions it belongs to.")
    else:
        print("No option has swallowed a passage.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Report stimulus-linked sections whose answers never vary.

`import_all_ctet.py` wrote `answer.optionId = "a"` for every stimulus-linked question of
the 2018, 2024 and 2026 cycles. A block of 6-9 questions that all have the same key is
not a pattern, it is a missing answer key, so those mocks are unanswerable.

This does not fail the build: the fix needs the official key for each cycle, which is
supplied per cycle through `bank-v2/sources/stimuli/<cycle>.json` and applied with
`tools/v2/apply_stimulus_sources.py`. Run this to see what is left.

Usage:
    python3 tools/v2/audit_answer_keys.py            # report, exit 0
    python3 tools/v2/audit_answer_keys.py --fail     # exit 1 while anything is left
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
EXAMS_DIR = os.path.join(ROOT, "bank-v2", "exams")
MIN_BLOCK = 6  # smallest stimulus block in the bank


def cycle_of(qid: str) -> str:
    parts = qid.split("-")
    if len(parts) >= 5 and parts[3].isdigit() and not parts[4].isdigit():
        return "-".join(parts[:5])  # ctet-p1-2021-dec
    return "-".join(parts[:4])


def scan() -> list[dict]:
    groups: dict[tuple, dict[str, int]] = defaultdict(lambda: defaultdict(int))
    for base, _dirs, files in os.walk(EXAMS_DIR):
        if "questions.ndjson" not in files:
            continue
        rel = os.path.relpath(base, EXAMS_DIR).replace(os.sep, "/")
        section = rel.split("paper-1/")[-1].split("paper-2/")[-1]
        with open(os.path.join(base, "questions.ndjson"), encoding="utf-8") as fh:
            for line in fh:
                if not line.strip():
                    continue
                row = json.loads(line)
                if not row.get("stimulusId"):
                    continue
                groups[(cycle_of(row["id"]), section)][
                    (row.get("answer") or {}).get("optionId")] += 1

    findings = []
    for (cycle, section), counts in sorted(groups.items()):
        total = sum(counts.values())
        if total < MIN_BLOCK:
            continue
        top, n = max(counts.items(), key=lambda kv: kv[1])
        if n == total:
            findings.append({"cycle": cycle, "section": section, "option": top,
                             "questions": total})
    return findings


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--fail", action="store_true",
                    help="exit 1 while any uniform section remains")
    ap.add_argument("--json", action="store_true", help="machine-readable output")
    args = ap.parse_args()

    findings = scan()
    if args.json:
        print(json.dumps(findings, ensure_ascii=False, indent=2))
    else:
        if not findings:
            print("Every stimulus-linked section has varied answer keys.")
        else:
            print(f"{len(findings)} sections have a single answer key for every question:")
            print(f"{'cycle':<22}{'section':<26}{'option':<8}questions")
            for f in findings:
                print(f"{f['cycle']:<22}{f['section']:<26}{f['option']:<8}{f['questions']}")
            print()
            print("Fix per cycle: put the official key in bank-v2/sources/stimuli/<cycle>.json")
            print("and run tools/v2/apply_stimulus_sources.py")
    return 1 if (args.fail and findings) else 0


if __name__ == "__main__":
    sys.exit(main())

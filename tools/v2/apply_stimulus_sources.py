#!/usr/bin/env python3
"""Replace placeholder stimulus text with verified passage/poem text, and correct
answers that the importer defaulted to option 'a'.

`import_all_ctet.py` did two things wrong:

1. it hardcoded the body of every passage and poem for 2016, 2018, 2019, 2021-Dec,
   2023, 2024 and 2026 (see docs/STIMULUS_LINK_AUDIT.md);
2. for the 2018, 2024 and 2026 cycles it wrote `answer.optionId = "a"` for every
   stimulus-linked question, so those questions are all keyed to the same option.

This tool overwrites both from `bank-v2/sources/stimuli/<cycle>.json`, which holds text
transcribed from the actual paper plus the official answer key, each with provenance.
Nothing is invented here: a stimulus is only touched when a source entry names it by id,
an answer is only touched when a source file supplies a key for that section, and
`review.textVerified` / `review.answerKeyVerified` are set from the source.

Usage:
    python3 tools/v2/apply_stimulus_sources.py --check     # dry run, no writes
    python3 tools/v2/apply_stimulus_sources.py             # apply
    python3 tools/v2/apply_stimulus_sources.py --cycle ctet-p1-2024
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SOURCES_DIR = os.path.join(ROOT, "bank-v2", "sources", "stimuli")
EXAMS_DIR = os.path.join(ROOT, "bank-v2", "exams")

NL = "\n"


def ndjson_paths(filename: str) -> list[str]:
    out = []
    for base, _dirs, files in os.walk(EXAMS_DIR):
        if filename in files:
            out.append(os.path.join(base, filename))
    return sorted(out)


def load_sources(cycle: str | None) -> tuple[dict[str, dict], dict[str, dict], dict[str, str]]:
    """Return (stimulus entries by id, provenance by source id, answer keys keyed by
    "<exam>-p<paper>-<cycle>-<section>"). The cycle is part of the key on purpose: the
    question numbers 91-150 repeat in every cycle, so a key scoped by section alone
    would silently rewrite other years."""
    entries: dict[str, dict] = {}
    provenance: dict[str, dict] = {}
    keys: dict[str, dict[str, str]] = {}
    if not os.path.isdir(SOURCES_DIR):
        return entries, provenance, keys
    for name in sorted(os.listdir(SOURCES_DIR)):
        if not name.endswith(".json"):
            continue
        if cycle and name != f"{cycle}.json":
            continue
        with open(os.path.join(SOURCES_DIR, name), encoding="utf-8") as fh:
            doc = json.load(fh)
        prov = {k: v for k, v in doc.get("provenance", {}).items() if k != "caveat"}
        provenance[doc["id"]] = prov
        for item in doc.get("stimuli", []):
            item = dict(item)
            item["_sourceId"] = doc["id"]
            item["_provenance"] = prov
            entries[item["stimulusId"]] = item
        # One leaf file holds every cycle, so the key is matched against the question
        # id itself: "<exam>-p<paper>-<cycleLabel>-<language-N>-...".
        # Question ids look like "ctet-p1-2024-i-lang2-en-q121" (older cycles use
        # "language-2"); the optional set code sits between the cycle and the slot.
        head = re.escape(f"{doc['exam']}-p{doc['paper']}-{doc['cycleLabel']}")
        idpat = re.compile(rf"^{head}(?:-[a-z0-9]+)?-(?:lang(\d)|language-(\d))-")
        for section, spec in doc.get("answerKey", {}).get("sections", {}).items():
            keys[section] = {
                "pattern": idpat,
                # the slot number of "language-2/english" is "2"
                "expected": section.split("/")[0].split("-")[1],
                "answers": {str(k): str(v) for k, v in spec.get("answers", {}).items()},
            }
    return entries, provenance, keys


def section_of(path: str) -> str:
    rel = os.path.relpath(path, EXAMS_DIR).replace(os.sep, "/")
    rel = rel.split("paper-1/")[-1].split("paper-2/")[-1]
    return "/".join(rel.split("/")[:-1])


def fix_answers(keys: dict[str, dict[str, str]], check_only: bool) -> tuple[int, int]:
    """Correct stimulus-linked answers against the official key for known cycles+sections."""
    fixed = same = 0
    for path in ndjson_paths("questions.ndjson"):
        section = section_of(path)
        tables = [t for name, t in keys.items() if name == section and "pattern" in t]
        if not tables:
            continue
        rows = [json.loads(line) for line in open(path, encoding="utf-8") if line.strip()]
        dirty = False
        for row in rows:
            if not row.get("stimulusId"):
                continue
            match = None
            for table in tables:
                m = table["pattern"].match(row["id"])
                if m and (m.group(1) or m.group(2)) == table["expected"]:
                    match = table["answers"]
                    break
            if not match:
                continue
            num = None
            for app in row.get("appearances") or []:
                if app.get("questionNumber") is not None:
                    num = int(app["questionNumber"])
                    break
            if num is None:
                m = re.search(r"q(\d+)$", row["id"])
                num = int(m.group(1)) if m else None
            if num is None or str(num) not in match:
                continue
            want = match[str(num)]
            if row.get("answer", {}).get("optionId") == want:
                same += 1
                continue
            print(f"  answer {row['id']}: {row.get('answer', {}).get('optionId')} -> {want}")
            if not check_only:
                row.setdefault("answer", {})["optionId"] = want
                review = row.setdefault("review", {})
                review["answerKeyVerified"] = True
            dirty = True
            fixed += 1
        if dirty and not check_only:
            with open(path, "w", encoding="utf-8") as fh:
                for row in rows:
                    fh.write(json.dumps(row, ensure_ascii=False) + NL)
    return fixed, same


def apply(check_only: bool, cycle: str | None) -> int:
    entries, provenance, keys = load_sources(cycle)
    if not entries and not keys:
        print(f"No source entries found in {os.path.relpath(SOURCES_DIR, ROOT)}"
              + (f" for cycle {cycle}" if cycle else ""))
        return 1

    per_file: dict[str, list[dict]] = {}
    for path in ndjson_paths("stimuli.ndjson"):
        per_file[path] = [json.loads(l) for l in open(path, encoding="utf-8") if l.strip()]
    location = {row["id"]: path for path, rows in per_file.items() for row in rows}

    missing = sorted(set(entries) - set(location))
    if missing:
        print("Refusing to run: source entries name stimuli that do not exist:")
        for sid in missing:
            print(f"  {sid}")
        return 1

    changed = skipped = 0
    for path, rows in per_file.items():
        dirty = False
        for row in rows:
            entry = entries.get(row["id"])
            if not entry:
                continue
            text = entry.get("text", "").strip()
            if not text:
                skipped += 1
                continue
            lang = entry.get("language", "hi")
            new_content = [{"kind": "markdown", "text": {lang: text}}]
            if (row.get("content") == new_content
                    and row.get("instructions", {}).get(lang) == entry.get("instructions")
                    and (row.get("review") or {}).get("textVerified") is True):
                skipped += 1
                continue
            print(f"  {row['id']}")
            print(f"    was : {(row.get('content') or [{}])[0].get('text', {})!s:.110}")
            print(f"    now : {text[:110]}")
            if not check_only:
                row["content"] = new_content
                if entry.get("instructions"):
                    row.setdefault("instructions", {})[lang] = entry["instructions"]
                row.setdefault("review", {})["textVerified"] = True
                row["sourceRef"] = {"id": entry["_sourceId"], **entry["_provenance"]}
            dirty = True
            changed += 1
        if dirty and not check_only:
            with open(path, "w", encoding="utf-8") as fh:
                for row in rows:
                    fh.write(json.dumps(row, ensure_ascii=False) + NL)

    total_stimuli = sum(len(rows) for rows in per_file.values())
    print()
    print(f"{'would replace' if check_only else 'replaced'} {changed} stimulus bodies "
          f"({skipped} already current), {total_stimuli} stimuli in the bank")
    print(f"still placeholder: {total_stimuli - changed - skipped} "
          f"- add sources under bank-v2/sources/stimuli/")

    if keys:
        fixed, same = fix_answers(keys, check_only)
        print()
        print(f"{'would correct' if check_only else 'corrected'} {fixed} answers from the "
              f"official key ({same} already right)")

    print()
    print("After applying, verify with:")
    print("  python3 tools/v2/audit_stimulus_links.py")
    print("  python3 tools/v2/validate_stimulus_groups.py")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--check", action="store_true", help="dry run, write nothing")
    ap.add_argument("--cycle", default=None, help="only this cycle file, e.g. ctet-p1-2024")
    args = ap.parse_args()
    return apply(args.check, args.cycle)


if __name__ == "__main__":
    sys.exit(main())

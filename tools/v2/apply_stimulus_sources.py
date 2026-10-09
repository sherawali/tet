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
                # Preferred shape: the paper's own option texts. The bank does not keep the
                # paper's option order in every cycle, so a key number cannot be turned into
                # a letter. When "answerTexts" is present the correct option is found by
                # comparing its text with the bank's options.
                "answerTexts": {
                    str(k): v for k, v in spec.get("answerTexts", {}).items()
                },
            }
    return entries, provenance, keys


_PUNCT = re.compile(r"[\s\u00a0]+")


def normalize_option_text(value: str) -> str:
    """Fold an option's text so paper and bank wordings can be compared.

    Lowercases, collapses whitespace (including non-breaking spaces) and strips
    punctuation from both ends, so "Five times as strong." matches "five times as strong".
    """
    text = _PUNCT.sub(" ", (value or "")).strip().lower()
    return text.strip(" .,;:!?\u0964\u0965\"'()[]-")


def option_text(option: dict) -> str:
    """The first text content of an option, in whichever language it is written."""
    for chunk in option.get("content", []):
        text = (chunk.get("text") or {})
        for lang in ("en", "hi", "sa", "ur"):
            if text.get(lang):
                return text[lang]
        for value in text.values():
            if value:
                return value
    return ""


def resolve_by_text(row: dict, want_text: str) -> tuple[str | None, int]:
    """Find the bank option whose text matches the key's option text.

    Returns (optionId, number_of_matches). Zero or more than one match means the key
    cannot be applied to this question and the caller must not guess.
    """
    target = normalize_option_text(want_text)
    hits = [o["id"] for o in row.get("options", []) if normalize_option_text(option_text(o)) == target]
    return (hits[0] if len(hits) == 1 else None), len(hits)


def section_of(path: str) -> str:
    rel = os.path.relpath(path, EXAMS_DIR).replace(os.sep, "/")
    rel = rel.split("paper-1/")[-1].split("paper-2/")[-1]
    return "/".join(rel.split("/")[:-1])


def fix_answers(keys: dict[str, dict], check_only: bool) -> tuple[int, int, int]:
    """Correct stimulus-linked answers against the official key for known cycles+sections.

    Returns (fixed, same, unresolved). `unresolved` counts questions the key covers but
    that could not be matched to a single bank option - those are reported, never guessed.
    """
    fixed = same = unresolved = 0
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
            table = None
            for candidate in tables:
                m = candidate["pattern"].match(row["id"])
                if m and (m.group(1) or m.group(2)) == candidate["expected"]:
                    table = candidate
                    break
            if not table:
                continue
            match = table["answers"]
            texts = table.get("answerTexts") or {}
            if not match and not texts:
                continue
            num = None
            for app in row.get("appearances") or []:
                if app.get("questionNumber") is not None:
                    num = int(app["questionNumber"])
                    break
            if num is None:
                m = re.search(r"q(\d+)$", row["id"])
                num = int(m.group(1)) if m else None
            if num is None:
                continue
            if str(num) not in match and str(num) not in table.get("answerTexts", {}):
                continue
            if str(num) in texts:
                # Apply by option text: the only shape that survives a shuffled option order.
                want, hits = resolve_by_text(row, texts[str(num)])
                if want is None:
                    unresolved += 1
                    print(f"  UNRESOLVED {row['id']} q{num}: key text "
                          f"{texts[str(num)]!r} matched {hits} bank option(s); left as "
                          f"{row.get('answer', {}).get('optionId')}")
                    continue
            elif str(num) in match:
                want = match[str(num)]
            else:
                continue
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
    if unresolved:
        print(f"  {unresolved} question(s) covered by a key could not be matched by option "
              f"text and were left untouched")
    return fixed, same, unresolved


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
        fixed, same, unresolved = fix_answers(keys, check_only)
        print()
        print(f"{'would correct' if check_only else 'corrected'} {fixed} answers from the "
              f"official key ({same} already right, {unresolved} unresolvable)")
        if unresolved:
            # A key that covers a question but cannot be matched is a defect, not a skip.
            print("ERROR: some key entries did not match a bank option; fix the key's "
                  "answerTexts or the bank's options before trusting this cycle.")
            return 1

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

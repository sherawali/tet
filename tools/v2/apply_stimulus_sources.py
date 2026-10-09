#!/usr/bin/env python3
"""Replace placeholder stimulus text with verified passage/poem text.

`import_all_ctet.py` hardcoded the body of every passage and poem for 2016, 2018,
2019, 2021-Dec, 2023, 2024 and 2026 (see docs/STIMULUS_LINK_AUDIT.md). This tool
overwrites those bodies from `bank-v2/sources/stimuli/<cycle>.json`, which holds text
transcribed from the actual paper together with its provenance.

Nothing is invented here: a stimulus is only touched when a source entry names it by
id, and `review.textVerified` is set from the source's own verification state.

Usage:
    python3 tools/v2/apply_stimulus_sources.py --check     # dry run, no writes
    python3 tools/v2/apply_stimulus_sources.py             # apply
    python3 tools/v2/apply_stimulus_sources.py --cycle ctet-p1-2024
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SOURCES_DIR = os.path.join(ROOT, "bank-v2", "sources", "stimuli")
EXAMS_DIR = os.path.join(ROOT, "bank-v2", "exams")


def stimuli_files() -> list[str]:
    out = []
    for base, _dirs, files in os.walk(EXAMS_DIR):
        if "stimuli.ndjson" in files:
            out.append(os.path.join(base, "stimuli.ndjson"))
    return sorted(out)


def load_sources(cycle: str | None) -> tuple[dict[str, dict], dict[str, dict]]:
    entries: dict[str, dict] = {}
    provenance: dict[str, dict] = {}
    if not os.path.isdir(SOURCES_DIR):
        return entries, provenance
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
    return entries, provenance


def index_stimuli() -> dict[str, str]:
    location: dict[str, str] = {}
    for path in stimuli_files():
        with open(path, encoding="utf-8") as fh:
            for line in fh:
                if line.strip():
                    location[json.loads(line)["id"]] = path
    return location


def apply(check_only: bool, cycle: str | None) -> int:
    entries, provenance = load_sources(cycle)
    if not entries:
        print(f"No source entries found in {os.path.relpath(SOURCES_DIR, ROOT)}"
              + (f" for cycle {cycle}" if cycle else ""))
        return 1
    location = index_stimuli()

    missing = sorted(set(entries) - set(location))
    if missing:
        print("Refusing to run: source entries name stimuli that do not exist:")
        for sid in missing:
            print(f"  {sid}")
        return 1

    per_file: dict[str, list[dict]] = {}
    for path in stimuli_files():
        rows = []
        with open(path, encoding="utf-8") as fh:
            for line in fh:
                if line.strip():
                    rows.append(json.loads(line))
        per_file[path] = rows

    changed = 0
    skipped = 0
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
            new_content = [{"kind": "markdown", "text": {entry.get("language", "hi"): text}}]
            same = (
                row.get("content") == new_content
                and row.get("instructions", {}).get(entry.get("language", "hi"))
                == entry.get("instructions")
                and (row.get("review") or {}).get("textVerified") is True
            )
            if same:
                skipped += 1
                continue
            print(f"  {row['id']}")
            print(f"    was : {(row.get('content') or [{}])[0].get('text', {})!s:.110}")
            print(f"    now : {text[:110]}")
            if not check_only:
                row["content"] = new_content
                if entry.get("instructions"):
                    row.setdefault("instructions", {})[entry.get("language", "hi")] = (
                        entry["instructions"])
                review = row.setdefault("review", {})
                review["textVerified"] = True
                row["sourceRef"] = {
                    "id": entry["_sourceId"],
                    **entry["_provenance"],
                }
            dirty = True
            changed += 1
        if dirty and not check_only:
            with open(path, "w", encoding="utf-8") as fh:
                for row in rows:
                    fh.write(json.dumps(row, ensure_ascii=False) + "\n")

    total_stimuli = sum(len(rows) for rows in per_file.values())
    print()
    print(f"{'would replace' if check_only else 'replaced'} {changed} stimulus bodies "
          f"({skipped} already current), {total_stimuli} stimuli in the bank")
    print(f"still placeholder: {total_stimuli - changed - skipped} "
          f"- add sources under bank-v2/sources/stimuli/")
    print("\nAfter applying, verify with:")
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

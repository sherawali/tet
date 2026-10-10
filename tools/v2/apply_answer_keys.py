#!/usr/bin/env python3
"""Apply content-solved answer keys to bank-v2 (answer + appearances together).

Reads ``tools/v2/answer_rekey.json`` — a mapping ``{question_id: "a"|"b"|"c"|"d"}``
built by content-solving the questions whose keys were destroyed by the
importer default-``a`` bug — and writes every key to BOTH:

* ``bank-v2/exams/**/questions.ndjson`` → ``answer.optionId``
* ``bank-v2/paper-forms/**/appearances.ndjson`` → ``officialOptionId``

Usage:
    python tools/v2/apply_answer_keys.py [--dry-run]
"""
from __future__ import annotations

import argparse
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
BANK = REPO_ROOT / "bank-v2"
REKEY_PATH = Path(__file__).resolve().parent / "answer_rekey.json"


def load_ndjson(path: Path) -> list[dict]:
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def dump_ndjson(path: Path, rows: list[dict]) -> None:
    with path.open("w", encoding="utf-8") as handle:
        for row in rows:
            handle.write(json.dumps(row, ensure_ascii=False) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    rekey: dict[str, str] = json.loads(REKEY_PATH.read_text(encoding="utf-8"))
    valid = {"a", "b", "c", "d"}
    bad = {qid: opt for qid, opt in rekey.items() if opt not in valid}
    if bad:
        print(f"ERROR: invalid option ids in {REKEY_PATH.name}: {bad}")
        return 1

    # ---- questions ----
    seen: set[str] = set()
    changed = 0
    dist = defaultdict(Counter)
    for path in sorted(BANK.glob("exams/**/questions.ndjson")):
        rows = load_ndjson(path)
        dirty = False
        for row in rows:
            qid = row.get("id", "")
            if qid not in rekey:
                continue
            seen.add(qid)
            opt = rekey[qid]
            answer = row.setdefault("answer", {"kind": "single"})
            if answer.get("optionId") != opt:
                answer["optionId"] = opt
                answer.setdefault("kind", "single")
                dirty = True
                changed += 1
            paper = qid.rsplit("-q", 1)[0]
            dist[paper][opt] += 1
        if dirty and not args.dry_run:
            dump_ndjson(path, rows)

    missing = set(rekey) - seen
    if missing:
        print(f"ERROR: {len(missing)} rekey qids not found in bank: {sorted(missing)[:10]}")
        return 1

    # ---- appearances ----
    app_changed = 0
    for path in sorted(BANK.glob("paper-forms/**/appearances.ndjson")):
        rows = load_ndjson(path)
        dirty = False
        for row in rows:
            qid = row.get("questionId", "")
            if qid not in rekey:
                continue
            if row.get("officialOptionId") != rekey[qid]:
                row["officialOptionId"] = rekey[qid]
                dirty = True
                app_changed += 1
        if dirty and not args.dry_run:
            dump_ndjson(path, rows)

    print(f"rekey entries applied : {len(rekey)}")
    print(f"question answers set  : {changed}{' (dry-run)' if args.dry_run else ''}")
    print(f"appearances set       : {app_changed}{' (dry-run)' if args.dry_run else ''}")
    print("resulting per-paper option distribution (rekeyed questions):")
    for paper in sorted(dist):
        c = dist[paper]
        n = sum(c.values())
        top, topn = c.most_common(1)[0]
        flag = "  <-- over 60%" if topn / n > 0.60 else ""
        print(f"  {paper}: {dict(sorted(c.items()))} (top {top}={topn}/{n}){flag}")
    return 0


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.exit(main())

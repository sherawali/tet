#!/usr/bin/env python3
"""Diff bank-v2 answer keys against an official CBSE key grid.

The official CTET keys are published as option NUMBERS 1-4 per question number,
split by booklet part (MAIN = CDP/Math/EVS, 01-ENGLISH and 02-HINDI = the two
language sections). bank-v2 stores letters a-d per question id, so this maps
    cdp | mathematics | environmental-studies  -> MAIN
    lang1-en | lang2-en                        -> 01-ENGLISH
    lang1-hi | lang2-hi                        -> 02-HINDI
    lang*-sa                                   -> (not in the main key; skipped)
and compares letter<->number.

A mismatch is NOT automatically a bank error: bank option order can be shuffled
relative to the printed booklet, so every mismatch is printed with the bank's
own option texts for a content check. Only after that does it go into
answer_rekey.json.

Usage:
    python3 tools/v2/verify_against_official_key.py \
        tools/v2/official_keys/ctet-2018-paper1-set-I.json 2018-m
"""
from __future__ import annotations

import glob
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LETTER_TO_NUM = {"a": 1, "b": 2, "c": 3, "d": 4}
NUM_TO_LETTER = {v: k for k, v in LETTER_TO_NUM.items()}

SECTION_TO_PART = {
    "cdp": "MAIN",
    "mathematics": "MAIN",
    "environmental-studies": "MAIN",
    "lang1-en": "01-ENGLISH",
    "lang2-en": "01-ENGLISH",
    "lang1-hi": "02-HINDI",
    "lang2-hi": "02-HINDI",
}


def texts(node, out):
    if isinstance(node, dict):
        for k, v in node.items():
            if k == "text" and isinstance(v, dict):
                out.extend(s for s in v.values() if isinstance(s, str))
            else:
                texts(v, out)
    elif isinstance(node, list):
        for x in node:
            texts(x, out)


def flat(node) -> str:
    out: list[str] = []
    texts(node, out)
    return " ".join(out).replace("\n", " ").strip()


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    key = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    cycle = sys.argv[2]

    # official option id per question id, from appearances
    official: dict[str, str] = {}
    for p in glob.glob(str(ROOT / "bank-v2/paper-forms/**/appearances.ndjson"), recursive=True):
        for line in open(p, encoding="utf-8"):
            line = line.strip()
            if not line:
                continue
            r = json.loads(line)
            qid = r.get("questionId", "")
            if qid.startswith(f"ctet-p1-{cycle}-"):
                official[qid] = r.get("officialOptionId")

    matched = mismatched = skipped = 0
    drift = []
    rows = []
    for p in sorted(glob.glob(str(ROOT / "bank-v2/exams/ctet/paper-1/**/questions.ndjson"), recursive=True)):
        for line in open(p, encoding="utf-8"):
            line = line.strip()
            if not line:
                continue
            r = json.loads(line)
            qid = r["id"]
            if not qid.startswith(f"ctet-p1-{cycle}-"):
                continue
            rest = qid[len(f"ctet-p1-{cycle}-"):]
            sec, _, qno = rest.rpartition("-q")
            part = SECTION_TO_PART.get(sec)
            if part is None:
                skipped += 1
                continue
            grid = key.get(part, {})
            want_num = grid.get(str(int(qno)))
            if want_num is None:
                skipped += 1
                continue
            got = r.get("answer", {}).get("optionId")
            got_num = LETTER_TO_NUM.get(got)
            if want_num == 9:
                matched += 1
                continue
            if got_num == want_num:
                matched += 1
            else:
                mismatched += 1
                rows.append((qid, sec, int(qno), got, NUM_TO_LETTER.get(want_num, str(want_num)),
                             flat(r.get("prompt", [])),
                             [(o["id"], flat(o.get("content", []))) for o in r.get("options", [])]))
            # question.answer and appearance.officialOptionId must agree
            if official.get(qid) and official[qid] != got:
                drift.append((qid, got, official[qid]))

    print(f"cycle {cycle}: matched {matched}, mismatched {mismatched}, "
          f"skipped {skipped} (Sanskrit / not in this key)")
    if drift:
        print(f"\n!! {len(drift)} question(s) where answer.optionId != appearance.officialOptionId:")
        for qid, a, b in drift[:20]:
            print(f"   {qid}: question={a} appearance={b}")
    if rows:
        print(f"\n=== {len(rows)} MISMATCH(ES) — content-check before re-keying ===")
        for qid, sec, qno, got, want, prompt, opts in rows:
            print(f"\n{qid}  [{sec} q{qno}]  bank={got}  official={want}")
            print(f"  prompt: {prompt[:150]}")
            for oid, txt in opts:
                mark = " <-bank" if oid == got else (" <-official" if oid == want else "")
                print(f"    ({LETTER_TO_NUM[oid]}) {oid}: {txt[:95]}{mark}")
    return 0


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.exit(main())

#!/usr/bin/env python3
"""Passage/poem integrity tracker — answers "kitna hua, kitna bacha" exactly.

Scans every stimulus in bank-v2 plus every language question, and classifies
each comprehension/poem group into one status. Unlike a pure length heuristic
this carries a curated status table, because a short passage is only a problem
when the question group behind it is long:

  * CTET prose groups carry 7-9 questions -> a real passage runs ~900-4000
    chars. Anything under ~600 cannot answer them.
  * CTET Sanskrit गद्यांश are genuinely short in the official papers, so they
    are judged separately and only flagged when unverifiable.
  * UTET groups carry 2-5 questions -> ~570-1600 chars is normal.

Statuses
  DONE          authentic text in place and checked against the questions
  FABRICATED    generic moral-essay invented by import_all_ctet.py; no proper
                nouns, nothing the questions refer to -> replace entirely
  TRUNCATED     real passage but cut short at import -> complete it
  PROVISIONAL   reconstructed from question constraints, not the original text
  MISSING       question group exists but there is no stimulus record at all
  UNVERIFIED    plausible length, source not yet confirmed against a paper

Run: python3 tools/v2/audit_passage_gaps.py [--md]
"""
from __future__ import annotations

import collections
import glob
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

# ---------------------------------------------------------------- curated state
# Kept explicit on purpose: the ledger in answer_rekey_notes.md is the argument,
# this table is the verdict. Update it in the same commit as any restoration.
STATUS: dict[str, str] = {
    # CTET Feb 2016
    "ctet-p1-2016-stimulus-en-pr-121": "TRUNCATED",   # water/60% — real, cut
    "ctet-p1-2016-stimulus-en-pr-143": "TRUNCATED",   # Raja Ram Mohan Roy — real, cut
    "ctet-p1-2016-stimulus-hi-po-91": "UNVERIFIED",
    "ctet-p1-2016-stimulus-hi-pr-112": "TRUNCATED",   # माँ/रमेश dialogue — real, cut
    # CTET 09 Dec 2018 — English closed by pass 4
    "ctet-p1-2018-stimulus-en-pr-91": "DONE",         # Castles
    "ctet-p1-2018-stimulus-en-po-100": "DONE",        # Blake, The Little Black Boy
    "ctet-p1-2018-stimulus-en-pr-121": "DONE",        # necessity is the mother of invention
    "ctet-p1-2018-stimulus-en-pr-129": "DONE",        # Kevlar / Stephanie Kwolek
    "ctet-p1-2018-stimulus-hi-po-91": "UNVERIFIED",
    "ctet-p1-2018-stimulus-hi-pr-97": "DONE",          # गीत-कविता अनुच्छेद (pass 6)
    "ctet-p1-2018-stimulus-sa-po-100": "UNVERIFIED",
    # CTET 08 Dec 2019
    "ctet-p1-2019-stimulus-en-pr-91": "TRUNCATED",    # Kangri Karchok — real, cut
    "ctet-p1-2019-stimulus-en-po-100": "UNVERIFIED",  # Blake 'Night'; handover claims Tennyson
    "ctet-p1-2019-stimulus-en-pr-121": "FABRICATED",
    "ctet-p1-2019-stimulus-en-pr-129": "FABRICATED",
    "ctet-p1-2019-stimulus-hi-po-100": "UNVERIFIED",
    "ctet-p1-2019-stimulus-hi-pr-91": "FABRICATED",
    "ctet-p1-2019-stimulus-hi-pr-121": "TRUNCATED",   # पाठ्यक्रम/कक्षाक्रम — real NCF text, cut
    "ctet-p1-2019-stimulus-hi-pr-129": "FABRICATED",
    "ctet-p1-2019-stimulus-sa-po-100": "UNVERIFIED",
    "ctet-p1-2019-stimulus-sa-pr-91": "FABRICATED",   # needs नर्मदा/अमरकण्टक गद्यांश
    "ctet-p1-2019-stimulus-sa-pr-121": "FABRICATED",   # needs दण्डचतुष्टय (bundle of sticks) गद्यांश
    "ctet-p1-2019-stimulus-sa-pr-129": "FABRICATED",   # needs चाणक्य/कम्बल गद्यांश
    # CTET 31 Jan 2021 / 2020 cycle — imported from a clean source
    "ctet-p1-2020-i-language-1-en-q091-prose": "DONE",
    "ctet-p1-2020-i-language-1-en-q100-poem": "DONE",
    "ctet-p1-2020-i-language-1-hi-q091-prose": "DONE",
    "ctet-p1-2020-i-language-1-hi-q100-poem": "DONE",
    "ctet-p1-2020-i-language-1-sa-q091-prose": "DONE",
    "ctet-p1-2020-i-language-1-sa-q100-poem": "DONE",
    "ctet-p1-2020-i-language-2-en-q121-prose": "DONE",
    "ctet-p1-2020-i-language-2-en-q129-prose": "DONE",
    "ctet-p1-2020-i-language-2-hi-q121-prose": "DONE",
    "ctet-p1-2020-i-language-2-hi-q129-prose": "DONE",
    "ctet-p1-2020-i-language-2-sa-q121-prose": "DONE",
    "ctet-p1-2020-i-language-2-sa-q129-prose": "DONE",
    "ctet-p1-2020-i-mathematics-q041-table": "UNVERIFIED",
    # CTET 16 Dec 2021
    "ctet-p1-2021-dec-stimulus-en-pr-91": "TRUNCATED",   # Delhi/tonga — real, cut
    "ctet-p1-2021-dec-stimulus-en-po-100": "UNVERIFIED", # Lucy Larcom 'The Tree That Never Had To Fight'
    "ctet-p1-2021-dec-stimulus-en-pr-121": "TRUNCATED",  # Himalayan ice — real, cut
    "ctet-p1-2021-dec-stimulus-en-pr-129": "TRUNCATED",  # Ruskin Bond, trees — real, cut
    "ctet-p1-2021-dec-stimulus-hi-pr-91": "TRUNCATED",   # शहर/खण्डहर — real, cut
    "ctet-p1-2021-dec-stimulus-hi-po-100": "UNVERIFIED",
    "ctet-p1-2021-dec-stimulus-hi-pr-121": "FABRICATED",
    "ctet-p1-2021-dec-stimulus-hi-pr-129": "TRUNCATED",  # Krishnamurti, शिक्षा का सार — real, cut
    "ctet-p1-2021-dec-stimulus-sa-pr-121": "FABRICATED",   # needs नागार्जुन/युवकौ गद्यांश
    "ctet-p1-2021-dec-stimulus-sa-pr-129": "FABRICATED",   # needs रानाडे गद्यांश
    # CTET 20 Aug 2023
    "ctet-p1-2023-stimulus-en-po-91": "UNVERIFIED",   # Herrick 'Gather ye rosebuds'
    "ctet-p1-2023-stimulus-en-pr-97": "FABRICATED",
    "ctet-p1-2023-stimulus-hi-po-91": "UNVERIFIED",
    "ctet-p1-2023-stimulus-hi-pr-97": "FABRICATED",
    "ctet-p1-2023-stimulus-sa-po-100": "UNVERIFIED",
    "ctet-p1-2023-stimulus-sa-pr-121": "FABRICATED",   # needs सिद्धार्थ/देवदत्त गद्यांश
    "ctet-p1-2023-stimulus-sa-pr-129": "FABRICATED",   # needs मृगेन्द्र/सिंह गद्यांश
    # CTET 21 Jan 2024
    "ctet-p1-2024-stimulus-en-pr-91": "FABRICATED",
    "ctet-p1-2024-stimulus-en-po-100": "TRUNCATED",   # Wordsworth daffodils, 1 stanza only
    "ctet-p1-2024-stimulus-en-pr-121": "FABRICATED",
    "ctet-p1-2024-stimulus-en-pr-129": "FABRICATED",
    "ctet-p1-2024-stimulus-hi-pr-91": "FABRICATED",
    "ctet-p1-2024-stimulus-hi-po-100": "DONE",        # आज तिरंगा फहराता है (pass 2)
    "ctet-p1-2024-stimulus-hi-pr-121": "FABRICATED",
    "ctet-p1-2024-stimulus-hi-pr-129": "FABRICATED",
    "ctet-p1-2024-stimulus-sa-po-100": "UNVERIFIED",
    "ctet-p1-2024-stimulus-sa-pr-91": "FABRICATED",   # needs योग/मोक्ष गद्यांश
    "ctet-p1-2024-stimulus-sa-pr-121": "FABRICATED",   # needs सामवेद/योगदर्शन गद्यांश
    "ctet-p1-2024-stimulus-sa-pr-129": "FABRICATED",   # needs साङ्ख्ययोग/हठयोग गद्यांश
    # CTET 08 Feb 2026 — pass 3 restored most of it
    "ctet-p1-2026-stimulus-en-pr-91": "DONE",         # Tarawati/Roopa
    "ctet-p1-2026-stimulus-en-po-100": "DONE",        # Kalahandi
    "ctet-p1-2026-stimulus-en-pr-121": "PROVISIONAL", # tea-seller reconstruction
    "ctet-p1-2026-stimulus-en-pr-129": "DONE",        # tribes/patriarch (git leak)
    "ctet-p1-2026-stimulus-hi-pr-91": "FABRICATED",   # needs the Hindi Tarawati
    "ctet-p1-2026-stimulus-hi-po-100": "DONE",        # जीवन अस्थिर अनजाने ही
    "ctet-p1-2026-stimulus-hi-pr-121": "PROVISIONAL", # लीडर/संघर्ष reconstruction
    "ctet-p1-2026-stimulus-hi-pr-129": "DONE",        # हिंदी बनाम स्थानीय भाषाएँ (git leak)
}

# Question groups with NO stimulus record at all. Keyed by (dir, qNo range).
MISSING_GROUPS = [
    ("ctet/paper-1/language-1/hindi", "ctet-p1-2016-i-lang1-hi", 97, 105,
     "2016 Lang-I Hindi गद्यांश — no stimulus id was ever created"),
    ("ctet/paper-1/language-2/english", "ctet-p1-2016-i-lang2-en", 128, 135,
     "2016 Lang-II English second passage — no stimulus id was ever created"),
]

# UTET passages are confirmed authentic by the owner: they came from his own
# paper OCR (UTET 2024/2025) and from the UTET 2026 paper he sat on 29 Sep 2026.
# Closed 2026-10-10 ("utet k para shi hai aur inko baad mai dekhenge") - out of
# scope for the CTET restoration work, revisit only if he asks.
UTET_STATUS = "DONE"

# Stimuli DELETED by repair_unlink_pass5.py: the official booklet has no passage
# at these ranges (CTET Language-II 121-150 is भाषा-शास्त्र/pedagogy + grammar in
# these cycles), so the fabricated essay was removed and the questions became
# standalone. Value = number of questions freed. Kept here so the tracker still
# reports them as closed instead of silently forgetting them.
NO_PASSAGE_REMOVED: dict[str, int] = {
    "ctet-p1-2016-stimulus-sa-pr-121": 8,
    "ctet-p1-2016-stimulus-sa-pr-129": 7,
    "ctet-p1-2018-stimulus-sa-pr-91": 9,
    "ctet-p1-2018-stimulus-sa-pr-121": 8,
    "ctet-p1-2018-stimulus-sa-pr-129": 7,
    "ctet-p1-2018-stimulus-hi-pr-121": 8,
    "ctet-p1-2018-stimulus-hi-pr-129": 7,
    "ctet-p1-2023-stimulus-sa-pr-91": 9,
    "ctet-p1-2023-stimulus-en-pr-121": 8,
    "ctet-p1-2023-stimulus-en-pr-129": 7,
    "ctet-p1-2023-stimulus-hi-pr-121": 8,
    "ctet-p1-2023-stimulus-hi-pr-129": 7,
}


def textlen(node, locs=None) -> int:
    tot = 0
    if isinstance(node, dict):
        for k, v in node.items():
            if k == "text" and isinstance(v, dict):
                for L, s in v.items():
                    if isinstance(s, str) and (locs is None or L in locs):
                        tot += len(s)
            else:
                tot += textlen(v, locs)
    elif isinstance(node, list):
        for x in node:
            tot += textlen(x, locs)
    return tot


def main() -> int:
    md = "--md" in sys.argv

    num: dict[str, int] = {}
    for p in glob.glob(str(ROOT / "bank-v2/paper-forms/**/appearances.ndjson"), recursive=True):
        for line in open(p, encoding="utf-8"):
            line = line.strip()
            if line:
                r = json.loads(line)
                num[r["questionId"]] = r.get("questionNumber")

    linked: dict[str, list[int]] = collections.defaultdict(list)
    unlinked: list[str] = []
    for p in sorted(glob.glob(str(ROOT / "bank-v2/exams/**/questions.ndjson"), recursive=True)):
        lang = "/language-" in p
        for line in open(p, encoding="utf-8"):
            line = line.strip()
            if not line:
                continue
            r = json.loads(line)
            s = r.get("stimulusId")
            n = num.get(r["id"])
            if s:
                linked[s].append(n if n is not None else -1)
                continue
            if not lang or n is None:
                continue
            slot = r.get("languageSlot")
            inrange = (91 <= n <= 105) if slot == 1 else (121 <= n <= 135)
            if inrange:
                unlinked.append(r["id"])

    stimuli = {}
    for p in sorted(glob.glob(str(ROOT / "bank-v2/exams/**/stimuli.ndjson"), recursive=True)):
        for line in open(p, encoding="utf-8"):
            line = line.strip()
            if not line:
                continue
            r = json.loads(line)
            stimuli[r["id"]] = r

    rows = []
    for sid, r in sorted(stimuli.items()):
        L = textlen(r.get("content", []))
        ns = sorted(x for x in linked.get(sid, []) if x > 0)
        rng = f"{ns[0]}-{ns[-1]}" if ns else "-"
        st = STATUS.get(sid, UTET_STATUS if sid.startswith("utet-") else "UNVERIFIED")
        rows.append((st, sid, r.get("type"), L, len(ns), rng))

    counts = collections.Counter(r[0] for r in rows)
    qcounts = collections.Counter()
    for st, sid, _t, _L, n, _r in rows:
        qcounts[st] += n
    for _d, _pfx, a, b, _why in MISSING_GROUPS:
        counts["MISSING"] += 1
        qcounts["MISSING"] += (b - a + 1)
    counts["NO-PASSAGE"] = len(NO_PASSAGE_REMOVED)
    qcounts["NO-PASSAGE"] = sum(NO_PASSAGE_REMOVED.values())

    # drift guard: the curated table must not keep ids the bank no longer has
    stale = sorted(set(STATUS) - set(stimuli))
    if stale:
        print(f"WARNING: {len(stale)} STATUS entries no longer exist in the bank "
              f"(move them to NO_PASSAGE_REMOVED or drop them):")
        for s in stale:
            print("   ", s)

    order = ["DONE", "NO-PASSAGE", "TRUNCATED", "FABRICATED", "PROVISIONAL", "MISSING", "UNVERIFIED"]
    total = sum(counts.values())
    totalq = sum(qcounts.values())

    if md:
        print("| status | groups | questions |")
        print("|---|---:|---:|")
        for st in order:
            print(f"| {st} | {counts.get(st,0)} | {qcounts.get(st,0)} |")
        print(f"| **total** | **{total}** | **{totalq}** |")
        return 0

    print("=" * 78)
    print("passage / poem integrity tracker")
    print("=" * 78)
    live = total - counts.get("NO-PASSAGE", 0)
    liveq = totalq - qcounts.get("NO-PASSAGE", 0)
    for st in order:
        pct = 100.0 * counts.get(st, 0) / live if (live and st != "NO-PASSAGE") else 0
        extra = f"  ({pct:4.1f}% of live groups)" if st != "NO-PASSAGE" else "  (closed — stimuli deleted)"
        print(f"  {st:12s} {counts.get(st,0):3d} groups  {qcounts.get(st,0):4d} questions{extra}")
    print(f"  {'LIVE TOTAL':12s} {live:3d} groups  {liveq:4d} questions   "
          f"(+{counts.get('NO-PASSAGE',0)} closed / {qcounts.get('NO-PASSAGE',0)}q)")

    ctet_open = [r for r in rows if r[1].startswith("ctet-") and r[0] in
                 ("FABRICATED", "TRUNCATED", "PROVISIONAL")]
    print()
    print(f"CTET groups needing text work: {len(ctet_open)} "
          f"({sum(r[4] for r in ctet_open)} questions) + {len(MISSING_GROUPS)} missing groups")
    for st in ("FABRICATED", "TRUNCATED", "PROVISIONAL"):
        sub = [r for r in ctet_open if r[0] == st]
        if not sub:
            continue
        print(f"\n  --- {st} ---")
        for _st, sid, typ, L, n, rng in sub:
            print(f"    {sid:46s} {str(typ):5s} {L:5d}c  q{rng} ({n})")

    print("\n  --- MISSING (no stimulus record at all) ---")
    for d, _pfx, a, b, why in MISSING_GROUPS:
        print(f"    {d:44s} q{a}-{b} ({b-a+1})  {why}")
    if unlinked:
        print(f"    ({len(unlinked)} unlinked language questions detected: "
              f"{unlinked[0]} … {unlinked[-1]})")

    sa = [r for r in rows if "-sa-" in r[1] and r[1].startswith("ctet-") and "2020-i" not in r[1]]
    print(f"\n  --- Sanskrit groups not yet sourced: {len(sa)} "
          f"({sum(r[4] for r in sa)} questions) — CTET Sanskrit passages are genuinely short,")
    print("      so these need a paper check before being called fabricated.")
    return 0


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.exit(main())

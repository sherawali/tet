#!/usr/bin/env python3
"""Cleanup pass 5 — delete fabricated passages that were bolted onto question
groups which never had a passage in the real paper.

Discovery
---------
`import_all_ctet.py` created a prose stimulus for every fixed question range
(91-99, 121-128, 129-135, ...) whether or not the official booklet had a
गद्यांश there. For CTET Language-II the 121-150 block is भाषा-शास्त्र /
language pedagogy plus grammar in most cycles — there is no passage at all — so
the importer invented a generic moral essay and stapled it to eight
standalone pedagogy questions.

That is worse than a missing passage: the app renders a fabricated paragraph
above questions like "वाइगोत्स्की ने भाषा-विकास का ___ परिप्रेक्ष्य प्रस्तुत
किया" or "Top-down means 'attend to the overall meaning'. What does
'bottom-up' mean?", and a learner then hunts for an answer in text that has
nothing to do with the question.

Verified group by group: every question in the 12 groups below is answerable
from its own stem + options, and not one stem refers back to a passage
(no 'अनुच्छेद', 'गद्यांश', 'the passage', 'उपर्युक्त' …). The script re-asserts
that before touching anything, so a future edit that links a real
passage-dependent question into one of these groups fails loudly.

Groups unlinked (93 questions):
  2016 Lang-II Sanskrit  q121-128, q129-135   (भाषा-शास्त्र)
  2018 Lang-I  Sanskrit  q091-099             (Cramming / Inductive method …)
  2018 Lang-II Sanskrit  q121-128, q129-135   (भाषा-शास्त्र)
  2018 Lang-II Hindi     q121-128, q129-135   (भाषा-शास्त्र)
  2023 Lang-I  Sanskrit  q091-099             (भाषा-शास्त्र)
  2023 Lang-II English   q121-128, q129-135   (TPR / formative evaluation …)
  2023 Lang-II Hindi     q121-128, q129-135   (टीपीआर / रचनात्मक मूल्यांकन …)

Run: python3 tools/v2/repair_unlink_pass5.py
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BANK = ROOT / "bank-v2" / "exams" / "ctet" / "paper-1"

# stimulus id -> (questions file, why there is no passage)
UNLINK: dict[str, tuple[Path, str]] = {
    "ctet-p1-2016-stimulus-sa-pr-121": (
        BANK / "language-2/sanskrit", "2016 Lang-II Sanskrit 121-128 = भाषा-शास्त्र"),
    "ctet-p1-2016-stimulus-sa-pr-129": (
        BANK / "language-2/sanskrit", "2016 Lang-II Sanskrit 129-135 = भाषा-शास्त्र"),
    "ctet-p1-2018-stimulus-sa-pr-91": (
        BANK / "language-1/sanskrit", "2018 Lang-I Sanskrit 091-099 = भाषा-शास्त्र"),
    "ctet-p1-2018-stimulus-sa-pr-121": (
        BANK / "language-2/sanskrit", "2018 Lang-II Sanskrit 121-128 = भाषा-शास्त्र"),
    "ctet-p1-2018-stimulus-sa-pr-129": (
        BANK / "language-2/sanskrit", "2018 Lang-II Sanskrit 129-135 = भाषा-शास्त्र"),
    "ctet-p1-2018-stimulus-hi-pr-121": (
        BANK / "language-2/hindi", "2018 Lang-II Hindi 121-128 = भाषा-शास्त्र"),
    "ctet-p1-2018-stimulus-hi-pr-129": (
        BANK / "language-2/hindi", "2018 Lang-II Hindi 129-135 = भाषा-शास्त्र"),
    "ctet-p1-2023-stimulus-sa-pr-91": (
        BANK / "language-1/sanskrit", "2023 Lang-I Sanskrit 091-099 = भाषा-शास्त्र"),
    "ctet-p1-2023-stimulus-en-pr-121": (
        BANK / "language-2/english", "2023 Lang-II English 121-128 = language pedagogy"),
    "ctet-p1-2023-stimulus-en-pr-129": (
        BANK / "language-2/english", "2023 Lang-II English 129-135 = language pedagogy"),
    "ctet-p1-2023-stimulus-hi-pr-121": (
        BANK / "language-2/hindi", "2023 Lang-II Hindi 121-128 = भाषा-शास्त्र"),
    "ctet-p1-2023-stimulus-hi-pr-129": (
        BANK / "language-2/hindi", "2023 Lang-II Hindi 129-135 = भाषा-शास्त्र"),
}

# A stem carrying any of these refers back to a passage and must NOT be unlinked.
PASSAGE_MARKER = re.compile(
    r"(the passage|in the passage|as used in the passage|according to the passage|"
    r"the poem|the author|the writer|Paragraph \d|"
    r"अनुच्छेद|गद्यांश|पद्यांश|उपर्युक्त|उक्त गद्यांश|पाठ के अनुसार|"
    r"अनुच्छेदे|गद्यांशे)",
    re.IGNORECASE,
)

failures: list[str] = []
changed: list[str] = []
unlinked_questions: list[str] = []


def load(path: Path) -> list[dict]:
    return [json.loads(l) for l in path.read_text(encoding="utf-8").splitlines() if l.strip()]


def save(path: Path, rows: list[dict]) -> None:
    path.write_text("\n".join(json.dumps(r, ensure_ascii=False) for r in rows) + "\n", encoding="utf-8")
    changed.append(str(path.relative_to(ROOT)))


def prompt_text(rec: dict) -> str:
    out: list[str] = []

    def walk(node):
        if isinstance(node, dict):
            for k, v in node.items():
                if k == "text" and isinstance(v, dict):
                    out.extend(s for s in v.values() if isinstance(s, str))
                else:
                    walk(v)
        elif isinstance(node, list):
            for x in node:
                walk(x)

    walk(rec.get("prompt", []))
    return " ".join(out)


# ---------------------------------------------------------------- load & assert
qfiles = sorted({d / "questions.ndjson" for d, _ in UNLINK.values()})
sfiles = sorted({d / "stimuli.ndjson" for d, _ in UNLINK.values()})

qstore: dict[Path, list[dict]] = {p: load(p) for p in qfiles}
sstore: dict[Path, list[dict]] = {p: load(p) for p in sfiles}

present = {s["id"] for rows in sstore.values() for s in rows}
for sid in UNLINK:
    if sid not in present:
        failures.append(f"stimulus already gone (re-run?): {sid}")

for sid, (d, _why) in UNLINK.items():
    for row in qstore[d / "questions.ndjson"]:
        if row.get("stimulusId") != sid:
            continue
        txt = prompt_text(row)
        if PASSAGE_MARKER.search(txt):
            failures.append(
                f"REFUSING to unlink {row['id']}: stem still refers to a passage -> {txt[:120]!r}"
            )

if failures:
    print("FAILURES (nothing written):")
    for f in failures:
        print("  -", f)
    sys.exit(1)

# ---------------------------------------------------------------- apply
by_stim: dict[str, list[str]] = {}
for sid, (d, _why) in UNLINK.items():
    qpath = d / "questions.ndjson"
    by_stim[sid] = []
    for row in qstore[qpath]:
        if row.get("stimulusId") == sid:
            by_stim[sid].append(row["id"])
            row.pop("stimulusId", None)
            unlinked_questions.append(row["id"])

for sid in UNLINK:
    for p, rows in sstore.items():
        sstore[p] = [r for r in rows if r["id"] != sid]

for p, rows in qstore.items():
    save(p, rows)
for p, rows in sstore.items():
    save(p, rows)

print(f"Pass 5: removed {len(UNLINK)} fabricated stimuli, unlinked {len(unlinked_questions)} questions.")
per_group = {sid: sum(1 for q in unlinked_questions if q in by_stim[sid]) for sid in UNLINK}
for sid, (_d, why) in sorted(UNLINK.items()):
    print(f"  - {sid:42s} {per_group[sid]:2d}q  {why}")
print("files written:")
for c in sorted(set(changed)):
    print("  wrote", c)

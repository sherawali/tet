#!/usr/bin/env python3
"""Enforce the stimulus-group contract: a passage/poem and all of its questions
are one indivisible unit, everywhere they are used.

Rule set
--------
G1  Every question with a `stimulusId` belongs to that stimulus's group; its group
    id is the stimulus id.
G2  A question's group and its stimulus agree on exam, paper, section, language and
    language slot. A passage can never be shared by another slot/language.
G3  The group size equals the stimulus `minimumQuestions`, and the question numbers
    parsed from the ids cover exactly the range announced in the instructions.
G4  `selectionPolicy` is `atomic`, so no selector may take the passage without its
    questions or the questions without the passage.
G5  Every group appears in exactly one section database, and the block is contiguous
    in the paper (no other question sits between the first and last member).

Usage:
    python3 tools/v2/validate_stimulus_groups.py            # exit 1 on any violation
    python3 tools/v2/validate_stimulus_groups.py --verbose
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

NUM_RE = re.compile(r"q(\d{3})(?!\d)")
RANGE_RE = re.compile(r"\d{1,3}\s*(?:\u2013|\u2014|-|to|\u0938\u0947)\s*\d{1,3}")


def load_ndjson(path: str) -> list[dict]:
    if not os.path.exists(path):
        return []
    with open(path, encoding="utf-8") as fh:
        return [json.loads(line) for line in fh if line.strip()]


def text_of(value, lang: str | None = None) -> str:
    if isinstance(value, dict):
        if lang and lang in value:
            return str(value[lang])
        for key in ("hi", "en", "sa", "ur"):
            if key in value:
                return str(value[key])
        return " ".join(str(v) for v in value.values())
    return "" if value is None else str(value)


def section_dirs() -> list[tuple[str, str, str, str]]:
    out = []
    for exam in sorted(os.listdir(EXAMS_DIR)):
        epath = os.path.join(EXAMS_DIR, exam)
        if not os.path.isdir(epath):
            continue
        for paper in sorted(os.listdir(epath)):
            ppath = os.path.join(epath, paper)
            if not os.path.isdir(ppath):
                continue
            for sec in sorted(os.listdir(ppath)):
                spath = os.path.join(ppath, sec)
                if os.path.exists(os.path.join(spath, "questions.ndjson")):
                    out.append((exam, paper, sec, spath))
                    continue
                for lang in sorted(os.listdir(spath)):
                    lpath = os.path.join(spath, lang)
                    if os.path.exists(os.path.join(lpath, "questions.ndjson")):
                        out.append((exam, paper, f"{sec}/{lang}", lpath))
    return out


def cycle_of(ident: str) -> str:
    """Cycle label of a question/stimulus id, e.g. ctet-p1-2021-dec-... -> 2021-dec."""
    parts = ident.split("-")
    for i, part in enumerate(parts):
        if part == "p1" and i + 1 < len(parts):
            return parts[i + 1]
    return "unknown"


def qnum(qid: str) -> int | None:
    m = NUM_RE.search(qid)
    return int(m.group(1)) if m else None


def validate(verbose: bool = False) -> tuple[list[str], dict]:
    errors: list[str] = []
    stats = dict(groups=0, questions=0, sections=0)
    seen_stimulus: dict[str, str] = {}

    for exam, paper, section, path in section_dirs():
        stats["sections"] += 1
        stimuli = {s["id"]: s for s in load_ndjson(os.path.join(path, "stimuli.ndjson"))}
        questions = load_ndjson(os.path.join(path, "questions.ndjson"))

        for sid, where in seen_stimulus.items():
            if sid in stimuli:
                errors.append(f"[G1] stimulus {sid} exists in both {where} and {section}")
        seen_stimulus.update({sid: section for sid in stimuli})

        groups: dict[str, list[dict]] = defaultdict(list)
        for q in questions:
            gid = q.get("groupId") or q.get("stimulusId")
            if not gid:
                continue
            stats["questions"] += 1
            if q.get("groupId") and q.get("stimulusId") and q["groupId"] != q["stimulusId"]:
                errors.append(f"[G1] {q['id']}: groupId {q['groupId']} != stimulusId "
                              f"{q['stimulusId']}")
            if gid not in stimuli:
                errors.append(f"[G1] {q['id']}: group {gid} has no stimulus in {section}")
                continue
            stim = stimuli[gid]
            for field in ("exam", "paper", "section", "language", "languageSlot"):
                if field in stim and field in q and stim[field] != q[field]:
                    errors.append(f"[G2] {q['id']}: {field} {q[field]!r} != stimulus "
                                  f"{stim[field]!r}")
            if stim.get("selectionPolicy") != "atomic":
                errors.append(f"[G4] {gid}: selectionPolicy is "
                              f"{stim.get('selectionPolicy')!r}, expected 'atomic'")
            groups[gid].append(q)

        for sid, stim in stimuli.items():
            members = groups.get(sid, [])
            stats["groups"] += 1
            min_q = stim.get("minimumQuestions")
            if isinstance(min_q, int) and len(members) != min_q:
                errors.append(f"[G3] {sid}: {len(members)} questions but "
                              f"minimumQuestions={min_q}")
            instr = text_of(stim.get("instructions"))
            nums = sorted(n for n in (qnum(q["id"]) for q in members) if n is not None)
            m = RANGE_RE.search(instr)
            if m and nums:
                low, high = (int(x) for x in re.findall(r"\d{1,3}", m.group(0))[:2])
                expected = set(range(low, high + 1))
                if set(nums) != expected:
                    errors.append(f"[G3] {sid}: instructions say {m.group(0)} but the group "
                                  f"holds {nums}")
            if not members:
                errors.append(f"[G3] {sid}: stimulus has no question - it would show up "
                              f"alone in the app")
            if verbose and members:
                print(f"  {section:22} {sid:46} {len(members)} questions "
                      f"({nums[0]}-{nums[-1]}) policy={stim.get('selectionPolicy')}")

        # G5: inside one cycle + language slot the block must be contiguous in
        # paper order. Question numbers repeat across cycles and between slot 1/2,
        # so contiguity only means anything within the same cycle and slot.
        by_scope: dict[tuple, list[tuple[int, str]]] = defaultdict(list)
        for q in questions:
            number = qnum(q["id"])
            if number is None:
                continue
            by_scope[(cycle_of(q["id"]), q.get("languageSlot"))].append(
                (number, q.get("groupId") or q.get("stimulusId") or ""))
        for gid, members in groups.items():
            own = sorted(qnum(q["id"]) for q in members if qnum(q["id"]) is not None)
            if not own:
                continue
            scope = (cycle_of(gid), members[0].get("languageSlot"))
            between = sorted({
                n for n, g in by_scope.get(scope, [])
                if own[0] <= n <= own[-1] and g != gid
            })
            if between:
                errors.append(f"[G5] {gid}: questions {between} sit inside the block "
                              f"{own[0]}-{own[-1]} but belong to another group")

    return errors, stats


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--verbose", action="store_true", help="list every group")
    args = ap.parse_args()

    errors, stats = validate(args.verbose)
    print(f"sections={stats['sections']} stimulus-groups={stats['groups']} "
          f"grouped-questions={stats['questions']}")
    if errors:
        print(f"\n{len(errors)} violation(s):")
        for e in errors:
            print("  " + e)
        return 1
    print("Stimulus groups are atomic and internally consistent.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

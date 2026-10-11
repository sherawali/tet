#!/usr/bin/env python3
"""Hold back question groups whose passage is fabricated, without deleting anything.

A CTET गद्यांश group is unanswerable when its stimulus text was invented at import
time: the student reads one passage and the questions ask about a different one
(`2019-sa-pr-91` carries a desert-traveller story while its nine questions ask
about नर्मदा / अमरकण्टक / डिण्डोरी). Shipping that is worse than shipping less.

This flips `status` to `"draft"` on the whole group - the stimulus and every
question linked to it - so `build_app_db.py` leaves it out of the app database
and the CDN packs. Nothing is removed from `bank-v2/`: restoring the real
passage and running `--restore` brings the group straight back, and because pack
ids are content-hashed the app picks it up on its next sync with no app update.

    python3 tools/v2/quarantine_bad_passages.py --dry-run
    python3 tools/v2/quarantine_bad_passages.py
    python3 tools/v2/quarantine_bad_passages.py --restore <stimulus-id> [...]
    python3 tools/v2/quarantine_bad_passages.py --restore-all
"""

from __future__ import annotations

import json
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from audit_passage_gaps import STATUS  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parents[2]
BANK = REPO_ROOT / "bank-v2"

# Only FABRICATED groups are held back. TRUNCATED passages are real but short,
# UNVERIFIED poems look authentic, PROVISIONAL ones are plausible - those stay
# published until they are actually fixed.
QUARANTINE_STATUSES = {"FABRICATED"}


def _ndjson_files(name: str) -> list[Path]:
    return sorted(BANK.rglob(name))


def _read(path: Path) -> list[tuple[str, dict]]:
    out: list[tuple[str, dict]] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.strip():
            out.append((line, json.loads(line)))
    return out


def _write(path: Path, records: list[dict]) -> None:
    body = "".join(
        json.dumps(rec, ensure_ascii=False) + "\n" for rec in records
    )
    path.write_text(body, encoding="utf-8")


def _targets() -> set[str]:
    return {sid for sid, status in STATUS.items() if status in QUARANTINE_STATUSES}


def main(argv: list[str]) -> int:
    dry = "--dry-run" in argv
    restore_all = "--restore-all" in argv
    restore_ids: set[str] = set()
    if "--restore" in argv:
        i = argv.index("--restore")
        restore_ids = {a for a in argv[i + 1:] if not a.startswith("--")}

    targets = _targets()
    mode = "quarantine"
    if restore_all:
        # Everything currently held back, stimuli first so each group returns whole.
        targets = set()
        for path in _ndjson_files("stimuli.ndjson"):
            for _raw, rec in _read(path):
                if rec.get("status") == "draft":
                    targets.add(rec.get("id"))
        mode = "restore-all"
    elif restore_ids:
        targets = restore_ids
        mode = "restore"

    if not targets:
        print("Nothing selected.")
        return 0

    print(f"mode: {mode} | targets: {len(targets)}")

    touched_q = 0
    touched_s = 0
    per_section: Counter[str] = Counter()
    flipped_stimuli: set[str] = set()

    # Pass 1: stimuli
    for path in _ndjson_files("stimuli.ndjson"):
        rows = _read(path)
        changed = False
        records = []
        for _raw, rec in rows:
            sid = rec.get("id")
            if sid in targets:
                want = "published" if mode in ("restore", "restore-all") else "draft"
                if rec.get("status") != want:
                    rec["status"] = want
                    changed = True
                    touched_s += 1
                    flipped_stimuli.add(sid)
                if mode == "quarantine":
                    print(f"  stimulus {sid} -> draft")
            records.append(rec)
        if changed and not dry:
            _write(path, records)

    # Pass 2: questions linked to those stimuli
    for path in _ndjson_files("questions.ndjson"):
        rows = _read(path)
        changed = False
        records = []
        for _raw, rec in rows:
            sid = rec.get("stimulusId")
            if sid in targets or (mode == "restore-all" and rec.get("status") == "draft"):
                want = "published" if mode in ("restore", "restore-all") else "draft"
                if rec.get("status") != want:
                    rec["status"] = want
                    changed = True
                    touched_q += 1
                    per_section[f"{rec.get('section')}/{rec.get('language')}"] += 1
            records.append(rec)
        if changed and not dry:
            _write(path, records)

    verb = "restored" if mode in ("restore", "restore-all") else "quarantined"
    print(f"\n{verb}: {touched_q} questions, {touched_s} stimuli"
          + (" (dry run - nothing written)" if dry else ""))
    for key in sorted(per_section):
        print(f"   {key:24s} {per_section[key]:3d} q")

    if mode == "quarantine" and touched_q and not dry:
        # Sanity: every group must go as a whole, never a passage without its
        # questions or the other way round.
        for path in _ndjson_files("questions.ndjson"):
            for _raw, rec in _read(path):
                if rec.get("stimulusId") in flipped_stimuli and rec.get("status") != "draft":
                    print(f"ERROR: {rec['id']} still published under a draft stimulus")
                    return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

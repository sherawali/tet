#!/usr/bin/env python3
"""Delete CDN pack files that the current manifest no longer references.

build_cdn_packs.py deliberately leaves superseded pack files on disk so a client
still holding an older manifest can finish its download. That is correct for one
release, but on `main` the leftovers accumulate forever and - worse - they make
"what is live right now?" impossible to answer by listing the directory.

Clients pin their packs to a `v<stamp>` git tag, and tags keep the tree exactly
as it was, so pruning `main` cannot break an app that is mid-sync on an older
release. Run this after every build, in CI and locally.

    python3 tools/v2/prune_stale_packs.py            # delete
    python3 tools/v2/prune_stale_packs.py --dry-run  # report only
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
CDN_DIR = REPO_ROOT / "cdn"
PACKS_DIR = CDN_DIR / "packs"
MANIFEST = CDN_DIR / "manifest.json"


def main(argv: list[str]) -> int:
    dry_run = "--dry-run" in argv

    if not MANIFEST.exists():
        print(f"Error: {MANIFEST} does not exist - run build_cdn_packs.py first.")
        return 1

    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    referenced: set[str] = set()
    for entry in manifest.get("packs", []):
        name = Path(entry["file"]).name
        referenced.add(name)
        if not (PACKS_DIR / name).exists():
            print(f"Error: manifest references a missing pack: {name}")
            return 1

    on_disk = sorted(p.name for p in PACKS_DIR.glob("pack-*.json"))
    stale = [name for name in on_disk if name not in referenced]

    ids = [entry["id"] for entry in manifest.get("packs", [])]
    if len(ids) != len(set(ids)):
        print("Error: duplicate pack ids in the manifest")
        return 1
    for entry in manifest.get("packs", []):
        # Files are pack-<index>-<hash12>.json; the id is that stem without "pack-".
        expected = Path(entry["file"]).stem.removeprefix("pack-")
        if entry["id"] != expected:
            print(
                f"Error: pack id {entry['id']!r} does not match its content-hashed "
                f"filename {expected!r}; the app diffs packs by id, so an id that "
                "does not move with the content hides updates from devices."
            )
            return 1

    print(
        f"bank_version {manifest.get('bank_version')} | "
        f"{len(referenced)} packs referenced | {len(on_disk)} on disk | "
        f"{len(stale)} stale"
    )
    for name in stale:
        if dry_run:
            print(f"  would delete {name}")
        else:
            (PACKS_DIR / name).unlink()
            print(f"  deleted {name}")

    if not stale:
        print("Nothing to prune.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

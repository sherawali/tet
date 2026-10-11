"""Shared build metadata for all generated bank artifacts."""

from __future__ import annotations

import os
from datetime import datetime, timezone

# Release stamps are UTC YYYYMMDDHH.
#
# They increase on their own, which matters because the app refuses to look at
# the CDN unless the stamp moves: its guard is `remote.bank_version <= local`.
# A hardcoded stamp (the old 20261010) silently froze every rebuild — the bank
# could change and the app would still report "up to date".
#
# Set BANK_VERSION in the environment to pin an exact stamp. CI pins it so the
# manifest, the SQLite meta row and the `v<stamp>` git tag all agree.
_STAMP_FORMATS = ("%Y%m%d%H", "%Y%m%d")


def _resolve_version() -> int:
    pinned = os.environ.get("BANK_VERSION", "").strip()
    if pinned:
        return int(pinned)
    return int(datetime.now(timezone.utc).strftime(_STAMP_FORMATS[0]))


BANK_VERSION = _resolve_version()


def version_stamp(version: int | str) -> str:
    """ISO-8601 timestamp for a release stamp (the manifest `generated` field)."""
    text = str(version)
    for fmt in _STAMP_FORMATS:
        try:
            parsed = datetime.strptime(text, fmt)
        except ValueError:
            continue
        return parsed.replace(tzinfo=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    raise ValueError(f"Unrecognised bank_version stamp: {text!r}")

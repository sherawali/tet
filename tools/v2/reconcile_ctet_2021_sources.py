#!/usr/bin/env python3
"""Reconcile recovered CTET candidate-paper metadata with the official date/key inventory.

This records source-matching evidence in the cycle manifest without importing any
question. An internal creation-date match is deliberately not labelled as full
verification: question-ID/stem and final-key reconciliation remain required.
"""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = ROOT / "bank-v2/sources/ctet-p1-2021-2022-cbt-cycle.json"
KEYS_PATH = ROOT / "bank-v2/sources/ctet-p1-2021-2022-final-keys.json"
RECOVERY_INDEX_PATH = (
    ROOT / "bank-v2/source-recovery/ctet-p1-2021-2022/recovery-index.json"
)


def field(text: str, label: str) -> str | None:
    match = re.search(rf"{re.escape(label)}\s*:\s*(.*?)\n", text, flags=re.IGNORECASE)
    return " ".join(match.group(1).split()) if match else None


def candidate_record(document: dict[str, Any]) -> dict[str, Any]:
    text_path = ROOT / document["textPath"]
    text = text_path.read_text(encoding="utf-8")[:20_000]
    creation = field(text, "Creation Date")
    creation_date = creation[:10] if creation and re.match(r"\d{4}-\d{2}-\d{2}", creation) else None
    return {
        "source": document["source"],
        "url": document["url"],
        "sha256": document["sha256"],
        "paperName": field(text, "Question Paper Name"),
        "subjectName": field(text, "Subject Name"),
        "internalCreationDateTime": creation,
        "internalDateMatchesForm": creation_date == document["date"] if creation_date else None,
        "pageCount": document["pageCount"],
        "textCharacters": document["textCharacters"],
        "uniqueQuestionIdCount": document["uniqueQuestionIdCount"],
        "recoveredText": document["textPath"],
    }


def main() -> int:
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    keys = json.loads(KEYS_PATH.read_text(encoding="utf-8"))
    recovery = json.loads(RECOVERY_INDEX_PATH.read_text(encoding="utf-8"))
    recovered_by_date: dict[str, list[dict[str, Any]]] = {}
    for document in recovery["documents"]:
        if document["date"] != "cycle":
            recovered_by_date.setdefault(document["date"], []).append(document)

    official_dates = keys["media"]["english"]["dates"]
    manifest["officialFinalKeyData"] = str(KEYS_PATH.relative_to(ROOT))
    for form in manifest["forms"]:
        date = form["date"]
        official = official_dates[date]
        languages = ["english", "hindi"]
        if "sanskrit" in official["keyTables"]:
            languages.append("sanskrit")
        form["officialAvailableTargetLanguages"] = languages
        form["officialAvailableTargetModules"] = [
            f"{language}-{slot}" for language in languages for slot in (1, 2)
        ]
        candidates = [
            candidate_record(document) for document in recovered_by_date.get(date, [])
        ]
        form["recoveredCandidateVariants"] = candidates
        if any(candidate["internalDateMatchesForm"] is True for candidate in candidates):
            form["candidateVariantStatus"] = "internal-date-matched-answer-sequence-pending"
        elif any(candidate["internalDateMatchesForm"] is None for candidate in candidates):
            form["candidateVariantStatus"] = "requires-ocr-or-alternate-variant"
        else:
            form["candidateVariantStatus"] = "mismatch-rejected"
        form.pop("knownInternalCreationDate", None)

    MANIFEST_PATH.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    statuses: dict[str, int] = {}
    for form in manifest["forms"]:
        status = form["candidateVariantStatus"]
        statuses[status] = statuses.get(status, 0) + 1
    print(f"Reconciled {len(manifest['forms'])} forms: {statuses}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

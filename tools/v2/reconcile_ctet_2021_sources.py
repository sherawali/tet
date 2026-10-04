#!/usr/bin/env python3
"""Reconcile recovered CTET candidate papers with official date/key evidence.

This is source-only work: it records paper metadata, explicit response-sheet test
dates, question-ID probes, and official final-key sequence matches. It does not
import questions, forms, appearances, stimuli, or answers into V2.
"""

from __future__ import annotations

import json
import re
from datetime import datetime
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = ROOT / "bank-v2/sources/ctet-p1-2021-2022-cbt-cycle.json"
KEYS_PATH = ROOT / "bank-v2/sources/ctet-p1-2021-2022-final-keys.json"
PROBES_PATH = ROOT / "bank-v2/sources/ctet-p1-2021-2022-sequence-probes.json"
RECOVERY_INDEX_PATH = (
    ROOT / "bank-v2/source-recovery/ctet-p1-2021-2022/recovery-index.json"
)


def field(text: str, label: str) -> str | None:
    match = re.search(rf"{re.escape(label)}\s*:\s*(.*?)\n", text, flags=re.IGNORECASE)
    return " ".join(match.group(1).split()) if match else None


def normalized_date(value: str | None) -> str | None:
    if not value:
        return None
    for pattern, fmt in (
        (r"(\d{4}-\d{2}-\d{2})", "%Y-%m-%d"),
        (r"(\d{2}/\d{2}/\d{4})", "%d/%m/%Y"),
    ):
        match = re.search(pattern, value)
        if match:
            return datetime.strptime(match.group(1), fmt).date().isoformat()
    return None


def probe_matches(
    probe: dict[str, Any], keys: dict[str, Any]
) -> list[dict[str, Any]]:
    positions = probe["positions"]
    observed = probe["observedCorrectOptions"]
    matches: list[dict[str, Any]] = []
    for medium, medium_data in keys["media"].items():
        for date, date_data in medium_data["dates"].items():
            answers = date_data["keyTables"]["main"]["answers"]
            matched_positions: list[int] = []
            for position, option in zip(positions, observed, strict=True):
                answer = answers[position - 1]
                if answer["universalCredit"] or option in answer["acceptedOptions"]:
                    matched_positions.append(position)
            matches.append(
                {
                    "date": date,
                    "medium": medium,
                    "matchedCount": len(matched_positions),
                    "probeCount": len(positions),
                    "exact": len(matched_positions) == len(positions),
                    "matchedPositions": matched_positions,
                }
            )
    ranked = sorted(
        matches,
        key=lambda item: (-item["matchedCount"], item["date"], item["medium"]),
    )
    # Keep the best candidates in the manifest rather than duplicating all 46
    # date/medium comparisons for every mirror. Any exact match necessarily
    # ranks first; the runners-up demonstrate sequence discrimination.
    return ranked[:5]


def candidate_record(
    document: dict[str, Any],
    probes_by_source_and_date: dict[tuple[str, str], list[dict[str, Any]]],
) -> dict[str, Any]:
    text_path = ROOT / document["textPath"]
    text = text_path.read_text(encoding="utf-8")
    front = text[:30_000]
    creation = field(front, "Creation Date")
    test_date_value = field(front, "Test Date")
    creation_date = normalized_date(creation)
    test_date = normalized_date(test_date_value)
    probes = probes_by_source_and_date.get((document["date"], document["source"]), [])
    exact_matches = [
        match
        for probe in probes
        for match in probe["officialKeyMatches"]
        if match["exact"]
    ]
    if any(match["date"] == document["date"] for match in exact_matches):
        disposition = "matches-catalogued-date-by-official-key-sequence"
    elif exact_matches:
        disposition = "matches-different-official-date-by-key-sequence"
    elif test_date == document["date"]:
        disposition = "response-sheet-test-date-matched-key-mapping-pending"
    elif creation_date == document["date"]:
        disposition = "internal-creation-date-matched-key-sequence-pending"
    elif document.get("ocrApplied") is False and document.get("pagesWithText", 0) <= 1:
        disposition = "requires-ocr"
    else:
        disposition = "date-evidence-unresolved"
    return {
        "source": document["source"],
        "url": document["url"],
        "sha256": document["sha256"],
        "paperName": field(front, "Question Paper Name"),
        "subjectName": field(front, "Subject Name") or field(front, "Subject"),
        "internalCreationDateTime": creation,
        "internalCreationDate": creation_date,
        "internalCreationDateMatchesForm": creation_date == document["date"] if creation_date else None,
        "explicitTestDate": test_date,
        "explicitTestDateMatchesForm": test_date == document["date"] if test_date else None,
        "pageCount": document["pageCount"],
        "textCharacters": document["textCharacters"],
        "uniqueQuestionIdCount": document["uniqueQuestionIdCount"],
        "ocrApplied": document.get("ocrApplied", False),
        "sequenceProbes": probes,
        "sourceDisposition": disposition,
        "recoveredText": document["textPath"],
    }


def main() -> int:
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    keys = json.loads(KEYS_PATH.read_text(encoding="utf-8"))
    probes_data = json.loads(PROBES_PATH.read_text(encoding="utf-8"))
    recovery = json.loads(RECOVERY_INDEX_PATH.read_text(encoding="utf-8"))

    probes_by_source_and_date: dict[tuple[str, str], list[dict[str, Any]]] = {}
    for source_probe in probes_data["probes"]:
        probe = {
            **source_probe,
            "officialKeyMatches": probe_matches(source_probe, keys),
        }
        for source in source_probe["sources"]:
            probes_by_source_and_date.setdefault(
                (source_probe["cataloguedFormDate"], source), []
            ).append(probe)

    recovered_by_date: dict[str, list[dict[str, Any]]] = {}
    for document in recovery["documents"]:
        if document["date"] != "cycle":
            recovered_by_date.setdefault(document["date"], []).append(document)

    official_dates = keys["media"]["english"]["dates"]
    manifest["officialFinalKeyData"] = str(KEYS_PATH.relative_to(ROOT))
    manifest["candidateSequenceProbeData"] = str(PROBES_PATH.relative_to(ROOT))
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
            candidate_record(document, probes_by_source_and_date)
            for document in recovered_by_date.get(date, [])
        ]
        form["recoveredCandidateVariants"] = candidates
        dispositions = {candidate["sourceDisposition"] for candidate in candidates}
        if "matches-catalogued-date-by-official-key-sequence" in dispositions:
            status = "official-key-sequence-matched"
        elif "response-sheet-test-date-matched-key-mapping-pending" in dispositions:
            status = "response-sheet-date-matched-key-mapping-pending"
        elif "internal-creation-date-matched-key-sequence-pending" in dispositions:
            status = "internal-date-matched-key-sequence-pending"
        elif "requires-ocr" in dispositions:
            status = "requires-ocr"
        else:
            status = "alternate-variant-required"
        form["candidateVariantStatus"] = status
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

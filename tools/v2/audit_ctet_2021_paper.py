#!/usr/bin/env python3
"""Create a strict, non-importing audit ledger for one CTET Paper-I export.

The ledger is intentionally pessimistic: source extraction and official-answer
attachment never count as human verification. Every position remains blocked
until its source page, both required presentations, options, answer and any
visual material have been checked question by question.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

from parse_ctet_2021_candidate_papers import (
    COMPREHENSION_HEADER,
    ROOT,
    clean_fragment,
    detected_common_language,
    page_at,
    parse_document,
)

MANIFEST_PATH = ROOT / "bank-v2/sources/ctet-p1-2021-2022-cbt-cycle.json"
RECOVERY_INDEX_PATH = ROOT / "bank-v2/source-recovery/ctet-p1-2021-2022/recovery-index.json"
FINAL_KEYS_PATH = ROOT / "bank-v2/sources/ctet-p1-2021-2022-final-keys.json"
AUDIT_ROOT = ROOT / "bank-v2/audits"

VISUAL_CANDIDATES = {
    37: "mathematical-expression",
    45: "table",
    57: "matching-layout-and-expressions",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--date", required=True, help="Catalogued form date (YYYY-MM-DD).")
    parser.add_argument("--source", required=True, help="Authenticated recovered source ID.")
    parser.add_argument(
        "--main-key-medium",
        required=True,
        choices=("english", "hindi"),
        help="Official main-key medium independently authenticated for this export.",
    )
    parser.add_argument("--output", help="Optional repository-relative output path.")
    return parser.parse_args()


def source_disposition(
    manifest: dict[str, Any], date: str, source: str, sha256: str
) -> str | None:
    for form in manifest["forms"]:
        if form["date"] != date:
            continue
        for candidate in form.get("recoveredCandidateVariants", []):
            if candidate["source"] == source and candidate["sha256"] == sha256:
                return candidate["sourceDisposition"]
    return None


def answer_for_position(
    keys: dict[str, Any],
    *,
    date: str,
    main_key_medium: str,
    position: int,
    language_1: str,
    language_2: str,
) -> dict[str, Any]:
    tables = keys["media"][main_key_medium]["dates"][date]["keyTables"]
    if position <= 90:
        table = "main"
    elif position <= 120:
        table = language_1
    else:
        table = language_2
    answer = tables[table]["answers"][position - tables[table]["firstQuestion"]]
    return {
        "evidence": str(FINAL_KEYS_PATH.relative_to(ROOT)),
        "medium": main_key_medium,
        "table": table,
        "keyPosition": position,
        "acceptedOptions": answer["acceptedOptions"],
        "universalCredit": answer["universalCredit"],
        "status": "official-final-key-attached-not-yet-human-audited",
    }


def stimulus_texts(candidate: dict[str, Any]) -> list[dict[str, Any]]:
    source_paths = [("native", candidate["sourceTextPath"])]
    if candidate.get("fullPageOcrTextPath"):
        source_paths.append(("full-page-ocr", candidate["fullPageOcrTextPath"]))

    choices: dict[tuple[str, int, int], list[dict[str, Any]]] = {}
    for origin, relative_path in source_paths:
        text = (ROOT / relative_path).read_text(encoding="utf-8")
        for match in COMPREHENSION_HEADER.finditer(text):
            key = (match.group(1), int(match.group(2)), int(match.group(3)))
            tail = text[match.end():]
            end_match = re.search(r"(?mi)^\s*Sub questions\s*$", tail)
            if not end_match:
                continue
            payload = tail[:end_match.start()]
            payload = re.sub(
                r"(?mi)^\s*Question Label\s*:\s*Comprehension\s*$", "", payload
            )
            payload = clean_fragment(payload)
            if not payload:
                continue
            language = detected_common_language({"stemText": payload, "options": []})
            choices.setdefault(key, []).append(
                {
                    "source": origin,
                    "page": page_at(text, match.start()),
                    "language": language,
                    "text": payload,
                }
            )

    stimuli: list[dict[str, Any]] = []
    for (question_id, first, last), values in sorted(choices.items(), key=lambda item: item[0][1]):
        # Full-page OCR recovers image-encoded passage text; prefer it when it
        # is at least as informative as native extraction.
        best = max(
            values,
            key=lambda value: (
                len(value["text"]),
                value["source"] == "full-page-ocr",
            ),
        )
        stimuli.append(
            {
                "questionId": question_id,
                "firstPosition": first,
                "lastPosition": last,
                "selectionPolicy": "atomic",
                "source": best["source"],
                "page": best["page"],
                "language": best["language"],
                "text": best["text"],
                "auditStatus": "pending-source-page-comparison",
                "importEligible": False,
            }
        )
    return stimuli


def main() -> int:
    args = parse_args()
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    recovery = json.loads(RECOVERY_INDEX_PATH.read_text(encoding="utf-8"))
    keys = json.loads(FINAL_KEYS_PATH.read_text(encoding="utf-8"))

    matches = [
        document
        for document in recovery["documents"]
        if document["date"] == args.date and document["source"] == args.source
    ]
    if len(matches) != 1:
        raise SystemExit(
            f"Expected exactly one recovered source for {args.date} {args.source}; found {len(matches)}"
        )
    document = matches[0]
    disposition = source_disposition(manifest, args.date, args.source, document["sha256"])
    if disposition != "matches-catalogued-date-by-official-key-sequence":
        raise SystemExit(f"Source is not authenticated for import audit: {disposition!r}")

    candidate = parse_document(document, disposition)
    if candidate["parsedQuestionCount"] != 150 or candidate["missingPositions"]:
        raise SystemExit("Selected source does not expose all 150 canonical positions")

    subject_match = re.search(
        r"P1\s+(English|Hindi|Sanskrit)\s+and\s+(English|Hindi|Sanskrit)",
        candidate["subjectName"] or "",
        flags=re.I,
    )
    if not subject_match:
        raise SystemExit(f"Cannot determine language slots from {candidate['subjectName']!r}")
    language_1, language_2 = (value.lower() for value in subject_match.groups())

    stimuli = stimulus_texts(candidate)
    stimulus_by_position = {
        position: stimulus["questionId"]
        for stimulus in stimuli
        for position in range(stimulus["firstPosition"], stimulus["lastPosition"] + 1)
    }

    questions: list[dict[str, Any]] = []
    structurally_ready = 0
    for question in candidate["questions"]:
        position = question["position"]
        expected_languages = (
            ["english", "hindi"]
            if position <= 90
            else [language_1 if position <= 120 else language_2]
        )
        presentations = question["presentations"]
        by_language = {presentation["language"]: presentation for presentation in presentations}
        findings: list[str] = []
        for language in expected_languages:
            presentation = by_language.get(language)
            if presentation is None:
                findings.append(f"missing-{language}-presentation")
            elif presentation["extractionStatus"] != "text-complete":
                findings.append(f"incomplete-{language}-presentation")
            elif [option["text"] for option in presentation["options"]] == ["1", "2", "3", "4"]:
                findings.append(f"unresolved-{language}-selector-options")
        if position in VISUAL_CANDIDATES:
            findings.append(f"potential-visual:{VISUAL_CANDIDATES[position]}")
        if not [finding for finding in findings if not finding.startswith("potential-visual:")]:
            structurally_ready += 1

        questions.append(
            {
                "position": position,
                "section": question["section"],
                "questionId": question["questionId"],
                "sourcePages": question["pages"],
                "expectedLanguages": expected_languages,
                "presentations": presentations,
                "stimulusQuestionId": stimulus_by_position.get(position),
                "officialAnswer": answer_for_position(
                    keys,
                    date=args.date,
                    main_key_medium=args.main_key_medium,
                    position=position,
                    language_1=language_1,
                    language_2=language_2,
                ),
                "potentialVisual": VISUAL_CANDIDATES.get(position),
                "automatedFindings": findings,
                "checks": {
                    "sourcePageCompared": "pending",
                    "fullStemVerified": "pending",
                    "allFourOptionsVerified": "pending",
                    "requiredPresentationsVerified": "pending",
                    "officialAnswerVerified": "pending",
                    "stimulusOrVisualVerified": "pending" if position in stimulus_by_position or position in VISUAL_CANDIDATES else "not-applicable",
                    "paper2ContaminationChecked": "pending",
                    "unwantedTextChecked": "pending",
                },
                "auditStatus": "pending-human-question-by-question-review",
                "importEligible": False,
            }
        )

    report = {
        "schemaVersion": 1,
        "id": f"ctet-p1-{args.date}-{args.source.lower()}-question-audit",
        "purpose": "Strict one-paper question audit. This artifact imports no bank rows.",
        "policy": {
            "onePaperOnly": True,
            "humanSourcePageComparisonRequired": True,
            "officialFinalKeyRequired": True,
            "uncertainContentImportProhibited": True,
            "stimuliSelectedAtomically": True,
        },
        "source": {
            "cataloguedDate": args.date,
            "source": args.source,
            "url": candidate["url"],
            "sha256": candidate["sourceSha256"],
            "sourceDisposition": candidate["sourceDisposition"],
            "paperName": candidate["paperName"],
            "subjectName": candidate["subjectName"],
            "pageCount": candidate["pageCount"],
            "language1": language_1,
            "language2": language_2,
            "nativeTextPath": candidate["sourceTextPath"],
            "fullPageOcrTextPath": candidate["fullPageOcrTextPath"],
        },
        "summary": {
            "requiredPositionCount": 150,
            "canonicalPositionCount": candidate["parsedQuestionCount"],
            "officialAnswersAttached": len(questions),
            "stimulusCount": len(stimuli),
            "structurallyReadyForHumanReview": structurally_ready,
            "humanAuditPassed": 0,
            "humanAuditPending": len(questions),
            "importEligible": 0,
            "imported": 0,
        },
        "stimuli": stimuli,
        "questions": questions,
    }

    output_path = (
        ROOT / args.output
        if args.output
        else AUDIT_ROOT / f"ctet-p1-{args.date}-{args.source.lower()}-question-audit.json"
    )
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report["summary"], indent=2))
    print(output_path.relative_to(ROOT))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

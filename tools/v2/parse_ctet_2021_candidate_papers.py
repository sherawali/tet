#!/usr/bin/env python3
"""Normalize recovered CTET Paper-I candidate exports without importing them.

The output is an audit/reconciliation artifact. It preserves candidate position,
question ID, best recoverable text/options, occurrence/page evidence, stimulus
IDs/ranges, and extraction completeness. It never writes V2 questions, forms,
appearances, stimuli, or answers.
"""

from __future__ import annotations

import hashlib
import json
import re
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = ROOT / "bank-v2/sources/ctet-p1-2021-2022-cbt-cycle.json"
RECOVERY_INDEX_PATH = ROOT / "bank-v2/source-recovery/ctet-p1-2021-2022/recovery-index.json"
OUTPUT_PATH = ROOT / "bank-v2/audits/ctet-p1-2021-2022-candidate-reconciliation.json"

PAGE_MARKER = re.compile(r"===== PDF PAGE (\d+) =====")
QUESTION_HEADER = re.compile(
    r"Question Number\s*:\s*(\d+)\s+Question Id\s*:\s*(\d+)\s+"
    r"Question Type\s*:\s*MCQ\b",
    flags=re.IGNORECASE,
)
COMPREHENSION_HEADER = re.compile(
    r"Question Id\s*:\s*(\d+)\s+Question Type\s*:\s*COMPREHENSION\b"
    r"(?:(?!Question Id\s*:).){0,800}?Question Numbers\s*:\s*\(\s*(\d+)\s+to\s+(\d+)\s*\)",
    flags=re.IGNORECASE | re.DOTALL,
)
OPTION_MARKER = re.compile(r"(?m)^\s*([1-4])\.\s*")

SECTION_RANGES = {
    "cdp": (1, 30),
    "mathematics": (31, 60),
    "evs": (61, 90),
    "language-1": (91, 120),
    "language-2": (121, 150),
}


def section_for(position: int) -> str:
    for section, (first, last) in SECTION_RANGES.items():
        if first <= position <= last:
            return section
    raise ValueError(f"Position outside Paper-I range: {position}")


def page_at(text: str, offset: int) -> int | None:
    page = None
    for match in PAGE_MARKER.finditer(text, 0, offset):
        page = int(match.group(1))
    return page


def clean_fragment(value: str) -> str:
    value = PAGE_MARKER.sub(" ", value)
    value = re.sub(r"\bOption Shuffling\s*:\s*(?:Yes|No)\b", " ", value, flags=re.I)
    value = re.sub(r"\bIs\s+Question Mandatory\s*:\s*No\b", " ", value, flags=re.I)
    value = re.sub(r"\bQuestion Mandatory\s*:\s*No\b", " ", value, flags=re.I)
    value = re.sub(r"\bCorrect Marks\s*:\s*1\s+Wrong Marks\s*:\s*0\b", " ", value, flags=re.I)
    value = re.sub(r"[ \t]+", " ", value)
    value = re.sub(r" *\n *", "\n", value)
    value = re.sub(r"\n{3,}", "\n\n", value)
    return value.strip()


def parse_options(value: str) -> list[dict[str, Any]]:
    markers = list(OPTION_MARKER.finditer(value))
    options: list[dict[str, Any]] = []
    for index, marker in enumerate(markers):
        end = markers[index + 1].start() if index + 1 < len(markers) else len(value)
        options.append(
            {
                "index": int(marker.group(1)),
                "text": clean_fragment(value[marker.end():end]),
            }
        )
    # A malformed extraction can contain duplicate option markers. Keep the
    # first four-option run only; never synthesize missing option text.
    for start in range(max(1, len(options) - 3)):
        run = options[start:start + 4]
        if [item["index"] for item in run] == [1, 2, 3, 4]:
            return run
    return options[:4]


def textual_characters(value: str) -> int:
    return sum(character.isalpha() for character in value)


def parse_occurrence(text: str, match: re.Match[str], end: int) -> dict[str, Any]:
    payload = text[match.end():end]
    options_split = re.split(r"\bOptions\s*:\s*", payload, maxsplit=1, flags=re.I)
    stem = clean_fragment(options_split[0])
    options = parse_options(options_split[1]) if len(options_split) == 2 else []
    meaningful_stem = textual_characters(stem)
    meaningful_options = [textual_characters(option["text"]) for option in options]
    complete_option_count = sum(count >= 1 for count in meaningful_options)
    if meaningful_stem >= 12 and complete_option_count == 4:
        status = "text-complete"
    elif meaningful_stem >= 5 or complete_option_count:
        status = "text-partial"
    else:
        status = "image-encoded"
    score = meaningful_stem + sum(meaningful_options) + complete_option_count * 20
    return {
        "page": page_at(text, match.start()),
        "stemText": stem,
        "options": options,
        "meaningfulStemCharacters": meaningful_stem,
        "nonemptyOptionCount": complete_option_count,
        "extractionStatus": status,
        "score": score,
    }


def candidate_metadata(text: str) -> dict[str, str | None]:
    def field(label: str) -> str | None:
        match = re.search(rf"{re.escape(label)}\s*:\s*(.*?)\n", text[:30_000], flags=re.I)
        return " ".join(match.group(1).split()) if match else None

    return {
        "paperName": field("Question Paper Name"),
        "subjectName": field("Subject Name") or field("Subject"),
        "creationDateTime": field("Creation Date"),
        "testDate": field("Test Date"),
    }


def parse_document(document: dict[str, Any], disposition: str | None) -> dict[str, Any]:
    text_path = ROOT / document["textPath"]
    text = text_path.read_text(encoding="utf-8")
    headers = list(QUESTION_HEADER.finditer(text))
    occurrences: dict[tuple[int, str], list[dict[str, Any]]] = defaultdict(list)
    for index, match in enumerate(headers):
        end = headers[index + 1].start() if index + 1 < len(headers) else len(text)
        position = int(match.group(1))
        question_id = match.group(2)
        if 1 <= position <= 150:
            occurrences[(position, question_id)].append(parse_occurrence(text, match, end))

    by_position: dict[int, list[tuple[str, list[dict[str, Any]]]]] = defaultdict(list)
    for (position, question_id), values in occurrences.items():
        by_position[position].append((question_id, values))

    questions: list[dict[str, Any]] = []
    position_conflicts: list[dict[str, Any]] = []
    for position in sorted(by_position):
        ids = by_position[position]
        if len(ids) > 1:
            position_conflicts.append(
                {"position": position, "questionIds": sorted(question_id for question_id, _ in ids)}
            )
        question_id, values = max(ids, key=lambda item: max(value["score"] for value in item[1]))
        best = max(values, key=lambda value: value["score"])
        questions.append(
            {
                "position": position,
                "section": section_for(position),
                "questionId": question_id,
                "occurrenceCount": len(values),
                "pages": sorted({value["page"] for value in values if value["page"] is not None}),
                "stemText": best["stemText"],
                "options": best["options"],
                "meaningfulStemCharacters": best["meaningfulStemCharacters"],
                "nonemptyOptionCount": best["nonemptyOptionCount"],
                "extractionStatus": best["extractionStatus"],
            }
        )

    stimuli_seen: set[tuple[str, int, int]] = set()
    stimuli: list[dict[str, Any]] = []
    for match in COMPREHENSION_HEADER.finditer(text):
        evidence = (match.group(1), int(match.group(2)), int(match.group(3)))
        if evidence in stimuli_seen:
            continue
        stimuli_seen.add(evidence)
        stimuli.append(
            {
                "questionId": evidence[0],
                "firstPosition": evidence[1],
                "lastPosition": evidence[2],
                "page": page_at(text, match.start()),
            }
        )

    position_set = {question["position"] for question in questions}
    missing_positions = sorted(set(range(1, 151)) - position_set)
    statuses = Counter(question["extractionStatus"] for question in questions)
    sections: dict[str, dict[str, int]] = {}
    for section, (first, last) in SECTION_RANGES.items():
        section_questions = [question for question in questions if first <= question["position"] <= last]
        section_statuses = Counter(question["extractionStatus"] for question in section_questions)
        sections[section] = {
            "positionCount": len(section_questions),
            "textComplete": section_statuses["text-complete"],
            "textPartial": section_statuses["text-partial"],
            "imageEncoded": section_statuses["image-encoded"],
        }

    sequence = "|".join(f"{question['position']}:{question['questionId']}" for question in questions)
    return {
        "cataloguedDate": document["date"],
        "source": document["source"],
        "sourceDisposition": disposition,
        "url": document["url"],
        "sourceSha256": document["sha256"],
        "sourceTextPath": document["textPath"],
        **candidate_metadata(text),
        "pageCount": document["pageCount"],
        "ocrApplied": document.get("ocrApplied", False),
        "parsedQuestionCount": len(questions),
        "missingPositions": missing_positions,
        "positionConflicts": position_conflicts,
        "textCompleteCount": statuses["text-complete"],
        "textPartialCount": statuses["text-partial"],
        "imageEncodedCount": statuses["image-encoded"],
        "questionIdSequenceSha256": hashlib.sha256(sequence.encode()).hexdigest(),
        "sections": sections,
        "stimuli": stimuli,
        "questions": questions,
    }


def main() -> int:
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    recovery = json.loads(RECOVERY_INDEX_PATH.read_text(encoding="utf-8"))
    dispositions: dict[tuple[str, str, str], str] = {}
    for form in manifest["forms"]:
        for candidate in form.get("recoveredCandidateVariants", []):
            dispositions[(form["date"], candidate["source"], candidate["sha256"])] = candidate[
                "sourceDisposition"
            ]

    candidates = []
    for document in recovery["documents"]:
        if document["date"] == "cycle":
            continue
        disposition = dispositions.get(
            (document["date"], document["source"], document["sha256"])
        )
        candidates.append(parse_document(document, disposition))

    fingerprint_groups: dict[str, list[dict[str, str]]] = defaultdict(list)
    for candidate in candidates:
        fingerprint_groups[candidate["questionIdSequenceSha256"]].append(
            {
                "cataloguedDate": candidate["cataloguedDate"],
                "source": candidate["source"],
                "sourceSha256": candidate["sourceSha256"],
            }
        )
    duplicate_groups = [
        {"questionIdSequenceSha256": fingerprint, "documents": documents}
        for fingerprint, documents in sorted(fingerprint_groups.items())
        if len(documents) > 1 and fingerprint != hashlib.sha256(b"").hexdigest()
    ]
    summary = {
        "candidateDocumentCount": len(candidates),
        "documentsWithAll150Positions": sum(
            candidate["parsedQuestionCount"] == 150 and not candidate["positionConflicts"]
            for candidate in candidates
        ),
        "documentsWithoutQuestionIds": sum(candidate["parsedQuestionCount"] == 0 for candidate in candidates),
        "duplicateQuestionIdSequenceGroupCount": len(duplicate_groups),
        "totalNormalizedQuestionRecords": sum(candidate["parsedQuestionCount"] for candidate in candidates),
        "totalTextComplete": sum(candidate["textCompleteCount"] for candidate in candidates),
        "totalTextPartial": sum(candidate["textPartialCount"] for candidate in candidates),
        "totalImageEncoded": sum(candidate["imageEncodedCount"] for candidate in candidates),
    }
    report = {
        "schemaVersion": 1,
        "id": "ctet-p1-2021-2022-candidate-reconciliation",
        "purpose": "Candidate source normalization and reconciliation only; this artifact is not an imported question bank.",
        "cycleSourceManifest": str(MANIFEST_PATH.relative_to(ROOT)),
        "recoveryIndex": str(RECOVERY_INDEX_PATH.relative_to(ROOT)),
        "positionModel": {
            section: {"first": first, "last": last}
            for section, (first, last) in SECTION_RANGES.items()
        },
        "summary": summary,
        "duplicateQuestionIdSequenceGroups": duplicate_groups,
        "candidates": sorted(candidates, key=lambda item: (item["cataloguedDate"], item["source"])),
    }
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(summary, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

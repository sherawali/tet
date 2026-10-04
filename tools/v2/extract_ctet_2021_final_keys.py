#!/usr/bin/env python3
"""Parse the two official CTET December-2021 Paper-I final keys.

The recovered key text is produced by recover_ctet_2021_sources.py. This parser
keeps English- and Hindi-medium option ordering separate, records every language
code available on each authenticated date, preserves multiple accepted options,
and represents official answer 9 as universal credit rather than option 9.
It writes source evidence only and never mutates the populated V2 question bank.
"""

from __future__ import annotations

import datetime as dt
import json
import re
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
SOURCE_ROOT = ROOT / "bank-v2/source-recovery/ctet-p1-2021-2022"
INDEX_PATH = SOURCE_ROOT / "recovery-index.json"
MANIFEST_PATH = ROOT / "bank-v2/sources/ctet-p1-2021-2022-cbt-cycle.json"
OUTPUT_PATH = ROOT / "bank-v2/sources/ctet-p1-2021-2022-final-keys.json"

KEY_SOURCES = {
    "english": SOURCE_ROOT / "text/cycle--paper1englishmediumfinalkey.txt",
    "hindi": SOURCE_ROOT / "text/cycle--paper1hindimediumfinalkey.txt",
}
TARGET_SECTIONS = {
    "-MAIN": "main",
    "01-ENGLISH": "english",
    "02-HINDI": "hindi",
    "16-SANSKRIT": "sanskrit",
}


def parse_answer(value: str) -> dict[str, Any]:
    compact = value.replace(" ", "")
    if compact == "9":
        return {"acceptedOptions": [], "universalCredit": True}
    return {
        "acceptedOptions": [int(option) for option in compact.split(",")],
        "universalCredit": False,
    }


def parse_key(path: Path) -> dict[str, Any]:
    raw = path.read_text(encoding="utf-8")
    chunks = re.split(r"^===== PDF PAGE (\d+) =====\n", raw, flags=re.MULTILINE)[1:]
    dates: dict[str, Any] = {}
    for offset in range(0, len(chunks), 2):
        pdf_page = int(chunks[offset])
        page = chunks[offset + 1]
        header = re.search(
            r"Exam Date:\s*(\d{2}/\d{2}/\d{4}).*?PAPER-I\s+(.+?)\s+Publish Date:",
            page,
            flags=re.DOTALL,
        )
        if not header:
            raise ValueError(f"No key header on PDF page {pdf_page} of {path}")
        raw_date, raw_section = header.groups()
        iso_date = dt.datetime.strptime(raw_date, "%d/%m/%Y").date().isoformat()
        section = " ".join(raw_section.split())
        lower, upper = (1, 90) if section == "-MAIN" else (91, 150)
        answers: dict[int, dict[str, Any]] = {}
        for question, answer in re.findall(
            r"(?<![\d/])(\d{1,3})\s+((?:[1-4](?:\s*,\s*[1-4])*)|9)(?=\s)",
            page,
        ):
            number = int(question)
            if lower <= number <= upper:
                answers[number] = parse_answer(answer)
        expected = set(range(lower, upper + 1))
        if set(answers) != expected:
            missing = sorted(expected - set(answers))
            extra = sorted(set(answers) - expected)
            raise ValueError(
                f"Incomplete key on {iso_date} {section} page {pdf_page}: "
                f"missing={missing}, extra={extra}"
            )
        date_record = dates.setdefault(
            iso_date,
            {
                "availableLanguageCodes": [],
                "keyTables": {},
            },
        )
        if section != "-MAIN":
            date_record["availableLanguageCodes"].append(section)
        if section in TARGET_SECTIONS:
            date_record["keyTables"][TARGET_SECTIONS[section]] = {
                "pdfPage": pdf_page,
                "firstQuestion": lower,
                "answers": [answers[number] for number in range(lower, upper + 1)],
            }

    for date_record in dates.values():
        date_record["availableLanguageCodes"].sort(key=lambda value: int(value[:2]))
    return dates


def main() -> int:
    cycle_manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    recovery_index = json.loads(INDEX_PATH.read_text(encoding="utf-8"))
    expected_dates = cycle_manifest["dateInventory"]["dates"]
    recovered_by_source = {
        record["source"]: record
        for record in recovery_index["documents"]
        if record["date"] == "cycle"
    }

    media: dict[str, Any] = {}
    for medium, source_path in KEY_SOURCES.items():
        source_name = f"paper1{medium.capitalize()}MediumFinalKey"
        source_record = recovered_by_source[source_name]
        parsed_dates = parse_key(source_path)
        if list(parsed_dates) != expected_dates:
            raise ValueError(
                f"{medium} key dates differ from the authorized inventory: "
                f"{list(parsed_dates)}"
            )
        media[medium] = {
            "officialDocument": source_record["url"],
            "sha256": source_record["sha256"],
            "pageCount": source_record["pageCount"],
            "dates": parsed_dates,
        }

    for date in expected_dates:
        english_languages = media["english"]["dates"][date]["availableLanguageCodes"]
        hindi_languages = media["hindi"]["dates"][date]["availableLanguageCodes"]
        if english_languages != hindi_languages:
            raise ValueError(f"Official language inventory differs by medium on {date}")
        for medium in media:
            tables = media[medium]["dates"][date]["keyTables"]
            required = {"main", "english", "hindi"}
            if "16-SANSKRIT" in english_languages:
                required.add("sanskrit")
            if set(tables) != required:
                raise ValueError(
                    f"Unexpected target tables for {medium} {date}: {sorted(tables)}"
                )

    output = {
        "schemaVersion": 1,
        "id": "ctet-p1-2021-2022-official-final-keys",
        "cycleSourceManifest": str(MANIFEST_PATH.relative_to(ROOT)),
        "exam": "ctet",
        "paper": 1,
        "cycleLabel": "December 2021",
        "answerRepresentation": {
            "acceptedOptions": "One or more official option positions; an empty list is valid only when universalCredit is true.",
            "universalCredit": "True exactly when the official key value is 9 (marks awarded to all candidates).",
            "questionPosition": "main answers start at question 1; language answers start at question 91.",
        },
        "media": media,
    }
    OUTPUT_PATH.write_text(
        json.dumps(output, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(
        f"Parsed both 177-page official keys for {len(expected_dates)} dates -> "
        f"{OUTPUT_PATH.relative_to(ROOT)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Create the clean TET V2 section-database structure.

This script is idempotent and never imports or reads the legacy CSV database.
"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BANK = ROOT / "bank-v2"

LOCALES = {
    "ctet": ("hi", "en", "sa"),
    "utet": ("hi", "en", "sa", "ur"),
}

KNOWLEDGE_SECTIONS = {
    1: ("cdp", "mathematics", "environmental-studies"),
    2: ("cdp", "mathematics", "science", "social-studies"),
}


def write_json_if_missing(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if not path.exists():
        path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def touch(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.touch(exist_ok=True)


def section_leaf(
    exam: str,
    paper: int,
    section: str,
    *,
    language: str | None = None,
    slot: int | None = None,
) -> None:
    paper_dir = BANK / "exams" / exam / f"paper-{paper}"
    if section == "language":
        assert language and slot
        leaf = paper_dir / f"language-{slot}" / {
            "hi": "hindi",
            "en": "english",
            "sa": "sanskrit",
            "ur": "urdu",
        }[language]
        database_id = f"{exam}-paper-{paper}-language-{slot}-{language}"
        mode = "language-specific"
    else:
        leaf = paper_dir / section
        database_id = f"{exam}-paper-{paper}-{section}"
        mode = "bilingual"

    write_json_if_missing(
        leaf / "section.json",
        {
            "$schema": "https://tet.local/schemas/section.schema.json",
            "schemaVersion": 1,
            "databaseId": database_id,
            "exam": exam,
            "paper": paper,
            "section": section,
            "language": language,
            "languageSlot": slot,
            "contentMode": mode,
            "questionsFile": "questions.ndjson",
            "stimuliFile": "stimuli.ndjson",
            "status": "empty",
        },
    )
    touch(leaf / "questions.ndjson")
    touch(leaf / "stimuli.ndjson")


def main() -> None:
    for exam in ("ctet", "utet"):
        for paper in (1, 2):
            for section in KNOWLEDGE_SECTIONS[paper]:
                section_leaf(exam, paper, section)
            for slot in (1, 2):
                for language in LOCALES[exam]:
                    section_leaf(exam, paper, "language", language=language, slot=slot)

            forms = BANK / "paper-forms" / exam / f"paper-{paper}"
            touch(forms / "forms.ndjson")
            touch(forms / "appearances.ndjson")

    (BANK / "assets" / "images").mkdir(parents=True, exist_ok=True)
    (BANK / "assets" / "audio").mkdir(parents=True, exist_ok=True)
    touch(BANK / "assets" / "images" / ".gitkeep")
    touch(BANK / "assets" / "audio" / ".gitkeep")
    (BANK / "releases").mkdir(parents=True, exist_ok=True)
    touch(BANK / "releases" / ".gitkeep")

    print("Created TET V2 clean-room structure (no legacy data imported).")


if __name__ == "__main__":
    main()

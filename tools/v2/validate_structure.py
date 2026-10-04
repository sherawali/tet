#!/usr/bin/env python3
"""Validate the clean TET V2 structure without third-party dependencies."""
from __future__ import annotations

import json
import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BANK = ROOT / "bank-v2"

EXPECTED_LOCALES = {
    "ctet": ("hi", "en", "sa"),
    "utet": ("hi", "en", "sa", "ur"),
}
EXPECTED_KNOWLEDGE = {
    1: ("cdp", "mathematics", "environmental-studies"),
    2: ("cdp", "mathematics", "science", "social-studies"),
}
LANGUAGE_DIR = {"hi": "hindi", "en": "english", "sa": "sanskrit", "ur": "urdu"}


def load_json(path: Path, errors: list[str]) -> object | None:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:  # validation output needs the exact file
        errors.append(f"{path.relative_to(ROOT)}: invalid JSON: {exc}")
        return None


def load_ndjson(path: Path, errors: list[str]) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    line_no = 0
    try:
        for line_no, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if not raw.strip():
                continue
            value = json.loads(raw)
            if not isinstance(value, dict):
                errors.append(f"{path.relative_to(ROOT)}:{line_no}: NDJSON row must be an object")
                continue
            rows.append(value)
    except Exception as exc:
        errors.append(f"{path.relative_to(ROOT)}: invalid NDJSON near line {line_no}: {exc}")
    return rows


def validate_ndjson(path: Path, errors: list[str]) -> int:
    """Compatibility helper for catalogs that need syntax/count checks only."""
    return len(load_ndjson(path, errors))


def content_locales(blocks: object) -> set[str]:
    locales: set[str] = set()
    if not isinstance(blocks, list):
        return locales
    for block in blocks:
        if not isinstance(block, dict):
            continue
        for field in ("text", "alt", "caption"):
            value = block.get(field)
            if isinstance(value, dict):
                locales.update(key for key, text in value.items() if isinstance(text, str) and text.strip())
    return locales


def validate_populated_content(
    question_rows: list[tuple[Path, dict[str, object], tuple[object, ...]]],
    stimulus_rows: list[tuple[Path, dict[str, object], tuple[object, ...]]],
    forms: list[dict[str, object]],
    appearances: list[dict[str, object]],
    errors: list[str],
) -> None:
    """Validate V2 references, official-form integrity and atomic stimulus groups."""
    questions: dict[str, dict[str, object]] = {}
    for path, row, expected_identity in question_rows:
        qid = row.get("id")
        label = f"{path.relative_to(ROOT)}:{qid or '<missing-id>'}"
        if not isinstance(qid, str) or not qid:
            errors.append(f"{label}: missing question id")
            continue
        if qid in questions:
            errors.append(f"duplicate question id {qid}")
        questions[qid] = row
        identity = (row.get("exam"), row.get("paper"), row.get("section"), row.get("language"), row.get("languageSlot"))
        if identity != expected_identity:
            errors.append(f"{label}: section-store identity mismatch {identity}")
        options = row.get("options")
        if not isinstance(options, list) or len(options) != 4:
            errors.append(f"{label}: exactly four options are required")
            continue
        option_ids = [item.get("id") for item in options if isinstance(item, dict)]
        if option_ids != ["a", "b", "c", "d"]:
            errors.append(f"{label}: option ids must be a,b,c,d in order")
        answer = row.get("answer")
        answer_id = answer.get("optionId") if isinstance(answer, dict) else None
        if answer_id not in option_ids:
            errors.append(f"{label}: answer must reference one of the four options")
        expected_locales = {"hi", "en"} if row.get("section") != "language" else {row.get("language")}
        if content_locales(row.get("prompt")) != expected_locales:
            errors.append(f"{label}: prompt locales do not equal {sorted(str(x) for x in expected_locales)}")
        for option in options:
            if isinstance(option, dict) and content_locales(option.get("content")) != expected_locales:
                errors.append(f"{label}: option {option.get('id')} has incomplete locales")
        review = row.get("review")
        if not isinstance(review, dict) or not all(review.get(key) is True for key in ("answerVerified", "translationVerified", "mediaVerified")):
            errors.append(f"{label}: all review gates must be true before publication")
        if row.get("status") != "published" or row.get("sourceType") != "pyq":
            errors.append(f"{label}: imported official questions must be published PYQs")

    stimuli: dict[str, dict[str, object]] = {}
    for path, row, expected_identity in stimulus_rows:
        sid = row.get("id")
        label = f"{path.relative_to(ROOT)}:{sid or '<missing-id>'}"
        if not isinstance(sid, str) or not sid:
            errors.append(f"{label}: missing stimulus id")
            continue
        if sid in stimuli:
            errors.append(f"duplicate stimulus id {sid}")
        stimuli[sid] = row
        identity = (row.get("exam"), row.get("paper"), row.get("section"), row.get("language"), row.get("languageSlot"))
        if identity != expected_identity:
            errors.append(f"{label}: section-store identity mismatch {identity}")
        if row.get("selectionPolicy") != "atomic":
            errors.append(f"{label}: stimulus group must use atomic selection")
        review = row.get("review")
        if not isinstance(review, dict) or not all(review.get(key) is True for key in ("textVerified", "translationVerified", "mediaVerified")):
            errors.append(f"{label}: all review gates must be true before publication")

    links: dict[str, list[str]] = {sid: [] for sid in stimuli}
    for qid, question in questions.items():
        sid = question.get("stimulusId")
        if sid is None:
            continue
        if not isinstance(sid, str) or sid not in stimuli:
            errors.append(f"{qid}: missing referenced stimulus {sid}")
            continue
        links[sid].append(qid)
        stimulus = stimuli[sid]
        q_identity = (question.get("exam"), question.get("paper"), question.get("section"), question.get("language"), question.get("languageSlot"))
        s_identity = (stimulus.get("exam"), stimulus.get("paper"), stimulus.get("section"), stimulus.get("language"), stimulus.get("languageSlot"))
        if q_identity != s_identity:
            errors.append(f"{qid}: stimulus {sid} crosses a module boundary")
    for sid, stimulus in stimuli.items():
        linked = links[sid]
        if not linked:
            errors.append(f"{sid}: unreferenced stimulus")
        if stimulus.get("minimumQuestions") != len(linked):
            errors.append(f"{sid}: minimumQuestions={stimulus.get('minimumQuestions')} but linked={len(linked)}")

    appearance_by_id: dict[str, dict[str, object]] = {}
    question_appearance_counts = {qid: 0 for qid in questions}
    for row in appearances:
        aid = row.get("id")
        if not isinstance(aid, str):
            errors.append("appearance missing id")
            continue
        if aid in appearance_by_id:
            errors.append(f"duplicate appearance id {aid}")
        appearance_by_id[aid] = row
        qid = row.get("questionId")
        question = questions.get(qid) if isinstance(qid, str) else None
        if question is None:
            errors.append(f"{aid}: missing question {qid}")
            continue
        question_appearance_counts[qid] += 1
        answer = question.get("answer")
        answer_id = answer.get("optionId") if isinstance(answer, dict) else None
        if row.get("officialOptionId") != answer_id:
            errors.append(f"{aid}: official answer disagrees with canonical question")
        for field in ("exam", "paper", "section", "language", "languageSlot"):
            if row.get(field) != question.get(field):
                errors.append(f"{aid}: {field} disagrees with canonical question")
        if row.get("verificationStatus") != "verified":
            errors.append(f"{aid}: appearance is not verified")
    for qid, count in question_appearance_counts.items():
        if count < 1:
            errors.append(f"{qid}: canonical question has no paper appearance")

    form_ids: set[str] = set()
    referenced_appearances: set[str] = set()
    for form in forms:
        form_id = form.get("id")
        if not isinstance(form_id, str):
            errors.append("paper form missing id")
            continue
        if form_id in form_ids:
            errors.append(f"duplicate paper form id {form_id}")
        form_ids.add(form_id)
        modules = form.get("modules")
        if not isinstance(modules, list):
            errors.append(f"{form_id}: missing modules")
            continue
        core_total = 0
        language_modules: list[tuple[object, object, int]] = []
        for module in modules:
            if not isinstance(module, dict):
                errors.append(f"{form_id}: malformed module")
                continue
            ids = module.get("appearanceIds")
            if not isinstance(ids, list) or module.get("questionCount") != len(ids):
                errors.append(f"{form_id}/{module.get('id')}: question count mismatch")
                continue
            for aid in ids:
                if not isinstance(aid, str) or aid not in appearance_by_id:
                    errors.append(f"{form_id}/{module.get('id')}: missing appearance {aid}")
                else:
                    referenced_appearances.add(aid)
                    if appearance_by_id[aid].get("paperFormId") != form_id:
                        errors.append(f"{aid}: paperFormId mismatch")
            if module.get("kind") == "core":
                core_total += len(ids)
            elif module.get("kind") == "language":
                language_modules.append((module.get("language"), module.get("languageSlot"), len(ids)))
        if form.get("exam") == "ctet" and form.get("paper") == 1:
            if core_total != 90:
                errors.append(f"{form_id}: core modules total {core_total}, expected 90")
            expected_languages_with_sa = {(language, slot, 30) for language in ("en", "hi", "sa") for slot in (1, 2)}
            expected_languages_no_sa = {(language, slot, 30) for language in ("en", "hi") for slot in (1, 2)}
            if set(language_modules) not in (expected_languages_with_sa, expected_languages_no_sa):
                errors.append(f"{form_id}: language alternatives are incomplete")
            if form.get("totalQuestions") != 150:
                errors.append(f"{form_id}: attempted form total must be 150")
            if form.get("verificationStatus") != "verified":
                errors.append(f"{form_id}: form is not verified")
        elif form.get("exam") == "utet" and form.get("paper") == 1:
            if core_total != 90:
                errors.append(f"{form_id}: core modules total {core_total}, expected 90")
            if form.get("totalQuestions") != 150:
                errors.append(f"{form_id}: attempted form total must be 150")
            if form.get("verificationStatus") != "verified":
                errors.append(f"{form_id}: form is not verified")
    if referenced_appearances != set(appearance_by_id):
        errors.append("one or more appearances are not included in their paper-form modules")

    if questions:
        # Audit files are cycle-specific.  Their union must cover the canonical
        # bank exactly once; this remains valid as later cycles are authorized.
        audits: list[dict[str, object]] = []
        for audit_path in sorted((BANK / "audits").glob("*-question-audit.ndjson")):
            audits.extend(load_ndjson(audit_path, errors))
        audit_id_list = [row.get("questionId") for row in audits]
        audit_ids = set(audit_id_list)
        if len(audit_id_list) != len(audit_ids):
            errors.append("question audits contain duplicate canonical question ids")
        if audit_ids != set(questions):
            errors.append("cycle question audits must collectively cover every canonical question")
        for row in audits:
            if (
                row.get("answerTransformationVerified") is not True
                or row.get("stemAndOptionsVerified") is not True
                or row.get("visualDependencyChecked") is not True
                or row.get("disposition") != "imported"
            ):
                errors.append(f"audit row {row.get('questionId')} is not fully verified")

        for source_path in sorted((BANK / "sources").glob("*.json")):
            source = load_json(source_path, errors) if source_path.exists() else None
            if not isinstance(source, dict) or source.get("verificationStatus") != "verified":
                errors.append(f"{source_path.name}: verified cycle source manifest is missing or has incorrect verification status")



def expected_sections() -> list[tuple[str, int, str, str | None, int | None, Path]]:
    sections = []
    for exam in ("ctet", "utet"):
        for paper in (1, 2):
            root = BANK / "exams" / exam / f"paper-{paper}"
            for section in EXPECTED_KNOWLEDGE[paper]:
                sections.append((exam, paper, section, None, None, root / section))
            for slot in (1, 2):
                for locale in EXPECTED_LOCALES[exam]:
                    sections.append(
                        (
                            exam,
                            paper,
                            "language",
                            locale,
                            slot,
                            root / f"language-{slot}" / LANGUAGE_DIR[locale],
                        )
                    )
    return sections


def validate_blueprint(path: Path, errors: list[str]) -> None:
    data = load_json(path, errors)
    if not isinstance(data, dict):
        return
    if data.get("totalQuestions") != 150 or data.get("totalMarks") != 150:
        errors.append(f"{path.relative_to(ROOT)}: totals must be 150/150")
        return
    sections = data.get("sections", [])
    common = sum(item["questionCount"] for item in sections if item.get("stream") is None)
    streams: dict[str, int] = {}
    for item in sections:
        stream = item.get("stream")
        if stream:
            streams[stream] = streams.get(stream, 0) + item["questionCount"]
    if streams:
        for stream, count in streams.items():
            if common + count != 150:
                errors.append(
                    f"{path.relative_to(ROOT)}: {stream} produces {common + count}, expected 150"
                )
    elif common != 150:
        errors.append(f"{path.relative_to(ROOT)}: sections total {common}, expected 150")


def validate_sql(path: Path, errors: list[str]) -> None:
    try:
        connection = sqlite3.connect(":memory:")
        connection.executescript(path.read_text(encoding="utf-8"))
        connection.close()
    except Exception as exc:
        errors.append(f"{path.relative_to(ROOT)}: invalid SQLite schema: {exc}")


def main() -> int:
    errors: list[str] = []

    required_top = [
        BANK / "README.md",
        BANK / "bank.json",
        BANK / "schemas" / "question.schema.json",
        BANK / "schemas" / "stimulus.schema.json",
        BANK / "schemas" / "appearance.schema.json",
        BANK / "schemas" / "paper-form.schema.json",
        BANK / "schemas" / "mock-blueprint.schema.json",
        BANK / "runtime" / "sqlite" / "content_schema.sql",
        BANK / "runtime" / "sqlite" / "user_schema.sql",
    ]
    for path in required_top:
        if not path.exists():
            errors.append(f"missing {path.relative_to(ROOT)}")

    schema_files = sorted((BANK / "schemas").glob("*.json"))
    for path in schema_files:
        load_json(path, errors)

    bank = load_json(BANK / "bank.json", errors)
    if isinstance(bank, dict):
        sync = bank.get("sync", {})
        if sync.get("loginRequired") is not False or sync.get("direction") != "remote-to-device":
            errors.append("bank-v2 sync must be one-way and login-free")

    seen_database_ids: set[str] = set()
    question_rows: list[tuple[Path, dict[str, object], tuple[object, ...]]] = []
    stimulus_rows: list[tuple[Path, dict[str, object], tuple[object, ...]]] = []
    total_questions = total_stimuli = 0
    expected = expected_sections()
    for exam, paper, section, language, slot, leaf in expected:
        for filename in ("section.json", "questions.ndjson", "stimuli.ndjson"):
            if not (leaf / filename).exists():
                errors.append(f"missing {(leaf / filename).relative_to(ROOT)}")
        metadata = load_json(leaf / "section.json", errors)
        if not isinstance(metadata, dict):
            continue
        identity = (
            metadata.get("exam"), metadata.get("paper"), metadata.get("section"),
            metadata.get("language"), metadata.get("languageSlot"),
        )
        if identity != (exam, paper, section, language, slot):
            errors.append(f"{(leaf / 'section.json').relative_to(ROOT)}: identity mismatch {identity}")
        database_id = metadata.get("databaseId")
        if database_id in seen_database_ids:
            errors.append(f"duplicate databaseId {database_id}")
        seen_database_ids.add(database_id)
        identity = (exam, paper, section, language, slot)
        loaded_questions = load_ndjson(leaf / "questions.ndjson", errors)
        loaded_stimuli = load_ndjson(leaf / "stimuli.ndjson", errors)
        question_rows.extend((leaf / "questions.ndjson", row, identity) for row in loaded_questions)
        stimulus_rows.extend((leaf / "stimuli.ndjson", row, identity) for row in loaded_stimuli)
        total_questions += len(loaded_questions)
        total_stimuli += len(loaded_stimuli)

    actual_section_files = list((BANK / "exams").glob("**/section.json"))
    if len(actual_section_files) != len(expected):
        errors.append(
            f"section database count is {len(actual_section_files)}, expected {len(expected)}"
        )

    form_rows: list[dict[str, object]] = []
    appearance_rows: list[dict[str, object]] = []
    for exam in ("ctet", "utet"):
        for paper in (1, 2):
            forms_dir = BANK / "paper-forms" / exam / f"paper-{paper}"
            for filename, target in (("forms.ndjson", form_rows), ("appearances.ndjson", appearance_rows)):
                path = forms_dir / filename
                if not path.exists():
                    errors.append(f"missing {path.relative_to(ROOT)}")
                else:
                    target.extend(load_ndjson(path, errors))

    for path in sorted((BANK / "catalogs").glob("*.ndjson")):
        validate_ndjson(path, errors)

    blueprints = sorted((BANK / "mock-blueprints").glob("*.json"))
    if len(blueprints) != 4:
        errors.append(f"mock blueprint count is {len(blueprints)}, expected 4")
    for path in blueprints:
        validate_blueprint(path, errors)

    validate_sql(BANK / "runtime" / "sqlite" / "content_schema.sql", errors)
    validate_sql(BANK / "runtime" / "sqlite" / "user_schema.sql", errors)

    if total_questions or total_stimuli or form_rows or appearance_rows:
        validate_populated_content(question_rows, stimulus_rows, form_rows, appearance_rows, errors)
        if isinstance(bank, dict) and (
            bank.get("status") != "active"
            or not isinstance(bank.get("bankVersion"), int)
            or bank.get("bankVersion", 0) < 1
        ):
            errors.append("populated V2 bank must be active at bankVersion 1 or later")
    elif isinstance(bank, dict) and (bank.get("status") != "structure-only" or bank.get("bankVersion") != 0):
        errors.append("empty V2 bank must remain structure-only at bankVersion 0")

    print(
        f"V2 structure: {len(actual_section_files)} section databases, "
        f"{len(schema_files)} schemas, {len(blueprints)} blueprints"
    )
    print(
        f"V2 content rows: questions={total_questions}, stimuli={total_stimuli}, "
        f"forms={len(form_rows)}, appearances={len(appearance_rows)}"
    )

    if errors:
        print(f"FAILED with {len(errors)} error(s):", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    if total_questions:
        print("Populated V2 validation passed: CTET Paper-I 2020 cycle is complete and internally consistent.")
    else:
        print("Clean-room V2 structure validation passed; no content imported.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

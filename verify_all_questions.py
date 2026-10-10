#!/usr/bin/env python3
"""Comprehensive 7-category audit for the bank-v2 TET question database.

Run from the repository root:

    python verify_all_questions.py

Categories
----------
1. Schema & ID validity      — record shape, required fields, option ids, id grammar.
2. Answer key validity       — answer.optionId in {a,b,c,d}, matches official appearance key.
3. Uniform answer distribution — per 30-question module; flags 100%%-single-letter and >60%% skew.
4. Bilingual completeness    — core subjects need hi+en stems and options; language papers need
                               their own locale everywhere; no blanks / N/A placeholders.
5. Clean stems               — no leaked question numbers, no trailing PART/भाग section labels,
                               no OMR/instruction leaks in options, no corrupted A/R option
                               fragments, no redundant option-label prefixes.
6. Passage-question linkage  — every stimulusId exists, no orphan stimuli, atomic groups are
                               contiguous and meet their minimum size.
7. Math rendering            — zero raw LaTeX ($...$, \\frac, \\sqrt, \\left ...).

Exit codes: 0 = clean, 1 = violations found, 2 = fatal/structural error.
"""
from __future__ import annotations

import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent
BANK = ROOT / "bank-v2"
FORMS = BANK / "paper-forms"

VALID_OPTION_IDS = ["a", "b", "c", "d"]
VALID_EXAMS = {"ctet", "utet"}
VALID_SECTIONS = {
    "cdp",
    "mathematics",
    "environmental-studies",
    "science",
    "social-studies",
    "language",
}
CORE_SECTIONS = {
    "cdp",
    "mathematics",
    "environmental-studies",
    "science",
    "social-studies",
}

# ---- Rule 2: leaked question numbers --------------------------------------
QUESTION_NUMBER_LEAK_RE = re.compile(
    r"(?:\*\*)?\b(?:Q(?:uestion|ue)?\.?\s*\d+|प्रश्न\s*\.?\s*\d+|प्र\.\s*\d+)"
    r"(?:[.)\]:\-–]|(?:\s*[-–]\s*\d+))?",
    re.IGNORECASE,
)
# Asset names in image references ("![Q56-a](images/q56_a.png)") are not prompt leaks.
IMAGE_MARKUP_RE = re.compile(r"!\[[^\]]*\]\([^)]*\)")
# A benign reference like "Q. Nos. 91-99" belongs to stimulus instructions, not stems.

# ---- Rule 3: leaked section / part labels at end of text -------------------
SECTION_ARTIFACT_RE = re.compile(
    r"(?:\s*(?:PART|भाग|SECTION|खण्ड)\s*[-–—:]\s*(?:[IVX]+|\d+)|"
    r"\s*o\s*0\s*o\s*[-–—]{1,2}\s*READ\s+THE\s+FOLLOWING\s+INSTRUCTIONS.*)\s*$",
    re.IGNORECASE,
)

# ---- Rule 5: option purity -------------------------------------------------
# A leading (1)/(2)/.../(a)/(A)... is a leaked option label unless the option is
# a statement-code combination such as "(A), (B) and (C)" / "Only (a)".
OPTION_LABEL_PREFIX_RE = re.compile(
    r"^\s*(?:\(\s*[1-4]\s*\)|[\(\[]\s*[a-d]\s*[\)\]]|\(\s*[A-D]\s*\))"
    r"\s+(?!(?:[,(]|(?:and|or|only|all|none|both|is|are|और|तथा|दोनों|व|केवल|सभी|कोई\W+नहीं)(?!\w)|सही|गलत))"
)
OMR_LEAK_RE = re.compile(
    r"READ\s+THE\s+FOLLOWING\s+INSTRUCTIONS|उत्तर\s*पत्रक|OMR",
    re.IGNORECASE,
)
# Assertion/Reason option fragments where the leading "(A)" was wrongly stripped.
CORRUPT_AR_OPTION_RE = re.compile(
    r"^(?:is\s+(?:true|false|correct)|are\s+(?:true|false)|"
    r"सही\s+है|गलत\s+है|दोनों)"
)
CORRUPT_AR_OPTION_NEED_REF = re.compile(r"\([RB]\)")

# ---- Rule 6: raw LaTeX ------------------------------------------------------
LATEX_RE = re.compile(
    r"\$[^$]+\$|\\(?:frac|dfrac|sqrt|left|right|times|div|ldots|quad|,)|\^\{?[0-9]\}?"
)

# ---- Rule 7: assertion-reasoning canonical format ---------------------------
AR_MARKER_RE = re.compile(
    r"अभिकथन|Assertion\s*(?:\(A\)|:)|कारण\s*\(R\)|तर्क\s*\(R\)|Reason\s*(?:\(R\)|:)",
    re.IGNORECASE,
)
AR_CANON_HI_RE = re.compile(r"\*\*अभिकथन \(A\):\*\*")
AR_CANON_EN_RE = re.compile(r"\*\*Assertion \(A\):\*\*")

PLACEHOLDER_RE = re.compile(r"^(?:N/?A|-|—|\.+|_+)$", re.IGNORECASE)


def load_ndjson(path: Path, errors: list[str]) -> list[dict]:
    rows: list[dict] = []
    if not path.exists():
        return rows
    for line_no, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not raw.strip():
            continue
        try:
            value = json.loads(raw)
        except Exception as exc:  # noqa: BLE001
            errors.append(f"{path.relative_to(ROOT)}:{line_no}: invalid JSON: {exc}")
            continue
        if not isinstance(value, dict):
            errors.append(f"{path.relative_to(ROOT)}:{line_no}: row is not an object")
            continue
        rows.append(value)
    return rows


def content_texts(blocks: object) -> dict[str, str]:
    texts: dict[str, str] = {}
    if not isinstance(blocks, list):
        return texts
    for block in blocks:
        if not isinstance(block, dict):
            continue
        value = block.get("text")
        if isinstance(value, dict):
            for locale, text in value.items():
                if isinstance(text, str):
                    texts[locale] = text
    return texts


def main() -> int:
    errors: list[str] = []
    warnings: list[str] = []

    question_files = sorted(BANK.glob("exams/**/questions.ndjson"))
    stimulus_files = sorted(BANK.glob("exams/**/stimuli.ndjson"))
    appearance_files = sorted(FORMS.glob("**/appearances.ndjson"))
    if not question_files:
        print("FATAL: no question files found under bank-v2/exams/", file=sys.stderr)
        return 2

    questions: list[tuple[Path, dict]] = []
    for path in question_files:
        for row in load_ndjson(path, errors):
            questions.append((path, row))
    stimuli: list[tuple[Path, dict]] = []
    for path in stimulus_files:
        for row in load_ndjson(path, errors):
            stimuli.append((path, row))
    appearances: list[dict] = []
    for path in appearance_files:
        appearances.extend(load_ndjson(path, errors))

    total_questions = len(questions)
    total_stimuli = len(stimuli)
    print("=" * 72)
    print("bank-v2 comprehensive audit — verify_all_questions.py")
    print("=" * 72)
    print(f"questions : {total_questions}")
    print(f"stimuli   : {total_stimuli}")
    print(f"appearances: {len(appearances)}")

    # ================================================================== #
    # Category 1 — Schema & ID validity                                    #
    # ================================================================== #
    seen_ids: set[str] = set()
    for path, q in questions:
        label = f"{path.relative_to(ROOT)}:{q.get('id', '<missing>')}"
        qid = q.get("id")
        if not isinstance(qid, str) or not qid:
            errors.append(f"[1-schema] {label}: missing id")
            continue
        if qid in seen_ids:
            errors.append(f"[1-schema] {label}: duplicate question id")
        seen_ids.add(qid)
        if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)+", qid):
            errors.append(f"[1-schema] {label}: id fails slug grammar")
        if q.get("exam") not in VALID_EXAMS:
            errors.append(f"[1-schema] {label}: invalid exam {q.get('exam')!r}")
        if q.get("section") not in VALID_SECTIONS:
            errors.append(f"[1-schema] {label}: invalid section {q.get('section')!r}")
        if q.get("type") not in {"single-choice", "passage-question", "poem-question", "table-question", "assertion-reason", "multiple-statement"}:
            errors.append(f"[1-schema] {label}: unexpected type {q.get('type')!r}")
        options = q.get("options")
        if not isinstance(options, list) or len(options) != 4:
            errors.append(f"[1-schema] {label}: exactly four options required")
            continue
        option_ids = [o.get("id") for o in options if isinstance(o, dict)]
        if option_ids != VALID_OPTION_IDS:
            errors.append(f"[1-schema] {label}: option ids must be a,b,c,d in order")
        answer = q.get("answer")
        if not isinstance(answer, dict) or answer.get("kind") != "single":
            errors.append(f"[1-schema] {label}: answer must be {{kind: single, optionId}}")

    # ================================================================== #
    # Category 2 — Answer key validity                                     #
    # ================================================================== #
    official_by_question: dict[str, list[str]] = defaultdict(list)
    for a in appearances:
        qid = a.get("questionId")
        if isinstance(qid, str):
            official_by_question[qid].append(str(a.get("officialOptionId", "")))

    for path, q in questions:
        label = f"{path.relative_to(ROOT)}:{q.get('id', '<missing>')}"
        qid = q.get("id")
        answer = q.get("answer")
        answer_id = answer.get("optionId") if isinstance(answer, dict) else None
        if answer_id not in VALID_OPTION_IDS:
            errors.append(f"[2-answer] {label}: answer.optionId {answer_id!r} not in a,b,c,d")
            continue
        for official in official_by_question.get(qid, []):
            if official and official != answer_id:
                errors.append(
                    f"[2-answer] {label}: answer {answer_id} != official key {official}"
                )
        review = q.get("review")
        if not isinstance(review, dict) or review.get("answerVerified") is not True:
            errors.append(f"[2-answer] {label}: review.answerVerified must be true")

    # ================================================================== #
    # Category 3 — Uniform answer distribution                             #
    # ================================================================== #
    # Group by paper form module (appearances) and by section store.
    module_answers: dict[tuple, list[str]] = defaultdict(list)
    for a in appearances:
        key = (a.get("paperFormId"), a.get("section"), a.get("language"))
        module_answers[key].append(str(a.get("officialOptionId", "")))
    for key, letters in sorted(module_answers.items()):
        counts = Counter(letters)
        n = len(letters)
        if n < 10:
            continue
        top_letter, top_count = counts.most_common(1)[0]
        if top_count == n:
            errors.append(
                f"[3-dist] {key}: all {n} answers are '{top_letter}' (default-a anomaly)"
            )
        elif top_count / n > 0.60:
            errors.append(
                f"[3-dist] {key}: answer '{top_letter}' is {top_count}/{n} "
                f"({100 * top_count / n:.0f}%) > 60% ceiling"
            )
    file_answers: dict[str, list[str]] = defaultdict(list)
    for path, q in questions:
        answer = q.get("answer")
        if isinstance(answer, dict):
            file_answers[str(path.relative_to(ROOT))].append(str(answer.get("optionId", "")))
    for key, letters in sorted(file_answers.items()):
        counts = Counter(letters)
        n = len(letters)
        if n < 10:
            continue
        top_letter, top_count = counts.most_common(1)[0]
        if top_count == n:
            errors.append(f"[3-dist] {key}: all {n} answers are '{top_letter}' (default-a anomaly)")
        elif top_count / n > 0.60:
            errors.append(
                f"[3-dist] {key}: answer '{top_letter}' is {top_count}/{n} "
                f"({100 * top_count / n:.0f}%) > 60% ceiling"
            )

    # ================================================================== #
    # Category 4 — Bilingual completeness                                  #
    # ================================================================== #
    for path, q in questions:
        label = f"{path.relative_to(ROOT)}:{q.get('id', '<missing>')}"
        section = q.get("section")
        language = q.get("language")
        if section in CORE_SECTIONS:
            expected = {"hi", "en"}
        else:
            expected = {language} if language else set()
        prompt_texts = content_texts(q.get("prompt"))
        prompt_locales = {
            loc for loc, text in prompt_texts.items() if text and text.strip()
        }
        if expected and prompt_locales != expected:
            errors.append(
                f"[4-bilingual] {label}: prompt locales {sorted(prompt_locales)} != {sorted(expected)}"
            )
        for locale, text in prompt_texts.items():
            if not text.strip() or PLACEHOLDER_RE.match(text.strip()):
                errors.append(f"[4-bilingual] {label}: blank/placeholder prompt.{locale}")
        for option in q.get("options") or []:
            if not isinstance(option, dict):
                continue
            texts = content_texts(option.get("content"))
            locales = {loc for loc, text in texts.items() if text and text.strip()}
            if expected and locales != expected:
                errors.append(
                    f"[4-bilingual] {label}: option {option.get('id')} locales "
                    f"{sorted(locales)} != {sorted(expected)}"
                )
            for locale, text in texts.items():
                if not text.strip() or PLACEHOLDER_RE.match(text.strip()):
                    errors.append(
                        f"[4-bilingual] {label}: blank/placeholder option {option.get('id')}.{locale}"
                    )

    # ================================================================== #
    # Category 5 — Clean stems & pure options                              #
    # ================================================================== #
    for path, q in questions:
        label = f"{path.relative_to(ROOT)}:{q.get('id', '<missing>')}"
        for locale, text in content_texts(q.get("prompt")).items():
            if QUESTION_NUMBER_LEAK_RE.search(IMAGE_MARKUP_RE.sub("", text)):
                errors.append(f"[5-clean] {label}: question-number leak in prompt.{locale}")
            if SECTION_ARTIFACT_RE.search(text):
                errors.append(f"[5-clean] {label}: section artifact in prompt.{locale}")
        for option in q.get("options") or []:
            if not isinstance(option, dict):
                continue
            oid = option.get("id")
            for locale, text in content_texts(option.get("content")).items():
                if QUESTION_NUMBER_LEAK_RE.search(IMAGE_MARKUP_RE.sub("", text)):
                    errors.append(f"[5-clean] {label}: question-number leak in option {oid}.{locale}")
                if SECTION_ARTIFACT_RE.search(text):
                    errors.append(f"[5-clean] {label}: section artifact in option {oid}.{locale}")
                if OMR_LEAK_RE.search(text):
                    errors.append(f"[5-clean] {label}: OMR/instruction leak in option {oid}.{locale}")
                if OPTION_LABEL_PREFIX_RE.match(text):
                    errors.append(f"[5-clean] {label}: redundant option-label prefix in {oid}.{locale}")
                if (
                    CORRUPT_AR_OPTION_RE.match(text)
                    and CORRUPT_AR_OPTION_NEED_REF.search(text)
                    and "(A)" not in text
                ):
                    errors.append(
                        f"[5-clean] {label}: corrupted Assertion/Reason option fragment in {oid}.{locale}"
                    )
                if len(text) > 320:
                    errors.append(
                        f"[5-clean] {label}: option {oid}.{locale} is {len(text)} chars — probable passage leak"
                    )

    # ================================================================== #
    # Category 6 — Passage-question linkage & atomicity                    #
    # ================================================================== #
    stimulus_ids = set()
    for path, s in stimuli:
        sid = s.get("id")
        if not isinstance(sid, str) or not sid:
            errors.append(f"[6-passage] {path.relative_to(ROOT)}: stimulus missing id")
            continue
        if sid in stimulus_ids:
            errors.append(f"[6-passage] duplicate stimulus id {sid}")
        stimulus_ids.add(sid)
        body = " ".join(content_texts(s.get("content")).values())
        if s.get("type") == "table":
            if not s.get("content"):
                errors.append(f"[6-passage] {sid}: table stimulus has no content blocks")
        elif len(body.strip()) < 30:
            errors.append(f"[6-passage] {sid}: stimulus body is empty/too short")
        if s.get("selectionPolicy") not in {"atomic", "independent"}:
            errors.append(f"[6-passage] {sid}: selectionPolicy must be atomic|independent")

    used_ids: set[str] = set()
    groups: dict[str, list[tuple[str, str]]] = defaultdict(list)  # sid -> [(file, qid)]
    for path, q in questions:
        sid = q.get("stimulusId")
        if sid is None:
            continue
        if not isinstance(sid, str) or sid not in stimulus_ids:
            errors.append(
                f"[6-passage] {path.relative_to(ROOT)}:{q.get('id')}: "
                f"stimulusId {sid!r} does not exist (orphan question)"
            )
            continue
        used_ids.add(sid)
        groups[sid].append((str(path.relative_to(ROOT)), str(q.get("id"))))
    for sid in sorted(stimulus_ids - used_ids):
        errors.append(f"[6-passage] {sid}: stimulus is never referenced (orphan stimulus)")

    stim_by_id = {s.get("id"): s for _, s in stimuli}
    for sid, members in sorted(groups.items()):
        stim = stim_by_id[sid]
        minimum = stim.get("minimumQuestions")
        if isinstance(minimum, int) and len(members) < minimum:
            errors.append(
                f"[6-passage] {sid}: {len(members)} linked questions < minimumQuestions {minimum}"
            )
        # atomic groups must live in one file and be contiguous by id
        files = {f for f, _ in members}
        if len(files) > 1:
            errors.append(f"[6-passage] {sid}: group spans multiple files {sorted(files)}")
        suffixes = sorted(qid for _, qid in members)
        nums = []
        for qid in suffixes:
            m = re.search(r"q(\d+)$", qid)
            if m:
                nums.append(int(m.group(1)))
        if nums and sorted(nums) != list(range(min(nums), max(nums) + 1)):
            errors.append(
                f"[6-passage] {sid}: group question numbers are not contiguous "
                f"({min(nums)}..{max(nums)}, {len(nums)} members)"
            )

    # ================================================================== #
    # Category 7 — Math rendering (no raw LaTeX)                           #
    # ================================================================== #
    for path, q in questions:
        label = f"{path.relative_to(ROOT)}:{q.get('id', '<missing>')}"
        for locale, text in content_texts(q.get("prompt")).items():
            if LATEX_RE.search(text):
                errors.append(f"[7-math] {label}: raw LaTeX in prompt.{locale}")
        for option in q.get("options") or []:
            if not isinstance(option, dict):
                continue
            for locale, text in content_texts(option.get("content")).items():
                if LATEX_RE.search(text):
                    errors.append(f"[7-math] {label}: raw LaTeX in option {option.get('id')}.{locale}")
    for path, s in stimuli:
        label = f"{path.relative_to(ROOT)}:{s.get('id', '<missing>')}"
        for locale, text in content_texts(s.get("content")).items():
            if LATEX_RE.search(text):
                errors.append(f"[7-math] {label}: raw LaTeX in stimulus.{locale}")

    # ---- Assertion/Reason canonical format (Rule 7, informational) --------
    for path, q in questions:
        label = f"{path.relative_to(ROOT)}:{q.get('id', '<missing>')}"
        for locale, text in content_texts(q.get("prompt")).items():
            if AR_MARKER_RE.search(text):
                canon = AR_CANON_HI_RE if locale == "hi" else AR_CANON_EN_RE
                if locale in {"hi", "en"} and not canon.search(text):
                    warnings.append(
                        f"[7-format] {label}: assertion-reason prompt.{locale} not in "
                        f"canonical **अभिकथन (A):** / **Assertion (A):** format"
                    )

    # ------------------------------------------------------------------ #
    # Report                                                              #
    # ------------------------------------------------------------------ #
    print()
    categories = Counter()
    for message in errors:
        m = re.match(r"\[(\d)-", message)
        if m:
            categories[int(m.group(1))] += 1
    for number in range(1, 8):
        count = categories.get(number, 0)
        status = "PASS" if count == 0 else f"FAIL ({count})"
        print(f"  category {number}: {status}")
    print()
    if warnings:
        print(f"warnings: {len(warnings)}")
        for message in warnings:
            print("  ", message)
        print()
    if errors:
        print(f"VIOLATIONS: {len(errors)}")
        for message in errors:
            print("  ", message)
        print()
        print("RESULT: FAIL")
        return 1
    print("RESULT: PASS — all 7 categories clean")
    return 0


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.exit(main())

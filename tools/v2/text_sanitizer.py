#!/usr/bin/env python3
"""Conservative, deterministic text cleanup shared by bank and app builders.

Only display text is changed. Question identity, option order, answer keys, source
references, and structured stimulus data are deliberately left untouched.
"""
from __future__ import annotations

import re
from typing import Any

_MARKDOWN_TABLE_SEPARATOR_CELL = re.compile(r":?-{3,}:?")
_MARKDOWN_BOLD_GAP_RE = re.compile(r"(?:\.{3,}|_{3,})")
_FILL_GAP_RE = re.compile(r"(?:\.{3,}|_{3,}|-{3,})")
_CANONICAL_GAP_RE = re.compile(r"\[\s*_{3,}\s*\]")
_ANSWER_LEAK_RE = re.compile(
    r"(?<![\w])(?:✅\s*)?(?:सही\s+उत्तर(?:\s*/\s*Correct\s+Answer)?|उत्तर|Correct\s+Answer|Answer|Ans\.?)"
    r"\s*[:\-–]\s*(?:\(\s*[1-4A-Da-d]\s*\)|[1-4A-Da-d](?=\s|[.)]|$))"
    r"[\s\S]*$",
    re.IGNORECASE,
)
_PAREN_ANSWER_LEAK_RE = re.compile(r"(?<!\S)\(\s*(?:Correct|Ans)\s*\)\s*$", re.IGNORECASE)
_EXPLANATION_HEADER_RE = re.compile(
    r"(?im)(?:^|\n)[ \t]*(?:व्याख्या|Explanation|हल|Solution)\s*[:\-–]"
)
_QUESTION_INDEX_RE = re.compile(
    r"^\s*(?:"
    r"(?:Q(?:uestion|ue)?\.?\s*\d+|प्रश्न\s*\d+|प्र\.\s*\d+)(?:[.)])?"
    r"|\d+[.:)\-–](?=\s)"
    r")\s*(?:[:\-–]\s*)?",
    re.IGNORECASE,
)
_OPTION_PREFIX_RE = re.compile(
    r"^\s*(?:"
    r"\(\s*(?P<paren>[1-4A-Da-d])\s*\)"
    r"|(?P<bare>[1-4A-Da-d])[.)]"
    r")\s+"
)
_DOUBLE_HYPHEN_RE = re.compile(r"(?<!-)-{2}(?!-)")


def _remove_markdown_artifacts(text: str, *, protect_fill_gaps: bool) -> str:
    """Remove emphasis/heading delimiters without eating underscore blanks."""
    protected: list[str] = []
    if protect_fill_gaps:
        def protect(match: re.Match[str]) -> str:
            token = f"\ufdd0TETGAP{len(protected)}\ufdd1"
            protected.append(match.group(0))
            return token

        text = _MARKDOWN_BOLD_GAP_RE.sub(protect, text)

    text = text.replace("**", "").replace("__", "").replace("###", "")
    for index, gap in enumerate(protected):
        text = text.replace(f"\ufdd0TETGAP{index}\ufdd1", gap)
    return text


def _split_markdown_row(line: str) -> list[str] | None:
    """Split a pipe-delimited table row, respecting escaped literal pipes."""
    value = line.strip()
    if "|" not in value:
        return None
    if value.startswith("|"):
        value = value[1:]
    if value.endswith("|") and not value.endswith(r"\|"):
        value = value[:-1]

    cells: list[str] = []
    cell: list[str] = []
    index = 0
    while index < len(value):
        char = value[index]
        if char == "\\" and index + 1 < len(value) and value[index + 1] == "|":
            cell.append("|")
            index += 2
            continue
        if char == "|":
            cells.append("".join(cell))
            cell = []
        else:
            cell.append(char)
        index += 1
    cells.append("".join(cell))
    return cells


def _is_markdown_table_row(line: str) -> bool:
    cells = _split_markdown_row(line)
    return cells is not None and len(cells) >= 2


def _is_markdown_table_separator(line: str) -> bool:
    cells = _split_markdown_row(line)
    return bool(
        cells
        and len(cells) >= 2
        and all(_MARKDOWN_TABLE_SEPARATOR_CELL.fullmatch(cell.strip()) for cell in cells)
    )


def _clean_table_cell(cell: str) -> str:
    value = _remove_markdown_artifacts(cell.strip(), protect_fill_gaps=True)
    value = re.sub(r"[ \t]+", " ", value).strip()
    # Pipes inside a cell must be escaped so they cannot become accidental columns.
    return value.replace("|", r"\|")


def normalize_markdown_tables(text: str) -> str:
    """Canonicalize well-formed Markdown tables without changing cell values.

    Table rows are reformatted only when a header is immediately followed by a
    valid separator row and every row has the same number of cells. Malformed
    blocks are left intact rather than silently dropping or inventing cells.
    """
    lines = text.split("\n")
    output: list[str] = []
    index = 0

    while index < len(lines):
        if (
            index + 1 < len(lines)
            and _is_markdown_table_row(lines[index])
            and _is_markdown_table_separator(lines[index + 1])
        ):
            header_cells = _split_markdown_row(lines[index]) or []
            separator_cells = _split_markdown_row(lines[index + 1]) or []
            width = len(separator_cells)
            table_end = index + 2
            data_rows: list[tuple[str, list[str]]] = [
                (lines[index], header_cells),
                (lines[index + 1], separator_cells),
            ]
            while table_end < len(lines) and _is_markdown_table_row(lines[table_end]):
                cells = _split_markdown_row(lines[table_end]) or []
                data_rows.append((lines[table_end], cells))
                table_end += 1

            if len(header_cells) == width and all(len(cells) == width for _, cells in data_rows):
                for row_number, (_, cells) in enumerate(data_rows):
                    if row_number == 1:
                        clean_cells = ["---"] * width
                    else:
                        clean_cells = [_clean_table_cell(cell) for cell in cells]
                    output.append("| " + " | ".join(clean_cells) + " |")
                index = table_end
                continue

        output.append(lines[index])
        index += 1

    return "\n".join(output)


def _normalize_horizontal_whitespace(text: str) -> str:
    text = re.sub(r"[ \t]+", " ", text)
    return "\n".join(line.rstrip() for line in text.split("\n")).strip()


def _normalize_double_hyphens(text: str) -> str:
    """Turn typographic double-hyphen punctuation into an em dash.

    Runs of three or more hyphens are reserved for fill-in-the-blank gaps and
    Markdown table rules, so they are not touched here.
    """
    return _DOUBLE_HYPHEN_RE.sub("—", text)


def sanitize_display_text(text: Any) -> str:
    """Remove Markdown display artifacts while preserving paragraph layout."""
    if not isinstance(text, str) or not text:
        return ""
    value = _remove_markdown_artifacts(text.strip(), protect_fill_gaps=True)
    value = normalize_markdown_tables(value)
    value = _normalize_double_hyphens(value)
    return _normalize_horizontal_whitespace(value)


def _strip_trailing_answer_leak(text: str) -> str:
    """Remove only explicit, terminal answer-key labels (not ordinary prose)."""
    original = text.rstrip()
    candidate = original

    # A trailing Markdown rule is often copied after a leaked key. Ignore it
    # while testing for a key, but retain it when no answer marker is present.
    rule = re.search(r"(?:\s*\n)?[ \t]*(?:-{3,}|\*{3,})[ \t]*$", candidate)
    if rule:
        candidate = candidate[: rule.start()].rstrip()

    match = _ANSWER_LEAK_RE.search(candidate)
    if match:
        return candidate[: match.start()].rstrip()
    match = _PAREN_ANSWER_LEAK_RE.search(candidate)
    if match:
        return candidate[: match.start()].rstrip()
    return original


def _looks_like_statement_explanation(text: str) -> bool:
    """Recognize assertion/reason stems where “Explanation:” is question content."""
    return bool(
        re.search(r"(?i)(?:\bstatement\s*[:(]|\bassertion\s*\(?A\)?|कथन\s*[:：]|अभिकथन\s*\(?A\)?)", text)
    )


def _strip_trailing_explanation_block(text: str) -> str:
    """Strip a standalone explanation/solution header block, not inline content."""
    match = _EXPLANATION_HEADER_RE.search(text)
    if not match:
        return text
    prefix = text[: match.start()].rstrip()
    if _looks_like_statement_explanation(prefix):
        return text
    return prefix


def _normalize_fill_gaps(text: str) -> str:
    lines = text.split("\n")
    normalized: list[str] = []
    canonical_token = "\ufdd2TETCANONICALGAP\ufdd3"
    for line in lines:
        if _is_markdown_table_separator(line):
            normalized.append(line)
            continue
        # The uniform marker itself contains underscores; protect it so running
        # the sanitizer again cannot nest brackets or grow the gap.
        line = _CANONICAL_GAP_RE.sub(canonical_token, line)
        line = _FILL_GAP_RE.sub(" [ ________ ] ", line)
        normalized.append(line.replace(canonical_token, "[ ________ ]"))
    return "\n".join(normalized)


def sanitize_question_stem(text: Any) -> str:
    """Sanitize one localized question stem conservatively and idempotently."""
    if not isinstance(text, str) or not text:
        return ""

    value = _remove_markdown_artifacts(text.strip(), protect_fill_gaps=True)
    value = normalize_markdown_tables(value)
    value = _QUESTION_INDEX_RE.sub("", value, count=1)
    value = _strip_trailing_answer_leak(value)
    value = _strip_trailing_explanation_block(value)
    value = _normalize_fill_gaps(value)
    value = _normalize_double_hyphens(value)
    value = re.sub(r"[\(（]\s*$", "", value)
    return _normalize_horizontal_whitespace(value)


def _looks_like_semantic_option_prefix(text: str, marker: str) -> bool:
    """Avoid stripping assertion/reason and list-reference answer content."""
    value = text.lstrip()
    if re.match(r"^[A-D]\.\s+[A-Z]\.\s+", value):
        # For example, A. S. Neill or B. F. Skinner.
        return True

    rest_match = _OPTION_PREFIX_RE.match(value)
    if not rest_match:
        return False
    remainder = value[rest_match.end() :]

    if re.match(r"(?i)^(?:and|or|और|या|,|/|एवं)\s*\(?\s*[A-D1-4]", remainder):
        return True

    # Assertion/reason options routinely begin with (A) and then discuss (R).
    if marker.upper() in {"A", "B"} and re.search(r"\(\s*(?:R|B|A)\s*\)", remainder[:180], re.IGNORECASE):
        if re.search(
            r"(?i)(?:\btrue\b|\bfalse\b|\bcorrect\b|\bincorrect\b|\bwrong\b|सही|गलत|सत्य|असत्य|दोनों|व्याख्या|explanation)",
            remainder[:180],
        ):
            return True
    return False


def strip_redundant_option_prefix(text: str, option_id: str | None, option_index: int) -> str:
    """Strip a label only when it unambiguously duplicates the option bubble.

    A marker must match the option's canonical position (A/1 for the first
    option, B/2 for the second, and so on). Assertion/reason references,
    enumerated combinations, and initials are retained as actual option text.
    """
    if not isinstance(text, str) or option_index not in range(4):
        return text
    match = _OPTION_PREFIX_RE.match(text)
    if not match:
        return text

    marker = (match.group("paren") or match.group("bare") or "").lower()
    expected = (option_id or chr(ord("a") + option_index)).lower()
    if expected not in {"a", "b", "c", "d"}:
        expected = chr(ord("a") + option_index)
    expected_digit = str(option_index + 1)
    if marker not in {expected, expected_digit}:
        return text
    if _looks_like_semantic_option_prefix(text, marker):
        return text

    return text[match.end() :].lstrip()


def sanitize_option_text(text: Any, option_id: str | None = None, option_index: int = -1) -> str:
    """Clean an option's display markup and remove only a confirmed bubble label."""
    if not isinstance(text, str) or not text:
        return ""
    value = sanitize_display_text(text)
    if option_index >= 0:
        value = strip_redundant_option_prefix(value, option_id, option_index)
    return _normalize_horizontal_whitespace(value)


def sanitize_stimulus_text(text: Any) -> str:
    """Clean a passage/table text block and remove a terminal leaked answer key."""
    value = sanitize_display_text(text)
    return _strip_trailing_answer_leak(value)


def sanitize_localized_map(value: Any, *, sanitizer=sanitize_display_text) -> Any:
    """Sanitize string values in a localized text map without changing its shape."""
    if not isinstance(value, dict):
        return value
    return {locale: sanitizer(text) if isinstance(text, str) else text for locale, text in value.items()}

#!/usr/bin/env python3
"""Structural and remediation regression checks for content/q_ctet.csv."""
from __future__ import annotations

import csv
import re
import sys
import unicodedata
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CSV_PATH = ROOT / "content" / "q_ctet.csv"
RESULTS_PATH = ROOT / "docs" / "ctet_paper1_repair_results.csv"
EXPECTED_FIELDS = [
    "exams", "section", "topic", "difficulty", "pid", "pseq", "p_kind",
    "p_dir", "p_body", "q_hi", "a_hi", "b_hi", "c_hi", "d_hi",
    "q_en", "a_en", "b_en", "c_en", "d_en", "ans", "source",
    "is_pyq", "years",
]
EN_FIELDS = ("q_en", "a_en", "b_en", "c_en", "d_en")
HI_OPTIONS = ("a_hi", "b_hi", "c_hi", "d_hi")
ALLOWED_SECTIONS = {"cdp", "hindi", "english", "sanskrit", "math", "evs"}
PAPER2_MARKER = re.compile(
    r"(?:paper\s*[- ]?ii|paper\s*[- ]?2|vi\s*[-–]\s*viii|class(?:es)?\s+vi)", re.I
)


def norm(value: str) -> str:
    value = unicodedata.normalize("NFKC", value or "").lower()
    return "".join(ch for ch in value if ch.isalnum())


def main() -> int:
    errors: list[str] = []
    with CSV_PATH.open(encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        if reader.fieldnames != EXPECTED_FIELDS:
            errors.append(f"schema mismatch: {reader.fieldnames!r}")
        rows = list(reader)

    for line, row in enumerate(rows, 2):
        if row["exams"] not in {"ctet1", "ctet2"}:
            errors.append(f"line {line}: invalid exams={row['exams']!r}")
        if row["section"] not in ALLOWED_SECTIONS:
            errors.append(f"line {line}: invalid section={row['section']!r}")
        if not row["q_hi"].strip():
            errors.append(f"line {line}: missing primary stem")
        if not all(row[field].strip() for field in HI_OPTIONS):
            errors.append(f"line {line}: incomplete primary options")
        if row["ans"] not in {"0", "1", "2", "3"}:
            errors.append(f"line {line}: answer index outside 0..3")
        english = [bool(row[field].strip()) for field in EN_FIELDS]
        if any(english) and not all(english):
            errors.append(f"line {line}: partial English record")
        if row["is_pyq"] not in {"0", "1"}:
            errors.append(f"line {line}: invalid is_pyq={row['is_pyq']!r}")
        if row["is_pyq"] == "1" and not row["years"].strip():
            errors.append(f"line {line}: PYQ has no year")
        if row["exams"] == "ctet1" and PAPER2_MARKER.search(row["source"]):
            errors.append(f"line {line}: Paper-II marker remains in ctet1")
        if any("परीक्षा तिथि" in row[field] for field in HI_OPTIONS):
            errors.append(f"line {line}: date metadata remains in an option")

    # Passage IDs must have exactly one body carrier and no conflicting body text.
    passages: dict[str, list[tuple[int, dict[str, str]]]] = defaultdict(list)
    for line, row in enumerate(rows, 2):
        if row["pid"]:
            passages[row["pid"]].append((line, row))
    for pid, members in passages.items():
        bodies = [(line, row["p_body"]) for line, row in members if row["p_body"].strip()]
        if len(bodies) != 1:
            errors.append(f"passage {pid}: expected one body, found {len(bodies)}")

    # Resolution ledger supplies the explicit exception set requested by the user:
    # non-CTET source rows remain independently classified even when content overlaps.
    protected_current_lines: set[int] = set()
    if not RESULTS_PATH.exists():
        errors.append("missing repair results ledger")
        result_rows: list[dict[str, str]] = []
    else:
        with RESULTS_PATH.open(encoding="utf-8-sig", newline="") as handle:
            result_rows = list(csv.DictReader(handle))
        if len(result_rows) != 1805:
            errors.append(f"repair ledger has {len(result_rows)} findings; expected 1805")
        non_ctet = [row for row in result_rows if row["issue_code"] == "scope_non_ctet_exam"]
        if len(non_ctet) != 171:
            errors.append(f"repair ledger has {len(non_ctet)} non-CTET rows; expected 171")
        for result in non_ctet:
            if result["resolution"] != "unchanged_by_user_request":
                errors.append(
                    f"original line {result['original_csv_line']}: non-CTET classification was not preserved"
                )
            if result["current_exam"] != "ctet1" or not result["current_csv_line"]:
                errors.append(
                    f"original line {result['original_csv_line']}: protected non-CTET row missing/reclassified"
                )
            else:
                protected_current_lines.add(int(result["current_csv_line"]))
        for result in result_rows:
            if result["resolution"] == "moved_to_ctet2" and result["current_exam"] != "ctet2":
                errors.append(
                    f"original line {result['original_csv_line']}: Paper-II finding not moved to ctet2"
                )
            if result["resolution"] in {"removed_unrecoverable", "consolidated_duplicate"}:
                if result["current_csv_line"] or result["current_exam"]:
                    errors.append(
                        f"original line {result['original_csv_line']}: removed record still has current mapping"
                    )

    # No option-order-independent duplicate may remain, except protected non-CTET
    # provenance records whose classification was explicitly frozen by the user.
    signatures: dict[tuple[object, ...], list[int]] = defaultdict(list)
    for line, row in enumerate(rows, 2):
        if line in protected_current_lines:
            continue
        options = [norm(row[field]) for field in HI_OPTIONS]
        answer = int(row["ans"])
        signature = (
            row["exams"], row["section"], row["pid"], norm(row["q_hi"]),
            tuple(sorted(options)), options[answer],
        )
        signatures[signature].append(line)
    duplicate_groups = [members for members in signatures.values() if len(members) > 1]
    if duplicate_groups:
        errors.append(f"{len(duplicate_groups)} semantic duplicate groups remain: {duplicate_groups[:5]}")

    exams = Counter(row["exams"] for row in rows)
    print(f"CTET validation: {len(rows)} rows; ctet1={exams['ctet1']}, ctet2={exams['ctet2']}")
    print(f"Passages: {len(passages)}; repair findings checked: {len(result_rows)}")
    if errors:
        print(f"FAILED with {len(errors)} error(s):", file=sys.stderr)
        for error in errors[:50]:
            print(f"- {error}", file=sys.stderr)
        return 1
    print("All structural, scope, passage, year, and duplicate checks passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

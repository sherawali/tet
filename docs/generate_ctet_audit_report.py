#!/usr/bin/env python3
"""Generate the archival pre-remediation CTET Paper-I audit report.

The report uses original CSV line numbers and therefore runs only against the exact
audited baseline checksum. Use ``tools/validate_ctet_content.py`` for the remediated
question bank. This utility never modifies the question bank.
"""
from __future__ import annotations

import collections
import csv
import glob
import hashlib
import os
import re
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
QUESTION_FILE = ROOT / "content" / "q_ctet.csv"
LEDGER_FILE = ROOT / "docs" / "ctet_paper1_audit_issues.csv"
REPORT_FILE = ROOT / "docs" / "CTET_PAPER1_AUDIT.md"
BASELINE_SHA256 = "597e280330093e502e8bbf2f52ac48128b068d54e6c94508aab776c71a2cef96"


def norm_build(value: str) -> str:
    return re.sub(r"\s+", "", value or "").lower()


def build_fingerprint(row: dict[str, str]) -> str:
    payload = (
        norm_build(row.get("exams", ""))
        + norm_build(row["q_hi"])
        + norm_build(row["q_en"])
        + norm_build(row["a_hi"])
    )
    return hashlib.sha1(payload.encode()).hexdigest()[:16]


def norm_semantic(value: str) -> str:
    value = unicodedata.normalize("NFKC", value or "").lower()
    return re.sub(r"[^\w\u0900-\u097f]+", "", value)


def clean_md(value: str) -> str:
    value = re.sub(r"\*\*(.+?)\*\*", r"\1", value)
    value = re.sub(r"^#+\s*", "", value, flags=re.M)
    return re.sub(r"\s+", " ", value).strip()


def paper2_rows_from_markdown(rows_by_line: dict[int, dict[str, str]]) -> set[int]:
    """Recover Paper-II provenance hidden/lost during Markdown conversion.

    A row is accepted only when its bank label, source question number and normalized
    stem match a source Markdown block that has a Paper-II/(VI-VIII) marker and no
    Paper-I/(I-V) marker in that same block.
    """
    p2_pattern = re.compile(
        r"(?:\b(?:II|IInd|2nd|Second)\s*[-_]?\s*Paper|"
        r"Paper\s*[-_]?\s*II\b|\(VI\s*[–-]\s*VIII?\)|"
        r"\bCTET\s*II\b|C\s*TET\s*\(VI)",
        re.I,
    )
    p1_pattern = re.compile(
        r"(?:\b(?:I|Ist|1st|First)\s*[-_]?\s*Paper|"
        r"Paper\s*[-_]?\s*I\b|\(I\s*[–-]\s*V\)|"
        r"\bCTET\s*I\b|C\s*TET\s*\(I)",
        re.I,
    )
    labels = {
        "CTET CDP Questiins for Paper-1.md": "CTET Bank CDP Questiins for Paper-1",
        "CTET Evs Notes and Pedagogy.md": "CTET Bank Evs Notes and Pedagogy",
        "CTET Maths Pedagogy Questions Paper 2_watermark.md": "CTET Bank Maths Pedagogy Questions Paper 2",
        "CTET Hindi Language_ Pedagogy.md": "CTET Bank Hindi Language_ Pedagogy",
        "CTET-Pedagogy of English Language _watermark.md": "CTET Bank Pedagogy of English Language",
    }

    source_blocks: dict[tuple[str, int], list[tuple[str, set[str]]]] = collections.defaultdict(list)
    for path in (ROOT / "ctet-questions").glob("*.md"):
        if path.name not in labels:
            continue
        current: list[str] = []
        lines = path.read_text(encoding="utf-8").splitlines() + ["### प्रश्न 999999"]
        for line in lines:
            if line.startswith("### प्रश्न "):
                if current:
                    head, body = current[0], current[1:]
                    match = re.match(r"### प्रश्न (\d+)", head)
                    stem_lines: list[str] = []
                    options_started = False
                    after_answer = False
                    for body_line in body:
                        if re.match(r"^- \*\*\([a-d1-4]\)\*\*", body_line):
                            options_started = True
                        elif re.match(r"^\*\*उत्तर:", body_line):
                            after_answer = True
                        elif (
                            not options_started
                            and not after_answer
                            and body_line.strip()
                            and not body_line.startswith("> ")
                        ):
                            stem_lines.append(body_line)
                    if match:
                        block_text = "\n".join(current)
                        provenance: set[str] = set()
                        if p2_pattern.search(block_text):
                            provenance.add("p2")
                        if p1_pattern.search(block_text):
                            provenance.add("p1")
                        source_blocks[(labels[path.name], int(match.group(1)))].append(
                            (clean_md(" ".join(stem_lines)), provenance)
                        )
                current = [line]
            elif current:
                current.append(line)

    result: set[int] = set()
    for line_no, row in rows_by_line.items():
        if row["exams"] != "ctet1":
            continue
        source_match = re.match(r"(.+?) Q(\d+)(?:\s|$)", row["source"])
        if not source_match:
            continue
        key = (source_match.group(1), int(source_match.group(2)))
        matched_provenance: set[str] = set()
        q_values = [norm_semantic(row["q_hi"]), norm_semantic(row["q_en"])]
        for source_stem, provenance in source_blocks.get(key, []):
            source_norm = norm_semantic(source_stem)
            if len(source_norm) < 20:
                continue
            if any(
                len(q_norm) >= 20
                and (q_norm == source_norm or q_norm in source_norm or source_norm in q_norm)
                for q_norm in q_values
            ):
                matched_provenance.update(provenance)
        if "p2" in matched_provenance and "p1" not in matched_provenance:
            result.add(line_no)
    return result


def main() -> None:
    digest = hashlib.sha256(QUESTION_FILE.read_bytes()).hexdigest()
    if digest != BASELINE_SHA256:
        raise SystemExit(
            "This archival report generator requires the pre-remediation q_ctet.csv "
            f"baseline ({BASELINE_SHA256}); current checksum is {digest}. "
            "Run tools/validate_ctet_content.py for the repaired bank."
        )

    all_rows: list[dict[str, str]] = []
    rows_by_line: dict[int, dict[str, str]] = {}
    with QUESTION_FILE.open(encoding="utf-8", newline="") as handle:
        for line_no, row in enumerate(csv.DictReader(handle), 2):
            row["_line"] = str(line_no)
            all_rows.append(row)
            rows_by_line[line_no] = row
    paper1_rows = [row for row in all_rows if row["exams"] == "ctet1"]

    issues: list[dict[str, str]] = []

    def add(
        line_no: int,
        severity: str,
        code: str,
        fields: str,
        finding: str,
        recommendation: str,
        related: str = "",
    ) -> None:
        row = rows_by_line[line_no]
        issues.append(
            {
                "csv_line": str(line_no),
                "source": row["source"],
                "section": row["section"],
                "severity": severity,
                "issue_code": code,
                "affected_fields": fields,
                "finding": finding,
                "recommended_action": recommendation,
                "related_lines": related,
            }
        )

    # Paper-II / upper-primary contamination visible directly in CSV metadata.
    p2_visible_pattern = re.compile(
        r"(?:\bII\s*-?\s*Paper|\bI\s*-?\s*Paper\s*\(VI|"
        r"\(VI\s*[–-]\s*VIII?\)|IInd\s+Paper)",
        re.I,
    )
    p2_visible = {
        int(row["_line"])
        for row in paper1_rows
        if p2_visible_pattern.search(row["source"])
        or p2_visible_pattern.search(row["d_hi"])
    }
    p2_source_match = paper2_rows_from_markdown(rows_by_line)
    p2_confirmed = p2_visible | p2_source_match
    for line_no in sorted(p2_confirmed):
        if line_no in p2_visible:
            finding = (
                "Row is classified as ctet1, but its CSV source/option metadata explicitly says "
                "Paper II or Classes VI-VIII."
            )
            code = "scope_paper2_visible"
        else:
            finding = (
                "Row is classified as ctet1, but its bank label, question number, and normalized "
                "stem match a source Markdown block marked Paper II/Classes VI-VIII, with no "
                "Paper-I marker in that block."
            )
            code = "scope_paper2_source_match"
        add(
            line_no,
            "high",
            code,
            "exams,source",
            finding,
            "Move to ctet2 or remove from the Paper-I bank after provenance review.",
        )

    # Five additional upper-primary/class VI-VIII stems not covered by explicit source matching.
    p2_probable = {554, 1656, 4905, 5474, 5945} - p2_confirmed
    for line_no in sorted(p2_probable):
        add(
            line_no,
            "high",
            "scope_upper_primary_probable",
            "exams,q_hi,q_en",
            "The stem explicitly targets upper-primary or Class VI/VII/VIII while the row is ctet1.",
            "Review provenance; move to ctet2 unless the official Paper-I source is verified.",
        )

    # Other TETs represented as CTET Paper-I rows.
    for line_no, row in rows_by_line.items():
        if row["exams"] != "ctet1":
            continue
        source_tag = re.search(r"\[([^\]]+)\]", row["source"])
        if source_tag and "CTET" not in source_tag.group(1).upper():
            add(
                line_no,
                "medium",
                "scope_non_ctet_exam",
                "exams,source,is_pyq,years",
                f"Source tag identifies a non-CTET exam: [{source_tag.group(1)}].",
                "Keep only if cross-TET practice is intentional; otherwise remove from the CTET bank or relabel exam provenance.",
            )

    wrong_answers = {
        24: "Stored d; correct a — development of symbolic thought is not a limitation of preoperational thought.",
        39: "Stored b; correct d — the discovery activity uses the inductive method.",
        52: "Stored a; correct b — assessment should not focus on precision in answers.",
        69: "Stored c; correct b — the described family-teaching approach is not inclusive.",
        76: "Stored d; correct b — BALA means Building as Learning Aid.",
        78: "Stored d; correct b — ‘Women are weaker than men’ is a stereotype.",
        82: "Stored c; correct b — NCF-2000 recommended integrated EVS across the primary stage.",
        305: "Stored b; correct a — school and neighbourhood are secondary socialisation agents.",
        642: "Stored b; correct c — learning disability is a variable state.",
        1245: "Stored c; correct b — flooding deprives roots of oxygen and root respiration stops.",
        3937: "Stored d; correct c — NCF-2000 is the correct option in this ordering.",
        6698: "Stored b; correct c — language learnt without deliberate practice is acquisition.",
    }
    for line_no, finding in wrong_answers.items():
        add(
            line_no,
            "critical",
            "wrong_answer_key",
            "ans",
            finding,
            "Correct the key after recording a source citation and regression test.",
        )

    add(
        172,
        "high",
        "wrong_option_text",
        "d_hi,d_en",
        "The official Feb-2015 item has ‘6 to 11 years’; this row says ‘9 to 12 years’.",
        "Replace option d in both languages with 6 to 11 years and retain d as the key.",
        "4518",
    )
    add(
        3947,
        "critical",
        "corrupt_options_no_correct_answer",
        "a_hi,b_hi,c_hi,d_hi,a_en,b_en,c_en,d_en,ans",
        "A 10 kg mass has Earth weight about 98 N, but no current option is correct; duplicate line 62 preserves 97.993 N.",
        "Restore the option set from the verified duplicate and realign the answer key.",
        "62",
    )

    missing_visuals = {
        42: "Number-line point labels A/B are absent.",
        47: "The rectangle/grid is absent.",
        49: "The pie chart is absent.",
        54: "The child’s worked subtraction is absent.",
        3909: "The child’s worked subtraction is absent.",
        3924: "The number line and point labels are absent.",
        3929: "The rectangle/grid is absent.",
        3931: "The pie chart is absent.",
        4688: "The board diagram with circles is absent.",
        4689: "The referenced rectangle figure is absent.",
        4717: "All three clock/animal figures are absent.",
        5387: "The dot-array diagrams are absent.",
        5855: "The square-paper grid is absent.",
        5860: "The shape cards are absent.",
        6004: "The sample decimal-multiplication grid is absent.",
        6009: "The cubical-block solid is absent.",
        6039: "The Venn diagram defining X is absent.",
        6175: "The two garbage heaps are absent.",
        6298: "The shaded square figure is absent and the Hindi stem is truncated.",
    }
    for line_no, finding in missing_visuals.items():
        add(
            line_no,
            "critical",
            "missing_visual_stimulus",
            "q_hi,q_en",
            finding + " The CSV schema has no media reference, and no Markdown image asset exists upstream.",
            "Restore the original figure and add a supported media/alt-text representation, or remove the item.",
        )

    expression_loss = {
        43: "Mixed fractions and packet size are flattened (3 1/4 and 1/16 are not represented correctly).",
        3702: "The Hindi stem loses the initial 100; only English preserves the complete expression.",
        3703: "The Hindi stem loses the alternating-sum expression.",
        3925: "Both languages flatten 3 1/4 kg and 1/16 kg.",
        3933: "The Hindi stem loses the complete alternating-sum expression.",
        4143: "Both languages flatten 1/4 and 1/3 as ‘1 4’ and ‘1 3’.",
        4552: "The dividend/mixed number is lost; displayed English asks 5 ÷ 1/10, whose answer 50 is absent.",
        5174: "The quantities 7 1/2 kg and 1/12 kg are flattened/misordered.",
        5381: "Hindi flattens 1/3 as ‘3 1’; English is recoverable.",
        5529: "Hindi loses the equation 72 × 28 = 36 × 4 × blank.",
        5723: "Hindi flattens mixed fractions (including 4 1/2 and 1 3/4); English is truncated.",
        5866: "Hindi flattens 4 1/2 hours; English is shortened and omits later data.",
        5873: "The dividend’s fractional part is lost; displayed 3 ÷ 1/6 conflicts with the stored answer.",
        6026: "The dividend 1/2 is flattened to 1; displayed 1 ÷ 1/8 conflicts with the stored answer.",
        6160: "Hindi fraction notation is flattened; English preserves 3/5 and 3/7.",
        6168: "Hindi loses all fraction bars in the erroneous addition; English preserves 1/2 + 1/3 = 2/5.",
        6452: "Hindi flattens 1/2 cm; English is recoverable.",
    }
    for line_no, finding in expression_loss.items():
        add(
            line_no,
            "critical" if line_no in {43, 3925, 4552, 5174, 5723, 5873, 6026} else "high",
            "math_expression_lost",
            "q_hi,q_en",
            finding,
            "Restore the original expression with unambiguous Unicode or LaTeX-style serialization and revalidate the key.",
        )

    incomplete_tables = {
        1656: "The experiment table containing A and B is absent.",
        3699: "The blood-group table contains no group counts.",
        4122: "The vegetable ‘price list’ contains quantities but no prices.",
        4738: "The Ahmedabad–Nagercoil diary/table omits data needed to verify distance statement A.",
        4856: "The marks table has subject headings but no marks.",
        5523: "The railway table omits Chennai arrival time.",
        6330: "The railway table omits the distance/day values needed to answer the distance part.",
        6599: "The cuboid table loses the length, breadth and height values for each box.",
    }
    for line_no, finding in incomplete_tables.items():
        add(
            line_no,
            "critical",
            "incomplete_table_or_data",
            "q_hi,q_en",
            finding,
            "Restore the complete table/data from the original paper and verify all options and the key.",
        )

    merged_rows = {
        816, 1641, 1693, 3694, 3737, 3756, 3835, 4858, 5195, 5197,
        5276, 5734, 6055, 6147, 6154,
    }
    for line_no in sorted(merged_rows):
        add(
            line_no,
            "critical",
            "stem_option_code_merged",
            "q_hi,a_hi,b_hi,c_hi,d_hi,q_en,a_en,b_en,c_en,d_en",
            "Statements/activities and answer-code choices have been fused into the same option fields, omitted, or split across languages; the item is not reliably answerable as stored.",
            "Reconstruct statement labels and four answer-code options from the original paper in both languages.",
        )

    label_artifacts = {
        3673, 3679, 3740, 3742, 3747, 3752, 5125, 5126, 5131, 5139,
        5191, 5199, 5204, 5209,
    }
    for line_no in sorted(label_artifacts):
        add(
            line_no,
            "medium",
            "assertion_reason_label_artifact",
            "q_hi,q_en,a_hi,b_hi,c_hi,d_hi,a_en,b_en,c_en,d_en",
            "Assertion/reason labels such as stray ‘(A)’, duplicated labels, or slash fragments remain in the rendered text.",
            "Remove parser artifacts while preserving the four standard assertion–reason choices.",
        )

    duplicated_options = {
        656: "English options c and d are both ‘child/system’; Hindi d is child/environment.",
        3677: "English options c and d are duplicated; Hindi d has a different meaning.",
        3772: "Choices c and d both say that R is the correct explanation; one must say ‘not the correct explanation’.",
        4548: "Abbreviated English options a and c are indistinguishable.",
        4551: "Three English choices are the same truncated phrase.",
        4717: "English choices c and d are indistinguishable after truncation.",
        5381: "English choices a and d are indistinguishable after truncation.",
        5396: "English choices a and d are indistinguishable after truncation.",
        5869: "English options b and c are both 262.6; Hindi c is 26.026.",
        6605: "All four Hindi options are the identical unit ‘मी/से’; every numeric value was lost.",
    }
    for line_no, finding in duplicated_options.items():
        add(
            line_no,
            "critical" if line_no in {3772, 6605} else "high",
            "duplicate_or_lost_option",
            "a_hi,b_hi,c_hi,d_hi,a_en,b_en,c_en,d_en",
            finding,
            "Restore distinct complete options from the source and revalidate the answer index.",
        )

    bilingual_mismatches = {
        623: "Hindi contains unrelated chapter material and asks about RTE 2009; English asks about two child-freedom principles.",
        1398: "Hindi ultimately asks for India’s national river (answer Ganga); English asks which river Lucknow is on (answer Gomti), after large unrelated lists.",
        1551: "Hindi asks which conditions construct EVS knowledge; English asks which item is an EVS theme.",
        1641: "English removes the teacher’s accept/reject setup and turns the item into a different vague question.",
        1693: "Hindi asks which 5Es are not included; English asks which activity represents Explore.",
        5384: "Hindi describes a child’s Van Hiele level; English asks for the highest listed level.",
        5399: "Hindi asks mountain-group leader duties; English asks duties of a responsible passenger.",
        6436: "Hindi option c gives reversal errors and d gives ADHD-like behaviour; English c/d contain different propositions.",
    }
    for line_no, finding in bilingual_mismatches.items():
        add(
            line_no,
            "critical",
            "bilingual_semantic_mismatch",
            "q_hi,q_en,a_hi,b_hi,c_hi,d_hi,a_en,b_en,c_en,d_en",
            finding,
            "Re-translate from one verified canonical question and align option meanings and key across languages.",
        )

    garbage_stems = {
        148, 623, 787, 830, 1398, 1551, 1582, 1912, 2764, 5384,
    }
    for line_no in sorted(garbage_stems):
        add(
            line_no,
            "high",
            "unrelated_preamble_or_ocr_garbage",
            "q_hi,q_en",
            "The stem includes unrelated chapter headings, preceding explanations/questions, lists, or OCR debris before the actual question.",
            "Delete unrelated text and retain one complete canonical stem only.",
        )

    add(
        3776,
        "high",
        "invalid_answer_code",
        "b_hi,b_en",
        "Option b uses A-vi although the matching list defines only i-v; the Hindi duplicate at line 3806 has A-iv.",
        "Replace A-vi with A-iv after checking the original paper.",
        "3806",
    )

    # Truncated English translations/options. The q_en heuristic deliberately targets
    # summaries much shorter than complete Hindi stems and excludes ordinary fill blanks.
    truncated_options: set[int] = set()
    truncated_questions: set[int] = set()
    for row in paper1_rows:
        line_no = int(row["_line"])
        if any(row[field].strip().endswith("...") for field in ("a_en", "b_en", "c_en", "d_en")):
            truncated_options.add(line_no)
        english = row["q_en"].strip()
        hindi = row["q_hi"].strip()
        if (
            "..." in english
            and len(english) < 0.72 * len(hindi)
            and "..." not in hindi
            and "........." not in english
            and line_no not in {5026, 5827}
        ):
            truncated_questions.add(line_no)
    for line_no in sorted(truncated_questions):
        add(
            line_no,
            "high",
            "english_stem_truncated",
            "q_en",
            "English is an ellipsis-based summary that omits statements, values, conditions, or the actual task present in Hindi.",
            "Provide a complete faithful English translation or leave English unavailable rather than serving an incomplete item.",
        )
    for line_no in sorted(truncated_options):
        add(
            line_no,
            "high",
            "english_option_truncated",
            "a_en,b_en,c_en,d_en",
            "One or more English options end in ‘...’ and omit substantive distinguishing text.",
            "Restore complete option translations and check that all four remain distinct.",
        )

    # Underlining was already absent in the source Markdown, so these targets are not
    # recoverable from the repository. Exclude two uses of 'underline' as an ordinary verb.
    underlining_rows: set[int] = set()
    underline_pattern = re.compile(r"underlin|रेखांकित|रेखांक|अधोरेख", re.I)
    for row in paper1_rows:
        line_no = int(row["_line"])
        if line_no in {4454, 5267}:
            continue
        if underline_pattern.search(row["q_hi"] + " " + row["q_en"]):
            underlining_rows.add(line_no)
    for line_no in sorted(underlining_rows):
        add(
            line_no,
            "high",
            "missing_underlining_target",
            "q_hi,q_en",
            "The question asks about an underlined word/expression, but plain text does not identify which token was underlined.",
            "Recover the target from an original scan and encode it explicitly (for example, with a target span or quoted target field).",
        )

    # Nine visible date/shift annotations appended to an option. Paper-II tags in d_hi
    # are already described by scope_paper2_visible.
    option_date_noise = {3671, 4088, 4296, 4657, 5011, 5335, 5826, 6268, 6416}
    for line_no in sorted(option_date_noise):
        add(
            line_no,
            "medium",
            "option_metadata_leak",
            "a_hi,b_hi,c_hi,d_hi",
            "Exam date and/or shift metadata is appended to one answer option.",
            "Move provenance to source/years and remove it from the option text.",
        )

    # Duplicate behaviour in the real build: exact fingerprint duplicates are dropped,
    # but normalized reordered/formatted duplicates survive.
    seen: dict[str, tuple[str, int]] = {}
    build_rows: list[dict[str, str]] = []
    exact_duplicate_pairs: list[tuple[dict[str, str], tuple[str, int]]] = []
    for file_name in sorted(glob.glob(str(ROOT / "content" / "q_*.csv"))):
        with open(file_name, encoding="utf-8", newline="") as handle:
            for line_no, row in enumerate(csv.DictReader(handle), 2):
                if not row.get("q_hi", "").strip():
                    continue
                row["_line"] = str(line_no)
                row["_file"] = os.path.basename(file_name)
                fingerprint = build_fingerprint(row)
                if fingerprint in seen:
                    exact_duplicate_pairs.append((row, seen[fingerprint]))
                else:
                    seen[fingerprint] = (row["_file"], line_no)
                    build_rows.append(row)
    for duplicate, original in exact_duplicate_pairs:
        if duplicate["_file"] != "q_ctet.csv" or duplicate["exams"] != "ctet1":
            continue
        line_no = int(duplicate["_line"])
        add(
            line_no,
            "low",
            "exact_duplicate_auto_dropped",
            "q_hi,q_en,a_hi,source",
            "The raw CSV repeats an earlier build fingerprint; tools/build.py silently drops this row.",
            "Remove/consolidate the raw duplicate and merge useful provenance.",
            f"{original[0]}:{original[1]}",
        )

    residual_groups: dict[tuple[str, tuple[str, ...]], list[dict[str, str]]] = collections.defaultdict(list)
    for row in build_rows:
        if row["exams"] != "ctet1":
            continue
        key = (
            norm_semantic(row["q_hi"]),
            tuple(sorted(norm_semantic(row[f"{letter}_hi"]) for letter in "abcd")),
        )
        if key[0] and all(key[1]):
            residual_groups[key].append(row)
    for group in residual_groups.values():
        if len(group) < 2:
            continue
        original = group[0]
        for duplicate in group[1:]:
            if duplicate["_file"] != "q_ctet.csv":
                continue
            line_no = int(duplicate["_line"])
            add(
                line_no,
                "medium",
                "duplicate_survives_build",
                "q_hi,a_hi,b_hi,c_hi,d_hi,source",
                "Same normalized Hindi stem and option set survives because option order or formatting defeats the current fingerprint.",
                "Consolidate the pair and make deduplication order-insensitive while preserving the correct answer mapping.",
                f"{original['_file']}:{original['_line']}",
            )

    # PYQ rows whose missing year affects p_score recency.
    for row in paper1_rows:
        if row["is_pyq"] == "1" and not row["years"].strip():
            add(
                int(row["_line"]),
                "medium",
                "pyq_year_missing",
                "years",
                "Row is marked PYQ but years is blank, so year-based scoring/filters lose provenance.",
                "Populate the normalized YYYY or YYYY-MM value from source metadata.",
            )

    severity_rank = {"critical": 0, "high": 1, "medium": 2, "low": 3}
    issues.sort(key=lambda item: (int(item["csv_line"]), severity_rank[item["severity"]], item["issue_code"]))
    fieldnames = [
        "csv_line", "source", "section", "severity", "issue_code",
        "affected_fields", "finding", "recommended_action", "related_lines",
    ]
    with LEDGER_FILE.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(issues)

    by_code = collections.Counter(issue["issue_code"] for issue in issues)
    unique_lines = {int(issue["csv_line"]) for issue in issues}
    severity_counts = collections.Counter(issue["severity"] for issue in issues)
    confirmed_sections = collections.Counter(rows_by_line[line]["section"] for line in p2_confirmed)
    duplicate_exact = by_code["exact_duplicate_auto_dropped"]
    duplicate_survives = by_code["duplicate_survives_build"]

    wrong_answer_table = "\n".join(
        f"| `{line}` | {rows_by_line[line]['source']} | {detail} |"
        for line, detail in wrong_answers.items()
    )
    report = f"""# CTET Paper-I question-bank quality audit

**Audit target:** `content/q_ctet.csv`  
**Line-number convention:** all `L…` references are physical CSV lines, including the header.  
**Database state:** this audit did **not** modify any question-bank row or source Markdown file.

## Executive conclusion

The Paper-I bank is **not ready to ship without cleanup**. All **5,075** rows labelled `ctet1` were checked structurally and by targeted semantic/provenance review. The row-level ledger contains **{len(issues):,} findings affecting {len(unique_lines):,} unique rows** (overlap is intentional when one row has several defects).

The highest-risk results are:

- **{len(p2_confirmed):,} confirmed Paper-II/upper-primary-origin rows** are labelled `ctet1` ({confirmed_sections.get('hindi', 0)} Hindi, {confirmed_sections.get('cdp', 0)} CDP). Of these, **{len(p2_visible):,}** expose the Paper-II/VI-VIII marker directly in CSV and **{len(p2_source_match - p2_visible):,}** more were recovered by matching bank label + question number + normalized stem to a source Markdown block marked Paper II/VI-VIII with no Paper-I marker. Another **{len(p2_probable)}** rows explicitly target upper-primary/Class VI-VIII and need provenance review.
- **171 rows** carry source tags from non-CTET exams (UP/MP/UK/Jharkhand TET or UP Aided JHS) while being stored as CTET Paper-I. This may be intentional cross-TET practice, but it is incorrect if `ctet1` is meant to mean CTET-only.
- **12 definite wrong answer keys** were corroborated by duplicate official-paper variants and/or external references.
- **{len(missing_visuals)} questions lack a required figure/diagram**, **{len(expression_loss)} have lost mathematical expressions**, and **{len(incomplete_tables)} have incomplete tables/data**.
- **{len(merged_rows)} rows have statements or answer-code choices merged into option fields**; line 6605 loses every Hindi numeric option.
- **{len(truncated_questions | truncated_options)} rows have a truncated English stem and/or option**, and **{len(underlining_rows)} questions refer to underlining that is not encoded anywhere in the repository**.
- The raw Paper-I CSV has **{duplicate_exact} exact duplicate rows that the builder silently drops**; **{duplicate_survives} additional duplicate instances survive the current build fingerprint**.
- **{by_code['pyq_year_missing']} `is_pyq=1` rows have no `years` value**, so chronology-based filters/scoring are degraded.

The complete question-level findings are in [`ctet_paper1_audit_issues.csv`](ctet_paper1_audit_issues.csv).

## Definite answer-key errors

| CSV line | Source | Finding / correction |
|---:|---|---|
{wrong_answer_table}

In addition, **L172** has a corrupted option (`9 to 12 years` instead of official `6 to 11 years`), and **L3947** has no correct option (its duplicate at L62 preserves approximately `98 N`). L4552, L5873 and L6026 display calculations inconsistent with their keys because source fractions/mixed numbers were lost; these are expression-reconstruction defects rather than safe one-field key fixes.

## Content corruption by category

### Missing visual stimuli ({len(missing_visuals)})

`{', '.join('L' + str(line) for line in sorted(missing_visuals))}`

No Markdown image objects/assets exist for these questions upstream. A text-only option is acceptable only when it fully describes the original figure; these rows do not.

### Lost mathematical expressions ({len(expression_loss)})

`{', '.join('L' + str(line) for line in sorted(expression_loss))}`

Typical failures are flattened fractions (`1/16` → `16`, `1/2` → `1`), missing alternating sums, and a Hindi stem losing an equation that survives only in English.

### Incomplete tables/data ({len(incomplete_tables)})

`{', '.join('L' + str(line) for line in sorted(incomplete_tables))}`

These omit the values needed to calculate or select an answer (blood-group counts, prices, marks, dimensions, distances, or arrival times).

### Merged statements and answer codes ({len(merged_rows)})

`{', '.join('L' + str(line) for line in sorted(merged_rows))}`

The parser has combined statements such as A/B/C with code choices such as “A and C”, sometimes differently in Hindi and English.

### Other confirmed field-level corruption

- **Identical/lost options:** `{', '.join('L' + str(line) for line in sorted(duplicated_options))}`
- **Material Hindi/English mismatch:** `{', '.join('L' + str(line) for line in sorted(bilingual_mismatches))}`
- **Unrelated preamble/OCR garbage:** `{', '.join('L' + str(line) for line in sorted(garbage_stems))}`
- **Assertion/reason label debris:** `{', '.join('L' + str(line) for line in sorted(label_artifacts))}`
- **Date/shift text appended to an option:** `{', '.join('L' + str(line) for line in sorted(option_date_noise))}`
- **Invalid matching code `A-vi`:** L3776 (only i-v are defined).

## Structural checks that passed

- All 5,075 Paper-I rows have a non-empty primary stem, four non-empty primary option fields, and an answer index in `0..3`.
- The passage structure is internally linked: 813 question rows use 111 passage IDs; each passage ID has one populated body and no question references a missing passage.
- Hindi-language rows intentionally have no English mirror; there are no *partial* English records—English is either absent for the whole item or present in all five stem/option fields. Presence alone does not imply quality, as the truncation findings show.
- The five Sanskrit rows (L5117-L5121) are legitimate Paper-I language-alternative content, but five items are too few for meaningful Sanskrit delivery if the product exposes that section.

## Systemic metadata/design defects

- Every Paper-I row has `difficulty=2`; difficulty selection cannot work meaningfully.
- Topics are only broad `CTET अभ्यास` / `CTET विगत वर्ष` buckets, not syllabus topics, so topic-balanced mocks cannot be generated from this file.
- 389 PYQ rows lack `years` (145 `CTET 2018`, 114 Jan-2023, 73 Hindi-bank, 33 EVS-bank, 23 CDP-bank, and one July-2024 row).
- The current build fingerprint uses only `exams + q_hi + q_en + a_hi`; it is option-order-sensitive and ignores options b-d, answer, and provenance. It drops {duplicate_exact} raw Paper-I rows but leaves {duplicate_survives} normalized duplicates.

## Verification notes and references

The 146 short `CTET 2018` records were aligned against their detailed December-2018 duplicates with option-order mapping. Six key errors came directly from those paired records. Additional disputed/high-risk items were checked against the following references:

- [Pythagoras activity — inductive method](https://testbook.com/question-answer/to-teach-the-pythagoras-theorem-a-teacher-has-dis--5de4fa42f60d5d59b90efe7b)
- [Secondary agents of socialisation](https://testbook.com/question-answer/which-of-the-following-are-secondary-agents-of-soc--5dea32b7f60d5d0e31eb3a95)
- [NCF-2000 and integrated EVS](https://testbook.com/question-answer/which-national-curriculum-framework-ncf-recommen--5dd3f6def60d5d4aeb58e377)
- [Flooding, oxygen deprivation and root respiration](https://pmc.ncbi.nlm.nih.gov/articles/PMC4244999/)
- [Language acquisition without deliberate practice](https://testbook.com/question-answer/when-language-is-learnt-without-practice-it-is-ca--62dfa94953fac85338650157)
- [Learning disability as a variable state](https://testbook.com/question-answer/children-with-learning-disabilities--5f1953395328660d122594e8)
- [Later childhood in the Feb-2015 item](https://testbook.com/question-answer/which-of-the-following-age-groups-falls-under-late--609cfc08fc974eccbef32f3f)

For the stereotype item, some answer mirrors say “myth”; the detailed local December-2018 source and the standard pedagogical definition support **stereotype**, so the audit marks the current key wrong.

## Recommended remediation order

1. **Quarantine the {len(p2_confirmed)} confirmed Paper-II/upper-primary rows** and review the five probable rows.
2. Fix the 12 definite keys, L172, L3947, line 6605, and all missing visual/expression/table records before users see them.
3. Reconstruct merged statement/code items and restore explicit formatting targets for “underlined” questions.
4. Replace truncated translations; do not serve an English item merely because all English fields are non-empty.
5. Consolidate duplicates and change fingerprinting to normalized stem + the complete option set, with answer remapping when option order changes.
6. Populate `years`, granular syllabus topics, and real difficulty values; add automated validation for duplicate options, metadata leakage, Paper-II markers, visual references without assets, and assertion/reason code templates.

## Limits

This was a row-by-row structural/provenance audit plus targeted semantic verification of duplicate conflicts and high-risk records. It does not claim an independent authoritative re-solve of every one of the 5,075 pedagogy, language, EVS and mathematics facts. Accordingly, only corroborated key errors are labelled “definite”; suspicious but unrecoverable records are labelled as corruption and should be checked against original CTET scans/official keys.
"""
    REPORT_FILE.write_text(report, encoding="utf-8")

    print(f"wrote {LEDGER_FILE.relative_to(ROOT)}: {len(issues)} findings, {len(unique_lines)} unique rows")
    print(f"wrote {REPORT_FILE.relative_to(ROOT)}")
    print("severity:", dict(severity_counts))
    print("top issue codes:", by_code.most_common(20))


if __name__ == "__main__":
    main()

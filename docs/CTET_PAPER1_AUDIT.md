# CTET Paper-I question-bank quality audit

**Audit target:** the pre-remediation snapshot of `content/q_ctet.csv`  
**Line-number convention:** all `L…` references below are **original baseline** CSV lines, including the header; they are not current line numbers.  
**Audit ledger:** [`ctet_paper1_audit_issues.csv`](ctet_paper1_audit_issues.csv) is the immutable baseline finding list.

## Remediation status (2026-10-04)

The audit findings have been remediated in the current question bank:

- `q_ctet.csv` now has **6,344** rows: **4,035 `ctet1`** and **2,309 `ctet2`**.
- All **494 confirmed** and **5 probable** upper-primary rows were processed as Paper II. **498 remain in `ctet2`**; the one incomplete-table record was removed as unrecoverable. Subject `section` values were preserved.
- The **171 non-CTET source rows** remain independently stored and classified as requested.
- Verified key, option, formula, merged-field, bilingual, OCR, assertion/reason, date-noise and year defects were repaired. Incomplete English mirrors were disabled rather than served as misleading translations.
- **80 unrecoverable rows** were removed (missing figures, tables, underlining targets, or inseparable merged questions), including eight equivalent defects found in the pre-existing `ctet2` bank during regression checks.
- **578 duplicate rows** were consolidated with PYQ years and passage bodies preserved. Two exact CTET/non-CTET provenance overlaps remain deliberately separate in the source CSV to honour the classification decision; the builder deduplicates those two at packaging time.
- The build fingerprint now includes exam, section, passage, both stems, all bilingual options, and the correct option, and is independent of option ordering.
- `python3 tools/validate_ctet_content.py` passes: schema, answer indices, complete primary options, all-or-none English, Paper-II scope, **145 passage groups**, PYQ years, repair-ledger mapping and semantic duplicates are valid.
- `python3 tools/build.py` succeeds with **7,542 packaged questions** across the full repository.

Finding-level outcomes and current line mappings are recorded in [`ctet_paper1_repair_results.csv`](ctet_paper1_repair_results.csv). The migration is in [`tools/repair_ctet_paper1.py`](../tools/repair_ctet_paper1.py). Granular topics and independently calibrated difficulty levels remain future enrichment work because the sources do not provide reliable values; they were not fabricated.

## Baseline executive conclusion

The Paper-I bank is **not ready to ship without cleanup**. All **5,075** rows labelled `ctet1` were checked structurally and by targeted semantic/provenance review. The row-level ledger contains **1,805 findings affecting 1,659 unique rows** (overlap is intentional when one row has several defects).

The highest-risk results are:

- **494 confirmed Paper-II/upper-primary-origin rows** are labelled `ctet1` (493 Hindi, 1 CDP). Of these, **180** expose the Paper-II/VI-VIII marker directly in CSV and **314** more were recovered by matching bank label + question number + normalized stem to a source Markdown block marked Paper II/VI-VIII with no Paper-I marker. Another **5** rows explicitly target upper-primary/Class VI-VIII and need provenance review.
- **171 rows** carry source tags from non-CTET exams (UP/MP/UK/Jharkhand TET or UP Aided JHS) while being stored as CTET Paper-I. This may be intentional cross-TET practice, but it is incorrect if `ctet1` is meant to mean CTET-only.
- **12 definite wrong answer keys** were corroborated by duplicate official-paper variants and/or external references.
- **19 questions lack a required figure/diagram**, **17 have lost mathematical expressions**, and **8 have incomplete tables/data**.
- **15 rows have statements or answer-code choices merged into option fields**; line 6605 loses every Hindi numeric option.
- **144 rows have a truncated English stem and/or option**, and **39 questions refer to underlining that is not encoded anywhere in the repository**.
- The raw Paper-I CSV has **388 exact duplicate rows that the builder silently drops**; **46 additional duplicate instances survive the current build fingerprint**.
- **389 `is_pyq=1` rows have no `years` value**, so chronology-based filters/scoring are degraded.

The complete question-level findings are in [`ctet_paper1_audit_issues.csv`](ctet_paper1_audit_issues.csv).

## Definite answer-key errors

| CSV line | Source | Finding / correction |
|---:|---|---|
| `24` | CTET 2018 Q23 | Stored d; correct a — development of symbolic thought is not a limitation of preoperational thought. |
| `39` | CTET 2018 Q38 | Stored b; correct d — the discovery activity uses the inductive method. |
| `52` | CTET 2018 Q55 | Stored a; correct b — assessment should not focus on precision in answers. |
| `69` | CTET 2018 Q72 | Stored c; correct b — the described family-teaching approach is not inclusive. |
| `76` | CTET 2018 Q79 | Stored d; correct b — BALA means Building as Learning Aid. |
| `78` | CTET 2018 Q81 | Stored d; correct b — ‘Women are weaker than men’ is a stereotype. |
| `82` | CTET 2018 Q85 | Stored c; correct b — NCF-2000 recommended integrated EVS across the primary stage. |
| `305` | CTET Bank CDP Questiins for Paper-1 Q159 | Stored b; correct a — school and neighbourhood are secondary socialisation agents. |
| `642` | CTET Bank CDP Questiins for Paper-1 Q22 | Stored b; correct c — learning disability is a variable state. |
| `1245` | CTET Bank Evs Notes and Pedagogy Q42 | Stored c; correct b — flooding deprives roots of oxygen and root respiration stops. |
| `3937` | CTET Paper 1 Dec 2018 Q64 | Stored d; correct c — NCF-2000 is the correct option in this ordering. |
| `6698` | CTET Bank Pedagogy of English Language Q8 | Stored b; correct c — language learnt without deliberate practice is acquisition. |

In addition, **L172** has a corrupted option (`9 to 12 years` instead of official `6 to 11 years`), and **L3947** has no correct option (its duplicate at L62 preserves approximately `98 N`). L4552, L5873 and L6026 display calculations inconsistent with their keys because source fractions/mixed numbers were lost; these are expression-reconstruction defects rather than safe one-field key fixes.

## Content corruption by category

### Missing visual stimuli (19)

`L42, L47, L49, L54, L3909, L3924, L3929, L3931, L4688, L4689, L4717, L5387, L5855, L5860, L6004, L6009, L6039, L6175, L6298`

No Markdown image objects/assets exist for these questions upstream. A text-only option is acceptable only when it fully describes the original figure; these rows do not.

### Lost mathematical expressions (17)

`L43, L3702, L3703, L3925, L3933, L4143, L4552, L5174, L5381, L5529, L5723, L5866, L5873, L6026, L6160, L6168, L6452`

Typical failures are flattened fractions (`1/16` → `16`, `1/2` → `1`), missing alternating sums, and a Hindi stem losing an equation that survives only in English.

### Incomplete tables/data (8)

`L1656, L3699, L4122, L4738, L4856, L5523, L6330, L6599`

These omit the values needed to calculate or select an answer (blood-group counts, prices, marks, dimensions, distances, or arrival times).

### Merged statements and answer codes (15)

`L816, L1641, L1693, L3694, L3737, L3756, L3835, L4858, L5195, L5197, L5276, L5734, L6055, L6147, L6154`

The parser has combined statements such as A/B/C with code choices such as “A and C”, sometimes differently in Hindi and English.

### Other confirmed field-level corruption

- **Identical/lost options:** `L656, L3677, L3772, L4548, L4551, L4717, L5381, L5396, L5869, L6605`
- **Material Hindi/English mismatch:** `L623, L1398, L1551, L1641, L1693, L5384, L5399, L6436`
- **Unrelated preamble/OCR garbage:** `L148, L623, L787, L830, L1398, L1551, L1582, L1912, L2764, L5384`
- **Assertion/reason label debris:** `L3673, L3679, L3740, L3742, L3747, L3752, L5125, L5126, L5131, L5139, L5191, L5199, L5204, L5209`
- **Date/shift text appended to an option:** `L3671, L4088, L4296, L4657, L5011, L5335, L5826, L6268, L6416`
- **Invalid matching code `A-vi`:** L3776 (only i-v are defined).

## Structural checks that passed

- All 5,075 Paper-I rows have a non-empty primary stem, four non-empty primary option fields, and an answer index in `0..3`.
- The passage structure is internally linked: 813 question rows use 111 passage IDs; each passage ID has one populated body and no question references a missing passage.
- Hindi-language rows intentionally have no English mirror; there are no *partial* English records—English is either absent for the whole item or present in all five stem/option fields. Presence alone does not imply quality, as the truncation findings show.
- The five Sanskrit rows (L5117-L5121) are legitimate Paper-I language-alternative content, but five items are too few for meaningful Sanskrit delivery if the product exposes that section.

## Baseline systemic metadata/design defects

- Every Paper-I row has `difficulty=2`; difficulty selection cannot work meaningfully.
- Topics are only broad `CTET अभ्यास` / `CTET विगत वर्ष` buckets, not syllabus topics, so topic-balanced mocks cannot be generated from this file.
- 389 PYQ rows lack `years` (145 `CTET 2018`, 114 Jan-2023, 73 Hindi-bank, 33 EVS-bank, 23 CDP-bank, and one July-2024 row).
- The current build fingerprint uses only `exams + q_hi + q_en + a_hi`; it is option-order-sensitive and ignores options b-d, answer, and provenance. It drops 388 raw Paper-I rows but leaves 46 normalized duplicates.

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

## Baseline remediation order (completed)

1. **Quarantine the 494 confirmed Paper-II/upper-primary rows** and review the five probable rows.
2. Fix the 12 definite keys, L172, L3947, line 6605, and all missing visual/expression/table records before users see them.
3. Reconstruct merged statement/code items and restore explicit formatting targets for “underlined” questions.
4. Replace truncated translations; do not serve an English item merely because all English fields are non-empty.
5. Consolidate duplicates and change fingerprinting to normalized stem + the complete option set, with answer remapping when option order changes.
6. Populate `years`, granular syllabus topics, and real difficulty values; add automated validation for duplicate options, metadata leakage, Paper-II markers, visual references without assets, and assertion/reason code templates.

## Limits

This was a row-by-row structural/provenance audit plus targeted semantic verification of duplicate conflicts and high-risk records. It does not claim an independent authoritative re-solve of every one of the 5,075 pedagogy, language, EVS and mathematics facts. Accordingly, only corroborated key errors are labelled “definite”; suspicious but unrecoverable records are labelled as corruption and should be checked against original CTET scans/official keys.

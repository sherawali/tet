# CTET July 2020 cycle — Paper I V2 import report

## Scope

The postponed July 2020 cycle held on **31 January 2021** is the only populated V2 cycle.
The official archive calls it **CTET January 2021 MAIN PAPER 1**. Official **Set I** is canonical.

Stored content:

| Module | Questions |
|---|---:|
| CDP (Hindi + English) | 30 |
| Mathematics (Hindi + English) | 30 |
| Environmental Studies (Hindi + English) | 30 |
| English-I | 30 |
| English-II | 30 |
| Hindi-I | 30 |
| Hindi-II | 30 |
| Sanskrit-I | 30 |
| Sanskrit-II | 30 |
| **Canonical/module total** | **270** |

The paper form contains 90 core questions and six independently selectable 30-question language
modules. An attempted form remains 150 questions: the 270 rows are not modeled as one attempted
paper.

## Primary evidence

- Official Set-I MAIN booklet: `2022040421.pdf`
- Official final Paper-I key: `2022033154.pdf`
- Official Set-I Sanskrit supplement: `2022040485-1.pdf`
- Searchable page-text/page-image mirrors are recorded alongside the official URLs.

The machine-readable provenance, complete relevant Set-I/Set-K/Set-J final-key tables, question
order mappings and option permutations are in:

- `bank-v2/sources/ctet-p1-2020-2021-set-i.json`
- `tools/v2/import_ctet_2020_paper1.py`

The clean Unicode transcription was identified as Set K for common/English/Hindi and Set J for
Sanskrit. Set-I order was reconstructed semantically. Set-I options are Set-K options in order
`[c,d,a,b]` and Sanskrit Set-J options in order `[d,a,b,c]`. Every transformed answer position is
asserted against the official Set-I final key by the importer.

## Repairs and non-text dependencies

Only recoverable source/layout defects were repaired. Notable repairs include:

- the complete route item and `100 m due west` answer for local Q71 / Set-I EVS Q87;
- Mathematics fractions, square-centimetre notation, stationery layout and units;
- the exact Set-I Mathematics Q41 marks table (Maria/Shehnaz, five subjects) as a structured table;
- four English underlined/error-analysis targets (Set-I Q96, Q97, Q127 and Q134);
- damaged Sanskrit stems/options, displaced text and Unicode visarga characters;
- line-preserving poem layouts.

The official Set-I EVS Q83–Q90 page-layout dependency audit found no omitted diagram, map or image.
Set-I Mathematics Q41 is the only common-section non-text dependency and is linked to its table.
No solution commentary was imported.

## Stimulus integrity

There are **13 first-class stimuli**:

- four for English (two prose, one poem in each language slot arrangement);
- four for Hindi;
- four for Sanskrit;
- one Mathematics marks table.

Every dependent question references its stimulus. Every stimulus has `selectionPolicy: atomic`, and
the validator requires its linked-question count to equal `minimumQuestions`; partial selection is
therefore rejected at the source-bank validation boundary. The SQLite content model also persists
the selection policy for the future Flutter mock assembler/player.

## Audit and validation

- `bank-v2/audits/ctet-p1-2020-2021-question-audit.ndjson` has exactly one row for each of 270 questions.
- Every question has four ordered options and one official-key answer.
- Every question has exactly one verified Set-I appearance.
- All 13 stimulus link groups are complete and atomic.
- The form has all 90 core appearances and all six 30-question language alternatives.
- All 554 question/stimulus/form/appearance rows pass their JSON Schema 2020-12 contracts.
- `python3 tools/v2/validate_structure.py` passes populated-content and cross-reference checks.

The bank is now `active`, `bankVersion: 1`. No 2021-or-later cycle has been started.

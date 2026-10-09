# TET Question Bank V2

This directory is the clean-room source database for the next Flutter question-bank runtime.
It is intentionally independent of the legacy `content/` CSV files. The first authorized cycle
has been populated directly from official-paper sources; no legacy CSV row was migrated.

## Principles

- CTET and UTET are separate exam namespaces.
- Paper I and Paper II are separate databases.
- Every section/language slot is an independently downloadable module.
- Canonical questions are separate from their appearances in real papers.
- Passages, poems, tables, images and case studies are reusable stimuli.
- Stable IDs replace CSV line numbers.
- Source data is NDJSON; generated Flutter runtime data is SQLite plus immutable update packs.
- Question-bank sync is one-way. There is no login and no user-data upload.
- Flutter stores content and local user progress in separate SQLite databases.

## Leaf section database

Every section leaf contains:

```text
section.json       Machine-readable section identity
questions.ndjson   One canonical question per line
stimuli.ndjson     Passages, poems, tables, case studies and grouped media
```

Language sections are partitioned by language slot and language, for example:

```text
exams/ctet/paper-1/language-1/hindi/
exams/ctet/paper-1/language-2/english/
```

## Top-level layout

```text
schemas/            JSON Schema 2020-12 contracts
catalogs/           Topics, concepts and asset registry
exams/              Independent section databases
paper-forms/        Verified real previous-year paper definitions
sources/            Official provenance and reconstruction manifests
audits/             One-row-per-question verification evidence
mock-blueprints/    Official and smart-mock constraints
runtime/sqlite/     Flutter content/user SQLite schemas
releases/           Empty target for future immutable manifests and update packs
```

## Status

`active`, bank version 1. The complete postponed July 2020 CTET Paper-I cycle held on
31 January 2021 is stored in official Set-I order:

- 90 bilingual common questions (CDP, Mathematics and EVS)
- 30 questions in each of English-I, English-II, Hindi-I, Hindi-II, Sanskrit-I and Sanskrit-II
- 13 first-class stimuli (12 language passages/poems and the Mathematics Q41 marks table)
- one verified selectable-module paper form and 270 verified appearances

Every passage/poem/table uses `selectionPolicy: atomic`. Later cycles remain unpopulated pending
separate authorization.

Run the structure and populated-content validator:

```bash
python3 tools/v2/validate_structure.py
```

`validate_structure.py` only proves the 2020 cycle is internally consistent. It does not
check whether a passage really belongs to the questions wired to it. For that run the
stimulus-link audit, which writes one report per exam+year under
`audits/stimulus-links/` and exits non-zero on a provable defect:

```bash
python3 tools/v2/audit_stimulus_links.py
python3 tools/v2/audit_stimulus_links.py --exam ctet --year 2016
```

Its findings are summarised in [`../docs/STIMULUS_LINK_AUDIT.md`](../docs/STIMULUS_LINK_AUDIT.md):
every CTET cycle imported by `import_all_ctet.py` (2016, 2018, 2019, 2021-Dec, 2023, 2024,
2026) carries placeholder passage/poem text hardcoded in `stimuli_specs`, so those stimuli
do not match their questions. Only the 2020 cycle (31 January 2021), imported by
`import_ctet_2020_paper1.py`, has genuine stimulus text.

## Sanitization and release build

Sanitize the active NDJSON content and check the pending diff without writing:

```bash
python3 tools/v2/sanitize_bank.py --check
python3 tools/v2/sanitize_bank.py
```

The sanitizer changes only localized display text. It preserves question IDs, option
IDs/order, answer keys, forms, appearances, and source/audit provenance; malformed
Markdown tables are left untouched rather than having cells guessed or discarded.
Then build the SQLite app database and publish a fresh manifest/packs:

```bash
python3 tools/v2/build_app_db.py
python3 tools/v2/build_cdn_packs.py            # add --prune to drop unreferenced packs
python3 tools/v2/test_app_build.py             # 11 regression tests for this pipeline
```

Builds use the content version in `tools/v2/build_config.py` — bump `BANK_VERSION`
whenever pack content changes, because a client only re-syncs when the manifest
`bank_version` is greater than the one it already stored. SQLite is built to a
temporary file and atomically replaces the runtime database only after integrity/count
checks pass. Pack ids are version-scoped (`v<BANK_VERSION>-<index>`) so one id never
points at two different byte sequences; the manifest is atomically replaced only after
all new content-addressed packs verify.

The deterministic, source-limited importer is:

```bash
python3 tools/v2/import_ctet_2020_paper1.py
```

## App-data pipeline defects fixed on 2026-10-09

Symptom in the app: passage/poem questions looked missing and the rest came out
scrambled. Six separate causes, each now covered by `tools/v2/test_app_build.py`:

1. **Poems were labelled prose.** `classify_topic()` guessed the topic from the
   stimulus *id* string (`"poem" in pid`), but `import_all_ctet.py` mints ids as
   `…-po-100`. Result: 126 poem questions sat under `अपठित गद्यांश` and only the 18
   from the 2020 cycle were `अपठित पद्यांश`. The stimulus `type` is authoritative now.
2. **`seq_in_passage` held the paper question number** (91…99, 121…128) instead of the
   position inside the block (1…N). A client walking a passage group by position found
   nothing. The paper number still lives in `appearances.question_number`.
3. **Language slot was dropped.** Language-I and Language-II both collapsed into
   `section = "hindi" | "english" | "sanskrit"`, so the mock blueprint's
   `languageSlot`/`mustDiffer` rules were unsatisfiable and the app mixed the two.
   `language`/`language_slot` now travel from NDJSON → SQLite → packs (`lg`/`sl`).
4. **Stimulus groups were split across packs** — 4 of 109 blocks had their questions in
   two different packs. Packing is now per block, never per fixed 200-question slice.
5. **A pack could not always render its own questions**: a passage shipped only in the
   pack holding its first question. Every pack now carries the full text of every
   passage it references (~100 KB total duplication, worth it for self-containment).
6. **The CI workflow was dead**: it ran `tools/build.py` on `content/**`, neither of
   which exists any more, and exported a git-count `BANK_VERSION` that the v2 builder
   would reject as a version mismatch. It now runs the v2 tools on `bank-v2/**`.

Still open, and it is a content problem rather than a pipeline one: the passage/poem
*text* of every cycle except 2020 is placeholder content hardcoded in
`import_all_ctet.py` — see [`../docs/STIMULUS_LINK_AUDIT.md`](../docs/STIMULUS_LINK_AUDIT.md).
A structurally correct pipeline still cannot invent the right passage.

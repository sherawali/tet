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

The deterministic, source-limited importer is:

```bash
python3 tools/v2/import_ctet_2020_paper1.py
```

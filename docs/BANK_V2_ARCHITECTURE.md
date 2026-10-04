# TET Question Bank V2 — architecture lock

## Decision

Build a fresh database under `bank-v2/` in the existing question-bank repository. The legacy
CSV database remains operational but is not a source dependency of V2. No migration/import is
part of the structure phase.

The existing Flutter application remains a separate consumer. It will eventually bundle a base
`content.sqlite`, download immutable updates without login, and keep attempts/bookmarks in a
separate local `user.sqlite`.

## Domain model

1. **Canonical question** — one stable question and answer, independent of a paper occurrence.
2. **Appearance** — one occurrence of a question in an official exam/date/shift/question number.
3. **Paper form** — verified ordered real-paper composition, including selectable language modules.
4. **Stimulus** — passage, poem, dialogue, table, image, map, diagram or case study shared by questions.
5. **Asset** — checksummed SVG/WebP/PNG/audio file with language variants and alt text.
6. **Topic/concept** — syllabus taxonomy used for trend analysis and blueprint balancing.
7. **Mock blueprint** — section counts, language choices, streams and smart-selection constraints.

## Exam databases

### CTET Paper I

- CDP — bilingual
- Language I — Hindi/English/Sanskrit
- Language II — Hindi/English/Sanskrit
- Mathematics — bilingual
- Environmental Studies — bilingual

### CTET Paper II

- CDP — bilingual
- Language I — Hindi/English/Sanskrit
- Language II — Hindi/English/Sanskrit
- Mathematics — bilingual
- Science — bilingual
- Social Studies — bilingual

The Mathematics & Science stream composes 30 Mathematics + 30 Science questions. The Social
Studies stream composes 60 Social Studies questions.

### UTET Paper I

- CDP
- Language I — Hindi/English
- Language II — Hindi/English/Sanskrit/Urdu-ready
- Mathematics
- Environmental Studies

### UTET Paper II

- CDP
- Language I
- Language II
- Mathematics
- Science
- Social Studies

## Content language

UI locale, question locale and language subject are independent. Knowledge sections can expose
Hindi, English or bilingual display. Language-subject questions use their actual language and slot.
Answers reference stable option IDs, never translated option positions.

## Previous papers

Real papers are immutable ordered forms. Only verified-complete forms may be published as real
papers. A repeated question has one canonical record and multiple appearance records so repetition
history is preserved without duplicating content.

## All question types

The schema supports single-choice, multi-select, true/false, assertion-reason, statement-code,
matching, sequence, fill-blank, numeric, passage, poem, image, table and case-study items. Official
TET paper simulations can restrict delivery to four-option single-choice items.

## Offline update model

- App ships with a base `content.sqlite`.
- A static manifest advertises bank/schema versions and section packs.
- App downloads only new/changed section packs and required assets.
- SHA-256 verification and a SQLite transaction precede activation.
- Failed updates roll back to the previous content version.
- If a device is too old for a delta chain, it downloads a current section snapshot.
- `user.sqlite` is never replaced by content updates.

## Structure phase acceptance criteria

- JSON schemas parse successfully.
- Every declared exam/paper/section has an independent leaf store.
- Every leaf has valid `section.json`, `questions.ndjson` and `stimuli.ndjson`.
- Official paper blueprints total 150 questions.
- SQLite content/user schemas are separate.
- No V2 file imports or depends on a legacy CSV.

## First populated cycle

Bank version 1 contains only the authorized postponed July 2020 CTET Paper-I cycle held on
31 January 2021. Official Set I is canonical. The form stores 90 core appearances plus six
independently selectable 30-question language modules (English/Hindi/Sanskrit in slots I and II),
so its 270 stored appearances still represent a 150-question attempted paper.

The cycle has one audit row per canonical question, an official-source manifest, final-key-derived
answers, four options per question and first-class atomic stimulus records. The validator rejects
partial stimulus groups, broken form/appearance references, incomplete language alternatives and
unverified publication gates. No later cycle is populated until separately authorized.

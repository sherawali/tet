# Flutter local SQLite split

- `content_schema.sql` defines replaceable/synchronised question-bank content.
- `user_schema.sql` defines local-only attempts, bookmarks, mocks and progress.

The Flutter app must open these as separate database files. Content snapshot replacement or delta
installation must never touch `user.sqlite`. Deleted/retired question IDs may remain referenced in
user history so past mock results remain readable.

## ⚠ `content_schema.sql` is the target schema, not what the build emits

`tools/v2/build_app_db.py` currently builds the **legacy app schema** that the shipping
Flutter app reads:

```sql
questions(id, exams, section, topic_index, topic_name, difficulty,
          q_hindi, options_hindi, q_english, options_english, answer,
          p_score, years, source_tag, passage_id, seq_in_passage,
          language, language_slot, stimulus_kind,
          group_id, group_policy, group_size)
passages(id, kind, dir_text, body, title, language, language_slot,
         minimum_questions, review_text_verified, selection_policy)
paper_forms(...)  appearances(...)  meta(key, val)
test_history(...)  mistake_records(...)
```

`content_schema.sql` above (`section_stores`, `stimuli`, `questions.payload_json`,
`mock_blueprints`, `installed_packs`, …) is the v2 target contract. Nothing builds it yet.
Do not generate app code from it until a builder exists.

## What the CDN packs actually carry

`cdn/manifest.json` lists version-scoped packs (`v<BANK_VERSION>-<index>`). Each pack is:

```json
{"p": [{"id": "…", "k": "prose|poem|table", "d": "directions", "b": "body",
        "lg": "hi", "sl": 1}],
 "q": [{"k": "qid", "e": "ctet1", "s": "hindi", "t": 1, "d": 2,
        "qh": "…", "oh": ["…"], "qe": "…", "oe": ["…"], "a": 0, "p": 0.85,
        "y": "2024", "lg": "hi", "sl": 2, "pid": "stimulus id", "n": 3}]}
```

Invariants the builder enforces (see `tools/v2/test_app_build.py`):

- **Group contract.** A passage and every question of that passage are one unit.
  `g = {"id": <group id>, "pol": "atomic", "n": <group size>}` on the question and
  `pol`/`g` on the passage. Take all `n` or none — never the passage alone, never one
  question without its passage. `tools/v2/validate_stimulus_groups.py` enforces this in
  the bank and `tools/v2/test_app_build.py` enforces it in the packs.
- `pid` + `n` = the question belongs to stimulus `pid` at position `n`, where `n` runs
  **1..N inside the block**, not the question number in the paper. The paper number is
  in `appearances.question_number`.
- A stimulus group is never split across two packs, and every pack contains the full
  text of every passage its questions reference — one pack is enough to render a
  question.
- `lg`/`sl` = language and language slot (1 = Language-I, 2 = Language-II). Without
  these a client cannot separate Language-I Hindi from Language-II Hindi.


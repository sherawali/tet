# TET App — V17 Deep Audit & Repair Report

**Date:** 2026-10-20  
**Vault version:** `2026102018` (`20261020_master_vault_clean_v18`)  
**Scope:** HTML booklet rendering, native question rendering, question/passage database, option integrity, answer keys, English option alignment, CDN export, and app-level quality recommendations.

---

## 1. Executive Summary

The V17 audit found three separate classes of problems:

1. **Rendering/parsing problems** — `कथन 1/कथन 2`, `निष्कर्ष`, assertion–reason, multi-statement, poem, paragraph and match-the-following questions were stored as long single-line strings. The HTML booklet and the native Flutter renderer interpreted them differently, so the same question could look correct in one engine and broken in the other.
2. **Database/content problems** — missing passage bodies, unlinked passages, wrong exam tags, prose/poem misclassification, options that had lost their leading values during the original import, duplicate options, and several objectively wrong answer keys.
3. **English-option problems** — many English option arrays were misaligned with their questions or had lost leading values such as `1 and 2` → `and 2`, `(A) and (D)` → `, (D)`, and numeric match codes.

The repairs below fixed the high-impact issues and left the vault in a verified, internally consistent state. Remaining source-level gaps are documented in section 6 rather than hidden.

---

## 2. Renderer & Parser Fixes

### 2.1 Shared, Flutter-free parser

New file: `lib/services/question_layout_parser.dart`

- Pure Dart; usable by both the HTML booklet builder and native widgets.
- Parses:
  - `कथन-1: ... कथन-2: ...`
  - `कथन १:` / `कथन (1):` variants
  - `अभिकथन (A)` / `कारण (R)`
  - `निष्कर्ष` / conclusion blocks
  - `कॉलम A/B`, `सूची-I/II`, `स्तम्भ 'अ'/'ब'`
  - `(A)/(i)`, `1./(a)`, dashed pairs, unequal/odd match columns
  - numbered statement lists and multi-statement questions
- Keeps the original intro and conclusion text instead of discarding it.

### 2.2 HTML booklet renderer

File: `lib/services/html_booklet_builder.dart`

- Uses the shared parser for kathan, conclusion and match-table layouts.
- Canonicalizes inline `कथन-1:` / `कथन १:` to `कथन (1):`.
- Preserves line breaks from `stripHtml` instead of collapsing the whole stem into one line.
- Restores a small safe inline-HTML whitelist (`<u>`, `<b>`, `<i>`, `sup`, `sub`, etc.) after escaping.
- Escapes raw `<`/`>` correctly; mathematical `<` is displayed as `<`, not interpreted as a tag.
- Adds match-table rendering for legacy flat option strings.
- Guards English error-spotting `(A) / (B) / (C) / (D)` segments so they are not mistaken for match columns.
- Fixed literal `<br>` handling so tags are not double-escaped.

### 2.3 Native renderer

File: `lib/widgets/formatted_question_stem.dart`

- Uses the same shared parser, so the native and HTML engines now agree on kathan/match/statement structure.
- Handles multiline prose, poems, match tables, and structured statement blocks.

### 2.4 Sanitizer and engine fixes

- `lib/models/question.dart`
  - `QuestionSanitizer.stripHtml` now preserves newlines.
- `lib/services/mock_engine.dart`
  - Correct language codes and section detection.
  - Passage-section detection and section banners fixed.
  - Paper-2 loader and yearly PYQ exam filtering fixed.
- `lib/services/sync_service.dart`
  - Anti-downgrade guard.
  - Digit-based version parsing so string suffixes do not break version comparison.
- `lib/database/db_helper.dart`
  - Paper-2 loading, language sections, bundled-vault version upgrade logic.

---

## 3. Database Repairs

### 3.1 Vault shape after repair

| Item | Value |
|---|---:|
| Questions | 9,720 |
| Unique question IDs | 9,720 |
| Passages | 181 |
| Paper-form appearances | 9,720 |
| Paper forms | 62 |
| Paper 1 forms | 39 × 150 questions |
| Paper 2 forms | 23 × 150 or 210 questions |
| Orphan passages | 0 |
| Questions linked to passages | 582 |

Exam tags are canonical:

| Exam | Questions |
|---|---:|
| UTET Paper 1 (`utet1`) | 3,150 |
| CTET Paper 1 (`ctet1`) | 2,700 |
| CTET Paper 2 (`ctet2`) | 2,400 |
| UTET Paper 2 (`utet2`) | 1,470 |

### 3.2 Passages, poems and linking

Script: `bin/repair_vault_v17.py`

- Recovered and inserted missing passage bodies from `C:\Users\pujariji\Desktop\tetmaster`.
- Linked passages to their question ranges.
- Extended an existing passage only when the new range started at the same first question.
- Skipped ranges already fully covered.
- Skipped overlapping duplicate language/stream variants.
- Reclassified **16 existing prose passages as poems**.
- Verified P2 mocks, CTET P1 English PYQ passages, and repaired UTET sets.
- Kept `test_history`, `mistake_records` and `question_reports` intact.

### 3.3 Option text and answer-key repairs

Script: `bin/repair_option_text_v17.py`

- **74 unique questions** repaired.
- Restored leading values lost by the old importer, for example:
  - `2 घण्टे` had become `घण्टे`
  - `1 and 2` had become `and 2`
  - ratio options such as `4 : 11` had become `: 11`
  - match-file codes lost their first number
- Removed all duplicate-option groups.
- Restored missing `(A)` prefixes, e.g. `व (B) दोनों` → `(A) व (B) दोनों`.
- Repaired invalid math/source-key cases.

### 3.4 English option repairs

Script: `bin/repair_english_options_v17.py`

- **57 unique questions** repaired.
- Restored lost leading values in English combinations:
  - `and 2` → `1 and 2`
  - `, (C) and (D)` → `(B), (C) and (D)`
  - `and 144` → `12 and 144`
- Fixed wholly misaligned English options, including IQ formula, simple-interest, average-speed, EVS dates, match codes, and language/EVS combination options.
- Fixed duplicate English options in EVS and language questions.
- Total option-map repair coverage: **131 unique questions** (74 Hindi + 57 English, zero overlap).

### 3.5 Wrong answer keys corrected

| Question ID | Correct answer | Note |
|---|---|---|
| `ctet-p1-mock-04_q006` | `11-12 वर्ष` (index 3) | Formal-operational stage age |
| `ctet-p1-mock-06_q043` | `1 मी 20 सेमी` (index 0) | 2 m 40 cm ribbon halved |
| `ctet-p1-mock-03_q041` | `2 मी 50 सेमी` (index 3) | 250 cm conversion |
| `54a83fe77e48aeae` | `24/25` (index 1) | `(2⁻¹+4⁻¹+6⁻¹+8⁻¹)x = 1` |
| `0235f2d925c7585c` | `8` (index 3) | `(2ⁿ+2ⁿ)/(2ⁿ⁻²)` |

Where the printed source key itself was invalid but the mathematics was unambiguous, the vault was corrected and the source discrepancy is recorded here.

### 3.6 Import bug recorded

The original importer stripped a single leading digit followed by a space. Consequences:

- Hindi: `2 घण्टे` → `घण्टे`
- English: `1 and 2` → `and 2`
- Decimal and two-digit prefixes survived, which made the bug look inconsistent.

The repair scripts now preserve these values. Future imports must use the same guard.

---

## 4. Verification

### 4.1 Database integrity

```text
PRAGMA integrity_check: ok
questions: 9720
unique ids: 9720
passages: 181
appearances: 9720
orphan passages: 0
hi_not_4: 0
en_not_4: 0
empty_hi: 0
invalid_answer: 0
dup_hi: 0
dup_en: 0
bad_prefix: 0
```

Form totals:

```text
Paper 1: 39 forms × 150 questions
Paper 2: 23 forms × 150 or 210 questions
```

### 4.2 Render audit

```text
should_kathan: 10/10
should_match:  20/21
should_stmt:   136/142
```

Remaining mismatches are audit false positives:

- English error-spotting `(A)/(B)/(C)/(D)` questions.
- One math-classroom question that lists sub-questions but is not a match table.
- A few statement-like questions where the detector expects a layout the content does not actually use.

The audit’s six `literal_html_leak` hits are mathematical `<` values that are correctly escaped as `&lt;`; they are not raw HTML leaks.

### 4.3 Tests and analysis

```text
flutter test: 42/42 passed
flutter analyze lib: No issues found
```

The complete `flutter analyze` still reports pre-existing `scratch/` helper-script lints; there are **no `lib/` errors or warnings**.

---

## 5. CDN / Release Export

- Vault metadata bumped to `2026102018`.
- `DbHelper.bundledVaultVersion` bumped to `2026102018`.
- `bin/build_github_cdn_vault.py` now exports:
  - `papers_data.version = 2026102018`
  - `manifest.bank_version = 2026102018`
  - `manifest.bank_version_str = 20261020_master_vault_clean_v18`
- Regenerated:
  - `cdn/papers.json` — 62 forms, 9,720 appearances
  - `cdn/manifest.json` — 49 packs, 9,720 questions
  - `cdn/packs/` — 49 current packs; 128 stale packs removed
- Verified all 49 pack SHA-256 values against the manifest.

Backups created during repair:

```text
scratch/tet_mock_vault_pre_v17.db
scratch/tet_mock_vault_pre_options.db
scratch/tet_mock_vault_pre_en_options.db
```

The repaired vault and CDN were pushed to `origin/main` in commit `d37948b`. Live verification after push:

```text
manifest.bank_version: 2026102018
manifest.bank_version_str: 20261020_master_vault_clean_v18
questions: 9720
papers: 62
packs: 49
papers.json version: 2026102018
sample pack SHA-256: matches manifest
```

---

## 6. Remaining Data-Quality Risks

### 6.1 Unrecoverable passages in the source corpus

The following source markdown files do not contain the passage bodies; the vault cannot invent them:

- UTET Paper 2: SET-A, SET-D, SET-E, SET-G
- UTET Paper 1: SET-E, SET-H, SET-I, SET-J, SET-11, SET-12

Also partially missing:

- UTET P1 SET-B Q45/49 poem and SET-J Q44/48/70/71/88 passages
- UTET P2 SET-B Q75–79 direction passage
- UTET P2 SET-D several poem/passage questions

These should be recovered from the original PDF/booklets, or marked as “passage not available” in the UI.

### 6.2 English options are not fully source-verified

57 questions were repaired using structural and numeric-loss evidence. English options that are conceptually wrong but numerically/structurally identical to Hindi cannot be detected reliably by heuristics. Recommended:

- Add an `en_verified` flag per question.
- Hide unverified English options rather than showing a wrong translation.
- Run a source-to-vault diff for every English option array.
- Prioritise EVS, CDP and language sections, where the remaining risk is highest.

### 6.3 Source answer-key errors

Some printed answer keys are objectively wrong. The five cases in section 3.5 were corrected where the mathematics was unambiguous. A full answer-key audit against an independent answer source is still recommended.

### 6.4 Legacy English stems

At least one duplicate exponent question has a corrupted English stem (for example `2⁴+4⁻⁴+6⁻¹+8` instead of `2⁻¹+4⁻¹+6⁻¹+8⁻¹`). Hindi remains correct. A future source re-import should replace these stems.

### 6.5 Expected audit noise

- `duplicate_stem`: 2,372 — mostly the same question reused across mocks/PYQs, not necessarily an error.
- `en_opts_equal_hi`: 2,745 — expected for mathematics and transliterated content.
- `monolingual_only`: 1,800 — expected for language-specific questions.
- One unit-only option row (`मीटर / मीटर² / मीटर/सेकण्ड / मीटर/सेकण्ड²`) is legitimate.

---

## 7. App Improvement Roadmap

### Priority 1 — Prevent data regressions

1. Build a **strict import contract**:
   - never strip a leading digit unless it is a confirmed question/option marker;
   - preserve `1 and 2`, `2 घण्टे`, decimals, ratios and match codes;
   - reject stems/options containing markdown table pipes or raw HTML unless explicitly allowed.
2. Add CI data gates:
   - exactly four options;
   - no duplicate options;
   - answer index 0–3;
   - no empty options;
   - every passage has a body and at least one linked question;
   - English/Hindi numeric-token parity for quantitative questions.
3. Store source provenance per question (`source_file`, `source_line`, `source_key`) so future audits can reproduce fixes.

### Priority 2 — Rendering correctness

4. Promote the shared parser to a **typed content model** (`KathanBlock`, `MatchTable`, `PoemBlock`, `ProseBlock`, `StatementList`) instead of re-parsing strings in the renderer.
5. Add golden HTML snapshot tests for:
   - kathan + conclusion
   - assertion–reason
   - match table with 4/5/6 rows
   - poem with stanzas
   - paragraph with multiple prose blocks
   - mathematics with `<`, `>`, fractions, superscripts
6. Cache parsed layouts per question to avoid re-parsing on every rebuild.

### Priority 3 — Content quality

7. Add a `question_audit` / `content_issues` table with status (`open`, `verified`, `fixed`, `unrecoverable`) and an admin review screen.
8. Add an **English review workflow** with `en_verified` and a “report translation” action.
9. Recover missing passages from original PDFs and add a passage editor for manual correction.
10. Cross-check all answer keys against at least two independent sources; log disagreements instead of silently choosing one.

### Priority 4 — Sync and release safety

11. Keep the anti-downgrade guard; add a **rollback manifest** and staged pack rollout.
12. Verify pack SHA-256 and total counts before activating a remote sync.
13. Keep user tables (`test_history`, `mistake_records`, `question_reports`) in a separate migration path so content updates can never overwrite them.
14. Add a visible “content version” in Settings for support/debugging.

### Priority 5 — UX / accessibility

15. Add font scaling and high-contrast modes for the booklet.
16. Add screen-reader labels for kathan/match blocks.
17. Add a “passage not available” placeholder instead of a blank panel.
18. Add a “report this question” shortcut directly from the solution view.
19. Show a small “content updated” notice after a CDN sync.
20. Add analytics for most-reported questions/topics to drive future repairs.

---

## 8. Reproduce

```powershell
# 1. Verify the repaired vault
python scratch\verify_v17.py
python scratch\final_check_v17.py

# 2. Re-run the repair scripts (dry-run first)
python bin\repair_vault_v17.py
python bin\repair_option_text_v17.py
python bin\repair_english_options_v17.py

# 3. Apply only after reviewing the dry-run
python bin\repair_vault_v17.py --apply
python bin\repair_option_text_v17.py --apply
python bin\repair_english_options_v17.py --apply

# 4. Export CDN
python bin\build_github_cdn_vault.py

# 5. App checks
flutter test
flutter analyze lib
```

---

## 9. Final Status

- Rendering fixes are in `lib/` and covered by the existing test suite.
- High-impact database corruption is repaired.
- Vault and CDN versions are aligned at `2026102018`.
- User data tables were preserved.
- Keystores and signing files were not touched.
- Remaining issues are source-level gaps, documented above, not silent regressions.

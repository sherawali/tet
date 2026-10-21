# TET App — V20 Release Audit & Renovation Report

**Date:** 2026-10-21
**Vault version:** `2026102020` (`20261021_master_vault_clean_v20`)
**Previous version:** `2026102018` (`20261020_master_vault_clean_v18`)
**Scope:** offline SQLite vault, Git-backed CDN packs, HTML booklet renderer, native app screens, offline typography, and release tooling.

---

## 1. Executive summary

V18 left the vault *structurally* valid but *content-wise* inconsistent, and the booklet renderer was tuned for a
much smaller question bank. Three independent problems were fixed as one programme:

1. **Content integrity** — the same question was printed two or three times inside one paper, the printed answer
   key disagreed with the repaired question key, one reading group was split by an unrelated item, thirteen
   questions pointed at a stimulus that does not exist anywhere in the vault, and every row carried
   `topic_index = 0`.
2. **Renderer** — the HTML booklet produced up to 123 section banners per paper, rendered every bilingual figure
   and question number twice, labelled options `(1)…(4)` while the OMR sheet and the result screen used `A–D`,
   pulled KaTeX from a CDN on every booklet (so LaTeX broke offline), and printed a passage once at the top of the
   page while its questions were scattered across the sheet.
3. **App** — the CBT screen counted down a decrementing timer (so backgrounding the app gave away time), the
   solution review showed a five-line cut of the passage, the completed test was stored without its questions
   (so History could not reopen it), the fonts were downloaded at runtime (so the app looked cheap offline), and a
   paper without questions crashed the exam screen.

After the repair every paper prints 150 **different** questions, every printed key matches the question key,
every passage group is contiguous, and the booklet renders premium on a 320 dp phone as well as on a desktop.

---

## 2. Offline database — exactly what changed

Compared byte-for-byte against the v18 vault (`b367c41`):

| Table | Added | Removed | Changed | Detail |
|---|---|---|---|---|
| `questions` | 0 | 0 | **9,719** | `topic_index` 9,719 · `seq_in_passage` 26 · `passage_id` 25 · `answer` 19 · `q_hindi` 15 · `options_hindi` 15 · `q_english` 3 · `options_english` 3 |
| `passages` | 0 | 0 | **1** | `utet-p1-set-c__stim_061` body: the Sanskrit `### C1./C2.` sections that were merged into the English passage were removed |
| `paper_forms` | 0 | 0 | **62** | `modules_json` now stores the real section codes of the paper; `total_questions` corrected on the 7 UTET Paper-2 forms |
| `appearances` | 0 | 0 | **9,720** | 85 rows remapped to a different question (duplicate removal), 90 `official_option_id` values re-synchronised with the repaired key |
| `meta` | 1 | 0 | 2 | `bank_version` → `2026102020`, `last_synced` refreshed, `packs_signature` added |

### 2.1 What each change means

* **43 duplicate slots swapped (85 appearance rows).** The mock papers were sampled with replacement, so the same
  question appeared two or three times inside one 150-question paper. Instead of deleting questions, the repeated
  slot was swapped with an equally-typed question that is used exactly once in the whole vault. Every paper keeps
  150 questions, the bank keeps all 9,720 rows, and no paper repeats a question any more.
* **90 answer keys re-synchronised.** `appearances.official_option_id` is the key that gets printed; the repaired
  `questions.answer` is the truth. The two had drifted for 90 rows (16 of them were the keys that were corrected
  during the v18 repair itself, e.g. the `52°` triangle question and the five comprehension questions).
* **25 `passage_id` + 26 `seq_in_passage` changes.** The five real comprehension questions were attached to
  `utet-p1-set-c__stim_061`, the standalone grammar items were detached again, and the CTET 2020 Paper-1 passage
  was made contiguous by moving the interrupting error-spotting item to position 135.
* **13 questions refilled.** Their stem asked about an "उपर्युक्त काव्यांश / पद" that exists nowhere in the vault,
  so they could not be answered. The slot now holds a vetted question of the same section (Hindi literature and
  grammar) with four options and a verified key.
* **9,719 `topic_index` values.** Every row carried `0`, which made the column useless for offline topic filters.
  It now matches the CDN topic catalogue (alphabetical index, identical to the packs).

---

## 3. Verification of the offline vault

`python scripts/validate_vault.py --strict` now checks 14 invariants. Current state:

| # | Check | Result |
|---|---|---|
| 1 | papers with a repeated question | **0** |
| 2 | answer key drift (`official_option_id` vs `answer`) | **0** |
| 3 | questions without exactly 4 options | **0** |
| 4 | questions with an invalid answer index | **0** |
| 5 | passages with a broken sequence | **0** |
| 6 | passages split inside their paper | **0** |
| 7 | questions pointing at a missing passage | **0** |
| 8 | passages without any question | **0** |
| 9 | papers not exposing a clean 1…150 after the stream filter | **0** |
| 10 | questions without their stimulus | **0** |
| 11 | topic index drift | **0** |
| 12 | CDN manifest / `papers.json` version agreement | **v2026102020 / v2026102020** |
| 13 | pack ↔ SQLite question id, section, key, passage mapping | **0 mismatches** |
| 14 | `PRAGMA` / question totals | 9,720 · 181 passages · 62 forms · 9,720 appearances · 49 packs |

---

## 4. HTML booklet — what was rebuilt

| Area | Before | After |
|---|---|---|
| Section banners | one per *contiguous run* → 123 banners in a UTET-Paper-2 booklet, 120 of them “भाग VI” | one per *logical section* → 5 banners, correct question ranges |
| Passage binding | stimulus printed once at the top, questions scattered, a floating peek box | stimulus + its own questions inside one `<section class="q-group">`; the peek button scrolls back and flashes the passage |
| Bilingual figure | rendered twice (once per language column) | rendered once, above the two columns |
| Question number | rendered twice | once — it moves to the English column when the Hindi column is hidden |
| Option labels | `(1) (2) (3) (4)` vs `A B C D` in the OMR sheet and result | `(A) (B) (C) (D)` everywhere |
| `ensureOptionLabel` | “(B)” options were prefixed “(A)” | fixed |
| Inline statements | “A. … B. … C. …” printed as one paragraph | statement list with markers |
| Assertion–Reason | only detected with a colon after the label | also detects “दावा (A) … तर्क (B)” |
| KaTeX CDN | 3 requests per booklet, LaTeX broken offline | removed (the vault contains no LaTeX); the booklet is fully offline |
| Booklet number | `hashCode` → changed on every launch | stable (`TET-A-9582`) |
| Tables | `table { display: block }` broke the layout | proper table, wide tables scroll inside their own wrapper |
| Progress | none | live progress bar + answered/review pills |
| Question meta | none | “1 अंक” chip + आसान/मध्यम/कठिन difficulty chip |
| Keyboard | none | `1-4`/`A-D` answer, `↑↓` question, `P` palette, `Enter` OMR, `role="radio"` + focus ring |
| Print | 7 CSS lines, a question could split across pages | A4 `@page`, `break-inside: avoid` for questions, options, figures and passage groups |
| Dark mode | none | full palette, driven by the **app** theme (`data-theme`), system setting as fallback |
| Performance | `querySelectorAll` per question (O(n) × 150) | option rows cached per question (O(1)) |

**Dark-mode defect found and fixed during the release check:** the special renderers painted hard-coded dark text
(`#0f172a`, `#1e293b`) while the card background became dark, so 30 elements had a contrast ratio of **1.0**
(invisible) — the multi-statement intro, the match intro, the option text and the statement conclusion. The dark
palette now covers 42 selectors and `test/booklet_theme_test.dart` guards it.

**Compact-screen check (S23 = 360 dp, plus 320 dp):** option rows were 40 dp high (below the 48 dp touch target),
the language buttons 22 dp, and the language switcher pushed the page 20 px sideways at 320 dp. Options are now
48 dp, the buttons 32 dp, the switcher wraps, and the complex renderers have their own compact type scale.

---

## 5. App changes

| File | Change |
|---|---|
| `lib/services/exam_rules.dart` (new) | single source of truth for duration and cut-offs (60 % / 55 %, 90 / 82 for 150) |
| `lib/models/test_session.dart` | full session serialisation (`encode`/`decode`), wall-clock `remainingSecondsAt` |
| `lib/models/question.dart` | `toJson` / `fromJson` for the history snapshot |
| `lib/database/db_helper.dart` | Paper-2 stream filter (Math/Science vs Social Studies never mixed), vault version `2026102020` |
| `lib/services/mock_engine.dart` | every passage resolved into the session (DB → official repository) so CBT and solution review show the same text |
| `lib/screens/cbt_exam_screen.dart` | wall-clock deadline, lifecycle observer, empty-paper guard, progress strip, figure options, full session snapshot on submit |
| `lib/screens/html_booklet_screen.dart` | booklet built with the app theme, WebView background follows the theme, full snapshot saved, navigation to `ResultScreen`, duplicate-submit guard |
| `lib/screens/result_screen.dart` | `ExamRules` cut-offs, `fromHistory` flag (no review popup when reopening an old result) |
| `lib/screens/home_screen.dart` | history card opens the full result, same pass rule |
| `lib/screens/solution_screen.dart` | expandable passage instead of a five-line cut, figure rendering |
| `lib/design_system/app_typography.dart` + `pubspec.yaml` + `lib/main.dart` | Outfit, Noto Sans Devanagari and Inter bundled (1.6 MB), weight via the variable axis, runtime font fetching disabled, system-font fallback |
| `lib/widgets/formatted_question_stem.dart` | parsed stems cached (smooth scrolling) |
| `lib/widgets/question_figure_catalog.dart` | `FigureSpec` equality (no needless repaints) |

---

## 6. Release tooling

* `scripts/repair_vault.py` — idempotent repair of the vault, the CDN packs and the manifest (v20).
* `scripts/validate_vault.py` — 14 strict invariants over SQLite, packs, manifest and `papers.json`.
* `bin/build_github_cdn_vault.py` — canonical, **deterministic** CDN builder (the passage order is sorted, so two
  builds produce byte-identical packs) that also removes stale pack files.
* `test/` — 64 tests, including the booklet renderer, the theme palette, the compact-screen rules and the
  renovation regressions.

---

## 7. Open items (not release blockers)

1. **Content originality.** 7,337 of 9,720 rows have a unique text; 2,383 rows share their text with another row
   *in a different paper* (no paper repeats a question any more). Producing fully unique mock papers needs new
   authored questions, not a repair.
2. **Figures.** 98 questions still refer to a drawing that is not in the vault. The vector catalogue covers 8
   question ids; the remaining ones either describe the figure in words (answerable) or need an authored diagram.
3. `memory/AUDIT_V17_REPORT.md` describes the v18 state and is kept for history.

---

## 8. Verification summary

* `flutter analyze lib` — no issues
* `flutter test` — 64/64 passed
* `python scripts/validate_vault.py --strict` — passed
* `flutter build apk --debug` — built (fonts and the v20 vault are inside the APK)
* Browser smoke tests — manual submit, auto-submit at expiry, timer restoration after reload, localStorage
  clearing, option/figure rendering, keyboard answering, dark and light palettes, 360 dp and 320 dp layouts
* Live CDN verified: `cdn/manifest.json` = `2026102020`, 9,720 questions, 62 papers, 49 packs, pack SHA-256
  match, `cdn/papers.json` = 62 forms / 9,720 appearances

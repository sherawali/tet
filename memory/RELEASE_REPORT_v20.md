# TET App - v20 Release Report

**Version** 1.0.0+1 · **Package** `com.sherawali.tet` · **Bank** `2026102020`
(`20261021_master_vault_clean_v20`) · **State**: release candidate, nothing published yet.

## 1. What the candidate gets

| | |
|---|---|
| Questions | **9,720** (all with an answer key, Hindi + English) |
| Papers | **62** (UTET P-1: 21, UTET P-2: 7, CTET P-1: 18, CTET P-2: 16) |
| Readings | **193** (every one printed with its own questions) |
| Figures | 12 vector drawings (geometry, prism, shapes, divided rectangle) |
| Practice | 30-question subject drills, topic drills, 7 practice sets per subject |
| Analysis | score, accuracy, section bars, topic table, recurring mistakes |
| Offline | **100 %** - the whole bank, the fonts and the figures live in the app |
| Updates | the question bank syncs from GitHub (new papers, fixes, flash messages) |
| Language | Hindi / Bilingual / English, and the booklet follows the app language |

## 2. What the user sees on the screen

- **Home** - exam switch (UTET/CTET), paper switch (Paper-1/2), **stream switch for
  Paper-2** (Math & Science / Social Studies), the live sync banner, the hero
  carousel of board papers, the paper list with the year stamp, the free / paid
  badge and the subject grid (only the active stream).
- **Booklet** - A4 print ready, sticky bar with timer, answer counter, OMR sheet,
  question palette, submit flag and exit; keyboard shortcuts; language switcher;
  dark and light palette; the result card with the score, the section bars and the
  topic table.
- **CBT** - one question per screen, big font, progress strip, the palette sheet,
  the language sheet, the submit sheet.
- **Result** - the verdict card, the section analysis, the topic table, the
  guidance card (in the language of the app) and the "re-test the questions you
  keep getting wrong" button.
- **Settings** - target exam, paper, stream, test mode, language, Pro Pass,
  database care, update check, and the **debug only** Pro Pass switch (paid view /
  free view).

## 3. Is it ready for the store?

| | |
|---|---|
| Package id | `com.sherawali.tet` (branded, not a placeholder) |
| Launcher name | शिक्षक पात्रता परीक्षा |
| Launcher icon | custom navy + gold "TET" mark (not the Flutter default) |
| Signing | a fresh release key (RSA 2048, 30 years), three backups, git ignored |
| Build | release APK 66 MB · **AAB 54 MB** (R8 shrunk, Play Billing classes kept) |
| Tests | 91 tests, `flutter analyze` clean, vault validator green, 0 audit findings |
| CDN | live: 9,720 questions, 62 papers, 49 packs, every pack hash verified |
| Privacy | the only permission is the network (for the optional bank update and the
  error reports); the bank itself is offline |

### Still open before the store

1. **Play Console products** - 3 subscriptions (₹399 / ₹1,499 / ₹2,499) - see
   `docs/PLAY_STORE_PASS_SETUP.md`.
2. **Store listing** - the description, the screenshots, the privacy policy and
   the data safety form. Note: an error report can carry a free text comment
   that is sent to a GitHub issue, so the listing has to say that.
3. **The report sheet** is still Hindi first (a teacher tool) - it should get an
   English version.
4. **2,383 questions** appear in a second paper as well. Every paper is unique
   inside itself, but a mock paper and a board paper can share a question. New
   content is needed to remove that; it cannot be fixed by a script.

## 4. How a new mock paper reaches the app

1. Add the paper to the vault (or to the source and re-run the ingest).
2. `python bin/build_github_cdn_vault.py` - rebuilds the packs and the manifest.
3. `git push` - the app syncs the new manifest and the new bank on the next
   start (or from the "update" button).
4. Free or paid? Put the paper id into `free_form_ids` or `paid_form_ids` in
   `bin/remote_access.json` and repeat step 2 and 3. **No app release needed.**

## 5. Release checklist

- [x] 9,720 questions audited, 0 findings
- [x] every reading bound to its own questions, no paragraph in an option
- [x] booklet proven for all 62 papers (9,300 questions, 27,487 options)
- [x] no overflow on a 360 dp phone (result, solution, CBT are guarded by a test)
- [x] one design system: colours, motion, dialogs, sheets, type scale
- [x] one language at a time, guarded by a test
- [x] release key + package id + AAB
- [ ] Play Console products and the price
- [ ] store listing, privacy policy, data safety
- [ ] publish the GitHub release (it is still a draft)

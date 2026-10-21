# TET App — Release Notes v20 (offline bank, real readings, drawn figures)

**Version:** 1.0.0+1 · **Bank:** `2026102020` / `20261021_master_vault_clean_v20`
**Works fully offline** (wifi + data off) — the whole bank ships inside the app.

## What a candidate gets

| | |
|---|---|
| Questions | 9,720 (62 papers) |
| Readings (गद्यांश / काव्यांश) | 193 — every one of them attached to its own questions |
| Questions that cannot be answered | **0** |
| Papers with a repeated question | **0** |
| Figures without a drawing | **0** |

## What was fixed in this release

1. **Real readings brought back.** The questions that talked about "the passage" without a
   passage were matched against the original source folder
   (`Desktop/tetmaster/UTET_Paper1_Passages.md`) and the **actual** text was restored:
   Alice in Wonderland, Gandhi's autobiography, Workaholism & corporate culture,
   The last great war, Law, शिक्षा, अवकाश. No passage was invented.
2. **Unanswerable questions removed.** Where a reading exists in no source at all
   (some UTET Paper-2 board papers, some CTET English groups), the whole group was replaced
   with self-contained questions of the same section — so every printed question has an
   answer.
3. **Booklet binding.** A reading is printed once, inside the same block as its own
   questions, and never leaks into an option.
4. **Figures drawn.** The questions that point to a picture now show a real vector drawing
   (parallel lines with angles, four shapes, the divided rectangle, the triangular prism),
   in the app *and* in the printed booklet, light and dark.
5. **Dark mode fixed for figures** — the vector drawings were unreadable on the dark
   background, now they follow the booklet palette.
6. **Offline first.** The bank is bundled, a newer bank downloaded from the CDN is never
   overwritten by the bundled one, and the whole test runs without any network.

## How to check it yourself

```powershell
python scripts/repair_vault.py        # idempotent repair
python scripts/validate_vault.py --strict
flutter test                          # 76 tests
flutter analyze                       # 0 issues
flutter build apk --debug
```

The booklet proof test prints:
`Verified 62 papers, 9300 questions, 27485 options, 193 passage groups`

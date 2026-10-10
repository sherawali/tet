# answer_rekey.json — provenance & confidence notes (2026-10-10)

541 entries = 540 broken keys (18 all-'a' sections) + 1 documented correction (2018-m-evs-q064 → NCF-2000).

## Sources used (content-mapped; bank language-section option orders are shuffled vs all booklets)
- **2024-i = CTET 21 Jan 2024, SET I** (identified: CDP Q1–30 letters match official SET-I grid 30/30).
  - Official final key: `https://cdnbbsr.s3waas.gov.in/s3443dec3062d0286986e21dc0631734c9/uploads/2024/02/2024021954.pdf` (F1JANKEY, 13/02/2024) — Set-I PAPER-I MAIN grid applied verbatim for CDP/Math/EVS (q001–q090).
  - Note: EVS q080 official key = "Z" (ALL options accepted); we store `d` (portfolio) as representative.
  - Languages: content-mapped via theexampillar (Set-K display+answers, 29/30 match official Grid C for Lang-II-English), oswaal solved PDF (question/option displays), and grammar/pedagogy reasoning. Official Set-I language grids exist but bank option orders are shuffled per question, so letters were never transplanted raw.
- **2026-e = CTET 08 Feb 2026 (FSC-26-I)** (identified: Q1 = "Misconceptions among students…", prepp question-paper PDF).
  - Prepp "Code-C" answer-key PDF exists (`cdn-images.prepp.in/.../CTET_2026_Paper_1_Answer_key_PDF_08_Feb_2026_Code_C__...pdf`) but is a different set's lettering (bank option order = FSC-26-I printed order, verified against prepp paper PDF).
  - Content-solved; q035 verified against testbook (official paper page): Game Theory → Ramanujan.
  - Official final key PDFs at `ctet.nic.in/previous-year-final-answer-key/` ("CTET Feb26 Answer Key P1 08Feb2026") — not machine-fetched (site fetch blocked); use for spot-checks if needed.
- **2018-m-lang1-en / lang2-en = CTET Dec 2018 Paper-1 Language I & II (English)** — content-solved (castles, Little Black Boy, maxim, Kevlar passages + pedagogy).
- **2018-m 8 audit corrections (docs/CTET_PAPER1_AUDIT.md)** — CSV letters map to different option orders; matched by CONTENT:
  - preoperational "symbolic thought" = 2018-m-cdp-q003 → b (already correct)
  - discovery/inductive = 2018-m-mathematics-q044 → a (already correct)
  - assessment precision = 2018-m-mathematics-q031 → c (already correct)
  - family not inclusive = 2018-m-environmental-studies-q081 → c (already correct)
  - BALA = 2018-m-environmental-studies-q088 → c (already correct)
  - stereotype = 2018-m-environmental-studies-q090 → c (already correct)
  - NCF-2000 integrated EVS = 2018-m-environmental-studies-q064 → **c** (CHANGED from d; audit L3937+L82)

## Provisional answers (content-guessed; passages missing/lost at import — verify after passage restoration)
- 2026-e-mathematics-q039 — **option texts broken at import** (fractions lost, only numerators "8/4/3/3" survive); answer `a` is a placeholder. Restore options from prepp FSC-26-I paper PDF.
- 2026-e-lang2-en-q121/125/126/127/128 (tea-seller/boy passage) — a,c,a,d,a (passage = restore-scope "2026-en-pr-121").
- 2026-e-lang2-hi-q121/125/127/128 (लीडर/संघर्ष passage) — c,a,b,b (passage = restore-scope "2026-hi-pr-121").
- 2026-e-lang1-en-q095/096 (Tarawati/Roopa) — d,a (passage = restore-scope "2026-en-pr-91").
- 2026-e-mathematics-q045 (Van Hiele folding) — a (Level 1 Analysis), plausible but unverified.
- 2018-m-lang1-en-q105 (Blake "bereav'd of light") — a; q114 cloze — a; q116 alphabetic — a; q118 NCF English — a; q119 (dialogue LOST at import) — a; q120 immersion — b.
- 2018-m-lang2-en-q124 (statements lost at import) — b; q126 — d; q127 — c; q142 — c; q146 — b.
- 2024-i languages: q-sa-092 (Vyasa bhashya) — b; q-sa-121 (Samaveda→Brahma) — c; q-sa-124 (एतादृक्ष) — b; q-sa-125 (195 sutras) — a; hi-q101 (नीति+इक) — c; en-q101 ("exits and entrances" figure) — b (oswaal grid dissents with "personification").

## Established constraints (this session)
- Apply keys ONLY with `tools/v2/apply_answer_keys.py` (writes question.answer.optionId + appearance.officialOptionId together; supports `--dry-run`).
- Rule-1 distribution: all 18 sections ≤60% after rekey (worst 13/30 = 43%).
- verify_all_questions.py: all 7 categories PASS after rekey (540-row all-'a' failure resolved).
- Pipeline ran: build_app_db (2880 q / 109 stimuli → runtime/tet_mock_vault.db), build_cdn_packs (15 packs + manifest), BANK_VERSION 20261006→20261010.

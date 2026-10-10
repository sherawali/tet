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

## Cleanup pass 2 (2026-10-10) — text integrity + hi/en parity

All verified by content; applied via `tools/v2/repair_cleanup_pass2.py` (idempotent).

- **Option-D leak removed** `ctet-p1-2026-e-lang1-hi-q099`: option d contained next question's instruction + `(100-105)` range marker + the full poem. Restored real poem (from the leaked text; matches q100–105 quotes) into `ctet-p1-2026-stimulus-hi-po-100`. Also fixed `मं़िजल`→`मंजिल` typo in that set.
- **Poem restored** `ctet-p1-2024-stimulus-hi-po-100` = "आज तिरंगा फहराता है" (सजीवन मयंक) — source: anubhuti-hindi.org/ghazalhighazal (full text) + q100–105 quote match (छल/लंबी चली लड़ाई थी/कीमत बड़ी चुकाई थी/वीर शहीदों के बलिदान से/स्वाभिमान). Replaced placeholder verses.
- **Math hi+en repairs**: 2026-e q047 (HCF/LCM text lost in hi, "HCF=18 LCM" bleed in en), q052 (x variable eaten in hi, bleed in en), q053 ("9 kg 995 g" lost in hi), 2024-i q041 (subject "1" lost in hi c/d; trailing "1" in en), q048 (price/qty garbled both), q056 (die-results list missing in en), 2023-e q045 (en end-time 24:15→21:15; matches answer d = 4h25m), q057 hi opt b duplicated→"6 as 1 added to 5", 2019-a q040 ((cid:1) bullets → (i)(ii)(iii)), 2016-i q044/45/46/50 hi `……` → canonical `[ ________ ]`, utet 2020 q095 (en option values restored: 15.59 g / 155.9 dag / 0.01559 kg / 1.559 hg), utet 2021 q106 (subtraction figure added to hi; question text added to en), utet 2024 q112 (series missing in hi), utet 2025 q114 (unit in en).
- **EVS**: 2019-a q076 hi options were all "h" (column bleed) → "53/45/132.5/60 किमी/घंटा" (+ km/h in en; answer a=53: 2120/40h); 2024-i q086 "4/5 students" split bleed repaired both.
- **CDP**: 2019-a q003 opt a exam-metadata leak removed (hi "(परीक्षा -2019 …" + en "CTET) Class I-V)").
- **Junk signs removed**: utet 2026 evs-q128 `*(tags)*`, utet 2020 math-q117 `*(चित्र … प्रिज्म)*` (was answer-leaking; now neutral figure description), utet 2026 math-q116 `expression*`, sanskrit 2023-e q148 `अ*ङ्गमस्ति`, utet 2024 lang1-hi-q058 editor's `*टिप्पणी` note, utet EN stimuli italic-star title artifacts (ut21-e2, ut22-e1).
- **Missing hi statements added**: utet 2020 cdp-q009 (4 maxims), utet 2020 evs-q128 (4 reasons) — matching en.
- **2021-dec math-q057**: figure bleed "+ 3811" removed (original student-work figure lost at import; question still answerable — remediation techniques don't depend on exact figure).

Post-pass scans: single-star leftovers 0; leaked number/range markers in prompts 0; verify_all_questions.py 7/7 PASS; DB/packs rebuilt (BANK_VERSION 20261010).

Still pending (passage restoration map): 2018-en-po-100 Blake, 2019-en-po-100 Tennyson, prose leaks→stimuli (2026-en-po-100 Kalahandi etc.), unlink fake stims, reconstruct from question constraints (2018 castles/maxim/Kevlar, 2019 endeavours, 2023 Garud/Mizoram, 2026 Tarawati/tea-seller, hi sets), then re-verify provisional answers.

## Cleanup pass 3 (script: tools/v2/repair_cleanup_pass3.py)

Restored 6 placeholder stimuli (ctet 2026-e, paper-1):
- lang1-en pr-91 = Tarawati/Roopa full passage (source: prepp.in official question paper PDF FSC-26-I/Code-E, Part-IV; 'Things were lying at sixes and sevens' line reconstructed from q099).
- lang1-en po-100 = Kalahandi extract 'Put away the road maps now...' (same PDF; replaces wrong Frost poem).
- lang2-en pr-129 = tribes/patriarch passage (recovered from q128 option-D leak in commit 7a6aa96).
- lang2-hi pr-129 = 'हिंदी बनाम स्थानीय भाषाएँ' passage (recovered from hi q128 option-D leak, same commit).
- lang2-en pr-121 = tea-seller/boy story — PROVISIONAL reconstruction from q121-128 constraints ('sped like a bullet towards the girl', 'in the quavering light', 'And what was that in his hand?', casual wear, old woman, son of tea-seller, no attack on sister, big sound, curious young man). Original passage unrecoverable online.
- lang2-hi pr-121 = लीडर/संघर्ष passage — PROVISIONAL reconstruction from q121-128 constraints (शरीर का राजा, जन्म लीडर बनने के लिए, संघर्ष-नेतृत्व=जीवन का सत्य, सत्ता प्राप्त करने के लिए संघर्ष).

Restored destroyed fractions: ctet-p1-2021-dec-d-mathematics-q037 options =
  a=3/8, 4/16, 1/4, 1/8 (=1 ✓); b=1/4, 1/2, 1/2; c=1/8, 5/8, 3/8; d=4/16, 2/5, 3/8
  (source: testbook.com QA for CTET 31 Dec 2021; letter map a/b/c/d = set 1/2/3/4).

Markdown tables → plain text (app renders no markdown): 2019-a-evs-q071 (match columns), 2021-dec-d-lang2-en-q128/q135 (sentence parts), 2026-e-math-q041 (eye-colour table), 2019-a-math-q039 (price list), q041 (parking rates). Format: "header:" + one item per line.

Underlined-word prompts now name the target word: 2026-e-lang2-en-q122 ('towards'), q124 ('quavering'), q130 ('them'), 2026-e-lang1-en-q092 ('to broker'); q123 quoted as sentence.

Open follow-ups:
- 2026-e-math-q039 options bare ['8','4','3','3'] — restore fractions from prepp PDF math section.
- Underlined-word prompts in 2023-e/2024-i/2020-i lang sets lost their underlines (quotes elided with [ ______ ]); recover per question from source papers.
- OCR sweep: 'कौन कार्यक्रम' type grammar slips across all sets.

## Cleanup pass 4 (script: tools/v2/repair_passages_pass4.py) — 2026-10-10

Scope of this revision: **CTET Paper-I, 09 Dec 2018, English (Language-I + Language-II)**.
All four placeholders in that cycle were fabricated at import time — `import_all_ctet.py`
carries the generic essays inline, and they have been identical in every commit since
`e33e5c0`, so no git-leak recovery was possible. They were sourced from the web instead.

Restored:
- `ctet-p1-2018-stimulus-en-pr-91` = **"Castles"**, full 6 paragraphs (was a 313-char
  "Bringing up children is a delicate art" essay). Source: ereadingworksheets.com
  "Castles — Nonfiction Reading Test", the text CTET adapted.
  *Why the full version and not testbook's condensed 4-paragraph rendering:* official key
  for Q92 ("main idea in Paragraph 2") is (2) "It explains why castles were first built in
  England and the military purposes they served", which is true only when Paragraph 2 is
  "Castles were originally built in England by Norman invaders in 1066 …". In the condensed
  rendering Paragraph 2 is the list of purposes and the key would have to be (4). Also Q92's
  distractor (3) "Norman lords … frequently retreated" only exists if the sentence "The
  castles he built allowed the Norman lords to retreat to safety when threatened by English
  rebellion." is present — the condensed rendering drops it. 'pinnacle' (Q99) and 'vestiges'
  (Q98) are both present. All 9 questions now answerable from the stored text.
- `ctet-p1-2018-stimulus-en-po-100` = **William Blake, "The Little Black Boy"** (Songs of
  Innocence, 1789, public domain), all 7 stanzas. Was Masefield "Sea Fever", which none of
  Q100–105 refers to; Q100–105 quote "the southern wild", "bereav'd of light", "like a shady
  grove", "a cloud", "learn to bear the beams of love". B-list item closed.
- `ctet-p1-2018-stimulus-en-pr-121` = **"necessity is the mother of invention"** maxim
  passage (was "Scientific temper…"). Source: theexampillar.com CTET 2018 Language-II
  English booklet reproduction.
- `ctet-p1-2018-stimulus-en-pr-129` = **"Kevlar" / Stephanie Kwolek** passage, 4 paragraphs
  (was "Physical exercise…"). Same source.

Structural fix (new finding — group boundary was wrong):
- The 2018 Lang-II English comprehension groups are **121–129** (maxim, 9 questions) and
  **130–135** (Kevlar, 6 questions), not 121–128 / 129–135. `q129` asks the meaning of
  'exhorting', which occurs only in the maxim passage, so
  `ctet-p1-2018-m-lang2-en-q129.stimulusId` was re-linked `pr-129 → pr-121`, and both
  stimuli got corrected `minimumQuestions` (9 / 6) and instruction ranges.

Prompt repair:
- `ctet-p1-2018-m-lang2-en-q124` — the statements behind options "Only I / Only I and II /
  Only III / Only II and III" were lost at import. Restored verbatim from the booklet
  (I. Man should be passive…; II. Spirit of inventiveness may not stand in good stead…;
  III. Man has a passion for more and more knowledge). Roman numerals kept because the
  options name them.

Answer keys corrected (were provisional content-guesses; now booklet-verified):
- `ctet-p1-2018-m-lang2-en-q121` c → **b** ("Necessity is the mother of invention." — the
  passage says this maxim is true "in a general way … by no means the whole truth").
- `ctet-p1-2018-m-lang2-en-q124` b → **c** (Only III; I contradicts "not to be passive",
  II contradicts "can be tackled successfully with the spirit of inventiveness").
- `ctet-p1-2018-m-lang2-en-q127` c → **d** (the inner spirit exhorts him to *cut down* his
  needs, so "be on the look out for newer and higher wants" is the untrue statement).
- `q122/q123/q125/q126/q128/q129` and all of `q130–q135` (Kevlar) re-checked against the
  booklet — already correct, no change. `q105` (Blake, 'bereav'd of light') stays **a** and
  is no longer provisional now that the poem is in the bank.
- The three corrections are recorded in `answer_rekey.json` (still 541 entries) and applied
  with `apply_answer_keys.py`, so question.answer and appearance.officialOptionId moved
  together.

Post-pass checks: `verify_all_questions.py` 7/7 PASS (2880 q / 109 stimuli); rule-1
distribution re-scanned over all 96 section groups ≥20 questions → 0 sections above 60%
(worst unchanged); `build_app_db.py` → 2880 q / 109 passages; `build_cdn_packs.py` → 15
packs, stale `pack-0001-ee974362f2af.json` deleted, manifest references only on-disk packs.

### ⚠ Blocker found while rebuilding — corrected content cannot reach installed apps
`README.md` documents the app sync as
`need = remote.packs.filter { it.id !in have }`, i.e. diffing by pack **id**, while
`build_cdn_packs.py` sets `id` to the zero-padded pack index (`"0001"`). A content fix
therefore produces the same `id` with a new `sha256`, and an app that already stored
`"0001"` will never re-download it. On top of that `bank_version` is a YYYYMMDD stamp and
the guard is `remote.bank_version <= localVersion`, so a second release on the same day is
invisible too. Passes 2, 3 and 4 are all affected — this is the real cause of the "stale
app cache" symptom in the handover, not just device caching. Needs a contract decision
(sha256-based diff with replace-and-prune) before more restoration work is worth shipping.

### Remaining A-list (re-scanned this session — larger than the handover's 15)
Prose stimuli serving 7–9 questions but holding <600 chars (Sanskrit excluded: CTET
Sanskrit गद्यांश are genuinely short, 90–250 chars):
- 2016 en pr-121 (433) / pr-143 (489), hi pr-112 (511) — real texts, likely truncated
- 2018 hi pr-97 (318), pr-121 (284), pr-129 (179) — fabricated
- 2019 en pr-91 (642, Kangri Karchok — real, truncated), pr-121 (200), pr-129 (167);
  hi pr-91 (267), pr-121 (321, real NCF-style opener, truncated), pr-129 (203)
- 2021-dec en pr-91 (534, real), pr-121 (312, real, truncated), pr-129 (387, Ruskin Bond,
  truncated); hi pr-91 (546, real), pr-121 (247), pr-129 (409, Krishnamurti, real)
- 2023 en pr-97 (318), pr-121 (210), pr-129 (206); hi pr-97 (233), pr-121 (156), pr-129 (141)
- 2024 en pr-91 (189), pr-121 (139), pr-129 (137); hi pr-91 (328), pr-121 (158), pr-129 (123)
- 2026 hi pr-91 (386, "अहंकार" placeholder — needs the Hindi Tarawati)
- provisional reconstructions still open: 2026 en pr-121 (820), 2026 hi pr-121 (477)

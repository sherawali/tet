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

## Passage-integrity tracker (tools/v2/audit_passage_gaps.py) — added this session

Single source of truth for "kitna hua, kitna bacha". Carries a curated status
table (DONE / TRUNCATED / FABRICATED / PROVISIONAL / MISSING / UNVERIFIED) plus
a structural scan, so it also catches groups whose stimulus record was never
created. Run it after every restoration pass; `--md` prints a markdown table.

Snapshot after pass 4 (2018 English closed):

| status | groups | questions |
|---|---:|---:|
| DONE | 22 | 161 |
| TRUNCATED | 11 | 87 |
| FABRICATED | 21 | 168 |
| PROVISIONAL | 2 | 16 |
| MISSING | 2 | 17 |
| UNVERIFIED | 53 | 310 |
| **total** | **111** | **759** |

Confirmed-broken CTET groups remaining: **36 groups / 288 questions**
(21 FABRICATED + 11 TRUNCATED + 2 PROVISIONAL + 2 MISSING). Pass 4 closed 4
groups / 30 questions.

Two structural gaps the handover did not list, found by the tracker — these
question groups have NO stimulus record at all, so the app shows them with no
passage above them:
- `ctet-p1-2016-i-lang1-hi-q097 … q105` (9 questions) — 2016 Lang-I Hindi गद्यांश
- `ctet-p1-2016-i-lang2-en-q128 … q135` (8 questions) — 2016 Lang-II English second passage
The handover's B-list attributed missing poem ids to 2018-hi-po-100 /
2023-en-po-100 / 2023-hi-po-100; those cycles simply have no poem group at
100-105 (their Lang-I runs poem 91-96 + prose 97-105), so nothing is missing
there. The real holes are the two 2016 groups above.

UNVERIFIED (53 groups / 310 questions) = 24 UTET groups, 20 CTET Sanskrit
groups, and 9 poems/misc. These are length-plausible but have not been checked
against a paper yet. CTET Sanskrit गद्यांश really are short (the clean 2020-i
Sanskrit imports run 530-2069 chars while the other cycles run 82-243), so the
non-2020 Sanskrit set is the suspicious half of that bucket.

## Cleanup pass 5 (script: tools/v2/repair_unlink_pass5.py) — fabricated passages removed

**New class of defect.** `import_all_ctet.py` minted a prose stimulus for every fixed
question range (91-99, 121-128, 129-135 …) whether or not the official booklet had a
गद्यांश there. CTET Language-II 121-150 is भाषा-शास्त्र / language pedagogy + grammar in
most cycles — no passage at all — so the importer stapled a generic moral essay onto
standalone pedagogy questions. That is worse than a missing passage: the app shows a
fabricated paragraph above questions like "वाइगोत्स्की ने भाषा-विकास का ___ परिप्रेक्ष्य
प्रस्तुत किया" or "Top-down means 'attend to the overall meaning'. What does 'bottom-up'
mean?", sending the learner hunting through irrelevant text.

Verified stem by stem that all 93 questions are answerable from their own stem + options,
and that not one stem refers back to a passage. The script re-asserts this with a
multilingual marker regex (the passage / अनुच्छेद / गद्यांश / उपर्युक्त …) and fails loudly
before writing, so a future real passage-dependent question can't be silently unlinked.

Removed 12 stimuli, unlinked 93 questions:
- 2016 Lang-II Sanskrit q121-128, q129-135
- 2018 Lang-I Sanskrit q091-099; Lang-II Sanskrit q121-128, q129-135; Lang-II Hindi q121-128, q129-135
- 2023 Lang-I Sanskrit q091-099; Lang-II English q121-128, q129-135; Lang-II Hindi q121-128, q129-135

verify_all_questions.py 7/7 PASS, stimuli 109 → 97; DB rebuilt (97 passages); 15 packs
regenerated, 6 stale packs deleted.

## Sanskrit verdict (was UNVERIFIED, now classified)

All 20 non-2020 CTET Sanskrit prose stimuli are fabricated generic subhashita-style essays,
and **every one of them mismatches its own question group** — e.g. `2019-sa-pr-91` holds a
desert-traveller story while its questions ask about नर्मदा / अमरकण्टक / डिण्डोरी. Only the
2020-i Sanskrit imports (530-2069 chars) are real. 10 groups therefore moved
UNVERIFIED → FABRICATED, with the topic each needs recorded in the tracker table:

| stimulus | questions actually need |
|---|---|
| 2019-sa-pr-91 / 121 / 129 | नर्मदा-अमरकण्टक / दण्डचतुष्टय (bundle of sticks) / चाणक्य-कम्बल |
| 2021-dec-sa-pr-121 / 129 | नागार्जुन-युवकौ / रानाडे |
| 2023-sa-pr-121 / 129 | सिद्धार्थ-देवदत्त / मृगेन्द्र-सिंह |
| 2024-sa-pr-91 / 121 / 129 | योग-मोक्ष / सामवेद-योगदर्शन / साङ्ख्ययोग-हठयोग |

## Real passages identified behind the remaining FABRICATED placeholders

Reading the question stems identifies what each placeholder is standing in for, which makes
them searchable rather than guesswork:
- 2023-en-pr-97 (q97-105) — **Garud, 69, travelling solo in Mizoram**; horse-riding, dancing
  at a festival, ex-athlete. Currently "The secret of happiness…".
- 2024-en-pr-91 (q91-99) — **Mrs. Higgins / Alfred / Mr. Carr, drug store** = Morley
  Callaghan's "All the Years of Her Life". Currently "Human ingenuity…".
- 2024-en-pr-121 (q121-128) — **Scarecrow / Dorothy / nuts / "kept her snug"** = Wizard of Oz
  extract. Currently "Reading opens doors…".
- 2024-en-pr-129 (q129-135) — **birder, bird calls, Delhi, "wild exultant laugh", "belligerent"**.
  Currently "Cooperation in communities…".
- 2019-en-pr-121 (q121-128) — freedom / 'endeavours' (para 1) / 'shun' (para 2) / established
  religion / authorities suppressing freedom fighters. Currently "History demonstrates…".
- 2019-en-pr-129 (q129-135) — **Uttarakhand Himalayas, water, perennial streams**, 'bounty',
  'benevolent'. Currently "Curiosity is the engine…".
- 2019-hi-pr-129 (q129-135) — गाँव को प्रयोगशाला, 'फर्स्ट हैंड समझ', ज्ञान. Currently "भाषा अभिव्यक्ति…".
- 2021-dec-hi-pr-121 (q121-128) — नदियों का पहाड़ी सफर, 'सरसब्ज', 'उल्लास'. Currently "वैज्ञानिक अनुसंधानों…".
- 2024-hi-pr-121 (q121-128) — गंगा, अल नीनो, ग्लेशियर, 2050 जल-संकट. Currently "श्रम ही जीवन…".
- 2024-hi-pr-129 (q129-135) — पाप और पुण्य, जंजीर की तुलना. Currently "वाणी में मधुरता…".
- 2026-hi-pr-91 (q91-99) — सृष्टि निर्माण, सद्भाव, अहंकार, मान-सम्मान. **The handover's claim
  that this is the Hindi twin of the Tarawati passage is wrong** — CTET Lang-I Hindi is its own
  section, and q91-99 are about अहंकार/सद्भाव, not Tarawati/Roopa.

Two more defects logged, not yet fixed:
- `ctet-p1-2016-i-lang1-hi-q119` ("अकबर का जन्म कहाँ हुआ था?") is linked to the मीना/रमेश
  dialogue stimulus — content mismatch, it belongs to a different (missing) गद्यांश. q120
  (मुहावरा) is standalone and should be unlinked too.
- 2016 Lang-I Hindi q097-105 and 2016 Lang-II English q128-135 still have no stimulus at all.

Snapshot after pass 5 (`python3 tools/v2/audit_passage_gaps.py`):

| status | groups | questions |
|---|---:|---:|
| DONE | 22 | 161 |
| NO-PASSAGE (closed, stimuli deleted) | 12 | 93 |
| TRUNCATED | 11 | 87 |
| FABRICATED | 25 | 201 |
| PROVISIONAL | 2 | 16 |
| MISSING | 2 | 17 |
| UNVERIFIED | 37 | 184 |
| **live total** | **99** | **666** |

## Cleanup pass 6 (script: tools/v2/repair_passages_pass6.py) + official-key diffing

Pass 6 is a *registry* rather than a one-off script: RESTORATIONS is keyed by stimulus id and
each entry carries its provenance plus a `must` list of substrings the linked questions
demand, asserted before anything is written. Later cycles append entries instead of adding a
new pass file.

Restored: `ctet-p1-2018-stimulus-hi-pr-97` = the गीत-कविता अनुच्छेद (1724 chars, 2 paragraphs,
9 questions). Source: testbook QnA 60a78c29f445f1e2f831d702 carries both paragraphs in full;
theexampillar's CTET 2018 Language-I Hindi page carries the same text but drops the block
between "कक्षाओं की" and "दूसरी ओर", so testbook was used as the base and theexampillar to
repair its typos. One OCR drop repaired and logged: "चाहते हैं कि शिक्षक पहले …" (the
subordinating कि is absent from both reproductions but the clause cannot stand without it).

### Why the official paper PDF could not be used for the Hindi text (important, permanent)
`ctet.nic.in` itself does not fetch. The prepp mirror of the official booklet
(`cdn-images.prepp.in/public/image/ctet-2018-paper-1-question-paper-and-answer-key-pdf-1761896188.pdf`,
booklet **MVD18–I**, Booklet Code **I**) is fetchable, but:
1. its Devanagari text layer is encoded in a **legacy Kruti-Dev font**, so Hindi comes out as
   `narjm nwpÒVH$m` for परीक्षा पुस्तिका — unusable without writing a Kruti-Dev→Unicode decoder
   (only some EVS pages carry a clean Unicode OCR layer alongside the garbage);
2. the booklet is ~42 pages and `fetch_page` caps at 30, which ends inside Part III (EVS q76).
   **Parts IV and V — both language sections — are beyond the cap entirely.**
So for Hindi/Sanskrit passages, booklet reproductions (testbook / theexampillar / gkscientist)
remain the only route, and for English passages the official PDF is reachable only if a
section-scoped PDF exists.

### Official CBSE answer key obtained — and it contradicts the previous rekey
The key PDF is small and fully fetchable:
`cdn-images.prepp.in/public/image/ctet-2018-paper-1-answer-key-1761917805.pdf`
= "CTET DEC-2018 KEY EXAM-09/12/2018 Date. 31/12/18, Set :- I, PAPER-I", with three grids:
MAIN (q1-90), 01-ENGLISH (q91-150), 02-HINDI (q91-150). Stored verbatim in
`tools/v2/official_keys/ctet-2018-paper1-set-I.json`, and diffed with the new
`tools/v2/verify_against_official_key.py <keyfile> <cycle>`.

First diff: **202 matched, 8 mismatched**. All 8 resolved in favour of the official key:

| question | was | official | content |
|---|---|---|---|
| evs q064 | c | **d** | NCF-1975 (pass-1 "documented correction" to NCF-2000 was wrong) |
| evs q090 | c | **a** | myth, not stereotype |
| lang1-en q105 | a | **d** | 'bereav'd of light' → All of the above |
| lang1-en q114 | a | **b** | 'Cloze' → missing part |
| lang1-en q115 | c | **d** | last stage of writing → advanced writing |
| lang2-en q123 | b | **c** | spirit tells him to cut down his desires |
| lang2-en q144 | c | **d** | graded inputs from the target language |
| lang2-en q145 | a | **b** | "The students are giving their examination." |

**7 of the 8 came from `answer_rekey.json`** — i.e. the previous session's content-solving
actively corrupted keys that were right before, and q123 is provable: the imported bank had
`c`, the rekey file overwrote it with `b`, the official key says `3` = `c`. q090 was the only
one inherited from the import.

Re-diff after applying: **210 matched, 0 mismatched**, and no drift anywhere between
`question.answer.optionId` and `appearance.officialOptionId`. Pass-4's three corrections
(q121 c→b, q124 b→c, q127 c→d) are independently confirmed by the official grid. Rule-1
distribution re-scanned for all nine 2018 sections: worst is lang2-sa at 43%, 0 violations.
verify 7/7 PASS (97 stimuli), DB + 15 packs rebuilt, 3 stale packs deleted.

**Consequence for the rest of the bank:** the 542-entry rekey file cannot be trusted as a
source of truth. Every cycle must be diffed against its official key grid before its answers
are called verified. Sanskrit is not covered by the MAIN/ENGLISH/HINDI grids — it needs the
separate Sanskrit supplement key.

Two label defects noted, not changed (renaming ids is risky and cosmetic):
`bank-v2/sources/ctet-p1-2018-sources.json` records `canonicalSet: "M"` and appearances carry
`setCode: "M"`, but the official booklet is **Set I / MVD18-I**. Also official key q74 = "9"
(all options accepted, marks to all); the bank stores a representative letter, same treatment
as 2024-i EVS q080.

## Release 2026101100 — pipeline repaired, fabricated groups held back

### Why two weeks of fixes never reached a device (all four breaks now closed)
1. **Nothing was on `main`.** Five commits / 37 files / +2154 −707 sat on the working branch.
   The app reads `@main`, so it still had the pre-cleanup bank.
2. **CI watched a dead layout.** `.github/workflows/build.yml` triggered on `content/**` and ran
   `tools/build.py`; neither exists since the CSV→`bank-v2` NDJSON migration, so no release was
   ever produced. Rewired to `bank-v2/**` + `tools/**` + `verify_all_questions.py`, with the
   7-category gate as a hard stop before anything ships.
3. **Pack ids were index-only** (`"0003"`), while the app downloads
   `remote.packs.filter { it.id !in have }`. A corrected pack looked "already downloaded"
   forever. Ids are now `<index>-<sha256[:12]>`, content-derived and equal to the immutable
   filename stem — so any content change is automatically a new download.
4. **`BANK_VERSION` was hardcoded 20261010** and **zero `v<N>` tags existed**, so the app's
   `remote.bank_version <= local` guard short-circuited and `@v<stamp>/…` 404'd. The stamp is now
   UTC `YYYYMMDDHH`, pinned once per run through the environment so manifest, SQLite meta and git
   tag agree; CI creates and force-updates the tag and purges jsDelivr.

App-side, one step was still missing from the documented contract and is now in the README:
`db.deletePacksNotIn(remote ids)`. Without that prune a superseded pack — and the wrong question
inside it — stays on the device forever. Passage groups are asserted to live in exactly one pack,
so pruning can never split a गद्यांश from its questions.

New tools: `tools/v2/prune_stale_packs.py` (also refuses a manifest whose pack id does not match
its content-hashed filename — the regression behind break 3) and
`tools/v2/quarantine_bad_passages.py`.

### Quarantine: 24 fabricated groups / 192 questions held back, nothing deleted
`quarantine_bad_passages.py` flips `status` to `"draft"` on every FABRICATED stimulus **and all
its questions as one unit**, then re-scans to prove no published question is left under a draft
stimulus. `build_app_db.py` now skips draft questions, their appearances, and any passage whose
only readers were drafts.

| section | before | held back | shipped | full 30-q mocks |
|---|---:|---:|---:|---:|
| cdp | 420 | 0 | 420 | 14 |
| environmental-studies | 420 | 0 | 420 | 14 |
| mathematics | 420 | 0 | 420 | 14 |
| language/en | 630 | 48 | 582 | 19 |
| language/hi | 630 | 66 | 564 | 18 |
| language/sa | 360 | 78 | 282 | 9 |
| **total** | **2880** | **192** | **2688** | — |

Database 3300 KB, 2688 questions, **73 passages**, 14 packs, 14 stale packs pruned, gate PASS 7/7
(the gate still audits all 2880 bank records — drafts included — on purpose).

Not held back, deliberately: the 11 TRUNCATED groups (87 q) and 13 UNVERIFIED poems (73 q) carry
real text that is merely incomplete or unconfirmed, and the 2 PROVISIONAL groups (16 q) are
plausible. Restoring a passage is now a silent content update — flip `status` back with
`quarantine_bad_passages.py --restore <stimulus-id>`, rebuild, and the app picks up the new pack
id on its next sync with no app release.

### Reclassification finding
The 2 `MISSING_GROUPS` entries (2016 Lang-I Hindi q097–105, 2016 Lang-II English q128–135, 17 q)
are **not** missing passages at all. Read out, all 17 are standalone pedagogy stems — "भाषा सीखने
का उद्देश्य है–", "Stephen Krashen's theory … does not consist of", "Constructivism in language
learning focuses on". They belong in `NO_PASSAGE_REMOVED` semantics (published, no stimulus), not
in MISSING. Left untouched this release; the tracker line should be corrected when next edited.

## Official CBSE Answer Key Verification Across All 8 CTET Cycles — 2026-10-11

Diffed all 8 CTET Paper-I cycles (`1,980` questions total) against official CBSE Final Answer Key PDFs:
- **`2016-i` (Feb 21, 2016, 180 q)**: Verified against Booklet Code I QP (`1559517a994bdfbff7c4107fa7875009.pdf`) and official answer key (`ctet-2016-paper-1-answer-key-pdf-feb-21-2016-1762326673.pdf`). Found and fixed **6 mismatches** (option-shift / import bugs): `mathematics-q040` (`a`→`b`), `environmental-studies-q064` (`b`→`a`), `lang1-hi-q107` (`a`→`b`), `lang2-en-q133` (`c`→`a`), `lang2-en-q139` (`b`→`c`), `lang2-en-q141` (`c`→`a`). Now **180/180**.
- **`2018-m` (Dec 09, 2018 Set I, 270 q)**: Already **210/210** verified on `MAIN`/`EN`/`HI` (`tools/v2/official_keys/ctet-2018-paper1-set-I.json`).
- **`2019-a` (Dec 08, 2019 Set A, 270 q)**: Verified against official Set A key (`ctet-2019-dec-paper-1-answer-key-1761917684.pdf` + `sanskrit-1761972468.pdf`) and Booklet Set A QP (`ATA-19-I`, `ctet-2019-paper-1-question-paper-and-answer-key-pdf-1761831997.pdf`). Found and fixed **1 mismatch**: `lang1-en-q098` (`b`→`a`, both Kangri Karchok and Langchen Khambab statements are true). Now **270/270**.
- **`2020-i` (Jan 31, 2021 Set I, 270 q)**: Verified against embedded official Set-I keys in `bank-v2/sources/ctet-p1-2020-2021-set-i.json`. **270/270 (0 mismatches)**.
- **`2021-dec-d` (Dec 31, 2021 CBT shift, 240 q)**: Identified exact shift date as **31 Dec 2021** and saved official key to `tools/v2/official_keys/ctet-2021-dec31-paper1.json` (`ctet-2021-paper-1-answer-key-dec-31-2021-1761656219.pdf`). Found and fixed **1 mismatch**: `environmental-studies-q075` (`a` Mars → `c` Mercury). Sanskrit `lang2-sa` (30 q) verified 30/30 (pedagogy q136–150 match official 15-question key sequence `[3,2,2,4,2,3,1,1,1,2,2,1,4,4,2]` 15/15). Now **240/240**.
- **`2023-e` (Aug 20, 2023, 270 q)**: Saved official Set D (`MAIN`/`EN`/`HI`) + Set A (`SA`) key to `tools/v2/official_keys/ctet-2023-aug-paper1-set-D.json` (`CTET_All_SETs_Paper_1_Answer_Key_874824de1a6c0792024dc41453f5342b.pdf` + `CTET_2023_Paper_1_Answer_Key_PDF_SET_A_Sanskrit_Aug_20_2023__93093a0c8a1a29db84b25dc90fb89a59.pdf`). Found and fixed **1 mismatch**: `lang2-hi-q122` (`a`→`b`). Now **270/270**.
- **`2024-i` (Jan 21, 2024 Set I, 270 q)**: Saved official Set I (`MAIN`/`EN`/`HI`/`SA`) key to `tools/v2/official_keys/ctet-2024-jan-paper1-set-I.json` (`2024021954.pdf` + `CTET_2023_Paper_1_Answer_Key_PDF_SET_I_Sanskrit_Jan_21_2024__1908e8b14ea3f9fe9356a3622d06e8c0.pdf`). Found and fixed **23 mismatches** introduced by the earlier LLM rekey (`mathematics-q050`, `lang1-en-q097/111/112/120`, `lang1-hi-q102/111/112/120`, `lang2-en-q130/139`, `lang2-hi-q131/139`, `lang1-sa-q094/095/096/101/111/112/120`, `lang2-sa-q121/124/139`), plus de-duplicated option `(c)` on `ctet-p1-2024-i-lang1-hi-q102` (`स्वा + अभिमान`). Now **270/270**.
- **`2026-e` (Feb 08, 2026 Set E / `FSC-26-I`, 210 q)**: Saved official Set E (`MAIN`/`EN`/`HI`) key to `tools/v2/official_keys/ctet-2026-feb-paper1-set-E.json` (`ctet-2026-paper-1-answer-key-pdf-feb-08-2026-1775563843.pdf`). Found and fixed **31 mismatches** (`cdp-q011/019`, `mathematics-q039/045/054`, `environmental-studies-q073/074/077/081`, `lang1-en-q096/109/110`, `lang1-hi-q102/104/109/110`, `lang2-en-q121/126/128/136/137/141/148/149`, `lang2-hi-q121/127/136/137/141/148/149`), and restored the 4 fraction options of `ctet-p1-2026-e-mathematics-q039` (`(a) 8/11, 5/9, 4/5, 3/7`, `(b) 4/5, 8/11, 5/9, 3/7`, `(c) 3/7, 4/5, 5/9, 8/11`, `(d) 3/7, 5/9, 8/11, 4/5`) verbatim from `FSC-26-I` (`ctet-2026-paper-1-question-paper-pdf-feb-08-2026-1775556035.pdf`). Now **210/210**.

**Pedagogical dissents logged (official CBSE key kept per standing rule)**:
- `ctet-p1-2026-e-lang2-en-q149` & `ctet-p1-2026-e-lang2-hi-q149`: Minimal pair drills standardly target pronunciation (`a`), but CBSE Set E final key awards `(4)`/`d` (`Vocabulary` / `शब्दसंपदा`) on both English and Hindi Q149.
- `ctet-p1-2024-i-lang2-en-q139`, `lang2-hi-q139`, `lang2-sa-q139`: "Language learning is an intensive process that begins at birth and continues throughout life" — CBSE Set I final key awards `(2)`/`b` ("I disagree with this statement", distinguishing *learning* from *acquisition*).
- `ctet-p1-2024-i-mathematics-q050`: CBSE Set I final key awards `(4)`/`d` (`Place value chart`) as least appropriate for developing conceptual understanding of relationships of ones, tens, hundreds (since a static chart shows positions without proportional grouping, though `Money` is non-proportional).


# MASTER PROMPT — Next Session (CTET/UTET Question Bank Forensic Cleanup)

> Yeh document next session ke liye handover hai. Padho, phir neeche "ROLE & RULES" se shuru karo.
> Repo: `sherawali/tet`, branch `arena/...` (session branch). Sab kuch `bank-v2/` + `tools/v2/` + `cdn/` me hai.

---

## 1. STATUS TRAFFIC-LIGHT (as of 2026-10-10, commits `61dd640` → `1600296` → `3f04c78`)

### 🟢 GREEN (done — do NOT redo)
- **Answer keys**: 541 broken keys re-keyed (`tools/v2/answer_rekey.json`, applied via `apply_answer_keys.py`). Key source: official PDFs + testbook/gkToday cross-check.
- **Structure integrity**: `python3 verify_all_questions.py` = **PASS 7/7 categories** (2880 questions, 109 stimuli, all paper-1).
- **No leaked question numbers** (`**Q149.**`, `Q.131.` etc.) in bank/DB — they were ONLY in stale CDN packs; 41 stale packs deleted. App screenshots showing `**Q###.**` = stale app cache → app must re-sync.
- **No leaked option content** in prompts (pass-2, 24 item classes).
- **hi/en parity fixes**, statement re-formatting (चिह्नित कीजिए style), figure/series/units questions repaired (2024-math-q112 series, 2021-math-q106 figure, utet-2020-q095 units, 2021-dec-d-math-q037 fractions restored).
- **Markdown tables → plain text** (app renders no markdown): 2019-a-evs-q071, 2021-dec-d-lang2-en-q128/q135, 2026-e-math-q041, 2019-a-math-q039/q041.
- **Poems restored**: 2024-hi-po-100 = "आज तिरंगा फहराता है" (सजीवन मयंक); 2026-hi-po-100 = "जीवन अस्थिर अनजाने ही…".
- **Passages restored (authentic)**: 2026-en-pr-91 Tarawati/Roopa (official PDF FSC-26-I), 2026-en-po-100 Kalahandi extract, 2026-en-pr-129 tribes/patriarch, 2026-hi-pr-129 हिंदी बनाम स्थानीय भाषाएँ.
- Pipeline works end-to-end: `verify_all_questions.py` → `tools/v2/build_app_db.py` → `tools/v2/build_cdn_packs.py` (manifest references only clean packs).

### 🟡 YELLOW (partially done — provisional, needs authentic replacement)
- **2026-en-pr-121** (boy/tea-seller, "He sped like a bullet towards the girl") — PROVISIONAL reconstruction from q121–128 constraints. NOT the original text.
- **2026-hi-pr-121** (लीडर/संघर्ष, "शरीर का राजा") — PROVISIONAL reconstruction from q121–128 constraints.
- **2026-hi-pr-91** — Hindi twin of Tarawati passage: abhi generic "अहंकार" placeholder hai. Asli Hindi translation likhni hai (ya official Hindi paper uthao).
- Answer-key provisional list (passage-restore ke baad re-verify karna hai):
  `2026-e lang2-en q121/125/126/127/128, lang2-hi q121/125/127/128, lang1-en q095/096;
   2018-m lang1-en q105/114/116/118/119/120, lang2-en q124/126/127/142/146`

### 🔴 RED (NOT done — placeholder/fake/missing content abhi bank me hai)

**A. Placeholder paragraphs (chhote generic "moral essay" — asli exam passages NAHI):**
| stimulus id | abhi kya pada hai | kya hona chahiye |
|---|---|---|
| `ctet-p1-2018-stimulus-en-pr-91` | "Bringing up children is a delicate art…" | 2018 Jul lang1-en q91-99 ka asli passage |
| `ctet-p1-2018-stimulus-en-pr-121` | "Scientific temper…" | 2018 Jul lang2-en q121-128 passage |
| `ctet-p1-2018-stimulus-en-pr-129` | "Physical exercise…" | 2018 Jul lang2-en q129-135 passage |
| `ctet-p1-2018-stimulus-hi-pr-97` | "मानव-इतिहास…" | 2018 Jul lang1-hi q97-105 passage (hi q097 se hai) |
| `ctet-p1-2018-stimulus-hi-pr-121` | "प्रकृति मनुष्य की सबसे बड़ी सहचरी…" | 2018 Jul lang2-hi q121-128 passage |
| `ctet-p1-2018-stimulus-hi-pr-129` | "समय का सदुपयोग…" | 2018 Jul lang2-hi q129-135 passage |
| `ctet-p1-2019-stimulus-en-pr-121` | "History demonstrates…" | 2019 Jul lang2-en q121-128 passage |
| `ctet-p1-2019-stimulus-en-pr-129` | "Curiosity is the engine…" | 2019 Jul lang2-en q129-135 passage |
| `ctet-p1-2023-stimulus-en-pr-97` | "The secret of happiness…" | 2023 lang1-en q97-105 passage |
| `ctet-p1-2023-stimulus-en-pr-121` | "Education is the manifestation…" | 2023 lang2-en q121-128 passage |
| `ctet-p1-2023-stimulus-en-pr-129` | "Nature has gifted humanity…" | 2023 lang2-en q129-135 passage |
| `ctet-p1-2023-stimulus-hi-pr-97` | "संसार के सभी प्राणी…" | 2023 lang1-hi q97-105 passage |
| `ctet-p1-2023-stimulus-hi-pr-121` | "सच्चा मित्र…" | 2023 lang2-hi q121-128 passage |
| `ctet-p1-2023-stimulus-hi-pr-129` | "समय का सदुपयोग…" | 2023 lang2-hi q129-135 passage |
| `ctet-p1-2026-stimulus-hi-pr-91` | "अहंकार…" | 2026 Tarawati ka Hindi sanskaran |

**B. Poems galat/missing:**
| id | abhi | asli |
|---|---|---|
| `ctet-p1-2018-stimulus-en-po-100` | Masefield "Sea Fever" | Blake "Little Black Boy" (q100-105 se confirm karo) |
| `ctet-p1-2019-stimulus-en-po-100` | Blake "The Tyger"-type | Tennyson "Charge of the Light Brigade" (q se confirm) |
| `ctet-p1-2019-stimulus-hi-po-100` | "वीर तुम बढ़े चलो" | verify karo — shayad sahi hai (2019 Jan official paper se match) |
| 2018-hi-po-100, 2023-en-po-100, 2023-hi-po-100 | **ID exist nahi karta** | stimuli file me add karo + questions ko link karo |

**C. Grammar/OCR prompts (22 questions):** "underlined word" prompts jisme underline/word hi gayab hai (2020-i, 2023-e, 2024-i lang sets + 2021-dec-d-lang2-en-q127, 2016-i-q149, 2019-a-q131 etc.). Target word identify karo (answer/options se + source paper se) aur prompt me naam likho — jaise `2026-e-lang2-en-q122` me `'towards'` kiya hai.

**D. Math remnants:**
- `ctet-p1-2026-e-mathematics-q039` options `['8','4','3','3']` bare — fractions restore karo (prepp PDF math section, chunk ~8–9).
- Cosmetic blanks: 2024-i-math-q045, 2026-e-math-q032/q058, utet-2025-math-q094 — normalize.
- OCR/grammar sweep: "कौन कार्यक्रम"→"कोई कार्यक्रम" type slips poori bank me ek baar scan karo (screenshot Q55 jaisi).

**E. Answer re-keying on restored passages:** upar YELLOW ke provisional answers re-verify + `tools/v2/answer_rekey.json` me daal ke `apply_answer_keys.py` chalao.

---

## 2. ROLE & RULES (original master prompt ka core)

Tum **Lead Data Architect** ho. Kaam: `bank-v2/` + `tools/v2/` (CTET/UTET 2016–2026) ko forensic-clean karke app ke liye **100% data integrity**.

**8 Golden Rules:**
1. Verified answer keys; kisi bhi 30-question section me ek hi option >60% nahi.
2. Prompt me leaked question numbers nahi (`Q.131.`, `**Q149.**`).
3. Prompt me leaked section labels nahi.
4. Column-bleed fix karo (option ka content prompt me nahi).
5. Options pure hon — koi instruction/meta text nahi.
6. Unicode math clean (no LaTeX mess, no crushed fractions like `384161418`).
7. Canonical AR format: `**अभिकथन (A):**` / `**कारण (R):**`.
8. hi + en parity — dono locales me content, meaning, options consistent.

**Data model:** `prompt`/option `content` = LIST of blocks `{kind, text:{hi,en}}` — **recurse, never concat**. NDJSON = `json.dumps(rec, ensure_ascii=False)` default separators. Option order shuffled ho sakti hai — **hamesha CONTENT se map karo, letters se nahi**.

**Pipeline (har fix ke baad):**
```
python3 verify_all_questions.py      # 7/7 PASS hona chahiye
python3 tools/v2/build_app_db.py
python3 tools/v2/build_cdn_packs.py
# manifest ke referenced packs hi cdn/packs/ me rakho; stale packs delete karo
```

**Pipeline tools:** `tools/v2/repair_cleanup_pass2.py`, `repair_cleanup_pass3.py` (idempotent repair scripts — pattern follow karo), `apply_answer_keys.py`, `answer_rekey.json`, `answer_rekey_notes.md` (har fix ka ledger), `text_sanitizer.py`.

**Recovery sources:**
- Official papers: `cdn-images.prepp.in/public/image/ctet-2026-paper-1-question-paper-pdf-*.pdf` (FSC-26-I/Code-E; fetch_page 30-page cap = 13 chunks; lang2 passages is PDF me nahi milte), cdnbsr.s3waas.gov.in answer-key PDFs, testbook.com/gkToday QA pages.
- Git history leaks: `git show 7a6aa96:<path>` (option-D leaks se full passages recover hue hain — tribes, हिंदी बनाम).
- Famous public-domain poems: anubhuti-hindi.org, gadyakosh, poetryfoundation.

**Pitfalls (do NOT repeat):**
- Repair script write-back pitfall: ROWS ko id-keyed rakho.
- Broad hi-truncation regexes Devanagari pe false-positive dete hain — narrow raho.
- `(?!\w)` ke baad Devanagari ke liye caution.
- Line-end whitespace `rstrip(" \t")` only.
- Kisi bhi **passage question-group ko mat todo** (passage ↔ uske questions hamesha saath).
- App markdown render nahi karta — tables/plain text hi use karo, `_`/`*`/`|` nahi.
- Keystore files (`upload-keystore.jks`, `key.properties`) — kabhi touch nahi.

**Work style (MEMORY.md):** Hinglish replies, ek time pe ek task, har reply ke end me "अब तू ये एक काम कर", raw.githubusercontent.com suggest mat karo, random selection kabhi nahi (p_score only).

---

## 3. SUGGESTED NEXT-SESSION ORDER (one task at a time)

1. **A-list**: 15 placeholder paragraphs replace karo — har set ke liye official question paper ya reliable archive se asli passage; na mile to git-leak method + question-constraint reconstruction (par PROVISIONAL mark karo `answer_rekey_notes.md` me).
2. **B-list**: 3 galat poems replace + 3 missing poem stimuli add/link.
3. **C-list**: 22 underlined-word prompts repair (target word naam se likho).
4. **D-list**: q039 fractions + OCR grammar sweep.
5. **E-list**: provisional answers re-verify, key json apply, pipeline rebuild, stale packs delete, commit.
6. Final: `verify_all_questions.py` 7/7 + manual spot-check 5 random questions per set against source paper — **tab tak green signal NAHI**.

## 4. DONE CRITERIA (green signal tabhi jab)
- [ ] Zero placeholder stimuli (140-380c generic moral essays = red flag).
- [ ] Zero provisional passages (dono 2026 reconstructions authentic text se replace).
- [ ] Zero "underlined word" prompts bina target word ke.
- [ ] Zero crushed fractions / bare fraction-numerators in math options.
- [ ] Sabhi poems authentic + right poem for the question set (title/content match).
- [ ] Sabhi answer keys source-verified (incl. provisional list).
- [ ] verify 7/7 PASS + app me sync karke `**Q###.**` junk absent + sample screenshots clean.

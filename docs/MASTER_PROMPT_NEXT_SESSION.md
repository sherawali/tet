# MASTER PROMPT — Next Session (CTET/UTET Question Bank)

> **Kaise use karna hai:** ye document padho, phir neeche **"ROLE & RULES"** se shuru karo.
> Repo `sherawali/tet`. Kaam **hamesha session branch pe**, aur kaam khatam hote hi **`main` pe merge** —
> kyunki app `@main` padhta hai, branch pe pada kaam device tak kabhi nahi pahunchta.
> Snapshot: **live release `v2026101101`** (2026-10-11, CI-built on `main`). Do hafte baad pehli successful CI run.

---

## 0. TL;DR — abhi kya state hai

| | |
|---|---|
| App ko jaane wala data | **2688 questions, 73 passages, 14 packs**, `bank_version 2026101101` — jsDelivr pe **live verified** |
| Bank me total | 2880 questions, 97 stimuli (**192 q / 24 groups held back**, `status:"draft"`) |
| Release gate | `verify_all_questions.py` → **PASS 7/7** |
| CI | `.github/workflows/build.yml` — `main` pe push hote hi gate + build + prune + tag + jsDelivr purge |
| Answers official-verified | **sirf 2018** (210/210 CBSE key se). Baaki 6 cycles **pending** — ye sabse bada bacha kaam hai |
| Sabse badi jeet is release ki | pack `id` ab content-hash se banta hai → koi bhi sudhaar **apne aap** device tak jaata hai, bina app update |

**Do hafte tak app kyun nahi hila** — data ki galti nahi thi, pipe toota tha. Chaar break the, chaaron band:
1. kaam `main` pe merge hi nahi hua tha;
2. CI `content/**` + `tools/build.py` dekh raha tha (CSV-era, dono cheezein repo me hain hi nahi);
3. pack `id` sirf index tha (`"0003"`) jabki app `packs.filter { it.id !in have }` karta hai → sudhaar hamesha "already downloaded" laga;
4. `BANK_VERSION` hardcoded `20261010` + **ek bhi git tag nahi** → app ka `remote.bank_version <= local` guard turant "UpToDate" bol deta aur `@v<stamp>/…` 404 karta.

---

## 1. ROLE & RULES

**Role:** Lead Data Architect. `bank-v2/` + `tools/v2/` ki forensic cleanup, 100% data integrity, ek mock-test app ke liye.

### 8 Golden Rules (har release me ye saaton gate categories + ye rules)
1. **Verified answer keys.** Kisi bhi 30-prashn section me koi ek option **60% se zyada** na ho (Rule-1 scan poore section pe chalao, sirf rekeyed questions pe nahi — `apply_answer_keys.py` ka distribution print gumrah karta hai).
2. **Leaked question numbers nahi** — `Q.131.`, `**Q149.**` prompt me nahi.
3. **Leaked section labels nahi** — "Language-II (English)" prompt me nahi.
4. **Column-bleed nahi** — option ka content prompt ke andar nahi.
5. **Pure options** — instruction/meta text option me nahi.
6. **Clean Unicode math** — LaTeX kachra nahi, crushed fractions nahi (`384161418` jaisa).
7. **Canonical AR format** — `**अभिकथन (A):**` / `**कारण (R):**` (⚠ dekho §10 open issues — app markdown render nahi karta).
8. **hi/en parity** — dono locale me same meaning, same option count.

### Hard constraints (user ne khud kaha — kabhi mat todna)
- **App Flutter me hai, user ke PC pe, is repo ke bahar.** App code ke peeche mat bhago. Bank-side fixes + progress report = tera kaam. Sync/propagation doosre AI agent ko delegated hai; uska contract `README.md` me hai.
- **`raw.githubusercontent.com` kabhi suggest mat karna** (per-IP rate limit; CGNAT users block ho jaate hain). Hamesha **jsDelivr**.
- **Random question selection kabhi nahi** — hamesha `p_score` weighted pick.
- **Passage↔question group kabhi mat todna** — stimulus ke saare prashn ek saath, aur `build_cdn_packs.py` assert karta hai ki ek passage **ek hi pack** me jaata hai.
- **`cdn/` me kabhi haath mat lagana** — wo generated hai.
- **Keystore files kabhi mat chhedna** (`upload-keystore.jks`, `key.properties`).
- App **markdown render nahi karta** → content me table, `_`, `*`, `|` nahi.
- **UTET passages user-confirmed sahi hain** — unhe dobara mat kholna jab tak user khud na kahe. **Abhi sirf CTET.**
- **"Fix all para and poem"** — sirf handover ki A-list pe mat ruko, bank ka har अनुच्छेद aur har कविता scope me hai.
- Ek reply me **ek hi kaam**; har reply ke end me **"अब तू ये एक काम कर"** + ek concrete ask. Jawab **Hinglish/Hindi**, chhote vakya, tables. Ek recommendation + reason, options ki list nahi.

### Pehle se reject ho chuke raaste (dobara mat sujhaana)
Firebase Firestore · private repo + embedded token · UTET 2023 Paper-2 data · weights 0.15/0.30/0.55 · random mock generation · UTET 2026 answer key se scoring · Telegram/Instagram business ideas.

---

## 2. RELEASE PIPELINE (har fix ke baad yahi order)

```bash
python3 verify_all_questions.py                    # gate — 7/7 PASS chahiye
python3 tools/v2/apply_answer_keys.py              # agar answer_rekey.json badla ho
python3 tools/v2/verify_against_official_key.py tools/v2/official_keys/<file>.json <cycle-prefix>
python3 tools/v2/build_app_db.py                   # bank-v2 → runtime/tet_mock_vault.db
python3 tools/v2/build_cdn_packs.py                # db → cdn/packs + cdn/manifest.json
python3 tools/v2/prune_stale_packs.py              # manifest me na bache packs hatao
python3 tools/v2/audit_passage_gaps.py             # tracker snapshot
git add -A && git commit && git push origin <session-branch>
# kaam khatam → PR → merge to main → CI apne aap release karega (stamp + tag + purge)
```

- **`BANK_VERSION`** = UTC `YYYYMMDDHH`, `tools/v2/build_config.py` me apne aap banta hai. CI use env se pin karta hai taaki manifest + SQLite meta + `v<stamp>` tag teeno same number rakhein. **Ab kabhi manually version bump nahi karna.**
- `build_cdn_packs.py` stamp **database se** leta hai (single source of truth) — agar env me `BANK_VERSION` pin hai aur DB se mismatch hua to build fail. Matlab: pehle DB banao, phir packs.
- `prune_stale_packs.py` ek guard bhi hai: agar manifest ka pack `id` apne content-hashed filename se match na kare to **error** — yahi wo regression tha jisne do hafte kha liye.
- CI sirf `main` pe release karta hai; PR pe sirf gate + build validation chalta hai (koi commit nahi).

---

## 3. APP SYNC CONTRACT (Flutter agent ke liye — `README.md` me poora hai)

App ka ek hi kaam baaki hai, aur wo zaroori hai:

```kotlin
db.deletePacksNotIn(remote.packs.map { it.id })   // ← ye step chhoota hua tha
```

Bina iske superseded pack (aur uske andar ka galat prashn) device pe hamesha ke liye tika rehta hai.
Baaki algorithm wahi: manifest `@main` → `bank_version` guard → `it.id !in have` filter → `@v<stamp>` se pack → sha256 verify → ek transaction → prune → `bank_version` store.

**Agar app me purana `bank_version` atka ho:** prefs se hatao / "डेटा रीसेट" — har pack ka id content se banta hai, isliye agla sync poora bank fresh utaar lega.

---

## 4. QUARANTINE — kya roka gaya, kaise wapas laana hai

`tools/v2/quarantine_bad_passages.py` FABRICATED group ko **poora ek unit** ki tarah `status:"draft"` karta hai (stimulus + uske saare prashn), phir re-scan karke saabit karta hai ki koi published prashn draft stimulus ke neeche nahi bacha. `build_app_db.py` draft prashn, unke appearances, aur wo passages skip karta hai jinke saare readers draft hain.

**Roka gaya: 24 groups / 192 prashn — sab Language sections me.**

| cycle | lang | q | nakli text jo pada tha | asli me hona chahiye |
|---|---|---|---|---|
| 2019 | en | 121–128 | "History demonstrates that cultural exchange…" | freedom / 'endeavours' / established religion |
| 2019 | en | 129–135 | "Curiosity is the engine of scientific discovery…" | Uttarakhand Himalayas, perennial streams, 'bounty' |
| 2019 | hi | 91–99 | "आधुनिक शिक्षा प्रणाली में विज्ञान…" | ❓ abhi tak pehchaana nahi gaya |
| 2019 | hi | 129–135 | "भाषा अभिव्यक्ति का सर्वोत्तम माध्यम…" | गाँव को प्रयोगशाला, 'फर्स्ट हैंड समझ' |
| 2019 | sa | 91–99 | मरुभूमि का प्यासा पथिक | नर्मदा / अमरकण्टक / डिण्डोरी |
| 2019 | sa | 121–128 | गुरु-शिष्य निबंध | दण्डचतुष्टय (लकड़ियों का गट्ठर) |
| 2019 | sa | 129–135 | पर्यावरण रक्षण निबंध | चाणक्य और कम्बल |
| 2021 | hi | 121–128 | "वैज्ञानिक अनुसंधानों ने जीवन सुगम…" | नदियों का पहाड़ी सफर, 'सरसब्ज', 'उल्लास' |
| 2021 | sa | 121–128 | निर्धन व्यक्ति / पुत्र का प्रवेश | नागार्जुन और दो युवक |
| 2021 | sa | 129–135 | "विचित्रः खलु संसारः…" | रानाडे |
| 2023 | en | 97–105 | "The secret of happiness…" | **Garud, 69, solo in Mizoram** (ex-athlete) |
| 2023 | hi | 97–105 | "संसार के सभी प्राणी निर्भर हैं…" | धन्यवाद / 'मन की कोठरी' |
| 2023 | sa | 121–128 | परोपकाराय फलन्ति वृक्षाः निबंध | सिद्धार्थ और देवदत्त |
| 2023 | sa | 129–135 | सत्सङ्गति निबंध | मृगेन्द्र और सिंह |
| 2024 | en | 91–99 | "Human ingenuity has continually…" | **Morley Callaghan — "All the Years of Her Life"** |
| 2024 | en | 121–128 | "Reading opens doors…" | **Wizard of Oz** (Scarecrow/Dorothy) |
| 2024 | en | 129–135 | "Cooperation in communities…" | birder / bird calls / Delhi, "wild exultant laugh" |
| 2024 | hi | 91–99 | "आंतरिक और बाह्य स्वच्छता…" | ❓ abhi tak pehchaana nahi gaya |
| 2024 | hi | 121–128 | "श्रम ही जीवन की साधना है…" | गंगा / अल-नीनो / ग्लेशियर / 2050 जल-संकट |
| 2024 | hi | 129–135 | "वाणी में मधुरता अमृत…" | पाप-पुण्य, जंजीर की तुलना |
| 2024 | sa | 91–99 | चम्पकवती वन का मृग-कौआ | योग और मोक्ष |
| 2024 | sa | 121–128 | भारतवर्ष वर्णन (हिमालय) | सामवेद / योगदर्शन |
| 2024 | sa | 129–135 | "वृक्षाः अस्माकं मित्राणि…" | साङ्ख्ययोग और हठयोग |
| 2026 | hi | 91–99 | "अहंकार में इंसान के चरित्र…" | सृष्टि निर्माण / सद्भाव / मान-सम्मान |

Section-wise asar: cdp/evs/math **0 cut**; english 630→**582**; hindi 630→**564**; sanskrit 360→**282**. Har section me 9–19 poore 30-question mocks bante hain.

**Wapas laane ka tareeka (ye ab bahut sasta hai):**
1. `tools/v2/repair_passages_pass6.py` ke `RESTORATIONS` me entry daalo — `dict(file, loc, text, src, must[], minQ?, instr?)`. Tool markdown-junk absence, har `must` needle ki maujoodgi, aur kam-az-kam ek linked prashn assert karta hai, tabhi likhta hai. **Naya pass7/pass8 file mat banana.**
2. `python3 tools/v2/quarantine_bad_passages.py --restore <stimulus-id>` → group `published`.
3. `audit_passage_gaps.py` ke `STATUS` me wahi id **DONE** karo (same commit me — drift guard warning deta hai).
4. Pipeline chalao (§2) → naya pack id → app khud le lega.

**Jaankar nahi roka gaya:** 11 TRUNCATED (87 q) — passage asli hai bas adhura; 13 UNVERIFIED poems (73 q) — poems asli lagte hain; 2 PROVISIONAL (16 q) — plausible reconstructions. Ye teeno shipped hain.

---

## 5. TRAFFIC LIGHT

### 🟢 GREEN (ho gaya — dobara mat karna)
- **Pipeline / sync**: content-hashed pack ids, self-bumping stamp, live CI, prune tool, README contract. (`cd53673`)
- **2018 cycle answers**: CBSE official key se **210/210 match**, zero mismatch, zero drift between `question.answer.optionId` aur `appearance.officialOptionId`. Rule-1 scan: 9 sections, sabse kharab lang2-sa 43%, **0 violation**.
- **2018 English passages + Blake poem** ("The Little Black Boy"), Castles, maxim, Kevlar — authentic restore (`de891a7`).
- **2018 Hindi गीत-कविता** `ctet-p1-2018-stimulus-hi-pr-97` — 1724 char, 2 paragraph, 9 q (`d0bf171`).
- **Pass 5**: 12 fabricated stimuli delete / 93 q unlink (`f1fc473`), tracker me `NO_PASSAGE_REMOVED` me darj.
- **Structure integrity**: gate PASS 7/7. Leaked Q-numbers, option leaks, hi/en parity, markdown→plain text — sab clean.
- **Poems**: 2024-hi-po-100 "आज तिरंगा फहराता है" (सजीवन मयंक); 2026-hi-po-100; 2026-en-po-100 Kalahandi.
- **Passages**: 2026-en-pr-91 Tarawati/Roopa, 2026-en-pr-129 tribes/patriarch, 2026-hi-pr-129.
- **UTET**: 24 groups / 111 q — user-confirmed authentic (uske apne 2024/2025 paper OCR + 29 Sep 2026 wala UTET paper). **Band, dobara mat kholna.**

### 🔴 RETRACTED — ye GREEN nahi hai
- **`answer_rekey.json` (542 entries) bharosemand NAHI hai.** 2018 official key se diff karne pe 8 mismatch mile, jinme se **7 khud rekey file ne bigaade the** — aur kuch me usne *sahi* original ko override kiya. Sabse saaf saboot: `lang2-en q123` import me `c` tha → rekey ne `b` kiya → official grid kehta hai `3` = `c`.
  **Nateeja:** har rekey entry ko tab tak unverified maano jab tak official key grid se diff na ho jaaye. Purane handover ka "answer-key rekey of 541 = GREEN" **wapas liya jaata hai**.
- **`docs/CTET_PAPER1_AUDIT.md` ke kuch daawe galat hain** (evs q064 = NCF-1975, NCF-2000 nahi).
- **Purane handover ki B-list aadhi galat thi**: `2018-hi-po-100`, `2023-en-po-100`, `2023-hi-po-100` asli gaps nahi. Real holes = 2016 ke wo 2 groups (jo ab pata chala: wo **standalone prashn hain, passage chahiye hi nahi** — §9).
- **"`2026-hi-pr-91` = Tarawati ka Hindi twin" — galat.** CTET Lang-I Hindi apna alag section hai, Lang-I English ka translation nahi.

### 🟡 YELLOW / 🔴 RED — bacha hua kaam, priority order me
1. **🔴 Sabse bada: baaki 6 cycles ki official CBSE answer key se diff.** 2019, 2021-dec, 2023, 2024, 2026, 2016, 2020-i. Method §6 me. Umeed: aur bhi rekey galtiyan niklengi.
2. **🔴 24 quarantined groups restore** — 22 ka asli topic pehchaana hua hai (§4 table), sirf 2 anjaan (2019-hi q91–99, 2024-hi q91–99).
3. **🟠 11 TRUNCATED groups ke chhoote paragraph bharo** — 2016 `en-pr-121` water/dehydration, `en-pr-143` Raja Ram Mohan Roy; 2019 `en-pr-91` Kangri Karchok (paras 3–4), `hi-pr-121` NCF पाठ्यक्रम; 2021-dec `en-pr-91` Delhi tonga, `en-pr-121` Himalayan ice, `en-pr-129` Ruskin Bond trees, `hi-pr-91` शहर/खण्डहर, `hi-pr-129` Krishnamurti; 2024 `en-po-100` Wordsworth daffodils (4 me se 1 stanza).
4. **🟠 13 UNVERIFIED poems (73 q) verify** — 2016 `hi-po-91`; 2018 `hi-po-91`(328c)/`sa-po-100`; 2019 `en-po-100` (abhi Blake "Night" pada hai, purana handover Tennyson kehta tha — q100–105 se jaancho), `hi-po-100`/`sa-po-100`; 2021-dec `en-po-100` (Lucy Larcom "The Tree That Never Had To Fight")/`hi-po-100`; 2023 `en-po-91` (Herrick "Gather ye rosebuds")/`hi-po-91`/`sa-po-100`; 2024 `sa-po-100`; 2026 `hi-po-100`.
5. **🟡 2 PROVISIONAL groups** — 2026 `en-pr-121` tea-seller (820c), 2026 `hi-pr-121` लीडर/संघर्ष (477c). Reconstructions hain, original nahi.
6. **🟡 MISLINKED prashn real groups ke andar** — 2016 `hi-pr-112`: q119 (अकबर का जन्म) किसी aur गद्यांश ka hai jo missing hai, q120 (मुहावरा) standalone; 2019 `hi-pr-121` q125–127 standalone; 2018 `hi-pr-97` q103–105 standalone.
7. **🟡 `2026-e-mathematics-q039`** — options import pe toote the (fractions gayab, sirf numerators "8/4/3/3" bache); answer `a` placeholder. prepp ke FSC-26-I paper PDF se options lautaao.
8. **🟡 Label defects (jaankar chhode, risky/cosmetic)** — 2018 bank me `canonicalSet:"M"` / `setCode:"M"` / `paperFormId ctet-p1-2018-set-m`, jabki official booklet **MVD18–I / Set I** hai.

---

## 6. OFFICIAL KEY METHOD — ab yahi primary tareeka hai

Reproduction sites ke answers par bharosa mat karo. **CBSE ki asli answer key** chhoti, saaf aur fully fetchable hoti hai (paper PDF ke ulta).

1. `prepp.in/ctet-exam/question-paper-<year>` kholo → usme official PDFs ke direct `cdn-images.prepp.in` URLs milte hain (paper + har language supplement + **answer key**).
2. Key PDF ko `fetch_page` se padho — 2018 wali me teen grids thi: `MAIN` (q1–90), `01-ENGLISH` (q91–150), `02-HINDI` (q91–150).
3. Grid ko verbatim `tools/v2/official_keys/<cycle>-paper1-set-<X>.json` me rakho. Values = printed option number 1–4; **`9` = saare options accepted, sabko 1 mark**.
4. `python3 tools/v2/verify_against_official_key.py <keyfile> <cycle-prefix>` — ye `cdp|mathematics|environmental-studies`→MAIN, `lang*-en`→01-ENGLISH, `lang*-hi`→02-HINDI map karta hai, `lang*-sa` skip karta hai (Sanskrit main key me hota hi nahi — uske liye alag Sanskrit supplement key chahiye). Output: matched/mismatched/skipped + har mismatch pe bank ke option texts + `optionId` ↔ `officialOptionId` drift report.
5. Mismatch mile to **official key jeetegi** (user directive: "CTET ke paper se match karo"). Dissent ledger me darj karo taaki reversible rahe.
6. `answer_rekey.json` me letter daalo → `apply_answer_keys.py` → **re-diff, 0 mismatch chahiye**.

**2018 ke 8 corrections jo official key se lage:** evs q064→**d**, evs q090→**a**, lang1-en q105→**d**, q114→**b**, q115→**d**, lang2-en q123→**c**, q144→**d**, q145→**b**.
Teen jagah official key pedagogy se takraati hai (dissent ledger me hai): q064 NCF-**1975**, q090 **myth** (stereotype nahi), q115 **advanced writing** (free writing nahi). 2018 q103 ka jhagda bhi suljha: official HINDI grid `103 = 2` = bank ka **b सकर्मक**; testbook ka अकर्मक galat tha.

---

## 7. DATA MODEL — gotchas jo baar-baar kaat ti hain

- `prompt` aur option `content` = **LIST of blocks** `{kind, text:{hi,en}}`. **Recurse karo, concat kabhi nahi.** (Warna `kind` ki value `"markdown"` text me ghus jaati hai — ye galti maine khud ki hai.)
- NDJSON likhte waqt `json.dumps(rec, ensure_ascii=False)`, default separators.
- **Option order printed booklet se shuffled hai** — hamesha **CONTENT se map karo, letter se kabhi nahi.**
- Locale-blind length scan mat karo: Sanskrit stimuli `sa` rakhte hain, `en`/`hi` nahi.
- Repair scripts me **id-keyed write-back** karo, index-keyed nahi.
- Broad hi-truncation regexes Devanagari pe false-positive dete hain; `(?!\w)` Devanagari se pehle sambhal ke; line-end cleanup sirf `rstrip(" \t")`.
- Passage-range filter stimulus id me embedded first-question number se banao — naive q-number ranges **false orphan** dete hain.
- **Passage-marker regex sirf heuristic hai, proof nahi** — genuine poem groups pe 0 hit deta hai. Unlink se pehle stems padho; poem ko hamesha uski कविता chahiye.
- Memory se answer letters mat likho — **pehle dobara dump karo**, phir `answer_rekey.json` chhedo.
- Local branch turn ke beech **fork** ho sakti hai. Recovery: `git fetch origin <branch>` → `git diff --stat HEAD origin/<branch>` → `git reset --soft origin/<branch>` → recommit → push. **Force-push kabhi nahi.**

### Cycle identities (`bank-v2/sources/*.json`)
| cycle | date | set | stimulus id pattern |
|---|---|---|---|
| 2016-i | Feb 2016 | — | `ctet-p1-2016-stimulus-<lang>-<pr\|po>-<firstQNo>` |
| 2018-m | 2018-12-09 | bank: **M** / official: **I (MVD18-I)** | `ctet-p1-2018-…` |
| 2019-a | 2019-12-08 | A | `ctet-p1-2019-…` |
| 2020-i | 2021-01-31 | I | `ctet-p1-2020-i-language-N-<lang>-qNNN-prose\|poem` |
| 2021-dec | 2021-12-16 | D (**Lang-I Sanskrit hai hi nahi**) | `ctet-p1-2021-dec-…` |
| 2023-e | 2023-08-20 | E | `ctet-p1-2023-…` |
| 2024-i | 2024-01-21 | I | `ctet-p1-2024-…` |
| 2026-e | 2026-02-08 | FSC-26-I / Code-E | `ctet-p1-2026-…` |

---

## 8. SOURCE INTEL — kya chalta hai, kya nahi

**Chalta hai:**
- `prepp.in/ctet-exam/question-paper-<year>` → official CBSE PDFs ke direct `cdn-images.prepp.in` links (papers + supplements + **answer keys**). **Sabse valuable.**
- Official **answer-key** PDFs — chhoti, saaf, poori padhi jaati hain.
- `career.aglasem.com/tet/ctet/previous-papers` → 177 papers; 2018 Dec Paper-1 viewer `docs.aglasem.com/view/a8a86b64-3607-11eb-89d9-02f21f5619c4`; 2011–2019 UUIDs inline; 2020–2026 `…/previous-papers/<year>`.
- `testbook.com/question-answer/ques--<id>` → Hindi गद्यांश **poore** milte hain (inka condensed English "Comprehension" block bekaar hai, wo mat use karna).
- `theexampillar.com/ctet-exam-2018-language-i-hindi-answerkey/2/` aur siblings (english-language-i/ii, cdp, mathematics, evs, hindi-language-ii) — typo repair ke liye accha.
- `gkscientist.com/ctet-december-2018-question-paper-with-answers/` — inline answers, cross-check ke liye.
- `ereadingworksheets.com/…/castles/` (+ `/castles/text.php` clean mirror), `poemanalysis.com` — English texts/poems.
- Aur mirrors: `adda247.com/teaching-jobs-exam/ctet-previous-year-question-paper-pdfs/`, `collegedekho.com/exam/ctet/previous-year-question-papers`, `cbseguidanceweb.com`, `sarkariteachers.com`.

**Nahi chalta (dobara koshish mat karna):**
- **`ctet.nic.in` page fetch fail hota hai** ("Failed to fetch page"). prepp/aglasem mirror use karo.
- **Official paper PDF se Hindi passage nahi mil sakta.** Do deewarein: (a) Devanagari text layer **legacy Kruti-Dev font** me hai → `narjm nwpÒVH$m` = परीक्षा पुस्तिका, bina decoder likhe bekaar (sirf kuch EVS pages pe saaf Unicode OCR layer hai); (b) booklet ~42 page aur **`fetch_page` 30 page pe rukta hai**, jo Part III (EVS q76) ke andar khatam hota hai — **Part IV aur V (dono language sections) pahunch se bahar**. English sections saaf hain par pahunch se bahar.
- `poetryfoundation.org/poems/43665/the-little-black-boy` → 404. `poemanalysis.com` use karo.
- **Git-leak recovery dead end hai** fabricated placeholders ke liye — wo pehle import pe गढ़े gaye, kisi commit me authentic the hi nahi.
- **Purani turn ki `routify-file-proxy-sg.oss-ap-southeast-1.aliyuncs.com` URL dobara fetch mat karna** → `SignatureDoesNotMatch` (do baar lag chuka). Original site URL ko wanted `chunkIndex` ke saath dobara maaro.
- **Bash ka outbound sirf github/npm/pypi tak** — saari web recovery `web_search`/`fetch_page` se hi hogi.

---

## 9. FILE MAP

```
bank-v2/exams/{ctet,utet}/paper-{1,2}/<section>[/<lang>]/
    questions.ndjson    # status, prompt[], options[], answer.optionId, stimulusId, review
    stimuli.ndjson      # status, content[].text{hi|en|sa}, instructions, minimumQuestions
    section.json
bank-v2/paper-forms/{ctet,utet}/paper-N/appearances.ndjson   # questionNumber + officialOptionId YAHAN hai (per-section nahi!)
bank-v2/sources/*.json     # examDate, canonicalSet, counts, verificationStatus
bank-v2/audits/*.ndjson
runtime/tet_mock_vault.db  # gitignored — build ka beech ka kadam, app ise nahi padhta
cdn/packs/*.json + cdn/manifest.json + cdn/flash_messages.json   # generated, JO yahi app tak jaata hai
tools/v2/
    build_config.py            # BANK_VERSION (auto UTC YYYYMMDDHH) + version_stamp()
    build_app_db.py            # bank-v2 → SQLite; draft questions/appearances/passages skip
    build_cdn_packs.py         # SQLite → packs; pack id = <index>-<sha256[:12]>
    prune_stale_packs.py       # stale packs hatao + id↔filename guard
    quarantine_bad_passages.py # FABRICATED groups → draft; --restore <id>; --restore-all; --dry-run
    audit_passage_gaps.py      # TRACKER: STATUS{}, NO_PASSAGE_REMOVED{}, MISSING_GROUPS[], UTET_STATUS
                               #          + HELD BACK line + "still published" warning
    repair_passages_pass6.py   # RESTORATIONS registry — nayi restorations YAHAN add karo
    repair_unlink_pass5.py, repair_passages_pass4.py, repair_cleanup_pass{2,3}.py
    verify_against_official_key.py  # official key grid ↔ bank diff
    apply_answer_keys.py + answer_rekey.json (542) + answer_rekey_notes.md (LEDGER)
    official_keys/ctet-2018-paper1-set-I.json
    text_sanitizer.py, validate_structure.py, sanitize_bank.py, repair_bank_v2.py
    import_all_ctet.py (89 KB — hardcoded stimulus texts inline ~line 639–753; saare fabricated placeholders YAHAN se aaye)
    import_ctet_2020_paper1.py, import_utet_paper1.py
verify_all_questions.py        # repo root — 7-category release gate
docs/MEMORY.md, HANDOVER.md, BANK_V2_ARCHITECTURE.md, CTET_PAPER1_AUDIT.md (⚠ kuch daawe galat),
     UTET_LANGUAGE_AUDIT_2026-10-03.md, MASTER_PROMPT_NEXT_SESSION.md (ye file)
README.md                      # app sync contract — Flutter agent ye padhta hai
```

**Ledger `tools/v2/answer_rekey_notes.md` hi single source of truth hai** provenance/confidence ke liye — har pass ka section usme append karo, commit message me nahi chhodo.

---

## 10. KHULI SAMASYAEIN (jaankar chhodi gayi)

1. **AR-format ka takraav:** Golden Rule 7 `**अभिकथन (A):**` maangta hai, gate ise flag nahi karta, aur app markdown render nahi karta. Jaisa hai waisa chhoda — faisla user ka.
2. **2016 ke 2 "MISSING" groups asli me missing nahi.** `ctet-p1-2016-i-lang1-hi-q097…q105` (9 q) aur `ctet-p1-2016-i-lang2-en-q128…q135` (8 q) — padh ke dekh liya, **saare 17 standalone pedagogy stems hain** ("भाषा सीखने का उद्देश्य है–", "Stephen Krashen's theory … does not consist of"). Inhe passage chahiye hi nahi. Tracker me `MISSING_GROUPS` se hata ke `NO_PASSAGE_REMOVED` semantics me daalo (published, no stimulus). Is release me chheda nahi.
3. **`apply_answer_keys.py` ka distribution print gumrah karta hai** — sirf rekeyed questions aggregate karta hai. Rule-1 hamesha poore 30-question section pe scan karo.
4. **17 prashn bina stimulus ke passage maangte lagte hain** (tight regex scan) — inme se asli dangling sirf ~4–6 hain (`2023-e-lang2-hi-q143/q144`, `2023-e-lang1-sa-q110`, `2016-i-lang2-sa-q139`); baaki false positive ("अनुच्छेद (धारा)" = Act ki section). Ek baar haath se padh ke decide karo.

---

## 11. TRACKER SNAPSHOT (release 2026101100)

```
DONE          47 groups   281 questions  (47.5% of live groups)
NO-PASSAGE    12 groups    93 questions  (closed — stimuli deleted)
TRUNCATED     11 groups    87 questions  (11.1%)   ← shipped
FABRICATED    24 groups   192 questions  (24.2%)   ← HELD BACK (draft)
PROVISIONAL    2 groups    16 questions  ( 2.0%)   ← shipped
MISSING        2 groups    17 questions  ( 2.0%)   ← shipped (asli me standalone, §10.2)
UNVERIFIED    13 groups    73 questions  (13.1%)   ← shipped
LIVE TOTAL    99 groups   666 questions  (+12 closed / 93 q)
HELD BACK     24 groups   192 questions
```
Bank: 2880 q / 97 stimuli / 2880 appearances · Gate **PASS 7/7** · App DB **2688 q / 73 passages / 3300 KB** · **14 packs**.

**Live release:** `main` = `156f290 bank v2026101101`, tag `v2026101101` usi commit pe. CI pehli baar **hara** hua (us se pehle ki 5 runs 10–14 second me fail ho rahi thi — wahi toota hua `tools/build.py`). jsDelivr se manifest khinch ke confirm kiya: `bank_version 2026101101`, `total 2688`, 14 packs, saare id content-hashed.

> Local build ne stamp `2026101100` banaya tha; CI ne apne run ke ghante ka `2026101101` pin kiya. Ye expected hai — stamp CI ka hota hai, local sirf jaanch ke liye.

---

## 12. AGLE SESSION KA PEHLA KAAM

**Baaki 6 cycles ki official CBSE answer key nikalo aur diff karo** (§6). Reason: 2018 akeli cycle me 8 galat keys nikli, 7 khud hamari rekey file ne bigaadi thi — matlab "verified" kehlaane wale answers me abhi bhi galatiyan hain, aur ye prashn ki quality se zyada zaroori hai (galat answer = galat score = app pe bharosa khatam). Har cycle ke baad pipeline chalao, aur **kaam khatam hote hi `main` pe merge karna mat bhoolna** — do hafte isi me gaye the.

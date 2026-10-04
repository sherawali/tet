# CTET Paper-1 PYQ Collection (2020–2026) — `ctetnew/`

**CTET Paper 1 (कक्षा 1–5 शिक्षक पात्रता परीक्षा)** के सभी आयोजित परीक्षाओं के प्रश्न —
**CDP + Maths + EVS हिन्दी और English दोनों भाषाओं में**, **उत्तर CBSE की अधिकारिक final answer key** से।

## 2020 से 2026 तक CTET कब-कब हुआ?

| # | परीक्षा | आयोजन तिथि | Folder | Booklet/Set | प्रश्न | अधिकारिक उत्तर |
|---|---|---|---|---|---|---|
| 1 | CTET Jan 2021 (July-2020 चक्र) | 31-01-2021 | `2021-01/` | Set K | 150 (90 core + 60 भाषा) | ✅ 150/150 |
| 2 | CTET Dec 2021 | 31-12-2021 (बहु-shift चक्र) | `2021-12/` | 31-Dec पुस्तिका | 150 | ✅ 149 + 1 निरस्त |
| 3 | CTET Dec 2022 | 13-01-2023 (बहु-shift चक्र) | `2022-12/` | 13-Jan Paper-1 | 120* | ✅ |
| 4 | CTET Aug 2023 | 20-08-2023 | `2023-08/` | Set D | 150 | ✅ |
| 5 | CTET Jan 2024 | 21-01-2024 | `2024-01/` | (auto) | 150 | ✅ |
| 6 | CTET July 2024 | 07-07-2024 | `2024-07/` | Code A | 150 | ✅ |
| 7 | CTET Dec 2024 | 14-12-2024 | `2024-12/` | Code H | 150 | ✅ |
| 8 | CTET Feb 2026 | 07 & 08-02-2026 | `2026-02/` | 7-Feb Set + 8-Feb Set | 150×2 | ✅ |

**नोट:**
- **2020 और 2025 में कोई CTET आयोजित नहीं हुआ** (जुलाई-2020 चक्र कोविड से टलकर 31-जन-2021 को हुआ; 2025 के जुलाई/दिसंबर सत्र रद्द होकर फ़र-2026 बने)।
- CTET Dec-2026 (12–13 दिसंबर 2026) अभी होना बाकी है — उसका पेपर उपलब्ध नहीं है।
- Dec-2021 और Dec-2022 चक्र कई तारीख़ों/shifts में चले — यहाँ एक-एक पूर्ण पुस्तिका (repo मौजूद वाली) दी गई है।
- \* `2022-12/` में स्रोत-extraction में Language-II English खंड नहीं था (Hindi Lang-I है)।

## हर folder में क्या है

- **`paper1.json`** — structured: प्रत्येक प्रश्न `q_hi`, `q_en`, `options_hi`, `options_en`, `ans`
  (अधिकारिक key से), `explanation` (जहाँ उपलब्ध), flags
- **`paper1.md`** — मानव-पठनीय द्विभाषी पेपर
- `_sources/keys/` — CBSE अधिकारिक final answer keys का text (ctet.nic.in से)
- `_sources/keys_parsed.json` — parsed keys (सभी sets, सभी तिथियाँ)
- `_sources/manifest.json` — क्या-क्या, कहाँ से लिया (traceability)
- **`all_questions.csv`** — repo के `content/q_*.csv` schema में सब प्रश्न (app merge के लिए)

## उत्तरों की प्रामाणिकता

- सभी उत्तर **ctet.nic.in की FINAL answer key** (चुनौती-पश्चात्) से हैं — किसी कोचिंग-बुक की key से नहीं।
- जहाँ स्रोत-पुस्तक का उत्तर अधिकारिक key से भिन्न था, वहाँ **अधिकारिक ही रखा गया** और flag किया गया
  (जैसे Jan-2021 Q71, Dec-2022 Q80/Q85 — `_build_report.json` देखें)।
- कुछ प्रश्नों में अधिकारिक key में **एक से अधिक विकल्प मान्य** हैं (challenge के बाद) — जैसे Aug-2023 Q48
  (आर्यभट्ट व भास्कर-1 दोनों)। ऐसे प्रश्नों में `ans_note` में स्पष्ट लिखा है और `ans_accepted` में सूची है।
- जिन प्रश्नों के सभी विकल्प मान्य थे / प्रश्न निरस्त हुआ, वहाँ `ans: null` + नोट है।

## Sources

- प्रश्न: `ctet-questions/*.md` (repo के PDF extractions) — **हर पेपर की पहचान official key से
  answer-pattern matching द्वारा सत्यापित** (match-rate 96–100%)
- उत्तर: <https://ctet.nic.in/previous-year-final-answer-key/> (CBSE official)
- Feb-2026 प्रश्न: ctet.nic.in के official paper zips / परीक्षा-केंद्र से एकत्र पुस्तिकाओं के scans
  (देखें `_sources/manifest.json`)

## Audit summary (पुराने extraction की समस्याएँ)

पूरी रिपोर्ट: [`docs/CTET_AUDIT_2026-10-04.md`](../docs/CTET_AUDIT_2026-10-04.md)

- `tools/md2csv_ctet.py` का section-detection टूटा है (restart-नंबरिंग वाले सभी papers 'cdp' बन जाते हैं)
- committed `content/q_ctet.csv` पुराने बेहतर script का है — वर्तमान script से दोबारा बनाने पर quality गिरेगी
- July-2024 (89/90 उत्तर गायब), Dec-2024 (90/90 गायब) — अब अधिकारिक key से भर दिए गए हैं
- लगभग 395 cross-paper duplicate stems (मुख्यतः `CTET 2018.md` ≡ `CTET Paper 1 Dec 2018.md`)

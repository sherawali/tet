# UTET भाषा ऑडिट — CDP, गणित और EVS

**ऑडिट तारीख:** 3 अक्टूबर 2026
**स्कोप:** `exams` में `utet1` वाले CDP, गणित और EVS के सभी प्रश्न — `q_cdp.csv`, `q_math.csv`, `q_evs.csv`, और आधिकारिक `q_utet2020/2021/2022/2024/2025/2026.csv`।
**कुल जाँचे गए प्रश्न:** 720 (हर section में 240)

## जाँच का तरीका

1. **Hindi mode:** `q_hi`, `a_hi`, `b_hi`, `c_hi`, `d_hi` मौजूद हैं या नहीं।
2. **English mode:** `q_en`, `a_en`, `b_en`, `c_en`, `d_en` मौजूद हैं या नहीं।
3. English fields में Devanagari/Hindi text तो नहीं है।
4. Hindi-only formula, variable, Roman numeral और chemical formula (जैसे `x = 9`, `HCl`, `SDG 6`) को error नहीं माना गया।

> यह field-level display audit है: इससे blank field और wrong-language field पकड़े जाते हैं। हर translation की वैचारिक/meaning-level समानता का अलग manual review अभी बाकी है।

## Hindi mode — सुरक्षित

- **720/720** Hindi questions मौजूद हैं।
- **720/720** में चारों Hindi options मौजूद हैं।
- कोई Hindi stem अथवा option blank नहीं है।
- जो cells Devanagari में नहीं हैं वे valid formula/notation/roman-number/chemical-formula वाले cases हैं; कोई पूरा English sentence Hindi option में नहीं मिला।

**नतीजा:** Hindi mode में blank/wrong-column issue नहीं मिला।

## English mode — direct Hindi leakage ठीक कर दिया गया है

पहले 13 प्रश्नों के English fields में Hindi text था। उन सभी rows के question/options को English में सुधार दिया गया है; answer index नहीं बदला गया है।

| File / CSV line | Source | Section |
|---|---|---|
| `q_utet2020.csv:10` | UTET 2020 Q9 | CDP |
| `q_utet2020.csv:11` | UTET 2020 Q10 | CDP |
| `q_utet2020.csv:121` | UTET 2020 Q120 | Maths |
| `q_utet2020.csv:129` | UTET 2020 Q128 | EVS |
| `q_utet2025.csv:99` | UTET 2025 Q98 | Maths |
| `q_utet2025.csv:128` | UTET 2025 Q127 | EVS |
| `q_utet2025.csv:148` | UTET 2025 Q147 | EVS |
| `q_utet2026.csv:6` | UTET 2026 Q5 | CDP |
| `q_utet2026.csv:21` | UTET 2026 Q20 | CDP |
| `q_utet2026.csv:25` | UTET 2026 Q24 | CDP |
| `q_utet2026.csv:26` | UTET 2026 Q25 | CDP |
| `q_utet2026.csv:111` | UTET 2026 Q110 | Maths |
| `q_utet2026.csv:126` | UTET 2026 Q125 | EVS |

अब English fields में **कोई Devanagari/Hindi leak नहीं** है।

## Current English-mode status

| Section | कुल | सारे English fields मौजूद | कोई field blank | Hindi/Devanagari English field में | पूरी तरह clean English row |
|---|---:|---:|---:|---:|---:|
| CDP | 240 | 231 | 9 | 0 | 231 |
| Maths | 240 | 176 | 64 | 0 | 176 |
| EVS | 240 | 191 | 49 | 0 | 191 |
| **कुल** | **720** | **598** | **122** | **0** | **598** |

- **598/720** rows अब English mode के लिए field-wise clean हैं।
- **122 questions** में अभी भी कम-से-कम एक English question/option field blank है।
- **0 questions** में English field के अन्दर Hindi बची है।

## File-wise स्थिति

| Source CSV | प्रश्न | Clean English | Missing English fields | Hindi inside English fields |
|---|---:|---:|---:|---:|
| `q_cdp.csv` | 60 | 60 | 0 | 0 |
| `q_evs.csv` | 60 | 60 | 0 | 0 |
| `q_math.csv` | 60 | 60 | 0 | 0 |
| `q_utet2020.csv` | 90 | 62 | 28 | 0 |
| `q_utet2021.csv` | 90 | 90 | 0 | 0 |
| `q_utet2022.csv` | 90 | 90 | 0 | 0 |
| `q_utet2024.csv` | 90 | 90 | 0 | 0 |
| `q_utet2025.csv` | 90 | 58 | 32 | 0 |
| `q_utet2026.csv` | 90 | 28 | 62 | 0 |

## बाकी काम

मुख्य visible bug — English mode में Hindi options दिखना — ठीक हो गया है।

English mode को पूरी तरह bilingual बनाने के लिए अब 122 questions के missing English fields भरने हैं:

1. `q_utet2020.csv` — 28 questions
2. `q_utet2025.csv` — 32 questions
3. `q_utet2026.csv` — 62 questions

हर affected question की exact file, CSV line, source और blank field `UTET_LANGUAGE_ISSUES.csv` में है।

## Data changes

इस phase में 13 rows के 29 English fields सुधारे गए हैं। Hindi columns, answer indices, source, PYQ flag और years में कोई बदलाव नहीं हुआ है।

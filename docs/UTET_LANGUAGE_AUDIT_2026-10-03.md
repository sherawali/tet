# UTET भाषा ऑडिट — CDP, गणित और EVS

**ऑडिट तारीख:** 3 अक्टूबर 2026
**स्कोप:** `exams` में `utet1` वाले CDP, गणित और EVS के सभी प्रश्न — `q_cdp.csv`, `q_math.csv`, `q_evs.csv`, और आधिकारिक `q_utet2020/2021/2022/2024/2025/2026.csv`।
**कुल जाँचे गए प्रश्न:** 720 (हर section में 240)

## क्या जाँचा गया

1. **Hindi mode:** `q_hi`, `a_hi`, `b_hi`, `c_hi`, `d_hi` सभी मौजूद हैं या नहीं।
2. **English mode:** `q_en`, `a_en`, `b_en`, `c_en`, `d_en` सभी मौजूद हैं या नहीं।
3. English वाले fields में Devanagari/Hindi text तो नहीं है।
4. Hindi-only formula, variable, Roman numeral, chemical formula (जैसे `x = 9`, `HCl`, `SDG 6`) को error **नहीं** माना गया; वे भाषा की गलती नहीं हैं।

> यह field-level display audit है: इससे blank field और गलत-language field पकड़े जाते हैं। हर translation की वैचारिक/meaning-level समानता का अलग manual review अभी बाकी है।

## निष्कर्ष

### Hindi mode — सुरक्षित

- **720/720** Hindi questions मौजूद हैं।
- **720/720** में चारों Hindi options मौजूद हैं।
- कोई Hindi stem खाली नहीं है।
- जो cells Devanagari में नहीं हैं वे सिर्फ formula/notation/roman-number/chemical-formula जैसे valid cases हैं; कोई पूरा English sentence Hindi option में नहीं मिला।

**नतीजा:** CDP, गणित और EVS में Hindi mode के लिए इस audit में blank/wrong-column issue नहीं मिला।

### English mode — 132 प्रश्न ठीक नहीं हैं

| Section | कुल | सारे English fields मौजूद | कोई field blank | Hindi/Devanagari English field में | पूरी तरह clean English row |
|---|---:|---:|---:|---:|---:|
| CDP | 240 | 231 | 9 | 6 | 226 |
| Maths | 240 | 176 | 64 | 3 | 174 |
| EVS | 240 | 191 | 49 | 4 | 188 |
| **कुल** | **720** | **598** | **122** | **13** | **588** |

- कुल **132 unique questions** में English-mode problem है।
- **122** प्रश्नों में कम-से-कम एक English question/option field blank है।
- **13** प्रश्नों के English fields में Hindi/Devanagari बची है।
- इन दोनों categories में **3 प्रश्न overlap** करते हैं; इसलिए total unique affected questions **132** हैं.
- इसलिए English mode अभी **588/720 (81.7%)** rows के लिए ही field-wise safe है।

## File-wise स्थिति

| Source CSV | प्रश्न | Clean English | Missing English fields | Hindi inside English fields |
|---|---:|---:|---:|---:|
| `q_cdp.csv` | 60 | 60 | 0 | 0 |
| `q_evs.csv` | 60 | 60 | 0 | 0 |
| `q_math.csv` | 60 | 60 | 0 | 0 |
| `q_utet2020.csv` | 90 | 60 | 28 | 4 |
| `q_utet2021.csv` | 90 | 90 | 0 | 0 |
| `q_utet2022.csv` | 90 | 90 | 0 | 0 |
| `q_utet2024.csv` | 90 | 90 | 0 | 0 |
| `q_utet2025.csv` | 90 | 55 | 32 | 3 |
| `q_utet2026.csv` | 90 | 23 | 62 | 6 |

## मुख्य कारण

1. **UTET 2020:** 28 प्रश्नों में English question है लेकिन चारों English options खाली हैं।
2. **UTET 2025:** 32 प्रश्नों में English data अधूरा है; खासकर Maths और EVS में options नहीं हैं।
3. **UTET 2026:** 62 प्रश्नों में English data अधूरा है; Maths और EVS के बहुत से questions/options blank हैं.
4. 13 प्रश्नों में English column में Hindi बची है — इसलिए English mode में Hindi option दिखेगा।

## Hindi text जो English mode में गलत जगह है

| File / CSV line | Source | Section | गलत fields |
|---|---|---|---|
| `q_utet2020.csv:10` | UTET 2020 Q9 | cdp | English question contains Devanagari/Hindi |
| `q_utet2020.csv:11` | UTET 2020 Q10 | cdp | English question contains Devanagari/Hindi |
| `q_utet2020.csv:121` | UTET 2020 Q120 | math | English option B contains Devanagari/Hindi; English option C contains Devanagari/Hindi; English option D contains Devanagari/Hindi |
| `q_utet2020.csv:129` | UTET 2020 Q128 | evs | English question contains Devanagari/Hindi |
| `q_utet2025.csv:99` | UTET 2025 Q98 | math | English option B contains Devanagari/Hindi; English option C contains Devanagari/Hindi; English option D contains Devanagari/Hindi |
| `q_utet2025.csv:128` | UTET 2025 Q127 | evs | English option A contains Devanagari/Hindi; English option B contains Devanagari/Hindi; English option D contains Devanagari/Hindi |
| `q_utet2025.csv:148` | UTET 2025 Q147 | evs | English option B contains Devanagari/Hindi; English option C contains Devanagari/Hindi; English option D contains Devanagari/Hindi |
| `q_utet2026.csv:6` | UTET 2026 Q5 | cdp | English option B contains Devanagari/Hindi; English option C contains Devanagari/Hindi; English option D contains Devanagari/Hindi |
| `q_utet2026.csv:21` | UTET 2026 Q20 | cdp | English option B contains Devanagari/Hindi; English option C contains Devanagari/Hindi; English option D contains Devanagari/Hindi |
| `q_utet2026.csv:25` | UTET 2026 Q24 | cdp | English option A contains Devanagari/Hindi; English option B contains Devanagari/Hindi; English option D contains Devanagari/Hindi |
| `q_utet2026.csv:26` | UTET 2026 Q25 | cdp | English option A contains Devanagari/Hindi; English option B contains Devanagari/Hindi; English option D contains Devanagari/Hindi |
| `q_utet2026.csv:111` | UTET 2026 Q110 | math | English option D contains Devanagari/Hindi |
| `q_utet2026.csv:126` | UTET 2026 Q125 | evs | English option D contains Devanagari/Hindi |

## Exact correction list

हर affected question की file, CSV line, source, section और affected field **`UTET_LANGUAGE_ISSUES.csv`** में है। यह file filter करके एक-एक question ठीक करने के लिए बनाई गई है।

### Fix order (recommended)

1. पहले `HINDI_IN_ENGLISH` वाली **13 rows** ठीक हों — ये वही visible issue है जिसमें English mode में Hindi दिखती है।
2. फिर missing English fields वाली rows भरें, पहले 2026 Maths/EVS, फिर 2025, फिर 2020।
3. हर corrected batch के बाद यही audit फिर चलाएँ; लक्ष्य: English में **720/720 clean**।

## Data को अभी नहीं बदला गया

इस audit में question-bank CSV या generated `cdn/` packs को बदला नहीं गया है। केवल audit report और issue list बनाई गई है।

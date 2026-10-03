# CTET भाषा ऑडिट — CDP, गणित और EVS

**ऑडिट तारीख:** 3 अक्टूबर 2026
**स्कोप:** `q_ctet.csv` के CTET-1 और CTET-2 में CDP, गणित और EVS के सभी प्रश्न।
**कुल जाँचे गए प्रश्न:** 3,845

## क्या जाँचा गया

1. Hindi mode में `q_hi` और `a_hi` से `d_hi` तक सभी fields मौजूद हैं या नहीं।
2. English mode में `q_en` और `a_en` से `d_en` तक सभी fields मौजूद हैं या नहीं।
3. English fields में अनचाहा Hindi/Devanagari text तो नहीं है।
4. Raw extraction की टूट-फूट जैसे `///`, अधूरे options, केवल `and`/`Only` जैसे option और mixed-language fragments खोजे गए।

> यह language + data-structure audit है। हर question का answer/fact सत्यापन अलग subject review में किया जाएगा।

## Field completeness — बहुत अच्छी स्थिति

| Exam | Section | प्रश्न | Hindi question + 4 options | English question + 4 options |
|---|---|---:|---:|---:|
| CTET-1 | CDP | 1,312 | 1,312 | 1,312 |
| CTET-1 | Maths | 495 | 495 | 495 |
| CTET-1 | EVS | 1,125 | 1,125 | 1,125 |
| CTET-2 | CDP | 278 | 278 | 278 |
| CTET-2 | Maths | 573 | 573 | 573 |
| CTET-2 | EVS | 62 | 62 | 62 |
| **कुल** |  | **3,845** | **3,845** | **3,845** |

- किसी भी Hindi या English question/option field में blank नहीं मिला।
- English options में Hindi/Devanagari text नहीं मिला।
- English question field में 3 बार Devanagari दिखी, पर वे `थ, फ, च` तथा `फ/व, म/न` जैसी **भाषा-विज्ञान की उदाहरण ध्वनियाँ** हैं; इसलिए यह bug नहीं है।

## लेकिन 8 records में raw-data corruption है — इन्हें ठीक करना जरूरी है

इन records में fields खाली नहीं हैं, लेकिन raw markdown extraction ने statement/option combinations को तोड़ दिया है। इसलिए app में दोनों modes में अधूरा या अजीब text दिखेगा।

| CSV line | Exam / Section | Source | समस्या |
|---:|---|---|---|
| 3,164 | CTET-2 / Maths | `CTET Bank Maths Pedagogy Questions Paper 2 Q75 [CTET (VI-VIII) 29/12/2021]` | Hindi options में `/ और /` fragments; English option D सिर्फ़ `Only...` है। Statements और combination options अधूरे हैं। |
| 3,596 | CTET-2 / Maths | `CTET Bank Maths Pedagogy Questions Paper 2 Q509 [CTET (VI-VIII) 24/01/2023 (Shift-II)]` | Van Hiele question के option combinations टूटे हुए हैं; Hindi/English में `Only` और `Only...` बचा है। |
| 4,121 | CTET-1 / Maths | `CTET Paper 1 dec 2019 Q41` | Car-parking table और Hindi/English stem एक-दूसरे में मिल गए हैं; rates/options अधूरे हैं। |
| 5,154 | CTET-1 / Maths | `CTET ctet paper 1 jan 2024 Q38` | Cognitive-conflict question में A/B/C statements हैं, पर four answer-combinations `and` / `Only` बनकर खराब हो गए हैं। |
| 5,180 | CTET-1 / EVS | `CTET ctet paper 1 jan 2024 Q64` | Wahida Prism question के Hindi/English options केवल separators (`/ , /`) और `and` में बदल गए हैं। |
| 5,181 | CTET-1 / EVS | `CTET ctet paper 1 jan 2024 Q65` | Hindi question/options में raw separators और `///`; option D English text के रूप में Hindi column में है। |
| 5,184 | CTET-1 / EVS | `CTET ctet paper 1 jan 2024 Q68` | Bee-hive question में mixed text और `///`; option combinations/source cleanup चाहिए। |
| 5,190 | CTET-1 / EVS | `CTET ctet paper 1 jan 2024 Q74` | Zoo field-trip question के सभी combination options टूटे हैं; English mode में भी `and` / `//` दिखेगा। |

इन सभी 8 records की exact location और repair note `docs/CTET_LANGUAGE_ISSUES.csv` में है।

## एक छोटा Hindi-mode cleanup candidate

`CTET Paper 1 dec 2021 Q11` (CSV line 4,299, CDP) में Hindi option A अभी `Linguistic intelligence` है। इसे `भाषाई बुद्धि` किया जा सकता है। यह question तोड़ता नहीं है, पर Hindi mode के लिए सफ़ाई बेहतर होगी।

## साफ़ निष्कर्ष

- **हाँ:** CTET CDP, Maths और EVS के सभी 3,845 questions में Hindi और English के question + चार options fields बने हुए हैं।
- **English mode:** language leakage वाला सामान्य issue नहीं मिला।
- **लेकिन:** ऊपर के **8 corrupted records** को source paper से फिर से बनाना जरूरी है। इन्हें ठीक किए बिना "पूरी तरह clean" नहीं कहा जा सकता।

**इस audit में कोई question data नहीं बदला गया है।**

# गद्यांश/कविता (stimulus) लिंक ऑडिट — CTET/UTET Paper-I

**तारीख़:** 2026-10-08 · **स्कोप:** `bank-v2` के सभी 109 stimulus-ब्लॉक (CTET P1 8 चक्र + UTET P1 6 चक्र), 742 प्रश्न
**टूल:** [`tools/v2/audit_stimulus_links.py`](../tools/v2/audit_stimulus_links.py) · **रिपोर्ट:** [`bank-v2/audits/stimulus-links/`](../bank-v2/audits/stimulus-links/)

## निष्कर्ष एक लाइन में

शिकायत सही है। **2020 चक्र (31-01-2021) को छोड़कर हर CTET चक्र में passage/poem की जगह
placeholder टेक्स्ट भरा हुआ है**, और उसी placeholder से Q91–Q105 / Q121–Q135 जोड़ दिए गए हैं।
प्रश्न असली पेपर के हैं, गद्यांश असली पेपर का नहीं है।

## जड़ कारण (कोड में पकड़ा गया)

`tools/v2/import_all_ctet.py` हर चक्र के लिए `stimuli_specs` में **गद्यांश का टेक्स्ट खुद हार्ड-कोड
करता है** — वह टेक्स्ट पेपर से पढ़ा नहीं गया:

| पंक्ति | क्या है |
|---|---|
| `23` | `CTET_BASE = Path(r"C:\Users\pujariji\Desktop\ctet\utet\ctet\CTET")` — स्रोत Markdown इस repo में हैं ही नहीं |
| `637, 669, 707, 744, 780, 818, 854` | 2016, 2018, 2019, 2021-Dec, 2023, 2024, 2026 के `stimuli_specs` (इनलाइन passage टेक्स्ट) |
| `819` | 2024 English-I का "गद्यांश": *"Human ingenuity has continually transformed the world…"* |
| `401` | `"review": {"textVerified": True, …}` — बिना जाँचे `True` हार्ड-कोड |

इसलिए हर dummy stimulus पर `review.textVerified: true` लगा है, जबकि टेक्स्ट पेपर से मेल नहीं खाता।

### पकड़े गए ठोस उदाहरण (हर एक इसी repo के डेटा से)

| चक्र | जुड़ा हुआ stimulus | प्रश्न किस बारे में हैं |
|---|---|---|
| 2024 English-I Q91–99 | "Human ingenuity has continually transformed the world…" | Mrs. Higgins, Alfred, Mr. Carr (चोरी की कहानी) |
| 2024 English-I Q100–105 | Wordsworth — *I wandered lonely as a cloud* | soldier / school-boy / lover / "exits and entrances" = **All the world's a stage** |
| 2024 Hindi-II Q121–128 | "श्रम ही जीवन की साधना है…" | गंगा की आबादी, ग्लेशियर, नदियों का जल |
| 2024 English-II Q121–128 | "Reading opens doors to vast realms of knowledge…" | Scarecrow, Dorothy (Wizard of Oz) |
| 2026 English-I Q100–105 | Frost — *The woods are lovely, dark and deep* | "village becoming a graveyard", "the poverty line/receded further" |
| 2018 English-II Q129–135 | "Physical exercise and regular activity are essential…" | **Kevlar** के प्रश्न |
| 2018 English-I Q100–105 | Masefield — *I must go down to the seas again* | Blake — **'The Little Black Boy'** |
| 2018 Hindi-I Q97–105 | "मानव-इतिहास में ऐसे अनेक उदाहरण…" | गीत-कविता बच्चों के जीवन में… |
| 2016 Hindi-I Q119 | माँ-रमेश-मीना संवाद | **"अकबर का जन्म कहाँ हुआ था?"** (EVS/इतिहास प्रश्न) |
| 2016 English-II Q125/126 | पानी वाला passage | `'irritated'`, `'assistance'` — दोनों शब्द passage में हैं ही नहीं |
| 2016 English-II Q147/148 | Raja Ram Mohan Roy passage | `'eliminating'`, `'encouraged'` — passage में नहीं |

2016/2018/2019/2021/2023/2024 के कई संस्कृत ब्लॉक में प्रश्न **भाषा-पेडागॉजी** के हैं
(शिक्षक/छात्र/अधिगम), जबकि गद्यांश से उनका कोई संबंध नहीं — यानी वे stimulus-आधारित हैं ही नहीं।

## चक्र-वार गिनती (टूल का आउटपुट)

ब्लॉक verdict: `ok` = प्रश्न अपने गद्यांश से मेल खाते हैं · `wrong` = आधे से ज़्यादा प्रश्नों का
गद्यांश से एक भी शब्द नहीं मिलता · `pedagogy` = प्रश्न गद्यांश पर निर्भर ही नहीं ·
`sa?` = संस्कृत रूपों के कारण स्वतः निर्णय असंभव, पढ़कर देखना होगा।

| चक्र | ok | partial | wrong | pedagogy | sa? | प्रमाणित (definite) प्रश्न-दोष |
|---|---:|---:|---:|---:|---:|---:|
| CTET 2016 (फ़रवरी) | 3 | 1 | 0 | 1 | 1 | 0 (6 संदिग्ध) |
| CTET 2018 (दिसंबर) | 0 | 3 | 5 | 2 | 2 | 8 |
| CTET 2019 (दिसंबर) | 3 | 1 | 4 | 0 | 4 | 3 |
| **CTET 2020 चक्र (31-01-2021)** | **12** | **1** | **0** | **0** | **0** | **0** |
| CTET 2021 (दिसंबर) | 4 | 2 | 2 | 0 | 2 | 1 |
| CTET 2023 (अगस्त) | 2 | 2 | 3 | 3 | 2 | 7 |
| CTET 2024 (जनवरी) | 1 | 0 | 7 | 0 | 4 | 17 |
| CTET 2026 (फ़रवरी) | 1 | 0 | 7 | 0 | 0 | 10 |
| UTET 2020–2026 | 20 | 3 | 1 | 0 | 0 | 1 |

**2020 चक्र साफ़ है** — वही एक चक्र है जो `import_ctet_2020_paper1.py` से आया था।
बाकी सब `import_all_ctet.py` से आए, और वहीं dummy passage हैं। यही इस निष्कर्ष का
control case है: टूल ठीक काम कर रहा है, डेटा ख़राब है।

"definite" का मतलब: प्रश्न किसी पंक्ति/वाक्यांश को उद्धृत करता है और वह वाक्यांश उसके अपने
गद्यांश में मिलता ही नहीं — यह रूप-विज्ञान (morphology) से प्रभावित नहीं होता, इसलिए पक्का प्रमाण है।

## 2016 की सुनी जाने वाली रिपोर्ट

CTET 2016 की ब्लॉक-दर-ब्लॉक समीक्षा ऑडियो में:
[`audio/ctet-p1-2016-part1.mp3`](../bank-v2/audits/stimulus-links/audio/ctet-p1-2016-part1.mp3)
और [`audio/ctet-p1-2016-part2.mp3`](../bank-v2/audits/stimulus-links/audio/ctet-p1-2016-part2.mp3)
(कुल ~1.5 MB, दोनों के बोल उसी ऑडिट रिपोर्ट से लिए गए हैं)।

## जाँच कैसे दोहराएँ

```bash
python3 tools/v2/audit_stimulus_links.py                 # पूरा बैंक, exit 1 अगर definite दोष हैं
python3 tools/v2/audit_stimulus_links.py --exam ctet --year 2016
python3 tools/v2/validate_structure.py                   # यह सिर्फ़ 2020 चक्र देखता है — इसलिए चुप था
```

जाँच की तीन परतें: (1) संरचना — stimulus मौजूद, प्रश्न-संख्या, ID-रेंज, exam/paper/section/language/slot;
(2) शब्द-मिलान — हर प्रश्न के content शब्द अपने गद्यांश में (stemming के साथ);
(3) उद्धरण-जाँच — प्रश्न में उद्धृत पंक्ति गद्यांश में होनी चाहिए।

## ठीक करने का रास्ता

1. **स्रोत चाहिए।** `CTET_BASE` के Markdown इस repo में नहीं हैं। असली passage/poem टेक्स्ट
   (हर चक्र, हर language slot) चाहिए — तभी dummy हट सकता है।
2. तब तक इन stimulus पर झूठा `review.textVerified: true` हटाना चाहिए, वरना बैंक
   "verified" दावा करता रहेगा।
3. `import_all_ctet.py` में passage इनलाइन हार्ड-कोड करने की जगह स्रोत फ़ाइल से पढ़ा जाए,
   और `textVerified` तभी `True` हो जब ऑडिट टूल उस ब्लॉक को `ok` दे।
4. `validate_structure.py` को 2020 चक्र से आगे बढ़ाकर इस ऑडिट को CI में जोड़ा जाए —
   तभी अगली बार यह गड़बड़ी build में ही पकड़ी जाएगी।

## अभी क्या जाँचा गया और क्या नहीं

- **जाँचा:** सभी 109 ब्लॉक स्वतः; CTET 2016 (Hindi-I, English-II, Sanskrit-II) और 2024 के
  ख़राब ब्लॉक पढ़कर हाथ से; 2020 चक्र control के तौर पर।
- **नहीं जाँचा:** असली CTET पेपर PDF से मिलान — इस सैंडबॉक्स में बाहरी वेब सिर्फ़
  github/npm/pypi तक सीमित है, इसलिए "असली passage यह था" कहना संभव नहीं। यही कारण है कि
  संस्कृत ब्लॉक `sa?` में रखे गए हैं: वहाँ रूप बदलने से शब्द-मिलान भरोसेमंद नहीं है।

---

## 2026-10-09: असली पेपर से पहला मिलान (CTET 21 जनवरी 2024, भाषा-II हिन्दी)

ऊपर लिखा "नहीं जाँचा: असली CTET पेपर PDF से मिलान" अब आंशिक रूप से बदल चुका है — इस
सेशन में वेब उपलब्ध था और 2024 का हल-सहित पेपर पढ़ा गया:
<https://www.oswaal360.com/pluginfile.php/10939/mod_folder/content/0/CTET/Paper%201/2024/21%20Jan%202024.pdf>
(आधिकारिक संग्रह: <https://ctet.nic.in/question-paper-january-2024/>, जो Google Drive लिंक
देता है और यहाँ से नहीं खुलता)।

**पुष्टि:** दोनों हिन्दी-II गद्यांश बैंक में ग़लत थे, ठीक वैसा ही जैसा ऑडिट ने कहा था।

| ब्लॉक | बैंक में था (placeholder) | असली पेपर में है |
|---|---|---|
| `hi-pr-121` (Q121–128) | "श्रम ही जीवन की साधना है…" | अल नीनो / मानसून / गंगोत्री ग्लेशियर और जल-संकट |
| `hi-pr-129` (Q129–135) | "वाणी में मधुरता अमृत के समान है…" | "इस संसार में सब कुछ अस्थायी है… पाप लोहे की जंजीर, पुण्य सोने की" |

Q129–135 के सातों प्रश्न (स्वतंत्र का विलोम, अस्थायी, लोहे/स्वर्ण की जंजीर की तुलना) अब
गद्यांश से शब्द-दर-शब्द मिलते हैं; ऑडिट में दोनों ब्लॉक `wrong` से `ok` हो गए और
CTET-2024 के definite दोष **17 → 10** रह गए (कुल बैंक 47 → 46)।

**नया दोष जो असली टेक्स्ट से ही पकड़ा गया — उत्तर-कुंजी:** Q124 पूछता है "गंगा के किनारे बसे
लोगों की संख्या कितनी है?" असली गद्यांश कहता है *"करीब चालीस करोड़ की आबादी"*, यानी सही उत्तर
विकल्प **(1) 40 करोड़** है, पर बैंक में `answer` = `c` (**87 करोड़**) भरा है — 87 ग्लेशियर के
पिघलने के **सालों** की संख्या है, आबादी नहीं। इसे `bank-v2/sources/stimuli/ctet-p1-2024.json`
के `note` में दर्ज किया गया है; उत्तर बिना आधिकारिक answer key देखे नहीं बदला गया।

**तरीक़ा बदला:** passage अब `import_all_ctet.py` में हार्ड-कोड नहीं होता। असली टेक्स्ट
`bank-v2/sources/stimuli/<cycle>.json` में provenance के साथ रखें और
`python3 tools/v2/apply_stimulus_sources.py` चलाएँ — वही टूल `review.textVerified` सेट करता
है, और उसकी जाँच यही ऑडिट है (`wrong` → `ok`)। निर्देश:
[`bank-v2/sources/stimuli/README.md`](../bank-v2/sources/stimuli/README.md)।

बाक़ी 107 stimuli अब भी placeholder हैं। एक-एक चक्र करके भरना है (उपयोगकर्ता का निर्देश)।

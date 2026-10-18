# 🎯 TET Master 2026: Universal AI Question Generation & Conversion Specification

> **उद्देश्य:** इस प्रॉम्प्ट का उपयोग किसी भी AI (Claude, ChatGPT, Gemini आदि) को देकर नए मॉक टेस्ट बनवाने या पुराने अनफॉर्मेटेड मॉक पेपर्स को 100% क्लीन, बग-फ्री JSON फॉर्मेट में बदलने के लिए करें। यह डेटा सीधे SQLite डेटाबेस और GitHub CDN में बिना किसी अतिरिक्त क्लीनिंग के लाइव हो जाएगा।

---

## 📋 System Prompt for AI Generator (AI के लिए मास्टर निर्देश)

```markdown
आप एक वरिष्ठ TET (CTET / UTET / State TET) परीक्षा प्रश्न-पत्र निर्माता और डेटा-इंजीनियर हैं।
आपका कार्य परीक्षा-स्तर के 100% प्रामाणिक, सटीक और स्वच्छ प्रश्न तैयार करना या दिए गए रफ प्रश्नों को हमारे स्टैंडर्ड JSON स्कीमा में बदलना है।

### ⚠️ सख्त नियम (Zero-Error Guidelines):
1. **कोई स्टार या बोल्ड कचरा नहीं:** स्टेम या ऑप्शन के अंदर कोई भी आवारा स्टार (`**` या `*`) नहीं होना चाहिए।
2. **ऑप्शन में स्टेम या हेडर लीकेज नहीं:** ऑप्शन (D) या किसी भी विकल्प के अंदर कभी भी अगला प्रश्न, सेक्शन हेडर (`## Part...`), निर्देश या पैसेज नहीं आना चाहिए।
3. **कॉम्बिनेशन विकल्पों में पहला अक्षर नहीं काटना:** यदि विकल्प कथनों का संयोजन है, तो वह पूरा लिखा होना चाहिए:
   - ✅ सही: `"(A) और (B)"`, `"(A), (B) और (C)"`, `"केवल (A)"`, `"(1) और (2)"`
   - ❌ गलत: `"और (B)"`, `", (B) और (C)"` (यह कभी नहीं होना चाहिए)
4. **उत्तर कुंजी (Answer Key):** `answer` हमेशा `0` से `3` के बीच पूर्णांक होना चाहिए (0 = A, 1 = B, 2 = C, 3 = D)।
5. **भाषा पृथक्करण:**
   - यदि प्रश्न द्विभाषी (Bilingual) है, तो `q_hindi` और `options_hindi` में शुद्ध हिन्दी, तथा `q_english` और `options_english` में शुद्ध अंग्रेजी होगी।
   - यदि प्रश्न केवल हिन्दी विषय का है, तो अंग्रेजी में ट्रांसलेट न करें, दोनों में हिन्दी ही रखें।
   - यदि प्रश्न केवल अंग्रेजी व्याकरण का है, तो हिन्दी में जबरन ट्रांसलेट न करें, दोनों में अंग्रेजी ही रखें।
```

---

## 🏛️ 6 मुख्य प्रश्न प्रकार (The 6 Archetypes & Standard Templates)

### प्रकार 1: सामान्य बहुविकल्पीय प्रश्न (Standard Single-Choice MCQ)
```json
{
  "id": "mock01_q001",
  "archetype": "mcq",
  "section": "cdp",
  "topic_name": "विकास की अवधारणा एवं अधिगम से संबंध",
  "q_hindi": "निम्नलिखित में से कौन सा स्थूल गत्यात्मक कौशल (Gross Motor Skill) का उदाहरण है?",
  "q_english": "Which of the following is an example of a gross motor skill?",
  "options_hindi": [
    "एक पैर पर संतुलन बनाना",
    "कागज़ पर वृत्त बनाना",
    "धागे में मोती पिरोना",
    "किताब के पन्ने पलटना"
  ],
  "options_english": [
    "Balancing on one foot",
    "Drawing a circle on paper",
    "Stringing beads on a thread",
    "Flipping pages of a book"
  ],
  "answer": 0,
  "explanation_hindi": "एक पैर पर संतुलन बनाने में शरीर की बड़ी मांसपेशियों का समन्वय आवश्यक होता है, इसलिए यह स्थूल गत्यात्मक कौशल है।",
  "difficulty": 1
}
```

---

### प्रकार 2: मिलान वाले प्रश्न (Match the Following / 2-Column Table)
> **नियम:** स्टेम के अंदर दोनों कॉलम साफ-साफ होने चाहिए। बाएं कॉलम के लिए `(A), (B), (C), (D)` और दाएं कॉलम के लिए `(i), (ii), (iii), (iv)` का उपयोग करें। विकल्पों में कूट साफ होना चाहिए।

```json
{
  "id": "mock01_q015",
  "archetype": "match",
  "section": "cdp",
  "topic_name": "अधिगम सिद्धांत",
  "q_hindi": "स्तम्भ I में दिए गए सिद्धांतों का स्तम्भ II में उनके प्रतिपादकों से सही मिलान कीजिए:\nस्तम्भ I (सिद्धांत) : (A) संज्ञानात्मक विकास (B) सामाजिक-सांस्कृतिक सिद्धांत (C) मनोविश्लेषणात्मक सिद्धांत (D) नैतिक विकास सिद्धांत\nस्तम्भ II (प्रतिपादक) : (i) लेव वाइगोत्स्की (ii) जीन पियाजे (iii) लॉरेंस कोहलबर्ग (iv) सिगमंड फ्रायड\nनीचे दिए गए कूट में से सही उत्तर का चयन कीजिए:",
  "q_english": "Match the theories in Column I with their propounders in Column II:\nColumn I (Theory) : (A) Cognitive Development (B) Socio-Cultural Theory (C) Psychoanalytic Theory (D) Moral Development\nColumn II (Propounder) : (i) Lev Vygotsky (ii) Jean Piaget (iii) Lawrence Kohlberg (iv) Sigmund Freud\nChoose the correct code:",
  "options_hindi": [
    "(A)-(ii), (B)-(i), (C)-(iv), (D)-(iii)",
    "(A)-(i), (B)-(ii), (C)-(iii), (D)-(iv)",
    "(A)-(ii), (B)-(iv), (C)-(i), (D)-(iii)",
    "(A)-(iv), (B)-(i), (C)-(ii), (D)-(iii)"
  ],
  "options_english": [
    "(A)-(ii), (B)-(i), (C)-(iv), (D)-(iii)",
    "(A)-(i), (B)-(ii), (C)-(iii), (D)-(iv)",
    "(A)-(ii), (B)-(iv), (C)-(i), (D)-(iii)",
    "(A)-(iv), (B)-(i), (C)-(ii), (D)-(iii)"
  ],
  "answer": 0,
  "explanation_hindi": "पियाजे ने संज्ञानात्मक विकास, वाइगोत्स्की ने सामाजिक-सांस्कृतिक, फ्रायड ने मनोविश्लेषण और कोहलबर्ग ने नैतिक विकास का सिद्धांत दिया।",
  "difficulty": 2
}
```

---

### प्रकार 3: अभिकथन एवं कारण (Assertion & Reason)
> **नियम:** स्टेम में हमेशा `अभिकथन (A):` और `कारण (R):` स्पष्ट लेबल के साथ होने चाहिए। इसके बाद `सही विकल्प का चुनाव कीजिए:` होना चाहिए।

```json
{
  "id": "mock01_q020",
  "archetype": "assertion_reason",
  "section": "evs",
  "topic_name": "पर्यावरण एवं शिक्षण विधियाँ",
  "q_hindi": "अभिकथन (A): प्राथमिक स्तर पर पर्यावरण अध्ययन के शिक्षण में कला और हस्तकला को एकीकृत किया जाना चाहिए।\nकारण (R): कला-एकीकृत शिक्षा विद्यार्थियों के अनुभवात्मक अधिगम और रचनात्मकता को बढ़ावा देती है।\nसही विकल्प चुनिए:",
  "q_english": "Assertion (A): Art and craft should be integrated into teaching of EVS at the primary level.\nReason (R): Art-integrated education promotes experiential learning and creativity in students.\nChoose the correct option:",
  "options_hindi": [
    "(A) और (R) दोनों सही हैं तथा (R), (A) की सही व्याख्या करता है।",
    "(A) और (R) दोनों सही हैं परन्तु (R), (A) की सही व्याख्या नहीं करता है।",
    "(A) सही है परन्तु (R) गलत है।",
    "(A) गलत है परन्तु (R) सही है।"
  ],
  "options_english": [
    "Both (A) and (R) are true and (R) is the correct explanation of (A).",
    "Both (A) and (R) are true but (R) is not the correct explanation of (A).",
    "(A) is true but (R) is false.",
    "(A) is false but (R) is true."
  ],
  "answer": 0,
  "explanation_hindi": "कला का एकीकरण पर्यावरण अध्ययन को रोचक और अनुभवात्मक बनाता है, इसलिए दोनों कथन सत्य हैं और व्याख्या सही है।",
  "difficulty": 2
}
```

---

### प्रकार 4: बहु-कथन मूल्यांकन (Multi-Statement Evaluation)
> **नियम:** स्टेम की शुरुआत भूमिका से हो (`नीचे दिए गए कथनों पर विचार कीजिए:`), उसके बाद कथन साफ तौर पर `(A), (B), (C), (D)` या `(i), (ii), (iii)` से लिखे हों। ऑप्शन्स में संयोजनों का पहला अक्षर कभी न छूटे!

```json
{
  "id": "mock01_q025",
  "archetype": "multi_statement",
  "section": "evs",
  "topic_name": "जीव-जंतु एवं पारिस्थितिकी",
  "q_hindi": "स्लॉथ के संदर्भ में निम्नलिखित कथनों पर विचार कीजिए:\n(A) स्लॉथ लगभग 40 वर्ष के अपने जीवनकाल में केवल 7 से 8 वृक्षों पर ही घूम पाते हैं।\n(B) स्लॉथ प्रतिदिन लगभग 17 घंटे वृक्ष की शाखा पर उल्टे लटक कर सोते हैं।\n(C) स्लॉथ सप्ताह में एक बार ही शौच करने के लिए वृक्ष से नीचे उतरते हैं।\nउपर्युक्त कथनों में से कौन-से सही हैं?",
  "q_english": "Consider the following statements regarding Sloth:\n(A) Sloths change only about 7 to 8 trees in their entire lifespan of 40 years.\n(B) Sloths sleep for about 17 hours a day hanging upside down on a tree branch.\n(C) Sloths come down from the tree only once a week to relieve themselves.\nWhich of the above statements are correct?",
  "options_hindi": [
    "(A), (B) और (C)",
    "(A) और (B)",
    "(B) और (C)",
    "केवल (B)"
  ],
  "options_english": [
    "(A), (B) and (C)",
    "(A) and (B)",
    "(B) and (C)",
    "Only (B)"
  ],
  "answer": 0,
  "explanation_hindi": "NCERT कक्षा 5 के अनुसार स्लॉथ के विषय में तीनों कथन (A, B, C) 100% सत्य हैं।",
  "difficulty": 2
}
```

---

### प्रकार 5: रिक्त स्थान पूर्ति (Fill-in-the-Blank)
> **नियम:** रिक्त स्थान को हमेशा `[ _______ ]` (कम से कम 5 से 7 अंडरस्कोर) के रूप में दर्शाएं ताकि HTML बुकलेट में वह साफ अंडरलाइन के रूप में दिखे।

```json
{
  "id": "mock01_q042",
  "archetype": "fill_blank",
  "section": "math",
  "topic_name": "संख्या पद्धति",
  "q_hindi": "एक समबाहु त्रिभुज का प्रत्येक आंतरिक कोण [ _______ ] अंश का होता है।",
  "q_english": "Each interior angle of an equilateral triangle measures [ _______ ] degrees.",
  "options_hindi": [
    "60°",
    "90°",
    "45°",
    "120°"
  ],
  "options_english": [
    "60°",
    "90°",
    "45°",
    "120°"
  ],
  "answer": 0,
  "explanation_hindi": "समबाहु त्रिभुज के तीनों कोण बराबर होते हैं: 180° / 3 = 60°।",
  "difficulty": 1
}
```

---

### प्रकार 6: गद्यांश / काव्यांश आधारित प्रश्न (Comprehension Passage Questions)
> **नियम:** गद्यांश का टेक्स्ट प्रश्न के अंदर नहीं, बल्कि एक अलग `passage` ऑब्जेक्ट में होना चाहिए। प्रश्न केवल उस `passage_id` को रेफर करेगा। इससे गद्यांश कभी भी ऑप्शन (D) में लीक नहीं होगा!

```json
{
  "passages": [
    {
      "id": "mock01_pass_hindi_01",
      "kind": "prose",
      "dir_text": "निम्नलिखित गद्यांश को पढ़कर प्रश्न संख्या 91 से 95 तक के सबसे उपयुक्त उत्तर वाले विकल्प चुनिए:",
      "body": "शिक्षा जीवन की तैयारी नहीं है, बल्कि शिक्षा ही स्वयं जीवन है। आज की शिक्षा व्यवस्था में केवल ज्ञान ठूंसने पर बल दिया जाता है, जबकि आवश्यकता बालक के सर्वांगीण विकास की है। जब तक विद्यार्थी स्वयं करके नहीं सीखता, तब तक उसका ज्ञान स्थायी नहीं हो सकता। प्रकृति के सानिध्य में सीखी गई बातें बालक के अंतर्मन पर गहरी छाप छोड़ती हैं।"
    }
  ],
  "questions": [
    {
      "id": "mock01_q091",
      "archetype": "passage_linked",
      "section": "hindi",
      "topic_name": "गद्यांश आधारित प्रश्न",
      "passage_id": "mock01_pass_hindi_01",
      "seq_in_passage": 1,
      "q_hindi": "गद्यांश के अनुसार स्थायी ज्ञान प्राप्त करने के लिए क्या आवश्यक है?",
      "q_english": "",
      "options_hindi": [
        "स्वयं करके सीखना",
        "पुस्तकों को कंठस्थ करना",
        "अध्यापक की आज्ञा का पालन",
        "कक्षा में शांत बैठना"
      ],
      "options_english": [],
      "answer": 0,
      "explanation_hindi": "गद्यांश की तीसरी पंक्ति में स्पष्ट उल्लेख है: 'जब तक विद्यार्थी स्वयं करके नहीं सीखता, तब तक उसका ज्ञान स्थायी नहीं हो सकता।'",
      "difficulty": 1
    }
  ]
}
```

---

## 🛠️ पुराने बने-बनाए अनफॉर्मेटेड मॉक्स को कैसे कन्वर्ट करें (Conversion Script Guide)

यदि आपके पास पहले से रफ Markdown फाइलें हैं, तो उन्हें AI को देकर यह निर्देश दें:

```markdown
नीचे दिए गए अनफॉर्मेटेड TET मॉक पेपर को ऊपर दिए गए 'Universal TET JSON Schema' में बदलो।
कन्वर्जन के समय यह जांचना अनिवार्य है:
1. किसी भी ऑप्शन के आगे लगे `- (A)`, `(A)` को हटाकर ऑप्शन का शुद्ध टेक्स्ट रखें, लेकिन यदि ऑप्शन अंदर से `(A) और (B)` है तो उस `(A)` को न काटें।
2. गद्यांशों को अलग 'passages' ऐरे में डालें और प्रश्नों में केवल 'passage_id' लिंक करें।
3. मिलान वाले प्रश्नों को 2-कॉलम टेबल स्टेम में फॉर्मेट करें।
4. आउटपुट केवल वैध JSON होना चाहिए, कोई अतिरिक्त टिप्पणी या चैट टेक्स्ट नहीं।
```

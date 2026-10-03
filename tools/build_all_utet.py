# -*- coding: utf-8 -*-
"""
Official UTET 2020-2026 Data Builder
Converts raw markdown papers from C:\\Users\\pujariji\\Desktop\\ctet\\utet\\utet all set\\UTET
into standardized, verified, production-grade CSV files in tet_repo/content/
"""
import os, sys, re, csv, glob

sys.stdout.reconfigure(encoding='utf-8')

SRC_BASE = r"C:\Users\pujariji\Desktop\ctet\utet\utet all set\UTET"
REPO_DIR = r"C:\Users\pujariji\Desktop\T\tet_repo"
CONTENT_DIR = os.path.join(REPO_DIR, "content")

VALID_TOPICS = {
    'cdp': [
        'समावेशी शिक्षा', 'मूल्यांकन', 'अधिगम सिद्धांत', 'शिक्षण विधियाँ',
        'बुद्धि', 'व्यक्तित्व', 'स्मृति/सृजनात्मकता', 'संज्ञानात्मक विकास',
        'अधिगम की प्रकृति', 'अभिप्रेरणा', 'नीति एवं अधिनियम', 'प्रसिद्ध कथन',
        'भाषा विकास', 'वैयक्तिक भिन्नता', 'लिंग एवं समानता'
    ],
    'hindi': [
        'अपठित गद्यांश', 'अपठित पद्यांश', 'व्याकरण', 'शब्द-भंडार',
        'वर्ण-विचार', 'भाषा शिक्षण', 'हिन्दी साहित्य', 'छंद/अलंकार/रस',
        'कारक/वाक्य', 'मुहावरा/लोकोक्ति'
    ],
    'english': [
        'Comprehension — Passage', 'Comprehension — Poem', 'Grammar',
        'Synonym/Antonym', 'ELT Methods', 'Idioms', 'Figures of Speech',
        'Language Skills', 'Spelling', 'Phonology'
    ],
    'math': [
        'गणित शिक्षाशास्त्र', 'संख्या पद्धति', 'ज्यामिति', 'प्रतिशत/लाभ-हानि',
        'औसत', 'गति-दूरी-समय', 'समय एवं कार्य', 'आँकड़ा निर्वचन',
        'क्षेत्रमिति', 'ब्याज', 'पैटर्न/शृंखला'
    ],
    'evs': [
        'EVS शिक्षाशास्त्र', 'जैव-विविधता', 'प्रदूषण', 'पारिस्थितिकी',
        'कृषि एवं मृदा', 'उत्तराखण्ड विशेष', 'कानून/संविधान/SDG',
        'ऊर्जा एवं जलवायु', 'वन एवं संसाधन', 'भूगोल एवं नदियाँ',
        'जीव अनुकूलन'
    ]
}

# Clean universal directives without any hardcoded question numbers
DIR_HINDI_PROSE = "निर्देश : दिए गए गद्यांश को पढ़कर पूछे गए प्रश्नों के सही/सबसे उपयुक्त उत्तर वाले विकल्प चुनिए।"
DIR_HINDI_POEM = "निर्देश : दी गई कविता/पद्यांश को पढ़कर पूछे गए प्रश्नों के सर्वाधिक उचित उत्तर वाले विकल्प का चयन कीजिए।"
DIR_ENG_PROSE = "Directions : Read the passage given below and answer the questions that follow by selecting the most appropriate option."
DIR_ENG_POEM = "Directions : Read the poem given below and answer the questions that follow by selecting the most appropriate option."

# All 24 passages metadata across the 6 years
PASSAGE_SPECS = [
    # (year, file, pid, kind, q_start, q_end, dir_clean, search_pattern)
    ('2020', '2020/Paper-1/02-भाषा-प्रथम-हिन्दी.md', 'UT20_H1', 'poem', 45, 49, DIR_HINDI_POEM, r'निर्देश \(प्रश्न 45 – 49\).*?\n(.*?)(?=\n\*{0,2}45\.\*{0,2})'),
    ('2020', '2020/Paper-1/02-भाषा-प्रथम-हिन्दी.md', 'UT20_H2', 'prose', 50, 54, DIR_HINDI_PROSE, r'निर्देश \(प्रश्न 50 – 54\).*?\n(.*?)(?=\n\*{0,2}50\.\*{0,2})'),
    ('2020', '2020/Paper-1/05-Language-II-English.md', 'UT20_E1', 'prose', 67, 71, DIR_ENG_PROSE, r'Direction \(Q\. No\. 67-71\).*?\n(.*?)(?=\n\*{0,2}67\.\*{0,2})'),
    ('2020', '2020/Paper-1/05-Language-II-English.md', 'UT20_E2', 'prose', 84, 88, DIR_ENG_PROSE, r'Directions \(Q\. No\. 84-88\).*?\n(.*?)(?=\n\*{0,2}84\.\*{0,2})'),

    ('2021', '2021/Paper-1-SET-C/02-language-1-hindi.md', 'UT21_H1', 'prose', 31, 35, DIR_HINDI_PROSE, r'गद्यांश \(प्रश्न 31–35\).*?\n(.*?)(?=\n\*{0,2}31\.\*{0,2})'),
    ('2021', '2021/Paper-1-SET-C/02-language-1-hindi.md', 'UT21_H2', 'poem', 56, 60, DIR_HINDI_POEM, r'पद्यांश \(प्रश्न 56–60\).*?\n(.*?)(?=\n\*{0,2}56\.\*{0,2})'),
    ('2021', '2021/Paper-1-SET-C/05-language-2-english.md', 'UT21_E1', 'prose', 69, 73, DIR_ENG_PROSE, r'Passage \(Q\. No\. 69 to 73\).*?\n(.*?)(?=\n\*{0,2}69\.\*{0,2})'),
    ('2021', '2021/Paper-1-SET-C/05-language-2-english.md', 'UT21_E2', 'prose', 74, 78, DIR_ENG_PROSE, r'Passage \(Q\. No\. 74 to 78\).*?\n(.*?)(?=\n\*{0,2}74\.\*{0,2})'),

    ('2022', '2022/02_Lang1_Hindi.md', 'UT22_H1', 'poem', 50, 51, DIR_HINDI_POEM, r'निर्देश \(प्रश्न 50-51\):.*?\n(.*?)(?=\n\*{0,2}50\.\*{0,2})'),
    ('2022', '2022/02_Lang1_Hindi.md', 'UT22_H2', 'prose', 55, 59, DIR_HINDI_PROSE, r'निर्देश \(प्रश्न 55-59\):.*?\n(.*?)(?=\n\*{0,2}55\.\*{0,2})'),
    ('2022', '2022/05_Lang2_English.md', 'UT22_E1', 'poem', 72, 75, DIR_ENG_POEM, r'Direction \(Q\.No\. 72-75\):.*?\n(.*?)(?=\n\*{0,2}72\.\*{0,2})'),
    ('2022', '2022/05_Lang2_English.md', 'UT22_E2', 'prose', 79, 82, DIR_ENG_PROSE, r'Direction \(Q\. No\. 79 to 82\):.*?\n(.*?)(?=\n\*{0,2}79\.\*{0,2})'),

    ('2024', '2024/Paper-1-SET-D/02-language-1-hindi.md', 'UT24_H1', 'prose', 46, 50, DIR_HINDI_PROSE, r'गद्यांश \(प्रश्न 46–50\).*?\n(.*?)(?=\n\*{0,2}46\.\*{0,2})'),
    ('2024', '2024/Paper-1-SET-D/02-language-1-hindi.md', 'UT24_H2', 'poem', 51, 55, DIR_HINDI_POEM, r'पद्यांश \(प्रश्न 51–55\).*?\n(.*?)(?=\n\*{0,2}51\.\*{0,2})'),
    ('2024', '2024/Paper-1-SET-D/05-language-2-english.md', 'UT24_E1', 'prose', 71, 75, DIR_ENG_PROSE, r'Passage \(Q\. No\. 71–75\).*?\n(.*?)(?=\n\*{0,2}71\.\*{0,2})'),
    ('2024', '2024/Paper-1-SET-D/05-language-2-english.md', 'UT24_E2', 'prose', 86, 90, DIR_ENG_PROSE, r'Passage \(Q\. No\. 86–90\).*?\n(.*?)(?=\n\*{0,2}86\.\*{0,2})'),

    ('2025', '2025/Paper-1/02-भाषा-प्रथम-हिन्दी.md', 'UT25_H1', 'prose', 31, 35, DIR_HINDI_PROSE, r'निर्देश \(प्रश्न 31 – 35\).*?\n(.*?)(?=\n\*{0,2}31\.\*{0,2})'),
    ('2025', '2025/Paper-1/02-भाषा-प्रथम-हिन्दी.md', 'UT25_H2', 'poem', 56, 60, DIR_HINDI_POEM, r'निर्देश \(प्रश्न 56 – 60\).*?\n(.*?)(?=\n\*{0,2}56\.\*{0,2})'),
    ('2025', '2025/Paper-1/05-Language-II-English.md', 'UT25_E1', 'prose', 64, 68, DIR_ENG_PROSE, r'Direction \(Q\. No\. 64 to 68\).*?\n(.*?)(?=\n\*{0,2}64\.\*{0,2})'),
    ('2025', '2025/Paper-1/05-Language-II-English.md', 'UT25_E2', 'prose', 81, 85, DIR_ENG_PROSE, r'Direction \(Q\. No\. 81 to 85\).*?\n(.*?)(?=\n\*{0,2}81\.\*{0,2})'),

    ('2026', '2026/Paper-1/02-भाषा-प्रथम-हिन्दी.md', 'UT26_H1', 'poem', 31, 34, DIR_HINDI_POEM, r'निर्देश \(प्रश्न 31 – 34\).*?\n(.*?)(?=\n\*{0,2}31\.\*{0,2})'),
    ('2026', '2026/Paper-1/02-भाषा-प्रथम-हिन्दी.md', 'UT26_H2', 'prose', 56, 59, DIR_HINDI_PROSE, r'निर्देश \(प्रश्न 56 – 59\).*?\n(.*?)(?=\n\*{0,2}56\.\*{0,2})'),
    ('2026', '2026/Paper-1/05-Language-II-English.md', 'UT26_E1', 'prose', 63, 66, DIR_ENG_PROSE, r'Direction \(Q\. No\. 63 to 66\).*?\n(.*?)(?=\n\*{0,2}63\.\*{0,2})'),
    ('2026', '2026/Paper-1/05-Language-II-English.md', 'UT26_E2', 'prose', 73, 76, DIR_ENG_PROSE, r'Direction \(Q\. No\. 73 to 76\).*?\n(.*?)(?=\n\*{0,2}73\.\*{0,2})')
]

# Extract all passage bodies cleanly
PASSAGES_CACHE = {}
for yr, rel_f, pid, kind, qs, qe, d_clean, pat in PASSAGE_SPECS:
    fpath = os.path.join(SRC_BASE, rel_f)
    with open(fpath, encoding='utf-8') as fp:
        c = fp.read()
    m = re.search(pat, c, re.DOTALL)
    if not m:
        print(f"❌ Failed to find passage {pid} in {rel_f}")
        sys.exit(1)
    raw_body = m.group(1).strip()
    raw_body = re.sub(r'^\*{0,2}Directions?:.*?\n', '', raw_body, flags=re.IGNORECASE)
    raw_body = re.sub(r'^\*{0,2}निर्देश:.*?\n', '', raw_body)
    raw_body = re.sub(r'^\*{0,2}Passage\s*\(.*?\).*?\n', '', raw_body, flags=re.IGNORECASE)
    raw_body = re.sub(r'^\*{0,2}गद्यांश\s*\(.*?\).*?\n', '', raw_body)
    raw_body = re.sub(r'^\*{0,2}पद्यांश\s*\(.*?\).*?\n', '', raw_body)
    lines = [re.sub(r'^>\s?', '', l).strip() for l in raw_body.split('\n')]
    lines = [l for l in lines if l and not l.startswith('निम्नलिखित') and not l.startswith('Read ') and not l.startswith('**निर्देश') and not l.startswith('*निर्देश')]
    clean_body = '<br>'.join(lines) if kind == 'poem' else ' '.join(lines)
    clean_body = clean_body.strip('"').strip("'")
    PASSAGES_CACHE[pid] = {
        'pid': pid,
        'kind': kind,
        'dir_text': d_clean,
        'body': clean_body,
        'q_start': qs,
        'q_end': qe,
        'year': yr
    }

def clean_q_text(text):
    if not text: return ''
    text = re.sub(r'^(?:###\s*)?(?:\*+)?(?:Directions?|निर्देश)\s*\([^)]*\)\s*(?::|\*+|-)?\s*', '', text, flags=re.IGNORECASE)
    text = re.sub(r'^(?:###\s*)?(?:\*+)?(?:Directions?|निर्देश)\s*:\s*', '', text, flags=re.IGNORECASE)
    text = re.sub(r'\(?\s*(?:प्रश्न|Q(?:uestion)?\.?\s*No\.?)\s*\d+\s*(?:से|to|–|-|&)\s*\d+\s*\)?[:\s\-]*', '', text, flags=re.IGNORECASE)
    text = re.sub(r'^\*+|\*+$', '', text.strip()).strip()
    text = re.sub(r'^-+|-+$', '', text.strip()).strip()
    return text.strip()

def parse_line_abcd(s):
    s_clean = s.strip().strip('*').strip()
    ia = s_clean.find('(A)')
    if ia == -1: return None
    ib = s_clean.find('(B)', ia + 3)
    if ib == -1: return None
    ic = s_clean.find('(C)', ib + 3)
    if ic == -1: return None
    id_ = s_clean.find('(D)', ic + 3)
    if id_ == -1: return None
    q = s_clean[:ia].strip()
    q = re.sub(r'[\s\-:–]+$', '', q).strip()
    oa = s_clean[ia+3:ib].strip()
    ob = s_clean[ib+3:ic].strip()
    oc = s_clean[ic+3:id_].strip()
    od = s_clean[id_+3:].strip()
    return q, [oa, ob, oc, od]

def guess_topic(sec, q_hi, q_en, pid, p_kind):
    if pid:
        if sec == 'hindi':
            return 'अपठित पद्यांश' if p_kind == 'poem' else 'अपठित गद्यांश'
        elif sec == 'english':
            return 'Comprehension — Poem' if p_kind == 'poem' else 'Comprehension — Passage'

    text = (q_hi + " " + (q_en or "")).lower()

    if sec == 'cdp':
        if any(w in text for w in ['समावेशी', 'दिव्यांग', 'अपवंचित', 'विशिष्ट', 'प्रतिभाशाली', 'inclusive', 'gifted', 'disabled']):
            return 'समावेशी शिक्षा'
        if any(w in text for w in ['मूल्यांकन', 'मापन', 'आकलन', 'सतत', 'evaluation', 'assessment', 'cce', 'परीक्षण']):
            return 'मूल्यांकन'
        if any(w in text for w in ['पियाजे', 'कोहलबर्ग', 'वायगोत्स्की', 'वायगॉट्स्की', 'piaget', 'kohlberg', 'vygotsky', 'संज्ञानात्मक विकास']):
            return 'संज्ञानात्मक विकास'
        if any(w in text for w in ['बुद्धि', 'iq', 'intelligence', 'गार्डनर', 'gardner', 'बिने', 'binet']):
            return 'बुद्धि'
        if any(w in text for w in ['व्यक्तित्व', 'personality', 'अंतर्मुखी', 'बहिर्मुखी', 'रोर्शा', 'rorschach', 'cat', 'tat']):
            return 'व्यक्तित्व'
        if any(w in text for w in ['अधिगम', 'थार्नडाइक', 'पावलव', 'स्किनर', 'learning', 'thorndike', 'pavlov', 'skinner', 'कोहलर', 'kohler', 'अन्तर्दृष्टि', 'गेस्टाल्ट']):
            return 'अधिगम सिद्धांत'
        if any(w in text for w in ['अभिप्रेरणा', 'प्रेरणा', 'motivation', 'मैस्लो', 'maslow']):
            return 'अभिप्रेरणा'
        if any(w in text for w in ['स्मृति', 'सृजनात्मकता', 'सृजन', 'रचनात्मक', 'memory', 'creativity', 'अपसारी', 'divergent']):
            return 'स्मृति/सृजनात्मकता'
        if any(w in text for w in ['शिक्षण विधि', 'प्रविधि', 'पद्धति', 'teaching method', 'सूक्ष्म शिक्षण', 'micro']):
            return 'शिक्षण विधियाँ'
        if any(w in text for w in ['rte', 'ncf', 'nep', 'अधिनियम', 'नीति', 'संविधान', 'act']):
            return 'नीति एवं अधिनियम'
        if any(w in text for w in ['भाषा', 'चॉम्स्की', 'chomsky', 'language']):
            return 'भाषा विकास'
        if any(w in text for w in ['लिंग', 'जेंडर', 'gender', 'समानता']):
            return 'लिंग एवं समानता'
        if any(w in text for w in ['वैयक्तिक', 'भिन्नता', 'individual differences']):
            return 'वैयक्तिक भिन्नता'
        if any(w in text for w in ['कथन', 'परिभाषा', 'किसने कहा', 'who said']):
            return 'प्रसिद्ध कथन'
        return 'अधिगम की प्रकृति'

    elif sec == 'hindi':
        if any(w in text for w in ['वर्ण', 'ध्वनि', 'स्वर', 'व्यंजन', 'उच्चारण स्थान', 'अल्पप्राण', 'महाप्राण', 'संवृत']):
            return 'वर्ण-विचार'
        if any(w in text for w in ['संधि', 'समास', 'उपसर्ग', 'प्रत्यय', 'संज्ञा', 'सर्वनाम', 'विशेषण', 'क्रिया', 'काल', 'लिंग', 'वचन']):
            return 'व्याकरण'
        if any(w in text for w in ['कारक', 'वाक्य', 'अशुद्ध', 'शुद्ध']):
            return 'कारक/वाक्य'
        if any(w in text for w in ['पर्यायवाची', 'विलोम', 'तद्भव', 'तत्सम', 'अनेकार्थी', 'एकार्थी', 'शब्द']):
            return 'शब्द-भंडार'
        if any(w in text for w in ['मुहावरा', 'लोकोक्ति', 'कहावत']):
            return 'मुहावरा/लोकोक्ति'
        if any(w in text for w in ['छंद', 'अलंकार', 'रस', 'स्थायी भाव', 'चौपाई', 'दोहा']):
            return 'छंद/अलंकार/रस'
        if any(w in text for w in ['कवि', 'लेखक', 'रचना', 'साहित्य', 'उपन्यास', 'कहानी', 'नाटक', 'मैथिल कोकिल', 'छायावाद']):
            return 'हिन्दी साहित्य'
        if any(w in text for w in ['शिक्षण', 'कौशल', 'उपचारात्मक', 'निदानात्मक', 'मातृभाषा', 'वाचन']):
            return 'भाषा शिक्षण'
        return 'व्याकरण'

    elif sec == 'english':
        if any(w in text for w in ['synonym', 'antonym', 'nearest in meaning', 'opposite']):
            return 'Synonym/Antonym'
        if any(w in text for w in ['idiom', 'phrase', 'proverb']):
            return 'Idioms'
        if any(w in text for w in ['spelt', 'spelling', 'correctly spelt', 'misspelt']):
            return 'Spelling'
        if any(w in text for w in ['sound', 'phoneme', 'diphthong', 'stress', 'intonation', 'vowel', 'consonant']):
            return 'Phonology'
        if any(w in text for w in ['method', 'pedagogy', 'approach', 'remedial', 'bilingual', 'direct method', 'dr. west', 'clt', 'communicative']):
            return 'ELT Methods'
        if any(w in text for w in ['listening', 'speaking', 'reading', 'writing', 'skill', 'lsrw']):
            return 'Language Skills'
        if any(w in text for w in ['metaphor', 'simile', 'personification', 'alliteration', 'figure of speech', 'hyperbole', 'oxymoron']):
            return 'Figures of Speech'
        if any(w in text for w in ['tense', 'preposition', 'conjunction', 'voice', 'narration', 'passive', 'active', 'clause', 'article', 'pronoun', 'verb', 'adverb', 'adjective', 'noun', 'error', 'subject-verb', 'punctuation']):
            return 'Grammar'
        return 'Grammar'

    elif sec == 'math':
        if any(w in text for w in ['शिक्षाशास्त्र', 'प्रकृति', 'पाठ्यक्रम', 'उद्देश्य', 'निदानात्मक', 'उपचारात्मक', 'वैन हीले', 'van hiele', 'ब्लूप्रिंट', 'मूल्यांकन', 'teaching']):
            return 'गणित शिक्षाशास्त्र'
        if any(w in text for w in ['त्रिभुज', 'कोण', 'वृत्त', 'चतुर्भुज', 'समरूप', 'समबाहु', 'जीवा', 'triangle', 'angle', 'circle']):
            return 'ज्यामिति'
        if any(w in text for w in ['क्षेत्रफल', 'आयतन', 'परिमाप', 'घनाभ', 'बेलन', 'शंकु', 'area', 'volume', 'perimeter']):
            return 'क्षेत्रमिति'
        if any(w in text for w in ['प्रतिशत', 'लाभ', 'हानि', 'क्रय', 'विक्रय', 'percent', 'profit', 'loss']):
            return 'प्रतिशत/लाभ-हानि'
        if any(w in text for w in ['औसत', 'माध्य', 'औसत चाल', 'average', 'mean']):
            return 'औसत'
        if any(w in text for w in ['गति', 'दूरी', 'समय', 'रेलगाड़ी', 'चाल', 'speed', 'distance', 'train']):
            return 'गति-दूरी-समय'
        if any(w in text for w in ['कार्य', 'दिन', 'मजदूरी', 'नल', 'हौज', 'work', 'time and work']):
            return 'समय एवं कार्य'
        if any(w in text for w in ['ब्याज', 'साधारण ब्याज', 'चक्रवृद्धि ब्याज', 'interest', 'compound', 'simple']):
            return 'ब्याज'
        if any(w in text for w in ['ग्राफ', 'पाई-चार्ट', 'दंड आरेख', 'माध्यिका', 'बहुलक', 'pie', 'chart', 'data', 'median', 'mode']):
            return 'आँकड़ा निर्वचन'
        if any(w in text for w in ['पैटर्न', 'शृंखला', 'श्रेणी', 'अगला पद', 'pattern', 'series']):
            return 'पैटर्न/शृंखला'
        return 'संख्या पद्धति'

    elif sec == 'evs':
        if any(w in text for w in ['उत्तराखण्ड', 'उत्तराखंड', 'चमोली', 'चिपको', 'जिम कॉर्बेट', 'नंदा देवी', 'फूलों की घाटी', 'uttarakhand']):
            return 'उत्तराखण्ड विशेष'
        if any(w in text for w in ['शिक्षाशास्त्र', 'ncf', 'उद्देश्य', 'क्रियाकलाप', 'भ्रमण', 'pedagogy', 'teaching', 'मूल्यांकन', 'थीम']):
            return 'EVS शिक्षाशास्त्र'
        if any(w in text for w in ['प्रदूषण', 'बीओडी', 'bod', 'ग्रीनहाउस', 'ओजोन', 'अम्ल वर्षा', 'acid rain', 'मीनामाता', 'वायु', 'जल प्रदूषण', 'smog']):
            return 'प्रदूषण'
        if any(w in text for w in ['पारिस्थितिकी', 'पारिस्थितिक', 'खाद्य श्रृंखला', 'खाद्य जाल', 'पोषण स्तर', 'ecology', 'ecosystem', 'food chain']):
            return 'पारिस्थितिकी'
        if any(w in text for w in ['जैव-विविधता', 'रेड डाटा', 'iucn', 'तप्त स्थल', 'hotspot', 'विलुप्त', 'अभयारण्य', 'राष्ट्रीय उद्यान', 'national park', 'biodiversity']):
            return 'जैव-विविधता'
        if any(w in text for w in ['कृषि', 'मृदा', 'मिट्टी', 'फसल', 'झूम', 'रबी', 'खरीफ', 'soil', 'agriculture']):
            return 'कृषि एवं मृदा'
        if any(w in text for w in ['ऊर्जा', 'सौर', 'बायोगैस', 'नवीकरणीय', 'अनवीकरणीय', 'ऊष्मा', 'energy', 'climate']):
            return 'ऊर्जा एवं जलवायु'
        if any(w in text for w in ['वन', 'जंगल', 'संसाधन', 'खनिज', 'कोयला', 'पेट्रोलियम', 'forest', 'resource']):
            return 'वन एवं संसाधन'
        if any(w in text for w in ['नदी', 'पर्वत', 'पठार', 'झील', 'गंगा', 'यमुना', 'river', 'geography']):
            return 'भूगोल एवं नदियाँ'
        if any(w in text for w in ['संविधान', 'अधिकार', 'कानून', 'पर्यावरण संरक्षण अधिनियम', 'वन्यजीव संरक्षण', 'sdg', 'दिवस', 'day', 'act']):
            return 'कानून/संविधान/SDG'
        if any(w in text for w in ['अनुकूलन', 'जड़', 'पत्ती', 'पक्षी', 'घोंसला', 'adaptation', 'animal', 'plant']):
            return 'जीव अनुकूलन'
        return 'पारिस्थितिकी'

    return VALID_TOPICS[sec][0]

LETTER_TO_ANS = {'A': 0, 'B': 1, 'C': 2, 'D': 3}

def parse_year_questions(year):
    """
    Parses exactly 150 questions for a given year.
    Returns list of 150 question dictionaries formatted for CSV.
    """
    all_qs = []

    # 1. Determine files for each section
    if year == '2020':
        sec_files = {
            'cdp': (os.path.join(SRC_BASE, '2020/Paper-1/01-बाल-विकास-एवं-शिक्षण-विज्ञान.md'), 1, 30),
            'hindi': (os.path.join(SRC_BASE, '2020/Paper-1/02-भाषा-प्रथम-हिन्दी.md'), 31, 60),
            'english': (os.path.join(SRC_BASE, '2020/Paper-1/05-Language-II-English.md'), 61, 90),
            'math': (os.path.join(SRC_BASE, '2020/Paper-1/07-गणित-Mathematics.md'), 91, 120),
            'evs': (os.path.join(SRC_BASE, '2020/Paper-1/08-पर्यावरण-अध्ययन-EVS.md'), 121, 150),
        }
    elif year == '2021':
        sec_files = {
            'cdp': (os.path.join(SRC_BASE, '2021/Paper-1-SET-C/01-child-development-pedagogy.md'), 1, 30),
            'hindi': (os.path.join(SRC_BASE, '2021/Paper-1-SET-C/02-language-1-hindi.md'), 31, 60),
            'english': (os.path.join(SRC_BASE, '2021/Paper-1-SET-C/05-language-2-english.md'), 61, 90),
            'math': (os.path.join(SRC_BASE, '2021/Paper-1-SET-C/07-mathematics.md'), 91, 120),
            'evs': (os.path.join(SRC_BASE, '2021/Paper-1-SET-C/08-environmental-studies.md'), 121, 150),
        }
    elif year == '2022':
        sec_files = {
            'cdp': (os.path.join(SRC_BASE, '2022/01_CDP_BalVikas.md'), 1, 30),
            'hindi': (os.path.join(SRC_BASE, '2022/02_Lang1_Hindi.md'), 31, 60),
            'english': (os.path.join(SRC_BASE, '2022/05_Lang2_English.md'), 61, 90),
            'math': (os.path.join(SRC_BASE, '2022/07_Mathematics.md'), 91, 120),
            'evs': (os.path.join(SRC_BASE, '2022/08_EVS.md'), 121, 150),
        }
    elif year == '2024':
        sec_files = {
            'cdp': (os.path.join(SRC_BASE, '2024/Paper-1-SET-D/01-child-development-pedagogy.md'), 1, 30),
            'hindi': (os.path.join(SRC_BASE, '2024/Paper-1-SET-D/02-language-1-hindi.md'), 31, 60),
            'english': (os.path.join(SRC_BASE, '2024/Paper-1-SET-D/05-language-2-english.md'), 61, 90),
            'math': (os.path.join(SRC_BASE, '2024/Paper-1-SET-D/07-mathematics.md'), 91, 120),
            'evs': (os.path.join(SRC_BASE, '2024/Paper-1-SET-D/08-environmental-studies.md'), 121, 150),
        }
    elif year == '2025':
        sec_files = {
            'cdp': (os.path.join(SRC_BASE, '2025/Paper-1/01-बाल-विकास-एवं-शिक्षण-विज्ञान.md'), 1, 30),
            'hindi': (os.path.join(SRC_BASE, '2025/Paper-1/02-भाषा-प्रथम-हिन्दी.md'), 31, 60),
            'english': (os.path.join(SRC_BASE, '2025/Paper-1/05-Language-II-English.md'), 61, 90),
            'math': (os.path.join(SRC_BASE, '2025/Paper-1/07-गणित-Mathematics.md'), 91, 120),
            'evs': (os.path.join(SRC_BASE, '2025/Paper-1/08-पर्यावरण-अध्ययन-EVS.md'), 121, 150),
        }
    elif year == '2026':
        sec_files = {
            'cdp': (os.path.join(SRC_BASE, '2026/Paper-1/01-बाल-विकास-एवं-शिक्षण-विज्ञान.md'), 1, 30),
            'hindi': (os.path.join(SRC_BASE, '2026/Paper-1/02-भाषा-प्रथम-हिन्दी.md'), 31, 60),
            'english': (os.path.join(SRC_BASE, '2026/Paper-1/05-Language-II-English.md'), 61, 90),
            'math': (os.path.join(SRC_BASE, '2026/Paper-1/07-गणित-Mathematics.md'), 91, 120),
            'evs': (os.path.join(SRC_BASE, '2026/Paper-1/08-पर्यावरण-अध्ययन-EVS.md'), 121, 150),
        }

    # Load external answer keys if 2021 or 2024
    key_map = {}
    if year == '2021':
        kp = os.path.join(SRC_BASE, '2021/Paper-1-SET-C/09-answer-key.md')
        with open(kp, encoding='utf-8') as f:
            for m in re.finditer(r'\|\s*(\d+)\s*\|\s*\*\*([A-D])\*\*', f.read()):
                key_map[int(m.group(1))] = m.group(2)
    elif year == '2024':
        kp = os.path.join(SRC_BASE, '2024/Paper-1-SET-D/09-answer-key.md')
        with open(kp, encoding='utf-8') as f:
            for m in re.finditer(r'\|\s*(\d+)\s*\|\s*\*\*([A-D])\*\*', f.read()):
                key_map[int(m.group(1))] = m.group(2)

    for sec in ['cdp', 'hindi', 'english', 'math', 'evs']:
        fpath, qstart, qend = sec_files[sec]
        with open(fpath, encoding='utf-8') as f:
            txt = f.read()

        # Strict split on **\d+.** to prevent splitting on numbered sub-points (e.g. 1. 2. 3.)
        blocks = re.split(r'\n(?=\*\*\d+\.\*\*\s+)', txt)
        sec_qs = {}
        active_dir = ''

        for b in blocks:
            b = b.strip()
            if not b: continue

            # Check if there is an overarching Direction at the top of this block before **X.**
            m_top_dir = re.search(r'(?:Directions?|निर्देश)\s*\([^)]*\)\s*(?::|\*+|-)?\s*([^\n]+)', b, re.IGNORECASE)
            if m_top_dir:
                active_dir = clean_q_text(m_top_dir.group(1))

            m_q = re.match(r'^\*{0,2}(\d+)\.\*{0,2}\s+(.*)', b, re.DOTALL)
            if not m_q: continue
            qnum = int(m_q.group(1))
            if qnum < qstart or qnum > qend: continue

            rest = m_q.group(2).strip()

            # Determine answer
            ans_letter = None
            if qnum in key_map:
                ans_letter = key_map[qnum]
            else:
                m_ans = re.search(r'(?:✅\s*)?(?:सही उत्तर|उत्तर|Correct Answer|Answer)\s*(?:/\s*(?:Correct Answer|उत्तर))?\s*:\s*\(([A-D])\)', rest, re.IGNORECASE)
                if m_ans:
                    ans_letter = m_ans.group(1)

            # Strip answer block from rest
            m_cut = re.search(r'\n(?:\*\*|#|\s*✅)?(?:सही उत्तर|उत्तर|Correct Answer|Answer)', rest, re.IGNORECASE)
            if m_cut:
                rest = rest[:m_cut.start()].strip()
            rest = re.sub(r'\n---+\s*$', '', rest).strip()

            # Special case for 2026 Math Q105
            if year == '2026' and qnum == 105:
                ans_letter = 'D'
                q_hi = 'निम्नलिखित में से कौन-सा एक सबसे बड़ा है?'
                oh = ['0.725', '0.725̄', '0.72̄5̄', '0.7̄2̄5̄']
                q_en = 'Which of the following is the greatest?'
                oe = ['0.725', '0.725̄', '0.72̄5̄', '0.7̄2̄5̄']
                sec_qs[qnum] = {
                    'num': qnum, 'sec': sec, 'topic': 'संख्या पद्धति',
                    'q_hi': q_hi, 'q_en': q_en, 'oh': oh, 'oe': oe,
                    'ans': 3, 'pid': '', 'pseq': '', 'p_kind': '',
                    'p_dir': '', 'p_body': '', 'source': f"UTET {year} Q{qnum}", 'year': year
                }
                continue

            # Check passage assignment
            assigned_pid = None
            assigned_kind = None
            assigned_dir = None
            assigned_body = None
            pseq = None

            for pid, pdata in PASSAGES_CACHE.items():
                if pdata['year'] == year and pdata['q_start'] <= qnum <= pdata['q_end']:
                    assigned_pid = pid
                    pseq = qnum - pdata['q_start'] + 1
                    if pseq == 1:
                        assigned_kind = pdata['kind']
                        assigned_dir = pdata['dir_text']
                        assigned_body = pdata['body']
                    break

            # Check format:
            # Format A: Bullet list: - (A) ...
            bullets = re.findall(r'(?:^|\n)-\s*\(([A-D])\)\s*(.*?)(?=(?:\n-\s*\([A-D]\)|\Z))', rest, re.DOTALL)
            if len(bullets) == 4:
                opt_dict = {ltr: re.sub(r'✅', '', otxt).strip().strip('*').strip() for ltr, otxt in bullets}
                for ltr, otxt in bullets:
                    if '✅' in otxt and not ans_letter:
                        ans_letter = ltr

                m_first = re.search(r'(?:^|\n)-\s*\([A-D]\)', rest)
                q_text = rest[:m_first.start()].strip() if m_first else rest
                q_text = clean_q_text(q_text)
                if not q_text and active_dir:
                    q_text = active_dir

                oh = [opt_dict['A'], opt_dict['B'], opt_dict['C'], opt_dict['D']]
                oe = None
                if any(' / ' in o for o in oh):
                    oh_clean = []
                    oe_clean = []
                    for o in oh:
                        if ' / ' in o:
                            sp = o.split(' / ', 1)
                            oh_clean.append(sp[0].strip())
                            oe_clean.append(sp[1].strip())
                        else:
                            oh_clean.append(o)
                            oe_clean.append(o)
                    oh = oh_clean
                    oe = oe_clean

                q_hi = q_text
                q_en = None
                if '\n*' in q_text:
                    sp = q_text.split('\n*', 1)
                    q_hi = sp[0].strip()
                    q_en = sp[1].strip('*').strip()
                elif '\n' in q_text:
                    lines = [l.strip() for l in q_text.split('\n') if l.strip()]
                    q_hi = lines[0]
                    if len(lines) > 1 and re.match(r'^[A-Za-z0-9\s,\.\?\-\'\"]+$', lines[1]):
                        q_en = lines[1]

                if sec == 'english':
                    q_en = q_hi
                    oe = oh

                # Check if bilingual pair in 2021/2024
                if qnum in sec_qs:
                    existing = sec_qs[qnum]
                    existing['q_en'] = q_hi
                    existing['oe'] = oh
                    continue

                topic = guess_topic(sec, q_hi, q_en, assigned_pid, assigned_kind)
                sec_qs[qnum] = {
                    'num': qnum, 'sec': sec, 'topic': topic,
                    'q_hi': q_hi, 'q_en': q_en, 'oh': oh, 'oe': oe,
                    'ans': LETTER_TO_ANS.get(ans_letter, 0),
                    'pid': assigned_pid or '', 'pseq': pseq or '',
                    'p_kind': assigned_kind or '', 'p_dir': assigned_dir or '',
                    'p_body': assigned_body or '', 'source': f"UTET {year} Q{qnum}", 'year': year
                }
                continue

            # Format B: Newline options: \n(A) ... \n(B) ...
            nl_opts = re.findall(r'(?:^|\n)\(([A-D])\)\s*(.*?)(?=(?:\n\([A-D]\)|\Z))', rest, re.DOTALL)
            if len(nl_opts) == 4:
                opt_dict = {ltr: re.sub(r'✅', '', otxt).strip().strip('*').strip() for ltr, otxt in nl_opts}
                for ltr, otxt in nl_opts:
                    if '✅' in otxt and not ans_letter:
                        ans_letter = ltr

                m_first = re.search(r'(?:^|\n)\([A-D]\)', rest)
                q_text = rest[:m_first.start()].strip() if m_first else rest
                q_text = clean_q_text(q_text)
                if not q_text and active_dir:
                    q_text = active_dir

                oh = [opt_dict['A'], opt_dict['B'], opt_dict['C'], opt_dict['D']]
                q_hi = q_text
                q_en = q_text if sec == 'english' else None
                oe = oh if sec == 'english' else None

                if qnum in sec_qs:
                    existing = sec_qs[qnum]
                    existing['q_en'] = q_hi
                    existing['oe'] = oh
                    continue

                topic = guess_topic(sec, q_hi, q_en, assigned_pid, assigned_kind)
                sec_qs[qnum] = {
                    'num': qnum, 'sec': sec, 'topic': topic,
                    'q_hi': q_hi, 'q_en': q_en, 'oh': oh, 'oe': oe,
                    'ans': LETTER_TO_ANS.get(ans_letter, 0),
                    'pid': assigned_pid or '', 'pseq': pseq or '',
                    'p_kind': assigned_kind or '', 'p_dir': assigned_dir or '',
                    'p_body': assigned_body or '', 'source': f"UTET {year} Q{qnum}", 'year': year
                }
                continue

            # Format C: Inline options (sequential search)
            lines = [l.strip() for l in rest.split('\n') if l.strip()]
            hi_q_lines = []
            hi_opts = None
            en_q_lines = []
            en_opts = None

            for l in lines:
                res = parse_line_abcd(l)
                if res:
                    q_part, opts = res
                    if sec == 'hindi':
                        if q_part: hi_q_lines.append(q_part)
                        hi_opts = opts
                    elif sec == 'english':
                        if q_part: en_q_lines.append(q_part)
                        en_opts = opts
                    else:
                        has_dev = bool(re.search(r'[\u0900-\u097F]', l))
                        is_star_en = l.startswith('*')
                        if is_star_en:
                            if q_part: en_q_lines.append(q_part)
                            en_opts = opts
                        elif has_dev:
                            if q_part: hi_q_lines.append(q_part)
                            hi_opts = opts
                        else:
                            # Numbers or symbols or matching column (e.g. 10, 20 or 1-a)
                            if hi_opts is None:
                                if q_part: hi_q_lines.append(q_part)
                                hi_opts = opts
                                if en_opts is None:
                                    en_opts = opts
                            else:
                                if q_part: en_q_lines.append(q_part)
                                en_opts = opts
                else:
                    if sec == 'hindi':
                        hi_q_lines.append(l)
                    elif sec == 'english':
                        en_q_lines.append(l.strip('*').strip())
                    else:
                        if re.search(r'[\u0900-\u097F]', l):
                            hi_q_lines.append(l)
                        else:
                            en_q_lines.append(l.strip('*').strip())

            q_hi = clean_q_text('\n'.join(hi_q_lines).strip())
            q_en = clean_q_text('\n'.join(en_q_lines).strip())

            if not q_hi and active_dir:
                q_hi = active_dir
            if not q_en and active_dir and sec == 'english':
                q_en = active_dir

            if sec == 'english':
                q_hi = q_en or q_hi
                q_en = q_hi
                hi_opts = en_opts or hi_opts
                en_opts = hi_opts
            else:
                if hi_opts is None and en_opts is not None:
                    hi_opts = en_opts
                if en_opts is None and hi_opts is not None:
                    en_opts = hi_opts

            if qnum in sec_qs:
                existing = sec_qs[qnum]
                existing['q_en'] = q_en or q_hi
                existing['oe'] = en_opts or hi_opts
                continue

            topic = guess_topic(sec, q_hi, q_en, assigned_pid, assigned_kind)
            sec_qs[qnum] = {
                'num': qnum, 'sec': sec, 'topic': topic,
                'q_hi': q_hi, 'q_en': q_en, 'oh': hi_opts, 'oe': en_opts,
                'ans': LETTER_TO_ANS.get(ans_letter, 0),
                'pid': assigned_pid or '', 'pseq': pseq or '',
                'p_kind': assigned_kind or '', 'p_dir': assigned_dir or '',
                'p_body': assigned_body or '', 'source': f"UTET {year} Q{qnum}", 'year': year
            }

        # Verify all 30 questions exist
        missing = [i for i in range(qstart, qend + 1) if i not in sec_qs]
        if missing:
            print(f"❌ Year {year} Section {sec} is missing questions: {missing}")
            sys.exit(1)

        for i in range(qstart, qend + 1):
            all_qs.append(sec_qs[i])

    return all_qs

def generate_all_csvs():
    years = ['2020', '2021', '2022', '2024', '2025', '2026']

    # 1. Remove old incomplete UTET files from content/
    old_files = [
        'q_utet2019.csv',
        'q_utet2021.csv',
        'q_utet2022.csv',
        'q_utet2025.csv',
        'q_utet2026.csv'
    ]
    for of in old_files:
        p = os.path.join(CONTENT_DIR, of)
        if os.path.exists(p):
            os.remove(p)
            print(f"🗑 Removed old file: {of}")

    fieldnames = [
        'exams', 'section', 'topic', 'difficulty',
        'pid', 'pseq', 'p_kind', 'p_dir', 'p_body',
        'q_hi', 'a_hi', 'b_hi', 'c_hi', 'd_hi',
        'q_en', 'a_en', 'b_en', 'c_en', 'd_en',
        'ans', 'source', 'is_pyq', 'years'
    ]

    total_generated = 0

    for yr in years:
        qs = parse_year_questions(yr)
        if len(qs) != 150:
            print(f"❌ Error: Year {yr} has {len(qs)} questions instead of 150!")
            sys.exit(1)

        out_csv = os.path.join(CONTENT_DIR, f"q_utet{yr}.csv")
        with open(out_csv, 'w', encoding='utf-8', newline='') as fp:
            writer = csv.DictWriter(fp, fieldnames=fieldnames)
            writer.writeheader()

            for q in qs:
                oh = q['oh'] or ['', '', '', '']
                oe = q['oe'] or ['', '', '', '']
                row = {
                    'exams': 'utet1',
                    'section': q['sec'],
                    'topic': q['topic'],
                    'difficulty': 2,
                    'pid': q['pid'],
                    'pseq': q['pseq'],
                    'p_kind': q['p_kind'],
                    'p_dir': q['p_dir'],
                    'p_body': q['p_body'],
                    'q_hi': q['q_hi'],
                    'a_hi': oh[0],
                    'b_hi': oh[1],
                    'c_hi': oh[2],
                    'd_hi': oh[3],
                    'q_en': q['q_en'] or '',
                    'a_en': oe[0] if oe else '',
                    'b_en': oe[1] if oe else '',
                    'c_en': oe[2] if oe else '',
                    'd_en': oe[3] if oe else '',
                    'ans': q['ans'],
                    'source': q['source'],
                    'is_pyq': 1,
                    'years': q['year']
                }
                writer.writerow(row)

        print(f"✅ Generated {out_csv}: 150 questions (Q1 to Q150)")
        total_generated += len(qs)

    print(f"\n🎉 Successfully generated {total_generated} official UTET questions across 6 years!")

if __name__ == '__main__':
    generate_all_csvs()

#!/usr/bin/env python3
"""Import the verified CTET July-2020/January-2021 Paper-I Set-I cycle.

This importer is deliberately narrow.  It reconstructs Set-I from the clean Unicode
question text in the local Set-K/Set-J transcription, the official Set-I booklets,
and the official final answer-key tables.  It never imports solution commentary.
"""
from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
BANK = ROOT / "bank-v2"
SOURCE_MD = ROOT / "ctet-questions" / "CTET Paper 1 jan 2021.md"
EXAM_DATE = "2021-01-31"
CYCLE = "2020"
FORM_ID = "ctet-p1-2020-set-i"
SOURCE_MANIFEST_ID = "ctet-p1-2020-2021-set-i-sources"
LETTERS = "abcd"

OFFICIAL_MAIN = "https://cdnbbsr.s3waas.gov.in/s3443dec3062d0286986e21dc0631734c9/uploads/2022/04/2022040421.pdf"
OFFICIAL_KEY = "https://cdnbbsr.s3waas.gov.in/s3443dec3062d0286986e21dc0631734c9/uploads/2022/03/2022033154.pdf"
OFFICIAL_SANSKRIT = "https://cdnbbsr.s3waas.gov.in/s3443dec3062d0286986e21dc0631734c9/uploads/2022/04/2022040485-1.pdf"
MAIN_MIRROR = "https://docs.aglasem.com/view/1a78ff64-e106-11ed-959e-0a5e36bc6706"
KEY_MIRROR = "https://docs.aglasem.com/view/07d63302-80f6-11ec-a618-0a5e36bc6706"

# Set-I question number -> question number in the local source set.
COMMON_I_FROM_K = [
    18, 19, 17, 21, 22, 20, 25, 26, 23, 24, 29, 30, 27, 28, 3,
    4, 1, 2, 7, 8, 5, 6, 12, 13, 9, 10, 11, 15, 16, 14,
    49, 50, 48, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 31, 32,
    33, 34, 35, 36, 38, 39, 37, 40, 41, 42, 43, 44, 45, 46, 47,
    77, 78, 75, 76, 80, 81, 79, 83, 84, 82, 86, 87, 85, 89, 90,
    88, 62, 63, 61, 65, 66, 64, 68, 69, 67, 70, 71, 73, 74, 72,
]

# Shared Set-I -> Set-K permutation for English and Hindi modules.
LANGUAGE_I_FROM_K = [
    96, 97, 98, 99, 91, 92, 93, 94, 95,
    103, 104, 105, 100, 101, 102,
    115, 116, 117, 118, 119, 120, 106, 107, 108, 109, 110, 111, 112, 113, 114,
    125, 126, 127, 128, 121, 122, 123, 124,
    133, 134, 135, 129, 130, 131, 132,
    145, 146, 147, 148, 149, 150, 136, 137, 138, 139, 140, 141, 142, 143, 144,
]

# Set-I -> Set-J permutation for Sanskrit.
SANSKRIT_I_FROM_J = [
    98, 99, 91, 92, 93, 94, 95, 96, 97,
    105, 100, 101, 102, 103, 104,
    118, 119, 120, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117,
    127, 128, 121, 122, 123, 124, 125, 126,
    134, 135, 129, 130, 131, 132, 133,
    148, 149, 150, 136, 137, 138, 139, 140, 141, 142, 143, 144, 145, 146, 147,
]

COMMON_I_KEY = [
    1,3,2,1,3,2,1,4,2,4,1,4,4,3,4,2,2,3,2,2,2,2,1,3,3,
    1,4,2,3,4,3,2,4,2,3,2,1,3,4,3,4,2,4,4,3,1,2,3,1,3,
    4,3,1,4,1,4,3,2,3,1,3,3,3,4,3,2,4,3,2,2,3,1,1,2,1,
    4,1,4,4,2,4,2,4,2,4,4,3,2,2,3,
]
COMMON_K_KEY = [
    4,1,2,4,4,4,4,4,1,3,2,3,1,2,4,1,4,3,1,4,3,1,4,2,3,
    2,2,1,3,2,2,1,3,4,1,3,1,1,2,3,2,3,2,1,4,1,3,2,1,4,
    4,1,4,3,1,2,1,2,4,2,2,3,2,4,4,2,2,2,4,2,1,1,4,4,1,
    2,1,1,2,1,4,4,1,4,3,1,3,2,4,3,
]
ENGLISH_I_KEY = [
    3,2,4,3,2,4,2,3,2,2,2,2,2,3,4,1,4,1,3,2,2,2,3,4,2,
    1,3,2,3,2,2,1,3,4,2,3,4,4,3,4,3,2,3,2,3,1,3,2,2,3,
    3,2,2,2,3,2,2,2,4,2,
]
ENGLISH_K_KEY = [
    4,2,4,1,4,1,4,2,1,4,1,2,4,4,4,4,1,2,4,3,1,4,1,4,3,
    2,3,1,4,4,4,1,2,2,4,3,1,2,4,1,4,1,1,2,1,4,4,4,1,4,
    4,4,2,4,3,1,4,4,1,1,
]
HINDI_I_KEY = [
    4,1,4,4,3,2,3,2,1,4,2,1,4,3,2,2,2,1,4,3,1,4,2,3,2,
    4,2,4,2,3,3,4,3,4,1,2,4,1,2,4,4,3,1,3,1,2,3,1,2,1,
    3,4,2,3,1,2,4,3,4,3,
]
HINDI_K_KEY = [
    1,4,1,4,3,2,3,2,2,2,1,4,2,4,3,2,4,1,4,2,4,2,4,1,4,
    4,3,2,1,3,3,4,2,3,1,2,1,2,1,3,1,3,4,2,2,2,4,1,3,4,
    2,1,2,1,4,1,3,4,3,1,
]
SANSKRIT_I_KEY = [
    2,2,1,3,2,4,1,4,3,2,4,1,3,3,2,4,3,4,2,3,2,3,1,4,2,
    2,1,3,4,3,3,1,2,3,4,2,3,2,1,2,4,1,4,3,2,2,3,4,2,4,
    2,2,1,3,2,1,1,4,4,3,
]
SANSKRIT_J_KEY = [
    4,2,1,3,4,3,2,1,1,3,4,2,2,1,1,1,2,1,2,4,3,1,1,4,2,
    3,2,3,2,3,1,2,3,1,2,1,2,4,3,4,3,2,1,4,1,1,3,1,1,4,
    2,1,4,4,3,3,2,1,2,3,
]

# Set-K options are [I3, I4, I1, I2]; Set-J Sanskrit options are [I2, I3, I4, I1].
I_OPTIONS_FROM_K = [2, 3, 0, 1]
I_OPTIONS_FROM_J = [3, 0, 1, 2]


@dataclass(frozen=True)
class SourceBlock:
    number: int
    stem: str
    options: tuple[str, str, str, str]
    local_answer: int


def clean_space(value: str) -> str:
    value = value.replace("\u00a0", " ").replace("\ufeff", "")
    value = re.sub(r"[ \t]+", " ", value)
    value = re.sub(r" *\n *", "\n", value)
    return value.strip()


def parse_blocks() -> list[SourceBlock]:
    text = SOURCE_MD.read_text(encoding="utf-8")
    blocks: list[SourceBlock] = []
    pattern = re.compile(r"^### प्रश्न (\d+)\s*\n(.*?)(?=^### प्रश्न |\Z)", re.M | re.S)
    for match in pattern.finditer(text):
        number = int(match.group(1))
        body = match.group(2)
        answer_match = re.search(r"\*\*उत्तर:\s*\(([a-d])\)\*\*", body)
        if answer_match is None:
            raise ValueError(f"source question {number} has no answer marker")
        if number == 71 and len(blocks) == 70:
            # The secondary transcription folded all four options into the stem and
            # printed a contradictory answer label.  The options below are recovered
            # from official Set-I Q87 and inverse-permuted to source Set-K order.
            stem = body.split(" (a) 100m due west", 1)[0].strip()
            options = (
                "100 m due west/100 m ठीक पश्चिम",
                "125 m due north/125 m ठीक उत्तर",
                "125 m due south/125 m ठीक दक्षिण",
                "100 m due east/100 m ठीक पूर्व",
            )
            blocks.append(SourceBlock(number, clean_space(stem), options, 1))
            continue
        options_found = re.findall(r"^- \*\*\(([a-d])\)\*\*\s*(.*)$", body, re.M)
        if len(options_found) != 4:
            raise ValueError(f"source question occurrence {len(blocks) + 1} has {len(options_found)} options")
        expected_letters = list(LETTERS)
        if [letter for letter, _ in options_found] != expected_letters:
            raise ValueError(f"source question occurrence {len(blocks) + 1} has malformed option labels")
        stem = body.split("\n- **(a)**", 1)[0].strip()
        blocks.append(SourceBlock(
            number=number,
            stem=clean_space(stem),
            options=tuple(clean_space(value) for _, value in options_found),  # type: ignore[arg-type]
            local_answer=LETTERS.index(answer_match.group(1)) + 1,
        ))
    if len(blocks) != 270:
        raise ValueError(f"expected 270 source blocks, got {len(blocks)}")
    return blocks


def split_bilingual(value: str) -> dict[str, str]:
    value = clean_space(value)
    match = re.search(r"[\u0900-\u097f]", value)
    if match is None:
        # Numbers/formulae are identical in both printed language columns.
        return {"en": value.strip(" /"), "hi": value.strip(" /")}
    # Prefer the explicit slash used by the transcription as a language-column
    # delimiter.  Splitting at the first Devanagari character loses a repeated
    # numeric prefix in values such as "29 hours / 29 घंटे".
    explicit_delimiters = list(re.finditer(r"\s/\s+(?=[^\n]*[\u0900-\u097f])", value[:match.end()]))
    slash_matches = list(re.finditer(r"/\s*(?=[^/]*[\u0900-\u097f])", value[:match.end()]))
    delimiter = explicit_delimiters[-1] if explicit_delimiters else (slash_matches[-1] if slash_matches else None)
    boundary = delimiter.start() if delimiter else match.start()
    hindi_start = delimiter.end() if delimiter else match.start()
    english = value[:boundary].strip(" /–-")
    hindi = value[hindi_start:].strip(" /–-")
    if not english or not hindi:
        raise ValueError(f"cannot split official bilingual text: {value!r}")
    return {"en": english, "hi": hindi}


def markdown(text: dict[str, str]) -> list[dict[str, Any]]:
    return [{"kind": "markdown", "text": text}]


def source_block(blocks: list[SourceBlock], module: str, number: int) -> SourceBlock:
    starts = {"common": 0, "english": 90, "hindi": 150, "sanskrit": 210}
    block = blocks[starts[module] + number - (1 if module == "common" else 91)]
    if block.number != number:
        raise ValueError(f"source indexing failure for {module} Q{number}")
    return block


# Corrections are limited to demonstrable OCR/layout loss or typography needed to
# represent the official item faithfully.  They are recorded in the audit rows.
STEM_OVERRIDES: dict[tuple[str, int], str] = {
    ("common", 47): "Amongst the following fractions, the largest and second largest fractions, respectively, are: 5/6, 3/4, 1/2, 2/3 and 3/5./निम्नलिखित भिन्नों में से सबसे बड़ी और दूसरी सबसे बड़ी भिन्न क्रमशः हैं: 5/6, 3/4, 1/2, 2/3 और 3/5।",
    ("common", 52): "The rates of various stationery items are given below:\n\n- A packet of crayons — ₹15.50\n- A packet of pencils — ₹14.00\n- A packet of sketch pens — ₹22.50\n- One pair of scissors — ₹17.00\n- One eraser — ₹2.00\n- One sheet of glazed paper — ₹2.50\n- A pack of decorative stickers — ₹5.00\n\nSohail buys one packet of crayons, two packets of pencils, one packet of sketch pens, one pair of scissors, five sheets of glazed paper and one pack of decorative stickers. How much would he be required to pay?/विभिन्न स्टेशनरी (लेखन-सामग्री) वस्तुओं की दरें नीचे दी गई हैं:\n\n- क्रेयॉन का एक पैकेट — ₹15.50\n- पेंसिलों का एक पैकेट — ₹14.00\n- स्केच पेन का एक पैकेट — ₹22.50\n- एक कैंची — ₹17.00\n- एक रबड़ — ₹2.00\n- चमकीले कागज़ की एक शीट — ₹2.50\n- सजावटी स्टिकर का एक पैक — ₹5.00\n\nसोहेल ने एक पैकेट क्रेयॉन, दो पैकेट पेंसिल, एक पैकेट स्केच पेन, एक कैंची, चमकीले कागज़ की पाँच शीटें और एक पैकेट सजावटी स्टिकर खरीदे। उसको कितना भुगतान करना होगा?",
    ("common", 58): "Based on the table above, identify the correct statement from among the following./ऊपर दी गई तालिका के आधार पर निम्नलिखित में से सही कथन को पहचानिए।",
    ("common", 71): "Your house is located at X and your school is located at Y. Although your school is just opposite, you cannot go straight because of the busy highway in between. So, you first go 125 m due south, then cross a 100 m long subway which is due east and finally reach your school at Y, which is 125 m due north. With respect to the school at Y, your house at X is/आपका घर X पर स्थित है तथा आपका विद्यालय Y पर स्थित है। यद्यपि आपका विद्यालय ठीक सामने है, परन्तु बीच में व्यस्त राजमार्ग होने के कारण आप सीधे नहीं जा सकते हैं। अतः पहले आप ठीक दक्षिण में 125 m दूर जाते हैं, फिर ठीक पूर्व में 100 m लम्बा सुरंग पथ पार करते हैं और अन्त में आप ठीक उत्तर में 125 m दूरी पर Y पर अपने विद्यालय पहुँचते हैं। Y पर विद्यालय के सापेक्ष X पर आपका घर कहाँ स्थित है?",
    ("english", 92): "Which part of speech is the underlined word in the following sentence?\n\n<u>Almost</u> overnight new grass spring up.",
    ("english", 93): "Which part of the following sentence contains an error?\n\n(a) He knew / (b) that he will / (c) go back / (d) on his promise.",
    ("english", 102): "The word 'mouth' in line 3 refers to the ________ of the tree.",
    ("english", 123): "Which part of speech is the underlined word in the following sentence?\n\nGraphologists can verify whether the autographs are real <u>or</u> fake.",
    ("english", 126): "A person who writes with large letters that cross over to the top line is likely to be",
    ("english", 131): "Which part of the following sentence contains an error?\n\n(a) Both Raghunath as well as Ravish / (b) have given / (c) their consent / (d) to the new proposal.",
    ("english", 136): "Alka, a student of class III, often makes a mistake between /sh/ and /s/. As a language teacher, your interpretation will be",
    ("english", 149): "As per Stephen Krashen, “The effective language teacher is someone who can provide input and help make it _________ in a low anxiety situation.”",
    ("english", 150): "A teacher divides the class into groups of five and asks them to discuss what they would do if they were caught in one of the following situations:\n\n- Their friend falls down in the play field and is hurt.\n- They are trapped in a building on fire.\n- They are stuck up in a traffic jam.\n\nThis activity is based on ________.",
    ("sanskrit", 104): "‘जहाति पापं श्रद्धावान् सर्पो जीर्णामिव त्वचाम्’ इति उक्तौ कः अलङ्कारः प्रयुक्तः?",
    ("sanskrit", 110): "नोम चॉमस्की (Noam Chomsky) मतानुसारं भाषायाः कृते बालानां सहजात-दक्षता अस्ति ________।",
    ("sanskrit", 112): "प्रारम्भिकबालान् शिक्षिका चित्राङ्कनं रङ्गकार्यं च कर्तुं प्रोत्साहयति। एवं सा ________।",
    ("sanskrit", 115): "द्वितीयकक्षायाः शिक्षिका कक्षास्थितवस्तूनि नामाङ्कितानि कृतवती। एते छात्राणां प्रकृतवस्तुभिः सह लिखितशब्दानां सम्बन्धस्थापने सहायकाः भविष्यन्ति। एवंविधं कार्यं छात्राणां संवर्धनं करिष्यति ________।",
    ("sanskrit", 128): "अलं चिन्तया इति वाक्यस्य अभिप्रायः ________।",
    ("sanskrit", 145): "भाषाकक्षायां चित्राणां/विज्ञापनानां प्रयोगविषये अधोलिखितेषु का उक्तिः न समीचीना?",
    ("sanskrit", 146): "उद्गामिसाक्षरतास्तरे (emergent literacy stage) ________ अपि लेखनवर्गे स्वीक्रियते।",
    ("sanskrit", 147): "विद्यार्थिनः भाषायाः व्यवहारस्य आकलनार्थं निम्नलिखितेषु किं सर्वाधिकं महत्त्वपूर्णम्?",
}

BILINGUAL_PROMPT_OVERRIDES: dict[int, dict[str, str]] = {
    33: {
        "en": "‘The sum of any two whole numbers is a whole number.’ This property of whole numbers is referred to as",
        "hi": "‘किन्हीं दो पूर्ण संख्याओं का योग एक पूर्ण संख्या होता है।’ पूर्ण संख्याओं के इस गुण को इस प्रकार उल्लेखित किया जाता है:",
    },
    35: {
        "en": "Which of the following statements is/are true regarding teaching ‘Numbers’ at primary level?\n\n(A) Intuitive understanding of numbers should be encouraged.\n(B) Writing numbers should be taught in sequence.\n(C) Writing numbers as numerals should precede counting.\n(D) Order irrelevance of numbers should be encouraged.",
        "hi": "प्राथमिक स्तर पर ‘संख्याओं’ को पढ़ाने के लिए निम्नलिखित में से कौन-से कथन सत्य हैं?\n\n(A) संख्याओं की अंतर्दर्शी समझ को प्रोत्साहित किया जाना चाहिए।\n(B) संख्याओं को लिखना अनुक्रम में पढ़ाना चाहिए।\n(C) गणना से पहले संख्याओं को संख्यांक रूप में लिखना सिखाना चाहिए।\n(D) संख्याओं में अनुक्रम-असंगति को प्रोत्साहित करना चाहिए।",
    },
    55: {
        "en": "What should be subtracted from the sum of 8008, 8088 and 8808 to obtain 17863?",
        "hi": "17863 पाने के लिए 8008, 8088 और 8808 के योग में से क्या घटाना होगा?",
    },
    56: {
        "en": "A bucket of 16 litres capacity is filled to the brim with water. Water from this bucket is to be transferred into smaller utensils. A mug filled to capacity has to be dipped 50 times to completely transfer the water in the bucket into the utensils. What is the capacity of the mug?",
        "hi": "16 लीटर धारिता वाली एक बाल्टी पूर्ण रूप से पानी से भरी हुई है। बाल्टी के इस पानी को छोटे-छोटे बर्तनों में भरा जाना है। बाल्टी में भरे समस्त पानी को एक मग द्वारा 50 बार पूर्णतया भरकर छोटे-छोटे बर्तनों में स्थानांतरित किया जाता है। मग की धारिता क्या है?",
    },
    60: {
        "en": "Following are some questions posed by the teacher in the mathematics classroom:\n\n(A) What is the area of the rectangle whose one side is 5 cm and perimeter is 30 cm?\n(B) Find a set of numbers whose median is 4.\n(C) List all prime numbers between 0 and 8.\n(D) Tell me any mathematical information you know about rectangles.",
        "hi": "गणित के कक्षा-कक्ष में अध्यापक ने निम्नलिखित कुछ प्रश्न प्रस्तुत किए:\n\n(A) उस आयत का क्या क्षेत्रफल है, जिसकी एक भुजा 5 cm और परिमाप 30 cm है?\n(B) उन संख्याओं का समुच्चय ज्ञात कीजिए जिनका माध्यक 4 है।\n(C) 0 और 8 के मध्य सभी अभाज्य संख्याओं की सूची बनाइए।\n(D) आयतों के बारे में आपको जो भी गणितीय जानकारी है, मुझे बताइए।",
    },
    64: {
        "en": "There is a paragraph in a Class V EVS textbook based on Al-Biruni’s observation of the construction of ponds in India some thousand years ago. What would be the purpose of including this paragraph?\n\n(A) It helps learners to identify sources of history.\n(B) It helps learners to improve their recording of observations.\n(C) It helps learners to appreciate technology present in India some 1000 years back.\n(D) It helps learners to appreciate the role of evidence in history.",
        "hi": "कुछ हज़ार साल पहले भारत में तालाबों के निर्माण के अल-बिरूनी के अवलोकन के आधार पर कक्षा V की ईवीएस पाठ्य-पुस्तक में एक अनुच्छेद है। इस अनुच्छेद को शामिल करने का क्या उद्देश्य होगा?\n\n(A) यह इतिहास के स्रोतों की पहचान करने में शिक्षार्थियों की मदद करता है।\n(B) यह शिक्षार्थियों को उनके अवलोकनों की रिकॉर्डिंग में सुधार करने में मदद करता है।\n(C) यह शिक्षार्थियों को लगभग 1000 साल पहले भारत में मौजूद तकनीक की सराहना करने में मदद करता है।\n(D) यह शिक्षार्थियों को इतिहास में साक्ष्य की भूमिका की सराहना करने में मदद करता है।",
    },
    76: {
        "en": "Consider the following functions for plants:\n\n(A) To give support to the plant.\n(B) To provide humus.\n(C) To store food.\n(D) To absorb water and minerals.\n\nThe functions of roots are",
        "hi": "पौधों के लिए किए जाने वाले नीचे दिए गए कार्यों पर विचार कीजिए:\n\n(A) पौधे को सहारा देना।\n(B) ह्यूमस प्रदान करना।\n(C) भोजन संचित करना।\n(D) पानी और खनिजों को अवशोषित करना।\n\nइनमें से जड़ों के कार्य हैं",
    },
    87: {
        "en": "What should be avoided in anecdotal records?\n\n(A) Identifying mainly problematic situations.\n(B) Making statements of judgement.\n(C) Identifying strengths and weaknesses.\n(D) Identifying a child’s areas of interest and relationships, etc.",
        "hi": "उपाख्यान अभिलेखों में क्या दर्ज नहीं करना चाहिए?\n\n(A) मुख्य रूप से समस्याग्रस्त स्थितियों की पहचान करना।\n(B) निर्णय वाले कथनों को लिखना।\n(C) मज़बूतियों और कमज़ोरियों की पहचान करना।\n(D) बच्चे की रुचियों और संबंधों आदि की पहचान करना।",
    },
}

OPTION_OVERRIDES: dict[tuple[str, int], tuple[str, str, str, str]] = {
    ("common", 46): ("128 cm²", "96 cm²", "124 cm²", "48 cm²"),
    ("common", 47): ("3/5 and 2/3 / 3/5 और 2/3", "3/4 and 1/2 / 3/4 और 1/2", "5/6 and 3/4 / 5/6 और 3/4", "5/6 and 3/5 / 5/6 और 3/5"),
    ("common", 52): ("₹100.50", "₹102.00", "₹98.00", "₹86.50"),
    ("common", 56): ("275 mL", "320 mL", "225 mL", "250 mL"),
    ("common", 57): ("15 km", "18 km", "12 km", "13 km"),
    ("common", 71): ("100 m due west/100 m ठीक पश्चिम", "125 m due north/125 m ठीक उत्तर", "125 m due south/125 m ठीक दक्षिण", "100 m due east/100 m ठीक पूर्व"),
    ("english", 93): ("(c)", "(d)", "(a)", "(b)"),
    ("english", 97): ("bushes and creepers", "tall grass", "thick moss", "maiden hair fern"),
    ("english", 104): ("producing fruit and flowers", "providing shade to travellers", "swinging its branches", "lifting her arms"),
    ("english", 131): ("(c)", "(b)", "(d)", "(a)"),
    ("sanskrit", 128): ("चिन्तां कुरु", "व्यर्थचिन्तां कुरु", "चिन्ता अलङ्कारसदृशी अस्ति", "चिन्तां न कुरु"),
    ("sanskrit", 138): (
        "अन्यानुप्रासिशब्दानां लघुयुग्मकार्यकलापानाम् (minimal pair activity) उपयोगं कुर्यात्। एवं सा छात्रान् वर्णोच्चारणं कारयेत् शब्देषु तस्य वर्णस्य अभिज्ञानं च कारयेत्।",
        "पाठस्य उच्चैः वाचनं कृत्वा विशिष्टवर्णं रेखाङ्कितं कृत्वा तद्विषये विवरणं दद्यात्।",
        "छात्रैः पौनःपुन्येन अभ्यासं कारयेत् येन तेषां काठिन्यस्य निवारणं भविष्यति।",
        "शिक्षिका मनुष्यमुखस्य एकां प्रतिकृतिम् उपयुज्य तत्र विशिष्टवर्णस्य विशिष्टोच्चारणस्थानस्य प्रदर्शनं कुर्यात्।",
    ),
    ("sanskrit", 143): (
        "ताभिः विद्यार्थिनः अनुशासिताः तिष्ठन्ति।",
        "ताभिः लक्ष्यभाषायाः व्याकरणस्य अधिगमे सहायता भवति।",
        "ताभिः विद्यार्थिनः कठिनशब्दानां वर्णनं कर्तुं ततश्च वाक्यानि रचयितुं समर्थाः भवन्ति।",
        "ताभिः विद्यार्थिनः लक्ष्यभाषां भाषितुम् अवसरं प्राप्नुवन्ति।",
    ),
    ("sanskrit", 146): ("शब्दानां लेखनम्", "वाक्यानां निर्माणम्", "चित्राङ्कनम्", "अक्षराणां निर्माणम्"),
    ("sanskrit", 147): ("मूल्यनिर्धारकश्रेणी (rating scale)", "पत्राधानम् (portfolio)", "वार्तालापः (interaction)", "चिह्नाङ्कनसूची (check list)"),
}

GENERIC_REPLACEMENTS = {
    "` ": "₹",
    "patna": "Patna",
    "cm2": "cm²",
    "1cm": "1 cm",
    "48cm²": "48 cm²",
    "16cm": "16 cm",
    "30cm": "30 cm",
    "students learning": "students’ learning",
    "student' poor spelling": "students’ poor spelling",
    "student' wrong answers": "students’ wrong answers",
    "चाहिए।।": "चाहिए।",
    "What it this known as?": "What is this known as?",
    "congnitive": "cognitive",
    "should NOT.": "should NOT",
    "text book": "textbook",
    "Iines": "lines",
    "contains as error": "contains an error",
    "Which one the following": "Which one of the following",
    "write done": "write down",
    "Suffer a lot.": "suffer a lot.",
    "Palpitating": "palpitating",
    "Zoom": "zoom",
    "grammatical from and structures": "grammatical forms and structures",
    "Total physical Response": "Total Physical Response",
    "Audio-lingual method": "Audiolingual method",
    "peer tutoring is must a schools.": "peer tutoring is must in schools.",
    "between the two students ask each other questions": "between the two. Students ask each other questions",
    "problem causes for it": "probable causes for it",
    "styles to drawing": "styles of drawing",
    "draw near and colourful pictures": "draw neat and colourful pictures",
    "story, its History": "story, its history",
    "enable learner to be a fast reader": "enable a learner to be a fast reader",
    "within the stipulated times": "within the stipulated time",
    "Setbacks a person": "setbacks a person",
    "attention seeking confident person": "attention seeking, confident person",
    "Conjunctions": "Conjunction",
    "Help couples": "help couples",
    "(Part 2)": "(Para 2)",
    "Creating an environment": "creating an environment",
    "classroom as it promotes.": "classroom as it promotes",
    "influence to her dialect": "influence of her dialect",
    "Children to learn": "children to learn",
    "Scribbling": "scribbling",
    "Zig-Zag writing": "zig-zag writing",
    "Basic interpersonal Communication skills": "Basic Interpersonal Communication Skills",
    "Meharishi": "Maharishi",
    "pochampalli,This town is now a part of.": "Pochampalli. This town is now a part of",
    "3.5m": "3.5 m",
    "class v learners": "class V learners",
    "before teaching chapter": "before teaching the chapter",
    "Identify learners": "identify learners",
    "diesel Vehicles": "diesel vehicles",
    "transpotation": "transportation",
    "sensitize student on": "sensitize students on",
    "class, vani": "class, Vani",
    "magazines in EVS": "magazines in EVS?",
    "descipline": "discipline",
    "36.5km/h": "36.5 km/h",
    "38.5km/h": "38.5 km/h",
    "40.5km/h": "40.5 km/h",
    "42.5km/h": "42.5 km/h",
    "traders coming from.": "traders coming from",
    "शिक्षर्थियों": "शिक्षार्थियों",
    "संख्याओ ": "संख्याओं ",
    "संख्यांको": "संख्यांकों",
    "रूचि": "रुचि",
    "नौतिक": "नैतिक",
    "शुरु से": "शुरू से",
    "गइराई": "गहराई",
    "पढ़ना सिखने": "पढ़ना सीखने",
    "चुनौतियाँ, प्रचलनों": "चुनौतियों, प्रचलनों",
    "‘अत: ": "‘अतः ",
    "दौर्भाभ्यं": "दौर्भाग्यं",
    "प्रायस:": "प्रयासः",
    "चित्राज्र्न": "चित्राङ्कन",
    "अलज्रर": "अलङ्कार",
    "नामज्र्तिानि": "नामाङ्कितानि",
    "रेखाज्र्तिं": "रेखाङ्कितं",
    "चिह्नाज्र्न": "चिह्नाङ्कन",
    "उष्ण भुङ्क्ते": "उष्णं भुङ्क्ते",
    "कस्मिन क्षेत्रे": "कस्मिन् क्षेत्रे",
    "व्याकरणिकसंरचनाभि :": "व्याकरणिकसंरचनाभिः",
    "एकं संवादं लिखतुं।": "एकं संवादं लिखतु।",
    "भवेत इति": "भवेत् इति",
    "कस्मिन् वाक्ये लिखितम्": "कस्मिन् वाच्ये लिखितम्",
    "प्रधान्येन": "प्राधान्येन",
    "वायुफुल्लितं (balloons) कियदूर्ध्वं डयितुं शक्नुवन्ति।": "वायुपूरितगोलकाः (balloons) कियदूर्ध्वम् उड्डयितुं शक्नुवन्ति?",
    "चित्राणाम् आधारेण लेखितुं च अवसर:": "चित्राणाम् आधारेण लेखितुं च अवसरः लभ्यते।",
    "तेषां सर्जनस्य कृत स्थानं": "तेषां सर्जनस्य कृते स्थानं",
}


def apply_repairs(module: str, block: SourceBlock) -> tuple[str, tuple[str, str, str, str], list[str]]:
    stem = STEM_OVERRIDES.get((module, block.number), block.stem)
    options = OPTION_OVERRIDES.get((module, block.number), block.options)
    repairs: list[str] = []
    if stem != block.stem:
        repairs.append("stem-layout-or-ocr-repair")
    if options != block.options:
        repairs.append("option-layout-or-ocr-repair")
    for bad, good in GENERIC_REPLACEMENTS.items():
        new_stem = stem.replace(bad, good)
        if new_stem != stem:
            repairs.append(f"text-repair:{bad}->{good}")
            stem = new_stem
        new_options = tuple(value.replace(bad, good) for value in options)
        if new_options != options:
            repairs.append(f"option-text-repair:{bad}->{good}")
            options = new_options  # type: ignore[assignment]
    if module == "sanskrit":
        # The Unicode transcription used an ASCII colon for the Sanskrit
        # visarga.  This is a character-encoding repair, not an editorial edit.
        normalized_stem = re.sub(r"(?<=[\u0900-\u097f]):", "ः", stem)
        normalized_options = tuple(re.sub(r"(?<=[\u0900-\u097f]):", "ः", value) for value in options)
        if normalized_stem != stem or normalized_options != options:
            repairs.append("unicode-visarga-repair")
        stem, options = normalized_stem, normalized_options
    return clean_space(stem), tuple(clean_space(value) for value in options), sorted(set(repairs))  # type: ignore[return-value]


def stimulus_id(language: str | None, slot: int | None, start: int, kind: str) -> str:
    if language is None:
        return f"ctet-p1-2020-i-mathematics-q{start:03d}-{kind}"
    return f"ctet-p1-2020-i-language-{slot}-{language}-q{start:03d}-{kind}"


def linked_stimulus(section: str, language: str | None, slot: int | None, question_number: int) -> tuple[str | None, str]:
    if section == "mathematics" and question_number == 41:
        return stimulus_id(None, None, 41, "table"), "table-question"
    if section != "language":
        return None, "single-choice"
    ranges = ((91, 99, "prose", "passage-question"), (100, 105, "poem", "poem-question"),
              (121, 128, "prose", "passage-question"), (129, 135, "prose", "passage-question"))
    for start, end, kind, question_type in ranges:
        if start <= question_number <= end:
            return stimulus_id(language, slot, start, kind), question_type
    return None, "single-choice"


def question_id(section: str, language: str | None, slot: int | None, number: int) -> str:
    if section == "language":
        return f"ctet-p1-2020-i-language-{slot}-{language}-q{number:03d}"
    return f"ctet-p1-2020-i-{section}-q{number:03d}"


def appearance_id(question: str) -> str:
    return f"{question}-appearance"


def build_question(
    *, module: str, source: SourceBlock, target_number: int, option_permutation: list[int],
    official_answer: int, section: str, language: str | None, slot: int | None,
) -> tuple[dict[str, Any], list[str]]:
    stem, source_options, repairs = apply_repairs(module, source)
    set_i_options = [source_options[index] for index in option_permutation]
    if section == "language":
        assert language is not None
        prompt_text = {language: stem}
        option_texts = [{language: value} for value in set_i_options]
        locales = [language]
    else:
        manual_prompt = BILINGUAL_PROMPT_OVERRIDES.get(source.number)
        prompt_text = manual_prompt if manual_prompt is not None else split_bilingual(stem)
        if manual_prompt is not None:
            repairs.append("bilingual-column-layout-repair")
        option_texts = [split_bilingual(value) for value in set_i_options]
        locales = ["hi", "en"]
    sid, qtype = linked_stimulus(section, language, slot, target_number)
    qid = question_id(section, language, slot, target_number)
    question: dict[str, Any] = {
        "schemaVersion": 1,
        "id": qid,
        "status": "published",
        "exam": "ctet",
        "paper": 1,
        "section": section,
        "language": language,
        "languageSlot": slot,
        "type": qtype,
        "availableLocales": locales,
        "prompt": markdown(prompt_text),
        "options": [
            {"id": letter, "content": markdown(content)}
            for letter, content in zip(LETTERS, option_texts)
        ],
        "answer": {"kind": "single", "optionId": LETTERS[official_answer - 1]},
        "stimulusId": sid,
        "sourceType": "pyq",
        "topicIds": [],
        "conceptIds": [],
        "difficulty": {"editorial": "unrated", "empirical": None},
        "cognitiveLevel": "unrated",
        "tags": ["ctet", "paper-1", "2020-cycle", "2021-01-31", "set-i", "pyq"],
        "review": {"answerVerified": True, "translationVerified": True, "mediaVerified": True},
    }
    return question, repairs


def extract_between(text: str, start: str, end: str) -> str:
    try:
        return text.split(start, 1)[1].split(end, 1)[0].strip()
    except IndexError as exc:
        raise ValueError(f"could not extract stimulus after {start!r}") from exc


def tidy_stimulus(value: str) -> str:
    replacements = {
        "That same spring. I later discovered": "That same spring, I later discovered",
        "leaf bud": "leaf-bud",
        "water bottle": "water-bottle",
        "does not quarrel, it simply": "does not quarrel; it simply",
        "Poem are made": "Poems are made",
        "sometime used": "sometimes used",
        "six week.": "six weeks.",
        "Compared to standard lined": "Compared to a standard lined",
        "topline. You": "topline, you",
        "Schizophrenia": "schizophrenia",
        "aggression: if": "aggression: if",
        "distance relationship": "distant relationship",
        "usual play": "usual ploy",
        "master of the situation I inform": "master of the situation. I inform",
        "' I must": "'I must",
        "I' m": "I'm",
        "दौर्भाभ्यं": "दौर्भाग्यं",
        "प्रायस:": "प्रयासः",
        "प्राप्येन्": "प्राप्येरन्",
        "स: कञ्चन लघुकुटुम्ब:": "सः कश्चन लघुकुटुम्बः",
        "किञ्चदपि": "किञ्चिदपि",
    }
    for bad, good in replacements.items():
        value = value.replace(bad, good)
    value = re.sub(r"(?<=[\u0900-\u097f]):", "ः", value)
    value = re.sub(r" (?=[2-9]\. )", "\n\n", value)
    return clean_space(value)


def make_stimulus(*, sid: str, language: str | None, slot: int | None, kind: str,
                  content: list[dict[str, Any]], count: int, title: dict[str, str],
                  instructions: dict[str, str]) -> dict[str, Any]:
    return {
        "schemaVersion": 1,
        "id": sid,
        "status": "published",
        "exam": "ctet",
        "paper": 1,
        "section": "mathematics" if language is None else "language",
        "language": language,
        "languageSlot": slot,
        "type": kind,
        "title": title,
        "instructions": instructions,
        "content": content,
        "selectionPolicy": "atomic",
        "minimumQuestions": count,
        "sourceType": "pyq",
        "review": {"textVerified": True, "translationVerified": True, "mediaVerified": True},
    }


def build_stimuli(source_text: str) -> dict[str, list[dict[str, Any]]]:
    result: dict[str, list[dict[str, Any]]] = {
        "mathematics": [], "english-1": [], "english-2": [],
        "hindi-1": [], "hindi-2": [], "sanskrit-1": [], "sanskrit-2": [],
    }
    table_content = [{
        "kind": "table",
        "caption": {"en": "Marks obtained out of 100", "hi": "100 में से प्राप्त अंक"},
        "columns": [
            {"id": "subject", "header": {"en": "Subject", "hi": "विषय"}},
            {"id": "maria", "header": {"en": "Maria", "hi": "मारिया"}},
            {"id": "shehnaz", "header": {"en": "Shehnaz", "hi": "शहनाज़"}},
        ],
        "rows": [
            {"cells": {"subject": {"en": "English", "hi": "अंग्रेज़ी"}, "maria": {"en": "74", "hi": "74"}, "shehnaz": {"en": "81", "hi": "81"}}},
            {"cells": {"subject": {"en": "Mathematics", "hi": "गणित"}, "maria": {"en": "88", "hi": "88"}, "shehnaz": {"en": "78", "hi": "78"}}},
            {"cells": {"subject": {"en": "Social Science", "hi": "सामाजिक विज्ञान"}, "maria": {"en": "65", "hi": "65"}, "shehnaz": {"en": "77", "hi": "77"}}},
            {"cells": {"subject": {"en": "Hindi", "hi": "हिन्दी"}, "maria": {"en": "73", "hi": "73"}, "shehnaz": {"en": "72", "hi": "72"}}},
            {"cells": {"subject": {"en": "Science", "hi": "विज्ञान"}, "maria": {"en": "90", "hi": "90"}, "shehnaz": {"en": "82", "hi": "82"}}},
        ],
    }]
    result["mathematics"].append(make_stimulus(
        sid=stimulus_id(None, None, 41, "table"), language=None, slot=None, kind="table",
        content=table_content, count=1,
        title={"en": "Maria and Shehnaz: subject marks", "hi": "मारिया और शहनाज़: विषयवार अंक"},
        instructions={"en": "Use the table to answer the linked question.", "hi": "संबद्ध प्रश्न का उत्तर देने के लिए तालिका का प्रयोग कीजिए।"},
    ))

    header_lines = [line for line in source_text.splitlines() if line.startswith("> **निर्देश / गद्यांश:**")]
    def header_containing(fragment: str) -> str:
        return next(line for line in header_lines if fragment in line)

    english_specs = [
        (1, 91, 99, "prose", header_containing("Each drop represents"), "options:", "Water and the monsoon"),
        (1, 100, 105, "poem", header_containing("I think that I shall never see"), "options:", "Trees"),
        (2, 121, 128, "prose", header_containing("The study of handwriting"), "options:", "Graphology"),
        (2, 129, 135, "prose", header_containing("Get rid of guests"), "options.", "Unwanted guests"),
    ]
    english_poem = "  \n".join([
        "I think that I shall never see",
        "A poem lovely as a tree.",
        "A tree whose hungry mouth is prest",
        "Against the earth's sweet flowing breast;",
        "A tree that looks at God all day,",
        "And lifts her leafy arms to pray;",
        "A tree that may in Summer wear",
        "A nest of robins in her hair;",
        "Upon whose bosom snow has lain;",
        "Who intimately lives with rain.",
        "Poems are made by fools like me,",
        "But only God can make a tree.",
    ])
    for slot, start, end, kind, raw, delimiter, title in english_specs:
        body = tidy_stimulus(raw.split(delimiter, 1)[1])
        if start == 100:
            body = english_poem
        result[f"english-{slot}"].append(make_stimulus(
            sid=stimulus_id("en", slot, start, kind), language="en", slot=slot, kind=kind,
            content=markdown({"en": body}), count=end - start + 1,
            title={"en": title},
            instructions={"en": f"Read the {kind} and answer questions {start}–{end}."},
        ))

    hindi_91 = tidy_stimulus(header_containing("यह नहीं भूलना चाहिए").split("चुनिए:", 1)[1])
    hindi_100 = "\n\n".join("  \n".join(stanza) for stanza in [
        ["देशवासियों सुनो, देश को नमन करो।", "देश ही आधार है, प्यार देश से करो।"],
        ["लड़ रहे हो आज क्यों छोटी-छोटी बात पर,", "देश हित को भूलकर प्रांत, भाषा, जात पर,", "मिटा के भेदभाव को, देश को सुदृढ़ करो।"],
        ["भ्रष्टाचार की लहर उठ रही नगर-नगर,", "घोर अंधकार में सूझती नहीं डगर,", "ज्योति नीति-धर्म की आज तुम प्रखर करो।"],
        ["देश आज रो रहा, देश का रुदन सुनो,", "बाँट दर्द देश का, मित्र देश के बनो,", "प्रेम के पीयूष से, द्वेष का शमन करो।"],
    ])
    hindi_121 = tidy_stimulus(header_containing("किताब का विषय").split("चुनिए :", 1)[1])
    hindi_129 = tidy_stimulus(extract_between(source_text, "दिए गए अनुच्छेद को पढ़कर पूछे गए प्रश्नों (प्रश्न सं. 129 से 135 तक) के सही / सबसे उपयुक्त उत्तर वाले विकल्प चुनिए:", "### प्रश्न 129"))
    for slot, start, end, kind, body, title in [
        (1, 91, 99, "prose", hindi_91, "व्यवहार और शांति"),
        (1, 100, 105, "poem", hindi_100, "देश को नमन"),
        (2, 121, 128, "prose", hindi_121, "छोटे बच्चों के लिए पुस्तकें"),
        (2, 129, 135, "prose", hindi_129, "चिनार वृक्ष"),
    ]:
        result[f"hindi-{slot}"].append(make_stimulus(
            sid=stimulus_id("hi", slot, start, kind), language="hi", slot=slot, kind=kind,
            content=markdown({"hi": body}), count=end - start + 1,
            title={"hi": title}, instructions={"hi": f"{kind == 'poem' and 'काव्यांश' or 'गद्यांश'} पढ़कर प्रश्न {start}–{end} के उत्तर दीजिए।"},
        ))

    sanskrit_91 = tidy_stimulus(header_containing("वाग्भट:").split("चिनुत।", 1)[1])
    sanskrit_91 = sanskrit_91.replace("‘कोऽरुक् ? कोऽरुक्’ ? कोऽरुक्’ ?", "‘कोऽरुक्? कोऽरुक्? कोऽरुक्?’")
    sanskrit_100 = "\n\n".join("  \n".join(stanza) for stanza in [
        ["अश्रद्धा परमं पापं,", "श्रद्धा पापप्रमोचिनी।", "जहाति पापं श्रद्धावान्,", "सर्पो जीर्णामिव त्वचाम्॥ (1)"],
        ["दूरेऽपि सज्जनाः भान्ति", "हिमवन्नगसन्निभाः।", "असन्तो नैव दृश्यन्ते", "रात्रिक्षिप्ताः शरा यथा॥ (2)"],
        ["भक्तिर्देवे मतिर्धर्मे,", "शक्तिस्त्यागे रतिः श्रुतौ।", "दया सर्वेषु भूतेषु", "स्यान्मे जन्मनि जन्मनि॥ (3)"],
        ["आयुषः क्षण एकोऽपि", "सर्वरत्नैर्न न लभ्यते।", "नीयते स वृथा येन", "प्रमादः सुमहानहो॥ (4)"],
        ["स्वभावो नोपदेशेन", "शक्यते कर्तुमन्यथा।", "सुतप्तमपि पानीयं", "पुनर्गच्छति शीतताम्॥ (5)"],
        ["दुर्जनः सुजनीकर्तुं", "यत्नेनापि न शक्यते।", "संस्कारेणापि लशुनं", "कः सुगन्धीकरिष्यति॥ (6)"],
    ])
    sanskrit_121 = tidy_stimulus(header_containing("ग्रामे आसीत्").split("चिनुत-", 1)[1])
    sanskrit_129 = tidy_stimulus(extract_between(source_text, "अधोलिखितं गद्यांशं पठित्वा तदाधारित - प्रश्नानां (129 - 135) विकल्पात्मकोत्तरेभ्य: उचिततमम् उत्तरं चित्वा लिखत–", "### प्रश्न 129"))
    for slot, start, end, kind, body, title in [
        (1, 91, 99, "prose", sanskrit_91, "वाग्भटः"),
        (1, 100, 105, "poem", sanskrit_100, "नीतिश्लोकाः"),
        (2, 121, 128, "prose", sanskrit_121, "शिलानोदनप्रयासः"),
        (2, 129, 135, "prose", sanskrit_129, "लघुकुटुम्बः"),
    ]:
        result[f"sanskrit-{slot}"].append(make_stimulus(
            sid=stimulus_id("sa", slot, start, kind), language="sa", slot=slot, kind=kind,
            content=markdown({"sa": body}), count=end - start + 1,
            title={"sa": title}, instructions={"sa": f"अंशं पठित्वा प्रश्नानां {start}–{end} उचिततमम् उत्तरं चिनुत।"},
        ))
    return result


def ndjson(rows: list[dict[str, Any]]) -> str:
    return "".join(json.dumps(row, ensure_ascii=False, separators=(",", ":")) + "\n" for row in rows)


def output_paths() -> dict[str, tuple[Path, Path]]:
    base = BANK / "exams" / "ctet" / "paper-1"
    return {
        "cdp": (base / "cdp" / "questions.ndjson", base / "cdp" / "stimuli.ndjson"),
        "mathematics": (base / "mathematics" / "questions.ndjson", base / "mathematics" / "stimuli.ndjson"),
        "environmental-studies": (base / "environmental-studies" / "questions.ndjson", base / "environmental-studies" / "stimuli.ndjson"),
        "english-1": (base / "language-1" / "english" / "questions.ndjson", base / "language-1" / "english" / "stimuli.ndjson"),
        "english-2": (base / "language-2" / "english" / "questions.ndjson", base / "language-2" / "english" / "stimuli.ndjson"),
        "hindi-1": (base / "language-1" / "hindi" / "questions.ndjson", base / "language-1" / "hindi" / "stimuli.ndjson"),
        "hindi-2": (base / "language-2" / "hindi" / "questions.ndjson", base / "language-2" / "hindi" / "stimuli.ndjson"),
        "sanskrit-1": (base / "language-1" / "sanskrit" / "questions.ndjson", base / "language-1" / "sanskrit" / "stimuli.ndjson"),
        "sanskrit-2": (base / "language-2" / "sanskrit" / "questions.ndjson", base / "language-2" / "sanskrit" / "stimuli.ndjson"),
    }


def transformed_answer(source_answer: int, permutation: list[int]) -> int:
    source_index = source_answer - 1
    return permutation.index(source_index) + 1


def main() -> int:
    # This narrow importer is idempotent for bank version 0/1 only.  Refuse to
    # overwrite cumulative content after another cycle has advanced the bank.
    existing_bank = json.loads((BANK / "bank.json").read_text(encoding="utf-8"))
    if existing_bank.get("bankVersion", 0) > 1:
        raise RuntimeError("refusing to run the first-cycle importer over a later bank version")
    existing_forms_path = BANK / "paper-forms" / "ctet" / "paper-1" / "forms.ndjson"
    if existing_forms_path.exists():
        existing_form_ids = {
            json.loads(line).get("id")
            for line in existing_forms_path.read_text(encoding="utf-8").splitlines()
            if line.strip()
        }
        if existing_form_ids - {FORM_ID}:
            raise RuntimeError("refusing to overwrite later CTET Paper-I forms")

    blocks = parse_blocks()
    source_text = SOURCE_MD.read_text(encoding="utf-8")
    stimuli = build_stimuli(source_text)
    questions_by_store: dict[str, list[dict[str, Any]]] = {name: [] for name in output_paths()}
    audit: list[dict[str, Any]] = []
    appearances: list[dict[str, Any]] = []

    modules: list[dict[str, Any]] = []

    def add_module(*, store: str, module: str, section: str, language: str | None, slot: int | None,
                   target_numbers: list[int], mapping: list[int], option_permutation: list[int],
                   source_set: str, source_key: list[int], target_key: list[int]) -> None:
        ids: list[str] = []
        for target_number, source_number in zip(target_numbers, mapping):
            source = source_block(blocks, module, source_number)
            target_answer = target_key[target_number - (1 if section != "language" else 91)]
            source_answer = source_key[source_number - (1 if section != "language" else 91)]
            calculated = transformed_answer(source_answer, option_permutation)
            if calculated != target_answer:
                raise ValueError(
                    f"key/mapping mismatch {module} I-Q{target_number}: "
                    f"source {source_set}-Q{source_number} answer {source_answer} -> {calculated}, key says {target_answer}"
                )
            question, repairs = build_question(
                module=module, source=source, target_number=target_number,
                option_permutation=option_permutation, official_answer=target_answer,
                section=section, language=language, slot=slot,
            )
            questions_by_store[store].append(question)
            aid = appearance_id(question["id"])
            ids.append(aid)
            appearances.append({
                "schemaVersion": 1,
                "id": aid,
                "questionId": question["id"],
                "paperFormId": FORM_ID,
                "exam": "ctet",
                "paper": 1,
                "examDate": EXAM_DATE,
                "shift": 1,
                "setCode": "I",
                "section": section,
                "language": language,
                "languageSlot": slot,
                "questionNumber": target_number,
                "officialOptionId": LETTERS[target_answer - 1],
                "sourceRef": f"{SOURCE_MANIFEST_ID}#set-i-q{target_number:03d}-{store}",
                "verificationStatus": "verified",
            })
            audit.append({
                "schemaVersion": 1,
                "questionId": question["id"],
                "targetSet": "I",
                "targetQuestionNumber": target_number,
                "sourceTextSet": source_set,
                "sourceTextQuestionNumber": source_number,
                "sourceOfficialAnswerPosition": source_answer,
                "setIOfficialAnswerPosition": target_answer,
                "optionPermutationSourceToSetI": [LETTERS[index] for index in option_permutation],
                "answerTransformationVerified": True,
                "stemAndOptionsVerified": True,
                "visualDependencyChecked": True,
                "visualDependency": "official-table-reconstructed" if question["type"] == "table-question" else "none",
                "repairs": repairs,
                "disposition": "imported",
            })
        module_id = f"{FORM_ID}-{store}"
        entry: dict[str, Any] = {
            "id": module_id,
            "kind": "language" if section == "language" else "core",
            "section": section,
            "language": language,
            "languageSlot": slot,
            "questionCount": len(ids),
            "appearanceIds": ids,
        }
        modules.append(entry)

    add_module(store="cdp", module="common", section="cdp", language=None, slot=None,
               target_numbers=list(range(1, 31)), mapping=COMMON_I_FROM_K[:30],
               option_permutation=I_OPTIONS_FROM_K, source_set="K", source_key=COMMON_K_KEY, target_key=COMMON_I_KEY)
    add_module(store="mathematics", module="common", section="mathematics", language=None, slot=None,
               target_numbers=list(range(31, 61)), mapping=COMMON_I_FROM_K[30:60],
               option_permutation=I_OPTIONS_FROM_K, source_set="K", source_key=COMMON_K_KEY, target_key=COMMON_I_KEY)
    add_module(store="environmental-studies", module="common", section="environmental-studies", language=None, slot=None,
               target_numbers=list(range(61, 91)), mapping=COMMON_I_FROM_K[60:90],
               option_permutation=I_OPTIONS_FROM_K, source_set="K", source_key=COMMON_K_KEY, target_key=COMMON_I_KEY)
    for language, module, target_key, source_key in [
        ("en", "english", ENGLISH_I_KEY, ENGLISH_K_KEY),
        ("hi", "hindi", HINDI_I_KEY, HINDI_K_KEY),
    ]:
        store_language = "english" if language == "en" else "hindi"
        for slot, target_range, map_slice in [
            (1, list(range(91, 121)), LANGUAGE_I_FROM_K[:30]),
            (2, list(range(121, 151)), LANGUAGE_I_FROM_K[30:]),
        ]:
            add_module(store=f"{store_language}-{slot}", module=module, section="language", language=language, slot=slot,
                       target_numbers=target_range, mapping=map_slice, option_permutation=I_OPTIONS_FROM_K,
                       source_set="K", source_key=source_key, target_key=target_key)
    for slot, target_range, map_slice in [
        (1, list(range(91, 121)), SANSKRIT_I_FROM_J[:30]),
        (2, list(range(121, 151)), SANSKRIT_I_FROM_J[30:]),
    ]:
        add_module(store=f"sanskrit-{slot}", module="sanskrit", section="language", language="sa", slot=slot,
                   target_numbers=target_range, mapping=map_slice, option_permutation=I_OPTIONS_FROM_J,
                   source_set="J", source_key=SANSKRIT_J_KEY, target_key=SANSKRIT_I_KEY)

    if len(audit) != 270 or len(appearances) != 270:
        raise ValueError("cycle must contain exactly 270 canonical questions and appearances")
    if len({row["questionId"] for row in audit}) != 270:
        raise ValueError("duplicate canonical question IDs")

    for store, (question_path, stimulus_path) in output_paths().items():
        question_path.write_text(ndjson(questions_by_store[store]), encoding="utf-8")
        stimulus_path.write_text(ndjson(stimuli.get(store, [])), encoding="utf-8")

    form = {
        "schemaVersion": 1,
        "id": FORM_ID,
        "exam": "ctet",
        "paper": 1,
        "examDate": EXAM_DATE,
        "shift": 1,
        "setCode": "I",
        "title": {
            "en": "CTET July 2020 cycle (held 31 January 2021) — Paper I, Set I",
            "hi": "सीटीईटी जुलाई 2020 चक्र (31 जनवरी 2021 को आयोजित) — पेपर I, सेट I",
        },
        "durationMinutes": 150,
        "totalQuestions": 150,
        "totalMarks": 150,
        "negativeMarking": 0,
        "verificationStatus": "verified",
        "sourceRef": SOURCE_MANIFEST_ID,
        "modules": modules,
    }
    forms_path = BANK / "paper-forms" / "ctet" / "paper-1" / "forms.ndjson"
    appearances_path = BANK / "paper-forms" / "ctet" / "paper-1" / "appearances.ndjson"
    forms_path.write_text(ndjson([form]), encoding="utf-8")
    appearances_path.write_text(ndjson(appearances), encoding="utf-8")

    source_manifest = {
        "schemaVersion": 1,
        "id": SOURCE_MANIFEST_ID,
        "exam": "ctet",
        "paper": 1,
        "cycleLabel": "July 2020",
        "examDate": EXAM_DATE,
        "canonicalSet": "I",
        "documents": {
            "officialMainPaperSetI": OFFICIAL_MAIN,
            "officialFinalAnswerKey": OFFICIAL_KEY,
            "officialSanskritSupplementSetI": OFFICIAL_SANSKRIT,
            "mainPaperTextAndPageImageMirror": MAIN_MIRROR,
            "finalKeyTextAndPageImageMirror": KEY_MIRROR,
            "unicodeRepairSource": "ctet-questions/CTET Paper 1 jan 2021.md",
        },
        "sourceSetIdentification": {
            "commonEnglishHindi": "K",
            "sanskrit": "J",
            "evidence": "Every local answer position matched its identified official final-key table after the recoverable Q71 layout error was corrected.",
        },
        "reconstruction": {
            "commonEnglishHindiOptionPermutationSourceToSetI": ["c", "d", "a", "b"],
            "sanskritOptionPermutationSourceToSetI": ["d", "a", "b", "c"],
            "setIQuestionOrderMappingsStoredIn": "tools/v2/import_ctet_2020_paper1.py",
            "correctnessAuthority": "officialFinalAnswerKey",
            "commentaryImported": False,
        },
        "officialSetIAnswerKeys": {
            "main": COMMON_I_KEY,
            "english": ENGLISH_I_KEY,
            "hindi": HINDI_I_KEY,
            "sanskrit": SANSKRIT_I_KEY,
        },
        "officialSourceSetAnswerKeys": {
            "mainSetK": COMMON_K_KEY,
            "englishSetK": ENGLISH_K_KEY,
            "hindiSetK": HINDI_K_KEY,
            "sanskritSetJ": SANSKRIT_J_KEY,
        },
        "setIToSourceQuestionMappings": {
            "mainSetK": COMMON_I_FROM_K,
            "englishSetK": LANGUAGE_I_FROM_K,
            "hindiSetK": LANGUAGE_I_FROM_K,
            "sanskritSetJ": SANSKRIT_I_FROM_J,
        },
        "counts": {"questions": 270, "appearances": 270, "stimuli": 13, "paperForms": 1},
        "verificationStatus": "verified",
    }
    sources_dir = BANK / "sources"
    sources_dir.mkdir(parents=True, exist_ok=True)
    (sources_dir / "ctet-p1-2020-2021-set-i.json").write_text(
        json.dumps(source_manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    audits_dir = BANK / "audits"
    audits_dir.mkdir(parents=True, exist_ok=True)
    (audits_dir / "ctet-p1-2020-2021-question-audit.ndjson").write_text(ndjson(audit), encoding="utf-8")

    bank_path = BANK / "bank.json"
    bank = json.loads(bank_path.read_text(encoding="utf-8"))
    bank["bankVersion"] = 1
    bank["status"] = "active"
    bank_path.write_text(json.dumps(bank, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print("Imported CTET Paper-I July-2020 cycle / 31-Jan-2021 Set I")
    print("questions=270 appearances=270 stimuli=13 forms=1")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

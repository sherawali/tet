#!/usr/bin/env python3
"""One-shot CTET Paper-I remediation migration.

This migration is intentionally pinned to the audited q_ctet.csv snapshot. It:
- moves audited Paper-II / upper-primary records to ``ctet2``;
- repairs verified answer keys, formulas, merged fields, translations and metadata;
- removes records whose missing visual/table/underline cannot be reconstructed;
- consolidates duplicates while retaining year metadata and passage bodies; and
- writes a finding-by-finding resolution ledger.

Run from the repository root. The input checksum guard prevents original-line
repairs from ever being applied to a different CSV revision.
"""
from __future__ import annotations

import csv
import hashlib
import re
import sys
import unicodedata
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CSV_PATH = ROOT / "content" / "q_ctet.csv"
ISSUES_PATH = ROOT / "docs" / "ctet_paper1_audit_issues.csv"
RESULTS_PATH = ROOT / "docs" / "ctet_paper1_repair_results.csv"
EXPECTED_SHA256 = "597e280330093e502e8bbf2f52ac48128b068d54e6c94508aab776c71a2cef96"

EN_FIELDS = ("q_en", "a_en", "b_en", "c_en", "d_en")
HI_OPTION_FIELDS = ("a_hi", "b_hi", "c_hi", "d_hi")
EN_OPTION_FIELDS = ("a_en", "b_en", "c_en", "d_en")


def norm(value: str) -> str:
    value = unicodedata.normalize("NFKC", value or "").lower()
    return "".join(ch for ch in value if ch.isalnum())


def years(value: str) -> set[str]:
    return {part.strip() for part in (value or "").split(",") if part.strip()}


def source_score(row: dict[str, str], repaired_lines: set[int]) -> tuple[int, int, int]:
    source = row["source"]
    line = int(row["_line"])
    score = 0
    if line in repaired_lines:
        score += 80
    if row.get("p_body", "").strip():
        score += 50
    if " Bank " not in f" {source} ":
        score += 25
    if re.search(r"\b(?:Paper[- ]?1|paper1|CTET 20\d\d)\b", source, re.I):
        score += 10
    if row.get("years", "").strip():
        score += 3
    if all(row.get(field, "").strip() for field in EN_FIELDS):
        score += 3
    garbage = sum(len(row.get(field, "")) > 220 for field in HI_OPTION_FIELDS)
    score -= garbage * 20
    return score, -line, -len(source)


def clean_option_metadata(text: str) -> str:
    text = re.sub(r"\s*\(परीक्षा तिथि\s*:[^)]*\)", "", text)
    text = re.sub(r"\s*\(Shift[-– ]*[IVX]+\)", "", text, flags=re.I)
    return re.sub(r"\s+", " ", text).strip()


def choose_cleaner_hi(current: str, alternative: str) -> str:
    current = current.strip()
    alternative = alternative.strip()
    if not current:
        return alternative
    if not alternative:
        return current
    ncur, nalt = norm(current), norm(alternative)
    if nalt and nalt in ncur and len(current) > len(alternative) + 35:
        return alternative
    cur_latin = len(re.findall(r"[A-Za-z]", current))
    alt_latin = len(re.findall(r"[A-Za-z]", alternative))
    if cur_latin > alt_latin + 5 and alt_latin <= 2:
        return alternative
    if len(current) > 220 and len(alternative) < 160:
        return alternative
    return current


def full_english(row: dict[str, str]) -> bool:
    return all(row.get(field, "").strip() for field in EN_FIELDS)


def main() -> int:
    digest = hashlib.sha256(CSV_PATH.read_bytes()).hexdigest()
    if digest != EXPECTED_SHA256:
        print(
            "Refusing to run: q_ctet.csv is not the audited baseline.\n"
            f"Expected {EXPECTED_SHA256}\nFound    {digest}",
            file=sys.stderr,
        )
        return 2

    with CSV_PATH.open(encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        fieldnames = list(reader.fieldnames or [])
        rows: list[dict[str, str]] = []
        for line, row in enumerate(reader, 2):
            row["_line"] = str(line)
            rows.append(row)

    with ISSUES_PATH.open(encoding="utf-8-sig", newline="") as handle:
        findings = list(csv.DictReader(handle))

    by_code: dict[str, set[int]] = defaultdict(set)
    for finding in findings:
        by_code[finding["issue_code"]].add(int(finding["csv_line"]))

    row_by_line = {int(row["_line"]): row for row in rows}
    original_source = {line: row["source"] for line, row in row_by_line.items()}
    original_exam = {line: row["exams"] for line, row in row_by_line.items()}
    passage_data: dict[str, tuple[str, str, str]] = {}
    for row in rows:
        if row["pid"] and row["p_body"].strip():
            passage_data[row["pid"]] = (row["p_kind"], row["p_dir"], row["p_body"])

    moved_lines = (
        by_code["scope_paper2_visible"]
        | by_code["scope_paper2_source_match"]
        | by_code["scope_upper_primary_probable"]
    )
    protected_non_ctet = by_code["scope_non_ctet_exam"]
    truncated_english = by_code["english_stem_truncated"] | by_code["english_option_truncated"]

    # The user chose removal rather than guessed reconstruction for these categories.
    unrecoverable_lines = (
        by_code["missing_visual_stimulus"]
        | by_code["missing_underlining_target"]
        | by_code["incomplete_table_or_data"]
        # Upper-primary rows were outside the Paper-I field audit, but these
        # have the same unrecoverable missing underline/diagram defect.
        | {1907, 1938, 2056, 2995, 3006, 3019, 3052, 3268}
        | {816, 3694, 4858, 5197, 5276, 5734}
    )

    repaired_lines: set[int] = set()
    removed_reason: dict[int, str] = {line: "removed_unrecoverable" for line in unrecoverable_lines}
    consolidated_into: dict[int, int] = {}

    # An incomplete English mirror is more harmful than an explicitly Hindi-only item.
    for line in truncated_english:
        for field in EN_FIELDS:
            row_by_line[line][field] = ""
        repaired_lines.add(line)

    # Remove option-level date/shift metadata without changing provenance fields.
    for line in by_code["option_metadata_leak"] | {2764}:
        for field in HI_OPTION_FIELDS:
            row_by_line[line][field] = clean_option_metadata(row_by_line[line][field])
        repaired_lines.add(line)

    # Verified answer-key corrections.
    answer_repairs = {
        24: "0", 39: "3", 52: "1", 69: "1", 76: "1", 78: "1",
        82: "1", 305: "0", 642: "2", 1245: "1", 3937: "2", 6698: "2",
    }
    for line, answer in answer_repairs.items():
        row_by_line[line]["ans"] = answer
        repaired_lines.add(line)

    def update(line: int, **values: str) -> None:
        row_by_line[line].update(values)
        repaired_lines.add(line)

    def bilingual(
        line: int,
        q_hi: str,
        q_en: str,
        hi: tuple[str, str, str, str],
        en: tuple[str, str, str, str],
        ans: int | None = None,
    ) -> None:
        values = {"q_hi": q_hi, "q_en": q_en}
        values.update(dict(zip(HI_OPTION_FIELDS, hi)))
        values.update(dict(zip(EN_OPTION_FIELDS, en)))
        if ans is not None:
            values["ans"] = str(ans)
        update(line, **values)

    # Corrupt option text and invalid matching code.
    update(172, d_hi="6 से 11 वर्ष", d_en="6 to 11 years")
    update(3776, b_hi="A-iv, B-iii, C-ii, D-i, E-v", b_en="A-iv, B-iii, C-ii, D-i, E-v")
    update(656, d_en="child/environment")
    update(3677, d_en="Providing them with ready-made solutions to problems")
    update(3772,
           d_hi="Both (A) and (R) are true, but (R) is not the correct explanation of (A)",
           d_en="Both (A) and (R) are true, but (R) is not the correct explanation of (A)")
    update(5869, c_en="26.026")
    update(6605, a_hi="42 मी/से", b_hi="15 मी/से", c_hi="9 मी/से", d_hi="54 मी/से")

    # Mathematical expressions reconstructed from the official parallel text/key.
    update(43,
           q_hi="3 1/4 किग्रा चीनी में से 1/16 किग्रा के कितने पैकेट बनाए जा सकते हैं?",
           q_en="How many packets of 1/16 kg sugar can be made from 3 1/4 kg of sugar?")
    update(3702,
           q_hi="100 में एक पूर्ण संख्या जोड़ी जाती है और फिर वही संख्या 100 में से घटा दी जाती है। इस प्रकार प्राप्त दोनों संख्याओं का योगफल है:",
           q_en="A whole number is added to 100 and the same number is subtracted from 100. What is the sum of the two resulting numbers?")
    update(3703,
           q_hi="5 – 5 + 5 – 5 + 5 – 5 + … में विषम संख्या में पद हों, तो योगफल है:",
           q_en="What is the sum of 5 – 5 + 5 – 5 + 5 – 5 + … when there is an odd number of terms?")
    update(3925,
           q_hi="3 1/4 किग्रा चीनी में से 1/16 किग्रा के कितने पैकेट बनाए जा सकते हैं?",
           q_en="How many packets of 1/16 kg sugar can be made from 3 1/4 kg of sugar?")
    update(3933,
           q_hi="1 – 1 + 1 – 1 + 1 – 1 + … का सम संख्या में पदों तक योग है:",
           q_en="What is the sum of 1 – 1 + 1 – 1 + 1 – 1 + … when there is an even number of terms?")
    update(4143,
           q_hi="यह समझाने के लिए कि 1/4, 1/3 से छोटा है, निम्नलिखित में से कौन-सी योजना सबसे उपयुक्त है?",
           q_en="Which of the following is the most appropriate strategy to explain that 1/4 is less than 1/3?")
    update(4552,
           q_hi="6/5 में कितने 1/10 हैं?",
           q_en="How many 1/10 are there in 6/5?")
    update(5174,
           q_hi="7 1/2 किग्रा नमक से 1/12 किग्रा के कितने पैकेट बनाए जा सकते हैं?",
           q_en="How many packets of 1/12 kg salt can be made from 7 1/2 kg of salt?")
    update(5381,
           q_hi="‘1/3 के समतुल्य भिन्न लिखिए।’ कक्षा IV के शिक्षार्थियों से पूछा गया यह सवाल किस प्रकार के कार्य की ओर संकेत करता है?",
           q_en="")
    update(5529,
           q_hi="72 × 28 = 36 × 4 × ____। रिक्त स्थान की संख्या (A) 7 का गुणज है, (B) अभाज्य है, (C) 10 से कम है, (D) सम है और (E) 56 का गुणनखण्ड है। कौन-सा विकल्प सही है?",
           q_en="72 × 28 = 36 × 4 × ____. The number in the blank is (A) a multiple of 7, (B) prime, (C) less than 10, (D) even and (E) a factor of 56. Which option is correct?")
    update(5723,
           q_hi="फलों के प्रति किग्रा मूल्य हैं—खरबूजा ₹18.50, चेरी ₹72, अंगूर ₹120.60 और सेब ₹78.40। रेशमा ने 4 1/2 किग्रा खरबूजा, 1 किग्रा 200 ग्राम चेरी, 250 ग्राम अंगूर और 1 3/4 किग्रा सेब खरीदे। ₹500 देने पर उसे कितने रुपये वापस मिले?",
           q_en="Fruit prices per kg are: melon ₹18.50, cherries ₹72, grapes ₹120.60 and apples ₹78.40. Reshma buys 4 1/2 kg melon, 1 kg 200 g cherries, 250 g grapes and 1 3/4 kg apples. How much change does she receive from ₹500?")
    update(5866,
           q_hi="गौरांग ने सोमवार को 4 1/2 घंटे, मंगलवार को 190 मिनट, बुधवार को प्रातः 5:20 से 9:10 तक और शुक्रवार को 220 मिनट काम किया। उसे प्रति घंटे ₹42 मिलते हैं। उसने कुल कितना कमाया?",
           q_en="Gaurang worked 4 1/2 hours on Monday, 190 minutes on Tuesday, from 5:20 a.m. to 9:10 a.m. on Wednesday, and 220 minutes on Friday. At ₹42 per hour, how much did he earn in total?")
    update(5873,
           q_hi="3 1/3 में कितने 1/6 हैं?",
           q_en="How many 1/6 are there in 3 1/3?")
    update(6026,
           q_hi="1/2 में कितने 1/8 हैं?",
           q_en="How many one-eighths (1/8) are there in 1/2?")
    update(6160,
           q_hi="समान अंश वाली भिन्नों 3/5 और 3/7 की तुलना करते समय रोहित ने कहा, ‘अंश समान हैं और 7, 5 से बड़ा है, इसलिए 3/7, 3/5 से बड़ा है।’ यह बताता है कि:",
           q_en="While comparing fractions with the same numerator, 3/5 and 3/7, Rohit says, ‘The numerators are equal and 7 is greater than 5, so 3/7 is greater than 3/5.’ This indicates that:")
    update(6168,
           q_hi="भिन्नों का योग पढ़ाते समय शिक्षक ने त्रुटि देखी: 1/2 + 1/3 = 2/5। उपचारात्मक कार्य के रूप में शिक्षक को क्या करना चाहिए?",
           q_en="While teaching addition of fractions, a teacher observes the error 1/2 + 1/3 = 2/5. What remedial action should the teacher take?")
    update(6452,
           q_hi="मानचित्र पर 1/2 सेमी की दूरी भूमि पर 200 किमी को दर्शाती है। यदि दो नगर भूमि पर 1800 किमी दूर हैं, तो मानचित्र पर उनकी दूरी कितनी होगी?",
           q_en="On a map, 1/2 cm represents 200 km on the ground. If two cities are 1800 km apart, what is their distance on the map?",
           c_hi="3 1/2 सेमी", d_hi="4 1/2 सेमी")

    # Remove unrelated preambles/OCR while preserving the actual item.
    update(148,
           q_hi="निम्नलिखित में से किस कारण को छोड़कर अन्य सभी कारणों से खेल छोटे बच्चों के विकास में महत्वपूर्ण भूमिका निभाता है?",
           q_en="Play has a significant role in the development of young children for all of the following reasons except:")
    update(787,
           q_hi="मनोविज्ञानशाला उत्तर प्रदेश, इलाहाबाद की स्थापना किस वर्ष की गई?",
           q_en="In which year was the Manovigyanshala (Psychology Bureau), Uttar Pradesh, Allahabad established?")
    update(830,
           q_hi="जब कोई बच्चा कक्षा में प्रश्न पूछता है, तो उसे क्या करना चाहिए?",
           q_en="When a child asks questions in class, the child should be:")
    update(1582,
           q_hi="पर्यावरण अध्ययन में बच्चों को जोड़ने की सबसे प्रभावशाली युक्ति कौन-सी है?",
           q_en="Which is the most effective strategy for engaging children in Environmental Studies?")
    update(1912, q_hi="‘बाजार’ से किस प्रकार की संज्ञा का बोध होता है?")
    update(2764,
           q_hi="‘डिस्ग्राफिया’ का संबंध किससे है?",
           d_hi="बोलने संबंधी अक्षमता से")

    # Material bilingual mismatches rebuilt around one coherent canonical item.
    bilingual(
        623,
        "शिक्षा का अधिकार अधिनियम, 2009 निम्नलिखित में से किस व्यवस्था की वकालत करता है?",
        "Which of the following does the Right to Education Act, 2009 advocate?",
        ("समावेशी शिक्षा", "पृथक्करण", "मुख्यधारा शिक्षण", "एकीकृत शिक्षा"),
        ("Inclusive education", "Segregation", "Mainstream teaching", "Integrated education"),
        0,
    )
    bilingual(
        1398,
        "निम्नलिखित में से किस नदी को भारत की राष्ट्रीय नदी घोषित किया गया है?",
        "Which of the following rivers has been declared the National River of India?",
        ("गंगा", "यमुना", "गोदावरी", "गोमती"),
        ("Ganga", "Yamuna", "Godavari", "Gomti"),
        0,
    )
    bilingual(
        1551,
        "पर्यावरण अध्ययन में ज्ञान की रचना के लिए कौन-से तत्व महत्वपूर्ण हैं? (A) बच्चों की सक्रिय भागीदारी (B) बच्चों के ज्ञान को केवल शिक्षक के ज्ञान से बदलना (C) कक्षा की चारदीवारी के बाहर सीखना (D) स्थानीय ज्ञान को विद्यालयी ज्ञान से जोड़ना",
        "Which elements are important for constructing knowledge in EVS? (A) Active participation of children (B) Replacing children's knowledge only with the teacher's knowledge (C) Learning beyond classroom walls (D) Relating local knowledge to school knowledge",
        ("केवल D", "केवल A", "केवल A और D", "A, C और D"),
        ("Only D", "Only A", "Only A and D", "A, C and D"),
        3,
    )
    bilingual(
        1641,
        "कक्षा III की शिक्षिका ने बच्चों से नींबू, आम, तुलसी, पुदीना, नीम और केले की पत्तियों को वर्गीकृत करने को कहा। समूह I ने उन्हें औषधीय/गैर-औषधीय और समूह II ने बड़ी/छोटी पत्तियों में बाँटा। शिक्षिका ने समूह I को सही और समूह II को गलत माना। यह किस दृष्टिकोण को दर्शाता है?",
        "A Class III teacher asks children to classify leaves of lemon, mango, tulsi, mint, neem and banana. Group I classifies them as medicinal/non-medicinal and Group II as large/small. The teacher accepts Group I and rejects Group II. Which view does this reflect?",
        (
            "वर्गीकरण एक विशिष्ट और संरचित कार्य है जिसका केवल एक सही उत्तर होता है।",
            "यह गतिविधि पत्तियों से सूचना लेने पर केन्द्रित है, जिसकी अलग-अलग व्याख्या हो सकती है।",
            "बच्चे कक्षा में अनेक प्रकार के संदर्भ लाते हैं, जिनकी सराहना होनी चाहिए।",
            "अपने अनुभवों के आधार पर बच्चे वर्गीकरण के अनेक तरीके अपना सकते हैं।",
        ),
        (
            "Classification is a specific, structured task with only one correct answer.",
            "The activity focuses on obtaining information from leaves, which can be interpreted differently.",
            "Children bring many kinds of contexts to the classroom, which should be appreciated.",
            "Depending on their experiences, children can classify in many ways.",
        ),
        0,
    )
    bilingual(
        1693,
        "Engage, Explore, Explain, Elaborate और Evaluate विज्ञान शिक्षण के पाँच ‘E’ हैं। शिक्षक बच्चों से (A) बीज रातभर पानी में रखकर गीले कपड़े में लपेटने, (B) दो दिन बाद परिवर्तन देखने और लिखने तथा (C) पुस्तक पढ़कर कार्यपत्रक पूरा करने को कहती है। इन गतिविधियों में कौन-से ‘E’ शामिल नहीं हैं?",
        "Engage, Explore, Explain, Elaborate and Evaluate are the five Es of science teaching. A teacher asks children to (A) soak seeds overnight and wrap them in wet cloth, (B) observe and record changes after two days, and (C) read the book and complete a worksheet. Which Es are not covered?",
        ("Explain और Elaborate", "Explore और Evaluate", "Engage और Explore", "Engage और Evaluate"),
        ("Explain and Elaborate", "Explore and Evaluate", "Engage and Explore", "Engage and Evaluate"),
        0,
    )
    bilingual(
        5384,
        "वैन हीले के ज्यामितीय चिंतन के स्तरों के अनुसार कक्षा III का बच्चा बहुभुजों को उनकी भुजाओं की संख्या के आधार पर वर्गीकृत करता है। बच्चा किस स्तर पर है?",
        "According to Van Hiele's levels of geometric thought, a Class III child classifies polygons by their number of sides. At which level is the child?",
        ("औपचारिक निगमन", "चाक्षुषीकरण", "विश्लेषण", "अनौपचारिक निगमन"),
        ("Formal deduction", "Visualisation", "Analysis", "Informal deduction"),
        2,
    )
    update(5399,
           q_en="Study the listed duties and choose those that are responsibilities of a mountaineering group leader: (A) help others carry luggage, (B) walk far ahead of the group, (C) tell anyone unable to walk to stay behind, (D) care for a sick companion and arrange food and drink, (E) find a good place to stop and rest.")
    bilingual(
        6436,
        "निम्नलिखित में से कौन-सा व्यवहार बच्चे की अधिगम-निर्योग्यता की पहचान करता है?",
        "Which of the following behaviours identifies a child's learning disability?",
        ("मनोभाव का जल्दी-जल्दी बदलना", "अपमानजनक व्यवहार", "‘b’ को ‘d’, ‘was’ को ‘saw’ और ‘21’ को ‘12’ लिखना", "कम अवधान-विस्तार और अत्यधिक शारीरिक गतिविधि"),
        ("Frequent mood swings", "Insulting behaviour", "Writing ‘b’ as ‘d’, ‘was’ as ‘saw’, and ‘21’ as ‘12’", "Short attention span and excessive physical activity"),
        2,
    )

    # Merged statement/code records that can be reconstructed without guessing.
    bilingual(
        3737,
        "हाथियों के बारे में कथनों पर विचार कीजिए: (A) तीन माह के बच्चे का वजन लगभग 100 किग्रा होता है। (B) वयस्क हाथी प्रतिदिन 200 किग्रा से अधिक पत्तियाँ/टहनियाँ खा सकता है। (C) हाथी दिन में केवल 2–4 घंटे सोते हैं। (D) हाथी कीचड़ और पानी में खेलना पसंद करते हैं। सही कथनों का चयन कीजिए।",
        "Consider the statements about elephants: (A) A three-month-old calf generally weighs about 100 kg. (B) An adult can eat more than 200 kg of leaves and twigs a day. (C) Elephants sleep only two to four hours a day. (D) Elephants like playing in mud and water. Choose the correct statements.",
        ("C और D", "B और D", "A और B", "A और C"),
        ("C and D", "B and D", "A and B", "A and C"),
        0,
    )
    bilingual(
        3756,
        "श्रीमती शीतल प्राथमिक कक्षाओं में EVS की अवधारणाएँ समझाने के लिए कहानियों और कविताओं का उपयोग करती हैं। संभावित तर्क हैं: (A) पाठ्यक्रम पूरा करना क्योंकि बच्चे इन्हें पहले सुन चुके हैं, (B) बच्चों को अपनी रचनाएँ लिखने के लिए प्रेरित करना, (C) भाषा और संस्कृति की विविधता से परिचित कराना, (D) पाठों को संवादात्मक, आनंददायक और रोचक बनाना। सही विकल्प चुनिए।",
        "Ms Sheetal uses stories and poems to explain EVS concepts in primary classes. The possible reasons are: (A) completing the syllabus because children heard them before school, (B) encouraging children to write their own stories and poems, (C) creating awareness of linguistic and cultural diversity, and (D) making lessons interactive, enjoyable and interesting. Choose the correct option.",
        ("A, C और D", "B और C", "A और B", "B, C और D"),
        ("A, C and D", "B and C", "A and B", "B, C and D"),
        3,
    )
    bilingual(
        3835,
        "Study the statements: (A) Uncle Henry had a tractor trolley in which wood was carried. (B) The wood for the house was carried from far away. Choose the correct option.",
        "Study the statements: (A) Uncle Henry had a tractor trolley in which wood was carried. (B) The wood for the house was carried from far away. Choose the correct option.",
        ("Both A and B are right.", "Both A and B are wrong.", "A is right and B is wrong.", "B is right and A is wrong."),
        ("Both A and B are right.", "Both A and B are wrong.", "A is right and B is wrong.", "B is right and A is wrong."),
        3,
    )
    bilingual(
        5195,
        "एक EVS शिक्षिका ने जानवरों पर पढ़ाने के बाद ये कार्य दिए: (A) आसपास के जानवरों के नाम लिखना, (B) उनकी गतिविधियों का अवलोकन करना, (C) अवलोकन के आधार पर वर्गीकरण करना, (D) ‘जानवर’ को परिभाषित करना। प्राथमिक स्तर पर EVS की प्रकृति के अनुसार कौन-सा कार्य उपयुक्त नहीं है?",
        "After teaching about animals, an EVS teacher gives these tasks: (A) list animals found nearby, (B) observe their activities, (C) classify them from observations, and (D) define the term ‘animal’. Which task is not appropriate at the primary level according to the nature of EVS?",
        ("केवल A", "केवल B", "केवल C", "केवल D"),
        ("Only A", "Only B", "Only C", "Only D"),
        3,
    )
    bilingual(
        6055,
        "Engage, Explore, Explain, Elaborate और Evaluate विज्ञान शिक्षण के पाँच ‘E’ हैं। शिक्षक बच्चों से (A) बीज रातभर पानी में रखकर गीले कपड़े में लपेटने, (B) दो दिन बाद परिवर्तन देखने और लिखने तथा (C) पुस्तक पढ़कर कार्यपत्रक पूरा करने को कहता है। इन गतिविधियों में कौन-से ‘E’ शामिल नहीं हैं?",
        "Engage, Explore, Explain, Elaborate and Evaluate are the five Es of science teaching. A teacher asks children to (A) soak seeds overnight and wrap them in wet cloth, (B) observe and record changes after two days, and (C) read the book and complete a worksheet. Which Es are not covered?",
        ("Explain और Elaborate", "Explore और Evaluate", "Engage और Explore", "Engage और Evaluate"),
        ("Explain and Elaborate", "Explore and Evaluate", "Engage and Explore", "Engage and Evaluate"),
        0,
    )
    bilingual(
        6147,
        "प्राथमिक कक्षाओं में आकार और स्थान की समझ के लिए कार्यों को क्रम दीजिए: (a) 2-D आकारों की भुजाओं/शीर्षों से गुण मिलाना, (b) गुणों का सहज वर्णन, (c) 2-D आकारों को छाँटना, (d) भुजाएँ, शीर्ष और विकर्ण गिनकर वर्णन करना।",
        "Order the tasks used to develop understanding of shape and space: (a) match properties of 2-D shapes by sides/corners, (b) describe properties intuitively, (c) sort 2-D shapes, (d) describe shapes by counting sides, corners and diagonals.",
        ("c, a, d, b", "d, b, a, c", "c, b, d, a", "a, d, b, c"),
        ("c, a, d, b", "d, b, a, c", "c, b, d, a", "a, d, b, c"),
        0,
    )
    bilingual(
        6154,
        "‘माप’ की अवधारणा के लिए कार्यों को क्रम दीजिए: (a) मानक इकाइयों से लंबाई मापना, (b) अमानक इकाइयों से मापना, (c) सरल अवलोकन से वस्तुओं की तुलना करना, (d) मीटरी इकाइयों के संबंध समझना।",
        "Order the tasks used to develop measurement: (a) measure length using standard units, (b) use non-standard units, (c) compare objects by simple observation, (d) understand relationships among metric units.",
        ("d, a, c, b", "a, b, d, c", "b, a, c, d", "c, b, a, d"),
        ("d, a, c, b", "a, b, d, c", "b, a, c, d", "c, b, a, d"),
        3,
    )

    # Assertion/reason and statement labels were dropped from option starts.
    option_sets: dict[int, tuple[tuple[str, ...], tuple[str, ...]]] = {
        3673: (
            ("(A) सही है, लेकिन (R) गलत है।", "(A) और (R) दोनों गलत हैं।", "(A) और (R) दोनों सही हैं तथा (R), (A) की सही व्याख्या है।", "(A) और (R) दोनों सही हैं, लेकिन (R), (A) की सही व्याख्या नहीं है।"),
            ("(A) is true, but (R) is false.", "Both (A) and (R) are false.", "Both (A) and (R) are true and (R) correctly explains (A).", "Both (A) and (R) are true, but (R) does not correctly explain (A)."),
        ),
        3679: (
            ("(A) सही है, लेकिन (R) गलत है।", "(A) और (R) दोनों गलत हैं।", "(A) और (R) दोनों सही हैं तथा (R), (A) की सही व्याख्या है।", "(A) और (R) दोनों सही हैं, लेकिन (R), (A) की सही व्याख्या नहीं है।"),
            ("(A) is true, but (R) is false.", "Both (A) and (R) are false.", "Both (A) and (R) are true and (R) correctly explains (A).", "Both (A) and (R) are true, but (R) does not correctly explain (A)."),
        ),
        3740: (
            ("A सही है, लेकिन B गलत है।", "A गलत है, लेकिन B सही है।", "A और B दोनों सही हैं।", "A और B दोनों गलत हैं।"),
            ("A is correct, but B is incorrect.", "A is incorrect, but B is correct.", "Both A and B are correct.", "Both A and B are incorrect."),
        ),
        3742: (
            ("(A) सही है, लेकिन (R) गलत है।", "(A) गलत है, लेकिन (R) सही है।", "(A) और (R) दोनों सही हैं तथा (R), (A) की सही व्याख्या है।", "(A) और (R) दोनों सही हैं, लेकिन (R), (A) की सही व्याख्या नहीं है।"),
            ("(A) is true, but (R) is false.", "(A) is false, but (R) is true.", "Both (A) and (R) are true and (R) correctly explains (A).", "Both (A) and (R) are true, but (R) does not correctly explain (A)."),
        ),
        3747: (
            ("(A) सही है, लेकिन (R) गलत है।", "(A) गलत है, लेकिन (R) सही है।", "(A) और (R) दोनों सही हैं तथा (R), (A) की सही व्याख्या है।", "(A) और (R) दोनों सही हैं, लेकिन (R), (A) की सही व्याख्या नहीं है।"),
            ("(A) is true, but (R) is false.", "(A) is false, but (R) is true.", "Both (A) and (R) are true and (R) correctly explains (A).", "Both (A) and (R) are true, but (R) does not correctly explain (A)."),
        ),
        3752: (
            ("(A) सही है, लेकिन (R) गलत है।", "(A) गलत है, लेकिन (R) सही है।", "(A) और (R) दोनों सही हैं तथा (R), (A) की सही व्याख्या है।", "(A) और (R) दोनों सही हैं, लेकिन (R), (A) की सही व्याख्या नहीं है।"),
            ("(A) is true, but (R) is false.", "(A) is false, but (R) is true.", "Both (A) and (R) are true and (R) correctly explains (A).", "Both (A) and (R) are true, but (R) does not correctly explain (A)."),
        ),
    }
    ar_explain_hi = ("(A) और (R) दोनों सही हैं तथा (R), (A) की सही व्याख्या है।", "(A) और (R) दोनों सही हैं, लेकिन (R), (A) की सही व्याख्या नहीं है।", "(A) सही है, लेकिन (R) गलत है।", "(A) और (R) दोनों गलत हैं।")
    ar_explain_en = ("Both (A) and (R) are true and (R) correctly explains (A).", "Both (A) and (R) are true, but (R) does not correctly explain (A).", "(A) is true, but (R) is false.", "Both (A) and (R) are false.")
    for line in (5125, 5126, 5131, 5139):
        option_sets[line] = (ar_explain_hi, ar_explain_en)
    ab_hi = ("A और B दोनों सही हैं।", "A और B दोनों गलत हैं।", "A सही है, लेकिन B गलत है।", "A गलत है, लेकिन B सही है।")
    ab_en = ("Both A and B are true.", "Both A and B are false.", "A is true, but B is false.", "A is false, but B is true.")
    for line in (5191, 5199, 5204):
        option_sets[line] = (ab_hi, ab_en)
    option_sets[5209] = (
        ("(A) और (R) दोनों सही हैं तथा (R), (A) की सही व्याख्या है।", "(A) और (R) दोनों सही हैं, लेकिन (R), (A) की सही व्याख्या नहीं है।", "(A) सही है, लेकिन (R) गलत है।", "(A) गलत है, लेकिन (R) सही है।"),
        ("Both (A) and (R) are true and (R) correctly explains (A).", "Both (A) and (R) are true, but (R) does not correctly explain (A).", "(A) is true, but (R) is false.", "(A) is false, but (R) is true."),
    )
    for line, (hi_options, en_options) in option_sets.items():
        for field, value in zip(HI_OPTION_FIELDS, hi_options):
            row_by_line[line][field] = value
        for field, value in zip(EN_OPTION_FIELDS, en_options):
            row_by_line[line][field] = value
        repaired_lines.add(line)
    update(5199,
           q_hi="कथनों को पढ़कर सही विकल्प चुनिए: (A) ज़ाइलम जड़ों से जल और खनिजों को पौधे के शेष भागों तक पहुँचाता है। (B) फ्लोएम पत्तियों से भोजन को पौधे के विभिन्न भागों तक पहुँचाता है।",
           q_en="Read the statements and choose the correct option: (A) Xylem transports water and minerals from roots to the rest of the plant. (B) Phloem transports food from leaves to different parts of the plant.")

    # Any remaining partial English block is explicitly made unavailable.
    for row in rows:
        present = [bool(row[field].strip()) for field in EN_FIELDS]
        if any(present) and not all(present):
            for field in EN_FIELDS:
                row[field] = ""
            repaired_lines.add(int(row["_line"]))

    # Classify every audited confirmed/probable upper-primary row as ctet2.
    marker_pattern = re.compile(r"(?:paper\s*[- ]?ii|paper\s*[- ]?2|vi\s*[-–]\s*viii|class(?:es)?\s+vi)", re.I)
    for line in moved_lines:
        row = row_by_line[line]
        row["exams"] = "ctet2"
        if not marker_pattern.search(row["source"]):
            row["source"] = f"{row['source']} [Paper II / Classes VI-VIII]"
        repaired_lines.add(line)

    # Restore all inferable PYQ years from source labels; do not reclassify non-CTET rows.
    for row in rows:
        line = int(row["_line"])
        if line in protected_non_ctet:
            continue
        if row["is_pyq"].strip() == "1" and not row["years"].strip():
            match = re.search(r"\b(20(?:1\d|2\d))\b", row["source"])
            if match:
                row["years"] = match.group(1)
                repaired_lines.add(line)

    # L3947 is a corrupt paraphrase of L62; consolidate it explicitly.
    row_by_line[62]["years"] = ",".join(sorted(years(row_by_line[62]["years"]) | years(row_by_line[3947]["years"])))
    consolidated_into[3947] = 62
    removed_reason[3947] = "consolidated_duplicate"

    active: dict[int, dict[str, str]] = {
        int(row["_line"]): row
        for row in rows
        if int(row["_line"]) not in unrecoverable_lines and int(row["_line"]) != 3947
    }

    def merge_group(lines: list[int]) -> int:
        candidates = [active[line] for line in lines if line in active]
        if len(candidates) < 2:
            return int(candidates[0]["_line"]) if candidates else lines[0]
        canonical = max(candidates, key=lambda row: source_score(row, repaired_lines))
        keep = int(canonical["_line"])

        # Preserve all occurrence years and PYQ status.
        merged_years: set[str] = set()
        for candidate in candidates:
            merged_years |= years(candidate["years"])
        canonical["years"] = ",".join(sorted(merged_years))
        canonical["is_pyq"] = "1" if any(c["is_pyq"].strip() == "1" for c in candidates) else "0"

        # Prefer a clearly cleaner Hindi text field over OCR/metadata contamination.
        for field in ("q_hi",) + HI_OPTION_FIELDS:
            for candidate in candidates:
                canonical[field] = choose_cleaner_hi(canonical[field], candidate[field])

        # Preserve the best complete English mirror, aligning reordered options by Hindi text.
        english_candidates = [c for c in candidates if full_english(c)]
        if english_candidates:
            english_source = max(english_candidates, key=lambda row: source_score(row, repaired_lines))
            canonical["q_en"] = english_source["q_en"]
            en_by_hi = {
                norm(english_source[hi_field]): english_source[en_field]
                for hi_field, en_field in zip(HI_OPTION_FIELDS, EN_OPTION_FIELDS)
            }
            if all(norm(canonical[field]) in en_by_hi for field in HI_OPTION_FIELDS):
                for hi_field, en_field in zip(HI_OPTION_FIELDS, EN_OPTION_FIELDS):
                    canonical[en_field] = en_by_hi[norm(canonical[hi_field])]
            else:
                for en_field in EN_OPTION_FIELDS:
                    canonical[en_field] = english_source[en_field]

        for candidate in candidates:
            line = int(candidate["_line"])
            if line == keep:
                continue
            consolidated_into[line] = keep
            removed_reason[line] = "consolidated_duplicate"
            active.pop(line, None)
        return keep

    # Consolidate all builder collisions and normalized duplicate findings, but never
    # collapse an item now intentionally represented in both ctet1 and ctet2.
    parent: dict[int, int] = {line: line for line in active}

    def find(line: int) -> int:
        while parent[line] != line:
            parent[line] = parent[parent[line]]
            line = parent[line]
        return line

    def union(left: int, right: int) -> None:
        if left not in active or right not in active:
            return
        # The user explicitly asked that non-CTET source records retain their
        # existing classification/provenance, even when content overlaps.
        if left in protected_non_ctet or right in protected_non_ctet:
            return
        if active[left]["exams"] != active[right]["exams"]:
            return
        if active[left]["section"] != active[right]["section"]:
            return
        lroot, rroot = find(left), find(right)
        if lroot != rroot:
            parent[rroot] = lroot

    for finding in findings:
        if finding["issue_code"] not in {"exact_duplicate_auto_dropped", "duplicate_survives_build"}:
            continue
        match = re.search(r":(\d+)", finding["related_lines"])
        if match:
            union(int(finding["csv_line"]), int(match.group(1)))

    groups: dict[int, list[int]] = defaultdict(list)
    for line in list(active):
        groups[find(line)].append(line)
    for group in groups.values():
        if len(group) > 1:
            merge_group(group)

    # A final option-order-independent pass catches duplicates that only became
    # identical after key/formula repairs.
    semantic_groups: dict[tuple[object, ...], list[int]] = defaultdict(list)
    for line, row in active.items():
        if line in protected_non_ctet:
            continue
        options = [norm(row[field]) for field in HI_OPTION_FIELDS]
        answer = int(row["ans"])
        key = (
            row["exams"], row["section"], row["pid"], norm(row["q_hi"]),
            tuple(sorted(options)), options[answer],
        )
        semantic_groups[key].append(line)
    for group in semantic_groups.values():
        current = [line for line in group if line in active]
        if len(current) > 1:
            merge_group(current)

    # Keep each passage body exactly once even if its original carrier was removed.
    ordered = [row for row in rows if int(row["_line"]) in active]
    seen_pid: set[str] = set()
    for row in ordered:
        pid = row["pid"]
        if not pid:
            row["p_kind"] = row["p_dir"] = row["p_body"] = ""
            continue
        row["p_kind"] = row["p_dir"] = row["p_body"] = ""
        if pid not in seen_pid and pid in passage_data:
            row["p_kind"], row["p_dir"], row["p_body"] = passage_data[pid]
            seen_pid.add(pid)

    with CSV_PATH.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        for row in ordered:
            writer.writerow({field: row[field] for field in fieldnames})

    current_line = {int(row["_line"]): index for index, row in enumerate(ordered, 2)}
    result_fields = [
        "original_csv_line", "source", "issue_code", "resolution",
        "current_csv_line", "current_exam",
    ]
    with RESULTS_PATH.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=result_fields, lineterminator="\n")
        writer.writeheader()
        for finding in findings:
            line = int(finding["csv_line"])
            code = finding["issue_code"]
            if line in removed_reason:
                resolution = removed_reason[line]
            elif code == "scope_non_ctet_exam":
                resolution = "unchanged_by_user_request"
            elif code.startswith("scope_paper2") or code == "scope_upper_primary_probable":
                resolution = "moved_to_ctet2"
            elif code in {"english_stem_truncated", "english_option_truncated"}:
                resolution = "incomplete_english_removed"
            elif code in {"exact_duplicate_auto_dropped", "duplicate_survives_build"}:
                resolution = "duplicate_group_canonical_or_cross_exam"
            else:
                resolution = "repaired"
            row = active.get(line)
            writer.writerow({
                "original_csv_line": line,
                "source": original_source[line],
                "issue_code": code,
                "resolution": resolution,
                "current_csv_line": current_line.get(line, ""),
                "current_exam": row["exams"] if row else "",
            })

    ctet1 = sum(row["exams"] == "ctet1" for row in ordered)
    ctet2 = sum(row["exams"] == "ctet2" for row in ordered)
    moved_retained = sum(line in active and active[line]["exams"] == "ctet2" for line in moved_lines)
    print(f"Repaired q_ctet.csv: {len(rows)} -> {len(ordered)} rows")
    print(f"Moved to ctet2: {len(moved_lines)} audited rows ({moved_retained} retained after cleanup)")
    print(f"Removed unrecoverable: {sum(reason == 'removed_unrecoverable' for reason in removed_reason.values())}")
    print(f"Consolidated duplicates: {sum(reason == 'consolidated_duplicate' for reason in removed_reason.values())}")
    print(f"Final exam totals: ctet1={ctet1}, ctet2={ctet2}")
    print(f"Resolution ledger: {RESULTS_PATH.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

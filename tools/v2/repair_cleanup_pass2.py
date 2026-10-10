#!/usr/bin/env python3
"""Cleanup pass 2 — fix column-bleed, leaked instruction/answer fragments, junk
asterisks, missing hi statements/figures, and broken math text (hi+en both).

Idempotent: each edit asserts its old text (or already-repaired text) before
writing. Run from repo root: python3 tools/v2/repair_cleanup_pass2.py
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BANK = ROOT / "bank-v2" / "exams"

changed_files: dict[str, int] = {}
failures: list[str] = []


def load_ndjson(path: Path) -> list[dict]:
    rows = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.strip():
            rows.append(json.loads(line))
    return rows


def save_ndjson(path: Path, rows: list[dict]) -> None:
    out = "\n".join(json.dumps(r, ensure_ascii=False) for r in rows)
    path.write_text(out + "\n", encoding="utf-8")
    changed_files[str(path.relative_to(ROOT))] = len(rows)


def edit_text(rec: dict, where: str, old: str, new: str, soft: bool = False) -> None:
    """Replace old->new inside a text map located by a lambda-free locator.

    where: 'prompt' (all prompt text maps) or 'opt:<id>' or 'content' (stimulus).
    """
    targets = []
    if where == "prompt":
        for blk in rec.get("prompt", []):
            t = blk.get("text")
            if isinstance(t, dict):
                targets.append(t)
    elif where.startswith("opt:"):
        oid = where.split(":", 1)[1]
        for opt in rec.get("options", []):
            if opt.get("id") == oid:
                for blk in opt.get("content", []):
                    t = blk.get("text")
                    if isinstance(t, dict):
                        targets.append(t)
    elif where == "content":
        for blk in rec.get("content", []):
            t = blk.get("text")
            if isinstance(t, dict):
                targets.append(t)
    ok = False
    for t in targets:
        for loc in list(t.keys()):
            if old in t[loc]:
                t[loc] = t[loc].replace(old, new)
                ok = True
            elif new in t[loc]:
                ok = True  # already applied
    if not ok and not soft:
        failures.append(f"{rec.get('id')}: [{where}] NOT FOUND: {old[:60]!r}")


def set_text(rec: dict, where: str, new: str, loc: str) -> None:
    targets = []
    if where == "prompt":
        for blk in rec.get("prompt", []):
            t = blk.get("text")
            if isinstance(t, dict):
                targets.append(t)
    elif where == "content":
        for blk in rec.get("content", []):
            t = blk.get("text")
            if isinstance(t, dict):
                targets.append(t)
    for t in targets:
        t[loc] = new


# --------------------------------------------------------------- file registry
FILES = {
    "ctet-cdp": BANK / "ctet/paper-1/cdp/questions.ndjson",
    "ctet-evs": BANK / "ctet/paper-1/environmental-studies/questions.ndjson",
    "ctet-math": BANK / "ctet/paper-1/mathematics/questions.ndjson",
    "ctet-l1hi": BANK / "ctet/paper-1/language-1/hindi/questions.ndjson",
    "ctet-l1hi-stim": BANK / "ctet/paper-1/language-1/hindi/stimuli.ndjson",
    "ctet-l2sa": BANK / "ctet/paper-1/language-2/sanskrit/questions.ndjson",
    "utet-cdp": BANK / "utet/paper-1/cdp/questions.ndjson",
    "utet-evs": BANK / "utet/paper-1/environmental-studies/questions.ndjson",
    "utet-math": BANK / "utet/paper-1/mathematics/questions.ndjson",
    "utet-l1hi": BANK / "utet/paper-1/language-1/hindi/questions.ndjson",
    "utet-l2en-stim": BANK / "utet/paper-1/language-2/english/stimuli.ndjson",
}

Q: dict[str, dict] = {}
S: dict[str, dict] = {}
ROWS: dict[str, list[dict]] = {}
for key, path in FILES.items():
    rows = load_ndjson(path)
    ROWS[key] = rows
    for r in rows:
        if "stimuli" in path.name:
            S[r["id"]] = r
        else:
            Q[r["id"]] = r


def q(qid: str) -> dict:
    if qid not in Q:
        failures.append(f"MISSING QUESTION {qid}")
        return {}
    return Q[qid]


# ============================================================================ #
# 1) ctet-p1-2026-e-lang1-hi-q099 — option D leak (instruction + poem + range)  #
# ============================================================================ #
r = q("ctet-p1-2026-e-lang1-hi-q099")
for opt in r.get("options", []):
    if opt.get("id") == "d":
        for blk in opt.get("content", []):
            t = blk.get("text", {})
            if isinstance(t, dict) and isinstance(t.get("hi"), str) and len(t["hi"]) > 10:
                t["hi"] = "श्रेष्ठ"

# poem q101 typo 'मं़िजल' -> 'मंजिल' (all locales anywhere in lang1-hi set)
for rid, rec in Q.items():
    if rid.startswith("ctet-p1-2026-e-lang1-hi"):
        for where in ["prompt"] + [f"opt:{o.get('id')}" for o in rec.get("options", [])]:
            edit_text(rec, where, "मं़िजल", "मंजिल", soft=True)

# ============================================================================ #
# 2) 2026-stimulus-hi-po-100 — restore real poem from q099 leak               #
# ============================================================================ #
POEM_2026 = (
    "जीवन अस्थिर अनजाने ही, हो जाता पथ पर मेल कहीं,\n"
    "सीमित पग-डग, लंबी मंजिल, तय कर लेना कुछ खेल नहीं।\n"
    "दाएँ-बाएँ सुख-दुख चलते, सम्मुख चलता पथ का प्रसाद,\n"
    "जिस-जिस से पथ पर स्नेह मिला, उस-उस राही को धन्यवाद।"
)
st = S.get("ctet-p1-2026-stimulus-hi-po-100")
if st:
    set_text(st, "content", POEM_2026, "hi")
else:
    failures.append("MISSING STIMULUS ctet-p1-2026-stimulus-hi-po-100")

# ============================================================================ #
# 3) 2024-stimulus-hi-po-100 — restore 'आज तिरंगा फहराता है' (सजीवन मयंक)      #
# ============================================================================ #
POEM_2024 = (
    "आज तिरंगा फहराता है अपनी पूरी शान से।\n"
    "हमें मिली आज़ादी वीर शहीदों के बलिदान से।।\n\n"
    "आज़ादी के लिए हमारी लंबी चली लड़ाई थी।\n"
    "लाखों लोगों ने प्राणों से कीमत बड़ी चुकाई थी।।\n\n"
    "व्यापारी बनकर आए और छल से हम पर राज किया।\n"
    "हमको आपस में लड़वाने की नीति अपनाई थी।।\n\n"
    "हमने अपना गौरव पाया, अपने स्वाभिमान से।\n"
    "हमें मिली आज़ादी वीर शहीदों के बलिदान से।।\n\n"
    "— सजीवन मयंक"
)
st = S.get("ctet-p1-2024-stimulus-hi-po-100")
if st:
    set_text(st, "content", POEM_2024, "hi")
    if isinstance(st.get("title"), dict):
        st["title"]["hi"] = "आज तिरंगा फहराता है"
    if isinstance(st.get("instructions"), dict):
        st["instructions"]["hi"] = (
            "निर्देश : निम्नलिखित काव्यांश को पढ़कर पूछे गए प्रश्नों के "
            "सही/सर्वाधिक उपयुक्त विकल्प का चयन कीजिए। (100-105)"
        )
else:
    failures.append("MISSING STIMULUS ctet-p1-2024-stimulus-hi-po-100")

# ============================================================================ #
# 4) ctet-p1-2026-e-mathematics-q047 — HCF/LCM text lost in hi, junk in en     #
# ============================================================================ #
r = q("ctet-p1-2026-e-mathematics-q047")
edit_text(r, "prompt", "If HCF of two numbers is 18, then which of the following cannot be their LCM? HCF=18 LCM",
          "If HCF of two numbers is 18, then which of the following cannot be their LCM?")
edit_text(r, "prompt", "यदि दो संख्याओं का है, तो निम्न में से कौन सी संख्या इनका नहीं हो सकती?",
          "यदि दो संख्याओं का म.स. (HCF) 18 है, तो निम्न में से कौन-सी संख्या इनका ल.स. (LCM) नहीं हो सकती?")

# 5) q052 — variable x eaten in hi, trailing junk in en
r = q("ctet-p1-2026-e-mathematics-q052")
edit_text(r, "prompt", "If a six digits number 72x292 is divisible by 36, then the value of (3x+2) is : x292 x+2)",
          "If a six-digit number 72x292 is divisible by 36, then the value of (3x + 2) is :")
edit_text(r, "prompt", "यदि एक छ: अंकों की संख्या 72संख्या 36 से विभाज्य है, तो (3का मान है :",
          "यदि एक छह अंकों की संख्या 72x292, 36 से विभाज्य है, तो (3x + 2) का मान है :")

# 6) q053 — '9 kg 995 g' lost in hi, trailing bleed in en
r = q("ctet-p1-2026-e-mathematics-q053")
edit_text(r, "prompt", "Radha bought 9 bags of rice each weighing 9 kg 995 g. Total weight of rice in the bags is : kg 995 g",
          "Radha bought 9 bags of rice each weighing 9 kg 995 g. Total weight of rice in the bags is :")
edit_text(r, "prompt", "राधा ने चावल के 9 बोरियाँ खरीदीं, जिसमें से प्रत्येक में चावल का भार 9 है। इन बोरियों में चावल का कुल भार है :",
          "राधा ने चावल की 9 बोरियाँ खरीदीं, जिनमें से प्रत्येक में चावल का भार 9 किग्रा 995 ग्रा है। इन बोरियों में चावल का कुल भार है :")

# 7) ctet-p1-2024-i-mathematics-q041 — '1' subject lost in hi c/d; trailing '1' junk in en c/d
r = q("ctet-p1-2024-i-mathematics-q041")
edit_text(r, "opt:c", "1 is both, a prime and a composite number 1", "1 is both, a prime and a composite number")
edit_text(r, "opt:d", "1 is neither prime nor a composite number 1", "1 is neither prime nor a composite number")
edit_text(r, "opt:c", "दोनों है, एक भाज्य और अभाज्य संख्या।", "1 भाज्य और अभाज्य दोनों है।")
edit_text(r, "opt:d", "न तो अभाज्य है और न ही भाज्य है।", "1 न तो अभाज्य है और न ही भाज्य है।")

# 8) q048 — price/quantity swapped+lost in hi, price bleed in en
r = q("ctet-p1-2024-i-mathematics-q048")
pairs = [
    ("a", "75 packets of ₹750 each ₹750", "75 packets of ₹750 each",
     "प्रत्येक पैकेल वाले 750 पैकेट", "₹750 प्रत्येक वाले 75 पैकेट"),
    ("b", "750 packets of ₹7.50 each ₹7.50", "750 packets of ₹7.50 each",
     "प्रत्येक पैकेट वाले 750 पैकेट", "₹7.50 प्रत्येक वाले 750 पैकेट"),
    ("c", "7.5 dozen items of ₹750 each item. ₹750", "7.5 dozen items of ₹750 each",
     "प्रत्येक वस्तु वाली 7.5 दर्जन वस्तुएँ", "₹750 प्रत्येक वाली 7.5 दर्जन वस्तुएँ"),
    ("d", "75 dozen items of ₹7.50 each item. ₹7.50", "75 dozen items of ₹7.50 each",
     "प्रत्येक वस्तु वाली 75 दर्जन वस्तुएँ", "₹7.50 प्रत्येक वाली 75 दर्जन वस्तुएँ"),
]
for oid, en_old, en_new, hi_old, hi_new in pairs:
    edit_text(r, f"opt:{oid}", en_old, en_new)
    edit_text(r, f"opt:{oid}", hi_old, hi_new)

# 9) q056 — die results lost in en
r = q("ctet-p1-2024-i-mathematics-q056")
edit_text(r, "prompt",
          "Yamina threw a die 10 times and got the following results : Which of the following numbers she got the maximum number of times?",
          "Yamina threw a die 10 times and got the following results : 5, 3, 6, 6, 1, 4, 5, 3, 3, 2. Which of the following numbers did she get the maximum number of times?")

# 10) ctet-p1-2023-e-mathematics-q045 — en end-time wrong (24:15 vs 21:15; answer d=4h25m)
r = q("ctet-p1-2023-e-mathematics-q045")
edit_text(r, "prompt", "finished at 24:15 hours", "finished at 21:15 hours")

# 11) ctet-p1-2023-e-mathematics-q057 — hi opt b duplicated from opt a
r = q("ctet-p1-2023-e-mathematics-q057")
edit_text(r, "opt:b", "विद्यार्थी संख्या 5 की पहचान 4 के परवर्ती के रूप में करता है।",
          "विद्यार्थी संख्या 6 की पहचान 5 में 1 जोड़ने के रूप में करता है।")

# 12) ctet-p1-2019-a-mathematics-q040 — (cid:1) bullets + broken parentheses
r = q("ctet-p1-2019-a-mathematics-q040")
set_text(r, "prompt",
         "(i) I am a 2 digit number.\n(ii) The digit in tens place and the digit in units place are consecutive prime numbers.\n"
         "(iii) The sum of digits is a multiple of 3 and 4.\nThe number is", "en")
set_text(r, "prompt",
         "(i) मैं एक दो अंकों की संख्या हूँ।\n(ii) दहाई के स्थान का अंक और इकाई के स्थान का अंक क्रमिक अभाज्य संख्याएँ हैं।\n"
         "(iii) अंकों का योग 3 और 4 दोनों का गुणज है।\nसंख्या है–", "hi")

# 13) utet-p1-2020-mathematics-q095 — en option values lost
r = q("utet-p1-2020-mathematics-q095")
for oid, old, new in [("a", "gram", "15.59 gram"), ("b", "Dekagram", "155.9 Dekagram"),
                      ("c", "Kilogram", "0.01559 Kilogram"), ("d", "Hectogram", "1.559 Hectogram")]:
    for opt in r.get("options", []):
        if opt.get("id") == oid:
            for blk in opt.get("content", []):
                t = blk.get("text", {})
                if isinstance(t, dict) and t.get("en") == old:
                    t["en"] = new
                elif isinstance(t, dict) and t.get("en") != new:
                    failures.append(f"utet-p1-2020-mathematics-q095 opt {oid}: unexpected en {t.get('en')!r}")

# 14) utet-p1-2021-mathematics-q106 — figure missing in hi; question text missing in en
FIG = "9 x 7 6\n− x 6 y 9\n─────────────\n3 y y 7"
r = q("utet-p1-2021-mathematics-q106")
set_text(r, "prompt", f"If\n```\n{FIG}\n```\nthen the values of x and y are :", "en")
set_text(r, "prompt", f"यदि\n```\n{FIG}\n```\nतो x और y के मान हैं —", "hi")

# 15) utet-p1-2024-mathematics-q112 — series missing in hi
r = q("utet-p1-2024-mathematics-q112")
edit_text(r, "prompt", "दी गई श्रृंखला में बॉक्स में क्या आएगा?",
          "दी गई श्रृंखला में बॉक्स में क्या आएगा?\n79, 87, [ ], 89, 83, 91")

# 16) ctet-p1-2016-i-mathematics fill marks -> canonical blank
for qid, old, new in [
    ("ctet-p1-2016-i-mathematics-q045", "= 7 ×…..", "= 7 × [ ________ ]"),
    ("ctet-p1-2016-i-mathematics-q046", "999 + 9 × ….", "999 + 9 × [ ________ ]"),
    ("ctet-p1-2016-i-mathematics-q050", "11012 +……", "11012 + [ ________ ]"),
]:
    r = q(qid)
    edit_text(r, "prompt", old, new)
# q044 original string variant with spaces
r = q("ctet-p1-2016-i-mathematics-q044")
edit_text(r, "prompt", "1001×111=110000+11×……..", "1001×111 = 110000 + 11 × [ ________ ]")
r = q("ctet-p1-2016-i-mathematics-q045")
edit_text(r, "prompt", "2659 मेंं 6", "2659 में 6", soft=True)

# 17) utet-p1-2025-mathematics-q114 — unit missing in en
r = q("utet-p1-2025-mathematics-q114")
edit_text(r, "prompt", "Speed of stream is :", "Speed of the stream (in km/h) is :")

# 18) ctet-p1-2019-a-environmental-studies-q076 — hi options all 'h', en missing '/h'
r = q("ctet-p1-2019-a-environmental-studies-q076")
for oid, hi_new, en_new in [
    ("a", "53 किमी/घंटा", "53 km/h"),
    ("b", "45 किमी/घंटा", "45 km/h"),
    ("c", "132.5 किमी/घंटा", "132.5 km/h"),
    ("d", "60 किमी/घंटा", "60 km/h"),
]:
    for opt in r.get("options", []):
        if opt.get("id") == oid:
            for blk in opt.get("content", []):
                t = blk.get("text", {})
                if isinstance(t, dict):
                    t["hi"] = hi_new
                    t["en"] = en_new

# 19) ctet-p1-2024-i-environmental-studies-q086 — 4/5 split across columns
r = q("ctet-p1-2024-i-environmental-studies-q086")
edit_text(r, "opt:a", "Make a roll number-wise groups of 4/5 students./4",
          "Make roll number-wise groups of 4/5 students.")
edit_text(r, "opt:a", "5 छात्रों के रोल नंबर के अनुसार समूह बनाएँ।",
          "रोल नंबर के अनुसार 4/5 छात्रों के समूह बनाएँ।")

# 20) ctet-p1-2019-a-cdp-q003 — exam-metadata leak in option a
r = q("ctet-p1-2019-a-cdp-q003")
edit_text(r, "opt:a", "Acquired through conditioning. CTET) Class I-V)", "Acquired through conditioning.")
edit_text(r, "opt:a", "अनुबंधन द्वारा अर्जित है। (परीक्षा -2019 (प्रश्न-पत्र का हल (परीक्षा तिथि: 8 दिसम्बर, 2019)",
          "अनुबंधन द्वारा अर्जित है।")

# 21) utet-p1-2026-environmental-studies-q128 — stray '*' before classification tags
r = q("utet-p1-2026-environmental-studies-q128")
for opt in r.get("options", []):
    for blk in opt.get("content", []):
        t = blk.get("text", {})
        if isinstance(t, dict) and isinstance(t.get("hi"), str):
            t["hi"] = t["hi"].replace(" *(", " (")

# 22) utet-p1-2020-mathematics-q117 — *(figure note)* leaks answer name
r = q("utet-p1-2020-mathematics-q117")
edit_text(r, "prompt",
          "चित्र में दिये गये ठोस का नाम है *(चित्र : त्रिभुजाकार फलक वाला प्रिज्म)* –",
          "दिये गये चित्र में ठोस का नाम है : (आकृति : दो समानान्तर त्रिभुजाकार फलकों तथा तीन आयताकार पार्श्व फलकों वाला ठोस)")
edit_text(r, "prompt", "The name of the solid in figure is :",
          "The name of the solid in the figure is : (Figure: a solid with two parallel triangular faces and three rectangular lateral faces)")

# 23) utet-p1-2026-mathematics-q116 — stray asterisks around expression
r = q("utet-p1-2026-mathematics-q116")
edit_text(r, "prompt", "What is the expression* [(√(2))^(√(2))]^(√(2)) *?",
          "What is the expression [(√(2))^(√(2))]^(√(2))?")

# 24) ctet-p1-2023-e-lang2-sa-q148 — stray '*' inside Sanskrit word
r = q("ctet-p1-2023-e-lang2-sa-q148")
for where in ["prompt"] + [f"opt:{o.get('id')}" for o in r.get("options", [])]:
    edit_text(r, where, "अ*ङ्गमस्ति", "अङ्गमस्ति", soft=True)

# 25) utet-p1-2024-lang1-hi-q058 — editor's note leak in prompt
r = q("utet-p1-2024-lang1-hi-q058")
edit_text(r, "prompt", "\n> *टिप्पणी: इस प्रश्न के विकल्प OCR में अस्पष्ट थे — original booklet से verify कर लें।", "")
edit_text(r, "prompt", "\n> *टिप्पणी: इस प्रश्न के विकल्प OCR में अस्पष्ट थे — original booklet से verify कर लें।", "")

# 26) utet-p1-2020-cdp-q009 — statements missing in hi
r = q("utet-p1-2020-cdp-q009")
edit_text(r, "prompt", "निम्नलिखित में से शिक्षण के सूत्र कौन से हैं?",
          "निम्नलिखित में से शिक्षण के सूत्र कौन से हैं?\n\n1. ज्ञात से अज्ञात की ओर।\n2. मूर्त से अमूर्त की ओर।\n3. सरल से जटिल की ओर।\n4. समग्र से अंश की ओर।")

# 27) utet-p1-2020-environmental-studies-q128 — reasons missing in hi
r = q("utet-p1-2020-environmental-studies-q128")
edit_text(r, "prompt", "केंचुआ किसान का मित्र माना जाता है। निम्न में से उसके लिए सही कारण चुनें –",
          "केंचुआ किसान का मित्र माना जाता है। निम्न में से उसके लिए सही कारण चुनें –\n\n"
          "1. केंचुआ मृत पत्तियों और पौधों को खाता है तथा उसका मल मिट्टी को उपजाऊ बनाता है।\n"
          "2. केंचुआ खरपतवार खाकर मुख्य फसल की रक्षा करता है।\n"
          "3. केंचुआ ज़मीन में बिल बनाकर मिट्टी ढीली करता है।\n"
          "4. उसके बिलों से मिट्टी में हवा और पानी आसानी से प्रवेश कर पाते हैं।")

# 28) ctet-p1-2021-dec-d-mathematics-q057 — figure bleed '+ 3811'
r = q("ctet-p1-2021-dec-d-mathematics-q057")
edit_text(r, "prompt",
          "A student solves the addition problem in the following way: + 3811 Which one of the following statements represents correct remedial technique for the error made by the student?",
          "A student solves an addition problem in an incorrect way. Which one of the following statements represents correct remedial technique for the error made by the student?")
edit_text(r, "prompt",
          "एक विद्यार्थी, योग (जमा) की समस्या को निम्नलिखित विधि से हल करता है– निम्नलिखित में से कौन-सा एक कथन विद्यार्थी के दोष को सुधारने के लिए सही तकनीक को दर्शाता है?",
          "एक विद्यार्थी, योग (जमा) की एक समस्या को गलत विधि से हल करता है। निम्नलिखित में से कौन-सा एक कथन विद्यार्थी के दोष को सुधारने के लिए सही तकनीक को दर्शाता है?")

# 29) utet EN stimuli — italic star artifacts around titles
for sid in ["utet-p1-2021-ut21-e2", "utet-p1-2022-ut22-e1"]:
    if sid in S:
        r = S[sid]
        edit_text(r, "content", "*Crisis in Civilisation*", "Crisis in Civilisation", soft=True)
        edit_text(r, "content", "*(The Road Not Taken — Robert Frost)*", "(The Road Not Taken — Robert Frost)", soft=True)

# ============================================================================ #
# write back                                                                  #
# ============================================================================ #
if failures:
    print("FAILURES (nothing written):")
    for f in failures:
        print("  -", f)
    sys.exit(1)

for key, path in FILES.items():
    save_ndjson(path, ROWS[key])

print("All edits applied.")
for k, v in changed_files.items():
    print(f"  wrote {k} ({v} rows)")

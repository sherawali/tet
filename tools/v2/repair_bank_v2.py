#!/usr/bin/env python3
"""Forensic display-text repairs for bank-v2 (deterministic and idempotent).

This tool fixes the corruption classes mandated by the master cleanup rules:

* Rule 3/4 — trailing section labels (``PART - II`` / ``भाग - V``) and column-bleed
  fragments, with dropped Hindi/English text restored for bilingual parity.
* Rule 5 — option-D contamination (leaked passages / OMR instructions) stripped
  from options; dangling option-label prefixes removed (``"(A) दोनों (A)…"``);
  corrupted Assertion/Reason option fragments (missing leading ``(A)``) restored.
* Rule 6 — raw LaTeX converted to clean Unicode (fractions, radicals,
  superscripts, operators).
* Rule 7 — assertion-reasoning prompts normalised to the canonical
  ``**अभिकथन (A):**`` / ``**Assertion (A):**`` layout (including marker-less
  ``अभिकथन : … कारण : …`` and ``तर्क (R)`` variants); multi-statement lists
  split onto separate lines with consistent ``(A)/(B)/(C)/(D)`` and
  ``(i)/(ii)/(iii)/(iv)`` / ``(I)/(II)…`` markers.
* Typography — OCR visarga-as-colon (``शब्द ः``) normalised to ``:``.

Identity, option order, answer keys, provenance and stimulus structure are left
untouched (use ``apply_forensic_content.py`` for answer-key and passage work).

Usage:
    python tools/v2/repair_bank_v2.py [--dry-run]
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
BANK = REPO_ROOT / "bank-v2"

# --------------------------------------------------------------------------- #
# Generic patterns                                                            #
# --------------------------------------------------------------------------- #

SECTION_ARTIFACT_RE = re.compile(
    r"\s*(?:o\s*0\s*o\s*[-–—]{1,2}\s*READ\s+THE\s+FOLLOWING\s+INSTRUCTIONS.*)$"
    r"|\s*(?:PART|भाग|SECTION|खण्ड)\s*[-–—:]\s*(?:[IVX]+|\d+)\s*$",
    re.IGNORECASE | re.DOTALL,
)
VISARGA_COLON_RE = re.compile(r"(?<=[\s)])\u0903")
CORRUPT_AR_OPTION_RE = re.compile(
    r"^(?:is\s+(?:true|false|correct)|are\s+(?:true|false)|"
    r"सही\s+है|गलत\s+है|दोनों)"
)
AR_OPTION_MUST_REF = re.compile(r"\([RB]\)")
AR_MARKER_HI = re.compile(r"अभिकथन")
AR_MARKER_EN = re.compile(r"Assertion\s*(?:\(A\)|:)|Reason\s*(?:\(R\)|:)", re.IGNORECASE)
STATEMENT_MARKER_RE = re.compile(
    r"(?:\b(?:Statement|कथन)\s*)?\((?:A|B|C|D|i|ii|iii|iv|I|II|III|IV)\)(?=\s)"
)
MENTION_BEFORE_MARKER_RE = re.compile(
    r"(?:Statement|statement|statements|कथन|कथनों|following|निम्नलिखित|point|Point|बिन्दु|बिंदु|शीर्ष|vertex)\s+$"
)
CODE_REF_RE = re.compile(r"\(([a-d])\)")
LATEX_DOLLAR_RE = re.compile(r"\$([^$]+)\$")
# dangling "(A) दोनों … (A)/(B)/(R) …" option prefix (OCR doubling of the label)
DOUBLED_A_PREFIX_RE = re.compile(r"^\(A\)\s+(?=दोनों.*\((?:A|B|R)\))")

SUPERSCRIPTS = str.maketrans("0123456789+-=()ni", "⁰¹²³⁴⁵⁶⁷⁸⁹⁺⁻⁼⁽⁾ⁿⁱ")


def latex_to_unicode(text: str) -> str:
    """Convert the LaTeX constructs found in the bank to clean Unicode."""

    def frac(m: re.Match[str]) -> str:
        num, den = m.group(1), m.group(2)
        return f"({num}) / ({den})" if len(num) > 3 or len(den) > 3 else f"{num}/{den}"

    def dollars(m: re.Match[str]) -> str:
        body = m.group(1)
        # sqrt first so frac denominators like \dfrac{1}{\sqrt{15}+\sqrt{16}}
        # no longer contain nested braces when the frac passes run.
        body = re.sub(r"\\sqrt\{([^{}]+)\}", lambda mm: "√(" + mm.group(1) + ")", body)
        body = re.sub(r"\\sqrt(\d+)", lambda mm: "√" + mm.group(1), body)
        for _ in range(3):
            body = re.sub(r"\\dfrac\{([^{}]+)\}\{([^{}]+)\}", frac, body)
            body = re.sub(r"\\frac\{([^{}]+)\}\{([^{}]+)\}", frac, body)
        body = body.replace("\\left", "").replace("\\right", "")
        body = body.replace("\\ldots", "...").replace("\\times", "×").replace("\\div", "÷")
        body = re.sub(r"\^\{([^{}]+)\}", lambda mm: "^(" + mm.group(1) + ")", body)
        body = re.sub(r"\^(\d+)", lambda mm: mm.group(1).translate(SUPERSCRIPTS), body)
        body = re.sub(r"\s+", " ", body).strip()
        return body

    out = LATEX_DOLLAR_RE.sub(dollars, text)
    # bare-caret powers outside dollars, e.g. 3^98
    out = re.sub(r"(?<=\d)\^(\d+)", lambda m: m.group(1).translate(SUPERSCRIPTS), out)
    out = out.replace("\\times", "×").replace("\\div", "÷")
    return out


def strip_section_artifact(text: str) -> str:
    return SECTION_ARTIFACT_RE.sub("", text).rstrip()


def restore_ar_option(text: str) -> str:
    if CORRUPT_AR_OPTION_RE.match(text) and AR_OPTION_MUST_REF.search(text):
        return "(A) " + text
    return text


def strip_doubled_a_prefix(text: str) -> str:
    return DOUBLED_A_PREFIX_RE.sub("", text)


def split_statements(text: str) -> str:
    """Put multi-statement markers on their own lines (Rule 7)."""
    markers = []
    for m in STATEMENT_MARKER_RE.finditer(text):
        before = text[: m.start()]
        if MENTION_BEFORE_MARKER_RE.search(before):
            continue
        if not before.strip() or before.rstrip(" \t").endswith("\n"):
            continue  # already at line start — keeps the transform idempotent
        markers.append(m)
    if len(markers) < 2:
        return text
    out = []
    prev = 0
    for m in markers:
        out.append(text[prev : m.start()].rstrip(" "))
        out.append("\n")
        prev = m.start()
    out.append(text[prev:])
    return "".join(out)


def uppercase_statement_codes(question: dict) -> None:
    """Normalise (a)/(b)... statement-code references to uppercase (A)/(B)..."""
    stem = " ".join(
        t for block in question.get("prompt") or [] for t in (block.get("text") or {}).values()
    )
    has_upper = len(re.findall(r"\((?:A|B|C|D)\)(?=\s)", stem)) >= 2
    has_lower = len(re.findall(r"\((?:a|b|c|d)\)(?=\s)", stem)) >= 2
    if not (has_upper or has_lower):
        return
    if has_lower and not has_upper:
        for block in question.get("prompt") or []:
            for loc, text in (block.get("text") or {}).items():
                block["text"][loc] = re.sub(
                    r"\((?:a|b|c|d)\)(?=\s)", lambda m: m.group(0).upper(), text
                )
    for option in question.get("options") or []:
        for block in option.get("content") or []:
            for loc, text in (block.get("text") or {}).items():
                block["text"][loc] = CODE_REF_RE.sub(lambda m: f"({m.group(1).upper()})", text)


def canonicalize_assertion_reason(question: dict) -> None:
    for block in question.get("prompt") or []:
        texts = block.get("text") or {}
        for loc, text in list(texts.items()):
            is_ar = AR_MARKER_HI.search(text) if loc == "hi" else AR_MARKER_EN.search(text)
            if not is_ar:
                continue
            texts[loc] = canonicalize_ar_text(text, loc)


def canonicalize_ar_text(text: str, loc: str) -> str:
    if loc == "hi":
        if not AR_MARKER_HI.search(text):
            return text
        # marker-less / variant markers -> (A)/(R) markers; only at real marker
        # positions (word followed by a colon) so ordinary words like "के कारण",
        # "का तर्क है", "reasonable" are never touched.
        text = re.sub(r"अभिकथन(?!\s*\(A\))(?=\s*[:\u0903])\s*[:\u0903]*", "अभिकथन (A): ", text)
        text = re.sub(r"(?:कारण|तर्क)(?!\s*\(R\))(?=\s*[:\u0903])\s*[:\u0903]*", "कारण (R): ", text)
        text = re.sub(r"तर्क(\s*\(R\))", r"कारण\1", text)
        a_pat = re.compile(r"\*{0,2}अभिकथन\s*\(A\)\s*[:\u0903*]*\s*")
        r_pat = re.compile(r"\*{0,2}कारण\s*\(R\)\s*[:\u0903*]*\s*")
        instruction = "सही विकल्प का चयन कीजिए:"
    else:
        text = re.sub(
            r"Assertion(?!\s*\(A\))(?=\s*[:*])\s*[:*]*", "Assertion (A): ", text, flags=re.IGNORECASE
        )
        text = re.sub(
            r"Reason(?!\s*\(R\))(?=\s*[:*])\s*[:*]*", "Reason (R): ", text, flags=re.IGNORECASE
        )
        a_pat = re.compile(r"\*{0,2}Assertion\s*\(A\)\s*[:*]*\s*", re.IGNORECASE)
        r_pat = re.compile(r"\*{0,2}Reason\s*\(R\)\s*[:*]*\s*", re.IGNORECASE)
        instruction = "Choose the correct option:"
    text = VISARGA_COLON_RE.sub(":", text)
    m_a = a_pat.search(text)
    m_r = r_pat.search(text)
    if not m_a or not m_r or m_r.start() < m_a.end():
        return text
    assertion = text[m_a.end() : m_r.start()].strip().strip("*").strip().rstrip(":").strip()
    reason = text[m_r.end() :].strip().strip("*").strip()
    # safety: marker mentions inside the extracted bodies mean we matched an
    # instruction, not the real pair — leave the text for explicit content fixes.
    if re.search(r"\((?:A|R)\)", assertion) or re.search(r"\((?:A|R)\)", reason):
        return text
    reason = re.sub(
        r"(?:\s*(?:सही\s+विकल्प(?:\s+का\s+चयन)?\s+(?:कीजिए|चुनें|चुनिए)|"
        r"सही\s+विकल्प\s+का\s+चयन\s+कीजिए|Choose\s+the\s+correct\s+option)"
        r"(?:\s*[:.।])?\s*)$",
        "",
        reason,
        flags=re.IGNORECASE,
    ).strip().rstrip(":").strip()
    if not assertion or not reason:
        return text
    if loc == "hi":
        return f"**अभिकथन (A):** {assertion}\n**कारण (R):** {reason}\n{instruction}"
    return f"**Assertion (A):** {assertion}\n**Reason (R):** {reason}\n{instruction}"


# --------------------------------------------------------------------------- #
# Explicit content repairs (column bleed, option contamination, lost data)     #
# --------------------------------------------------------------------------- #

CONTENT_FIXES: dict[str, dict[str, dict[str, str]]] = {
    # ---- Rule 4: column bleed — dropped starts / trailing leak fragments ----
    "ctet-p1-2024-i-mathematics-q040": {
        "prompt": {
            "hi": "25454 प्राप्त करने के लिए 9909, 9099 और 9009 के योग में से क्या घटाना होगा?",
            "en": "What should be subtracted from the sum of 9909, 9099 and 9009 to obtain 25454?",
        }
    },
    "ctet-p1-2024-i-mathematics-q042": {
        "prompt": {
            "hi": "नीचे दिए गए संख्या पैटर्न को देखिए : 1, 8, 27, 64, 125, [ ________ ] , [ ________ ] इसमें अगले दो पद क्या होंगे?",
            "en": "See the number pattern given below : 1, 8, 27, 64, 125, [ ________ ] , [ ________ ] What will be the next two terms?",
        }
    },
    "ctet-p1-2024-i-mathematics-q044": {
        "prompt": {
            "hi": "25.3 × 5 - 35 ÷ 5 - 3 × 18.5 का मान है :",
            "en": "The value of 25.3 × 5 - 35 ÷ 5 - 3 × 18.5 is :",
        }
    },
    "ctet-p1-2024-i-mathematics-q055": {
        "prompt": {
            "hi": (
                "कक्षा II में 82 – 7 को हल करवाते हुए एक अध्यापिका ने स्पष्ट किया कि हमें 7 को 82 में से "
                "घटाना है और 2, छोटा है 7 से। इसलिए हमें 8 से एक उधार लेना पड़ेगा और तब हम 12 में से "
                "7 को घटा पाएँगे। एक बच्चे ने अध्यापिका से पूछा : मैडम! हम 8 से उधार क्यों ले रहे हैं। "
                "उधार लेना अच्छा नहीं होता। इस परिस्थिति में अध्यापिका को क्या करना चाहिए?"
            ),
            "en": (
                "In class II, a teacher explained that we have to subtract 7 from 82 and 2 is smaller "
                "than 7. So we will borrow one from 8 and then we can subtract 7 from 12. One student "
                "told teacher: Man! why we are borrowing from eight, as borrowing is not good. What a "
                "teacher should do in such as situation?"
            ),
        }
    },
    "ctet-p1-2026-e-mathematics-q031": {
        "prompt": {
            "hi": "1 से 50 तक की संख्याओं में, कितने अभाज्य युग्म हैं?",
            "en": "How many twin primes are there in the numbers from 1 to 50?",
        }
    },
    "ctet-p1-2019-a-mathematics-q045": {
        "prompt": {
            "hi": "एक वर्ग की भुजा 4 cm है। इसे काट कर 4 बराबर वर्गों में विभाजित किया गया है। प्रत्येक छोटे वर्ग का क्षेत्रफल क्या होगा?",
            "en": "The side of a square is 4 cm. It is cut into 4 equal squares. What is the area of each small square?",
        }
    },
    "ctet-p1-2019-a-mathematics-q055": {
        "prompt": {
            "en": (
                "When asked to write 44, some students of grade II wrote it as 404. As a teacher, "
                "how will you address this?"
            )
        }
    },
    "ctet-p1-2019-a-environmental-studies-q082": {
        "prompt": {
            "hi": "NCF-2005 के अनुसार निम्नलिखित में से क्या प्राथमिक स्तर पर पर्यावरण अध्ययन शिक्षण का उद्देश्य नहीं होना चाहिए?",
            "en": "Which one of the following should NOT be the objective of teaching EVS at primary level as per NCF-2005?",
        }
    },
    # The 5-number data list is required to answer (third of the five) and had
    # been dropped from the English column.
    "ctet-p1-2019-a-mathematics-q042": {
        "prompt": {
            "hi": "आरोही क्रम में व्यवस्थित करने पर निम्नलिखित में से कौन सी संख्या तृतीय स्थान पर होगी? 7.07, 7.70, 7.707, 7.007, 0.77",
            "en": "Which of the following is at third place when the numbers are arranged in ascending order? 7.07, 7.70, 7.707, 7.007, 0.77",
        }
    },
    # Flattened mixed-number fraction destroyed the stem ("2 4" = 2/3 + 4/5;
    # corroborated by distractor 6/8 = numerator+denominator addition).
    "ctet-p1-2018-m-mathematics-q046": {
        "prompt": {
            "hi": "2/3 + 4/5 का मान क्या है?",
            "en": "What is the value of 2/3 + 4/5?",
        }
    },
    # Statement (A) marker had been dropped from the Hindi column; option (a)
    # also carried stray OCR noise ("दोनों एवं सही हैं").
    "ctet-p1-2024-i-environmental-studies-q071": {
        "prompt": {
            "hi": (
                "निम्नलिखित कथन (A) तथा कथन (B) को ध्यान से पढ़ें तथा सही विकल्प का चुनाव करें। "
                "(A) लगभग 4700 वर्ष पूर्व सिंधु तथा इसकी सहायक नदियों के किनारे कुछ आरंभिक नगर "
                "फले-फूले। (B) गंगा तथा इसकी सहायक नदियों के किनारे नगरों का विकास लगभग 1500 "
                "वर्ष पूर्व हुआ।"
            )
        },
        "options": {
            "a": {"hi": "(A) और (B) दोनों सही हैं।", "en": "Both (A) and (B) are true."}
        },
    },
    # ---- Rule 5: option-D contamination (leaked passage / OMR instructions) --
    "ctet-p1-2026-e-lang1-en-q099": {
        "options": {"d": {"en": "in proper order"}}
    },
    "ctet-p1-2026-e-lang2-en-q128": {
        "options": {"d": {"en": "was happy and smiling."}}
    },
    "ctet-p1-2026-e-lang2-hi-q128": {
        "options": {"d": {"hi": "सत्ता की सीमाएँ निर्धारित करने"}}
    },
    "ctet-p1-2026-e-lang2-hi-q150": {
        "options": {"d": {"hi": "कार्यालयी भाषा में"}}
    },
    # Duplicated statement-code options (OCR lost the leading code of both);
    # the four choices are the choose-3 combinations of statements A-D.
    "ctet-p1-2024-i-environmental-studies-q064": {
        "options": {
            "a": {"hi": "(A), (B) और (C)", "en": "(A), (B) and (C)"},
            "b": {"hi": "(B), (C) और (D)", "en": "(B), (C) and (D)"},
            "c": {"hi": "(A), (C) और (D)", "en": "(A), (C) and (D)"},
            "d": {"hi": "(A), (B) और (D)", "en": "(A), (B) and (D)"},
        }
    },
    # ---- 2021-Dec dropped Hindi code options ------------------------------
    "ctet-p1-2021-dec-d-cdp-q003": {
        "options": {
            "a": {"hi": "(i)"},
            "b": {"hi": "(ii)"},
        },
        "prompt": {
            "hi": "निम्नलिखित में से कौन-सी प्रवृत्ति/गुण पूर्णत: आनुवांशिक है? (i) आँखों का रंग (ii) बुद्धि (iii) नैतिक विकास (iv) सामाजिक कौशल",
            "en": "Which of the following traits are determined solely by heredity? (i) Colour of eyes (ii) Intelligence (iii) Moral development (iv) Social skills",
        },
    },
    "ctet-p1-2021-dec-d-cdp-q017": {
        "options": {
            "a": {"hi": "(i), (iii), (iv)"},
            "b": {"hi": "(i), (iii)"},
            "c": {"hi": "(i), (ii)"},
            "d": {"hi": "(i), (ii), (iv)"},
        }
    },
    "ctet-p1-2021-dec-d-mathematics-q043": {
        "options": {
            "a": {"hi": "UGJTF"},
            "b": {"hi": "VGHSD"},
            "c": {"hi": "XIJUF"},
            "d": {"hi": "XGJSF"},
        }
    },
    # ---- Rule 7: remaining non-canonical A/R phrasings --------------------
    "ctet-p1-2021-dec-d-cdp-q014": {
        "prompt": {
            "hi": (
                "**अभिकथन (A):** एक अध्यापक को कक्षा की सामाजिक सांस्कृतिक, धार्मिक और भाषीय "
                "विविधता को समझना चाहिए।\n**कारण (R):** कक्षा में विद्यार्थी एक समरूप समूह गठित "
                "करते हैं।\nसही विकल्प का चयन कीजिए:"
            )
        }
    },
    "ctet-p1-2024-i-environmental-studies-q077": {
        "prompt": {
            "hi": (
                "**अभिकथन (A):** रेशम का कीड़ा अपनी मादा को उसकी गंध से कई किलोमीटर दूर से ही "
                "पहचान लेता है।\n**कारण (R):** कुछ मादा कीड़ें ‘फैरीमोनस्’ छोड़ते हैं जिसके गंध को "
                "नर कीड़े पहचान लेते हैं।\nसही विकल्प का चयन कीजिए:"
            ),
            "en": (
                "**Assertion (A):** Silkworm can find his female worm from many kilometers away "
                "by her smell.\n**Reason (R):** Some female insects release 'Pheromones' which can "
                "be recognised by their males by smell.\nChoose the correct option:"
            ),
        }
    },
    # ---- Rule 7: recovery of A/R texts mangled by early normalize passes ----
    # (word-level "Reason/कारण/तर्क" mentions were wrongly rewritten as markers)
    "ctet-p1-2023-e-lang1-hi-q115": {
        "prompt": {
            "hi": (
                "**अभिकथन (A):** विद्यालय में प्रवेश करने वाले सभी बच्चे अपनी आयु अनुसार भाषा के "
                "सक्षम प्रयोगकर्ता होते हैं।\n**कारण (R):** भाषिक और सांस्कृतिक विविधता के कारण वे "
                "अपनी योग्यताओं का प्रदर्शन नहीं कर पाते हैं।\nसही विकल्प का चयन कीजिए:"
            )
        }
    },
    "ctet-p1-2024-i-cdp-q010": {
        "prompt": {
            "hi": (
                "**अभिकथन (A):** लॉरेंस कोहलबर्ग के नैतिक विकास सिद्धान्त में बच्चे कार्यों को "
                "उनके परिणाम के आधार पर अच्छा या बुरा समझने से, इस समझ पर पहुँचते हैं कि नियम "
                "और कानून नम्य हैं और बदले जा सकते हैं।\n**कारण (R):** लॉरेंस कोहलबर्ग का तर्क है "
                "कि नैतिक विकास क्रमिक रूप से चरणों में होता है।\nसही विकल्प का चयन कीजिए:"
            )
        }
    },
    "ctet-p1-2024-i-cdp-q018": {
        "prompt": {
            "en": (
                "**Assertion (A):** School curriculum should give reasonable space and value to "
                "learner's cultural knowledges'.\n**Reason (R):** Supporting students to uphold "
                "their cultural identities facilitates learning.\nChoose the correct option:"
            )
        }
    },
    "ctet-p1-2026-e-environmental-studies-q065": {
        "prompt": {
            "hi": (
                "**अभिकथन (A):** समुदायों का सांस्कृतिक स्रोत भी बच्चे के अधिगम के लिए बहुत "
                "जरूरी है। लोक कथाएँ, लोकगीत, चुटकुले, कला आदि बच्चे की भाषा और उसके ज्ञान को "
                "समृद्ध बनाते हैं।\n**कारण (R):** बच्चे का स्थानीय परिवेश केवल भौतिक या प्राकृतिक "
                "ही नहीं होता है बल्कि उसका सामाजिक-सांस्कृतिक परिवेश भी स्थानीय होता है।\n"
                "सही विकल्प का चयन कीजिए:"
            ),
            "en": (
                "**Assertion (A):** The cultural resources of the communities are also very "
                "important for the learning of the child. Folk tales, folk songs, jokes, art etc. "
                "enrich the language and knowledge of the child.\n**Reason (R):** The local "
                "environment of the child is not only physical or natural, but his socio-cultural "
                "environment is also local.\nChoose the correct option:"
            ),
        }
    },
    "ctet-p1-2026-e-environmental-studies-q072": {
        "prompt": {
            "hi": (
                "**अभिकथन (A):** बच्चे की स्थानीय वस्तुएँ एक स्वाभाविक अधिगम का स्रोत हैं जिन्हें "
                "कक्षा में प्रधानता देनी चाहिए।\n**कारण (R):** जब स्कूल के अंदर और उसके आसपास का "
                "जीवंत संसार चिंतन के लिए उपलब्ध होगा, बच्चे पर्यावरण के मुद्दों के प्रति सचेत "
                "होंगे और उनके प्रति अपनी रुचि को पोषित कर पाएँगे।\nसही विकल्प का चयन कीजिए:"
            ),
            "en": (
                "**Assertion (A):** The child’s local objects are a natural source of learning "
                "which should be given primacy in the classroom.\n**Reason (R):** When the living "
                "world in and around the school is available for contemplation, children will be "
                "aware of environmental issues and will be able to nurture their interest in "
                "them.\nChoose the correct option:"
            ),
        }
    },
    "ctet-p1-2026-e-environmental-studies-q077": {
        "prompt": {
            "hi": (
                "**अभिकथन (A):** अगर अलग-अलग क्षेत्रों का इतिहास देखें तो हमें पता चलेगा कि किस "
                "तरह विभिन्न सांस्कृतिक प्रभावों ने वहाँ के जीवन और संस्कृति को आकार देने में "
                "मदद किया है।\n**कारण (R):** इस तरह से कई क्षेत्र अपने विशिष्ट इतिहास के कारण "
                "विविधतासंपन्न हो जाते थे, उदाहरण के लिए लद्दाख एवं केरल।\nसही विकल्प का "
                "चयन कीजिए:"
            ),
            "en": (
                "**Assertion (A):** The history of many places show us how many different cultural "
                "influences have helped to shape life and culture there.\n**Reason (R):** Thus "
                "regions became very diverse because of their unique history for example Laddakh "
                "and Kerala.\nChoose the correct option:"
            ),
        }
    },
    # ---- Rule 6: nested-brace LaTeX residue (see also latex_to_unicode) ----
    "utet-p1-2026-mathematics-q102": {
        "prompt": {
            "hi": "1/(1 + √2) + 1/(√2 + √3) + ... + 1/(√15 + √16) का मान क्या है?",
            "en": "What is the value of 1/(1 + √2) + 1/(√2 + √3) + ... + 1/(√15 + √16)?",
        }
    },
}

# Questions whose stems lost the multi-statement markers in Hindi; the full
# stem text is provided here after OCR forensics.
STEM_MARKER_FIXES: dict[str, dict[str, str]] = {
    "ctet-p1-2021-dec-d-cdp-q017": {
        "hi": (
            "निम्नलिखित में से कौन-सी युक्ति अधिगम नि:शक्तता वाले विद्यार्थियों के समावेशन के सफल "
            "क्रियान्वयन हेतु प्रभावशाली है? (i) विषयवस्तु के प्रस्तुतिकरण के लिए बहुविध साधनों का "
            "प्रयोग। (ii) विद्यार्थी की आवश्यकता के अनुसार वैयक्तिक शैक्षिक योजना को समुन्नत करना। "
            "(iii) प्रक्रिया उन्मुख अधिगम के बजाय उत्पादन उन्मुख लक्ष्य को बढ़ावा देना। (iv) सभी "
            "विद्यार्थियों के लिए एक समान मानक निर्धारित करना और कक्षा में विविधता की अनदेखी करना।"
        ),
    },
}


# --------------------------------------------------------------------------- #
# Pipeline                                                                    #
# --------------------------------------------------------------------------- #

def iter_text_blocks(record: dict, key: str):
    blocks = record.get(key)
    if isinstance(blocks, list):
        for block in blocks:
            if isinstance(block, dict) and isinstance(block.get("text"), dict):
                yield block["text"]


def repair_question(question: dict, log: list[str]) -> bool:
    changed = False
    original = json.dumps(question, ensure_ascii=False, sort_keys=True)

    # 1. visarga-as-colon typography
    for textmap in iter_text_blocks(question, "prompt"):
        for loc, text in list(textmap.items()):
            textmap[loc] = VISARGA_COLON_RE.sub(":", text)
    for option in question.get("options") or []:
        for textmap in iter_text_blocks(option, "content"):
            for loc, text in list(textmap.items()):
                textmap[loc] = VISARGA_COLON_RE.sub(":", text)

    # 2. LaTeX -> Unicode
    for textmap in iter_text_blocks(question, "prompt"):
        for loc, text in list(textmap.items()):
            textmap[loc] = latex_to_unicode(text)
    for option in question.get("options") or []:
        for textmap in iter_text_blocks(option, "content"):
            for loc, text in list(textmap.items()):
                textmap[loc] = latex_to_unicode(text)

    # 3. trailing section artifacts
    for textmap in iter_text_blocks(question, "prompt"):
        for loc, text in list(textmap.items()):
            textmap[loc] = strip_section_artifact(text)
    for option in question.get("options") or []:
        for textmap in iter_text_blocks(option, "content"):
            for loc, text in list(textmap.items()):
                textmap[loc] = strip_section_artifact(text)

    # 4. corrupted Assertion/Reason option fragments + dangling "(A) दोनों"
    for option in question.get("options") or []:
        for textmap in iter_text_blocks(option, "content"):
            for loc, text in list(textmap.items()):
                textmap[loc] = strip_doubled_a_prefix(restore_ar_option(text))

    # 5. statement-code case normalisation
    uppercase_statement_codes(question)

    # 6. explicit content fixes
    fixes = CONTENT_FIXES.get(question.get("id", ""), {})
    prompt_fix = fixes.get("prompt")
    if prompt_fix:
        for textmap in iter_text_blocks(question, "prompt"):
            for loc, text in prompt_fix.items():
                if loc in textmap:
                    textmap[loc] = text
    option_fix = fixes.get("options")
    if option_fix:
        for option in question.get("options") or []:
            patch = option_fix.get(option.get("id"))
            if not patch:
                continue
            for textmap in iter_text_blocks(option, "content"):
                for loc, text in patch.items():
                    if loc in textmap:
                        textmap[loc] = text
    stem_fix = STEM_MARKER_FIXES.get(question.get("id", ""))
    if stem_fix:
        for textmap in iter_text_blocks(question, "prompt"):
            for loc, text in stem_fix.items():
                if loc in textmap:
                    textmap[loc] = text

    # 7. assertion-reason canonical format (after explicit fixes)
    canonicalize_assertion_reason(question)

    # 8. multi-statement line splitting (non-assertion prompts)
    for textmap in iter_text_blocks(question, "prompt"):
        for loc, text in list(textmap.items()):
            is_ar = AR_MARKER_HI.search(text) if loc == "hi" else AR_MARKER_EN.search(text)
            if not is_ar and not text.startswith("**"):
                textmap[loc] = split_statements(text)

    return json.dumps(question, ensure_ascii=False, sort_keys=True) != original


def process_file(path: Path, dry_run: bool, log: list[str]) -> tuple[int, int]:
    rows = []
    raw = path.read_text(encoding="utf-8")
    changed_rows = 0
    for line_no, line in enumerate(raw.splitlines(), 1):
        if not line.strip():
            continue
        row = json.loads(line)
        if repair_question(row, log):
            changed_rows += 1
            log.append(f"{path.relative_to(REPO_ROOT)}:{line_no}: {row.get('id')}")
        rows.append(row)
    total = len(rows)
    if changed_rows and not dry_run:
        with path.open("w", encoding="utf-8") as handle:
            for row in rows:
                handle.write(json.dumps(row, ensure_ascii=False) + "\n")
    return total, changed_rows


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    log: list[str] = []
    total_rows = 0
    total_changed = 0
    for path in sorted(BANK.glob("exams/**/questions.ndjson")):
        rows, changed = process_file(path, args.dry_run, log)
        total_rows += rows
        total_changed += changed
    print(f"questions scanned : {total_rows}")
    print(f"records changed   : {total_changed}{' (dry-run)' if args.dry_run else ''}")
    for entry in log:
        print("  ", entry)
    return 0


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.exit(main())

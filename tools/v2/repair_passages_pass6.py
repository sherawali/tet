#!/usr/bin/env python3
"""Cleanup pass 6 — restore authentic passages into the remaining fabricated /
truncated CTET stimuli.

Unlike passes 3-5 this script is a *registry*: RESTORATIONS is keyed by stimulus
id and each entry carries its own provenance, so later sessions append entries
instead of writing a new pass file per cycle. Idempotent, fails fast if an id is
absent from the bank or if a linked question still cannot be answered from the
new text.

Every entry must answer these before it goes in:
  1. Where does the text come from (paper PDF / booklet reproduction / author)?
  2. Which words or facts do the linked questions demand, and are they present?
  3. Does the group really need a passage at all? (see repair_unlink_pass5.py)

Run: python3 tools/v2/repair_passages_pass6.py
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EXAMS = ROOT / "bank-v2" / "exams"

failures: list[str] = []
applied: list[str] = []
changed: list[str] = []


def load(path: Path) -> list[dict]:
    return [json.loads(l) for l in path.read_text(encoding="utf-8").splitlines() if l.strip()]


def save(path: Path, rows: list[dict]) -> None:
    path.write_text("\n".join(json.dumps(r, ensure_ascii=False) for r in rows) + "\n", encoding="utf-8")
    changed.append(str(path.relative_to(ROOT)))


def texts(node, out):
    if isinstance(node, dict):
        for k, v in node.items():
            if k == "text" and isinstance(v, dict):
                out.extend(s for s in v.values() if isinstance(s, str))
            else:
                texts(v, out)
    elif isinstance(node, list):
        for x in node:
            texts(x, out)


# ============================================================================ #
# REGISTRY                                                                     #
# ============================================================================ #
# entry = dict(
#   file    : stimuli.ndjson path holding the stimulus
#   loc     : locale key to write ("hi" | "en" | "sa")
#   text    : the authentic passage
#   src     : provenance, one line
#   must    : substrings the linked questions demand; asserted before writing
#   minQ    : optional minimumQuestions correction
#   instr   : optional instruction-line correction
# )
RESTORATIONS: dict[str, dict] = {}

# --------------------------------------------------------------------------- #
# CTET 09-Dec-2018 Paper-I, Language-I Hindi, Q97-105 — गीत-कविता             #
# --------------------------------------------------------------------------- #
# The slot held a 318-char invented essay ("मानव-इतिहास में ऐसे अनेक उदाहरण…")
# about परोपकार/त्याग, which nothing in Q97-105 refers to. The real अनुच्छेद is
# about why parents and schools refuse to let गीत-कविता live inside children's
# lives (NCERT language-pedagogy prose).
# Sources cross-merged: testbook.com/question-answer/ques--60a78c29f445f1e2f831d702
# carries both paragraphs in full; theexampillar.com CTET 2018 Language-I Hindi
# page carries the same text but drops the block between "कक्षाओं की" and
# "दूसरी ओर". Testbook used as the base, theexampillar used to repair its typos
# ("चाहते है" -> "चाहते हैं", missing comma after "व्यापक सहमति है"). One clear
# OCR drop repaired: "चाहते हैं कि शिक्षक पहले …" (the subordinating कि is
# absent from both reproductions but the clause cannot stand without it).
# Question demands verified present: 'कविताएँ सुनी और सुनायी जाएँ' (Q103 क्रिया),
# 'सांस्कृतिक' (Q104 प्रत्यय), 'मंज़ूर' (Q105 समानार्थी), व्यापक सहमति (Q99),
# राह से भटक जाएँगे (Q101), पाठ्य-पुस्तक से बाहर (Q98), सोची हुई मंज़िल (Q102),
# जीवन-शैली का स्वाभाविक हिस्सा (Q99 option 1).
RESTORATIONS["ctet-p1-2018-stimulus-hi-pr-97"] = dict(
    file=EXAMS / "ctet/paper-1/language-1/hindi/stimuli.ndjson",
    loc="hi",
    src="testbook QnA 60a78c29f445f1e2f831d702 (full 2 paragraphs) + theexampillar "
        "CTET 2018 Language-I Hindi (typo repairs)",
    must=["कविताएँ सुनी और सुनायी जाएँ", "सांस्कृतिक", "मंज़ूर", "व्यापक सहमति",
          "राह से भटक जाएँगे", "पाठ्य-पुस्तक से बाहर", "सोची हुई मंज़िल",
          "जीवन-शैली का स्वाभाविक हिस्सा"],
    text=(
        "राष्ट्रीय पर्वों और सांस्कृतिक समारोहों के दौरान गीत गाए जाएँ, कविताएँ सुनी और सुनायी जाएँ, "
        "इसे लेकर माता-पिताओं, स्कूल और समाज में व्यापक सहमति है, लेकिन गीत-कविताएँ बच्चों के जीवन में "
        "रच-बस जाएँ, वे उनका भरपूर आनंद लेने लगें, खुद तुकबंदियाँ करने लगें, रचने लगें, यह माता-पिता को "
        "मंज़ूर नहीं। माता को लगता है, ऐसा करते हुए तो वे उस राह से भटक जाएँगे जिस राह पर वे उन्हें चलाना "
        "चाहते हैं। जिस राह से वे उन्हें अपनी सोची हुई मंज़िल पर पहुँचाना चाहते हैं। उनकी इस इच्छा में यह "
        "निहित है कि बच्चे वैसा कुछ भी नहीं करें जो वे करना चाहते हैं, बल्कि वे वैसा करें जैसा माता-पिता "
        "चाहते हैं। उनके भीतर बच्चे के स्वतंत्रतापूर्वक सीखने की प्रक्रिया के प्रति सतत संदेह और गहरा डर "
        "बना रहता है। यही हाल स्कूल का भी है। गीत-कविता स्कूल और कक्षाओं की रोज़मर्रा की गतिविधि का हिस्सा "
        "बन जाए, यह स्कूल को मंज़ूर नहीं। स्कूल को लगता है, इस सबके लिए समय कहाँ है। यह पाठ्य-पुस्तक से "
        "बाहर की गतिविधि है। शिक्षक और शिक्षा अधिकारी चाहते हैं कि शिक्षक पहले परीक्षा परिणाम बेहतर लाने के "
        "लिए काम करें।\n\n"
        "दूसरी ओर हमारी संस्कृति और समाज में गीत-कविता की जो जगहें थीं, वे जगहें लगातार सीमित हुई हैं। "
        "गीत गाने, सुनने-सुनाने के अवसर हुआ करते थे, वे अवसर ही गीत-कविताओं को गुनगुनाते रह सकने के लिए "
        "याद करने को प्रेरित करते थे। सहेजने और रचने के लिए प्रेरित करते थे। उनमें कुछ जोड़ने के लिए प्रेरित "
        "करते थे। इस सबके लिए अतिरिक्त प्रयासों की ज़रूरत नहीं पड़ती थी, वह जीवन-शैली का स्वाभाविक हिस्सा "
        "था। बच्चों के लिए पढ़ाई से अधिक खेलने-कूदने के लिए समय और जगहें थीं। खेलने-कूदने की मस्ती के दौरान "
        "ही उनके बीच से स्वतः ही नये खेलों, तुकबंदियों और खेलगीतों और बालगीतों का सृजन भी हो जाया करता था। "
        "उनकी ये रचनाएँ चलन में आ जाया करती थीं, जबान पर चढ़ जाती थीं और सालों-साल उनकी टोलियों के बीच बनी "
        "रहती थीं। समय के साथ उनमें कुछ कमी पाए जाने पर संशोधित होती रहती थीं।"
    ),
)

# ============================================================================ #
# apply                                                                       #
# ============================================================================ #
# App renders no markdown: keep these out of restored passage text.
JUNK = re.compile(r"[*_|#`]|\|\s*---")

stores: dict[Path, list[dict]] = {}
idx: dict[str, tuple[Path, dict]] = {}
for entry in RESTORATIONS.values():
    p = entry["file"]
    if p not in stores:
        stores[p] = load(p)
        for r in stores[p]:
            idx[r["id"]] = (p, r)

# question files, to run the `must` assertion against what learners will see
qstores: dict[Path, list[dict]] = {}


def questions_for(sid: str) -> list[dict]:
    sp = RESTORATIONS[sid]["file"]
    qp = sp.parent / "questions.ndjson"
    if qp not in qstores:
        qstores[qp] = load(qp)
    return [r for r in qstores[qp] if r.get("stimulusId") == sid]


for sid, e in RESTORATIONS.items():
    if sid not in idx:
        failures.append(f"MISSING stimulus {sid}")
        continue
    text = e["text"]
    if JUNK.search(text):
        failures.append(f"{sid}: restored text contains markdown the app cannot render")
    for needle in e.get("must", []):
        if needle not in text:
            failures.append(f"{sid}: required text {needle!r} absent from the restoration")

    linked = questions_for(sid)
    if not linked:
        failures.append(f"{sid}: no question links to it — restore would create an orphan stimulus")
    mq = e.get("minQ")
    if mq is None and linked:
        mq = len(linked)

    _p, st = idx[sid]
    hit = False
    for blk in st.get("content", []):
        t = blk.get("text")
        if isinstance(t, dict):
            t[e["loc"]] = text
            hit = True
    if not hit:
        failures.append(f"{sid}: no content block to write into")
        continue
    if mq is not None:
        st["minimumQuestions"] = mq
    if e.get("instr"):
        if isinstance(st.get("instructions"), dict):
            st["instructions"][e["loc"]] = e["instr"]
        else:
            failures.append(f"{sid}: instructions correction requested but field is absent")
    applied.append(f"{sid}  ({len(text)} chars, {len(linked)} questions)  <- {e['src']}")

if failures:
    print("FAILURES (nothing written):")
    for f in failures:
        print("  -", f)
    sys.exit(1)

for p, rows in stores.items():
    save(p, rows)

print(f"Pass 6: restored {len(applied)} passage(s).")
for a in applied:
    print("  +", a)
print("files written:")
for c in sorted(set(changed)):
    print("  wrote", c)

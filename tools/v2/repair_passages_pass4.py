#!/usr/bin/env python3
"""Cleanup pass 4 — replace FABRICATED placeholder passages/poems with the
authentic source texts, cycle by cycle. Idempotent; fails fast on missing ids.

Background
----------
`tools/v2/import_all_ctet.py` hardcoded short generic "moral essay" paragraphs
for every cycle whose real passage was not present in the OCR source. Those
placeholders are still in the bank: a 7–9 question comprehension group cannot
be answered from a 150–350 character essay. This pass swaps each placeholder
for the text the questions were actually written against.

Cycle 1 (this revision): CTET Paper-I, 09 Dec 2018, English (Lang-I + Lang-II)

  ctet-p1-2018-stimulus-en-pr-91   -> "Castles" (6 paragraphs)
  ctet-p1-2018-stimulus-en-po-100  -> William Blake, "The Little Black Boy"
  ctet-p1-2018-stimulus-en-pr-121  -> "Necessity is the mother of invention"
  ctet-p1-2018-stimulus-en-pr-129  -> "Kevlar" (Stephanie Kwolek)

Structural fix found while sourcing: the 2018 Lang-II English comprehension
groups are 121-129 (maxim, 9 questions) and 130-135 (Kevlar, 6 questions) —
NOT 121-128 / 129-135. q129 asks the meaning of 'exhorting', a word that occurs
only in the maxim passage, so it is re-linked to the pr-121 stimulus and both
stimuli get corrected `minimumQuestions` + instruction ranges.

Answer keys touched by this cycle are NOT set here — they go through
`tools/v2/answer_rekey.json` + `tools/v2/apply_answer_keys.py` as usual.

Run: python3 tools/v2/repair_passages_pass4.py
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BANK = ROOT / "bank-v2" / "exams"

failures: list[str] = []
changed: list[str] = []
applied: list[str] = []


def load(path: Path) -> list[dict]:
    return [json.loads(l) for l in path.read_text(encoding="utf-8").splitlines() if l.strip()]


def save(path: Path, rows: list[dict]) -> None:
    path.write_text("\n".join(json.dumps(r, ensure_ascii=False) for r in rows) + "\n", encoding="utf-8")
    changed.append(str(path.relative_to(ROOT)))


def set_loc(rec: dict, where: str, loc: str, new: str) -> None:
    targets = []
    if where == "prompt":
        for blk in rec.get("prompt", []):
            if isinstance(blk.get("text"), dict):
                targets.append(blk["text"])
    elif where == "content":
        for blk in rec.get("content", []):
            if isinstance(blk.get("text"), dict):
                targets.append(blk["text"])
    elif where.startswith("opt:"):
        oid = where.split(":", 1)[1]
        for opt in rec.get("options", []):
            if opt.get("id") == oid:
                for blk in opt.get("content", []):
                    if isinstance(blk.get("text"), dict):
                        targets.append(blk["text"])
    if not targets:
        failures.append(f"NO TARGET {rec.get('id')} where={where} loc={loc}")
        return
    for t in targets:
        t[loc] = new


# ---------------------------------------------------------------- file registry
F_L1EN_Q = BANK / "ctet/paper-1/language-1/english/questions.ndjson"
F_L1EN_S = BANK / "ctet/paper-1/language-1/english/stimuli.ndjson"
F_L2EN_Q = BANK / "ctet/paper-1/language-2/english/questions.ndjson"
F_L2EN_S = BANK / "ctet/paper-1/language-2/english/stimuli.ndjson"

STORE: dict[Path, list[dict]] = {}
IDX: dict[str, dict] = {}
for p in [F_L1EN_Q, F_L1EN_S, F_L2EN_Q, F_L2EN_S]:
    rows = load(p)
    STORE[p] = rows
    for r in rows:
        if r["id"] in IDX:
            failures.append(f"DUPLICATE ID {r['id']}")
        IDX[r["id"]] = r


def rec(rid: str) -> dict:
    if rid not in IDX:
        failures.append(f"MISSING {rid}")
        return {}
    return IDX[rid]


# ============================================================================ #
# 1) CTET 09-Dec-2018 Paper-I, Language-I English, Q91-99 — "Castles"          #
# ============================================================================ #
# Source text: ereadingworksheets.com "Castles — Nonfiction Reading Test"
#   (https://www.ereadingworksheets.com/reading-comprehension-worksheets/castles/)
# Why this version and not testbook's 4-paragraph condensed rendering:
#   * official key for Q92 ("main idea in Paragraph 2") = (2) "It explains why
#     castles were first built in England and the military purposes they served"
#     — true only if Paragraph 2 is "Castles were originally built in England by
#     Norman invaders in 1066 ...". In the condensed rendering Paragraph 2 is the
#     list of purposes, which would make the key (4).
#   * Q92 distractor (3) "It shows how Norman lords were often scared and
#     frequently retreated" only exists as a distractor if the sentence "The
#     castles he built allowed the Norman lords to retreat to safety when
#     threatened by English rebellion." is in the passage — the condensed
#     rendering drops it.
#   * 'pinnacle' (Q99 antonym) is in Paragraph 1; 'vestiges' (Q98 synonym) is in
#     the closing paragraph. Both present.
CASTLES = "\n\n".join([
    "Palaces are known for their beauty and splendor, but they offer little protection against attacks. "
    "It is easy to defend a fortress, but fortresses are not designed with the comfort of a king or queen "
    "in mind. When it comes to structures that are both majestic and well-fortified, the classic European "
    "castle is the pinnacle of design. Across the ages castles changed, developed, and eventually fell out "
    "of use, but they still command the fascination of our culture.",

    "Castles were originally built in England by Norman invaders in 1066. As William the Conqueror advanced "
    "through England, he fortified key positions to secure the land he had taken. The castles he built "
    "allowed the Norman lords to retreat to safety when threatened by English rebellion. Castles also served "
    "as bases of operation for offensive attacks. Troops were summoned to, organized around, and deployed "
    "from castles. In this way castles served both offensive and defensive roles in military operations.",

    "Not limited to military purposes, castles also served as offices from which the lord would administer "
    "control over his fiefdom. That is to say, the lord of the land would hold court in his castle. Those "
    "that were socially beneath the lord would come to report the affairs of the lands that they governed "
    "and pay tribute to the lord. They would address disputes, handle business, feast, and enjoy "
    "festivities. In this way castles served as important social centers in medieval England. Castles also "
    "served as symbols of power. Built on prominent sites overlooking the surrounding areas, castles "
    "constantly loomed in the background of many peasants' lives and served as a daily reminder of the "
    "lord's strength.",

    "The first castles constructed in England were made from earth and timber. Those who constructed them "
    "took advantage of natural features, such as hills and rivers, to increase defenses. Since these "
    "castles were constructed from wood, they were highly susceptible to attacks by fire. Wooden castles "
    "were gradually replaced by stone, which greatly increased the strength of these fortifications; "
    "however, being made from stone did not make these castles entirely fireproof. Attackers could hurl "
    "flaming objects into the castle through the windows or ignite the wooden doors. This led to moving the "
    "windows and entrances off of the ground floor and up to the first floor to make them more difficult to "
    "access.",

    "As the nobility accumulated wealth, England became increasingly attractive to those who sought to "
    "plunder. Raids by Vikings and other marauders increased in regularity. In response to these attacks, "
    "castle defenses were updated and improved. Arrow-slits were added. These were small holes in the "
    "castle, large enough for an arrow to fit through, which allowed defenders to fire from nearly "
    "invulnerable positions. Towers were built from which defenders could provide flanking fire. These "
    "towers were connected to the castle by wooden bridges, so that if one tower fell, the rest of the "
    "castle was still easy to defend. Multiple rings of castle walls were constructed, so that even if "
    "attackers made it past one wall, they would be caught on a killing ground between inner and outer "
    "walls. Advances such as these greatly increased the defense of castles.",

    "The demise of castles can ultimately be attributed to gunpowder. Gunpowder was first introduced to "
    "Europe during the 14th century, but the first gunpowder weapons were unreliable, inaccurate, and weak "
    "by later standards. During the 15th century, artillery became powerful enough to break through stone "
    "walls. This greatly undermined the military role of castles. Castles were then replaced by artillery "
    "forts that had no role in civil administration, and country houses that were indefensible. Though "
    "castles no longer serve their original purposes, remaining castles receive millions of visitors each "
    "year from those who wish to experience these majestic vestiges of a time long passed.",
])

st = rec("ctet-p1-2018-stimulus-en-pr-91")
if st:
    set_loc(st, "content", "en", CASTLES)
    applied.append("ctet-p1-2018-stimulus-en-pr-91 = 'Castles' (6 paragraphs)")


# ============================================================================ #
# 2) CTET 09-Dec-2018 Paper-I, Language-I English, Q100-105 — Blake poem       #
# ============================================================================ #
# The slot held Masefield's "Sea Fever", which none of Q100-105 refers to.
# Q100-105 quote "the southern wild", "bereav'd of light", "like a shady grove",
# "a cloud", "learn to bear the beams of love" and name the speaker
# 'The Little Black Boy' — i.e. William Blake, Songs of Innocence (1789),
# public domain. Full seven stanzas restored.
BLAKE_LITTLE_BLACK_BOY = "\n\n".join([
    "My mother bore me in the southern wild,\n"
    "And I am black, but O! my soul is white;\n"
    "White as an angel is the English child:\n"
    "But I am black as if bereav'd of light.",

    "My mother taught me underneath a tree\n"
    "And sitting down before the heat of day,\n"
    "She took me on her lap and kissed me,\n"
    "And pointing to the east began to say.",

    "Look on the rising sun: there God does live\n"
    "And gives his light, and gives his heat away.\n"
    "And flowers and trees and beasts and men receive\n"
    "Comfort in morning joy in the noonday.",

    "And we are put on earth a little space,\n"
    "That we may learn to bear the beams of love,\n"
    "And these black bodies and this sun-burnt face\n"
    "Is but a cloud, and like a shady grove.",

    "For when our souls have learn'd the heat to bear\n"
    "The cloud will vanish we shall hear his voice.\n"
    "Saying: come out from the grove my love & care,\n"
    "And round my golden tent like lambs rejoice.",

    "Thus did my mother say and kissed me,\n"
    "And thus I say to little English boy.\n"
    "When I from black and he from white cloud free,\n"
    "And round the tent of God like lambs we joy:",

    "I'll shade him from the heat till he can bear,\n"
    "To lean in joy upon our fathers knee.\n"
    "And then I'll stand and stroke his silver hair,\n"
    "And be like him and he will then love me.",
])

st = rec("ctet-p1-2018-stimulus-en-po-100")
if st:
    set_loc(st, "content", "en", BLAKE_LITTLE_BLACK_BOY)
    if isinstance(st.get("title"), dict):
        st["title"]["en"] = "The Little Black Boy — William Blake"
    applied.append("ctet-p1-2018-stimulus-en-po-100 = Blake 'The Little Black Boy' (7 stanzas)")


# ============================================================================ #
# 3) CTET 09-Dec-2018 Paper-I, Language-II English, Q121-129 — maxim passage   #
# ============================================================================ #
MAXIM = (
    "Man who is believed to have evolved from apes, is a curious mixture of varied motives. He is not only "
    "the subject of needs but is also their creator. He not only seeks to satisfy his needs but also caters "
    "to his desire for beauty and grace. He is eager to satisfy his passion for more and more knowledge. "
    "Although in a general way, the maxim ‘necessity is the mother of invention’ is true, it is by no means "
    "the whole truth. Man is something much greater than an intelligent being using his intellect to make "
    "newer inventions from time to time. He has within him a spirit which is ever exhorting him to cut down "
    "his needs and learn to be happy with what he has. The real purpose underlying this maxim lies in its "
    "utility in the worldly sense. It tells us to be up and doing, not to be passive in our attitude to "
    "life. It asks us not to remain slaves of old habits and ways of life. We must face the new situations "
    "with a creative mind. Every new difficulty, every new problem, which confronts us in life, can be "
    "tackled successfully with the spirit of inventiveness."
)

st = rec("ctet-p1-2018-stimulus-en-pr-121")
if st:
    set_loc(st, "content", "en", MAXIM)
    st["minimumQuestions"] = 9
    if isinstance(st.get("instructions"), dict) and "en" in st["instructions"]:
        st["instructions"]["en"] = (
            "Direction: Read the passage given below and answer the questions that follow "
            "(Q. Nos. 121 to 129) by selecting the correct/most appropriate options."
        )
    applied.append("ctet-p1-2018-stimulus-en-pr-121 = maxim passage (121-129)")


# ============================================================================ #
# 4) CTET 09-Dec-2018 Paper-I, Language-II English, Q130-135 — Kevlar          #
# ============================================================================ #
KEVLAR = "\n\n".join([
    "Did you know that there is a fiber that is as flexible and lightweight as nylon yet five times stronger "
    "than steel? Did you know that this fabric is resistant to temperatures higher than 500 degrees "
    "Fahrenheit? Did you know that a woman invented this fiber? This miraculous fabric is called Kevlar and "
    "it is used to make everything from body armor to musical instruments.",

    "The year was 1964. There were gasoline shortages due to conflict in the Middle East. A Polish American "
    "chemist named Stephanie Louise Kwolek was working for DuPont, an American Chemical Company. She and her "
    "group were trying to make a lightweight, yet durable fiber to be used in tires. Lighter tires would "
    "allow vehicles to get better gas mileage, but the tires had to be strong enough to resist the wear and "
    "tear of the road. They had been working on the problem for some time and had little success, until "
    "Kwolek had a breakthrough. Kwolek and her group were synthesizing or creating fibers to test. During "
    "one of the steps in the process, Kwolek created a milky white solution by mixing two chemicals that "
    "were often used in the process. This solution was usually thrown away, but Kwolek convinced one of the "
    "technicians to help her test it. They were amazed to discover that the fabric that Kwolek had created "
    "was not only more durable than nylon, it was more durable than steel.",

    "Kwolek had invented Kevlar. Kevlar is a remarkable fabric known for its strength and durability. Since "
    "its invention it has found its way into a wide variety of products. Kevlar is used in sporting "
    "equipment like bike tires, bowstrings, and tennis racquets. It is used in musical instruments like drum "
    "heads, reeds, and speaker cones. And it is used in protective gear like motorcycle safety jackets, "
    "gloves, and shoes. However, Kevlar is best known for its ability to stop bullets.",

    "Richard Armellino created the first Kevlar bulletproof vest in 1975. It contained 15 layers of Kevlar, "
    "which could stop handgun and shotgun bullets. The vest also had a steel plate over the heart, which "
    "made the vest strong enough to stop rifle rounds. Vests like Armellino’s were quickly picked up by "
    "police forces and it is estimated that by 1990, half of all police officers in America wore "
    "bulletproof vests daily. By 2006 there were over 2,000 documented police vest ‘saves,’ or instances "
    "where officers were protected from deadly wounds by wearing bulletproof vests.",
])

st = rec("ctet-p1-2018-stimulus-en-pr-129")
if st:
    set_loc(st, "content", "en", KEVLAR)
    st["minimumQuestions"] = 6
    if isinstance(st.get("instructions"), dict) and "en" in st["instructions"]:
        st["instructions"]["en"] = (
            "Direction: Read the passage given below and answer the questions that follow "
            "(Q. Nos. 130 to 135) by selecting the correct/most appropriate options."
        )
    applied.append("ctet-p1-2018-stimulus-en-pr-129 = Kevlar passage (130-135)")


# ============================================================================ #
# 5) Re-link Q129 ('exhorting') to the maxim passage                           #
# ============================================================================ #
r = rec("ctet-p1-2018-m-lang2-en-q129")
if r:
    if r.get("stimulusId") != "ctet-p1-2018-stimulus-en-pr-121":
        r["stimulusId"] = "ctet-p1-2018-stimulus-en-pr-121"
        applied.append("ctet-p1-2018-m-lang2-en-q129 stimulusId -> pr-121 (maxim, not Kevlar)")


# ============================================================================ #
# 6) Restore the statements lost from Q124's prompt                            #
# ============================================================================ #
# Options are "Only I / Only I and II / Only III / Only II and III" but the
# statements themselves never survived the import. Restored verbatim from the
# 2018 Language-II English booklet. Roman numerals kept because the options
# refer to them by name.
r = rec("ctet-p1-2018-m-lang2-en-q124")
if r:
    set_loc(
        r, "prompt", "en",
        "Which of the following statements is/are true in the context of the passage?\n"
        "I. Man should be passive in his attitude to life.\n"
        "II. Spirit of inventiveness may not stand in good stead in solving every new problem.\n"
        "III. Man has a passion for more and more knowledge.",
    )
    applied.append("ctet-p1-2018-m-lang2-en-q124 statements I/II/III restored")


# ============================================================================ #
# write back                                                                  #
# ============================================================================ #
if failures:
    print("FAILURES (nothing written):")
    for f in failures:
        print("  -", f)
    sys.exit(1)

for p, rows in STORE.items():
    save(p, rows)

print("Pass 4 (2018 English cycle) applied:")
for a in applied:
    print("  +", a)
print("files written:")
for c in changed:
    print("  wrote", c)

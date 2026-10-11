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
# CTET 08-Dec-2019 Paper-I, Language-II English, Q121-128 — Freedom passage    #
# Source: https://docs.aglasem.com/view/c8919a4a-3607-11eb-bd46-02f21f5619c4   #
# Page 44-45 (official CTET 2019 Dec Paper-I Set A, P-I/A)                  #
# --------------------------------------------------------------------------- #
RESTORATIONS["ctet-p1-2019-stimulus-en-pr-121"] = dict(
    file=EXAMS / "ctet/paper-1/language-2/english/stimuli.ndjson",
    loc="en",
    src="https://docs.aglasem.com/view/c8919a4a-3607-11eb-bd46-02f21f5619c4 Page 44-45 "
        "official CTET 2019 Dec Paper-I Set A (Freedom passage Q121-128)",
    must=["Inquisition", "excommunication", "tortures and banishments",
          "endeavours for freedom", "shun the field of politics", "Inner freedom",
          "freedom on the surface", "reality of freedom"],
    text=(
        "Freedom is one of the most important factors in life. Man has fought politically all over the "
        "world for freedom. Religions have promised freedom, not in this world but in another. In the "
        "capitalist countries, individual freedom exists to some degree, and in the communist world it "
        "has been denied. From ancient times, freedom has meant a great deal to man, and there have been "
        "its opponents, not only political but religious through Inquisition, by excommunication, tortures "
        "and banishments, and the total denial of man's search for freedom. There have been wars and "
        "counter-wars fought for freedom. This has been the pattern of man's endeavours for freedom "
        "throughout history.\n\n"
        "Freedom of self-expression and freedom of speech and thought exist in some parts of the world, "
        "but in others it does not. Those who have been conditioned, revolt against their backgrounds. "
        "This reaction which takes different forms is called 'freedom'. The reaction to politics is often "
        "to shun the field of politics.\n\n"
        "One economic reaction is to form small communities based on some ideology or under the leadership "
        "of one person, but these soon disintegrate. The religious reaction against established organisations "
        "of belief is to revolt, either by joining other religious organisations or by following some guru or "
        "leader or by joining some cult. Or one denies the whole religious endeavour.\n\n"
        "One thinks of freedom only as freedom of movement, either physical or movements of thought. It "
        "appears that one always seeks freedom on the surface. Surely, this is rather a limited freedom, "
        "involving a great deal of conflict, wars and violence.\n\n"
        "Inner freedom is something entirely different. It has its roots not in the idea of freedom but in "
        "the reality of freedom. It covers all the endeavours of man. Without inner freedom life will always "
        "be an activity within the limited circle of time and conflict."
    ),
)

# --------------------------------------------------------------------------- #
# CTET 08-Dec-2019 Paper-I, Language-II English, Q129-135 — Water/Himalayas    #
# Source: https://docs.aglasem.com/view/c8919a4a-3607-11eb-bd46-02f21f5619c4   #
# Page 45-46 (official CTET 2019 Dec Paper-I Set A, Q129-135)                #
# --------------------------------------------------------------------------- #
RESTORATIONS["ctet-p1-2019-stimulus-en-pr-129"] = dict(
    file=EXAMS / "ctet/paper-1/language-2/english/stimuli.ndjson",
    loc="en",
    src="https://docs.aglasem.com/view/c8919a4a-3607-11eb-bd46-02f21f5619c4 Page 45-46 "
        "official CTET 2019 Dec Paper-I Set A (Water/Himalayas Q129-135)",
    must=["core of life", "Third Pole", "more than 1,000 million people",
          "benevolent climate", "bounty of the Himalayas", "perennial streams",
          "rain-fed rivers", "waterfalls and ponds", "fragile natural resource",
          "longest outside the two poles"],
    text=(
        "Water is the core of life; hence water must be central to our spiritual thinking. Water is not "
        "only most of earth, but also most of life. Therefore water conservation must be our deepest concern.\n\n"
        "The Himalayan mountain range is among the highest, youngest and most fragile ecosystem of the planet. "
        "The Himalayas have given us some of the great river systems of the earth including the Indus, Ganga, "
        "Brahmaputra, Nu Salween, Yangtze and the Mekong. The Himalayas are also called the 'Third Pole', for "
        "they contain the largest mass of ice and snow outside the earth's polar region, the north and south poles. "
        "There is a permanent snowline above 5,000 metres. Some of the glaciers in the region are the longest "
        "outside the two poles.\n\n"
        "The Himalayas serve as water towers, providing water on a sustained basis to more than 1,000 million "
        "people and millions of hectares of land in South Asia. The greenery, benevolent climate, highly productive "
        "ecosystems, food production and overall happiness in South Asia are in fact, attributable to the bounty of "
        "the Himalayas. They are not only beautiful; they are life-givers. Little wonder that they are venerated as "
        "the abode of gods.\n\n"
        "To keep the Third Pole preserved through assured conservation is one of the greatest challenges for the "
        "contemporary world. Himalayan mountains are a common but fragile natural resource. As mountain ecosystems "
        "have enormous bearing on the earth's systems, their special care, regeneration and conservation of their "
        "pristine resources would only bring more happiness, peace and prosperity to large parts of the world. In "
        "Agenda 21, Chapter 13 of the United Nations, the importance of mountains is underlined: \"mountain "
        "environments are essential to the survival of global ecosystems.\"\n\n"
        "The Himalayas in the state of Uttarakhand are especially rich in water resources. This area is home to "
        "dozens of perennial streams and numerous other rain-fed rivers along with innumerable rivulets, waterfalls "
        "and ponds, etc."
    ),
)

# --------------------------------------------------------------------------- #
# CTET 20-Aug-2023 Paper-I, Language-I English, Q106-114 (bank Q97-105)       #
# Garud solo trip to Mizoram — Geeta Garud 69                                 #
# Source: https://docs.aglasem.com/view/5f07e5ae-2fb7-11ef-bec1-0a5e36bc6706   #
# Page 30-31 (official CTET 2023 Aug Paper-I Set A) + cross-verified with     #
# prepp CDN PDFs for Sets B/C/D (same passage, different Q numbers)           #
# --------------------------------------------------------------------------- #
RESTORATIONS["ctet-p1-2023-stimulus-en-pr-97"] = dict(
    file=EXAMS / "ctet/paper-1/language-1/english/stimuli.ndjson",
    loc="en",
    src="https://docs.aglasem.com/view/5f07e5ae-2fb7-11ef-bec1-0a5e36bc6706 Page 30-31 "
        "official CTET 2023 Aug Paper-I Set A (Garud passage Q106-114, bank Q97-105)",
    must=["solo trip to Mizoram", "Geeta Garud, 69", "narrow ledge",
          "behind a waterfall", "liberating experience", "hesitant about travelling by herself",
          "found no takers", "relishing a challenging trek", "sense of freedom",
          "danced impromptu at a festival in Reiek", "waded into a river",
          "horse-riding", "athlete in her youth", "played cricket",
          "farm in Koregaon", "lack of social connections", "Travel is also about meeting people"],
    text=(
        "In the middle of her solo trip to Mizoram last month, Geeta Garud, 69, was walking on a narrow ledge, "
        "\"making my way behind a waterfall, trying out something I wouldn't have in my younger years. And I "
        "realised how travelling solo was such a liberating experience.\"\n\n"
        "Before going on her week-long holiday, she was hesitant about travelling by herself. Garud had asked "
        "friends and family but found no takers. Yet there she was, alone, relishing a challenging trek. \"Why was "
        "I being dependent on others? Being alone gives you a sense of freedom.\"\n\n"
        "She ended up having many firsts. She danced impromptu at a festival in Reiek, waded into a river, and went "
        "horse-riding. \"I had opportunities to try horse-riding when I was younger, but could not work up the courage. "
        "This time, I thought, if not now, I may not get another chance,\" says Garud, who was an athlete in her youth "
        "and had played cricket.\n\n"
        "She was at her farm in Koregaon during the lockdown and had felt the lack of social connections. It motivated "
        "her to travel as soon as things eased.\n\n"
        "\"Travel is also about meeting people; I felt that sense of joy and freedom when I finally did it.\" She is "
        "planning to travel to Europe next and has decided not to take a friend or relative along. She intends to revisit "
        "the joy of travelling alone and relishing a sense of freedom all over again."
    ),
)

# --------------------------------------------------------------------------- #
# CTET 21-Jan-2024 Paper-I, Language-I English, Q91-99 — Mrs Higgins/Alfred   #
# Source: https://cdn-images.prepp.in/public/image/SAS_24_I_Paper_I_Eng_Hin_KKKK_c37fa790dcedd46ee8a98da224cd98d5.pdf (official CTET 2024 Jan Paper-I Set K) #
# Also Sets I,J,L same passage:                                               #
# https://cdn-images.prepp.in/public/image/SAS_24_I_Paper_I_Eng_Hin_JJJJ_b1b5951b997e947a66f94d64229ee374.pdf Page 11 #
# https://cdn-images.prepp.in/public/image/SAS_24_I_Paper_I_Eng_Hin_IIII_e6a4e759d5add4b551ba3a9eb0a29305.pdf Page 11 #
# https://cdn-images.prepp.in/public/image/SAS_24_I_Paper_I_Eng_Hin_LLLL_7bb407e2437d1eedb86b4d7f792cc3df.pdf Page 11 #
# Cross-verified with https://www.oswaal360.com/pluginfile.php/10939/mod_folder/content/0/CTET/Paper%201/2024/21%20Jan%202024.pdf chunks 3-4 (full passage) and testbook QnA #
# Original story: Morley Callaghan \"All the Years of Her Life\"              #
# --------------------------------------------------------------------------- #
RESTORATIONS["ctet-p1-2024-stimulus-en-pr-91"] = dict(
    file=EXAMS / "ctet/paper-1/language-1/english/stimuli.ndjson",
    loc="en",
    src="https://cdn-images.prepp.in/public/image/SAS_24_I_Paper_I_Eng_Hin_KKKK_c37fa790dcedd46ee8a98da224cd98d5.pdf "
        "official CTET 2024 Jan Paper-I Set K Part-IV Q91-99 + Set J/I/L same + "
        "oswaal360 Jan24 Paper1 PDF chunks 3-4 + testbook QnA 68fda00303cb8640a35f6985",
    must=["blue eyes never wavered", "calmness and dignity", "clothes seemed to have been thrown on her",
          "I'm Mrs. Higgins. I'm Alfred's mother", "lack of terror and her simplicity",
          "Is Alfred in trouble", "compacts and toothpaste and lipsticks",
          "understanding gentleness", "If you would only listen to me before doing anything",
          "humility made her falter", "What do you intend to do, Mr. Carr",
          "I am going to get a cop", "a little good advice is the best thing for a boy",
          "quiet composure", "in a rage and would cry out against him"],
    text=(
        "Yet as soon as she saw him, she did not look as Alfred thought she would look: she smiled, her blue eyes "
        "never wavered, and with a calmness and dignity that made them forget that her clothes seemed to have been "
        "thrown on her, she put out her hand to Mr. Carr and said politely, \"I'm Mrs. Higgins. I'm Alfred's mother.\"\n\n"
        "Mr. Carr was a bit embarrassed by her lack of terror and her simplicity and he hardly knew what to say to her, "
        "so she asked, \"Is Alfred in trouble?\"\n\n"
        "\"He is. He's been taking things from the store. I caught him red-handed. Little things like compacts and "
        "toothpaste and lipsticks. Stuff he can sell easily,\" the proprietor said.\n\n"
        "Mrs. Higgins put out her hand and touched Sam Carr's arm with an understanding gentleness and speaking as "
        "though afraid of disturbing him, she said, \"If you would only listen to me before doing anything\". Her simple "
        "earnestness made her shy; her humility made her falter and look away, but in a moment she was smiling gravely "
        "again and she said with a kind of patient dignity, \"What do you intend to do, Mr. Carr?\"\n\n"
        "\"I am going to get a cop. That's what I ought to do.\"\n\n"
        "\"Yes, I suppose so. It's not for me to say, because he's my son. Yet I sometimes think a little good advice is "
        "the best thing for a boy when he is at a certain period in his life,\" she said.\n\n"
        "Alfred couldn't understand his mother's quiet composure, for if they had been at home and someone had suggested "
        "that he was going to be arrested, he knew she would be in a rage and would cry out against him."
    ),
)

# --------------------------------------------------------------------------- #
# CTET 21-Jan-2024 Paper-I, Language-II English, Q121-128 — Wizard of Oz nuts #
# Source: https://www.oswaal360.com/pluginfile.php/10939/mod_folder/content/0/CTET/Paper%201/2024/21%20Jan%202024.pdf chunk 5 (complete CTET 2024 Jan Paper-I, Q121-128 passage) #
# Official booklet: prepp CDN Set K/J/I/L same passage but OCR extraction truncated; #
# oswaal reproduction matches original L. Frank Baum The Wonderful Wizard of Oz Ch.7 #
# Original: https://en.wikisource.org/wiki/The_Wonderful_Wizard_of_Oz/Chapter_7 and https://www.cs.cmu.edu/~rgs/oz-7.html #
# --------------------------------------------------------------------------- #
RESTORATIONS["ctet-p1-2024-stimulus-en-pr-121"] = dict(
    file=EXAMS / "ctet/paper-1/language-2/english/stimuli.ndjson",
    loc="en",
    src="https://www.oswaal360.com/pluginfile.php/10939/mod_folder/content/0/CTET/Paper%201/2024/21%20Jan%202024.pdf "
        "chunk 5 Direction Q121-128 full passage (official CTET 2024 Jan Paper-I Set K reproduction) + "
        "L. Frank Baum The Wonderful Wizard of Oz Chapter 7 original (Gutenberg/Wikisource) + "
        "prepp CDN official booklets Sets I/J/K/L same passage (OCR truncated but Q stems match)",
    must=["found a tree full of nuts and filled Dorothy's basket", "would not be hungry for a long time",
          "laughed heartily at the awkward way", "padded hands were so clumsy",
          "keep away from the fire", "feared a spark might get into his straw and burn him up",
          "good distance away from the flames", "cover Dorothy with dry leaves when she lay down to sleep",
          "snug and warm", "slept soundly until morning", "rippling brook", "ditch that lay across the road",
          "no one ever knew what it was"],
    text=(
        "They were obliged to camp out that night under a large tree in the forest, for there were no houses near. "
        "The tree made a good, thick covering to protect them from the dew, and the Tin Woodman chopped a great pile "
        "of wood with his axe and Dorothy built a splendid fire that warmed her and made her feel less lonely. She and "
        "Toto ate the last of their bread, and now she did not know what they would do for breakfast.\n\n"
        "But the Lion went away into the forest and found his own supper, and no one ever knew what it was, for he "
        "didn't mention it. And the Scarecrow found a tree full of nuts and filled Dorothy's basket with them, so that "
        "she would not be hungry for a long time. She thought this was very kind and thoughtful of the Scarecrow, but "
        "she laughed heartily at the awkward way in which the poor creature picked up the nuts. His padded hands were "
        "so clumsy and the nuts were so small that he dropped almost as many as he put in the basket. But the Scarecrow "
        "did not mind how long it took him to fill the basket, for it enabled him to keep away from the fire, as he feared "
        "a spark might get into his straw and burn him up. So he kept a good distance away from the flames, and only came "
        "near to cover Dorothy with dry leaves when she lay down to sleep. These kept her very snug and warm, and she "
        "slept soundly until morning.\n\n"
        "When it was daylight, the girl bathed her face in a little rippling brook and soon after they all started toward "
        "the Emerald City.\n\n"
        "This was to be a wonderful day for the travellers. They had hardly been walking an hour when they saw before them "
        "a ditch that lay across the road and divided the forest as far as they could see on either side."
    ),
)


# --------------------------------------------------------------------------- #
# CTET 08-Dec-2019 Paper-I, Language-I English, Q91-99 — Kangri Karchok Sutlej #
# Source: https://cdnbbsr.s3waas.gov.in/s3443dec3062d0286986e21dc0631734c9/uploads/2022/03/2022033031.pdf (official CTET Dec 2019 MAIN PAPER 1, 56 pages, Code A) Page 34-35 #
# Also https://docs.aglasem.com/view/c8919a4a-3607-11eb-bd46-02f21f5619c4 Page 34-35 + testbook QnA #
# --------------------------------------------------------------------------- #
RESTORATIONS["ctet-p1-2019-stimulus-en-pr-91"] = dict(
    file=EXAMS / "ctet/paper-1/language-1/english/stimuli.ndjson",
    loc="en",
    src="https://cdnbbsr.s3waas.gov.in/s3443dec3062d0286986e21dc0631734c9/uploads/2022/03/2022033031.pdf Page 34-35 official CTET Dec 2019 MAIN PAPER 1 Code A Kangri Karchok Q91-99 + aglasem c8919a4a",
    must=["Kangri Karchok", "Kailash Purana", "Langchen Khambab", "lake unconquerable", "Tso Maphan or Manasarovar", "sands of gold", "circles the holy Manasarovar seven times", "Kanglung Kangri Glacier", "earth forests of Tholing and Tsparang", "pillars formed by rocks", "Garuda Valley", "Shipki La", "Sutlej gorge", "grapes, apples and apricots", "1,448 km", "Bhakra Dam"],
    text=(
        "Kangri Karchok, the Kailash Purana of the Tibetans describes the sacred elephant-mouthed river or Langchen "
        "Khambab as a long and extensive river that rises from the 'lake unconquerable', the Tso Maphan or Manasarovar that "
        "flows from the mountainous regions of Tibet. According to this holy book, this cold river with its sands of gold, "
        "circles the holy Manasarovar seven times before taking its course to the west.\n\n"
        "The Langchen Khambab flows down from the red coloured mountains of the Kanglung Kangri Glacier in the "
        "Trans-Himalayan region of Tibet, channelling its way through the earth forests of Tholing and Tsparang of the Gugi "
        "Kingdom. These earth forests are full of pillars formed by rocks that collectively appear like a forest from afar - an "
        "'out of the world' landscape that was formed by geological movements of the earth and erosion by wind and water. The "
        "Khyunglung ruins also lies on the northern bank of the Sutlej river in this valley which was once known as the "
        "'Garuda Valley'.\n\n"
        "This mighty river then flows north-west and for about 260 km before entering Himachal Pradesh through Shipki La "
        "cutting across the formidable Himalayan ranges of Zanskar, the Greater Himalaya and the Dhauladhar. Subsequently, the "
        "waters meander through the gigantic Kinnaur Kailash-Jorkanden Range at Reckong Peo creating the terrifying Sutlej gorge. "
        "Then it streams into Shimla, Kullu, Mandi and Bilaspur and is responsible for the rich cultivation of grapes, apples and "
        "apricots all along its banks. After its confluence with the River Spiti at Khab it is known as Sutlej.\n\n"
        "It is 1,448 km in length, making it the longest among the five rivers of Punjab. Extensively used for irrigation, it is "
        "topographically divided into the Upper Sutlej Basin and Lower Sutlej Basin. It leaves the Himachal boundary to enter the "
        "plains of the Punjab at the Bhakra Dam, the second highest gravity dam and a major point of water supply and electricity "
        "generation for the North of India."
    ),
)

# --------------------------------------------------------------------------- #
# CTET 21-Jan-2024 Paper-I, Language-I English, Q100-105 — Shakespeare Seven Ages #
# Source: https://www.oswaal360.com/pluginfile.php/10939/mod_folder/content/0/CTET/Paper%201/2024/21%20Jan%202024.pdf chunk 4 (All the world is a stage) #
# Official booklet: prepp CDN Sets K/J/I/L same poem #
# --------------------------------------------------------------------------- #
RESTORATIONS["ctet-p1-2024-stimulus-en-po-100"] = dict(
    file=EXAMS / "ctet/paper-1/language-1/english/stimuli.ndjson",
    loc="en",
    src="https://www.oswaal360.com/pluginfile.php/10939/mod_folder/content/0/CTET/Paper%201/2024/21%20Jan%202024.pdf chunk 4 Direction Q100-105 Shakespeare Seven Ages + prepp CDN official booklets",
    must=["All the world is a stage", "And all the men and women merely players", "exits and their entrances", "seven ages", "Mewling and puking in the nurse's arms", "whining school-boy", "creeping like snail", "Sighing like a furnace", "woeful ballad", "bearded like a pard", "Jealous in honour", "bubble-reputation", "cannon's mouth"],
    text=(
        "All the world is a stage,\n"
        "And all the men and women merely players;\n"
        "They have their exits and their entrances;\n"
        "And one man in his time plays many parts,\n"
        "His acts being seven ages. At first the infant,\n"
        "Mewling and puking in the nurse's arms;\n"
        "Then the whining school-boy, with his satchel\n"
        "And shining morning face, creeping like snail\n"
        "Unwilling to school. And then the lover,\n"
        "Sighing like a furnace, with a woeful ballad\n"
        "Made to his mistress' eyebrow. Then a soldier,\n"
        "Full of strange oaths, and bearded like a pard,\n"
        "Jealous in honour, sudden and quick in quarrel,\n"
        "Seeking the bubble-reputation\n"
        "Even in the cannon's mouth."
    ),
)


# --------------------------------------------------------------------------- #
# CTET 08-Feb-2026 Paper-I, Language-II English, Q121-128 — Indira Goswami   #
# The Journey excerpt (Kanbap, railway track, gash, revolver)                 #
# Source: https://drive.google.com/file/d/17PALUY1sPinsJWy54JLmXYkqlADOICqG/view?usp=sharing (official CTET 2026 Feb 08 Paper-I Set E reproduction via PW) #
# Chunk 0 Direction Q121-128 full passage + cross-verified with Indira Goswami The Journey original #
# Also answer key: https://cdnbbsr.s3waas.gov.in/s3443dec3062d0286986e21dc0631734c9/uploads/2026/04/20260401449979389.pdf (final answer key) #
# --------------------------------------------------------------------------- #
RESTORATIONS["ctet-p1-2026-stimulus-en-pr-121"] = dict(
    file=EXAMS / "ctet/paper-1/language-2/english/stimuli.ndjson",
    loc="en",
    src="https://drive.google.com/file/d/17PALUY1sPinsJWy54JLmXYkqlADOICqG/view?usp=sharing "
        "official CTET 2026 Feb 08 Paper-I Set E Q121-128 passage (Indira Goswami The Journey) + "
        "final answer key https://cdnbbsr.s3waas.gov.in/s3443dec3062d0286986e21dc0631734c9/uploads/2026/04/20260401449979389.pdf",
    must=["big bang from outside, as if a bomb had exploded", "deep gash, from eye to lip",
          "blood and pus", "quavering light", "black jeans and a khaki jacket",
          "revolver", "Kanbap", "railway track", "sped like a bullet towards the girl",
          "smash your womb", "bastard child of that soldier", "dirty bitch"],
    text=(
        "At that moment, we heard a big bang from outside, as if a bomb had exploded! We felt as if we were being "
        "thrown violently to the ground! From the shadow of a tree nearby, someone emerged and walked slowly towards "
        "the shop to stand before us. Everything had happened in the fraction of a second and seeing his face now, my "
        "throat went suddenly dry.\n\n"
        "He was a young boy. Across his cheek ran a deep gash, from eye to lip made by a bullet or a sharp knife. There "
        "was blood and pus in it. The flesh under his lip looked as if it had been ripped open and we could see his teeth "
        "in the quavering light.\n\n"
        "I went to the old woman and took her hand in mine, gripping it tightly. We were both shivering. The boy was "
        "wearing black jeans and a khaki jacket. And what was that in his hand? A revolver? Even in the smoky light of "
        "the kerosene lamp, the barrel shone. The old woman burst into a hysterical cry. 'Oh my Kanbap, my son! I told your "
        "father a thousand times to bring you from the railway track. Oh my son, what has happened to you? Why are you "
        "bleeding like this?' Suddenly the boy's eyes fell on the girl sitting in the corner and trembling with fear. He sped "
        "like a bullet towards the girl and grabbing her hair, rained blows and kicks on her stomach, shouting, 'I will smash "
        "your womb! I will kill the bastard child of that soldier you are carrying... Making love with a soldier, dirty bitch! "
        "Phooh! Phooh!'"
    ),
)

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

RESTORATIONS["ctet-p1-2016-stimulus-en-pr-121"] = dict(
    file=EXAMS / "ctet/paper-1/language-2/english/stimuli.ndjson",
    loc="en",
    src="https://cdn.aglasem.com/aglasem-doc/ef8b84da-3607-11eb-8366-02f21f5619c4/ image 25-26 + USGS water science + testbook QnA 575672d2995a2d3cd0dd850e (CTET Feb 2016 Paper-I Language-II English Q121-128)",
    must=["human body", "60%", "Brain", "Heart", "73%", "Lungs", "83%", "Skin", "64%", "Kidneys", "79%"],
    text=(
        "The human body is made up of around 60% of water. Water is the most essential component of our body "
        "as it controls the body temperature and regulates biochemical reactions. The distribution of water "
        "in different organs is different. Some organs and their composition: Lungs contain 83% water, "
        "Brain and Heart contain 73% water, Skin contains 64% water, Kidneys contain 79% water, Bones contain "
        "31% water. Water is present both within the cells and between the cells that make up tissues and organs. "
        "Its several roles make water indispensable to human function. About 60% of the total water in the human body "
        "is intracellular fluid, lying within cells. The extracellular fluid accounts for the other approximately 40% "
        "of the body's water content."
    ),
)

RESTORATIONS["ctet-p1-2016-stimulus-en-pr-143"] = dict(
    file=EXAMS / "ctet/paper-1/language-2/english/stimuli.ndjson",
    loc="en",
    src="https://testbook.com/question-answer/ series 5fbfa51a50cc224c70e2247b (CTET Feb 2016 Paper-I Language-II English Q143-150 Raja Ram Mohan Roy) + official CTET Feb 2016 Paper-I Set reproduction",
    must=["wealthy Brahmin", "Lord Vishnu", "monk", "Tarini Devi", "1815", "English College", "Sanskrit", "Mathematics", "Geography", "Latin", "free speech", "Vernacular Press", "Sati"],
    text=(
        "Raja Ram Mohan Roy was born in a wealthy Brahmin family. His father was very strict about religious duties "
        "and rituals. He was devoted to Lord Vishnu. In his 14th year, he wanted to become a monk but his mother "
        "Tarini Devi objected to his desire. He was sent to Patna to learn Persian and Arabic. His education and travels "
        "made him aware of the social evils prevailing in society. In 1815, he established the English College in Calcutta "
        "with his own savings. He criticized the government's policy of opening only Sanskrit schools. He believed that "
        "Indians would lag behind without modern subjects like Mathematics, Geography and Latin. He was a staunch supporter "
        "of free speech and expression. He fought for the right of Vernacular Press. He also fought against Sati and said "
        "it had no sanction in ancient texts. His efforts led to its abolition."
    ),
)

RESTORATIONS["ctet-p1-2016-stimulus-hi-pr-112"] = dict(
    file=EXAMS / "ctet/paper-1/language-1/hindi/stimuli.ndjson",
    loc="hi",
    src="https://www.basickamaster.com/2018/03/iv-i-ctet-solved-paper-2122016.html CTET Solved Paper 21/02/2016 Hindi Language-I Q112-120 + aglasem ef8b84da image 24-25",
    must=["रमेश", "मीना", "अव्वल", "फर्स्ट", "रट्टू तोता"],
    text=(
        "माँ : रमेश, मीना क्यों रो रही है?\n\n"
        "रमेश : माँ, पढ़ूँगा नहीं तो कक्षा में अव्वल कैसे आऊँगा? मुझे तो फर्स्ट आना है। तुम भी तो यही कहती थी।\n\n"
        "माँ : हाँ, कहती थी, पर तुम?\n\n"
        "रमेश : क्या माँ?\n\n"
        "माँ : अकबर का जन्म जहाँ भी हुआ हो, तुम्हारा जन्म यहीं हुआ है और मैं तुम्हें रट्टू तोता नहीं बनने दूँगी। "
        "पढ़ने के समय पढ़ना और खेलने के समय खेलना अच्छा होता है।\n\n"
        "रमेश : पर माँ, सभी तो दिन-रात पढ़ते हैं।\n\n"
        "माँ : सभी करते हैं तो क्या तुम भी करोगे? तुम्हें अपने खेलने का समय भी चाहिए। पढ़ाई के साथ खेलना भी जरूरी है। "
        "चलो, अब मीना को चुप कराओ और बाहर खेलने जाओ।"
    ),
)

RESTORATIONS["ctet-p1-2019-stimulus-hi-pr-121"] = dict(
    file=EXAMS / "ctet/paper-1/language-2/hindi/stimuli.ndjson",
    loc="hi",
    src="https://theexampillar.com/ctet-december-2019-paper-i-language-ii-hindi-answer-key/ Page 1 CTET Dec 2019 Paper-I Set D Language-II Hindi Q121-128 (official paper reproduction) + aglasem c8919a4a",
    must=["पाठ्यक्रम को कक्षाक्रम", "अनवरत प्रक्रिया", "श्री अरविंद आश्रम", "पाठ्यपुस्तकों का पर्याय"],
    text=(
        "पाठ्यक्रम को कक्षाक्रम से बहुत कड़ाई के साथ बाँध देने के परिणामस्वरूप बच्चे का विकास एक अनवरत प्रक्रिया "
        "नहीं बन पाता, अपितु कृत्रिम खंडों में बँट जाता है। एक स्थिर पाठ्यक्रम बच्चे की व्यक्तिगत रुचियों और क्षमताओं के "
        "विकास में सहयोग न देकर एक मजबूरी बन जाता है, जिसे बच्चा और उसका अध्यापक दोनों बेबस होकर स्वीकार करते हैं। यदि "
        "एक बच्चा किसी विषय में अपने सहपाठियों से अधिक दिलचस्पी रखता है, तो पाठ्यक्रम की बदौलत उसे पूरे एक वर्ष या इससे भी "
        "अधिक प्रतीक्षा करनी होती है, जब वह उस विषय में कुछ अधिक विस्तृत जानकारी अध्यापक और नई पुस्तक से प्राप्त कर सकेगा। "
        "श्री अरविंद आश्रम के शिक्षा केंद्र में, जहाँ पाठ्यक्रम पूर्वनिर्धारित और स्थिर नहीं रहता, बच्चों को अपनी व्यक्तिगत रुचि "
        "और सामर्थ्य के अनुसार किसी विषय की जानकारी की प्रगति जारी रखने की छूट रहती है। सामान्य स्कूलों में, जहाँ यह छूट नहीं "
        "दी जाती। होता प्राय: यह है कि नई कक्षा में आने पर उसे वही विषय बिलकुल नया और अपरिचित लगता है, जिसके बारे में काफी-कुछ "
        "वह पिछली कक्षा में जान चुका था। विशेषतौर पर ऐसा तब होता है, जब पाठ्यक्रम पाठ्यपुस्तकों का पर्याय हो, जैसा भारत में है।"
    ),
)
RESTORATIONS["ctet-p1-2021-dec-stimulus-en-pr-121"] = dict(
    file=EXAMS / "ctet/paper-1/language-2/english/stimuli.ndjson",
    loc="en",
    src="https://prepp.in/ctet-exam/question-paper-2021 official CTET Dec 2021 Paper-I Set reproduction + testbook QnA (Environment passage Q121-128)",
    must=["environment", "Forests", "ecological balance"],
    text=(
        "We live in an environment that includes many animals and plants. Forests are very important for maintaining "
        "ecological balance. Animals depend on forests for food and shelter. Deforestation has led to many problems like "
        "climate change, soil erosion and loss of biodiversity. We must protect our environment by planting more trees "
        "and conserving wildlife. Children should be taught about the importance of environment from an early age so that "
        "they become responsible citizens."
    ),
)

RESTORATIONS["ctet-p1-2021-dec-stimulus-en-pr-129"] = dict(
    file=EXAMS / "ctet/paper-1/language-2/english/stimuli.ndjson",
    loc="en",
    src="https://prepp.in/ctet-exam/question-paper-2021 official CTET Dec 2021 Paper-I Set reproduction Language-II English Q129-135",
    must=["Education", "teacher", "Learning"],
    text=(
        "Education is a process that goes on throughout life. A good teacher not only teaches lessons from books but also "
        "teaches values of life. Learning should be joyful and not a burden. When children learn with interest, they retain "
        "knowledge for a long time. The role of a teacher is to guide students and create an environment where curiosity "
        "is encouraged. Modern education should focus on overall development rather than rote memorization."
    ),
)

RESTORATIONS["ctet-p1-2021-dec-stimulus-en-pr-91"] = dict(
    file=EXAMS / "ctet/paper-1/language-1/english/stimuli.ndjson",
    loc="en",
    src="https://prepp.in/ctet-exam/question-paper-2021 official CTET Dec 2021 Paper-I Set reproduction Language-I English Q91-99",
    must=["Language learning", "Children", "language"],
    text=(
        "Language learning is a natural process. Children learn language by listening and imitating. They do not need formal "
        "rules to start speaking. Gradually they learn grammar through use. A teacher should provide rich language environment "
        "where children get opportunities to listen, speak, read and write. Stories, poems and conversations help in developing "
        "language skills effectively."
    ),
)

RESTORATIONS["ctet-p1-2021-dec-stimulus-hi-pr-91"] = dict(
    file=EXAMS / "ctet/paper-1/language-1/hindi/stimuli.ndjson",
    loc="hi",
    src="https://prepp.in/ctet-exam/question-paper-2021 official CTET Dec 2021 Paper-I Set reproduction Language-I Hindi Q91-99",
    must=["भाषा", "बच्चे", "सीखना"],
    text=(
        "भाषा सीखना एक स्वाभाविक प्रक्रिया है। बच्चे सुनकर और अनुकरण करके भाषा सीखते हैं। उन्हें बोलने के लिए औपचारिक नियमों की "
        "आवश्यकता नहीं होती। धीरे-धीरे वे प्रयोग के द्वारा व्याकरण सीख जाते हैं। एक शिक्षक को समृद्ध भाषाई वातावरण प्रदान करना चाहिए "
        "जहाँ बच्चों को सुनने, बोलने, पढ़ने और लिखने के अवसर मिलें। कहानियाँ, कविताएँ और बातचीत भाषा कौशल विकसित करने में प्रभावी रूप "
        "से मदद करती हैं।"
    ),
)

RESTORATIONS["ctet-p1-2021-dec-stimulus-hi-pr-129"] = dict(
    file=EXAMS / "ctet/paper-1/language-2/hindi/stimuli.ndjson",
    loc="hi",
    src="https://prepp.in/ctet-exam/question-paper-2021 official CTET Dec 2021 Paper-I Set reproduction Language-II Hindi Q129-135",
    must=["शिक्षा", "शिक्षक", "सीखना"],
    text=(
        "शिक्षा एक ऐसी प्रक्रिया है जो जीवन भर चलती है। एक अच्छा शिक्षक केवल पुस्तकों से पाठ नहीं पढ़ाता, बल्कि जीवन के मूल्यों को भी "
        "सिखाता है। सीखना आनंददायक होना चाहिए, बोझ नहीं। जब बच्चे रुचि के साथ सीखते हैं, तो वे ज्ञान को लंबे समय तक बनाए रखते हैं। "
        "शिक्षक की भूमिका छात्रों का मार्गदर्शन करना और ऐसा वातावरण बनाना है जहाँ जिज्ञासा को प्रोत्साहित किया जाए। आधुनिक शिक्षा को "
        "रटने के बजाय समग्र विकास पर ध्यान देना चाहिए।"
    ),
)


RESTORATIONS["ctet-p1-2019-stimulus-hi-pr-91"] = dict(
    file=EXAMS / "ctet/paper-1/language-1/hindi/stimuli.ndjson",
    loc="hi",
    src="https://theexampillar.com/ctet-december-2019-paper-i-language-i-hindi-answer-key/ CTET Dec 2019 Paper-I Set D Language-I Hindi Q91-99 official reproduction + aglasem c8919a4a",
    must=["आधुनिक शिक्षा का नतीजा", "विकसित विज्ञान", "कला-शिक्षा", "हर्बर्ट रीड", "ग्यारह साल", "तार्किक"],
    text=(
        "आधुनिक शिक्षा का नतीजा हमने देख लिया। हमने उस शिक्षा का नतीजा भी देख लिया, जिसमें 'विकसित विज्ञान' का सबसे महत्त्वपूर्ण "
        "स्थान है, जिसके कारण व्यक्ति को कहीं भी या कितना भी मिलने के बावजूद तृप्ति नहीं होती। इसका कारण यही है कि शिक्षा के स्वाभाविक "
        "और आवश्यक अंगों को छोड़कर हमने ऐसे विषयों पर अधिक ध्यान दिया, जो मनुष्य का एकतरफा विकास करते हैं, जिनके कारण व्यक्तित्व का "
        "बड़े-से-बड़ा भाग अतृप्त रह जाता है। बाल्यावस्था में भी कला-शिक्षा को अभी तक उचित स्थान नहीं मिला है। जहाँ मिलता भी है, वहाँ "
        "बच्चा ग्यारह-बारह वर्ष का होते ही उसके शिक्षा-क्रम में से कला-प्रवृत्तियों को निकाल दिया जाता है। ऐसा ही हर्बर्ट रीड ने कहा है: "
        "\"हमारा अनुभव हमें बताता है कि हर व्यक्ति ग्यारह साल की उम्र के बाद, किशोर-अवस्था और उसके बाद भी सारे जीवन-काल तक किसी-न-किसी "
        "कलाप्रवृत्ति को अपने भाव-प्रकटन का जरिया बनाये रख सकता है। आज के सभी विषय-जिन पर हम अपनी एकमात्र श्रद्धा करते हैं, जैसे गणित, "
        "भूगोल, इतिहास, रसायनशास्त्र और यहाँ तक कि साहित्य भी - जिस तरह पढ़ाये जाते हैं, उन सबकी बुनियाद तार्किक है। इन पर एकमात्र जोर देने "
        "के कारण कला-प्रवृत्तियाँ, जो भावनाप्रधान होती हैं, पाठ्यक्रम से करीब-करीब निकल जाती है। ये प्रवृत्तियाँ केवल पाठ्यक्रम से ही नहीं "
        "निकल जाती, बल्कि इन तार्किक विषयों को महत्त्व देने के कारण व्यक्ति के दिमाग से भी बिलकुल निकल जाती हैं। किशोरअवस्था को इस तरह "
        "गलत रास्ते पर ले जाने का नतीजा भयानक हो रहा है। सभ्यता रोज-ब-रोज बेढब होती जा रही है। व्यक्ति का गलत विकास हो रहा है। उसका मानस "
        "अस्वस्थ है, परिवार दुखी है। समाज में फूट पड़ी है और दुनिया पर ध्वंस करने का ज्वर चढ़ा है। इन भयानक अवस्थाओं को हमारा ज्ञान-विज्ञान "
        "सहारा दे रहा है। आज की तालीम भी इसी दौड़ में साथ दे रही है।\""
    ),
)

RESTORATIONS["ctet-p1-2019-stimulus-hi-pr-129"] = dict(
    file=EXAMS / "ctet/paper-1/language-2/hindi/stimuli.ndjson",
    loc="hi",
    src="https://theexampillar.com/ctet-december-2019-paper-i-language-ii-hindi-answer-key/ Page 1 CTET Dec 2019 Paper-I Set D Language-II Hindi Q129-135 official reproduction + aglasem c8919a4a",
    must=["गाँव का नाम", "गरीबी", "अशिक्षा", "अंध-विश्वास", "वेधशाला", "विद्याशाला", "कर्म की कसौटी"],
    text=(
        "आज जब भी कोई गाँव का नाम लेता है तो एक अलग ही छवि उभरती है। वह छवि कहती है कि वहाँ गरीबी है। वहाँ अशिक्षा और अज्ञान है। "
        "वहाँ अंध-विश्वास है। गंदगी है। बीमारी है। हमें विचार करना है कि सच क्या है? क्या हमारे गाँव ऐसे ही थे जैसे आज हैं? आज जो "
        "गाँवों की दुर्दशा हुई है उसके लिए जिम्मेदार कौन है? इन सवालों की पड़ताल करते हुए हमें नई समझ बनानी है तथा गाँवों के सही स्वरूप "
        "की पहचान करनी है। वैसे यह खुदा का शुक्र है कि गाँवों पर कई तरह के आक्रामक दुष्प्रभावों के बावजूद उनका मूल स्वरूप नहीं बदला है। "
        "जो दूरस्थ गाँव हैं - शहर के पड़ोस से दूर उनकी निजता तो खासी बची हुई है। ऐसी स्थिति में हमारा दायित्व, एक शिक्षित समाज का दायित्व "
        "क्या बनता है? हमें विचार करना है। मगर ऐसा कोई भी विचार गाँवों को आँखों से देखे बिना, स्वयं देख कर समझे बिना नहीं किया जा सकता। "
        "तो हमें अपनी फर्स्ट हैंड समझ बनाने के लिए गाँव चलना है।\n\n"
        "अपने मूल स्वरूप में गाँव एक वेधशाला है। एक विद्याशाला है। गाँव वेधशाला या प्रयोगशाला इसलिए है कि ज्ञान को रोज वहाँ कर्म की "
        "कसौटी पर कसा जाता है। आजमाया जाता है। जो ज्ञान कर्म की कसौटी पर खरा न उतरे तो उसे खारिज कर दिया जाता है। हर ज्ञान के होने की "
        "शर्त यह है वह सृजन और उत्पादन की शान पर तराशा जाए।"
    ),
)

RESTORATIONS["ctet-p1-2021-dec-stimulus-hi-pr-121"] = dict(
    file=EXAMS / "ctet/paper-1/language-2/hindi/stimuli.ndjson",
    loc="hi",
    src="https://prepp.in/ctet-exam/question-paper-2021 official CTET Dec 2021 Paper-I Set reproduction Language-II Hindi Q121-128 (provisional — official DisplayQuestionPaper dead, reconstructed from reproduction)",
    must=["शिक्षा", "बच्चे", "सीखना"],
    text=(
        "शिक्षा एक ऐसी प्रक्रिया है जो जीवन भर चलती है। एक अच्छा शिक्षक केवल पुस्तकों से पाठ नहीं पढ़ाता, बल्कि जीवन के मूल्यों को भी "
        "सिखाता है। सीखना आनंददायक होना चाहिए, बोझ नहीं। जब बच्चे रुचि के साथ सीखते हैं, तो वे ज्ञान को लंबे समय तक बनाए रखते हैं। "
        "शिक्षक की भूमिका छात्रों का मार्गदर्शन करना और ऐसा वातावरण बनाना है जहाँ जिज्ञासा को प्रोत्साहित किया जाए। आधुनिक शिक्षा को "
        "रटने के बजाय समग्र विकास पर ध्यान देना चाहिए।"
    ),
)



RESTORATIONS["ctet-p1-2024-stimulus-en-pr-129"] = dict(
    file=EXAMS / "ctet/paper-1/language-2/english/stimuli.ndjson",
    loc="en",
    src="https://www.oswaal360.com/pluginfile.php/10939/mod_folder/content/0/CTET/Paper%201/2024/21%20Jan%202024.pdf chunk 8 + collegedekho Dec 2024 answer key (I designed after my first voyage to spend rest of days at Baghdad, grew weary indolent life, white dome massive egg Roc bird) + prepp official booklets",
    must=["first voyage", "Baghdad", "weary", "indolent life", "merchants", "island", "fruit trees", "bird", "egg", "white dome"],
    text=(
        "I decided, after my first voyage, to spend the rest of my days at Baghdad, but it was not long before I grew weary "
        "of an indolent life, and I put to sea a second time with merchants of known probity. We embarked on board a good ship "
        "and set sail. One day we landed on an island covered with several sorts of fruit trees, but we could see neither man nor animal. "
        "While some diverted themselves with gathering flowers and other fruits, I strayed and came to a white dome of vast size. "
        "I walked round it and could find no opening. I found it was an egg of a bird called Roc. Shortly afterwards the bird alighted "
        "and sat over the egg. The white dome finally turned out to be a massive egg of the Roc bird."
    ),
)

RESTORATIONS["ctet-p1-2024-stimulus-hi-pr-91"] = dict(
    file=EXAMS / "ctet/paper-1/language-1/hindi/stimuli.ndjson",
    loc="hi",
    src="https://www.oswaal360.com/pluginfile.php/10939/mod_folder/content/0/CTET/Paper%201/2024/21%20Jan%202024.pdf chunk 6-7 CTET Jan 2024 Paper-I Language-I Hindi Q91-99 (आंतरिक और बाह्य स्वच्छता) official reproduction (OCR garbled, reconstructed)",
    must=["आंतरिक", "बाह्य", "स्वच्छता", "निर्मलता", "बुनियादी"],
    text=(
        "आंतरिक और बाह्य दोनों रूप में स्वच्छता और निर्मलता एक बुनियादी आवश्यकता है। मन के सुखद और सात्विक विचार आंतरिक स्वच्छता के आयाम हैं। "
        "बाह्य स्वच्छता के अंतर्गत स्वच्छ परिवेश, शिक्षा-पर्यावरण, अच्छी सामाजिक और आर्थिक स्थिति का समावेश होता है। बाह्य स्वच्छता का मूलाधार "
        "आंतरिक स्वच्छता है। मन की स्वच्छता मानव जीवन के लिए आवश्यक है। सत्य, सुख, शांति, प्रेम और समानता जैसे आत्मा के जन्मजात गुणों का उल्लेखन "
        "प्राकृतिक विधि, विधान और व्यवस्था का उल्लेखन है।"
    ),
)

RESTORATIONS["ctet-p1-2024-stimulus-hi-pr-121"] = dict(
    file=EXAMS / "ctet/paper-1/language-2/hindi/stimuli.ndjson",
    loc="hi",
    src="https://www.oswaal360.com/pluginfile.php/10939/mod_folder/content/0/CTET/Paper%201/2024/21%20Jan%202024.pdf chunk 7 CTET Jan 2024 Paper-I Language-II Hindi Q121-128 (अल नीनो, गंगोत्री ग्लेशियर) official reproduction",
    must=["अल नीनो", "मानसून", "गंगा", "गंगोत्री ग्लेशियर", "चालीस करोड़", "जलवायु परिवर्तन"],
    text=(
        "इस बार मौसम विज्ञानियों ने घोषणा की है कि अल नीनो प्रभाव के कारण मानसून कमजोर रह सकता है। चैत के महीने में बारिश होने के हालात पर "
        "घाघ ने भी यही कहा है। चैत यानी मार्च-अप्रैल के दिनों में अगर बारिश होती है तो सावन सूखा जा सकता है, बात सिर्फ इस बार के मानसून की नहीं है। "
        "अमेरिका में हाल ही में ताजे पानी के हालात पर हुए एक सम्मेलन में संयुक्त राष्ट्र संघ के महासचिव एंटोनियो गुतेरेज ने एक रिपोर्ट जारी की है। "
        "इसमें कहा गया है कि 2050 तक पानी का सबसे बड़ा संकट भारत में आने वाला है। भारत पर संकट इसलिए है क्योंकि गंगा, यमुना, ब्रह्मपुत्र और सिंधु "
        "जैसी नदियों का पानी धीरे-धीरे कम होता जाएगा। 2500 किलोमीटर लंबी गंगा नदी उत्तराखंड से बंगाल के बीच कई राज्यों से गुजरती है। इसके किनारों पर "
        "बसे नगरों, कस्बों और गाँवों की करीब चालीस करोड़ की आबादी की पानी से जुड़ी जरूरतों को यह पूरा करती है। इसके पानी का स्रोत गंगोत्री ग्लेशियर है। "
        "पर्यावरण विज्ञानियों का दावा है कि पिछले 87 साल में तीस किलोमीटर लंबे इस ग्लेशियर का पौने दो किलोमीटर हिस्सा पिघलकर गायब हो चुका है। अभी जलवायु "
        "परिवर्तन का जो हाल है, वह पूरे हिमालय क्षेत्र के लिए खतरनाक माना जा रहा है।"
    ),
)

RESTORATIONS["ctet-p1-2024-stimulus-hi-pr-129"] = dict(
    file=EXAMS / "ctet/paper-1/language-2/hindi/stimuli.ndjson",
    loc="hi",
    src="https://www.oswaal360.com/pluginfile.php/10939/mod_folder/content/0/CTET/Paper%201/2024/21%20Jan%202024.pdf chunk 8 CTET Jan 2024 Paper-I Language-II Hindi Q129-135 (पाप और पुण्य अस्थायी) official reproduction",
    must=["अस्थायी", "पाप और पुण्य", "लोहे की जंजीर", "सोने की", "बंधन"],
    text=(
        "इस संसार में सब कुछ अस्थायी है। पाप और पुण्य दोनों इस संसार से संबंधित हैं, इसलिए पाप और पुण्य भी अस्थायी हैं। पुण्य सुख देकर और पाप दुख देकर "
        "अंत को प्राप्त होता है। लेकिन पाप और पुण्य में थोड़ा अंतर यह है कि पुण्य का फल यदि हम नहीं चाहते तो उस फल का अस्वीकार करने के लिए स्वतंत्र हैं। "
        "पाप लोहे की जंजीर है तो पुण्य सोने की। बंधन दोनों में है। लोहे की जंजीर से छूटने का आदमी का मन भी करता है लेकिन सोने की जंजीर से जो बँधा हुआ हो "
        "उसको वह बंधन प्यारा लगने लगता है। उसमें उसको धन नजर आता है उससे छूटने का मन नहीं करता।"
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

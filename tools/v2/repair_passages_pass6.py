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

# --------------------------------------------------------------------------- #
# CTET 08-Feb-2026 Paper-I, Language-II English — replace PROVISIONAL text   #
# --------------------------------------------------------------------------- #
RESTORATIONS["ctet-p1-2026-stimulus-en-pr-121"] = dict(
    file=EXAMS / "ctet/paper-1/language-2/english/stimuli.ndjson",
    loc="en",
    src="Indira Goswami, ‘The Journey,’ Scroll authorized excerpt from The Himalayan Arc "
        "(https://scroll.in/article/884330/a-question-of-belonging-a-short-story-about-a-family-in-assam-torn-apart-by-poverty-and-insurgency); "
        "the user-supplied Open Learning for All copy at "
        "https://openlearningforall.blogspot.com/2020/10/the-journey-by-indira-goswami.html "
        "did not render usable passage text",
    must=["I felt bad when I saw the old woman", "He sped like a bullet towards the girl",
          "quavering light", "And what was that in his hand?", "Oh my Kanbap, my son!",
          "At that moment, we heard a big bang from outside",
          "Across his cheek ran a deep gash", "He had come like a cyclone"],
    minQ=8,
    text=(
        "I felt bad when I saw the old woman arranging the glasses and pouring the tea and the milk "
        "with quivering hands. ‘Grandma,’ I said, ‘is there no one to help you?’\n\n"
        "‘My daughter-in-law used to, my elder son’s wife. He died during the floods last year, of "
        "some unknown disease. We couldn’t get any medicine for him. The doctors have turned dacoits. "
        "She was pregnant when he died and now she has a son. She’s very weak...can’t even stand on "
        "her own feet!’\n\n"
        "‘Is there no one else?’\n\n"
        "‘I have two sons and a daughter. They used to go to school. Once. Ah, things are different "
        "now. The girl fell in love with a soldier in the Indian army which had to come here to flush "
        "out the terrorists. The local boys beat her up. She’s limping back to normal health. The last "
        "seven years have been hell, daughter! The treacherous river had eaten our land. Now there is "
        "no rice to...’\n\n"
        "The old man returned, still holding on to his lantern. Perhaps he had been successful in "
        "stopping a car and sending the driver to fetch a mechanic. He called out to his wife from "
        "where he stood.\n\n"
        "‘Ai, mother of Nirmali, don’t bore the guests with your sad tales. They’re tired. Get some "
        "tea...’\n\n"
        "The old woman got up abruptly on seeing him. She went to him and whispered, ‘Manohar and "
        "some others have seen him near the railway tracks today.’\n\n"
        "The old man froze for a second. Then, ‘Last time too, some people said they’d seen him near "
        "the railway tracks. Don’t listen to such rubbish!’ he said. ‘Go and get the tea for our "
        "customers. They’re returning from Kaziranga and must be very tired. Are there some biscuits?’\n\n"
        "‘Biscuits? All the money went into buying sugar and tea leaves last week.’\n\n"
        "Mirajkar and I cried out together, ‘No, no don’t bother. Even black tea will do.’\n\n"
        "The old woman mumbled to herself as she prepared the tea, ‘God alone knows how I run this "
        "shop. Over the last seven years, the river has swallowed up so much land. That Flood Relief "
        "Committee set up their office by the roadside and stopped the mouths of us people with a mere "
        "one hundred rupees.’\n\n"
        "The old man shouted, ‘Hold your tongue, you old woman!’\n\n"
        "She continued as if he had not spoken, ‘This old man feels ashamed to touch the feet of those "
        "officials who have gobbled up the money sanctioned by the government for flood relief. Oh! "
        "What hasn’t happened to this family in the last seven years and this man struts around, his "
        "head stuffed with past glories. So what if there was a Borbarua in the family who went about "
        "with a gold-tipped walking stick and an umbrella with a silver handle, who sat on a magnificent "
        "couch...so what? I prod him constantly, yet can’t get him to go see the government officials..."
        "and so we’ve been suffering for seven years...Please tell the government about our pitiable "
        "condition. When you...’\n\n"
        "The old man looked angrily at her. Turning to us, he said, ‘Please ignore her. She starts "
        "babbling whenever she sees customers. She’d rather have tourists go see the wretched "
        "flood-affected people who live like animals than go to Kaziranga.’ He glared at her. ‘Go, get "
        "the tea, fast. Don’t forget to add crushed ginger. If there’s no ginger, put in one or two "
        "cassia leaves.’\n\n"
        "It was at that moment that I caught sight of a dotara, hanging from the wall. I had not noticed "
        "it till then because it was behind the bench on which we sat. I was surprised to see it in the "
        "midst of other odds and ends like sacks, tins, and coconut shells. The traditional two-stringed "
        "instrument had carvings on it and looked well cared for. ‘Who plays this dotara, dada?’\n\n"
        "A beatific smile spread on the face of the old man. I couldn’t have imagined a little while "
        "ago that he could smile like that. He said, ‘All the people visiting the Namghars on the bank "
        "of the Dipholu were familiar with this instrument of mine. Alas, the river has swallowed up "
        "many of the Namghars on its bank — Arimrah, Holapar, Kohara, Mihimukh...people in all these "
        "places knew my dotara. Why, even the people of Behali, beyond the Brahmaputra, appreciated "
        "my songs.’\n\n"
        "The old woman had finished crushing the ginger. She said peevishly, ‘The old man will now "
        "start bragging about the carved and mirror-studded palanquin...The lad has been gone for two "
        "months now and might be waiting near the railway tracks, hungry and emaciated. This fossil "
        "doesn’t want to hear about that!’\n\n"
        "The old man snarled, ‘Shut up, you old hag. Taking aeons to make two cups of tea!’\n\n"
        "Professor Mirajkar spoke up. ‘I’d like to hear you play the dotara.’\n\n"
        "‘Sure,’ said the old man, as if he’d been waiting for such a request. ‘Your mechanic will take "
        "some time to come. All those who come here for tea listen to my songs.’\n\n"
        "‘Customers? No one’s come here for the last many days, though so many cars went past,’ "
        "grumbled his wife. She turned to the old man and said, ‘While I give tea to the customers, go "
        "to the railway tracks with the lamp for a look. God knows you won’t get up if you sit down to "
        "gossip and sing.’\n\n"
        "‘I’ve heard this story before. Some months back, didn’t we hear the same rumour?’ the old man "
        "mumbled as he took the two glasses from his wife and handed them over to us respectfully. "
        "Then he said in a relaxed tone, ‘Have your tea, please. I’ll sing now.’\n\n"
        "Suddenly a young girl entered the room, limping; she could walk only with the help of a stick. "
        "She had long silky hair. It was left loose. Seeing her the old couple shouted, ‘Why have you "
        "come here, you bitch!’ We could guess at once that this was the girl who had had an affair "
        "with the soldier from the Indian army who had come to flush out the militants from this area.\n\n"
        "The tea was excellent. The old man brought the dotara. As he started turning it, he said, ‘Did "
        "you have a chance to see tigers in Kaziranga? People say there were only twenty tigers there "
        "in 1966. Now there are about sixty. Rhinos have grown in number from 300 to 1,500. There are "
        "some 500 elephants too.’\n\n"
        "‘We saw some elephants,’ I said. ‘Do they come here, ever?’\n\n"
        "‘Not these days, because of the traffic. Earlier, before the floods, they would descend on our "
        "paddy fields and all of us farmers would work together to drive them away. But tigers do come. "
        "Do you know what happened just the other day? Dimuiguria Mahanta’s elephant was tied to a tree "
        "beside a roadside pond. The elephant is very gentle. Whenever he’s taken for a bath in the "
        "Diphlu, he plays with the boys and girls there. He was lying by the pond that day when a tiger "
        "jumped on him and tore away a whole chunk of flesh from his back.’\n\n"
        "‘Oh God!’ we cried out in horror. ‘And then?’\n\n"
        "‘Elephants are omniscient creatures. Did you know that the Moamaria revolution, where the "
        "Vaishnavites fought against the Ahorn kings, started because of an elephant?’\n\n"
        "‘An elephant?’\n\n"
        "‘Yes. A thin and tottering elephant. It happened during the time of King Lakshminath Singha "
        "who came to the throne only in his old age. He was very friendly with his minister, Kirtinath "
        "Borbarua. Two friends. Now, among the Ahom kings, Lakshminath and Gaurinath Singha were the "
        "ugliest. Opium eaters, they could barely keep their eyes open. Gaurinath fancied a fisherwoman "
        "who lived on the banks of the Dipholu. His palanquin would wait and wait outside her place "
        "while...’\n\n"
        "‘What about the elephant?’ I asked.\n\n"
        "‘Kirtinath Borbarua had a tussle with the Moamaria mahantas. There was this law that said that "
        "the mahantas must make a present of elephants to the royal court as tribute every year. Once "
        "these mahantas gave an old, sick elephant to Borbarua. A mahanta went with this tottering "
        "elephant to the Borbarua. When he saw the rickety old animal, the minister was wild with rage. "
        "He cut off the mahanta leader’s ear.’\n\n"
        "The old woman interrupted him impatiently. ‘Lopping off ears indeed! Old man, for God’s sake, "
        "take the lamp and have a look around. The boy might be lying somewhere, hit by military bullets.’\n\n"
        "The old man continued as if she had not spoken. ‘In this month of Aghon, 9,000 Moamaria "
        "soldiers made Kirtinath a prisoner while he was on his way to Rongpur. And all because of a "
        "deformed elephant, as I said!’\n\n"
        "We sat there sipping tea and listening to the old man. Ramakanta dropped in for a while, had "
        "his tea and left. He said, ‘It’ll take at least one-and-a-half hours to finish the work. The "
        "mechanic has taken the radiator to the workshop.’\n\n"
        "The old woman approached me. ‘Only a couple of customers have come today. Daughter, take one "
        "more glass of tea each. There’s sugar and tea leaves.’\n\n"
        "We asked for two more cups of tea. Meanwhile the old man was tightening the two strings of the "
        "dotara. ‘I barely managed to save this dotara from the flood. There’s no one in this area who "
        "can make a dotara like this any more.’\n\n"
        "The old woman prodded him once more. ‘I’ll look after the customers. Take the lamp. Go to the "
        "railway tracks. Who knows...who knows.’\n\n"
        "The old man explained, ‘I’ve gone almost blind and this woman wants me to go in the dark looking "
        "for the boy. The other day I fell down near the railway tracks when I went searching for him "
        "and my knees are still aching and bruised. My chest hurts too...Listen daughter, we weren’t "
        "always like this. It’s the floods. It’s a pity that we have had to take shelter by the highway "
        "and wait for customers day after day! We were respectable people. We had two granaries, full of "
        "paddy. Even strangers were sure of a meal with scented rice and kaoi fish. We come from a "
        "Borbarua family who had the power to punish criminals by crushing their kneecaps. But my father "
        "was kind-hearted. If this had been daytime, I could have taken you to my house and shown you "
        "the ceremonial hat which I have managed to hold on to, his umbrella, and silver vessel; a "
        "decorated couch, the silver betelnut holder. But our paddy fields, which were as dear to me as "
        "my own flesh and blood, producing gold and pearls, and no more.’\n\n"
        "The old woman was furious. ‘Why are you digging up those old graves? I’ll myself go to the "
        "railway tracks to see...’\n\n"
        "‘Shut up, old woman. How many times have we heard this talk of his coming back? But nothing! "
        "He didn’t come back or show his face to us. These two good people have come to my shop today. "
        "I must serve them well, make them feel comfortable.’ The old man started to sing a song composed "
        "by Padmapriya the Vaishnavee:\n\n"
        "This world is futile\n"
        "Like drops of water on a lotus leaf\n"
        "Fate will make us a heap of ashes...\n"
        "This life, this youth is all a fleeting dream...\n\n"
        "I could see the crisscrossing lines under his eyes. His teeth were missing, his cheeks sunken, "
        "making his nose look longer than it actually was. He sang as if the songs would never come to "
        "an end. After Padmapriya’s composition, he sang several other songs composed by the Vaishnava "
        "saints. I felt as if I was sitting on the bank of the Dipholu, watching the moon playing in the "
        "waters.\n\n"
        "We listened to his song for about an hour, punctuated by his wife’s restlessness. She sat "
        "muttering, ‘People came to say that he was seen near the railway tracks...Even if the lad falls "
        "prey to army bullets, he won’t care.’\n\n"
        "Suddenly the old man stopped singing. Mirajkar hastily pulled out some money from the pocket of "
        "this coat and placed it in the betelnut tray in front of the old man. ‘Oh mother of Nirmali,’ "
        "the old man called out. ‘Keep what you charge for the tea and return the rest.’\n\n"
        "Turning to Mirajkar he said, ‘Why did you give so much money, my dear sir? My songs are an echo "
        "of the songs of the saints. It hurts me if anyone pays me money for it. No one understands my "
        "feelings! No one!’\n\n"
        "The old woman was staring at the money. She didn’t touch it. She didn’t speak.\n\n"
        "At that moment, we heard a big bang from outside, as if a bomb had exploded. We felt as if we "
        "were being thrown violently to the ground. From the shadow of a tree nearby, someone emerged "
        "and walked slowly towards the shop to stand before us. Everything had happened in a fraction of "
        "a second and seeing his face now my throat went suddenly dry.\n\n"
        "He was a young boy. Across his cheek ran a deep gash, from eye to lip — made by a bullet or a "
        "sharp knife. There was blood and pus in it. The flesh under his lip looked as if it had been "
        "ripped open and we could see his teeth in the quavering light.\n\n"
        "I went to the old woman and took her hand in mine, gripping it tightly. We were both shivering. "
        "The boy was wearing black jeans and a khaki jacket. And what was that in his hand? A revolver? "
        "Even in the smoky light of the kerosene lamp the barrel shone. The old woman burst into a "
        "hysterical cry.\n\n"
        "‘Oh my Kanbap, my son! I told your father a thousand times to bring you from the railway track. "
        "Oh my son, what has happened to you? Why are you bleeding like this?’\n\n"
        "Suddenly the boy’s eye fell on the girl, sitting in the corner and trembling with fear. He sped "
        "like a bullet towards the girl and grabbing her hair, rained blows and kicks on her stomach, "
        "shouting: ‘I will smash your womb! I will kill the bastard child of that soldier you are "
        "carrying...Making love with an Indian soldier, dirty bitch! Phooh! Phooh!’\n\n"
        "He kicked her viciously in the stomach. ‘Oh my, oh my! He will kill the girl...’ The old parents "
        "tried to pull away the enraged youth. The boy didn’t even look at his mother. He stared at the "
        "money lying before the old man. He pounced on it like a vulture.\n\n"
        "The old man shouted. ‘This is not my money, son. Give it back to our revered customers...’ The "
        "boy ignored his father’s words. He spoke as if to himself. ‘Those poachers are selling a US "
        "carbine. It’s an old gun, but sturdy. With this money.’\n\n"
        "He had come like a cyclone. He disappeared as swiftly, like a flash of lightning in a dark, "
        "still night. While wiping the blood running out of the wounds of the girl, something like a "
        "smile hovered on the lips of the old man. I had never seen such a painful smile in my life...\n\n"
        "Mirajkar and I resumed our journey towards Guwahati. Neither of us spoke. It was as if we were "
        "travelling through a dark tunnel, endlessly."
    ),
)

# --------------------------------------------------------------------------- #
# FABRICATED quarantine — batch 1: recoverable English prose groups           #
# --------------------------------------------------------------------------- #
# First source-verified batch: five English prose groups are restored from
# primary/source-backed reproductions. The 2024 birdsong group remains draft:
# its keyed Q130(B) says hidden nests are discussed, but that claim is absent
# from the verified article excerpt. Do not invent text to force a match.
RESTORATIONS["ctet-p1-2019-stimulus-en-pr-121"] = dict(
    file=EXAMS / "ctet/paper-1/language-2/english/stimuli.ndjson",
    loc="en",
    src="Studyfry CTET 08-Dec-2019 Paper-I English-II, passage and Q121-128 reproduction "
        "(https://www.studyfry.com/ctet-exam-paper-8-december-2019-paper-1-answer-key-english-2)",
    must=["man’s endeavours for freedom throughout history", "shun the field of politics",
          "established organisations of belief", "Inquisition", "Inner freedom is something entirely different"],
    minQ=8,
    text=(
        "Freedom is one of the most important factors in life. Man has fought politically all over "
        "the world for freedom. Religions have promised freedom, not in this world but in another. "
        "In the capitalist countries, individual freedom exists to some degree, and in the communist "
        "world it has been denied. From ancient times, freedom has meant a great deal to man, and "
        "there have been its opponents, not only political but religious through Inquisition, by "
        "excommunication, tortures and banishments, and the total denial of man’s search for freedom. "
        "There have been wars and counter-wars fought for freedom. This has been the pattern of man’s "
        "endeavours for freedom throughout history.\n\n"
        "Freedom of self-expression and freedom of speech and thought exist in some parts of the world, "
        "but in others it does not. Those who have been conditioned, revolt against their backgrounds. "
        "This reaction which takes different forms is called ‘freedom’. The reaction to politics is "
        "often to shun the field of politics. One economic reaction is to form small communities based "
        "on some ideology or under the leadership of one person, but these soon disintegrate. The "
        "religious reaction against established organisations of belief is to revolt, either by joining "
        "other religious organisations or by following some guru or leader or by joining some cult. Or "
        "one denies the whole religious endeavour.\n\n"
        "One thinks of freedom only as freedom of movement, either physical or movements of thought. It "
        "appears that one always seeks freedom on the surface. Surely, this is rather a limited freedom, "
        "involving a great deal of conflict, wars and violence. Inner freedom is something entirely "
        "different. It has its roots not in the idea of freedom but in the reality of freedom. It covers "
        "all the endeavours of man. Without inner freedom life will always be an activity within the "
        "limited circle of time and conflict."
    ),
)

RESTORATIONS["ctet-p1-2019-stimulus-en-pr-129"] = dict(
    file=EXAMS / "ctet/paper-1/language-2/english/stimuli.ndjson",
    loc="en",
    src="Studyfry CTET 08-Dec-2019 Paper-I English-II, passage and Q129-135 reproduction "
        "(https://www.studyfry.com/ctet-exam-paper-8-december-2019-paper-1-answer-key-english-2)",
    must=["Water is the core of life", "The Himalayas serve as water towers",
          "benevolent climate", "bounty of the Himalayas", "Uttarakhand are especially rich in water resources",
          "perennial streams"],
    minQ=7,
    text=(
        "Water is the core of life; hence water must be central to our spiritual thinking. Water is "
        "not only most of earth, but also most of life. Therefore water conservation must be our "
        "deepest concern.\n\n"
        "The Himalayan mountain range is among the highest, youngest and most fragile ecosystem of the "
        "planet. The Himalayas have given us some of the great river systems of the earth including the "
        "Indus, Ganga, Brahmaputra, Nu Salween, Yangtze and the Mekong. The Himalayas are also called "
        "the ‘Third Pole’, for they contain the largest mass of ice and snow outside the earth’s polar "
        "region, the north and south poles. There is a permanent snowline above 5,000 metres. Some of "
        "the glaciers in the region are the longest outside the two poles.\n\n"
        "The Himalayas serve as water towers, providing water on a sustained basis to more than 1,000 "
        "million people and millions of hectares of land in South Asia. The greenery, benevolent climate, "
        "highly productive ecosystems, food production and overall happiness in South Asia are in fact, "
        "attributable to the bounty of the Himalayas. They are not only beautiful; they are life-givers. "
        "Little wonder that they are venerated as the abode of gods.\n\n"
        "To keep the Third Pole preserved through assured conservation is one of the greatest challenges "
        "for the contemporary world. Himalayan mountains are a common but fragile natural resource. As "
        "mountain ecosystems have enormous bearing on the earth’s systems, their special care, regeneration "
        "and conservation of their pristine resources would only bring more happiness, peace and prosperity "
        "to large parts of the world. In Agenda 21, Chapter 13 of the United Nations, the importance of "
        "mountains is underlined: ‘mountain environments are essential to the survival of global ecosystems.’ "
        "The Himalayas in the state of Uttarakhand are especially rich in water resources. This area is home "
        "to dozens of perennial streams and numerous other rain-fed rivers along with innumerable rivulets, "
        "waterfalls and ponds, etc."
    ),
)

RESTORATIONS["ctet-p1-2023-stimulus-en-pr-97"] = dict(
    file=EXAMS / "ctet/paper-1/language-1/english/stimuli.ndjson",
    loc="en",
    src="Testbook reproduction of the Geeta Garud/Mizoram passage, cross-checked against "
        "the CTET 20-Aug-2023 Paper-I English-I question cues "
        "(https://testbook.com/question-answer/garud-travelled-alone-as--68fda139059ccd6eed81e64a)",
    must=["Geeta Garud, 69", "found no takers", "danced impromptu at a festival in Reiek",
          "waded into a river", "went horse-riding", "athlete in her youth",
          "farm in Koregaon", "sense of joy and freedom"],
    minQ=9,
    text=(
        "In the middle of her solo trip to Mizoram last month, Geeta Garud, 69, was walking on a "
        "narrow ledge, ‘making my way behind a waterfall, trying out something I wouldn’t have in my "
        "younger years. And I realised how travelling solo was such a liberating experience.’\n\n"
        "Before going on her week-long holiday, she was hesitant about travelling by herself. Garud had "
        "asked friends and family but found no takers. Yet there she was, alone, relishing a challenging "
        "trek. ‘Why was I being dependent on others? Being alone gives you a sense of freedom.’\n\n"
        "She ended up having many firsts. She danced impromptu at a festival in Reiek, waded into a river, "
        "and went horse-riding. ‘I had opportunities to try horse-riding when I was younger, but could not "
        "work up the courage. This time, I thought, if not now, I may not get another chance,’ says Garud, "
        "who was an athlete in her youth and had played cricket.\n\n"
        "She was at her farm in Koregaon during the lockdown and had felt the lack of social connections. "
        "It motivated her to travel as soon as things eased.\n\n"
        "‘Travel is also about meeting people; I felt that sense of joy and freedom when I finally did it.’ "
        "She is planning to travel to Europe next and has decided not to take a friend or relative along. "
        "She intends to revisit the joy of travelling alone and relishing a sense of freedom all over again."
    ),
)

RESTORATIONS["ctet-p1-2024-stimulus-en-pr-91"] = dict(
    file=EXAMS / "ctet/paper-1/language-1/english/stimuli.ndjson",
    loc="en",
    src="Morley Callaghan, ‘All the Years of Her Life,’ New Yorker original (08-Jun-1935), "
        "matched to the CTET 21-Jan-2024 passage/Qs "
        "(https://www.newyorker.com/magazine/1935/06/08/all-the-years-of-her-life)",
    must=["her blue eyes never wavered", "clothes seemed to have been thrown on her",
          "lack of terror", "compacts and toothpaste and lipsticks", "her humility made her falter",
          "What did you intend to do, Mr. Carr?", "I was going to get a cop",
          "a little good advice is the best thing for a boy", "she would be in a rage"],
    minQ=9,
    text=(
        "Mrs. Higgins must have been going to bed when he telephoned, for her hair was tucked in loosely "
        "under her hat, and her hand at her throat held her light coat tight across her chest so her dress "
        "would not show. She came in, large and plump, with a little smile on her friendly face. Most of "
        "the store lights had been turned out and at first she did not see Alfred, who was standing in the "
        "shadow at the end of the counter. Yet as soon as she saw him she did not look as Alfred thought "
        "she would look: she smiled, her blue eyes never wavered, and with a calmness and dignity that made "
        "them forget that her clothes seemed to have been thrown on her, she put out her hand to Mr. Carr "
        "and said politely, ‘I’m Mrs. Higgins. I’m Alfred’s mother.’\n\n"
        "Mr. Carr was a bit embarrassed by her lack of terror and her simplicity, and he hardly knew what "
        "to say to her, so she asked, ‘Is Alfred in trouble?’\n\n"
        "‘He is. He’s been taking things from the store. I caught him red-handed. Little things like "
        "compacts and toothpaste and lipsticks. Stuff he can sell easily,’ the proprietor said.\n\n"
        "As she listened Mrs. Higgins looked at Alfred sometimes and nodded her head sadly, and when Sam "
        "Carr had finished she said gravely, ‘Is it so, Alfred?’\n\n"
        "‘Yes.’\n\n"
        "‘Why have you been doing it?’\n\n"
        "‘I been spending money, I guess.’\n\n"
        "‘On what?’\n\n"
        "‘Going around with the guys, I guess,’ Alfred said.\n\n"
        "Mrs. Higgins put out her hand and touched Sam Carr’s arm with an understanding gentleness and, "
        "speaking as though afraid of disturbing him, she said, ‘If you would only listen to me before "
        "doing anything.’ Her simple earnestness made her shy; her humility made her falter and look away, "
        "but in a moment she was smiling gravely again and she said with a kind of patient dignity, ‘What "
        "did you intend to do, Mr. Carr?’\n\n"
        "‘I was going to get a cop. That’s what I ought to do.’\n\n"
        "‘Yes, I suppose so. It’s not for me to say, because he’s my son. Yet I sometimes think a little "
        "good advice is the best thing for a boy when he is at a certain period in his life,’ she said.\n\n"
        "Alfred couldn’t understand his mother’s quiet composure, for if they had been at home and someone "
        "had suggested that he was going to be arrested, he knew she would be in a rage and would cry out "
        "against him."
    ),
)

RESTORATIONS["ctet-p1-2024-stimulus-en-pr-121"] = dict(
    file=EXAMS / "ctet/paper-1/language-2/english/stimuli.ndjson",
    loc="en",
    src="L. Frank Baum, The Wonderful Wizard of Oz, Chapter 7, public-domain CMU text, "
        "verified against CTET 21-Jan-2024 Q121-128 "
        "(https://www.cs.cmu.edu/~rgs/oz-7.html)",
    must=["the Scarecrow found a tree full of nuts", "filled Dorothy’s basket", "no one ever knew what it was",
          "feared a spark might get into his straw", "These kept her very snug and warm"],
    minQ=8,
    text=(
        "They were obliged to camp out that night under a large tree in the forest, for there were no "
        "houses near. The tree made a good, thick covering to protect them from the dew, and the Tin "
        "Woodman chopped a great pile of wood with his axe and Dorothy built a splendid fire that warmed "
        "her and made her feel less lonely. She and Toto ate the last of their bread, and now she did not "
        "know what they would do for breakfast.\n\n"
        "‘If you wish,’ said the Lion, ‘I will go into the forest and kill a deer for you. You can roast "
        "it by the fire, since your tastes are so peculiar that you prefer cooked food, and then you will "
        "have a very good breakfast.’\n\n"
        "‘Don’t! Please don’t,’ begged the Tin Woodman. ‘I should certainly weep if you killed a poor deer, "
        "and then my jaws would rust again.’\n\n"
        "But the Lion went away into the forest and found his own supper, and no one ever knew what it "
        "was, for he didn’t mention it. And the Scarecrow found a tree full of nuts and filled Dorothy’s "
        "basket with them, so that she would not be hungry for a long time. She thought this was very "
        "kind and thoughtful of the Scarecrow, but she laughed heartily at the awkward way in which the "
        "poor creature picked up the nuts. His padded hands were so clumsy and the nuts were so small "
        "that he dropped almost as many as he put in the basket. But the Scarecrow did not mind how long "
        "it took him to fill the basket, for it enabled him to keep away from the fire, as he feared a "
        "spark might get into his straw and burn him up. So he kept a good distance away from the flames, "
        "and only came near to cover Dorothy with dry leaves when she lay down to sleep. These kept her "
        "very snug and warm, and she slept soundly until morning."
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

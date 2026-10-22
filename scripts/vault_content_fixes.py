#!/usr/bin/env python3
"""Curated content fixes for the bundled vault.

The vault was imported from several source dumps.  A subset of the English
translations was attached to the wrong Hindi question (the source rows were
shifted while the papers were shuffled), and a subset of the answer keys was
scrambled for the questions that a mock paper copied from an official board
paper.

This module holds the human-verified data for those repairs:

``FOREIGN_EN_FAMILIES``
    The correct English stem and the correct English option per Hindi
    option, for every question family whose English data was foreign.

``ANSWER_KEY_OVERRIDES``
    Explicit answer index corrections for the questions where the official
    board paper and the mock paper disagree and no automatic rule applies.

``ORPHAN_QUESTION_IDS``
    Questions whose stimulus (reading / figure) does not exist anywhere in
    the vault.  They are replaced by a self-contained question of the same
    section so that the candidate can always answer them.

``OPTION_TEXT_FIXES``
    Small option-level corrections (stray markers, shifted lists).

The data is keyed on the normalised Hindi text, never on a question id, so
the repair keeps working when the vault is regenerated.
"""

from __future__ import annotations

# ---------------------------------------------------------------------------
# 1. Foreign English translations
# ---------------------------------------------------------------------------
# Each entry: hi_stem (normalised Hindi stem) -> English stem plus a
# mapping "normalised Hindi option" -> "English option".
FOREIGN_EN_FAMILIES: dict[str, dict] = {
    # --- EVS ---------------------------------------------------------------
    "खाद्य श्रृंखला (food chain) में ऊर्जा का प्रवाह होता है :": {
        "en_stem": "The flow of energy in a food chain is:",
        "options": {
            "उत्पादक → शाकाहारी → मांसाहारी": "Producer -> Herbivore -> Carnivore",
            "मांसाहारी → शाकाहारी → उत्पादक": "Carnivore -> Herbivore -> Producer",
            "शाकाहारी → उत्पादक → मांसाहारी": "Herbivore -> Producer -> Carnivore",
            "उत्पादक → मांसाहारी → शाकाहारी": "Producer -> Carnivore -> Herbivore",
        },
    },
    "विघटक (decomposers) का कार्य है :": {
        "en_stem": "The function of decomposers is:",
        "options": {
            "भोजन बनाना": "Making food",
            "मृत जीवों को तोड़ना": "Breaking down dead organisms",
            "शिकार करना": "Hunting",
            "प्रकाश संश्लेषण": "Photosynthesis",
        },
    },
    "वनों की कटाई (deforestation) का प्रभाव है :": {
        "en_stem": "Effect of deforestation is:",
        "options": {
            "ऑक्सीजन बढ़ता है": "Oxygen increases",
            "मिट्टी का अपरदन (erosion)": "Soil erosion",
            "वर्षा बढ़ती है": "Rainfall increases",
            "जलवायु ठंडा होता है": "Climate becomes colder",
        },
    },
    "evs में 'क्यों' वाले प्रश्न पूछने का उद्देश्य है :": {
        "en_stem": "'Why' questions in EVS are for:",
        "options": {
            "रटना": "Memorization",
            "स्पष्टीकरण (explanation)": "Explanation",
            "डराना": "Intimidating",
            "मनोरंजन": "Entertainment",
        },
    },
    "evs और पर्यावरण शिक्षा (environmental education) में अंतर है :": {
        "en_stem": "EVS is broader than Environmental Education because:",
        "options": {
            "कोई अंतर नहीं": "There is no difference",
            "evs व्यापक है (परिवार, भोजन, आवास आदि), environmental education केवल पर्यावरण पर ध्यान देता है":
                "EVS is broader (family, food, shelter etc.) while Environmental Education "
                "focuses only on the environment",
            "environmental education व्यापक है": "Environmental Education is broader",
            "दोनों एक ही हैं": "Both are the same",
        },
    },
    "धान का खेत (paddy field) किस प्रकार का पारिस्थितिकी तंत्र है ?": {
        "en_stem": "A paddy field is what kind of ecological system?",
        "options": {
            "प्राकृतिक": "Natural",
            "कृत्रिम": "Artificial",
            "जलीय": "Aquatic",
            "तटीय": "Coastal",
        },
    },
    "पानी में फ्लोराइड (fluoride) की अधिकतम सीमा है :": {
        "en_stem": "The maximum permissible limit of fluoride in water is:",
        "options": {
            "0.5 mg/l": "0.5 mg/L",
            "1.0 mg/l": "1.0 mg/L",
            "1.5 mg/l": "1.5 mg/L",
            "2.0 mg/l": "2.0 mg/L",
        },
    },
    "नाइट्रेट (nitrate) की अधिकता से कौन-सा संलक्षण (syndrome) होता है ?": {
        "en_stem": "Excess of nitrate in water causes which syndrome?",
        "options": {
            "नील-शिशु संलक्षण (blue baby syndrome)": "Blue baby syndrome",
            "गलघोंटू": "Jaundice",
            "हैज़ा": "Cholera",
            "टाइफॉइड": "Typhoid",
        },
    },
    "गंगा कार्य योजना (ganga action plan) कब शुरू हुई ?": {
        "en_stem": "When was the Ganga Action Plan started?",
        "options": {
            "1980": "1980",
            "1985/86": "1985/86",
            "1990": "1990",
            "1995": "1995",
        },
    },
    "ओजोन (ozone) परत का ह्रास (depletion) सबसे अधिक कहाँ होता है ?": {
        "en_stem": "Depletion of the ozone layer is maximum at:",
        "options": {
            "उत्तरी ध्रुव": "North Pole",
            "दक्षिणी ध्रुव": "South Pole",
            "भूमध्य रेखा": "Equator",
            "ट्रॉपिक ऑफ कैंसर": "Tropic of Cancer",
        },
    },
    "अपूर्ण दहन (incomplete combustion) से कौन-सा गैस निकलता है ?": {
        "en_stem": "Which gas is released by incomplete combustion?",
        "options": {
            "co₂": "CO2",
            "co (carbon monoxide)": "CO (Carbon Monoxide)",
            "o₂": "O2",
            "n₂": "N2",
        },
    },
    "eia (environment impact assessment) का अर्थ है :": {
        "en_stem": "EIA (Environment Impact Assessment) stands for:",
        "options": {
            "पर्यावरण प्रभाव आकलन": "Environmental Impact Assessment",
            "आर्थिक प्रभाव आकलन": "Economic Impact Assessment",
            "सामाजिक प्रभाव आकलन": "Social Impact Assessment",
            "तकनीकी प्रभाव आकलन": "Technical Impact Assessment",
        },
    },
    "मीनामाता रोग (minamata disease) किससे होता है ?": {
        "en_stem": "Minamata disease is caused by:",
        "options": {
            "सीसा (lead)": "Lead",
            "पारा (mercury)": "Mercury",
            "आर्सेनिक": "Arsenic",
            "कैडमियम": "Cadmium",
        },
    },
    "कार्बन क्रेडिट (carbon credit) किससे जुड़ा है ?": {
        "en_stem": "Carbon Credit is associated with:",
        "options": {
            "मॉन्ट्रियल प्रोटोकॉल": "Montreal Protocol",
            "क्योटो प्रोटोकॉल": "Kyoto Protocol",
            "रियो शिखर सम्मेलन": "Rio Summit",
            "जी-8 शिखर सम्मेलन": "G-8 Summit",
        },
    },
    "wii (wildlife institute of india) कहाँ स्थित है ?": {
        "en_stem": "WII (Wildlife Institute of India) is located at:",
        "options": {
            "नई दिल्ली": "New Delhi",
            "देहरादून": "Dehradun",
            "मुंबई": "Mumbai",
            "कोलकाता": "Kolkata",
        },
    },
    "बायोडीजल (biodiesel) किस पौधे से बनता है ?": {
        "en_stem": "Biodiesel is made from which plant?",
        "options": {
            "नीम": "Neem",
            "जेट्रोफा (jatropha)": "Jatropha",
            "बांस": "Bamboo",
            "तुलसी": "Tulsi",
        },
    },
    "क्रायो-संरक्षण (cryo-preservation) में किसका उपयोग होता है ?": {
        "en_stem": "Cryo-preservation uses which of the following?",
        "options": {
            "बर्फ (ice)": "Ice",
            "तरल नाइट्रोजन (liquid nitrogen)": "Liquid nitrogen",
            "अमोनिया": "Ammonia",
            "कार्बन टेट्राक्लोराइड": "Carbon tetrachloride",
        },
    },
    "स्थानिक प्रजाति (endemic species) का अर्थ है :": {
        "en_stem": "Endemic species means:",
        "options": {
            "विलुप्त प्रजाति": "Extinct species",
            "किसी विशेष क्षेत्र तक सीमित प्रजाति": "Species confined to a particular area",
            "विदेशी प्रजाति": "Foreign species",
            "खतरे में प्रजाति": "Endangered species",
        },
    },
    "नाइट्रोजन स्थिरीकरण (nitrogen fixation) किस बैक्टीरिया द्वारा होता है ?": {
        "en_stem": "Nitrogen fixation is carried out by which bacterium?",
        "options": {
            "राइज़ोबियम (rhizobium)": "Rhizobium",
            "लैक्टोबैसिलस": "Lactobacillus",
            "ई. कोलाई": "E. coli",
            "स्ट्रेप्टोकोकस": "Streptococcus",
        },
    },
    "माइकोराइज़ा (mycorrhiza) किस पेड़ से जुड़ा है ?": {
        "en_stem": "Mycorrhiza is associated with which tree?",
        "options": {
            "बरगद": "Banyan",
            "चीड़ (pine)": "Pine",
            "नीम": "Neem",
            "पीपल": "Peepal",
        },
    },
    "आपदा प्रबन्धन (disaster management) किस सूची में आता है ?": {
        "en_stem": "Disaster management comes under which list?",
        "options": {
            "केन्द्रीय सूची": "Central list",
            "राज्य सूची": "State list",
            "समवर्ती सूची (concurrent list)": "Concurrent list",
            "कोई नहीं": "None",
        },
    },
    "'ecomark' किससे संबंधित है ?": {
        "en_stem": "'Ecomark' is related to:",
        "options": {
            "निर्यात वस्तुएँ": "Export goods",
            "आयात वस्तुएँ": "Import goods",
            "सर्वोत्तम गुणवत्ता वस्तुएँ": "Best quality goods",
            "पर्यावरण-अनुकूल वस्तुएँ": "Environment-friendly goods",
        },
    },
    # --- Mathematics --------------------------------------------------------
    "वृत्त का क्षेत्रफल (area of circle) =": {
        "en_stem": "Area of circle =",
        "options": {
            "2πr": "2*pi*r",
            "πr²": "pi*r^2",
            "2πr²": "2*pi*r^2",
            "πd": "pi*d",
        },
    },
    "एक घन (cube) का आयतन (volume) =": {
        "en_stem": "Volume of a cube =",
        "options": {
            "a²": "a^2",
            "a³": "a^3",
            "6a²": "6a^2",
            "4a³": "4a^3",
        },
    },
    "एक घन का कुल पृष्ठीय क्षेत्रफल (total surface area) =": {
        "en_stem": "Total Surface Area of a cube =",
        "options": {
            "a²": "a^2",
            "a³": "a^3",
            "6a²": "6a^2",
            "4a²": "4a^2",
        },
    },
    "एक समबाहु त्रिभुज (equilateral triangle) कभी नहीं हो सकता :": {
        "en_stem": "An equilateral triangle can never be:",
        "options": {
            "न्यूनकोण त्रिभुज": "Obtuse-angled triangle",
            "समकोण त्रिभुज": "Right-angled triangle",
            "अधिककोण त्रिभुज": "Acute-angled triangle",
            "बहुभुज": "Polygon",
        },
    },
    "lcm (लघुत्तम समापवर्त्य) और hcf (महत्तम समापवर्तक) में सम्बन्ध है :": {
        "en_stem": "The relation between LCM and HCF is:",
        "options": {
            "lcm × hcf = दो संख्याओं का योग": "LCM x HCF = sum of the two numbers",
            "lcm × hcf = दो संख्याओं का गुणनफल": "LCM x HCF = product of the two numbers",
            "lcm + hcf = दो संख्याओं का योग": "LCM + HCF = sum of the two numbers",
            "lcm − hcf = दो संख्याओं का अन्तर": "LCM - HCF = difference of the two numbers",
        },
    },
    "12 और 18 का hcf होगा :": {
        "en_stem": "HCF of 12 and 18 will be:",
        "options": {"2": "2", "3": "3", "6": "6", "9": "9"},
    },
    "12 और 18 का lcm होगा :": {
        "en_stem": "LCM of 12 and 18 will be:",
        "options": {"24": "24", "30": "30", "36": "36", "42": "42"},
    },
    "औसत चाल (average speed) का सूत्र है :": {
        "en_stem": "The formula for average speed is:",
        "options": {
            "(x + y) / 2": "(x + y) / 2",
            "2xy / (x + y)": "2xy / (x + y)",
            "xy / (x + y)": "xy / (x + y)",
            "(x − y) / 2": "(x - y) / 2",
        },
    },
    # --- English ------------------------------------------------------------
    "त्रिभुज में कम-से-कम कितने न्यूनकोण (acute angles) होते हैं ?": {
        "en_stem": "What is the minimum number of acute angles in a triangle?",
        "options": {"0": "0", "1": "1", "2": "2", "3": "3"},
    },
    "पृथ्वी दिवस (earth day) कब मनाया जाता है ?": {
        "en_stem": "When is Earth Day observed?",
        "options": {
            "22 जनवरी": "22 January",
            "22 मार्च": "22 March",
            "22 अप्रैल": "22 April",
            "22 मई": "22 May",
        },
    },
    "nidm (national institute of disaster management) कहाँ स्थित है ?": {
        "en_stem": "NIDM (National Institute of Disaster Management) is located at:",
        "options": {
            "पुणे": "Pune",
            "मिदनापुर": "Midnapur",
            "नई दिल्ली": "New Delhi",
            "कोलकाता": "Kolkata",
        },
    },
    "कार्बन फुटप्रिंट (carbon footprint) सबसे अधिक किस निर्माण सामग्री का होता है ?": {
        "en_stem": "The carbon footprint is highest for which building material?",
        "options": {
            "बांस": "Bamboo",
            "पुनर्नवीनीकरण इस्पात": "Recycled steel",
            "कंक्रीट": "Concrete",
            "पुनर्निर्मित लकड़ी": "Reclaimed wood",
        },
    },
    "टिकाऊ आवास (sustainable housing) की विशेषता है :": {
        "en_stem": "A feature of sustainable housing is:",
        "options": {
            "उच्च ऊर्जा खपत": "High energy consumption",
            "स्थानीय और पुनर्नवीनीकरण सामग्री का उपयोग": "Use of local and recycled material",
            "पक्के सतहों का बड़ा क्षेत्र": "Large area of hard surfaces",
            "गैर-नवीकरणीय ऊर्जा पर निर्भरता": "Dependence on non-renewable energy",
        },
    },
    "find out which part of the sentence has an error: what to speak off refreshment (a) / she did not ask me (b) / even for a glass of water. (c) / no error (d)": {
        "en_stem": "Find out which part of the sentence has an error:",
        "options": {
            "what to speak off refreshment": "What to speak off refreshment",
            "she did not ask me": "she did not ask me",
            "even for a glass of water.": "even for a glass of water.",
            "no error": "No error",
        },
    },
    '2017 के पुत्तुस्वामी मामले में भारत के सर्वोच्च न्यायालय ने माना कि गोपनीयता का अधिकार:': {
        "en_stem": 'In the Puttaswamy case of 2017 the Supreme Court of India held that the right to privacy is:',
        "options": {
            'संविधान द्वारा संरक्षित नहीं है': 'not protected by the constitution',
            'संविधान के अंतर्गत एक मौलिक अधिकार है': 'a fundamental right under the constitution',
            'केवल एक वैधानिक अधिकार है': 'only a legal right',
            'केवल लिखित संप्रेषण तक सीमित है': 'limited only to written communication',
        },
    },
    'kohlberg के नैतिक विकास का तीसरा स्तर (post-conventional level) किस पर आधारित है ?': {
        "en_stem": "Kohlberg's third level (Post-conventional level) of moral development is based on:",
        "options": {
            'दण्ड और पुरस्कार': 'punishment and reward',
            'समाज के नियम': "society's rules",
            'सार्वभौमिक नैतिक सिद्धान्त': 'universal moral principles',
            'अभिभावक का निर्देश': "parent's guidance",
        },
    },
    "vygotsky का 'more knowledgeable other' (mko) का अर्थ है :": {
        "en_stem": "Vygotsky's 'More Knowledgeable Other' (MKO) means:",
        "options": {
            'बच्चा': 'child',
            'शिक्षक/साथी': 'teacher/peer',
            'अभिभावक': 'parent',
            'पाठ्यपुस्तक': 'textbook',
        },
    },
    'एक आयत का क्षेत्रफल = लम्बाई × चौड़ाई। यदि लम्बाई 8 cm और चौड़ाई 5 cm है, तो क्षेत्रफल होगा :': {
        "en_stem": 'If two numbers have sum 25 and product 144, their difference will be:',
        "options": {
            '35 cm²': '35 cm²',
            '40 cm²': '40 cm²',
            '45 cm²': '45 cm²',
            '50 cm²': '50 cm²',
        },
    },
    'एक परिमेय और एक अपरिमेय संख्या का गुणनफल होता है :': {
        "en_stem": 'The product of a rational and an irrational number is:',
        "options": {
            'परिमेय': 'rational',
            'अपरिमेय': 'irrational',
            'पूर्णांक': 'integer',
            'भाज्य': 'divisor',
        },
    },
    'एक परिमेय और एक अपरिमेय संख्या का योग होता है :': {
        "en_stem": 'Sum of a rational and an irrational number is:',
        "options": {
            'परिमेय': 'rational',
            'अपरिमेय': 'irrational',
            'पूर्णांक': 'integer',
            'भाज्य': 'divisor',
        },
    },
    'गणित में कम उपलब्धि (underachievement) का मुख्य कारण है :': {
        "en_stem": 'Main cause of underachievement in math is:',
        "options": {
            'लिंग': 'gender',
            'विषय की प्रकृति': 'nature of subject',
            'सामाजिक-सांस्कृतिक पृष्ठभूमि': 'exam method',
            'परीक्षा पद्धति': 'socio-cultural background',
        },
    },
    'गणित में त्रुटि-विश्लेषण (error analysis) का उद्देश्य है :': {
        "en_stem": 'Purpose of error analysis in math is:',
        "options": {
            'छात्रों को दण्ड देना': 'punishing students',
            'त्रुटियों का निदान और उपचार': 'diagnosis and treatment of errors',
            'छात्रों की तुलना करना': 'comparing students',
            'परीक्षा लेना': 'taking exams',
        },
    },
    'गणित में दुश्चिंता (math anxiety) का मुख्य कारण है :': {
        "en_stem": 'Main cause of math anxiety is:',
        "options": {
            'लिंग': 'gender',
            'विषय की प्रकृति': 'nature of subject',
            'परीक्षा पद्धति': 'exam method',
            'सामाजिक-सांस्कृतिक पृष्ठभूमि': 'socio-cultural background',
        },
    },
    'गणित शिक्षण में सबसे महत्त्वपूर्ण पहलू क्या है?': {
        "en_stem": 'Most important thing in Mathematics teaching is :',
        "options": {
            'प्रक्रिया याद रखना': 'remembering procedures',
            'सूत्र याद करना': 'memorizing formulas',
            'सही उत्तर प्राप्त करना': 'getting correct answer',
            'अवधारणात्मक समझ': 'conceptual understanding',
        },
    },
    'गणित शिक्षण में सबसे महत्वपूर्ण पहलू क्या है ?': {
        "en_stem": 'Most important aspect in math teaching is:',
        "options": {
            'प्रक्रिया याद रखना': 'remembering procedures',
            'सूत्र याद करना': 'memorizing formulas',
            'सही उत्तर प्राप्त करना': 'getting correct answer',
            'अवधारणात्मक समझ': 'conceptual understanding',
        },
    },
    'गणित शिक्षण में सबसे महत्वपूर्ण पहलू क्या है?': {
        "en_stem": 'What is the most important aspect of teaching mathematics?',
        "options": {
            'प्रक्रिया याद रखना': 'remembering procedures',
            'सूत्र याद करना': 'memorizing formulas',
            'सही उत्तर प्राप्त करना': 'getting correct answer',
            'अवधारणात्मक समझ': 'conceptual understanding',
        },
    },
    'गणित-भय दूर करने का सबसे अच्छा तरीका है :': {
        "en_stem": 'Best way to overcome math fear is:',
        "options": {
            'अधिक होमवर्क': 'more homework',
            'दण्ड देना': 'punishment',
            'अधिक परीक्षा': 'more exams',
            'खेल, पहेली और वास्तविक जीवन से जोड़ना': 'games, puzzles and real life connections',
        },
    },
    'गरीब बच्चे के लिए समावेशी शिक्षा में शिक्षक क्या करे ?': {
        "en_stem": 'What should a teacher do for a poor child in inclusive education?',
        "options": {
            'कक्षा से बाहर बैठाए': 'seat outside classroom',
            'डाँटे': 'scold',
            'वैकल्पिक सामग्री/बुक-बैंक उपलब्ध कराए': 'provide alternative material/book-bank',
            'परीक्षा से वंचित करे': 'exclude from exam',
        },
    },
    'जब दो चर वाले रैखिक समीकरण का ग्राफ खींचा जाता है, तो यह सदैव होता है :': {
        "en_stem": 'When the graph of a linear equation in two variables is drawn, it is always a :',
        "options": {
            'परवलय': 'parabola',
            'दीर्घवृत्त': 'ellipse',
            'सरल रेखा': 'straight line',
            'वृत्त': 'circle',
        },
    },
    'जब दो चर वाले रैखिक समीकरण का ग्राफ खींचा जाता है, तो यह सदैव होता है एक': {
        "en_stem": 'When graph of a two-variable linear equation is drawn, it is always a:',
        "options": {
            'परवलय': 'parabola',
            'दीर्घवृत्त': 'ellipse',
            'सरल रेखा': 'straight line',
            'वृत्त': 'circle',
        },
    },
    'जब दो चर वाले रैखिक समीकरण का ग्राफ खींचा जाता है, तो यह होता है :': {
        "en_stem": 'When the graph of a linear equation in two variables is drawn, it is:',
        "options": {
            'परवलय': 'parabola',
            'दीर्घवृत्त': 'ellipse',
            'सरल रेखा': 'straight line',
            'वृत्त': 'circle',
        },
    },
    'जीन पियाजे (jean piaget) का जन्म किस देश में हुआ ?': {
        "en_stem": 'In which country was Jean Piaget born?',
        "options": {
            'फ्रांस': 'France',
            'स्विट्जरलैंड': 'Switzerland',
            'जर्मनी': 'Germany',
            'इंग्लैंड': 'England',
        },
    },
    'पारिस्थितिकी तंत्र (ecosystem) में ऊर्जा का प्रवाह होता है :': {
        "en_stem": 'The flow of energy in an ecosystem is:',
        "options": {
            'द्विदिशीय (दोनों दिशाओं में)': 'bidirectional (in both directions)',
            'एकदिशीय (एक दिशा में)': 'unidirectional (in one direction)',
            'चक्रीय': 'cyclic',
            'बिना दिशा': 'directionless',
        },
    },
    "पियाजे के अनुसार 'संरक्षण' (conservation) किस अवस्था में विकसित होता है ?": {
        "en_stem": "According to Piaget, 'Conservation' develops in which stage?",
        "options": {
            'संवेदी-प्रेरक': 'sensorimotor',
            'पूर्व-संक्रियात्मक': 'pre-operational',
            'मूर्त-संक्रियात्मक': 'concrete operational',
            'औपचारिक': 'formal operational',
        },
    },
    'प्राथमिक स्तर पर गणित का क्या महत्व है ?': {
        "en_stem": 'What is the importance of math at primary level?',
        "options": {
            'सांस्कृतिक': 'cultural',
            'सामाजिक': 'social',
            'धार्मिक': 'religious',
            'मानसिक': 'mental',
        },
    },
    'प्राथमिक स्तर पर गणित का क्या महत्व है?': {
        "en_stem": 'What is the importance of mathematics at the primary level?',
        "options": {
            'सांस्कृतिक': 'cultural',
            'सामाजिक': 'social',
            'धार्मिक': 'religious',
            'मानसिक': 'mental',
        },
    },
    'प्राथमिक स्तर पर गणित का महत्व है :': {
        "en_stem": 'Importance of math at primary level is:',
        "options": {
            'सांस्कृतिक': 'cultural',
            'सामाजिक': 'social',
            'धार्मिक': 'religious',
            'मानसिक': 'mental',
        },
    },
    'प्ले-वे (play-way) विधि किस आयु के लिए सबसे उपयुक्त है ?': {
        "en_stem": 'Play-way method is most suitable for which age?',
        "options": {
            'वयस्क': 'adult',
            'किशोर': 'adolescent',
            'बाल्यावस्था': 'childhood',
            'वृद्धावस्था': 'old age',
        },
    },
    'फ्रोबेल (froebel) ने किस शिक्षा पद्धति का विकास किया ?': {
        "en_stem": 'Froebel developed which teaching method?',
        "options": {
            'मोंटेसरी पद्धति': 'montessori method',
            'किंडरगार्टन पद्धति': 'kindergarten method',
            'प्रोजेक्ट पद्धति': 'project method',
            'प्ले-वे पद्धति': 'play-way method',
        },
    },
    'भारत का प्रथम राष्ट्रीय उद्यान (1936) था :': {
        "en_stem": "India's first national park (1936) was:",
        "options": {
            'कान्हा राष्ट्रीय उद्यान': 'Kanha National Park',
            'भरतपुर राष्ट्रीय उद्यान': 'Bharatpur National Park',
            'हैली (कॉर्बेट) राष्ट्रीय उद्यान': 'Hailley (Corbett) National Park',
            'राजाजी राष्ट्रीय उद्यान': 'Rajaji National Park',
        },
    },
    'भारत में सबसे अधिक वन क्षेत्र किस प्रकार का है ?': {
        "en_stem": 'Which type of forest covers the largest area in India?',
        "options": {
            'उष्णकटिबंधीय नम पर्णपाती': 'tropical moist deciduous forests',
            'उष्णकटिबंधीय सूखा पर्णपाती': 'tropical dry deciduous forests',
            'शीतोष्ण मिश्रित': 'temperate mixed forests',
            'अल्पाइन': 'alpine forests',
        },
    },
    'मोंटेसरी (montessori) शिक्षा का मुख्य तत्व है :': {
        "en_stem": 'The main element of Montessori education is:',
        "options": {
            'इन्द्रिय-प्रशिक्षण (sensory training)': 'sensory training',
            'रटना': 'rote learning',
            'परीक्षा': 'exam',
            'दण्ड': 'punishment',
        },
    },
    'यदि एक संख्या का 20% = 50 है, तो संख्या होगी :': {
        "en_stem": 'If 20% of a number is 50, the number is:',
        "options": {
            '200': '200',
            '250': '250',
            '300': '300',
            '350': '350',
        },
    },
    'यदि एक संख्या का 25% = 75 है, तो संख्या होगी :': {
        "en_stem": 'If 25% of a number is 75, the number will be:',
        "options": {
            '200': '200',
            '250': '250',
            '300': '300',
            '350': '350',
        },
    },
    'यदि किसी वस्तु का मूल्य ₹500 है और उस पर 10% छूट मिलती है, तो बिक्री मूल्य होगा :': {
        "en_stem": 'If an article costs Rs 500 and a 10% discount is offered, the selling price is:',
        "options": {
            '₹400': '₹400',
            '₹425': '₹425',
            '₹450': '₹450',
            '₹475': '₹475',
        },
    },
    'योगात्मक मूल्यांकन (summative assessment) का उद्देश्य है :': {
        "en_stem": 'The purpose of Summative Assessment is:',
        "options": {
            'सुधार हेतु': 'for improvement',
            'ग्रेड/पदोन्नति हेतु': 'for grades/promotion',
            'त्रुटियाँ पहचानना': 'to identify errors',
            'अधिगम की कमियाँ पहचानना': 'to identify learning gaps',
        },
    },
    'रचनात्मक मूल्यांकन (formative assessment) का उद्देश्य है :': {
        "en_stem": 'The purpose of Formative Assessment is:',
        "options": {
            'ग्रेड देना': 'giving grades',
            'अधिगम की कमियाँ पहचानना': 'identifying learning gaps',
            'पदोन्नति देना': 'giving promotion',
            'तुलना करना': 'comparison',
            # The same question with a slightly different option wording.
            'ग्रेड/पदोन्नति देना': 'giving grades/promotion',
            'त्रुटियाँ पहचानकर सुधार करना': 'identifying errors and correcting',
            'छात्रों की तुलना करना': 'comparing students',
            'अंतिम परीक्षा लेना': 'taking final exam',
        },
    },
    'शिक्षण सहायक सामग्री (tlm) का उपयोग करते समय सबसे पहले ध्यान देना चाहिए :': {
        "en_stem": 'When using TLM, the first thing to consider is:',
        "options": {
            'आकर्षक हो': 'attractive',
            'चमकीला हो': 'bright',
            'विषय से संबंधित हो': 'related to the subject',
            'सस्ता हो': 'cheap',
        },
    },
    "समावेशी शिक्षा में 'बैरियर-फ्री' (barrier-free) का अर्थ है :": {
        "en_stem": "'Barrier-free' in inclusive education means:",
        "options": {
            'बिना बाधा का वातावरण': 'environment without barriers',
            'बाधाओं वाला वातावरण': 'environment with barriers',
            'केवल शारीरिक बाधाएँ': 'only physical barriers',
            'केवल मानसिक बाधाएँ': 'only mental barriers',
        },
    },
    'समावेशी शिक्षा में श्रवण-बाधित (hearing impaired) बच्चों के लिए उपयुक्त बैठक व्यवस्था है :': {
        "en_stem": 'Suitable seating arrangement for hearing impaired children in inclusive education is:',
        "options": {
            'अर्ध-वृत्ताकार (semi-circular)': 'semi-circular',
            'एकल पंक्ति': 'single row',
            'वृत्ताकार': 'circular',
            'चौकोर': 'square',
        },
    },
    "स्किनर (skinner) का 'shaping' का अर्थ है :": {
        "en_stem": "Skinner's 'Shaping' means:",
        "options": {
            'व्यवहार को एक बार में सिखाना': 'teaching behavior in one go',
            'व्यवहार को छोटे चरणों में सिखाना': 'teaching behavior in small steps',
            'व्यवहार को दण्ड देना': 'punishing behavior',
            'व्यवहार को नजरअंदाज करना': 'ignoring behavior',
        },
    },

    '2017 के पुत्तुस्वामी मामले में भारत के सर्वोच्च न्यायालय ने माना कि गोपनीयता का अधिकार:': {
        "en_stem": 'In the Puttaswamy case of 2017 the Supreme Court of India held that the right to privacy is:',
        "options": {
            'संविधान द्वारा संरक्षित नहीं है': 'not protected by the constitution',
            'संविधान के अंतर्गत एक मौलिक अधिकार है': 'a fundamental right under the constitution',
            'केवल एक वैधानिक अधिकार है': 'only a legal right',
            'केवल लिखित संप्रेषण तक सीमित है': 'limited only to written communication',
        },
    },
    'kohlberg के नैतिक विकास का तीसरा स्तर (post-conventional level) किस पर आधारित है ?': {
        "en_stem": "Kohlberg's third level (Post-conventional level) of moral development is based on:",
        "options": {
            'दण्ड और पुरस्कार': 'punishment and reward',
            'समाज के नियम': "society's rules",
            'सार्वभौमिक नैतिक सिद्धान्त': 'universal moral principles',
            'अभिभावक का निर्देश': "parent's guidance",
        },
    },
    "vygotsky का 'more knowledgeable other' (mko) का अर्थ है :": {
        "en_stem": "Vygotsky's 'More Knowledgeable Other' (MKO) means:",
        "options": {
            'बच्चा': 'child',
            'शिक्षक/साथी': 'teacher/peer',
            'अभिभावक': 'parent',
            'पाठ्यपुस्तक': 'textbook',
        },
    },
    'एक आयत का क्षेत्रफल = लम्बाई × चौड़ाई। यदि लम्बाई 8 cm और चौड़ाई 5 cm है, तो क्षेत्रफल होगा :': {
        "en_stem": 'If two numbers have sum 25 and product 144, their difference will be:',
        "options": {
            '35 cm²': '35 cm²',
            '40 cm²': '40 cm²',
            '45 cm²': '45 cm²',
            '50 cm²': '50 cm²',
        },
    },
    'एक परिमेय और एक अपरिमेय संख्या का गुणनफल होता है :': {
        "en_stem": 'The product of a rational and an irrational number is:',
        "options": {
            'परिमेय': 'rational',
            'अपरिमेय': 'irrational',
            'पूर्णांक': 'integer',
            'भाज्य': 'divisor',
        },
    },
    'एक परिमेय और एक अपरिमेय संख्या का योग होता है :': {
        "en_stem": 'Sum of a rational and an irrational number is:',
        "options": {
            'परिमेय': 'rational',
            'अपरिमेय': 'irrational',
            'पूर्णांक': 'integer',
            'भाज्य': 'divisor',
        },
    },
    'गणित में कम उपलब्धि (underachievement) का मुख्य कारण है :': {
        "en_stem": 'Main cause of underachievement in math is:',
        "options": {
            'लिंग': 'gender',
            'विषय की प्रकृति': 'nature of subject',
            'सामाजिक-सांस्कृतिक पृष्ठभूमि': 'exam method',
            'परीक्षा पद्धति': 'socio-cultural background',
        },
    },
    'गणित में त्रुटि-विश्लेषण (error analysis) का उद्देश्य है :': {
        "en_stem": 'Purpose of error analysis in math is:',
        "options": {
            'छात्रों को दण्ड देना': 'punishing students',
            'त्रुटियों का निदान और उपचार': 'diagnosis and treatment of errors',
            'छात्रों की तुलना करना': 'comparing students',
            'परीक्षा लेना': 'taking exams',
        },
    },
    'गणित में दुश्चिंता (math anxiety) का मुख्य कारण है :': {
        "en_stem": 'Main cause of math anxiety is:',
        "options": {
            'लिंग': 'gender',
            'विषय की प्रकृति': 'nature of subject',
            'परीक्षा पद्धति': 'exam method',
            'सामाजिक-सांस्कृतिक पृष्ठभूमि': 'socio-cultural background',
        },
    },
    'गणित शिक्षण में सबसे महत्त्वपूर्ण पहलू क्या है?': {
        "en_stem": 'Most important thing in Mathematics teaching is :',
        "options": {
            'प्रक्रिया याद रखना': 'remembering procedures',
            'सूत्र याद करना': 'memorizing formulas',
            'सही उत्तर प्राप्त करना': 'getting correct answer',
            'अवधारणात्मक समझ': 'conceptual understanding',
        },
    },
    'गणित शिक्षण में सबसे महत्वपूर्ण पहलू क्या है ?': {
        "en_stem": 'Most important aspect in math teaching is:',
        "options": {
            'प्रक्रिया याद रखना': 'remembering procedures',
            'सूत्र याद करना': 'memorizing formulas',
            'सही उत्तर प्राप्त करना': 'getting correct answer',
            'अवधारणात्मक समझ': 'conceptual understanding',
        },
    },
    'गणित शिक्षण में सबसे महत्वपूर्ण पहलू क्या है?': {
        "en_stem": 'What is the most important aspect of teaching mathematics?',
        "options": {
            'प्रक्रिया याद रखना': 'remembering procedures',
            'सूत्र याद करना': 'memorizing formulas',
            'सही उत्तर प्राप्त करना': 'getting correct answer',
            'अवधारणात्मक समझ': 'conceptual understanding',
        },
    },
    'गणित-भय दूर करने का सबसे अच्छा तरीका है :': {
        "en_stem": 'Best way to overcome math fear is:',
        "options": {
            'अधिक होमवर्क': 'more homework',
            'दण्ड देना': 'punishment',
            'अधिक परीक्षा': 'more exams',
            'खेल, पहेली और वास्तविक जीवन से जोड़ना': 'games, puzzles and real life connections',
        },
    },
    'गरीब बच्चे के लिए समावेशी शिक्षा में शिक्षक क्या करे ?': {
        "en_stem": 'What should a teacher do for a poor child in inclusive education?',
        "options": {
            'कक्षा से बाहर बैठाए': 'seat outside classroom',
            'डाँटे': 'scold',
            'वैकल्पिक सामग्री/बुक-बैंक उपलब्ध कराए': 'provide alternative material/book-bank',
            'परीक्षा से वंचित करे': 'exclude from exam',
        },
    },
    "गार्डनर (gardner) के अनुसार 'संगीतात्मक बुद्धि' (musical intelligence) का उदाहरण है :": {
        "en_stem": 'An example of musical intelligence according to Gardner is:',
        "options": {
            'गायक': 'singer',
            'चित्रकार': 'painter',
            'लेखक': 'writer',
            'खिलाड़ी': 'athlete',
        },
    },
    'जब दो चर वाले रैखिक समीकरण का ग्राफ खींचा जाता है, तो यह सदैव होता है :': {
        "en_stem": 'When the graph of a linear equation in two variables is drawn, it is always a :',
        "options": {
            'परवलय': 'parabola',
            'दीर्घवृत्त': 'ellipse',
            'सरल रेखा': 'straight line',
            'वृत्त': 'circle',
        },
    },
    'जब दो चर वाले रैखिक समीकरण का ग्राफ खींचा जाता है, तो यह सदैव होता है एक': {
        "en_stem": 'When graph of a two-variable linear equation is drawn, it is always a:',
        "options": {
            'परवलय': 'parabola',
            'दीर्घवृत्त': 'ellipse',
            'सरल रेखा': 'straight line',
            'वृत्त': 'circle',
        },
    },
    'जब दो चर वाले रैखिक समीकरण का ग्राफ खींचा जाता है, तो यह होता है :': {
        "en_stem": 'When the graph of a linear equation in two variables is drawn, it is:',
        "options": {
            'परवलय': 'parabola',
            'दीर्घवृत्त': 'ellipse',
            'सरल रेखा': 'straight line',
            'वृत्त': 'circle',
        },
    },
    'जीन पियाजे (jean piaget) का जन्म किस देश में हुआ ?': {
        "en_stem": 'In which country was Jean Piaget born?',
        "options": {
            'फ्रांस': 'France',
            'स्विट्जरलैंड': 'Switzerland',
            'जर्मनी': 'Germany',
            'इंग्लैंड': 'England',
        },
    },
    'जैविक और अजैविक घटकों के बीच अन्तःक्रिया का उदाहरण है :': {
        "en_stem": 'An example of interaction between biotic and abiotic components is:',
        "options": {
            'टिड्डा पत्ता खाता है': 'a grasshopper eats a leaf',
            'वर्षा जल झील में बहता है': 'rain water flows into a lake',
            'केंचुआ मिट्टी में बिल बनाता है': 'an earthworm makes a burrow in the soil',
            'चूहा चूहे से लड़ता है': 'a rat fights with another rat',
        },
    },
    'पारिस्थितिकी तंत्र (ecosystem) में ऊर्जा का प्रवाह होता है :': {
        "en_stem": 'The flow of energy in an ecosystem is:',
        "options": {
            'द्विदिशीय (दोनों दिशाओं में)': 'bidirectional (in both directions)',
            'एकदिशीय (एक दिशा में)': 'unidirectional (in one direction)',
            'चक्रीय': 'cyclic',
            'बिना दिशा': 'directionless',
        },
    },
    "पियाजे के अनुसार 'संरक्षण' (conservation) किस अवस्था में विकसित होता है ?": {
        "en_stem": "According to Piaget, 'Conservation' develops in which stage?",
        "options": {
            'संवेदी-प्रेरक': 'sensorimotor',
            'पूर्व-संक्रियात्मक': 'pre-operational',
            'मूर्त-संक्रियात्मक': 'concrete operational',
            'औपचारिक': 'formal operational',
        },
    },
    'प्राथमिक स्तर पर गणित का क्या महत्व है ?': {
        "en_stem": 'What is the importance of math at primary level?',
        "options": {
            'सांस्कृतिक': 'cultural',
            'सामाजिक': 'social',
            'धार्मिक': 'religious',
            'मानसिक': 'mental',
        },
    },
    'प्राथमिक स्तर पर गणित का क्या महत्व है?': {
        "en_stem": 'What is the importance of mathematics at the primary level?',
        "options": {
            'सांस्कृतिक': 'cultural',
            'सामाजिक': 'social',
            'धार्मिक': 'religious',
            'मानसिक': 'mental',
        },
    },
    'प्राथमिक स्तर पर गणित का महत्व है :': {
        "en_stem": 'Importance of math at primary level is:',
        "options": {
            'सांस्कृतिक': 'cultural',
            'सामाजिक': 'social',
            'धार्मिक': 'religious',
            'मानसिक': 'mental',
        },
    },
    'प्ले-वे (play-way) विधि किस आयु के लिए सबसे उपयुक्त है ?': {
        "en_stem": 'Play-way method is most suitable for which age?',
        "options": {
            'वयस्क': 'adult',
            'किशोर': 'adolescent',
            'बाल्यावस्था': 'childhood',
            'वृद्धावस्था': 'old age',
        },
    },
    'फ्रोबेल (froebel) ने किस शिक्षा पद्धति का विकास किया ?': {
        "en_stem": 'Froebel developed which teaching method?',
        "options": {
            'मोंटेसरी पद्धति': 'montessori method',
            'किंडरगार्टन पद्धति': 'kindergarten method',
            'प्रोजेक्ट पद्धति': 'project method',
            'प्ले-वे पद्धति': 'play-way method',
        },
    },
    'भारत का प्रथम राष्ट्रीय उद्यान (1936) था :': {
        "en_stem": "India's first national park (1936) was:",
        "options": {
            'कान्हा राष्ट्रीय उद्यान': 'Kanha National Park',
            'भरतपुर राष्ट्रीय उद्यान': 'Bharatpur National Park',
            'हैली (कॉर्बेट) राष्ट्रीय उद्यान': 'Hailley (Corbett) National Park',
            'राजाजी राष्ट्रीय उद्यान': 'Rajaji National Park',
        },
    },
    'भारत में सबसे अधिक वन क्षेत्र किस प्रकार का है ?': {
        "en_stem": 'Which type of forest covers the largest area in India?',
        "options": {
            'उष्णकटिबंधीय नम पर्णपाती': 'tropical moist deciduous forests',
            'उष्णकटिबंधीय सूखा पर्णपाती': 'tropical dry deciduous forests',
            'शीतोष्ण मिश्रित': 'temperate mixed forests',
            'अल्पाइन': 'alpine forests',
        },
    },
    'मोंटेसरी (montessori) शिक्षा का मुख्य तत्व है :': {
        "en_stem": 'The main element of Montessori education is:',
        "options": {
            'इन्द्रिय-प्रशिक्षण (sensory training)': 'sensory training',
            'रटना': 'rote learning',
            'परीक्षा': 'exam',
            'दण्ड': 'punishment',
        },
    },
    'यदि एक संख्या का 20% = 50 है, तो संख्या होगी :': {
        "en_stem": 'If 20% of a number is 50, the number is:',
        "options": {
            '200': '200',
            '250': '250',
            '300': '300',
            '350': '350',
        },
    },
    'यदि एक संख्या का 25% = 75 है, तो संख्या होगी :': {
        "en_stem": 'If 25% of a number is 75, the number will be:',
        "options": {
            '200': '200',
            '250': '250',
            '300': '300',
            '350': '350',
        },
    },
    'यदि किसी वस्तु का मूल्य ₹500 है और उस पर 10% छूट मिलती है, तो बिक्री मूल्य होगा :': {
        "en_stem": 'If an article costs Rs 500 and a 10% discount is offered, the selling price is:',
        "options": {
            '₹400': '₹400',
            '₹425': '₹425',
            '₹450': '₹450',
            '₹475': '₹475',
        },
    },
    'योगात्मक मूल्यांकन (summative assessment) का उद्देश्य है :': {
        "en_stem": 'The purpose of Summative Assessment is:',
        "options": {
            'सुधार हेतु': 'for improvement',
            'ग्रेड/पदोन्नति हेतु': 'for grades/promotion',
            'त्रुटियाँ पहचानना': 'to identify errors',
            'अधिगम की कमियाँ पहचानना': 'to identify learning gaps',
        },
    },
    'रचनात्मक मूल्यांकन (formative assessment) का उद्देश्य है :': {
        "en_stem": 'The purpose of Formative Assessment is:',
        "options": {
            'ग्रेड देना': 'giving grades',
            'अधिगम की कमियाँ पहचानना': 'identifying learning gaps',
            'पदोन्नति देना': 'giving promotion',
            'तुलना करना': 'comparison',
            'ग्रेड/पदोन्नति देना': 'giving grades/promotion',
            'त्रुटियाँ पहचानकर सुधार करना': 'identifying errors and correcting',
            'छात्रों की तुलना करना': 'comparing students',
            'अंतिम परीक्षा लेना': 'taking final exam',
        },
    },
    'रचनात्मक मूल्यांकन (formative assessment) गणित में क्या करता है ?': {
        "en_stem": 'Formative assessment in math does:',
        "options": {
            'ग्रेड/पदोन्नति देता है': 'gives grades/promotion',
            'अधिगम की कमियाँ पहचानता है': 'identifies learning gaps',
            'छात्रों की तुलना करता है': 'compares students',
            'अंतिम परीक्षा लेता है': 'takes final exam',
        },
    },
    'शिक्षण सहायक सामग्री (tlm) का उपयोग करते समय सबसे पहले ध्यान देना चाहिए :': {
        "en_stem": 'When using TLM, the first thing to consider is:',
        "options": {
            'आकर्षक हो': 'attractive',
            'चमकीला हो': 'bright',
            'विषय से संबंधित हो': 'related to the subject',
            'सस्ता हो': 'cheap',
        },
    },
    "समावेशी शिक्षा में 'बैरियर-फ्री' (barrier-free) का अर्थ है :": {
        "en_stem": "'Barrier-free' in inclusive education means:",
        "options": {
            'बिना बाधा का वातावरण': 'environment without barriers',
            'बाधाओं वाला वातावरण': 'environment with barriers',
            'केवल शारीरिक बाधाएँ': 'only physical barriers',
            'केवल मानसिक बाधाएँ': 'only mental barriers',
        },
    },
    'समावेशी शिक्षा में श्रवण-बाधित (hearing impaired) बच्चों के लिए उपयुक्त बैठक व्यवस्था है :': {
        "en_stem": 'Suitable seating arrangement for hearing impaired children in inclusive education is:',
        "options": {
            'अर्ध-वृत्ताकार (semi-circular)': 'semi-circular',
            'एकल पंक्ति': 'single row',
            'वृत्ताकार': 'circular',
            'चौकोर': 'square',
        },
    },
    "स्किनर (skinner) का 'shaping' का अर्थ है :": {
        "en_stem": "Skinner's 'Shaping' means:",
        "options": {
            'व्यवहार को एक बार में सिखाना': 'teaching behavior in one go',
            'व्यवहार को छोटे चरणों में सिखाना': 'teaching behavior in small steps',
            'व्यवहार को दण्ड देना': 'punishing behavior',
            'व्यवहार को नजरअंदाज करना': 'ignoring behavior',
        },
    },}


# ---------------------------------------------------------------------------
# 2. Answer keys
# ---------------------------------------------------------------------------
# Questions that are printed in two papers with two different keys and where
# neither the "official board paper wins" rule nor the majority rule gives the
# right answer.  The value is the correct answer index (0 = A).
ANSWER_KEY_OVERRIDES: dict[str, int] = {
    # --- mock paper vs. mock paper -----------------------------------------
    "c8fa2985fbd31ae2": 2,   # 'rabbit hole' -> "In a complex situation"
    "4677c1f6dafdc46f": 3,   # "by the next month, we shall have completed"
    "b7e6863404934c82": 3,   # "in the middle ages ... couldn't travel by plane"
    "884fcfd4007ed8a5": 2,   # "kate is ill, so she has to stay in bed"
    "1207756f5bdb7b86": 0,   # "the maid servant left the police station contrite"
    "79525239b0e74b15": 0,   # 216 m3 cuboid -> 10^6 cubes
    "c9674d1aed7d6eb9": 2,   # "priyanka has solved the issue" -> active voice
    # --- UTET 2021 Paper-II (Set-D) vs. UTET 2020 Paper-II (Set-E) --------
    "eea1b40da8973185": 3,   # memory level: perception, retention, recall, recognition
    "85714622f3f1d431": 1,   # "wholesome food for the body ... mind"
    "3e52e08d21ac8c87": 2,   # grammar-cum-translation -> second language
    "748a47619db20816": 2,   # "new method of teaching english" -> Dr. West
    "689036e1e6f39953": 2,   # learnt without practice -> acquisition
    "58587ba79eb7a4c9": 0,   # disorder of language comprehension -> aphasia
    "eac94e4a261a1d25": 2,   # "nature is seldom lavish with her intellectual gifts"
}


# ---------------------------------------------------------------------------
# 3. Questions whose stimulus does not exist in the vault
# ---------------------------------------------------------------------------
# The reading / figure these questions refer to is not part of the vault, so
# they are replaced by a self-contained question of the same section.
ORPHAN_QUESTION_IDS: set[str] = {
    # "The above passage is about ..."  - no passage in the paper
    "037c687ae58da96f",
    # pie-chart questions - the chart was never imported
    "4ce61d795fb64212",
    "0a5cb086b104a22f",
    # a poem the classroom task refers to
    "ctet-p1-2020-pyq_q149",
    # Tagore's "Where the Mind is Without Fear" - the poem is not in the vault
    "669de32792629ccf",
    "456934d30d7be685",
    "335655c1b900ab34",
    "4e2d066f497a434d",
    "92d9ced4d398a68b",
    "8fd54200e0447832",
}

# The stem each orphan question had before it was repaired.  The repair only
# touches a question while it still carries this stem, which keeps the
# repair idempotent.
ORPHAN_ORIGINAL_STEMS: dict[str, str] = {
    "037c687ae58da96f": "The above passage is about ______ :",
    "0a5cb086b104a22f": (
        "दिया गया पाई-चार्ट किसी विद्यार्थी द्वारा विभिन्न विषयों में प्राप्त अंकों को दर्शाता है। "
        "यदि कुल अंक 648 हैं, तो अंग्रेज़ी, विज्ञान और सामाजिक विज्ञान में प्राप्त अंक हिंदी और "
        "गणित में प्राप्त अंकों से कितने अधिक हैं? "
        "[अंग्रेज़ी 55°, विज्ञान 80°, सामाजिक विज्ञान 60°, हिंदी 75°, गणित 90°]"
    ),
    "335655c1b900ab34": "What do yellow woods refer to?",
    "456934d30d7be685": "What does the poet's decision of taking less travelled road signify?",
    "4ce61d795fb64212": "उपर्युक्त पाई-चार्ट के अनुसार सब्जी और दाल के उत्पादन का अनुपात है —",
    "4e2d066f497a434d": "The word 'trodden' means",
    "669de32792629ccf": "State the cause of regret in the poet in the beginning of the poem:",
    "8fd54200e0447832": "Why did the poet want to take the less travelled road?",
    "92d9ced4d398a68b": "Why did the poet want to take the less travelled road?",
    "ctet-p1-2020-pyq_q149": (
        "In a language classroom a teacher is asking students to interact in groups and then "
        "share their personal response to the poem with each other. This task promotes social "
        "interaction as advocated by [ ________ ]"
    ),
}


# ---------------------------------------------------------------------------
# 4. Small option level corrections
# ---------------------------------------------------------------------------
# question id -> {index: new option text}
OPTION_TEXT_FIXES: dict[str, dict[int, str]] = {
    # The English option list of this question was shifted by one and ended
    # with a stray "*"; the Hindi list keeps the plain fourth part.
    "84e490f73270ed9c": {3: "No error"},
}


# ---------------------------------------------------------------------------
# 5. English text that the broken import stole from a neighbouring question
# ---------------------------------------------------------------------------
# The source dump of the mock papers carried a *shifted English column*: a
# question kept the English stem or the English option list of the question
# that follows it.  The Hindi side of those questions is correct, so the
# English side can be restored from the one clean copy of the same question
# (or written down when the question only exists once).
#
# ``ENGLISH_STEM_FIXES``
#     question id -> the English stem that belongs to the question.
#
# ``ENGLISH_OPTION_COPIES``
#     question id -> id of the question whose English option list is the
#     correct translation of the question's own Hindi option list.
#
# ``ENGLISH_OPTION_FIXES``
#     question id -> the English option list that belongs to the question.
#
# ``ANSWER_INDEX_FIXES``
#     question id -> the correct answer index.

ENGLISH_STEM_FIXES: dict[str, str] = {
    # --- a stem that belongs to a completely different question ------------
    "978ef8d5b300fc58": "When did Project Red Panda start?",
    "efd8fc1425a456ea": (
        "If an article costs Rs 500 and a 10% discount is offered, "
        "the selling price is:"
    ),
    "b6692a656a1cf07d": "The formula for Simple Interest (SI) is:",
    "8807c02727cb924c": "What is 15% of 50?",
    "c2ffcc0e74a1ccad": (
        "The best example of learner-centred teaching in EVS is:"
    ),
    "0c77ebf98c33182e": (
        "An example of interaction between biotic and abiotic components is:"
    ),
    "4991d5c06e1fca19": (
        "The product of a rational and an irrational number is:"
    ),
    "810169ceafab300f": "When is World Water Day celebrated?",
    "e24369f5d1bb0ad7": "India's first national park (1936) was:",
    "75873093e9a96685": (
        "If sum and product of two numbers are 25 and 144 respectively, "
        "their difference will be:"
    ),
    "6a1076b107fdac05": "Which type of forest covers the largest area in India?",
    "9786205656f79ab7": (
        "When the graph of a linear equation in two variables is drawn, it is:"
    ),
    "5643f946ff0c0cf0": "If 20% of a number is 50, the number is:",
    "6d19af1ee1f57893": (
        "Simple interest on Rs 1000 at 10% annual rate for 2 years will be:"
    ),
    "dac6988f3a874bd6": "The flow of energy in an ecosystem is:",
    # --- a stem that belongs to a question of the same mock paper ----------
    "740d9817c4fe7c43": (
        "What should a teacher do for a poor child in inclusive education?"
    ),
    "652b8fdbd555559c": (
        "What should a teacher do for a poor child in inclusive education?"
    ),
    "060db07ea79429c1": (
        "What should a teacher do for a poor child in inclusive education?"
    ),
    "9c57db495f4b2d32": (
        "What should a teacher do for a poor child in inclusive education?"
    ),
    "f75756b067aab563": (
        "What should a teacher do for a poor child in inclusive education?"
    ),
    "a8e038635057acbc": (
        "What should a teacher do for a poor child in inclusive education?"
    ),
    "e3b7dd2d530ca5c4": (
        "What should a teacher do for a poor child in inclusive education?"
    ),
    "2a8e1b2f166fee05": (
        "What should a teacher do for a poor child in inclusive education?"
    ),
    "709f3db99a844498": "The three stages of teaching are:",
    "e47ec81e04cba0cf": "The three stages of teaching are:",
    "86f4e59bca3fe6ec": "The three stages of teaching are:",
    "4686807ecdfad9bb": "The three stages of teaching are:",
    "639f1a3a30b77ca5": "The three stages of teaching are:",
    "8b7e41d9311687bb": "The three stages of teaching are:",
    "044fc86d56ffdff8": "The formula for IQ is:",
    "4b533d060cf9c6ed": "The formula for IQ is:",
    "ad8f6ef76344f3c0": "The formula for IQ is:",
    "c67779ede0e84434": "The formula for IQ is:",
    "798752ae296c3020": "The formula for IQ is:",
    "9e8e136a82b281f9": "The formula for IQ is:",
}

# The English option list of these questions belongs to the question that
# follows them in the mock papers; the clean copy of the same question is
# named here so that the repair stays data driven.
ENGLISH_OPTION_COPIES: dict[str, str] = {
    '01cb4e6532730aa2': '221a5868d0ee1cd6',
    '03f005e351141275': '48d7c2540f9b7395',
    '0bbec10f89ada773': '42d2d85761b1c8d0',
    '0d4d1021d7840d9b': '48d7c2540f9b7395',
    '1497e36df76ac60a': '45fb8522776abeff',
    '16218167d67340e2': '443135edf61e0412',
    '18c14735ab4dd406': '2c5c2519b75e5491',
    '2ddcf938ddceb2cf': '88d829b0642f9760',
    '3343f72c713032ee': '221a5868d0ee1cd6',
    '396b4d0fc5eb8f96': '2c5c2519b75e5491',
    '421236edc67cef89': '45fb8522776abeff',
    '43c80abf8ff7f1cf': '221a5868d0ee1cd6',
    '47c01597e674961f': '27373632c543ffe7',
    '4896ff245de51345': '0fa6f868f60ddbdd',
    '4be2a834a1249f9a': '42d2d85761b1c8d0',
    '4f020b409bf3101f': '27373632c543ffe7',
    '544a7d16e5965fcc': 'cc00840c7ff49ec7',
    '594e7e3a7b22fb7c': '45fb8522776abeff',
    '64f1db134519f71d': '443135edf61e0412',
    '6a6269fa16ede08f': '0fa6f868f60ddbdd',
    '6b22232cfc758cd5': '443135edf61e0412',
    '730778c71d9cf9e5': '42d2d85761b1c8d0',
    '77aed5ba0c9ba51f': '88d829b0642f9760',
    '7838fc2001bf47e2': '2c5c2519b75e5491',
    '7c6ec9dc84736c4b': 'cc00840c7ff49ec7',
    '7cf3e5ee8563efc3': '42d2d85761b1c8d0',
    '811b9d2ac15b96e5': '88d829b0642f9760',
    '838282fa7c5affd9': '88d829b0642f9760',
    '85b1eb31e090d842': '27373632c543ffe7',
    '8d87db049f5d77f0': '88d829b0642f9760',
    '8ef2b9dee9065f2e': '48d7c2540f9b7395',
    '9361c88b61110d28': 'cc00840c7ff49ec7',
    '9416356a2bed8f25': '48d7c2540f9b7395',
    '9e7b749556ee954c': '443135edf61e0412',
    'a351015c3c793a90': '221a5868d0ee1cd6',
    'a4830457d8d2ac2f': '45fb8522776abeff',
    'a5137c5d7d4ffa19': '2c5c2519b75e5491',
    'a5ce9722bbb18f8d': '2c5c2519b75e5491',
    'aa3b44953bdd7c2d': '0fa6f868f60ddbdd',
    'b15d92133a1a5593': '88d829b0642f9760',
    'b164bcf44bff472c': '27373632c543ffe7',
    'b71084ca08bbc342': '27373632c543ffe7',
    'bafc4dfe943bd684': '2c5c2519b75e5491',
    'bc4da80f9cc3fcd2': '42d2d85761b1c8d0',
    'c42e9875ef21074f': '27373632c543ffe7',
    'c9274700cc91104a': '45fb8522776abeff',
    'cb38ba8a998dbb28': '0fa6f868f60ddbdd',
    'cd302aa8f9b1e3c2': '221a5868d0ee1cd6',
    'd17873a6868efe61': '443135edf61e0412',
    'd54542cf911825bc': '221a5868d0ee1cd6',
    'd946436e7743c8d9': '443135edf61e0412',
    'dac5c6fcdc9f87cf': 'cc00840c7ff49ec7',
    'ddb4b2d58684f754': '48d7c2540f9b7395',
    'e65f2ff1faeeb820': 'cc00840c7ff49ec7',
    'e8b88bda4765ec2e': '0fa6f868f60ddbdd',
    'e8c192278a198a5d': '42d2d85761b1c8d0',
    'ea92e16fab3c2286': 'cc00840c7ff49ec7',
    'ed1c60ad99531005': '48d7c2540f9b7395',
    '709f3db99a844498': '04f8177650146d9b',
    'e47ec81e04cba0cf': '04f8177650146d9b',
    '86f4e59bca3fe6ec': '04f8177650146d9b',
    '4686807ecdfad9bb': '04f8177650146d9b',
    '639f1a3a30b77ca5': '04f8177650146d9b',
    '8b7e41d9311687bb': '04f8177650146d9b',
    'f0cd74cc508ab641': '45fb8522776abeff',
    'f29944afeedff93a': '0fa6f868f60ddbdd',
}

# The English option list of these questions belongs to another question
# (or to no question at all), so it is written down instead of copied.
ENGLISH_OPTION_FIXES: dict[str, list[str]] = {
    "b6692a656a1cf07d": [
        "P \u00d7 R \u00d7 T",
        "(P \u00d7 R \u00d7 T) / 100",
        "P \u00d7 R / T",
        "P + R + T",
    ],
    "c2ffcc0e74a1ccad": [
        "Audio tape",
        "Question-answer method",
        "Nature trip and observation",
        "Only reading from the textbook",
    ],
    # The English option list of this question was shifted by two positions:
    # the Hindi list and the printed key agree (the second option is the
    # "sudden destructive event"), the English list did not.  The list is
    # put back into the order of the Hindi options.
    "5fcb80a037445cc2": [
        "Happy event",
        "Sudden destructive event",
        "Routine event",
        "Normal event",
    ],
    "ad1b9f84528e7e85": [
        "Happy event",
        "Sudden destructive event",
        "Routine event",
        "Normal event",
    ],
    "2e6e482dbb8d90b1": [
        "Happy event",
        "Sudden destructive event",
        "Routine event",
        "Normal event",
    ],
    "3e8be78e13f41433": [
        "Happy event",
        "Sudden destructive event",
        "Routine event",
        "Normal event",
    ],
    "b6a010b4c80f1a3f": [
        "Happy event",
        "Sudden destructive event",
        "Routine event",
        "Normal event",
    ],
    "3804130dd69da71e": [
        "Happy event",
        "Sudden destructive event",
        "Routine event",
        "Normal event",
    ],
    "d07d1183e893325e": [
        "Happy event",
        "Sudden destructive event",
        "Routine event",
        "Normal event",
    ],
    "80d5acc412c057df": [
        "Happy event",
        "Sudden destructive event",
        "Routine event",
        "Normal event",
    ],
}

# The answer index of the question was wrong: the printed key pointed at the
# first option ("granting grades / promotion") instead of the second one
# ("identifying errors and improving them"), which is what formative
# assessment actually does.
ANSWER_INDEX_FIXES: dict[str, int] = {
    "3c07b7bfd5bf7dcf": 1,
}

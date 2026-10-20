# -*- coding: utf-8 -*-
"""Restore English options for a set of questions whose English options were
misaligned or lost their leading value during the original import.

Only the English option array is touched; the Hindi text and answer index are
left as they are.  Each entry is keyed by a distinctive fragment of the Hindi
stem so the repair is auditable and repeatable.
"""

import argparse
import json
import os
import shutil
import sqlite3
import sys

sys.stdout.reconfigure(encoding='utf-8')

DB = os.path.join(os.path.dirname(__file__), '..', 'assets', 'database', 'tet_mock_vault.db')
BACKUP = os.path.join(os.path.dirname(__file__), '..', 'scratch', 'tet_mock_vault_pre_en_options.db')

# (Hindi stem fragment, correct English options)
GROUPS = [
    (
        'IQ) का सूत्र है',
        ['(MA/CA) × 100', '(CA/MA) × 100', 'MA × CA', 'MA + CA'],
    ),
    (
        '50 का 15% कितना है',
        ['5.5', '6.5', '7.5', '8.5'],
    ),
    (
        '₹1000 पर 10% वार्षिक दर',
        ['₹100', '₹150', '₹200', '₹250'],
    ),
    (
        'औसत चाल (Average speed) का सूत्र',
        ['(x + y) / 2', '2xy / (x + y)', 'xy / (x + y)', '(x − y) / 2'],
    ),
    (
        'यदि दो संख्याओं का योग 25 और गुणनफल 144',
        ['5', '6', '7', '8'],
    ),
    (
        'एक ट्रेन 60 km/h की चाल से चल रही है',
        ['10 sec', '12 sec', '15 sec', '20 sec'],
    ),
    (
        '6 से 8 वय वर्ग के बच्चों के विकासात्मक कार्य',
        ['only 1', '1 and 2', '2 and 3', 'only 3'],
    ),
    (
        'संवेगात्मक बुद्धि की विशेषताएँ',
        ['1 and 2', '1, 2, 3', '2 and 3', '1 and 3'],
    ),
    (
        'गगाला तने से प्राप्त',
        ['1 and 4', '2 and 3', 'only 3', '2 and 4'],
    ),
    (
        'खरीफ की फसलें हैं',
        ['1 and 3', '1, 3 and 4', '2 and 4', '2, 3 and 4'],
    ),
    (
        'शिक्षण के सूत्र कौन से हैं',
        ['(1), (2) and (3)', '(1), (2) and (4)', '(2), (3) and (4)', 'All the above'],
    ),
    (
        'विश्व जल दिवस (World Water Day)',
        ['22 January', '22 March', '22 April', '22 May'],
    ),
    (
        'पृथ्वी दिवस (Earth Day)',
        ['22 January', '22 March', '22 April', '22 May'],
    ),
    (
        'पानी में फ्लोराइड (Fluoride) की अधिकतम सीमा',
        ['0.5 mg/L', '1.0 mg/L', '1.5 mg/L', '2.0 mg/L'],
    ),
    (
        'गंगा कार्य योजना (Ganga Action Plan)',
        ['1980', '1985/86', '1990', '1995'],
    ),
    (
        'कार्बन क्रेडिट (Carbon Credit)',
        ['Montreal Protocol', 'Kyoto Protocol', 'Rio Summit', 'G-8 Summit'],
    ),
    (
        'Project Red Panda कब शुरू',
        ['1984', '1986', '1994', '1996'],
    ),
    (
        'एक पंचभुज के विकर्णों की संख्या',
        ['4:5', '1:2', '5 : 12', '5 : 6'],
    ),
    (
        'कॉलम A का मिलान कॉलम B से कीजिए — कॉलम (A) (विद्यालय का वातावरण)',
        ['1 2 3 4', '2 1 3 4', '2 3 1 4', '1 2 4 3'],
    ),
    (
        'सूची-I को सूची-II से सुमेलित कीजिए और सही उत्तर चुनिए। सूची-I: (a) अनाईमुडी',
        ['1 2 4 3', '2 1 4 3', '4 1 3 2', '2 4 3 1'],
    ),
    (
        'सूची-I को सूची-II से सुमेलित कीजिए। सूची-I (उद्योग)',
        ['4 3 2 1', '1 2 3 4', '1 2 4 3', '3 2 4 1'],
    ),
    (
        'पानी के दो शुद्धतम रूप',
        ['1 and 2', '2 and 4', '1 and 3', '3 and 4'],
    ),
    (
        'सूची-A को सूची-B के साथ सुमेलित कीजिये और सूचियों में दिये गये कूट',
        ['3 2 1 4', '3 1 2 4', '4 1 2 3', '4 2 1 3'],
    ),
    (
        'Teaching aids such as Charts',
        ['Only (1)', '(1) and (2)', '(1) and (3)', 'All of these'],
    ),
    (
        'सूची A को सूची B के साथ सुमेलित कीजिये — झूम कृषि',
        ['2 4 1 3', '2 4 3 1', '4 1 2 3', '4 2 1 3'],
    ),
    (
        'अल्पकालिक स्मृति के संदर्भ',
        ['Only 1', '1 and 2', '1, 2 and 3', '1 and 3'],
    ),
    (
        'सकारात्मक संवेगों को बढ़ाने के तरीके',
        ['(1), (2), (3)', '(2) and (3)', '(1) and (2)', 'Only (2)'],
    ),
    (
        'गंगा नदी की निम्न सहायक नदियों',
        ['1 2 3 4', '4 3 2 1', '3 2 1 4', '3 2 4 1'],
    ),
    (
        'कक्षा 1 में पर्यावरण अध्ययन',
        ['1, 2 and 3', 'Only 4', '1 and 2', '2 and 4'],
    ),
    (
        'पर्यावरण अध्ययन में, बच्चे शिल्पकला',
        ['1 and 4', '1, 2 and 4', '1, 2 and 3', '1 and 3'],
    ),
    (
        'प्राथमिक कक्षाओं में शिक्षार्थियों के पास अनेक प्रकरणों',
        ['1, 2 and 4', '1, 2, 3 and 4', 'Only 1', '1 and 2'],
    ),
    (
        'पर्यावरण अध्ययन पाठ्य-पुस्तक की विषय-वस्तु',
        ['1 and 4', '2 and 3', 'Only 3', '1, 2 and 3'],
    ),
    (
        '12, 18 एवं 24 का म.स.प.',
        ['6 and 36', '12 and 36', '12 and 144', '6 and 72'],
    ),
    (
        'बहुपद x^2 - 9 के शून्यक',
        ['only 3', '3 and -3', '9 and -9', '0 and 9'],
    ),
    (
        'यदि y = 2x + 1 एवं 3x + y = 11',
        ['1 and 9', '2 and 7', '2 and 5', '3 and 3'],
    ),
    (
        "भारत के सर्वोच्च न्यायालय ने 'संविधान के आधारभूत ढांचे'",
        ['The Golaknath Case in 1967', 'The Kesavananda Bharati Case in 1973',
         'The Shankari Prasad Case in 1951', 'The Sajjan Singh Case in 1965'],
    ),
    (
        'भारत के संविधान में वन्यजीव संरक्षण',
        ['1 and 2', '2 and 3', '1 and 3', '1, 2 and 3'],
    ),
    (
        'भारत के संविधान में वन्य जीवन का संरक्षण',
        ['1 and 2', '2 and 3', '1 and 3', '1, 2 and 3'],
    ),
    (
        'मृदा के संबंध में निम्न कथनों',
        ['1 and 2 are correct', '2 and 3 are correct',
         '1 and 3 are correct', '1, 2 and 3 are correct'],
    ),
    (
        "संधि विच्छेद: 'विद्यालय'",
        ['Vidya + Aalaya', 'Vidya + Laya', 'Vid + Yalaya', 'Vidy + Aalaya'],
    ),
    (
        'प्राथमिक स्तर पर पर्यावरण अध्ययन की क्या सार्थकता',
        ['(A) and (D)', '(A), (C) and (D)', '(A), (B) and (C)', '(B), (C) and (D)'],
    ),
    (
        'एनसीईआरटी के पर्यावरण अध्ययन के पाठ्यपुस्तक',
        ['(B), (C) and (D)', '(A), (C) and (D)',
         '(A), (B) and (C)', '(A), (B) and (D)'],
    ),
    (
        'निम्नलिखित में से क्या पर्यावरण अध्ययन के संदर्भ में सही है? (A) पर्यावरण अध्ययन का पाठ्यक्रम शीर्षक आधारित',
        ['(B), (C) and (D)', '(A), (B) and (C)',
         '(A), (C) and (D)', '(A), (B) and (D)'],
    ),
    (
        'आरंभिक संख्या अवधारणा के बनने',
        ['Only (A)', '(A) and (C)', '(A) and (B)', '(B) and (C)'],
    ),
    (
        'संज्ञानात्मक संघर्ष के विचार',
        ['(B) and (C)', '(A) and (C)', 'Only (A)', 'Only (C)'],
    ),
    (
        'वहीदा का प्रिज्म',
        ['(A), (B) and (C)', '(B), (C) and (D)',
         '(A), (C) and (D)', '(A), (B) and (D)'],
    ),
    (
        'बाल-केन्द्रित रणनीतियों',
        ['(A) and (B)', '(B) and (C)', '(C) and (D)', '(A) and (D)'],
    ),
    (
        'सीमा, एक ईवीएस शिक्षिका',
        ['(A), (B) and (C)', '(B), (C) and (D)',
         '(A), (C) and (D)', '(A) and (B)'],
    ),
]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--db', default=DB)
    args = parser.parse_args()

    db = os.path.abspath(args.db)
    if args.apply and not os.path.exists(BACKUP):
        shutil.copy2(db, BACKUP)
        print('backup ->', os.path.abspath(BACKUP))

    con = sqlite3.connect(db)
    cur = con.cursor()
    total = 0
    missing = []
    for fragment, en in GROUPS:
        rows = cur.execute(
            'SELECT id FROM questions WHERE q_hindi LIKE ?',
            ('%' + fragment + '%',),
        ).fetchall()
        if not rows:
            missing.append(fragment)
            continue
        print(f'{len(rows):2d}  {fragment[:72]}')
        total += len(rows)
        if args.apply:
            cur.execute(
                'UPDATE questions SET options_english=? WHERE q_hindi LIKE ?',
                (json.dumps(en, ensure_ascii=False), '%' + fragment + '%'),
            )
    if args.apply:
        con.commit()
        print('updated questions:', total)
    else:
        print('DRY RUN: would update', total, 'questions (use --apply)')
    if missing:
        print('\nNO MATCH:')
        for fragment in missing:
            print(' ', fragment)
    con.close()


if __name__ == '__main__':
    main()

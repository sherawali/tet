# -*- coding: utf-8 -*-
"""Repair options that lost leading values/signs during an earlier import.

The old importer stripped a single leading digit followed by a space, so
options such as ``2 घण्टे`` became ``घण्टे`` and ``-12`` became ``12``.
This script restores the original options from the source corpus for every
affected question.  It is intentionally conservative: each entry matches one
distinct question stem and carries all four options plus the answer index.

Usage:
    python bin/repair_option_text_v17.py             # dry run
    python bin/repair_option_text_v17.py --apply     # write + backup
"""

import argparse
import json
import os
import shutil
import sqlite3
import sys
from datetime import datetime

sys.stdout.reconfigure(encoding='utf-8')

DB = os.path.join(os.path.dirname(__file__), '..', 'assets', 'database', 'tet_mock_vault.db')
BACKUP = os.path.join(os.path.dirname(__file__), '..', 'scratch', 'tet_mock_vault_pre_options.db')

# (stem fragment, Hindi options, English options, correct index)
GROUPS = [
    (
        'अपनी चाल को कम करके 2/3',
        ['2 घण्टे', '2.5 घण्टे', '3 घण्टे', '1.5 घण्टे'],
        ['2 hours', '2.5 hours', '3 hours', '1.5 hours'],
        0,
    ),
    (
        'कितने घण्टों में सेकेण्डों की संख्या, 10 दिनों',
        ['2 घण्टे', '3 घण्टे', '4 घण्टे', '5 घण्टे'],
        ['2 hours', '3 hours', '4 hours', '5 hours'],
        2,
    ),
    (
        'एक वर्ग की भुजा 4 सेमी है',
        ['4 सेमी²', '1 सेमी²', '16 सेमी²', '8 सेमी²'],
        ['4 cm²', '1 cm²', '16 cm²', '8 cm²'],
        0,
    ),
    (
        'यदि वृत्त की परिधि तथा क्षेत्रफल का आंकिक मान बराबर',
        ['1 इकाई', '2 इकाई', '4 इकाई', 'π इकाई'],
        ['1 unit', '2 units', '4 units', 'π units'],
        2,
    ),
    (
        'वस्तु स्थायित्व (Object Permanence)',
        ['जन्म से', '8-12 महीने', '2 वर्ष', '5 वर्ष'],
        ['From birth', '8-12 months', '2 years', '5 years'],
        1,
    ),
    (
        'सं.रा. अमेरिका और जापान से आने वाले पर्यटकों',
        ['2 लाख', '3 लाख', '4 लाख', '10 लाख'],
        ['2 lakh', '3 lakh', '4 lakh', '10 lakh'],
        0,
    ),
    (
        'एक घण्टे का y%',
        ['1 मिनट', '2 मिनट', '1/2 मिनट', '1/4 मिनट'],
        ['1 minute', '2 minutes', '1/2 minute', '1/4 minute'],
        1,
    ),
    (
        'समतल दर्पण में देख रहे हैं',
        ['2 मीटर', '3 मीटर', '5 मीटर', '6 मीटर'],
        ['2 metres', '3 metres', '5 metres', '6 metres'],
        3,
    ),
    (
        'v – t ग्राफ द्वारा घेरा गया',
        ['मीटर', 'मीटर²', 'मीटर/सेकण्ड', 'मीटर/सेकण्ड²'],
        ['metre', 'metre²', 'metre/second', 'metre/second²'],
        0,
    ),
    (
        'सांवेगिक बुद्धि अनेक कौशलों का एक समुच्चय',
        ['1 & 2', '1 & 3', '1, 2 & 3', '2 & 3'],
        ['1 & 2', '1 & 3', '1, 2 & 3', '2 & 3'],
        2,
    ),
    (
        'ब्लू प्रिंट एक त्रिआयामी चार्ट है जिसमें अधिभार दिया जाता है: '
        '(1) आकलन के उद्देश्यों को (2) विषय क्षेत्रों को (3) प्रश्नों के प्रकार को',
        ['1 व 2', '1 व 3', '2 व 3', '1, 2 व 3'],
        ['1 and 2', '1 and 3', '2 and 3', '1, 2 and 3'],
        3,
    ),
    (
        '(2⁻¹+4⁻¹+6⁻¹+8⁻¹)x',
        ['-1', '24/25', '1', '2'],
        ['-1', '24/25', '1', '2'],
        1,
    ),
    (
        'शुद्ध बर्फ का गलनांक',
        ['273 K', '0 K', '-273 K', '300 K'],
        ['273 K', '0 K', '-273 K', '300 K'],
        0,
    ),
    (
        '(2ⁿ+2ⁿ)/(2ⁿ⁻²)',
        ['1', '2', '4', '8'],
        ['1', '2', '4', '8'],
        3,
    ),
    (
        'सूची-I को सूची-II से सुमेलित कीजिए: सूची-I: (a) प्राकृतिक संसाधन',
        ['(iv)(i)(ii)(iii)', '(i)(ii)(iv)(iii)', '(i)(ii)(iii)(iv)', '(iv)(iii)(ii)(i)'],
        ['(iv)(i)(ii)(iii)', '(i)(ii)(iv)(iii)', '(i)(ii)(iii)(iv)', '(iv)(iii)(ii)(i)'],
        2,
    ),
    (
        'एक त्रिभुजाकार पिरामिड् में',
        ['3 फलक और 6 किनारे होते हैं।', '3 फलक और 4 किनारे होते हैं।',
         '4 फलक और 4 किनारे होते हैं।', '4 फलक और 6 किनारे होते हैं।'],
        ['3 faces and 6 edges.', '3 faces and 4 edges.',
         '4 faces and 4 edges.', '4 faces and 6 edges.'],
        3,
    ),
    (
        'एक वर्ग के परिमाप और क्षेत्रफल के संख्यात्मक मान समान',
        ['4 इकाई', '8 इकाई', '1 इकाई', '2 इकाई'],
        ['4 units', '8 units', '1 unit', '2 units'],
        0,
    ),
    (
        'एक वर्ग की भुजा 5cm है',
        ['4 गुना', '8 गुना', '2 गुना', '3 गुना'],
        ['4 times', '8 times', '2 times', '3 times'],
        0,
    ),
    (
        'रूबीना ने कार से 16:50',
        ['3 घंटे 35 मिनट', '4 घंटे 35 मिनट', '3 घंटे 25 मिनट', '4 घंटे 25 मिनट'],
        ['3 hours 35 minutes', '4 hours 35 minutes',
         '3 hours 25 minutes', '4 hours 25 minutes'],
        3,
    ),
    (
        'एक मिनी बस में अधिकतम 15 विद्यार्थी',
        ['2 मिनी बस और 2 बड़ी बस', '1 मिनी बस और 2 बड़ी बस',
         '3 मिनी बस और 1 बड़ी बस', '4 मिनी बस और 1 बड़ी बस'],
        ['2 mini buses and 2 big buses', '1 mini bus and 2 big buses',
         '3 mini buses and 1 big bus', '4 mini buses and 1 big bus'],
        0,
    ),
    (
        'एक घन की भुजा 5 सेमी',
        ['2 गुना', '3 गुना', '4 गुना', '6 गुना'],
        ['2 times', '3 times', '4 times', '6 times'],
        2,
    ),
    (
        'एक वर्ग की भुजा 4 cm है। इसे काट कर',
        ['16 cm2', '8 cm2', '4 cm2', '1 cm2'],
        ['16 cm2', '8 cm2', '4 cm2', '1 cm2'],
        2,
    ),
    (
        'हरीश ने 18 : 40 बजे',
        ['3 घंटे 40 मिनट', '3 घंटे 80 मिनट', '4 घंटे 40 मिनट', '3 घंटे 20 मिनट'],
        ['3 hours 40 minutes', '3 hours 80 minutes',
         '4 hours 40 minutes', '3 hours 20 minutes'],
        0,
    ),
    (
        '2 मी 40 सेमी रिबन',
        ['1 मी 20 सेमी', '1 मी 40 सेमी', '2 मी', '1 मी'],
        ['1 m 20 cm', '1 m 40 cm', '2 m', '1 m'],
        0,
    ),
    (
        'फिल्म 5:45 PM से 7:30 PM',
        ['2 घं 15 मि', '2 घं 45 मि', '1 घं 30 मि', '1 घं 45 मि'],
        ['2 hr 15 min', '2 hr 45 min', '1 hr 30 min', '1 hr 45 min'],
        3,
    ),
    (
        '|-7| + |-3|',
        ['-10', '10', '4', '-4'],
        ['-10', '10', '4', '-4'],
        1,
    ),
    (
        '(−12) + (+7) − (−5)',
        ['-10', '-20', '0', '10'],
        ['-10', '-20', '0', '10'],
        2,
    ),
    (
        'एक कक्षा में 18 लड़कियाँ एवं 12 लड़के',
        ['2 : 3', '3 : 5', '2 : 5', '3 : 2'],
        ['2 : 3', '3 : 5', '2 : 5', '3 : 2'],
        2,
    ),
    (
        'द्विघात समीकरण x^2 - 7x + 12 = 0 के मूल',
        ['-3 एवं -4', '2 एवं 6', '3 एवं 4', '-2 एवं 6'],
        ['-3 and -4', '2 and 6', '3 and 4', '-2 and 6'],
        2,
    ),
    (
        'एक रेलगाड़ी 09:45 बजे चलती है',
        ['3 घंटे 25 मिनट', '4 घंटे 35 मिनट', '3 घंटे 35 मिनट', '4 घंटे 25 मिनट'],
        ['3 hours 25 minutes', '4 hours 35 minutes',
         '3 hours 35 minutes', '4 hours 25 minutes'],
        2,
    ),
    (
        'यदि a = 3 एवं b = −2',
        ['1', '25', '-25', '13'],
        ['1', '25', '-25', '13'],
        1,
    ),
    (
        'संख्या-रेखा पर, -2 से 5 इकाई बाईं ओर',
        ['-7', '3', '-3', '7'],
        ['-7', '3', '-3', '7'],
        0,
    ),
    (
        '₹500, 6% वार्षिक साधारण ब्याज',
        ['3 वर्ष', '4 वर्ष', '5 वर्ष', '6 वर्ष'],
        ['3 years', '4 years', '5 years', '6 years'],
        2,
    ),
    (
        'x^3 + 2x^2 - 5x + 4 को x - 1 से भाग',
        ['4', '0', '2', '-2'],
        ['4', '0', '2', '-2'],
        2,
    ),
    (
        'A कोई कार्य 12 दिन में तथा B 6 दिन में',
        ['3 दिन में', '9 दिन में', '4 दिन में', '18 दिन में'],
        ['3 days', '9 days', '4 days', '18 days'],
        2,
    ),
    (
        'एक नाव स्थिर जल में 12 किमी',
        ['5 घंटे', '4 घंटे', '6 घंटे', '3 घंटे'],
        ['5 hours', '4 hours', '6 hours', '3 hours'],
        0,
    ),
    (
        'समीकरण x² − 7x + 12 = 0 के मूलों का योग',
        ['12', '-7', '7', '5'],
        ['12', '-7', '7', '5'],
        2,
    ),
    (
        'उस त्रिभुज की अन्त:वृत्त की त्रिज्या',
        ['2 सेमी.', '3 सेमी.', '4 सेमी.', '1 सेमी.'],
        ['2 cm', '3 cm', '4 cm', '1 cm'],
        3,
    ),
    (
        '3 सेमी, 4 सेमी और 5 सेमी भुजाओं वाले',
        ['2 सेमी', '3 सेमी', '4 सेमी', '1 सेमी'],
        ['2 cm', '3 cm', '4 cm', '1 cm'],
        3,
    ),
    (
        'औपचारिक-संक्रियात्मक अवस्था सामान्यतः',
        ['18 वर्ष', '2 वर्ष', '7 वर्ष', '11-12 वर्ष'],
        ['18 years', '2 years', '7 years', '11-12 years'],
        3,
    ),
    (
        'एक टंकी में दो पाइप A तथा B',
        ['1 घंटा 12 मिनट', '2 घंटा 30 मिनट', '1 घंटा', '1 घंटा 21 मिनट'],
        ['1 hour 12 minutes', '2 hours 30 minutes', '1 hour', '1 hour 21 minutes'],
        0,
    ),
    (
        '15 दिनों में मिनटों की संख्या',
        ['6 घण्टे', '8 घण्टे', '4 घण्टे', '5 घण्टे'],
        ['6 hours', '8 hours', '4 hours', '5 hours'],
        0,
    ),
    (
        'दृष्टि बाधितों के लिए एकीकृत शिक्षा',
        ['सामाजिक एकीकरण', 'सामाजिक मान्यता', '(A) व (B) दोनों',
         'उपर्युक्त में से कोई नहीं'],
        ['Social integration', 'Social recognition', 'Both (A) and (B)',
         'None of the above'],
        2,
    ),
    (
        'उपर्युक्त पाई-चार्ट के अनुसार सब्जी और दाल',
        ['7 : 3', '3 : 4', '1 : 2', '2 : 1'],
        ['7 : 3', '3 : 4', '1 : 2', '2 : 1'],
        0,
    ),
    (
        'यदि x : y = 2 : 3 है, तो (3x + 2y)',
        ['4 : 11', '5 : 14', '11 : 4', '15 : 7'],
        ['4 : 11', '5 : 14', '11 : 4', '15 : 7'],
        0,
    ),
    (
        'यदि x : y = 2 : 3, तो 3x + 2y',
        ['4 : 11', '5 : 14', '11 : 4', '15 : 7'],
        ['4 : 11', '5 : 14', '11 : 4', '15 : 7'],
        0,
    ),
    (
        'यदि (3a + 5b) : (3a – 5b) = 5 : 1',
        ['3 : 2', '5 : 3', '2 : 1', '5 : 2'],
        ['3 : 2', '5 : 3', '2 : 1', '5 : 2'],
        3,
    ),
    (
        'कंपनी X का उत्पादन कंपनी Y के उत्पादन का 120%',
        ['4 : 3 : 5', '6 : 5 : 9', '10 : 9 : 12', '12 : 10 : 15'],
        ['4 : 3 : 5', '6 : 5 : 9', '10 : 9 : 12', '12 : 10 : 15'],
        3,
    ),
    (
        'कौन-सा अनुपात सबसे बड़ा है',
        ['2 : 5', '3 : 7', '4 : 9', '1 : 3'],
        ['2 : 5', '3 : 7', '4 : 9', '1 : 3'],
        2,
    ),
    (
        'दो त्रिभुज समरूप हैं और उनकी संगत भुजाओं',
        ['2 : 3', '8 : 27', '9 : 4', '4 : 9'],
        ['2 : 3', '8 : 27', '9 : 4', '4 : 9'],
        3,
    ),
    (
        '250 सेमी = ___ मी ___ सेमी',
        ['25 मी', '2 मी 5 सेमी', '250 मी', '2 मी 50 सेमी'],
        ['25 m', '2 m 5 cm', '250 m', '2 m 50 cm'],
        3,
    ),
    (
        'विद्यालय 8:00 AM से 1:30 PM',
        ['5 घं', '5 घं 30 मि', '6 घं', '4 घं 30 मि'],
        ['5 hrs', '5 hrs 30 min', '6 hrs', '4 hrs 30 min'],
        1,
    ),
    (
        'पालतू को स्वस्थ रखने हेतु',
        ['1 घंटे में नहाना', 'अतिरिक्त वस्त्र', 'दैनिक मिठाई',
         'उचित भोजन, स्वच्छ जल, स्थान एवं समय पर देखभाल/टीकाकरण'],
        ['bath every hour', 'extra clothes', 'sweets daily',
         'proper food, clean water, space and timely care/vaccination'],
        3,
    ),
    (
        'उस वस्तु का द्रव्यमान ज्ञात करिए जिसका घनत्व 12',
        ['15 ग्रा.', '24 ग्रा.', '36 ग्रा.', '4 ग्रा.'],
        ['15 g', '24 g', '36 g', '4 g'],
        2,
    ),
    (
        '110 मी लम्बी ट्रेन',
        ['11 सेकण्ड', '10 सेकण्ड', '9 सेकण्ड', '2 सेकण्ड'],
        ['11 seconds', '10 seconds', '9 seconds', '2 seconds'],
        0,
    ),
    (
        'त्रिभुज ABC में DE, BC के समांतर',
        ['5 cm', '8 cm', '3 cm', '6 cm'],
        ['5 cm', '8 cm', '3 cm', '6 cm'],
        3,
    ),
    (
        'टास्क अनेलिसिस क्या है',
        ['यह निर्णय लेना कि कौन सी विषयवस्त पढ़ानी है और कौन सी नहीं।',
         'जटिल कार्य को छोटे प्राप्त करने योग्य चरणों में बाँटना',
         '(A) व (B) दोनों', 'उपरोक्त में से कोई नहीं'],
        ['Deciding which content is to be taught and which is not.',
         'Breaking a complex task into small achievable steps',
         'Both (A) and (B)', 'None of the above'],
        1,
    ),
    (
        'यदि पाठय सामग्री अथवा सिखाए जाने वाली क्रिया',
        ['बच्चे सीखने में रूचि नहीं लेते है', 'उन्हें सीखने में कठिनाई होती है',
         '(A) व (B) दोनों', 'उपरोक्त में से कोई नहीं'],
        ['children do not take interest in learning',
         'they face difficulty in learning', 'both (A) and (B)',
         'none of the above'],
        2,
    ),
    (
        'निम्नलिखित में से बच्चों के सामाजिक विकास को प्रभावित करने वाला कारक',
        ['माता-पिता', 'विद्यालय', '(A) व (B) दोनों', 'गुणसूत्र'],
        ['Parents', 'School', 'Both (A) and (B)', 'Chromosomes'],
        2,
    ),
]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--db', default=DB)
    args = parser.parse_args()

    db = os.path.abspath(args.db)
    if args.apply:
        os.makedirs(os.path.dirname(BACKUP), exist_ok=True)
        if not os.path.exists(BACKUP):
            shutil.copy2(db, BACKUP)
            print('backup ->', os.path.abspath(BACKUP))

    con = sqlite3.connect(db)
    cur = con.cursor()
    total = 0
    missing = []
    for fragment, hi, en, ans in GROUPS:
        rows = cur.execute(
            'SELECT id FROM questions WHERE q_hindi LIKE ?',
            ('%' + fragment + '%',),
        ).fetchall()
        if not rows:
            missing.append(fragment)
            continue
        if len(hi) != 4 or len(en) != 4:
            raise SystemExit('invalid option count for: ' + fragment)
        print(f'{len(rows):2d}  {fragment[:70]}')
        total += len(rows)
        if args.apply:
            cur.execute(
                'UPDATE questions SET options_hindi=?, options_english=?, answer=? WHERE q_hindi LIKE ?',
                (json.dumps(hi, ensure_ascii=False),
                 json.dumps(en, ensure_ascii=False),
                 ans, '%' + fragment + '%'),
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

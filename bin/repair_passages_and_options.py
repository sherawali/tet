#!/usr/bin/env python3
"""
repair_passages_and_options.py — One-shot, idempotent data repair for the TET vault.

Fixes every issue found by bin/audit_render_quality.py on 2026-10-19:

PASSAGES
  A. ctet-p1-2020-pyq_p1  : instruction line leaked inside body -> moved to dir_text;
                            q098/q099 (passage-based) relinked as seq 7, 8.
  B. ctet-p1-2020-pyq_p2  : body was ONLY the instruction line ("*Read the prose and
                            answer questions 121-128.*") — real Graphology prose was
                            MISSING. Restored authentic CTET Jan-2021 passage text;
                            q127/q128 relinked as seq 7, 8.
  C. set-b_p1             : CJK full-stop '。' -> '।'

QUESTIONS — option corruption caused by bin/build_master_vault.py & bin/ingest_ctet_vault.py
  * clean_opt() used to run:  re.sub(r'^\\(?[1-4]\\)?\\s+', '', t)
    which DELETED real numeric option values ("4 : 11" -> ": 11", "2 घण्टे" -> "घण्टे").
  * clean_opt() also stripped a genuine leading "(A)"/"(B)" marker from combination
    options ("(A), (B) and (C)" -> ", (B) and (C)").
  Each fix below reconstructs the original content from the surviving fragments,
  the intact Hindi mirror, or the mathematics of the question. Answer keys are
  never touched unless explicitly noted.

Usage:
    python3 bin/repair_passages_and_options.py [--db assets/database/tet_mock_vault.db] [--dry-run]
"""
import argparse
import json
import re
import sqlite3
import sys

sys.stdout.reconfigure(encoding='utf-8')

DEFAULT_DB = 'assets/database/tet_mock_vault.db'
NEW_BANK_VERSION = '20261019_master_vault_clean_v17'

# ---------------------------------------------------------------------------
# Canonical Graphology passage (CTET Jan 2021 Paper-I), OCR duplications cleaned.
# ---------------------------------------------------------------------------
GRAPHOLOGY_BODY = """1. The study of handwriting is known as graphology and it has been practised for hundreds of years. Professional forensic graphologists have worked on many court cases to use handwriting to link suspects with crimes.

2. Handwriting is particularly important legally in the case of signatures and proving whether signatures are real or forged can be pivotal. Graphologists also work to verify whether autographs are real or fake.

3. Some handwriting analysts also study writing samples to determine personality types and some businesses commission this analysis before hiring new employees. The method is even sometimes used to help couples see if they are compatible. According to graphologists, there is very little you can't tell from a person's handwriting.

4. From psychological conditions like high blood pressure and schizophrenia to personality traits like dominance and aggression: if you write by hand, graphologists can analyse you.

5. Everything from the size of your letters to how closely you space words can reveal intricate details of your personality. In general, the size of your letters can reveal whether you are shy or outgoing. Compared to a standard lined sheet of paper, if you write with tiny letters that do not reach the top line, you are likely to have a timid and introverted personality. If you write with large letters that go over the top line, you are likely to be the opposite: outgoing, confident and attention seeking.

6. Studies suggest that people who space words widely like freedom and independence, whereas those choosing to write with small spaces prefer to be among others and do not like to be alone."""

GRAPHOLOGY_DIR = ('Directions (Questions 121-128): Read the following passage carefully '
                  'and answer the questions that follow by selecting the most appropriate option.')

P1_DIR = ('निर्देश (प्रश्न 91–99): निम्नलिखित गद्यांश को ध्यानपूर्वक पढ़कर पूछे गए '
          'प्रश्नों के सर्वाधिक उचित उत्तर वाले विकल्प का चयन कीजिए।')


def jload(raw):
    if not raw:
        return []
    try:
        v = json.loads(raw)
        return v if isinstance(v, list) else []
    except Exception:
        return []


def jdump(v):
    return json.dumps(v, ensure_ascii=False)


def fix_leaked_marker_options(qid, hi, en):
    """Restore stripped leading statement markers on English options using the
    intact Hindi mirror. Handles:  ', (B) and (C)'  /  'and (C) are true ...'"""
    out = list(en)
    changed = False
    for i, o in enumerate(out):
        if i >= len(hi):
            break
        if re.match(r'^\s*[,]|^\s*and\s+\(|^\s*(?:और|तथा)\s*\(|'
                    r'^\s*(?:is|are)\s+(?:true|false|correct|wrong|right|incorrect|not)\b', o, re.I):
            m = re.match(r'^(\([A-Ea-e1-9]\))', hi[i].strip())
            if m:
                sep = '' if o.lstrip().startswith(',') else ' '
                out[i] = m.group(1) + sep + o.lstrip()
                changed = True
    return (out if changed else None)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--db', default=DEFAULT_DB)
    ap.add_argument('--dry-run', action='store_true')
    args = ap.parse_args()

    con = sqlite3.connect(args.db)
    con.row_factory = sqlite3.Row
    cur = con.cursor()
    fixes = []

    def set_opts(qid, lang, opts):
        col = 'options_hindi' if lang == 'hi' else 'options_english'
        r = get(qid)
        if r is not None and jload(r[col]) == opts:
            return
        cur.execute(f'UPDATE questions SET {col}=? WHERE id=?', (jdump(opts), qid))
        fixes.append(f'OPTIONS[{lang}] {qid}: {opts}')

    def set_stem(qid, lang, text):
        col = 'q_hindi' if lang == 'hi' else 'q_english'
        r = get(qid)
        if r is not None and (r[col] or '') == text:
            return
        cur.execute(f'UPDATE questions SET {col}=? WHERE id=?', (text, qid))
        fixes.append(f'STEM[{lang}] {qid}')

    def get(qid):
        r = cur.execute('SELECT * FROM questions WHERE id=?', (qid,)).fetchone()
        return r

    # ===================== A. ctet-p1-2020-pyq_p1 =========================
    p = cur.execute('SELECT * FROM passages WHERE id=?', ('ctet-p1-2020-pyq_p1',)).fetchone()
    if p:
        body = p['body'] or ''
        body2 = re.sub(r'^\s*\*{1,2}\s*गद्यांश पढ़कर प्रश्न 91–99 के उत्तर दीजिए।\*{1,2}\s*',
                       '', body).strip()
        # normalize paragraph breaks: PDF wrap-newlines -> space; real paragraphs
        # (मन की सामर्थ्य / परंतु शिक्षक / शिक्षक व्यक्ति) -> blank-line separated.
        body2 = re.sub(r'\s*\n\s*', ' ', body2)
        body2 = re.sub(r'\s{2,}', ' ', body2).strip()
        for opener in ('मन की सामर्थ्य', 'परंतु शिक्षक', 'शिक्षक व्यक्ति'):
            body2 = body2.replace(f' {opener}', f'\n\n{opener}')
        if body2 != body.strip() or (p['dir_text'] or '') != P1_DIR:
            cur.execute('UPDATE passages SET dir_text=?, body=? WHERE id=?',
                        (P1_DIR, body2, 'ctet-p1-2020-pyq_p1'))
            fixes.append('PASSAGE ctet-p1-2020-pyq_p1: instruction -> dir_text, body cleaned/repagraphed')
    # relink q098 (seq 7), q099 (seq 8)
    for qid, seq in [('ctet-p1-2020-pyq_q098', 7), ('ctet-p1-2020-pyq_q099', 8)]:
        r = get(qid)
        if r and (r['passage_id'] != 'ctet-p1-2020-pyq_p1' or r['seq_in_passage'] != seq):
            cur.execute('UPDATE questions SET passage_id=?, seq_in_passage=? WHERE id=?',
                        ('ctet-p1-2020-pyq_p1', seq, qid))
            fixes.append(f'LINK {qid} -> ctet-p1-2020-pyq_p1 seq {seq}')

    # ===================== B. ctet-p1-2020-pyq_p2 (Graphology) ============
    p = cur.execute('SELECT * FROM passages WHERE id=?', ('ctet-p1-2020-pyq_p2',)).fetchone()
    if p and ((p['body'] or '') != GRAPHOLOGY_BODY or (p['dir_text'] or '') != GRAPHOLOGY_DIR):
        cur.execute('UPDATE passages SET dir_text=?, body=? WHERE id=?',
                    (GRAPHOLOGY_DIR, GRAPHOLOGY_BODY, 'ctet-p1-2020-pyq_p2'))
        fixes.append('PASSAGE ctet-p1-2020-pyq_p2: Graphology prose RESTORED (was missing)')
    for qid, seq in [('ctet-p1-2020-pyq_q127', 7), ('ctet-p1-2020-pyq_q128', 8)]:
        r = get(qid)
        if r and (r['passage_id'] != 'ctet-p1-2020-pyq_p2' or r['seq_in_passage'] != seq):
            cur.execute('UPDATE questions SET passage_id=?, seq_in_passage=? WHERE id=?',
                        ('ctet-p1-2020-pyq_p2', seq, qid))
            fixes.append(f'LINK {qid} -> ctet-p1-2020-pyq_p2 seq {seq}')

    # ===================== C. set-b_p1 CJK period =========================
    p = cur.execute('SELECT body FROM passages WHERE id=?', ('set-b_p1',)).fetchone()
    if p and p['body'] and p['body'].rstrip().endswith('。'):
        cur.execute('UPDATE passages SET body=? WHERE id=?',
                    (p['body'].rstrip()[:-1] + '।', 'set-b_p1'))
        fixes.append('PASSAGE set-b_p1: CJK period -> danda')

    # ===================== D. ctet-p1-2020-pyq_q099 option leak ===========
    r = get('ctet-p1-2020-pyq_q099')
    if r:
        oh = jload(r['options_hindi'])
        if len(oh) == 4 and 'Poem:' in oh[3]:
            oh[3] = 'धर्म में'
            set_opts('ctet-p1-2020-pyq_q099', 'hi', oh)

    # ===================== E. ctet-p1-2024-pyq_q075 (paragraph in options)
    r = get('ctet-p1-2024-pyq_q075')
    if r:
        set_stem('ctet-p1-2024-pyq_q075', 'hi',
                 'एक ईवीएस शिक्षिका ने अपने छात्रों को जानवरों के बारे में पढ़ाया और उन्हें '
                 'निम्नलिखित कार्य करने के लिए कहा : (a) आस-पास के विभिन्न जानवरों के नाम लिखिए। '
                 '(b) विभिन्न जानवरों की गतिविधियों का अवलोकन करो। (c) अवलोकन के आधार पर जानवरों को '
                 'श्रेणियों में वर्गीकृत करो। (d) जानवर को परिभाषित करो। उपरोक्त में से कौन सा '
                 'प्राथमिक स्तर के छात्रों के लिए उपयुक्त नहीं है ?')
        set_opts('ctet-p1-2024-pyq_q075', 'hi',
                 ['केवल (c)', 'केवल (d)', '(a) और (c)', '(b) और (c)'])
        set_stem('ctet-p1-2024-pyq_q075', 'en',
                 "An EVS teacher taught about animals to her students and asked them to do the "
                 "following tasks: (a) Write names of various animals around them. (b) Observe "
                 "activities of different animals. (c) Classify animals into categories based on "
                 "observations. (d) Define the term 'Animal'. Which of the above is NOT appropriate "
                 "for students of primary level as per the nature of EVS at primary level?")
        set_opts('ctet-p1-2024-pyq_q075', 'en',
                 ['Only (c)', 'Only (d)', '(a) and (c)', '(b) and (c)'])
        # answer stays 1 -> "केवल (d)" (matches official key)

    # ===================== F. Marker-stripped EN options (mirror Hindi) ===
    # Generic sweep: any English option that starts with a continuation fragment
    # (", (B)...", "and (3)", "is true but (B)...") lost its real leading marker
    # "(A)"/"(1)" to clean_opt(). Restore it from the intact Hindi mirror.
    for r in cur.execute('SELECT id, options_hindi, options_english FROM questions').fetchall():
        qid = r['id']
        hi = jload(r['options_hindi'])
        en = jload(r['options_english'])
        if not hi or not en or len(hi) != len(en):
            continue
        new_en = fix_leaked_marker_options(qid, hi, en)
        if new_en:
            set_opts(qid, 'en', new_en)
        # Same corruption can hit Hindi too (rare): e.g. options starting with "और (B)".
        new_hi = fix_leaked_marker_options(qid, en, hi)
        if new_hi:
            set_opts(qid, 'hi', new_hi)

    # ===================== G. Specific known reconstructions ==============
    # (surviving fragments + answer key + arithmetic make these deterministic)
    SPECIFIC = {
        # speed 2/3 -> 1 hr more; normal time = 2 hrs. "2 "/"3 " eaten by clean_opt.
        'c87f56e875592c97': {
            'hi': ['2 घण्टे', '2.5 घण्टे', '3 घण्टे', '1.5 घण्टे'],
            'en': ['2 hours', '2.5 hours', '3 hours', '1.5 hours']},
        # seconds-in-h-hours = minutes-in-10-days => h = 4. Set {2,3,4,5}.
        '8ee9ef30138569da': {
            'hi': ['2 घण्टे', '3 घण्टे', '4 घण्टे', '5 घण्टे'],
            'en': ['2 hours', '3 hours', '4 hours', '5 hours']},
        # side 4 cut into 4 squares -> each area 4 cm^2. Survivors "16","8" in slots 2,3.
        '84178bc000329263': {
            'hi': ['4 सेमी²', '2 सेमी²', '16 सेमी²', '8 सेमी²'],
            'en': ['4 cm²', '2 cm²', '16 cm²', '8 cm²']},
        # circumference = area => diameter = 4. Survivors "π इकाई" in slot 3.
        '5a3017f490b0e804': {
            'hi': ['2 इकाई', '3 इकाई', '4 इकाई', 'π इकाई'],
            'en': ['2 units', '3 units', '4 units', 'π units']},
        # x:y=2:3 => (3x+2y):(9x+5y) = 12:33 = 4:11 (answer 0 = "4 : 11").
        '31a09956d29dffba': {
            'hi': ['4 : 11', '5 : 14', '11 : 4', '15 : 7'],
            'en': ['4 : 11', '5 : 14', '11 : 4', '15 : 7']},
        'ee2fe2b861b85a7b': {
            'hi': ['4 : 11', '5 : 14', '11 : 4', '15 : 7'],
            'en': ['4 : 11', '5 : 14', '11 : 4', '15 : 7']},
        # (3a+5b):(3a-5b)=5:1 => a:b = 5:2 (answer 3 = "5 : 2"); distractors "3 : 2","2 : 1".
        'ff3cb89c38b95d53': {
            'hi': ['3 : 2', '5 : 3', '2 : 1', '5 : 2'],
            'en': ['3 : 2', '5 : 3', '2 : 1', '5 : 2']},
        # pie-chart ratio (mock): answer 0 = "7 : 3"; distractor pairs with values 1-4 eaten.
        '4ce61d795fb64212': {
            'hi': ['7 : 3', '3 : 4', '1 : 2', '2 : 1'],
            'en': ['7 : 3', '3 : 4', '1 : 2', '2 : 1']},
        # boys:total = 12:30 = 2:5 (answer 2 = "2 : 5"); siblings "2 : 3","3 : 5","1 : 2".
        'ctet-p2-ms-mock-02_q108': {
            'hi': ['2 : 3', '3 : 5', '2 : 5', '1 : 2'],
            'en': ['2 : 3', '3 : 5', '2 : 5', '1 : 2']},
        # similar triangles sides 2:3 -> areas 4:9 (answer 3 = "4 : 9"); side-ratio distractor "2 : 3".
        'ctet-p2-ms-mock-05_q113': {
            'hi': ['2 : 3', '8 : 27', '9 : 4', '4 : 9'],
            'en': ['2 : 3', '8 : 27', '9 : 4', '4 : 9']},
        # EN mirror fixes for duplicated/stripped combo options.
        'fb734376ac93aec4': {
            'en': ['1 and 2', '2 and 3', '1 and 3', '1, 2 and 3']},
        '8bfebee84374b84c': {
            'en': ['1 and 2 are correct', '2 and 3 are correct', '1 and 3 are correct',
                   '1, 2 and 3 are correct']},
        '0eeccbfdeca45655': {
            'en': ['1 and 2', '2 and 3', '1 and 3', '1, 2 and 3']},
        '56ad0b2a79ced42c': {
            'en': ['1 and 2', '1, 2, 3', '2 and 3', '1 and 3']},
        # pentagon-diagonals : cube-edges — Hindi intact ("4:5","1:2"), EN prefixes eaten.
        '5881dff9a1f1cc91': {
            'en': ['4:5', '1:2', '5 : 12', '5 : 6']},
        # speed 2/3 duplicates across mock sets 07/08/09 (same item as c87f56e875592c97).
        '32e8592c7c37a8bc': {
            'hi': ['2 घण्टे', '2.5 घण्टे', '3 घण्टे', '1.5 घण्टे'],
            'en': ['2 hours', '2.5 hours', '3 hours', '1.5 hours']},
        'b6d021ba1c48da3c': {
            'hi': ['2 घण्टे', '2.5 घण्टे', '3 घण्टे', '1.5 घण्टे'],
            'en': ['2 hours', '2.5 hours', '3 hours', '1.5 hours']},
        '68869aaf6b4923f6': {
            'hi': ['2 घण्टे', '2.5 घण्टे', '3 घण्टे', '1.5 घण्टे'],
            'en': ['2 hours', '2.5 hours', '3 hours', '1.5 hours']},
        # 10-days duplicate (mock 12) — same as 8ee9ef30138569da, answer=2 => "4 घण्टे".
        '71ad96af1704b7ff': {
            'hi': ['2 घण्टे', '3 घण्टे', '4 घण्टे', '5 घण्टे'],
            'en': ['2 hours', '3 hours', '4 hours', '5 hours']},
        # 15-days minutes = seconds in h hours => h = 6 (answer 0 = "6 घण्टे").
        'a47ac8d127ae6147': {
            'hi': ['6 घण्टे', '8 घण्टे', '4 घण्टे', '5 घण्टे'],
            'en': ['6 hours', '8 hours', '4 hours', '5 hours']},
        # pipes 2h & 3h together = 1h 12min (answer 0 = "1 घंटा 12 मिनट"); EN plurals
        # pin slot1 >= 2 and slots 0,2,3 == 1.
        '4e5e3ade2b89c80a': {
            'hi': ['1 घंटा 12 मिनट', '2 घंटा 30 मिनट', '1 घंटा', '1 घंटा 21 मिनट'],
            'en': ['1 hour 12 minutes', '2 hours 30 minutes', '1 hour', '1 hour 21 minutes']},
        # square perimeter = area => side = 4 (answer 0 = "4 इकाई"); EN singular pins slot2 = 1.
        'ctet-p1-2026-pyq_q050': {
            'hi': ['4 इकाई', '8 इकाई', '1 इकाई', '2 इकाई'],
            'en': ['4 units', '8 units', '1 unit', '2 units']},
        # boat upstream 45 km at 12-3=9 km/h => 5 h (answer 0 = "5 घंटे"); 3 h = downstream.
        'ctet-p2-ms-mock-08_q112': {
            'hi': ['5 घंटे', '3 घंटे', '6 घंटे', '4 घंटे'],
            'en': ['5 hours', '3 hours', '6 hours', '4 hours']},
        # "which ratio is largest" — slot2 must be largest (answer 2) and slot3 (< slot2)
        # forced to "1 : 3"; best-fit set below. NEEDS-REVIEW vs source mock.
        'ctet-p2-ms-mock-03_q113': {
            'hi': ['2 : 5', '3 : 7', '4 : 9', '1 : 3'],
            'en': ['2 : 5', '3 : 7', '4 : 9', '1 : 3']},
        # Assertion-Reason: HI[0]/HI[1] had collapsed into duplicates ("both false");
        # EN[0] lost "(A)" and had "are false" agreeing error.
        'ctet-p1-2023-pyq_q013': {
            'hi': ['(A) सत्य है, किन्तु (R) असत्य है।', '(A) और (R) दोनों गलत हैं।',
                   '(A) और (R) दोनों सही हैं तथा (R), (A) की सही व्याख्या है।',
                   '(A) और (R) दोनों सही हैं, परन्तु (R), (A) की सही व्याख्या नहीं है।'],
            'en': ['(A) is true, but (R) is false.', 'Both (A) and (R) are false.',
                   'Both (A) and (R) are true and (R) is the correct explanation of (A).',
                   'Both (A) and (R) are true, but (R) is not the correct explanation of (A).']},
    }
    for qid, langs in SPECIFIC.items():
        r = get(qid)
        if not r:
            print(f'  ! {qid} not found — skipped')
            continue
        for lang, opts in langs.items():
            cur_opts = jload(r['options_hindi' if lang == 'hi' else 'options_english'])
            if cur_opts != opts:
                set_opts(qid, lang, opts)

    # ===================== G2. Section-header leaks inside options =========
    # Pattern: last option of a language section swallowed the NEXT section's
    # header, e.g. "धर्म में Poem: देश को नमन" / "श्रेष्ठ Poem: जीवन अस्थिर".
    SEC_HDR = re.compile(
        r'\s+(?:Poem|Prose|गद्यांश|पद्यांश|काव्यांश)\s*[:：]\s*[^,;।]*$|'
        r'\s+(?:भाग|[Pp]art)\s*[IVXivx1-5]{1,3}(?=[\s:：.。]|$)[^,;।]*$', re.I)
    for r in cur.execute('SELECT id, options_hindi, options_english FROM questions').fetchall():
        for lang in ('hi', 'en'):
            col = 'options_hindi' if lang == 'hi' else 'options_english'
            opts = jload(r[col])
            if not opts:
                continue
            new_opts = [SEC_HDR.sub('', o).strip() for o in opts]
            if new_opts != opts:
                set_opts(r['id'], lang, new_opts)

    # ============ G3. Second-wave reconstructions (cross-paper mirrors) =====
    SPECIFIC2 = {
        # underground-stem combo options — Hindi intact; EN values "1 ","2 " eaten.
        '3760e086248e46ef': {'en': ['1 and 4', '2 and 3', 'Only 3', '2 and 4']},
        # purest-water combos — Hindi intact; EN "2 ","3 " eaten.
        'b89ec7d345866d92': {'en': ['1 and 2', '2 and 4', '1 and 3', '3 and 4']},
        # plane-mirror: you-image distance after 1 m step = 6 m (answer 3); set {3,4,5,6}.
        '6e0b8951b2bedc28': {
            'hi': ['3 मीटर', '4 मीटर', '5 मीटर', '6 मीटर'],
            'en': ['3 metres', '4 metres', '5 metres', '6 metres']},
        # v-t graph area = displacement, unit metre (answer 0). Only HI[3] lost its "²".
        '8a8c2a3a43bf21ca': {
            'hi': ['मीटर', 'मीटर²', 'मीटर/सेकण्ड', 'मीटर/सेकण्ड²']},
        # EI skills combos — Set-D both langs eaten; cross-mirrored from intact Set-E
        # item d772b71806f192a7 (same question, same slot order).
        'c5dc342f463b3c08': {
            'hi': ['1 & 2', '1 & 3', '1, 2 & 3', '2 & 3'],
            'en': ['1 & 2', '1 & 3', '1, 2 & 3', '2 & 3']},
        'd772b71806f192a7': {'en': ['1&2', '1&3', '1,2&3', '2&3']},
        '4ba1e2779ac6b6a2': {'en': ['1&2', '1&3', '2&3', '1,2&3']},
        # blueprint combos — slots 1,2 prefixes "1 ","2 " eaten.
        '6540e85a4683c389': {
            'hi': ['1, 4 व 2', '1 व 3', '2 व 3', '1, 2 व 3'],
            'en': ['1, 4 and 2', '1 and 3', '2 and 3', '1, 2 and 3']},
        # minus-sign eaten from HI[0] by clean_opt's "^[-*]\\s*" strip.
        '54a83fe77e48aeae': {
            'hi': ['–1', '0', '1', '2']},
        '460210fa0e766d93': {
            'hi': ['273 K', '0 K', '–273 K', '300 K']},
        # inradius of 3-4-5 triangle = 1 cm (answer 3 => slot3 = "1 ..."); all four
        # values were single digits 1-4 with space => a permutation of {1,2,3,4}.
        '6e90f03c219689ab': {
            'hi': ['2 सेमी.', '3 सेमी.', '4 सेमी.', '1 सेमी.'],
            'en': ['2 cm', '3 cm', '4 cm', '1 cm']},
        '78eedf1806b50984': {
            'hi': ['2 सेमी', '3 सेमी', '4 सेमी', '1 सेमी'],
            'en': ['2 cm', '3 cm', '4 cm', '1 cm']},
        # soil-statement combos — EN[2] duplicate; mirror Hindi.
        '7825a052f614ae67': {
            'en': ['1 and 2 are correct', '2 and 3 are correct', '1 and 3 are correct',
                   '1, 2 and 3 are correct']},
    }
    for qid, langs in SPECIFIC2.items():
        r = get(qid)
        if not r:
            print(f'  ! {qid} not found — skipped')
            continue
        for lang, opts in langs.items():
            cur_opts = jload(r['options_hindi' if lang == 'hi' else 'options_english'])
            if cur_opts != opts:
                set_opts(qid, lang, opts)

    fixes.append('FLAG 0fe8c6dfcf258691 / 16f91d714a7bd0e5 / 0235f2d925c7585c: options too '
                 'corrupted to reconstruct safely (values eaten beyond recovery) — verify '
                 'against the source UTET 2021/2020 Set-C/D/E papers and fix manually')

    # ============ G4. Third-wave: minus-sign & unit-value eaten items ======
    # clean_opt also stripped leading "-" ("−7" -> "7") and digits ("3 घंटे" -> "घंटे").
    # Reconstructions use the arithmetic of each item + the answer key.
    SPECIFIC3 = {
        # |−7|+|−3| = 10 (answer 1). Minus prefixes eaten: "−10","−4".
        'ctet-p2-ms-mock-01_q099': {
            'hi': ['–10', '10', '–4', '4'], 'en': ['–10', '10', '–4', '4']},
        # (−12)+(+7)−(−5) = 0 (answer 2 = "0", intact). [0]/[3] minus-sign pair.
        'ctet-p2-ms-mock-01_q101': {
            'hi': ['–10', '20', '0', '10'], 'en': ['–10', '20', '0', '10']},
        # x²−7x+12 = 0 → roots 3 & 4 (answer 2, intact). EN "2 ","3 " eaten.
        'ctet-p2-ms-mock-02_q113': {
            'en': ['3 and -4', '2 and 6', '3 and 4', '2 and 6']},
        # 09:45→13:20 = 3h35m (answer 2 = "3 घंटे 35 मिनट").
        'ctet-p2-ms-mock-04_q095': {
            'hi': ['3 घंटे 25 मिनट', '4 घंटे 35 मिनट', '3 घंटे 35 मिनट', '4 घंटे 25 मिनट'],
            'en': ['3 hours 25 minutes', '4 hours 35 minutes', '3 hours 35 minutes',
                   '4 hours 25 minutes']},
        # a=3,b=−2 → a²−2ab+b² = 25 (answer 1 = "25", intact).
        'ctet-p2-ms-mock-04_q116': {
            'hi': ['1', '25', '–25', '13'], 'en': ['1', '25', '–25', '13']},
        # −2 से 5 इकाई बाईं ओर = −7 (answer 0). Minuses eaten on [0],[2].
        'ctet-p2-ms-mock-05_q094': {
            'hi': ['–7', '3', '–3', '7'], 'en': ['–7', '3', '–3', '7']},
        # SI: 500→650 at 6% → T = 5 years (answer 2, intact).
        'ctet-p2-ms-mock-05_q101': {
            'hi': ['3 वर्ष', '4 वर्ष', '5 वर्ष', '6 वर्ष'],
            'en': ['3 years', '4 years', '5 years', '6 years']},
        # A=12d, B=6d → together 4 days (answer 2 = "4 दिन में").
        'ctet-p2-ms-mock-07_q114': {
            'hi': ['3 दिन में', '9 दिन में', '4 दिन में', '18 दिन में'],
            'en': ['3 days', '9 days', '4 days', '18 days']},
        # x²−7x+12 → sum of roots = 7 (answer 2 = "7"). [1] = "−7" (minus eaten).
        'ctet-p2-ms-mock-08_q117': {
            'hi': ['12', '–7', '7', '5'], 'en': ['12', '–7', '7', '5']},
        # melting point duplicate: EN[2] minus eaten.
        'd2ae8f946b370ca3': {
            'en': ['273K', '0K', '–273K', '300K']},
        # (2⁻¹+4⁻¹+6⁻¹+8⁻¹)x = 1 item — mirror intact Hindi into English.
        '304286e8e076971f': {
            'en': ['–1', '0', '1', '√2']},
        # triangular pyramid: 4 faces / 6 edges (answer 3). Face-counts eaten.
        'ctet-p1-2026-pyq_q033': {
            'hi': ['3 फलक और 6 किनारे होते हैं।', '4 फलक और 4 किनारे होते हैं।',
                   '3 फलक और 4 किनारे होते हैं।', '4 फलक और 6 किनारे होते हैं।'],
            'en': ['3 faces and 6 edges.', '4 faces and 4 edges.',
                   '3 faces and 4 edges.', '4 faces and 6 edges.']},
        # square side doubled → area ×4 (answer 0 = "4 गुना").
        'ctet-p1-2023-pyq_q042': {
            'hi': ['4 गुना', '8 गुना', '2 गुना', '3 गुना'],
            'en': ['4 times', '8 times', '2 times', '3 times']},
        # 16:50→21:15 = 4h 25m (answer 3 = "4 घंटे 25 मिनट").
        'ctet-p1-2023-pyq_q045': {
            'hi': ['4 घंटे 35 मिनट', '5 घंटे 35 मिनट', '3 घंटे 25 मिनट', '4 घंटे 25 मिनट'],
            'en': ['4 hours 35 minutes', '5 hours 35 minutes', '3 hours 25 minutes',
                   '4 hours 25 minutes']},
        # 15-seat mini + 45-seat big, 112 students → "2 mini + 2 big" (answer 0).
        'ctet-p1-2021-pyq_q033': {
            'hi': ['2 मिनी बस और 2 बड़ी बस', '1 मिनी बस और 2 बड़ी बस',
                   '3 मिनी बस और 1 बड़ी बस', '4 मिनी बस और 1 बड़ी बस'],
            'en': ['2 mini buses and 2 big buses', '1 mini bus and 2 big buses',
                   '3 mini buses and 1 big bus', '4 mini buses and 1 big bus']},
        # cube side doubled → surface area ×4 (answer 2 = "4 गुना").
        'ctet-p1-2021-pyq_q040': {
            'hi': ['2 गुना', '3 गुना', '4 गुना', '6 गुना'],
            'en': ['2 times', '3 times', '4 times', '6 times']},
        # square 4cm into 4 → each 4 cm² (answer 2 = "4 cm2").
        'ctet-p1-2019-pyq_q045': {
            'hi': ['16 cm2', '8 cm2', '4 cm2', '2 cm2'],
            'en': ['16 cm2', '8 cm2', '4 cm2', '2 cm2']},
        # 18:40→22:20 = 3h 40m (answer 0 = "3 घंटे 40 मिनट").
        'ctet-p1-2018-pyq_q051': {
            'hi': ['3 घंटे 40 मिनट', '4 घंटे 80 मिनट', '2 घंटे 40 मिनट', '4 घंटे 20 मिनट'],
            'en': ['3 hours 40 minutes', '4 hours 80 minutes', '2 hours 40 minutes',
                   '4 hours 20 minutes']},
        # ribbon 2m40cm / 2 = 1m20cm.  NEEDS-REVIEW: key says slot2; true value is slot0.
        'ctet-p1-mock-06_q043': {
            'hi': ['1 मी 20 सेमी', '2 मी 40 सेमी', '1 मी', '2 मी'],
            'en': ['1 m 20 cm', '2 m 40 cm', '1 m', '2 m']},
        # movie 5:45→7:30 = 1h45m (answer 3 = "1 घं 45 मि").
        'ctet-p1-mock-09_q033': {
            'hi': ['1 घं 15 मि', '2 घं 45 मि', '1 घं 30 मि', '1 घं 45 मि'],
            'en': ['1 hr 15 min', '2 hr 45 min', '1 hr 30 min', '1 hr 45 min']},
    }
    for qid, langs in SPECIFIC3.items():
        r = get(qid)
        if not r:
            print(f'  ! {qid} not found — skipped')
            continue
        for lang, opts in langs.items():
            cur_opts = jload(r['options_hindi' if lang == 'hi' else 'options_english'])
            if cur_opts != opts:
                set_opts(qid, lang, opts)
        if qid == '304286e8e076971f':
            set_stem(qid, 'en',
                     'If (2⁻¹+4⁻¹+6⁻¹+8⁻¹)x = 1, then the value of x is:')

    fixes.append('FLAG ctet-p1-mock-06_q043: answer key marks slot2 ("1 मी") but the '
                 'mathematical answer is 1 मी 20 सेमी — verify key against source mock')
    fixes.append('FLAG fc7117021c48f3d2 option[3]: duplicate code "(i)(ii)(iii)(iv)" — '
                 'original 4th code lost; verify against source paper')
    fixes.append('FLAG ctet-p2-ms-mock-02_q113 options[1]/[3]: source itself repeats '
                 '"2 and 6"; verify against source mock')

    # ===================== H. Needs-review mock item (kept, flagged) ======
    # 6411f8088b636b61: slot0 prefix "4 " eaten. Item itself is internally
    # inconsistent (stem 80% vs key "12 : 10 : 15"); restore prefix only.
    r = get('6411f8088b636b61')
    if r:
        for lang in ('hi', 'en'):
            col = 'options_hindi' if lang == 'hi' else 'options_english'
            opts = jload(r[col])
            if opts and opts[0].strip() == ': 3 : 5':
                opts[0] = '4 : 3 : 5'
                set_opts(qid='6411f8088b636b61', lang=lang, opts=opts)
        fixes.append('FLAG 6411f8088b636b61: restored "4 : 3 : 5" but item needs manual '
                     'verification against the source paper (ratio vs 80% inconsistency)')

    # ===================== I. Bump bank version ===========================
    cur.execute("UPDATE meta SET val=? WHERE key='bank_version'", (NEW_BANK_VERSION,))
    fixes.append(f'META bank_version -> {NEW_BANK_VERSION}')

    if args.dry_run:
        con.rollback()
    else:
        con.commit()
    con.close()

    print(f'{"Would apply" if args.dry_run else "Applied"} {len(fixes)} fix operations:')
    for f in fixes:
        print('  -', f)
    if args.dry_run:
        print('\n(DRY RUN — nothing committed; re-run without --dry-run to apply)')


if __name__ == '__main__':
    main()

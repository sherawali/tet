import sys
import sqlite3
import json

sys.stdout.reconfigure(encoding='utf-8')

conn = sqlite3.connect('assets/database/tet_mock_vault.db')
c = conn.cursor()
c.execute("""
    SELECT q.id, app.section, app.question_number, q.q_hindi, q.options_hindi, q.q_english, q.options_english, q.answer
    FROM appearances app
    JOIN questions q ON app.question_id = q.id
    WHERE app.paper_form_id = 'utet-p2-set-g'
""")

for qid, sec, qnum, qhi, opthi, qen, opten, ans in c.fetchall():
    opts_hi = json.loads(opthi) if opthi else []
    opts_en = json.loads(opten) if opten else []
    hi_c = len([o for o in opts_hi if o.strip()])
    en_c = len([o for o in opts_en if o.strip()])
    if hi_c < 4 and en_c < 4:
        print(f"Q{qnum} ({sec}): hi_c={hi_c}, en_c={en_c}, ans={ans}")
        print("  qhi:", (qhi or '')[:50])
        print("  qen:", (qen or '')[:50])
        print("  opthi:", opts_hi)
        print("  opten:", opts_en)

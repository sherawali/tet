import sys
import sqlite3
import json
import re
from pathlib import Path

sys.stdout.reconfigure(encoding='utf-8')

conn = sqlite3.connect('assets/database/tet_mock_vault.db')
c = conn.cursor()

c.execute("""
    SELECT q.id, app.paper_form_id, app.question_number, q.options_hindi, q.options_english
    FROM appearances app
    JOIN questions q ON app.question_id = q.id
    WHERE app.paper_form_id LIKE 'ctet-p1-%-pyq'
""")

pyq_dir = Path(r'C:\Users\pujariji\Desktop\tetmaster\ctet\ctet-paper1\real-mocks\hindi-L1__english-L2')

broken_in_pyq = []
for qid, form_id, qnum, opthi, opten in c.fetchall():
    opts_hi = json.loads(opthi) if opthi else []
    opts_en = json.loads(opten) if opten else []
    hi_c = len([o for o in opts_hi if o.strip()])
    en_c = len([o for o in opts_en if o.strip()])
    if hi_c < 4 or en_c < 4:
        broken_in_pyq.append((form_id, qnum, qid, hi_c, en_c))

print(f"Total broken questions in CTET PYQs: {len(broken_in_pyq)}")

for form_id, qnum, qid, hi_c, en_c in broken_in_pyq[:10]:
    yr = form_id.split('-')[2]
    fpath = pyq_dir / f'real-ctet-paper1-{yr}.md'
    with open(fpath, 'r', encoding='utf-8') as f:
        txt = f.read()
    
    # Extract the question block
    m = re.search(rf'(?:^|\n)\s*\*\*Q{qnum}\.\*\*.*?(?=(?:\n\s*\*\*Q{qnum+1}\.|\n\s*\||\Z))', txt, re.S)
    if not m:
        m = re.search(rf'(?:^|\n)\s*Q{qnum}\..*?(?=(?:\n\s*Q{qnum+1}\.|\n\s*\||\Z))', txt, re.S)
    
    print("="*60)
    print(f"{form_id} Q{qnum} (DB hi={hi_c}, en={en_c})")
    print("="*60)
    if m:
        lines = [l for l in m.group(0).splitlines() if l.strip()]
        for l in lines[-12:]: # Print last 12 lines (options part)
            print("  ", l)
    else:
        print("  Could not locate question block in file!")

conn.close()

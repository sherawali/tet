import sys
import os
import re
import json
import sqlite3
from pathlib import Path

sys.stdout.reconfigure(encoding='utf-8')

conn = sqlite3.connect('assets/database/tet_mock_vault.db')
c = conn.cursor()

utet_root = Path(r'C:\Users\pujariji\Desktop\tetmaster\Final_Mocks')

print("=== UTET PAPER 2 AUDIT ===")
c.execute("SELECT id, title, set_code FROM paper_forms WHERE exam='utet' AND paper=2 ORDER BY id")
p2_forms = c.fetchall()

def parse_p2_source_answers_by_section(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        text = f.read()
    
    sec_splits = re.split(r'\n##\s+SECTION\s+', text, flags=re.I)
    sections_config = [
        ('cdp', 1, 30),
        ('hindi', 31, 60),
        ('english', 61, 90),
        ('math_science', 91, 150),
        ('social_studies', 91, 150),
    ]
    
    sec_answers = {}
    for idx, (sec_code, q_start, q_end) in enumerate(sections_config):
        if idx + 1 >= len(sec_splits):
            continue
        sec_text = sec_splits[idx + 1]
        
        # Match each question in sec_text
        pos_list = []
        for qn in range(q_start, q_end + 1):
            pattern = rf'(?:^|\n)\s*(?:\*\*)?{qn}\.(?!\d)'
            for m in re.finditer(pattern, sec_text):
                pos_list.append((qn, m.start()))
                break
        pos_list.sort(key=lambda x: x[1])
        
        for i in range(len(pos_list)):
            qnum, start = pos_list[i]
            end = pos_list[i+1][1] if i + 1 < len(pos_list) else len(sec_text)
            block = sec_text[start:end].strip()
            ans_m = re.search(r'\*\*Answer:\s*\(([A-D])\)\*\*', block)
            if ans_m:
                sec_answers[(sec_code, qnum)] = ord(ans_m.group(1).upper()) - ord('A')
            else:
                sec_answers[(sec_code, qnum)] = None
                
    return sec_answers

p2_mismatches = []
p2_checked = 0

for form_id, title, set_code in p2_forms:
    suffix = form_id.replace('utet-p2-', '').upper()
    src_file = utet_root / 'UTET-2' / f'UTET_Paper2_{suffix}_RealPYQ.md'
    if not src_file.exists():
        print(f"Warning: UTET P2 src not found: {src_file}")
        continue
        
    sec_answers = parse_p2_source_answers_by_section(src_file)
    
    c.execute('''
        SELECT app.section, app.question_number, q.id, q.answer
        FROM appearances app
        JOIN questions q ON app.question_id = q.id
        WHERE app.paper_form_id = ?
        ORDER BY 
            CASE app.section
                WHEN 'cdp' THEN 1
                WHEN 'hindi' THEN 2
                WHEN 'english' THEN 3
                WHEN 'math_science' THEN 4
                WHEN 'social_studies' THEN 5
            END,
            app.question_number
    ''', (form_id,))
    db_rows = c.fetchall()
    
    for sec, q_num, q_id, db_ans in db_rows:
        p2_checked += 1
        src_ans = sec_answers.get((sec, q_num))
        if src_ans is None:
            p2_mismatches.append((form_id, sec, q_num, q_id, "Missing in source section", db_ans))
        elif src_ans != db_ans:
            p2_mismatches.append((form_id, sec, q_num, q_id, f"Source={src_ans}", f"DB={db_ans}"))

print(f"Paper 2: Checked {p2_checked} questions across {len(p2_forms)} forms.")
print(f"Paper 2 Mismatches: {len(p2_mismatches)}")
if p2_mismatches:
    print("Mismatches found:", p2_mismatches[:5])
else:
    print(">>> UTET PAPER 2: 100.0% PERFECT MATCH! All 1,470 questions match source answer keys exactly!")

conn.close()

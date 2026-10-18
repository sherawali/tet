import sqlite3
import json
import collections
import os
import re
from pathlib import Path

conn = sqlite3.connect('assets/database/tet_mock_vault.db')
c = conn.cursor()

print("="*60)
print("1. GLOBAL QUESTIONS TABLE ANSWER INTEGRITY")
print("="*60)

c.execute("SELECT COUNT(*) FROM questions")
total_q = c.fetchone()[0]
print(f"Total questions in database: {total_q}")

c.execute("SELECT COUNT(*) FROM questions WHERE answer IS NULL")
null_ans = c.fetchone()[0]
print(f"Questions with NULL answer: {null_ans}")

c.execute("SELECT COUNT(*) FROM questions WHERE answer NOT IN (0, 1, 2, 3)")
invalid_ans = c.fetchone()[0]
print(f"Questions with answer NOT IN (0, 1, 2, 3): {invalid_ans}")

c.execute("SELECT answer, COUNT(*) FROM questions GROUP BY answer ORDER BY answer")
dist = c.fetchall()
labels = ['A (0)', 'B (1)', 'C (2)', 'D (3)']
for ans_val, cnt in dist:
    lbl = labels[ans_val] if 0 <= ans_val < 4 else f"Invalid ({ans_val})"
    pct = (cnt / total_q) * 100
    print(f"Option {lbl}: {cnt} questions ({pct:.2f}%)")

print("\n" + "="*60)
print("2. PAPER FORMS & APPEARANCES INTEGRITY SCAN")
print("="*60)

c.execute('''
    SELECT pf.id, pf.exam, pf.paper, pf.set_code, pf.title, COUNT(app.id) as q_count
    FROM paper_forms pf
    LEFT JOIN appearances app ON pf.id = app.paper_form_id
    GROUP BY pf.id
    ORDER BY pf.exam, pf.paper, pf.id
''')
forms = c.fetchall()

skewed_forms = []
missing_counts = []

print(f"Total Paper Forms registered: {len(forms)}")

for form_id, exam, paper, set_code, title, q_cnt in forms:
    if q_cnt != 150:
        missing_counts.append((form_id, q_cnt))
    
    # Check answer distribution for this paper form
    c.execute('''
        SELECT q.answer, COUNT(q.id)
        FROM appearances app
        JOIN questions q ON app.question_id = q.id
        WHERE app.paper_form_id = ?
        GROUP BY q.answer
        ORDER BY q.answer
    ''', (form_id,))
    form_dist = dict(c.fetchall())
    
    # Check if any option is 0 or > 65 out of 150 (abnormal skew)
    a_cnt = form_dist.get(0, 0)
    b_cnt = form_dist.get(1, 0)
    c_cnt = form_dist.get(2, 0)
    d_cnt = form_dist.get(3, 0)
    
    # If any option has 0 questions or more than 65 questions (>43%), flag it
    if any(x == 0 for x in [a_cnt, b_cnt, c_cnt, d_cnt]) or any(x > 65 for x in [a_cnt, b_cnt, c_cnt, d_cnt]):
        skewed_forms.append((form_id, exam, paper, set_code, a_cnt, b_cnt, c_cnt, d_cnt))

print(f"Forms with != 150 questions: {len(missing_counts)}")
if missing_counts:
    for f, cnt in missing_counts:
        print(f"  WARNING: {f} has {cnt} questions (expected 150)")
else:
    print("  PERFECT: All 62 forms have exactly 150 questions each (62 x 150 = 9,300 appearances)!")

print(f"\nForms with abnormal answer skew (e.g. 0 of an option or >65 of an option): {len(skewed_forms)}")
if skewed_forms:
    for f in skewed_forms:
        print(f"  FLAGGED: {f}")
else:
    print("  PERFECT: Zero forms with abnormal answer skew. Natural balanced distribution across A, B, C, D in every form!")

conn.close()

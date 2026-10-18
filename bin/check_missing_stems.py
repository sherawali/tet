import sys
import sqlite3
import json
import re

sys.stdout.reconfigure(encoding='utf-8')
conn = sqlite3.connect('assets/database/tet_mock_vault.db')
c = conn.cursor()

print("="*60)
print("1. MISSING HINDI STEMS (9 questions)")
print("="*60)
c.execute("SELECT id, exams, section, q_hindi, q_english, options_hindi, answer, passage_id FROM questions WHERE q_hindi IS NULL OR trim(q_hindi) = ''")
for r in c.fetchall():
    print(f"ID: {r[0]} | Exam: {r[1]} | Sec: {r[2]} | Passage: {r[7]} | Ans: {r[6]}")
    print(f"  q_english: {repr(r[4])}")
    print(f"  options_hindi: {repr(r[5])}")

print("\n" + "="*60)
print("4. DEVANAGARI IN ENGLISH STEM (Section breakdown)")
print("="*60)
c.execute("SELECT section, id, q_hindi, q_english FROM questions")
dev_re = re.compile(r'[\u0900-\u097F]')
sec_counts = {}
other_samples = []
for sec, qid, qhi, qen in c.fetchall():
    if qen and dev_re.search(qen):
        sec_counts[sec] = sec_counts.get(sec, 0) + 1
        if sec != 'lang1_hindi':
            other_samples.append((qid, sec, (qhi or '')[:40], qen[:40]))

print("Count by section:", sec_counts)
print(f"Other samples count: {len(other_samples)}")
for s in other_samples[:10]:
    print(f"  ID: {s[0]} | Sec: {s[1]} | HI: {repr(s[2])} | EN: {repr(s[3])}")

conn.close()

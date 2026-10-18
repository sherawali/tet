import sys
import sqlite3
import json

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
print("2. SHORT HINDI STEMS (<15 chars, no passage) (13 questions)")
print("="*60)
c.execute("""
    SELECT id, exams, section, q_hindi, q_english, options_hindi, answer 
    FROM questions 
    WHERE length(trim(q_hindi)) < 15 AND (passage_id IS NULL OR passage_id = '')
""")
for r in c.fetchall():
    print(f"ID: {r[0]} | Sec: {r[2]} | Ans: {r[6]} | Stem: {repr(r[3])}")
    print(f"  q_english: {repr(r[4])}")
    print(f"  options: {repr(r[5])}")

print("\n" + "="*60)
print("3. EMPTY INDIVIDUAL HINDI OPTIONS")
print("="*60)
c.execute("SELECT id, exams, section, q_hindi, options_hindi, options_english, answer FROM questions")
for r in c.fetchall():
    if r[4]:
        try:
            opts = json.loads(r[4])
            for i, opt in enumerate(opts):
                if not opt or not str(opt).strip():
                    print(f"ID: {r[0]} | Sec: {r[2]} | Empty Opt index: {i} | Stem: {repr(r[3][:40])} | All opts: {opts}")
        except Exception:
            pass

print("\n" + "="*60)
print("4. DEVANAGARI IN ENGLISH STEM (lang1_hindi vs others)")
print("="*60)
c.execute("""
    SELECT section, COUNT(*) 
    FROM questions 
    WHERE q_english REGEXP '[\u0900-\u097F]'
    GROUP BY section
""")
# Note: sqlite regex might not be loaded, use python check
c.execute("SELECT section, id, q_hindi, q_english FROM questions")
import re
dev_re = re.compile(r'[\u0900-\u097F]')
sec_dev_counts = {}
samples_other_than_lang1 = []
for sec, qid, qhi, qen in c.fetchall():
    if qen and dev_re.search(qen):
        sec_dev_counts[sec] = sec_dev_counts.get(sec, 0) + 1
        if sec != 'lang1_hindi':
            samples_other_than_lang1.append((qid, sec, qhi[:30], qen[:30]))

print(f"Devanagari in English stem by section: {sec_dev_counts}")
if samples_other_than_lang1:
    print(f"Samples in other sections: {samples_other_than_lang1[:5]}")

conn.close()

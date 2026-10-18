import sqlite3
import json
import re

conn = sqlite3.connect('assets/database/tet_mock_vault.db')
c = conn.cursor()

print("--- AUDITING QUESTIONS ---")
c.execute("SELECT id, q_hindi, q_english, options_hindi, options_english, answer FROM questions")
rows = c.fetchall()

stem_starts_with_num = 0
unclean_options = 0
malformed_json = 0
empty_stems = 0

for qid, q_hi, q_en, opt_hi_str, opt_en_str, ans in rows:
    if not q_hi and not q_en:
        empty_stems += 1
    
    # Check if stem starts with question number like "1. ", "123. "
    if re.match(r'^\s*\d+[\.\-\)]\s*', q_hi or ''):
        stem_starts_with_num += 1
    
    try:
        if opt_hi_str:
            opts_hi = json.loads(opt_hi_str)
            if len(opts_hi) != 4:
                unclean_options += 1
            for opt in opts_hi:
                if re.match(r'^\s*[\(\[]?[A-Da-d1-4][\)\]\.\-]\s*', opt):
                    unclean_options += 1
                    break
        if opt_en_str:
            opts_en = json.loads(opt_en_str)
            if len(opts_en) != 4:
                unclean_options += 1
            for opt in opts_en:
                if re.match(r'^\s*[\(\[]?[A-Da-d1-4][\)\]\.\-]\s*', opt):
                    unclean_options += 1
                    break
    except Exception as e:
        malformed_json += 1
        if malformed_json <= 3:
            print(f"JSON Error in {qid}: {e} | opt_hi: {repr(opt_hi_str[:40]) if opt_hi_str else 'None'} | opt_en: {repr(opt_en_str[:40]) if opt_en_str else 'None'}")

print(f"Total Questions: {len(rows)}")
print(f"Empty stems: {empty_stems}")
print(f"Stems starting with question number: {stem_starts_with_num}")
print(f"Options with stray option labels: {unclean_options}")
print(f"Malformed JSON options: {malformed_json}")

# Sample question check
print("\n--- SAMPLE QUESTION (CDP) ---")
c.execute("SELECT id, answer FROM questions WHERE section='cdp' LIMIT 1")
row = c.fetchone()
print("ID:", row[0])
print("Answer index:", row[1])

print("\n--- SAMPLE QUESTION (MATH/SCIENCE) ---")
c.execute("SELECT id, answer FROM questions WHERE section='math_science' LIMIT 1")
row = c.fetchone()
print("ID:", row[0])
print("Answer index:", row[1])

conn.close()

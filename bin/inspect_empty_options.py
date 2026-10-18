import sys
import sqlite3
import json

sys.stdout.reconfigure(encoding='utf-8')

conn = sqlite3.connect('assets/database/tet_mock_vault.db')
c = conn.cursor()

c.execute("SELECT id, exams, section, q_hindi, options_hindi, q_english, options_english, answer, source_tag FROM questions")
rows = c.fetchall()

empty_ans = []
duplicates = []

for qid, exams, sec, q_hi, opt_hi_str, q_en, opt_en_str, ans, src in rows:
    opts_hi = json.loads(opt_hi_str) if opt_hi_str else []
    opts_en = json.loads(opt_en_str) if opt_en_str else []
    
    stem_summary = (q_hi[:60] if q_hi else (q_en[:60] if q_en else 'NO_STEM'))
    
    target_opt = None
    if opts_hi and 0 <= ans < len(opts_hi):
        target_opt = opts_hi[ans]
    elif opts_en and 0 <= ans < len(opts_en):
        target_opt = opts_en[ans]
        
    if not target_opt or not target_opt.strip():
        empty_ans.append((qid, src, sec, ans, opts_hi, opts_en, stem_summary))
        
    if len(opts_hi) == 4:
        non_empty = [o.strip() for o in opts_hi if o.strip()]
        if len(set(non_empty)) < len(non_empty) and len(non_empty) > 1:
            duplicates.append((qid, src, sec, non_empty, stem_summary))

print(f"=== EMPTY ANSWER OPTION TEXT ({len(empty_ans)}) ===")
for item in empty_ans:
    print(f"QID: {item[0]} | Src: {item[1]} | Sec: {item[2]} | AnsIdx: {item[3]}")
    print(f"  QStem: {item[6]}")
    print(f"  OptsHi: {item[4]}")
    print(f"  OptsEn: {item[5]}")
    print()

print(f"\n=== DUPLICATE OPTIONS ({len(duplicates)}) ===")
for item in duplicates:
    print(f"QID: {item[0]} | Src: {item[1]} | Sec: {item[2]}")
    print(f"  QStem: {item[4]}")
    print(f"  Opts: {item[3]}")
    print()

conn.close()

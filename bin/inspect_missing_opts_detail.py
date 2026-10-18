import sys
import sqlite3
import json
from collections import Counter

sys.stdout.reconfigure(encoding='utf-8')

conn = sqlite3.connect('assets/database/tet_mock_vault.db')
c = conn.cursor()
c.execute('SELECT id, exams, section, source_tag, options_hindi, options_english FROM questions')
rows = c.fetchall()

missing_opts = []
for qid, exams, sec, src, opt_hi_str, opt_en_str in rows:
    opts_hi = json.loads(opt_hi_str) if opt_hi_str else []
    opts_en = json.loads(opt_en_str) if opt_en_str else []
    
    hi_count = len([o for o in opts_hi if o.strip()])
    en_count = len([o for o in opts_en if o.strip()])
    
    if hi_count < 4 or en_count < 4:
        missing_opts.append((qid, exams, sec, src, hi_count, en_count, opts_hi, opts_en))

print(f"Total questions with < 4 non-empty options: {len(missing_opts)}")

src_counter = Counter([item[3] for item in missing_opts])
print("\nBreakdown by source:")
for s, cnt in src_counter.most_common():
    print(f"  {s}: {cnt}")

print("\nSample questions with missing options:")
for item in missing_opts[:8]:
    qid, exams, sec, src, hi_c, en_c, opts_hi, opts_en = item
    print(f"ID: {qid} | Src: {src} | Sec: {sec} | HiCount: {hi_c} | EnCount: {en_c}")
    print(f"  OptsHi: {opts_hi}")
    print(f"  OptsEn: {opts_en}")
    print()

conn.close()

# -*- coding: utf-8 -*-
"""मौजूदा bank.db के 300 प्रश्न → CSV (सिर्फ़ एक बार चलाना है)"""
import sqlite3,json,csv,os
R="/home/user/qbank-repo/content"; os.makedirs(R,exist_ok=True)
con=sqlite3.connect("/home/user/bank/bank.db"); con.row_factory=sqlite3.Row

with open(f"{R}/passages.csv","w",newline="",encoding="utf-8") as f:
    w=csv.writer(f); w.writerow(["pid","kind","lang","dir_text","body"])
    for p in con.execute("SELECT * FROM passage"):
        w.writerow([f"P{p['id']:03d}",p["kind"],p["lang"],p["dir_text"],p["body"]])

COLS=["exams","section","topic","difficulty","pid","pseq",
      "q_hi","a_hi","b_hi","c_hi","d_hi","q_en","a_en","b_en","c_en","d_en","ans","source"]
buckets={}
for q in con.execute("SELECT * FROM q ORDER BY section,topic,id"):
    oh=json.loads(q["o_hi"]); oe=json.loads(q["o_en"] or "[]") or ["","","",""]
    buckets.setdefault(q["section"],[]).append([
        q["exams"],q["section"],q["topic"],q["difficulty"],
        f"P{q['passage_id']:03d}" if q["passage_id"] else "", q["seq_in_passage"] or "",
        q["q_hi"],*oh, q["q_en"] or "",*oe, q["ans"], q["source"]])
for sec,rs in buckets.items():
    with open(f"{R}/q_{sec}.csv","w",newline="",encoding="utf-8") as f:
        w=csv.writer(f); w.writerow(COLS); w.writerows(rs)
    print(f"   content/q_{sec}.csv  →  {len(rs)} प्रश्न")
con.close()

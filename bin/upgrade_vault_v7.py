import sqlite3
import json
import re
import sys

sys.stdout.reconfigure(encoding='utf-8')

DB_PATH = 'assets/database/tet_mock_vault.db'

def clean_stem(text):
    if not text:
        return text
    # Clean Assertion / Reason headers with asterisks
    t = re.sub(r'\*\*\s*(अभिकथन|दावा|Assertion)(?:\s*\(([A-Za-z0-9]+)\))?\s*[:\-–—ः.]?\s*\*\*', r'\1 (\2): ', text, flags=re.I)
    t = re.sub(r'(अभिकथन|दावा|Assertion)(?:\s*\(([A-Za-z0-9]+)\))?\s*[:\-–—ः.]?\s*\*\*', r'\1 (\2): ', t, flags=re.I)
    t = re.sub(r'\*\*\s*(कारण|तर्क|Reason)(?:\s*\(([A-Za-z0-9]+)\))?\s*[:\-–—ः.]?\s*\*\*', r'\1 (\2): ', t, flags=re.I)
    t = re.sub(r'(कारण|तर्क|Reason)(?:\s*\(([A-Za-z0-9]+)\))?\s*[:\-–—ः.]?\s*\*\*', r'\1 (\2): ', t, flags=re.I)
    t = re.sub(r'\*\*\s*(कथन|Statement)(?:\s*[-–—]?\s*(?:1|2|I|II|[A-Za-z0-9]))?\s*[:\-–—ः.]?\s*\*\*', r'\1: ', t, flags=re.I)
    t = re.sub(r'(कथन|Statement)(?:\s*[-–—]?\s*(?:1|2|I|II|[A-Za-z0-9]))?\s*[:\-–—ः.]?\s*\*\*', r'\1: ', t, flags=re.I)
    
    # Strip any remaining markdown bold asterisks
    t = t.replace('**', '')
    # Normalize spaces
    t = re.sub(r'[ \t]+', ' ', t)
    return t.strip()

def clean_opt(opt, fallback_opt=''):
    if not opt:
        return fallback_opt
    t = opt.strip()
    # Strip trailing poem/table tags like **Poem: जीवन अस्थिर**
    t = re.split(r'\s*\*{1,2}(?:Poem|Table|Passage|Directions?):[^*]+\*{1,2}', t, flags=re.I)[0]
    t = t.replace('**', '').replace('*', '').strip()
    if not t and fallback_opt:
        t = fallback_opt.replace('**', '').replace('*', '').strip()
    return t

def main():
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    
    print("Upgrading database to v7...")
    c.execute("SELECT id, q_hindi, q_english, options_hindi, options_english FROM questions")
    rows = c.fetchall()
    print(f"Total rows to process: {len(rows)}")
    
    updated = 0
    for qid, qh, qe, oh_json, oe_json in rows:
        new_qh = clean_stem(qh)
        new_qe = clean_stem(qe)
        
        oh_list = json.loads(oh_json) if (oh_json and oh_json != 'null') else []
        oe_list = json.loads(oe_json) if (oe_json and oe_json != 'null') else []
        
        new_oh = []
        for i, opt in enumerate(oh_list):
            fb = oe_list[i] if (oe_list and i < len(oe_list)) else ''
            new_oh.append(clean_opt(opt, fb))
            
        new_oe = []
        for i, opt in enumerate(oe_list):
            fb = new_oh[i] if (new_oh and i < len(new_oh)) else ''
            new_oe.append(clean_opt(opt, fb))
            
        # Specific recovery for ctet-p1-2020-pyq_q040 option D (18 km / 18 किमी)
        if qid == 'ctet-p1-2020-pyq_q040':
            new_oh[3] = '18 किमी'
            new_oe[3] = '18 km'
            
        new_oh_json = json.dumps(new_oh, ensure_ascii=False)
        new_oe_json = json.dumps(new_oe, ensure_ascii=False) if oe_list else None
        
        if (new_qh != qh or new_qe != qe or new_oh_json != oh_json or new_oe_json != oe_json):
            c.execute("""
                UPDATE questions 
                SET q_hindi = ?, q_english = ?, options_hindi = ?, options_english = ?
                WHERE id = ?
            """, (new_qh, new_qe, new_oh_json, new_oe_json, qid))
            updated += 1
            
    conn.commit()
    print(f"Updated {updated} questions with clean stems and clean options.")
    
    # Update meta bank_version to v7
    c.execute("UPDATE meta SET val = '20261018_master_vault_clean_v7' WHERE key = 'bank_version'")
    conn.commit()
    print("Meta bank_version updated to '20261018_master_vault_clean_v7'")
    
    # Verification
    c.execute("SELECT count(*) FROM questions WHERE q_hindi LIKE '%**%' OR q_english LIKE '%**%'")
    stars_stems = c.fetchone()[0]
    c.execute("SELECT count(*) FROM questions WHERE options_hindi LIKE '%**%' OR options_english LIKE '%**%'")
    stars_opts = c.fetchone()[0]
    print(f"Verification: Stems with ** = {stars_stems}, Options with ** = {stars_opts}")
    
    conn.close()

if __name__ == '__main__':
    main()

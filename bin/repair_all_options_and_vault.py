import sqlite3
import json
import re
import sys

sys.stdout.reconfigure(encoding='utf-8')

DB_PATH = 'assets/database/tet_mock_vault.db'

def restore_statement_ref(opt):
    if not opt: return opt
    t = opt.strip()
    # If starts with 'और (B)' or 'और (b)' or 'और (C)'
    if re.match(r'^(?:और|तथा)\s*\(([B-Db-d])\)', t):
        t = f"(A) {t}"
    # If starts with ', (B)' or ', (C)'
    elif re.match(r'^,\s*\(([B-Db-d])\)', t):
        t = f"(A){t}"
    # If starts with 'सही है' or 'गलत है' or 'सत्य है' or 'असत्य है' followed by (B) or (R)
    elif re.match(r'^(?:सही|गलत|सत्य|असत्य)\s+है\s+(?:परन्तु|लेकिन|किन्तु|तथा|और)\s*\(([BRbr])\)', t):
        t = f"(A) {t}"
    # English: 'is correct/wrong/true/false but/and (B)'
    elif re.match(r'^(?:is|are)\s+(?:correct|wrong|true|false|right|incorrect)\b', t, re.I):
        t = f"(A) {t}"
    # English: 'and (B) both are'
    elif re.match(r'^and\s*\(([B-Db-d])\)\s+both\b', t, re.I):
        t = f"(A) {t}"
    return t

def main():
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    
    print("Repairing statement options across vault...")
    c.execute("SELECT id, options_hindi, options_english FROM questions")
    rows = c.fetchall()
    
    fixed = 0
    for qid, oh_json, oe_json in rows:
        oh_list = json.loads(oh_json) if (oh_json and oh_json != 'null') else []
        oe_list = json.loads(oe_json) if (oe_json and oe_json != 'null') else []
        
        new_oh = [restore_statement_ref(o) for o in oh_list]
        new_oe = [restore_statement_ref(o) for o in oe_list]
        
        # Specific fix for ctet-p1-2024-pyq_q068 (Beehives)
        if qid == 'ctet-p1-2024-pyq_q068':
            new_oh = ['(a) और (b)', '(c) और (d)', '(a) और (c)', '(a) और (d)']
            new_oe = ['(a) and (b)', '(c) and (d)', '(a) and (c)', '(a) and (d)']
            
        new_oh_json = json.dumps(new_oh, ensure_ascii=False)
        new_oe_json = json.dumps(new_oe, ensure_ascii=False) if oe_list else None
        
        if new_oh_json != oh_json or new_oe_json != oe_json:
            c.execute("UPDATE questions SET options_hindi = ?, options_english = ? WHERE id = ?", (new_oh_json, new_oe_json, qid))
            fixed += 1
            
    conn.commit()
    print(f"Fixed {fixed} questions with restored statement options.")
    
    # Ensure bank_version is v7
    c.execute("UPDATE meta SET val = '20261018_master_vault_clean_v7' WHERE key = 'bank_version'")
    conn.commit()
    print("Meta bank_version verified as '20261018_master_vault_clean_v7'")
    
    conn.close()

if __name__ == '__main__':
    main()

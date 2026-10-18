import sqlite3, json

conn = sqlite3.connect('assets/database/tet_mock_vault.db')
c = conn.cursor()
c.execute("SELECT id, q_hindi, q_english, options_hindi, options_english, source_tag FROM questions WHERE id='dfdec27033a5e7e0'")
r = c.fetchone()
with open('bin/dfdec_q.json', 'w', encoding='utf-8') as f:
    json.dump({
        'id': r[0],
        'q_hi': r[1],
        'q_en': r[2],
        'opt_hi': json.loads(r[3]) if r[3] else None,
        'opt_en': json.loads(r[4]) if r[4] else None,
        'source': r[5]
    }, f, ensure_ascii=False, indent=2)
conn.close()
print("Dumped dfdec_q.json")

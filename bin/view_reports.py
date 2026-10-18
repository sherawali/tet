import sqlite3
import os
import sys

def view_reports(db_path='assets/database/tet_mock_vault.db'):
    # Check if reports table exists
    if not os.path.exists(db_path):
        print(f"Error: Database not found at {db_path}")
        return

    conn = sqlite3.connect(db_path)
    cur = conn.cursor()

    # Check if question_reports table exists
    cur.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='question_reports'")
    if not cur.fetchone():
        print("No 'question_reports' table found in database yet.")
        conn.close()
        return

    cur.execute("""
        SELECT r.id, r.question_number, r.paper_form_id, r.reason, r.comment, r.created_at,
               q.q_hindi, q.q_english
        FROM question_reports r
        LEFT JOIN questions q ON r.question_id = q.id
        ORDER BY r.id DESC
    """)
    reports = cur.fetchall()

    if not reports:
        print("No student reports submitted yet.")
        conn.close()
        return

    print("=" * 80)
    print(f"STUDENT ERROR REPORTS ({len(reports)} total)")
    print("=" * 80)

    os.makedirs('reports', exist_ok=True)
    md_lines = ["# 🚩 Student Question Error Reports\n\n"]

    for rep in reports:
        rid, qnum, paper, reason, comment, created, qhi, qen = rep
        stem = (qhi or qen or 'N/A').strip()[:120]
        print(f"[{rid}] Q{qnum} ({paper}) - Reason: {reason}")
        if comment:
            print(f"    Comment: {comment}")
        print(f"    Stem: {stem}...")
        print(f"    Time: {created}")
        print("-" * 80)

        md_lines.append(f"### [Report #{rid}] Question {qnum} ({paper})\n")
        md_lines.append(f"- **Reason:** {reason}\n")
        if comment:
            md_lines.append(f"- **Comment:** {comment}\n")
        md_lines.append(f"- **Date:** {created}\n")
        md_lines.append(f"- **Stem:** {stem}\n\n---\n")

    with open('reports/reported_questions.md', 'w', encoding='utf-8') as f:
        f.writelines(md_lines)
    print("Saved report summary to reports/reported_questions.md")
    conn.close()

if __name__ == '__main__':
    db = sys.argv[1] if len(sys.argv) > 1 else 'assets/database/tet_mock_vault.db'
    view_reports(db)

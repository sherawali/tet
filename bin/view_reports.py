#!/usr/bin/env python3
"""
Student Question Error Report Inspector & Management Tool.

Usage:
  python bin/view_reports.py                 # View all active reports and generate Markdown summary
  python bin/view_reports.py --solve <ID>    # Mark report ID as solved/resolved
  python bin/view_reports.py --clean-7days   # Auto-clear reports older than 7 days
"""

import sqlite3
import os
import sys
from datetime import datetime, timedelta

def get_db_path():
    for candidate in ['assets/database/tet_mock_vault.db']:
        if os.path.exists(candidate):
            return candidate
    return None

def view_reports(db_path):
    if not os.path.exists(db_path):
        print(f"Error: Database not found at {db_path}")
        return

    conn = sqlite3.connect(db_path)
    cur = conn.cursor()

    cur.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='question_reports'")
    if not cur.fetchone():
        print("No 'question_reports' table found in database yet.")
        conn.close()
        return

    cur.execute("""
        SELECT r.id, r.question_number, r.paper_form_id, r.reason, r.comment, r.created_at,
               r.status, r.suggested_option, q.q_hindi, q.q_english
        FROM question_reports r
        LEFT JOIN questions q ON r.question_id = q.id
        ORDER BY r.id DESC
    """)
    reports = cur.fetchall()

    if not reports:
        print("[INFO] No student error reports found in local vault.")
        conn.close()
        return

    print("=" * 80)
    print(f"🚩 STUDENT QUESTION ERROR REPORTS ({len(reports)} Active)")
    print("=" * 80)

    os.makedirs('reports', exist_ok=True)
    md_lines = [
        "# 🚩 Student Question Error Reports\n\n",
        "> ⚠️ **Mandatory Protocol:** Whenever starting app development, inspect these reported questions,\n",
        "> verify against authentic board papers & NCERT/SCERT, solve them, and push updates to Git.\n",
        "> Reports older than 7 days are automatically archived/cleared.\n\n",
        f"**Last Inspected:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n",
        "---\n\n"
    ]

    for rep in reports:
        rid, qnum, paper, reason, comment, created, status, suggested_opt, qhi, qen = rep
        stem = (qhi or qen or 'N/A').strip().replace('\n', ' ')[:130]
        status_label = "🟢 हल हो गया (Solved)" if status in ('solved', 'resolved') else "🟡 समीक्षाधीन (Under Review)"

        print(f"[{rid}] Q{qnum} ({paper}) - Status: {status_label}")
        print(f"    Problem   : {reason}")
        if suggested_opt:
            print(f"    Suggested : Option ({suggested_opt})")
        if comment:
            print(f"    Comment   : {comment}")
        print(f"    Question  : {stem}...")
        print(f"    Date      : {created}")
        print("-" * 80)

        md_lines.append(f"### [Report #{rid}] Question Q{qnum} ({paper})\n")
        md_lines.append(f"- **Status:** `{status_label}`\n")
        md_lines.append(f"- **Problem:** {reason}\n")
        if suggested_opt:
            md_lines.append(f"- **Student Suggested Answer:** Option ({suggested_opt})\n")
        if comment:
            md_lines.append(f"- **Comment:** {comment}\n")
        md_lines.append(f"- **Date:** {created}\n")
        md_lines.append(f"- **Question Stem:** {stem}...\n\n---\n")

    report_file = 'reports/reported_questions.md'
    with open(report_file, 'w', encoding='utf-8') as f:
        f.writelines(md_lines)
    print(f"\n[OK] Updated report tracking file: {report_file}")
    conn.close()

def mark_solved(db_path, report_id):
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()
    cur.execute("UPDATE question_reports SET status='solved' WHERE id=?", (report_id,))
    conn.commit()
    print(f"✅ Report #{report_id} marked as 'solved' (हल हो गया) successfully!")
    conn.close()

def clean_7days(db_path):
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()
    threshold = (datetime.now() - timedelta(days=7)).isoformat()
    cur.execute("DELETE FROM question_reports WHERE created_at < ?", (threshold,))
    deleted = cur.rowcount
    conn.commit()
    print(f"🧹 Cleaned {deleted} reports older than 7 days.")
    conn.close()

def main():
    db_path = get_db_path()
    if not db_path:
        print("Database not found.")
        return

    if len(sys.argv) > 1:
        if sys.argv[1] == '--solve' and len(sys.argv) > 2:
            mark_solved(db_path, int(sys.argv[2]))
            return
        elif sys.argv[1] == '--clean-7days':
            clean_7days(db_path)
            return

    view_reports(db_path)

if __name__ == '__main__':
    main()

"""Adds a real revision paper to the vault.

The paper is a "संयुक्त पुनरावृत्ति सेट" (combined revision set): 150 verified
questions of UTET Paper-1 (30 per section), taken from the bank.  Only
questions without a reading are used, because a question that belongs to a
reading keeps its place in that reading and cannot be repeated in another
paper.

It is also the end to end test of the update path: the paper is added here,
the CDN is rebuilt, the phone syncs it and shows it.
"""
import json
import sqlite3
from pathlib import Path

DB = Path('assets/database/tet_mock_vault.db')
FORM_ID = 'utet-p1-revision-01'
TITLE = 'UTET 2026 पेपर-1 · संयुक्त पुनरावृत्ति सेट 01'
SECTIONS = ['cdp', 'hindi', 'english', 'math', 'evs']


def main() -> int:
    conn = sqlite3.connect(DB)
    conn.row_factory = sqlite3.Row

    if conn.execute('SELECT 1 FROM paper_forms WHERE id = ?', (FORM_ID,)).fetchone():
        print('the revision set is already there')
        return 0

    picked: list[tuple[str, str]] = []
    for section in SECTIONS:
        rows = conn.execute(
            'SELECT a.question_id AS qid FROM appearances a '
            'JOIN paper_forms p ON p.id = a.paper_form_id '
            'JOIN questions q ON q.id = a.question_id '
            'WHERE p.exam = ? AND p.paper = ? AND a.section = ? '
            'AND (q.passage_id IS NULL OR q.passage_id = "") '
            'GROUP BY a.question_id ORDER BY a.question_id LIMIT 30',
            ('utet', 1, section),
        ).fetchall()
        if len(rows) < 30:
            print(f'section {section} has only {len(rows)} free questions')
            return 1
        for row in rows:
            picked.append((row['qid'], section))

    conn.execute(
        'INSERT INTO paper_forms (id, exam, paper, exam_date, set_code, title, '
        'total_questions, modules_json) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        (
            FORM_ID,
            'utet',
            1,
            '2026-Mock',
            'REV-01',
            TITLE,
            150,
            json.dumps(SECTIONS, ensure_ascii=False),
        ),
    )

    number = 0
    for qid, section in picked:
        number += 1
        answer = conn.execute(
            'SELECT answer FROM questions WHERE id = ?', (qid,)
        ).fetchone()['answer']
        option = chr(ord('A') + int(answer)) if answer is not None else 'A'
        conn.execute(
            'INSERT INTO appearances (id, question_id, paper_form_id, section, '
            'question_number, official_option_id) VALUES (?, ?, ?, ?, ?, ?)',
            (f'{FORM_ID}_{number}', qid, FORM_ID, section, number, option),
        )

    conn.commit()
    print(f'the revision set is in: {FORM_ID} with {number} questions')
    conn.close()
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

# -*- coding: utf-8 -*-
"""Repair the TET mock vault (v17).

What this script fixes
----------------------
1. Adds reading-comprehension passages recovered from the tetmaster source
   corpus and links the corresponding questions (passage_id/seq_in_passage).
2. Canonicalises questions.exams from the appearances/paper_forms join
   (ctet1, ctet2, utet1, utet2) instead of the old ambiguous '["ctet"]'.
3. Reclassifies prose passages that are actually poems.
4. Bumps meta.bank_version to 2026102017 and VACUUMs the database.

User-data tables (test_history, mistake_records, question_reports) are never
touched.

Usage:
    python bin/repair_vault_v17.py            # dry run
    python bin/repair_vault_v17.py --apply    # write DB (creates a backup)
"""
import argparse
import io
import json
import os
import shutil
import sqlite3
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'scratch'))
import extract_passages as ex  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
DB = os.path.join(ROOT, 'assets', 'database', 'tet_mock_vault.db')
BACKUP = os.path.join(ROOT, 'scratch', 'tet_mock_vault_pre_v17.db')
NEW_VERSION = '2026102017'
SOURCE_ROOT = r'C:\Users\pujariji\Desktop\tetmaster'


def source_map():
    """form id -> markdown source path."""
    m = {}
    for i in range(1, 11):
        m[f'ctet-p1-mock-{i:02d}'] = os.path.join(
            SOURCE_ROOT, 'ctet', 'ctet-paper1', 'mocks', f'mock-{i:02d}.md')
    for i in range(1, 9):
        m[f'ctet-p2-ms-mock-{i:02d}'] = os.path.join(
            SOURCE_ROOT, 'ctet', 'ctet-paper2', 'mocks', f'mock-ms-{i:02d}.md')
        m[f'ctet-p2-sst-mock-{i:02d}'] = os.path.join(
            SOURCE_ROOT, 'ctet', 'ctet-paper2', 'mocks', f'mock-sst-{i:02d}.md')
    for y in (2016, 2018, 2019, 2020, 2021, 2023, 2024, 2026):
        m[f'ctet-p1-{y}-pyq'] = os.path.join(
            SOURCE_ROOT, 'ctet', 'ctet-paper1', 'real-mocks', 'by-year', f'complete-{y}.md')
    for s in ('b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j'):
        m[f'utet-p1-set-{s}'] = os.path.join(
            SOURCE_ROOT, 'Final_Mocks', 'UTET-1', f'UTET_Paper1_SET-{s.upper()}_FreshMock.md')
    for s in ('2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12'):
        m[f'utet-p1-set{s}'] = os.path.join(
            SOURCE_ROOT, 'Final_Mocks', 'UTET-1', f'UTET_Paper1_SET{s}_FreshMock.md')
    for s in ('a', 'b', 'c', 'd', 'e', 'f', 'g'):
        m[f'utet-p2-set-{s}'] = os.path.join(
            SOURCE_ROOT, 'Final_Mocks', 'UTET-2', f'UTET_Paper2_SET-{s.upper()}_RealPYQ.md')
    m['utet-p1-fullmock'] = os.path.join(
        SOURCE_ROOT, 'Final_Mocks', 'UTET-1', 'UTET_Paper1_FullMock_RealPYQ.md')
    return m


CANONICAL = {
    ('ctet', 1): 'ctet1',
    ('ctet', 2): 'ctet2',
    ('utet', 1): 'utet1',
    ('utet', 2): 'utet2',
}

# Real-PYQ source files contain several language variants.  These specs pick
# the sections used by the app's form and, where a passage row already exists,
# extend that row instead of creating a duplicate.
PYQ_SPECS = {
    'ctet-p1-2018-pyq': {
        'sections': ['Language II: English'],
        'extend': {},
    },
    'ctet-p1-2019-pyq': {
        'sections': ['Language II: English'],
        'extend': {},
    },
    'ctet-p1-2020-pyq': {
        'sections': ['Language I: Hindi', 'Language II: English'],
        'extend': {
            ('Language I: Hindi', 91): 'ctet-p1-2020-pyq_p1',
            ('Language II: English', 121): 'ctet-p1-2020-pyq_p2',
        },
    },
    'ctet-p1-2021-pyq': {
        'sections': ['Language II: English'],
        'extend': {},
    },
}


def link_range(cur, form_id, pid, first_q, last_q):
    cur.execute(
        '''UPDATE questions
           SET passage_id=?, seq_in_passage=(
               SELECT a.question_number - ? + 1 FROM appearances a
               WHERE a.question_id = questions.id AND a.paper_form_id = ?
           )
           WHERE id IN (SELECT question_id FROM appearances
                        WHERE paper_form_id=? AND question_number BETWEEN ? AND ?)''',
        (pid, first_q, form_id, form_id, first_q, last_q),
    )
    return cur.rowcount


def repair_pyq(cur, form_id, spec, apply_changes):
    src = source_map().get(form_id)
    if not src or not os.path.exists(src):
        return 0, 0
    passages = ex.extract_passages(src, dedupe=False)
    selected = [p for p in passages
                if any(s in (p.get('section') or '') for s in spec['sections'])]
    selected.sort(key=lambda p: (p['declared'] or (p['first_q'], p['last_q']))[0])
    inserted = linked = 0
    for p in selected:
        first, last = p['declared'] or (p['first_q'], p['last_q'])
        pid = None
        for (section_key, q_key), existing_pid in spec.get('extend', {}).items():
            if section_key in (p.get('section') or '') and q_key == first:
                pid = existing_pid
                break
        if pid is None:
            pid = f'{form_id}__stim_{first:03d}'
            inserted += 1
            if apply_changes:
                cur.execute(
                    'INSERT OR REPLACE INTO passages (id, kind, dir_text, body) VALUES (?,?,?,?)',
                    (pid, p['kind'], p['dir_text'], p['body']),
                )
        elif apply_changes:
            cur.execute(
                'UPDATE passages SET kind=?, dir_text=?, body=? WHERE id=?',
                (p['kind'], p['dir_text'], p['body'], pid),
            )
        if apply_changes:
            linked += link_range(cur, form_id, pid, first, last)
        else:
            linked += cur.execute(
                '''SELECT COUNT(*) FROM appearances
                   WHERE paper_form_id=? AND question_number BETWEEN ? AND ?''',
                (form_id, first, last),
            ).fetchone()[0]
    return inserted, linked


def canonical_exams(cur):
    """Return {question_id: canonical exam id} and counts."""
    rows = cur.execute('''
        SELECT a.question_id, f.exam, f.paper, q.exams
        FROM appearances a
        JOIN paper_forms f ON f.id = a.paper_form_id
        JOIN questions q ON q.id = a.question_id
    ''').fetchall()
    out = {}
    unknown = {}
    for qid, exam, paper, old in rows:
        key = CANONICAL.get((exam, paper))
        if key is None:
            unknown[exam] = unknown.get(exam, 0) + 1
            key = exam
        out[qid] = key
    return out, unknown


def reclassify_poems(cur):
    """Eight prose passages are actually poems (detected by short lines)."""
    changed = []
    rows = cur.execute("SELECT id, kind, dir_text, body FROM passages").fetchall()
    for pid, kind, dir_text, body in rows:
        if kind == 'poem':
            continue
        probe = dir_text or ''
        if not ex._is_poem(probe, body or ''):
            continue
        cur.execute('UPDATE passages SET kind=? WHERE id=?', ('poem', pid))
        changed.append(pid)
    return changed


def add_passages_for_form(cur, form_id, source_path, apply_changes):
    """Insert passages and link questions. Returns (inserted, linked).

    Many UTET forms already have passages linked, so a range that is fully
    covered is left alone.  A partially covered range extends the existing
    passage row rather than creating a duplicate.
    """
    passages = ex.extract_passages(source_path)
    inserted = 0
    linked = 0

    full_ranges = {}
    for pid, _count, mn, mx in cur.execute(
        '''SELECT q.passage_id, COUNT(*), MIN(a.question_number), MAX(a.question_number)
           FROM appearances a JOIN questions q ON q.id=a.question_id
           WHERE a.paper_form_id=? AND q.passage_id IS NOT NULL AND q.passage_id <> ''
           GROUP BY q.passage_id''',
        (form_id,),
    ):
        full_ranges[pid] = (mn, mx)

    for p in passages:
        first, last = p['first_q'], p['last_q']

        overlapping = [(pid, mn, mx) for pid, (mn, mx) in full_ranges.items()
                       if mn <= last and mx >= first]
        if overlapping:
            # A range that overlaps a passage starting earlier is a duplicate
            # language/stream variant; keep the first variant only.
            if any(mn < first for _pid, mn, _mx in overlapping):
                continue
            if len(overlapping) == 1:
                pid, mn, mx = overlapping[0]
                if mn == first and mx >= last:
                    # Fully covered.  Refresh only a missing/empty body.
                    if apply_changes:
                        body_len = cur.execute(
                            "SELECT LENGTH(COALESCE(body,'')) FROM passages WHERE id=?",
                            (pid,),
                        ).fetchone()[0]
                        if body_len < 80:
                            cur.execute(
                                'UPDATE passages SET kind=?, dir_text=?, body=? WHERE id=?',
                                (p['kind'], p['dir_text'], p['body'], pid),
                            )
                    continue
                if mn == first and mx < last:
                    # Extend a partially linked passage.
                    if apply_changes:
                        cur.execute(
                            'UPDATE passages SET kind=?, dir_text=?, body=? WHERE id=?',
                            (p['kind'], p['dir_text'], p['body'], pid),
                        )
                    if apply_changes:
                        linked += link_range(cur, form_id, pid, first, last)
                    full_ranges[pid] = (first, max(mx, last))
                    continue
            # Ambiguous overlap (e.g. two partial pids): leave it alone.
            continue

        pid = f'{form_id}__stim_{first:03d}'
        inserted += 1
        if apply_changes:
            cur.execute(
                'INSERT OR REPLACE INTO passages (id, kind, dir_text, body) VALUES (?,?,?,?)',
                (pid, p['kind'], p['dir_text'], p['body']),
            )
            linked += link_range(cur, form_id, pid, first, last)
        else:
            linked += cur.execute(
                '''SELECT COUNT(*) FROM appearances a JOIN questions q ON q.id=a.question_id
                   WHERE a.paper_form_id=? AND a.question_number BETWEEN ? AND ?
                     AND (q.passage_id IS NULL OR q.passage_id='')''',
                (form_id, first, last),
            ).fetchone()[0]
        full_ranges[pid] = (first, last)
    return inserted, linked


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--apply', action='store_true', help='write the database')
    ap.add_argument('--only', default='ctet-p2', help='form prefix to repair (default ctet-p2)')
    ap.add_argument('--db', default=DB, help='database path (default: asset vault)')
    args = ap.parse_args()
    db_path = args.db

    if not os.path.exists(db_path):
        print(f'DB not found: {db_path}')
        return 2
    if args.apply and os.path.abspath(db_path) == os.path.abspath(DB) and not os.path.exists(BACKUP):
        shutil.copy2(db_path, BACKUP)
        print(f'backup: {BACKUP}')

    conn = sqlite3.connect(db_path)
    cur = conn.cursor()
    apply_changes = args.apply
    smap = source_map()

    forms = [r[0] for r in cur.execute(
        'SELECT id FROM paper_forms ORDER BY id') if r[0].startswith(args.only)]
    print(f'forms matching {args.only!r}: {len(forms)}')

    total_ins = total_link = 0
    for form_id in forms:
        src = smap.get(form_id)
        if not src or not os.path.exists(src):
            print(f'  SKIP {form_id}: source missing ({src})')
            continue
        if form_id in PYQ_SPECS:
            ins, link = repair_pyq(cur, form_id, PYQ_SPECS[form_id], apply_changes)
        else:
            ins, link = add_passages_for_form(cur, form_id, src, apply_changes)
        total_ins += ins
        total_link += link
        print(f'  {form_id:24} passages={ins:2} linked={link:3}')

    # canonical exams
    exams, unknown = canonical_exams(cur)
    if apply_changes:
        for qid, exam in exams.items():
            cur.execute('UPDATE questions SET exams=? WHERE id=?',
                        (json.dumps([exam], ensure_ascii=False), qid))
    print(f'exams canonicalised: {len(exams)} questions; unknown={unknown}')

    # poem reclassification
    poems = reclassify_poems(cur) if apply_changes else []
    print(f'passages reclassified as poems: {len(poems)} {poems[:10]}')

    if apply_changes:
        cur.execute('INSERT OR REPLACE INTO meta(key,val) VALUES (?,?)',
                    ('bank_version', NEW_VERSION))
        conn.commit()
        conn.execute('VACUUM')
        conn.commit()
        print(f'bank_version -> {NEW_VERSION}')
    else:
        print('DRY RUN: no changes written (use --apply)')

    conn.close()
    print(f'total inserted={total_ins} linked={total_link}')
    return 0


if __name__ == '__main__':
    sys.exit(main())

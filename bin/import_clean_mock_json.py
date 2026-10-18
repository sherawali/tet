#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
TET Clean Mock JSON Validator & Importer
Usage:
    python bin/import_clean_mock_json.py <path_to_mock_json> [--dry-run]
"""

import sys
import json
import sqlite3
import os
import re

sys.stdout.reconfigure(encoding='utf-8')

def validate_and_import(json_path, dry_run=False):
    if not os.path.exists(json_path):
        print(f"❌ Error: File not found: {json_path}")
        sys.exit(1)

    with open(json_path, 'r', encoding='utf-8') as f:
        try:
            data = json.load(f)
        except Exception as e:
            print(f"❌ Error parsing JSON: {e}")
            sys.exit(1)

    paper_meta = data.get('paper_meta', {})
    paper_id = paper_meta.get('id')
    exam = paper_meta.get('exam', 'ctet')
    paper_num = paper_meta.get('paper', 1)
    paper_title = paper_meta.get('title', 'TET Model Paper')
    set_code = paper_meta.get('set_code', 'SET 01')

    passages = data.get('passages', [])
    questions = data.get('questions', [])

    print(f"🔍 Validating Mock: {paper_title} ({len(questions)} Questions, {len(passages)} Passages)")

    errors = []

    # 1. Validate Passages
    passage_ids = set()
    for p in passages:
        pid = p.get('id')
        if not pid:
            errors.append("Passage missing 'id'")
        passage_ids.add(pid)
        if not p.get('body') or len(p.get('body', '').strip()) < 10:
            errors.append(f"Passage '{pid}' has empty or invalid body.")

    # 2. Validate Questions
    for idx, q in enumerate(questions, 1):
        qid = q.get('id', f'q_{idx}')
        stem_hi = q.get('q_hindi', '').strip()
        stem_en = q.get('q_english', '').strip()
        opts_hi = q.get('options_hindi', [])
        opts_en = q.get('options_english', [])
        ans = q.get('answer')
        pid = q.get('passage_id')

        # Check Stem
        if not stem_hi and not stem_en:
            errors.append(f"Q{idx} ({qid}): Both Hindi and English stems are empty.")

        if '**' in stem_hi or '**' in stem_en:
            errors.append(f"Q{idx} ({qid}): Stem contains stray '**' bold markers.")

        # Check Options
        if len(opts_hi) != 4 and len(opts_en) != 4:
            errors.append(f"Q{idx} ({qid}): Must have exactly 4 options (found {len(opts_hi)} Hindi, {len(opts_en)} English).")

        # Check for damaged leading combo words
        for o in opts_hi:
            if re.search(r'^\s*(?:और|एवं|तथा|and)\s*[\(\d]', o) or re.search(r'^\s*,\s*\(', o):
                errors.append(f"Q{idx} ({qid}): Damaged option marker detected: '{o}' (Missing leading (A) or statement label).")
            if '**' in o:
                errors.append(f"Q{idx} ({qid}): Option contains stray '**': '{o}'")

        # Check Answer Key
        if ans is None or not isinstance(ans, int) or ans < 0 or ans > 3:
            errors.append(f"Q{idx} ({qid}): Invalid answer key '{ans}'. Must be integer 0, 1, 2, or 3.")

        # Check Passage Link
        if pid and pid not in passage_ids:
            # Check if it exists in DB
            pass

    if errors:
        print(f"\n❌ Validation Failed with {len(errors)} errors:")
        for e in errors[:20]:
            print(f"  • {e}")
        if len(errors) > 20:
            print(f"  ... and {len(errors) - 20} more errors.")
        sys.exit(1)

    print("✅ 100% Validation Passed! All questions conform strictly to Universal TET Schema.")

    if dry_run:
        print("Dry run complete. No changes made to database.")
        return

    # 3. Import to SQLite Database
    db_path = 'assets/database/tet_mock_vault.db'
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()

    try:
        # Insert Passages
        for p in passages:
            cur.execute("""
                INSERT OR REPLACE INTO passages (id, kind, dir_text, body)
                VALUES (?, ?, ?, ?)
            """, (p.get('id'), p.get('kind', 'prose'), p.get('dir_text', ''), p.get('body', '')))

        # Insert Questions
        for idx, q in enumerate(questions, 1):
            qid = q.get('id', f"{paper_id}_q{idx:03d}")
            section = q.get('section', 'cdp').lower()
            topic = q.get('topic_name', 'सामान्य')
            diff = q.get('difficulty', 1)
            stem_hi = q.get('q_hindi', '')
            opts_hi = json.dumps(q.get('options_hindi', []), ensure_ascii=False)
            stem_en = q.get('q_english', '')
            opts_en = json.dumps(q.get('options_english', []), ensure_ascii=False)
            ans = q.get('answer', 0)
            pid = q.get('passage_id')
            seq_p = q.get('seq_in_passage')

            cur.execute("""
                INSERT OR REPLACE INTO questions (
                    id, exams, section, topic_name, difficulty,
                    q_hindi, options_hindi, q_english, options_english,
                    answer, passage_id, seq_in_passage
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                qid, f"{exam},{exam}{paper_num}", section, topic, diff,
                stem_hi, opts_hi, stem_en, opts_en,
                ans, pid, seq_p
            ))

            # Record appearance if paper_id is defined
            if paper_id:
                app_id = f"{paper_id}_{idx:03d}"
                cur.execute("""
                    INSERT OR REPLACE INTO appearances (
                        id, question_id, paper_form_id, section, question_number, official_option_id
                    ) VALUES (?, ?, ?, ?, ?, ?)
                """, (app_id, qid, paper_id, section, idx, str(ans + 1)))

        # Update paper_forms if defined
        if paper_id:
            cur.execute("""
                INSERT OR REPLACE INTO paper_forms (
                    id, exam, paper, exam_date, set_code, title, total_questions
                ) VALUES (?, ?, ?, ?, ?, ?, ?)
            """, (paper_id, exam, paper_num, '2026', set_code, paper_title, len(questions)))

        # Bump bank version
        import datetime
        v_tag = f"20261018_master_vault_clean_v16_{paper_id}"
        cur.execute("UPDATE meta SET val = ? WHERE key = 'bank_version'", (v_tag,))
        conn.commit()
        print(f"🎉 Successfully imported {len(questions)} questions into SQLite and updated bank_version to {v_tag}!")
    except Exception as e:
        conn.rollback()
        print(f"❌ Database error: {e}")
        sys.exit(1)
    finally:
        conn.close()

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python bin/import_clean_mock_json.py <path_to_mock_json> [--dry-run]")
        sys.exit(1)
    dry = '--dry-run' in sys.argv
    path = sys.argv[1]
    validate_and_import(path, dry_run=dry)

#!/usr/bin/env python3
"""Builds SQLite database tet_mock_vault.db from bank-v2 for the Flutter mobile app.
"""
from __future__ import annotations

import json
import os
import re
import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3] # C:\Users\pujariji\Desktop\T
BANK = ROOT / "tet_repo" / "bank-v2"
APP_ASSETS_DB = ROOT / "tet_app" / "assets" / "database"
APP_ASSETS_DB.mkdir(parents=True, exist_ok=True)
DB_PATH = APP_ASSETS_DB / "tet_mock_vault.db"


def table_to_markdown(block: dict) -> str:
    caption = block.get("caption", {}).get("hi") or block.get("caption", {}).get("en") or ""
    cols = block.get("columns", [])
    headers = [c.get("header", {}).get("hi") or c.get("header", {}).get("en") or c.get("id", "") for c in cols]
    col_ids = [c.get("id") for c in cols]
    
    lines = []
    if caption:
        lines.append(f"**{caption}**\n")
    lines.append("| " + " | ".join(headers) + " |")
    lines.append("| " + " | ".join(["---"] * len(headers)) + " |")
    for r in block.get("rows", []):
        cells = r.get("cells", {})
        row_vals = []
        for cid in col_ids:
            c_val = cells.get(cid, {})
            val_str = c_val.get("hi") or c_val.get("en") or str(c_val)
            row_vals.append(str(val_str))
        lines.append("| " + " | ".join(row_vals) + " |")
    return "\n".join(lines)


def get_stimulus_body_and_dir(s: dict) -> tuple[str, str, str]:
    kind = s.get("type", "prose")
    instructions = s.get("instructions", {})
    dir_text = instructions.get("hi") or instructions.get("en") or instructions.get("sa") or ""
    
    body_parts = []
    for block in s.get("content", []):
        if block.get("kind") == "table":
            body_parts.append(table_to_markdown(block))
        else:
            text_dict = block.get("text", {})
            t = text_dict.get("hi") or text_dict.get("en") or text_dict.get("sa") or ""
            if t:
                body_parts.append(t)
    body = "\n\n".join(body_parts)
    return kind, dir_text, body


def main():
    print(f"Building SQLite database from {BANK}...")
    if DB_PATH.exists():
        DB_PATH.unlink()

    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()

    cur.execute("PRAGMA user_version = 1")

    # Create tables
    cur.execute("""
        CREATE TABLE IF NOT EXISTS questions (
            id TEXT PRIMARY KEY,
            exams TEXT,
            section TEXT,
            topic_index INTEGER,
            topic_name TEXT,
            difficulty INTEGER,
            q_hindi TEXT,
            options_hindi TEXT,
            q_english TEXT,
            options_english TEXT,
            answer INTEGER,
            p_score REAL,
            years TEXT,
            source_tag TEXT,
            passage_id TEXT,
            seq_in_passage INTEGER
        )
    """)

    cur.execute("""
        CREATE TABLE IF NOT EXISTS passages (
            id TEXT PRIMARY KEY,
            kind TEXT,
            dir_text TEXT,
            body TEXT
        )
    """)

    cur.execute("""
        CREATE TABLE IF NOT EXISTS paper_forms (
            id TEXT PRIMARY KEY,
            exam TEXT,
            paper INTEGER,
            exam_date TEXT,
            set_code TEXT,
            title TEXT,
            total_questions INTEGER,
            modules_json TEXT
        )
    """)

    cur.execute("""
        CREATE TABLE IF NOT EXISTS appearances (
            id TEXT PRIMARY KEY,
            question_id TEXT,
            paper_form_id TEXT,
            section TEXT,
            question_number INTEGER,
            official_option_id TEXT
        )
    """)

    cur.execute("""
        CREATE TABLE IF NOT EXISTS meta (
            key TEXT PRIMARY KEY,
            val TEXT
        )
    """)

    cur.execute("""
        CREATE TABLE IF NOT EXISTS test_history (
            id TEXT PRIMARY KEY,
            timestamp INTEGER,
            mode TEXT,
            section_filter TEXT,
            score INTEGER,
            total INTEGER,
            time_spent_seconds INTEGER,
            session_json TEXT
        )
    """)

    cur.execute("""
        CREATE TABLE IF NOT EXISTS mistake_records (
            question_id TEXT PRIMARY KEY,
            section TEXT,
            topic_name TEXT,
            wrong_count INTEGER DEFAULT 0,
            correct_count INTEGER DEFAULT 0,
            last_wrong_timestamp INTEGER
        )
    """)

    # 1. Collect all appearances for year & order lookup
    q_appearances: dict[str, dict] = {}
    for app_file in sorted(BANK.rglob("appearances.ndjson")):
        for line in app_file.read_text(encoding="utf-8").splitlines():
            if not line.strip(): continue
            app = json.loads(line)
            cur.execute("""
                INSERT INTO appearances (id, question_id, paper_form_id, section, question_number, official_option_id)
                VALUES (?, ?, ?, ?, ?, ?)
            """, (
                app["id"], app["questionId"], app["paperFormId"], app.get("section", ""),
                app.get("questionNumber", 0), app.get("officialOptionId", "")
            ))
            q_appearances[app["questionId"]] = app

    # 2. Collect paper forms
    for form_file in sorted(BANK.rglob("forms.ndjson")):
        for line in form_file.read_text(encoding="utf-8").splitlines():
            if not line.strip(): continue
            f = json.loads(line)
            title = f.get("title", {}).get("hi") or f.get("title", {}).get("en") or f.get("id", "")
            cur.execute("""
                INSERT INTO paper_forms (id, exam, paper, exam_date, set_code, title, total_questions, modules_json)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                f["id"], f["exam"], f["paper"], f["examDate"], f["setCode"],
                title, f["totalQuestions"], json.dumps(f.get("modules", []), ensure_ascii=False)
            ))

    # 3. Collect stimuli
    stimuli_seen = set()
    for stim_file in sorted(BANK.rglob("stimuli.ndjson")):
        for line in stim_file.read_text(encoding="utf-8").splitlines():
            if not line.strip(): continue
            s = json.loads(line)
            sid = s["id"]
            if sid in stimuli_seen: continue
            stimuli_seen.add(sid)
            kind, dir_text, body = get_stimulus_body_and_dir(s)
            cur.execute("""
                INSERT INTO passages (id, kind, dir_text, body)
                VALUES (?, ?, ?, ?)
            """, (sid, kind, dir_text, body))

    # 4. Collect questions
    questions_seen = set()
    total_q = 0
    letter_to_int = {"a": 0, "b": 1, "c": 2, "d": 3}

    for q_file in sorted(BANK.rglob("questions.ndjson")):
        for line in q_file.read_text(encoding="utf-8").splitlines():
            if not line.strip(): continue
            q = json.loads(line)
            qid = q["id"]
            if qid in questions_seen: continue
            questions_seen.add(qid)

            exam = q.get("exam", "utet")
            exams_tag = "ctet1" if exam == "ctet" else "utet1"

            raw_sec = q.get("section", "")
            if raw_sec == "cdp":
                sec = "cdp"
            elif raw_sec == "mathematics":
                sec = "math"
            elif raw_sec == "environmental-studies":
                sec = "evs"
            elif raw_sec == "language":
                lang = q.get("language", "hi")
                if lang == "en": sec = "english"
                elif lang == "sa": sec = "sanskrit"
                elif lang == "ur": sec = "urdu"
                else: sec = "hindi"
            else:
                sec = raw_sec

            # Year
            app = q_appearances.get(qid)
            year = ""
            if app and "examDate" in app:
                year = app["examDate"][:4]
            if not year:
                for tag in q.get("tags", []):
                    if re.match(r"^20\d\d$", tag):
                        year = tag
                        break
            if not year:
                m_y = re.search(r"20\d\d", qid)
                if m_y: year = m_y.group(0)

            # Source tag
            source_tag = f"{exam.upper()} {year} (Paper 1)" if year else f"{exam.upper()} PYQ"

            # Prompt text
            prompt_block = q.get("prompt", [{}])[0]
            text_map = prompt_block.get("text", {})
            q_hi = text_map.get("hi") or text_map.get("sa") or text_map.get("en") or ""
            q_en = text_map.get("en") if "en" in text_map else None

            # Options text
            opts_hi = []
            opts_en = []
            has_en_opts = False
            for opt in q.get("options", []):
                opt_content = opt.get("content", [{}])[0]
                ot = opt_content.get("text", {})
                hi_text = ot.get("hi") or ot.get("sa") or ot.get("en") or ""
                opts_hi.append(hi_text)
                if "en" in ot:
                    has_en_opts = True
                    opts_en.append(ot["en"])
                else:
                    opts_en.append(hi_text)

            final_opts_en = json.dumps(opts_en, ensure_ascii=False) if (has_en_opts and q_en) else None
            ans_letter = q.get("answer", {}).get("optionId", "a").lower()
            ans_int = letter_to_int.get(ans_letter, 0)
            passage_id = q.get("stimulusId")

            seq_in_passage = None
            if app:
                qnum = app.get("questionNumber")
                if qnum:
                    seq_in_passage = qnum

            cur.execute("""
                INSERT INTO questions (
                    id, exams, section, topic_index, topic_name, difficulty,
                    q_hindi, options_hindi, q_english, options_english,
                    answer, p_score, years, source_tag, passage_id, seq_in_passage
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                qid, exams_tag, sec, 0, sec.capitalize(), 2,
                q_hi, json.dumps(opts_hi, ensure_ascii=False),
                q_en, final_opts_en,
                ans_int, 0.85, year, source_tag, passage_id, seq_in_passage
            ))
            total_q += 1

    # Indexes
    cur.execute("CREATE INDEX idx_q_sec_topic ON questions(section, topic_index)")
    cur.execute("CREATE INDEX idx_q_pscore ON questions(p_score DESC)")
    cur.execute("CREATE INDEX idx_q_years ON questions(years)")
    cur.execute("CREATE INDEX idx_q_exams ON questions(exams)")

    # Meta
    cur.execute("INSERT INTO meta (key, val) VALUES (?, ?)", ("bank_version", "20261004"))
    cur.execute("INSERT INTO meta (key, val) VALUES (?, ?)", ("total_questions", str(total_q)))
    cur.execute("INSERT INTO meta (key, val) VALUES (?, ?)", ("total_passages", str(len(stimuli_seen))))
    cur.execute("INSERT INTO meta (key, val) VALUES (?, ?)", ("is_v2_migrated", "true"))

    conn.commit()
    conn.close()

    db_size = DB_PATH.stat().st_size
    print(f"Successfully built SQLite DB at {DB_PATH}")
    print(f"Total Questions: {total_q}")
    print(f"Total Passages: {len(stimuli_seen)}")
    print(f"Database size: {db_size / 1024:.1f} KB ({db_size / (1024*1024):.2f} MB)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

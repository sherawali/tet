#!/usr/bin/env python3
"""Builds SQLite database tet_mock_vault.db from bank-v2 for the Flutter mobile app.
"""
from __future__ import annotations

import json
import os
import re
import sqlite3
import sys
import tempfile
from pathlib import Path

from build_config import BANK_VERSION
from text_sanitizer import (
    normalize_markdown_tables,
    sanitize_display_text,
    sanitize_option_text,
    sanitize_question_stem,
    sanitize_stimulus_text,
)

REPO_ROOT = Path(__file__).resolve().parents[2] # tet_repo
BANK = REPO_ROOT / "bank-v2"
WORKSPACE_ROOT = REPO_ROOT.parent # T if local
APP_ASSETS_DB = WORKSPACE_ROOT / "tet_app" / "assets" / "database"

if (WORKSPACE_ROOT / "tet_app").exists():
    APP_ASSETS_DB.mkdir(parents=True, exist_ok=True)
    DB_PATH = APP_ASSETS_DB / "tet_mock_vault.db"
else:
    RUNTIME_DIR = REPO_ROOT / "runtime"
    RUNTIME_DIR.mkdir(parents=True, exist_ok=True)
    DB_PATH = RUNTIME_DIR / "tet_mock_vault.db"

# Useful for isolated builds; the normal app/runtime target remains the default.
if os.environ.get("TET_DB_PATH"):
    DB_PATH = Path(os.environ["TET_DB_PATH"]).expanduser().resolve()
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)


def _localized_text(value: object, *locales: str) -> str:
    if isinstance(value, dict):
        for locale in locales:
            text = value.get(locale)
            if isinstance(text, str) and text:
                return text
        return ""
    return str(value) if value is not None else ""


def _clean_table_cell(value: object) -> str:
    text = sanitize_display_text(str(value) if value is not None else "")
    return text.replace("|", r"\|")


def table_to_markdown(block: dict) -> str:
    caption = sanitize_display_text(_localized_text(block.get("caption", {}), "hi", "en"))
    cols = block.get("columns", [])
    headers = [
        _clean_table_cell(_localized_text(c.get("header", {}), "hi", "en") or c.get("id", ""))
        for c in cols
    ]
    col_ids = [c.get("id") for c in cols]

    lines = []
    if caption:
        lines.append(caption)
    lines.append("| " + " | ".join(headers) + " |")
    lines.append("| " + " | ".join(["---"] * len(headers)) + " |")
    for row in block.get("rows", []):
        cells = row.get("cells", {})
        row_values = []
        for column_id in col_ids:
            cell = cells.get(column_id, {})
            row_values.append(_clean_table_cell(_localized_text(cell, "hi", "en") or cell))
        lines.append("| " + " | ".join(row_values) + " |")
    return normalize_markdown_tables("\n".join(lines))


def get_stimulus_body_and_dir(s: dict) -> tuple[str, str, str]:
    kind = s.get("type", "prose")
    instructions = s.get("instructions", {})
    dir_text = sanitize_display_text(_localized_text(instructions, "hi", "en", "sa"))

    body_parts = []
    for block in s.get("content", []):
        if block.get("kind") == "table":
            body_parts.append(table_to_markdown(block))
        else:
            text_dict = block.get("text", {})
            text = _localized_text(text_dict, "hi", "en", "sa")
            if text:
                body_parts.append(sanitize_stimulus_text(text))
    body = "\n\n".join(body_parts)
    return kind, dir_text, body


def classify_topic(sec: str, qh: str, qe: str | None, pid: str | None) -> str:
    if pid:
        return "अपठित पद्यांश" if "poem" in (pid or "").lower() else "अपठित गद्यांश"
    text = (qh + " " + (qe or "")).lower()
    if sec == "cdp":
        if any(w in text for w in ["समावेशी", "विशेष आवश्यकता", "वंचित", "disability", "inclusive", "अक्षमता", "डिस्लेक्सिया", "dyslexia"]):
            return "समावेशी शिक्षा"
        elif any(w in text for w in ["पियाजे", "वाइगोत्स्की", "कोहलबर्ग", "piaget", "vygotsky", "kohlberg", "संज्ञानात्मक", "समीपस्थ", "scaffolding", "पाड़"]):
            return "संज्ञानात्मक विकास"
        elif any(w in text for w in ["बुद्धि", "intelligence", "iq", "गार्डनर", "gardner", "बीने", "binet"]):
            return "बुद्धि"
        elif any(w in text for w in ["मूल्यांकन", "आकलन", "सतत", "assessment", "evaluation", "cce", "पोर्टफोलियो", "रुब्रिक"]):
            return "मूल्यांकन"
        elif any(w in text for w in ["अधिगम", "सीखना", "learning", "थार्नडाइक", "पावलोव", "स्किनर", "पुनर्बलन", "reinforcement"]):
            return "अधिगम सिद्धांत"
        elif any(w in text for w in ["अभिप्रेरणा", "motivation", "मास्लो", "maslow", "आंतरिक अभिप्रेरणा"]):
            return "अभिप्रेरणा"
        elif any(w in text for w in ["व्यक्तित्व", "personality", "प्रक्षेपी"]):
            return "व्यक्तित्व"
        elif any(w in text for w in ["सृजनात्मकता", "creativity", "अपसारी", "divergent"]):
            return "स्मृति/सृजनात्मकता"
        elif any(w in text for w in ["लिंग", "gender", "रूढ़िवादिता", "समानता"]):
            return "लिंग एवं समानता"
        elif any(w in text for w in ["वैयक्तिक भिन्नता", "individual difference"]):
            return "वैयक्तिक भिन्नता"
        elif any(w in text for w in ["शिक्षण विधि", "teaching method", "विधि", "शिक्षण अधिगम"]):
            return "शिक्षण विधियाँ"
        elif any(w in text for w in ["भाषा विकास", "चॉम्स्की", "chomsky", "lad"]):
            return "भाषा विकास"
        elif any(w in text for w in ["nep", "rte", "ncf", "अधिनियम", "नीति", "policy"]):
            return "नीति एवं अधिनियम"
        else:
            return "बाल विकास एवं अधिगम"
    elif sec == "math":
        if any(w in text for w in ["शिक्षण", "अधिगम", "वैन हील", "van hiele", "त्रुटि", "गणित की प्रकृति", "pedagogy", "पाठ्यक्रम", "tictac"]):
            return "गणित शिक्षाशास्त्र"
        elif any(w in text for w in ["संख्या", "अभाज्य", "भाज्य", "गुणनखंड", "ल.स.", "म.स.", "भिन्न", "स्थान मान", "fraction", "number", "prime"]):
            return "संख्या पद्धति"
        elif any(w in text for w in ["कोण", "त्रिभुज", "आयत", "वर्ग", "वृत्त", "geometry", "triangle", "angle", "समान्तर"]):
            return "ज्यामिति"
        elif any(w in text for w in ["क्षेत्रफल", "परिमाप", "आयतन", "mensuration", "area", "perimeter", "volume"]):
            return "क्षेत्रमिति"
        elif any(w in text for w in ["पैटर्न", "शृंखला", "क्रम", "pattern", "series"]):
            return "पैटर्न/शृंखला"
        elif any(w in text for w in ["प्रतिशत", "लाभ", "हानि", "बट्टा", "percentage", "profit", "loss"]):
            return "प्रतिशत/लाभ-हानि"
        elif any(w in text for w in ["औसत", "माध्य", "औसत चाल", "average", "mean"]):
            return "औसत"
        elif any(w in text for w in ["समय", "दूरी", "चाल", "ट्रेन", "रेलगाड़ी", "speed", "distance", "time"]):
            return "गति-दूरी-समय"
        elif any(w in text for w in ["कार्य", "दिन", "मजदूर", "work", "days"]):
            return "समय एवं कार्य"
        elif any(w in text for w in ["ब्याज", "साधारण ब्याज", "चक्रवृद्धि", "interest"]):
            return "ब्याज"
        elif any(w in text for w in ["आँकड़ा", "आलेख", "तालिका", "दंड", "data", "graph"]):
            return "आँकड़ा निर्वचन"
        else:
            return "अंकगणित एवं संख्या"
    elif sec == "evs":
        if any(w in text for w in ["शिक्षण", "थीम", "उद्देश्य", "गतिविधि", "भ्रमण", "pedagogy", "evs", "परियोजना", "पाठ्यचर्या"]):
            return "EVS शिक्षाशास्त्र"
        elif any(w in text for w in ["प्रदूषण", "अपशिष्ट", "प्लास्टिक", "pollution", "स्मॉग"]):
            return "प्रदूषण"
        elif any(w in text for w in ["पारिस्थितिकी", "पारितंत्र", "खाद्य शृंखला", "ecosystem", "food chain", "उत्पादक", "उपभोक्ता"]):
            return "पारिस्थितिकी"
        elif any(w in text for w in ["जैव-विविधता", "राष्ट्रीय उद्यान", "अभयारण्य", "रेड डेटा", "biodiversity", "national park", "प्रजाति"]):
            return "जैव-विविधता"
        elif any(w in text for w in ["उत्तराखण्ड", "जिम कॉर्बेट", "नंदा देवी", "चिपको", "गौरा देवी", "फूलों की घाटी", "उत्तराखंड"]):
            return "उत्तराखण्ड विशेष"
        elif any(w in text for w in ["ऊर्जा", "जलवायु", "ग्लोबल वार्मिंग", "ग्रीनहाउस", "सौर ऊर्जा", "climate", "energy"]):
            return "ऊर्जा एवं जलवायु"
        elif any(w in text for w in ["मृदा", "मिट्टी", "कृषि", "फसल", "झूम", "soil", "crop", "agriculture"]):
            return "कृषि एवं मृदा"
        elif any(w in text for w in ["नदी", "पर्वत", "पठार", "झील", "जल", "river", "water", "lake"]):
            return "भूगोल एवं नदियाँ"
        elif any(w in text for w in ["वन", "जंगल", "संसाधन", "खनिज", "forest", "resource"]):
            return "वन एवं संसाधन"
        elif any(w in text for w in ["अनुकूलन", "पक्षी", "घोंसला", "जानवर", "कीट", "हाथी", "स्लॉथ", "adaptation", "animal"]):
            return "जीव अनुकूलन"
        else:
            return "पर्यावरण एवं जीवन"
    elif sec == "hindi":
        if any(w in text for w in ["शिक्षण", "अधिगम", "कौशल", "भाषा अर्जन", "मातृभाषा", "त्रुटि", "व्याकरण शिक्षण", "उपचारात्मक"]):
            return "भाषा शिक्षण"
        elif any(w in text for w in ["संधि", "समास", "उपसर्ग", "प्रत्यय", "संज्ञा", "सर्वनाम", "विशेषण", "क्रिया", "कारक", "लिंग", "वचन"]):
            return "व्याकरण"
        elif any(w in text for w in ["पर्यायवाची", "विलोम", "तद्भव", "तत्सम", "मुहावरा", "लोकोक्ति", "अनेकार्थी", "शब्द"]):
            return "शब्द-भंडार"
        elif any(w in text for w in ["वर्ण", "स्वर", "व्यंजन", "उच्चारण", "अल्पप्राण", "महाप्राण"]):
            return "वर्ण-विचार"
        elif any(w in text for w in ["रस", "छंद", "अलंकार"]):
            return "छंद/अलंकार/रस"
        elif any(w in text for w in ["कवि", "लेखक", "रचना", "साहित्य", "उपन्यास", "कविता"]):
            return "हिन्दी साहित्य"
        else:
            return "हिन्दी भाषा एवं व्याकरण"
    elif sec == "english":
        if any(w in text for w in ["teaching", "pedagogy", "acquisition", "learning", "method", "skill", "remedial", "error", "language"]):
            return "ELT Methods & Skills"
        elif any(w in text for w in ["tense", "preposition", "verb", "noun", "pronoun", "conjunction", "adjective", "passive", "direct", "indirect", "clause"]):
            return "Grammar"
        elif any(w in text for w in ["synonym", "antonym", "vocabulary", "spelling", "idiom", "phrase", "meaning"]):
            return "Vocabulary & Idioms"
        elif any(w in text for w in ["metaphor", "simile", "personification", "alliteration", "figure of speech"]):
            return "Figures of Speech"
        elif any(w in text for w in ["phoneme", "sound", "diphthong", "stress", "syllable", "phonology"]):
            return "Phonology"
        else:
            return "English Language"
    return sec.capitalize()


def _build_database(temp_db_path: Path) -> int:
    print(f"Building SQLite database from {BANK}...")
    conn = sqlite3.connect(temp_db_path)
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
    appearance_count = 0
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
            appearance_count += 1

    # 2. Collect paper forms
    form_count = 0
    for form_file in sorted(BANK.rglob("forms.ndjson")):
        for line in form_file.read_text(encoding="utf-8").splitlines():
            if not line.strip(): continue
            f = json.loads(line)
            title = sanitize_display_text(
                f.get("title", {}).get("hi") or f.get("title", {}).get("en") or f.get("id", "")
            )
            cur.execute("""
                INSERT INTO paper_forms (id, exam, paper, exam_date, set_code, title, total_questions, modules_json)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                f["id"], f["exam"], f["paper"], f["examDate"], f["setCode"],
                title, f["totalQuestions"], json.dumps(f.get("modules", []), ensure_ascii=False)
            ))
            form_count += 1

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
            paper_num = q.get("paper", 1)
            exams_tag = f"{exam}{paper_num}"

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
            source_tag = f"{exam.upper()} {year} (Paper {paper_num})" if year else f"{exam.upper()} PYQ"

            # Prompt text
            prompt_block = q.get("prompt", [{}])[0]
            text_map = prompt_block.get("text", {})
            q_hi = sanitize_question_stem(
                text_map.get("hi") or text_map.get("sa") or text_map.get("en") or ""
            )
            q_en = (
                sanitize_question_stem(text_map.get("en"))
                if isinstance(text_map.get("en"), str)
                else None
            )

            # Options text
            opts_hi = []
            opts_en = []
            has_en_opts = False
            for option_index, opt in enumerate(q.get("options", [])):
                opt_content = opt.get("content", [{}])[0]
                ot = opt_content.get("text", {})
                option_id = opt.get("id")
                hi_text = sanitize_option_text(
                    ot.get("hi") or ot.get("sa") or ot.get("en") or "",
                    option_id,
                    option_index,
                )
                opts_hi.append(hi_text)
                if "en" in ot:
                    has_en_opts = True
                    opts_en.append(
                        sanitize_option_text(ot["en"], option_id, option_index)
                    )
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

            topic_name = classify_topic(sec, q_hi, q_en, passage_id)

            cur.execute("""
                INSERT INTO questions (
                    id, exams, section, topic_index, topic_name, difficulty,
                    q_hindi, options_hindi, q_english, options_english,
                    answer, p_score, years, source_tag, passage_id, seq_in_passage
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                qid, exams_tag, sec, 0, topic_name, 2,
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
    cur.execute("INSERT INTO meta (key, val) VALUES (?, ?)", ("bank_version", str(BANK_VERSION)))
    cur.execute("INSERT INTO meta (key, val) VALUES (?, ?)", ("total_questions", str(total_q)))
    cur.execute("INSERT INTO meta (key, val) VALUES (?, ?)", ("total_passages", str(len(stimuli_seen))))
    cur.execute("INSERT INTO meta (key, val) VALUES (?, ?)", ("is_v2_migrated", "true"))

    conn.commit()
    integrity_result = cur.execute("PRAGMA integrity_check").fetchone()
    if integrity_result != ("ok",):
        raise sqlite3.DatabaseError(f"SQLite integrity check failed: {integrity_result}")
    expected_rows = {
        "questions": total_q,
        "passages": len(stimuli_seen),
        "paper_forms": form_count,
        "appearances": appearance_count,
    }
    for table_name, expected_count in expected_rows.items():
        actual_count = cur.execute(f"SELECT COUNT(*) FROM {table_name}").fetchone()[0]
        if actual_count != expected_count:
            raise sqlite3.DatabaseError(
                f"{table_name} count {actual_count} != expected {expected_count}"
            )
    conn.close()

    db_size = temp_db_path.stat().st_size
    print(f"Successfully built SQLite DB at {DB_PATH}")
    print(f"Total Questions: {total_q}")
    print(f"Total Passages: {len(stimuli_seen)}")
    print(f"Database size: {db_size / 1024:.1f} KB ({db_size / (1024*1024):.2f} MB)")
    return 0


def main() -> int:
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(
        prefix=f".{DB_PATH.name}.build-", dir=DB_PATH.parent
    ) as staging_dir:
        temp_db_path = Path(staging_dir) / DB_PATH.name
        result = _build_database(temp_db_path)
        if result != 0:
            return result
        # Replace only after a complete SQLite build; a previous database remains
        # available if parsing, inserts, or integrity checks fail.
        os.replace(temp_db_path, DB_PATH)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

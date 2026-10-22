#!/usr/bin/env python3
"""Repair the bundled SQLite vault and the Git-backed CDN source packs.

The repair is deliberately idempotent.  It fixes the known corrupted
UTET Paper-I passage, restores its comprehension questions, detaches
standalone grammar questions that were accidentally shown with reading
passages, and re-aligns paper metadata.

Run from the repository root:

    python scripts/repair_vault.py

Afterwards run:

    python scripts/validate_vault.py
"""

from __future__ import annotations

import collections
import hashlib
import json
import re
import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from vault_content_fixes import (  # noqa: E402
    ANSWER_INDEX_FIXES,
    ANSWER_KEY_OVERRIDES,
    ENGLISH_OPTION_COPIES,
    ENGLISH_OPTION_FIXES,
    ENGLISH_STEM_FIXES,
    FOREIGN_EN_FAMILIES,
    OPTION_TEXT_FIXES,
    ORPHAN_ORIGINAL_STEMS,
    ORPHAN_QUESTION_IDS,
)
from vault_data_rules import (  # noqa: E402
    normalize,
    norm_lower,
    normalize_options,
    option_anchor_violation,
    stem_anchor_violation,
)

ROOT = Path(__file__).resolve().parents[1]
DB_PATH = ROOT / "assets" / "database" / "tet_mock_vault.db"
CDN_DIR = ROOT / "cdn"
PACK_DIR = CDN_DIR / "packs"

VAULT_VERSION = 2026102020
VAULT_VERSION_STR = "20261021_master_vault_clean_v20"

CORRUPT_PASSAGE_ID = "utet-p1-set-c__stim_061"
CLEAN_DIRECTION = "निम्नलिखित गद्यांश को पढ़कर प्रश्नों के उत्तर दीजिए।"

# The English questions that actually belong to "The last great war" passage.
COMPREHENSION_MAP = {
    "c831e600eb0b79b8": 1,  # What was the impact of the last great war...
    "c27c380ae72953b4": 2,  # What did Tagore articulate...
    "8fa85f18511f9f2e": 3,  # What was the stance of Indian Intelligentsia...
    "2b19231183dc5f29": 4,  # Find words meaning disgust/disappointment
    "7998ee518e47fa78": 5,  # Which statement is true?
}

# Correct option indices (A=0).  The source extractor kept the official
# answer letter while re-ordering options, so these five keys had drifted.
COMPREHENSION_ANSWERS = {
    "c831e600eb0b79b8": 1,
    "c27c380ae72953b4": 1,
    "8fa85f18511f9f2e": 3,
    "2b19231183dc5f29": 2,
    "7998ee518e47fa78": 1,
}

GRAMMAR_ANSWER_FIXES = {
    "bf282c92c0146a34": 3,  # By the next month ... have completed
    "6481a19579f98188": 3,  # In the Middle Ages ... couldn't
    "c1e417281426450c": 2,  # Kate is ill ... has to
}

# Additional key corrections found while rebuilding the missing figures.
# For 42585dbbc302b422 the figure supplies ∠A = 50° and ∠B : ∠C = 2 : 3,
# so ∠B = 52° (option B), not 65°.
GENERAL_ANSWER_FIXES = {
    "42585dbbc302b422": 1,
}

QUESTION_TEXT_FIXES = {
    "8635839d93b24272": {
        "qh": "निम्नलिखित चित्र में x का मान है:",
        "qe": "In the following figure, the value of x is:",
    },
    "240502e5a4f70e25": {
        "qh": "दिए गए चित्र में ABCD और PQRS दोनों समांतर चतुर्भुज हैं। θ का मान होगा —",
        "qe": "In the given figure, both ABCD and PQRS are parallelograms. The value of θ will be —",
    },
}

OPTION_FIGURE_FIXES = {
    "ctet-p1-2018-pyq_q056": (
        ["चित्र A", "चित्र B", "चित्र C", "चित्र D"],
        ["Figure A", "Figure B", "Figure C", "Figure D"],
    ),
    "ctet-p1-2018-pyq_q058": (
        ["चित्र A", "चित्र B", "चित्र C", "चित्र D"],
        ["Figure A", "Figure B", "Figure C", "Figure D"],
    ),
}

# Independent grammar / spelling / tense items which were incorrectly
# rendered underneath a reading passage.
DETACH_QUESTION_IDS = {
    # Grammar items that were grouped under the "last great war" passage.
    "33d37d1cf677481b",
    "bf282c92c0146a34",
    "6481a19579f98188",
    "c1e417281426450c",
    "c946dc4b1f841370",
    # CTET official PYQ papers
    "ctet-p1-2020-pyq_q134",
    "ctet-p1-2021-pyq_q128",
    "ctet-p1-2021-pyq_q135",
    # Generated CTET language mocks: the last three items are grammar,
    # not comprehension questions for the poem above them.
    "ctet-p1-mock-02_q130",
    "ctet-p1-mock-02_q131",
    "ctet-p1-mock-02_q132",
    "ctet-p1-mock-07_q130",
    "ctet-p1-mock-07_q131",
    "ctet-p1-mock-07_q132",
    "ctet-p1-mock-08_q130",
    "ctet-p1-mock-08_q131",
    "ctet-p1-mock-08_q132",
    "ctet-p1-mock-09_q130",
    "ctet-p1-mock-09_q131",
    "ctet-p1-mock-09_q132",
}


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def write_json(path: Path, value: object) -> None:
    path.write_text(
        json.dumps(value, ensure_ascii=False, separators=(",", ":")) + "\n",
        encoding="utf-8",
    )


def write_pretty_json(path: Path, value: object) -> None:
    """Keep the human-reviewed manifest readable in Git diffs."""
    path.write_text(
        json.dumps(value, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def clean_corrupt_body(body: str) -> str:
    """Remove the Sanskrit sections appended by a bad source merge."""
    for marker in ("\n### C1.", "\n### C2.", "\nC1. संस्कृत", "\nC2. संस्कृत"):
        if marker in body:
            body = body.split(marker, 1)[0]
    return body.rstrip()


def repair_packs() -> dict[str, dict]:
    """Repair every JSON pack. Returns metadata keyed by the new file name."""
    pack_files = sorted(PACK_DIR.glob("pack-*.json"))
    if not pack_files:
        raise SystemExit("No CDN packs found")

    # Load all packs once, then operate on the in-memory documents so a
    # question may live in any pack.
    docs: dict[Path, dict] = {}
    for path in pack_files:
        docs[path] = json.loads(path.read_text(encoding="utf-8"))

    clean_body = None
    for path, doc in docs.items():
        for passage in doc.get("p", []):
            if passage.get("id") == CORRUPT_PASSAGE_ID:
                clean_body = clean_corrupt_body(passage.get("b", ""))
                break
        if clean_body:
            break
    if not clean_body:
        raise SystemExit(f"Corrupt passage {CORRUPT_PASSAGE_ID} was not found")

    # Do not keep the Sanskrit instructions in the clean English passage.
    clean_body = clean_body.replace("### C1. संस्कृत गद्यांश — राष्ट्रपति", "")
    clean_body = clean_body.replace("### C2. संस्कृत गद्यांश — साधु", "").strip()

    changed_pack_paths: list[tuple[Path, dict]] = []

    for path, doc in docs.items():
        changed = False

        for passage in doc.get("p", []):
            if passage.get("id") == CORRUPT_PASSAGE_ID:
                if passage.get("d") != CLEAN_DIRECTION or passage.get("b") != clean_body:
                    passage["d"] = CLEAN_DIRECTION
                    passage["b"] = clean_body
                    changed = True

        for question in doc.get("q", []):
            qid = question.get("k")

            if qid in DETACH_QUESTION_IDS:
                if "pid" in question or "n" in question:
                    question.pop("pid", None)
                    question.pop("n", None)
                    changed = True

            if qid in COMPREHENSION_MAP:
                seq = COMPREHENSION_MAP[qid]
                answer = COMPREHENSION_ANSWERS[qid]
                if question.get("pid") != CORRUPT_PASSAGE_ID or question.get("n") != seq:
                    question["pid"] = CORRUPT_PASSAGE_ID
                    question["n"] = seq
                    changed = True
                if question.get("a") != answer:
                    question["a"] = answer
                    changed = True

            if qid in GRAMMAR_ANSWER_FIXES and question.get("a") != GRAMMAR_ANSWER_FIXES[qid]:
                question["a"] = GRAMMAR_ANSWER_FIXES[qid]
                changed = True

            if qid in GENERAL_ANSWER_FIXES and question.get("a") != GENERAL_ANSWER_FIXES[qid]:
                question["a"] = GENERAL_ANSWER_FIXES[qid]
                changed = True

            if qid in QUESTION_TEXT_FIXES:
                for key, value in QUESTION_TEXT_FIXES[qid].items():
                    if question.get(key) != value:
                        question[key] = value
                        changed = True

            if qid in OPTION_FIGURE_FIXES:
                options_hi, options_en = OPTION_FIGURE_FIXES[qid]
                if question.get("oh") != options_hi:
                    question["oh"] = options_hi
                    changed = True
                if question.get("oe") != options_en:
                    question["oe"] = options_en
                    changed = True

        if changed:
            changed_pack_paths.append((path, doc))

    # Re-index every passage after detaching questions.  The sequence values
    # are displayed to candidates, so a gap (e.g. 1,2,3,4,5,7) is visible.
    by_passage: dict[str, list[dict]] = {}
    for doc in docs.values():
        for question in doc.get("q", []):
            pid = question.get("pid")
            if pid:
                by_passage.setdefault(pid, []).append(question)
    for pid, questions in by_passage.items():
        questions.sort(key=lambda q: (q.get("n") is None, q.get("n") or 0, q.get("k", "")))
        for index, question in enumerate(questions, start=1):
            if question.get("n") != index:
                question["n"] = index
                # Locate the owning pack and mark it dirty.
                for path, doc in docs.items():
                    if question in doc.get("q", []):
                        if (path, doc) not in changed_pack_paths:
                            changed_pack_paths.append((path, doc))
                        break

    if not changed_pack_paths:
        print("CDN packs already repaired; nothing to rename.")
        return {}

    # A pack file name embeds its SHA-256 prefix.  Rewrite changed packs with
    # their new content hash so the manifest and Git history stay honest.
    new_manifest_entries: dict[str, dict] = {}
    for old_path, doc in changed_pack_paths:
        payload = json.dumps(doc, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        digest = sha256_bytes(payload)
        index = old_path.name.split("-")[1]
        new_name = f"pack-{index}-{digest[:12]}.json"
        new_path = PACK_DIR / new_name
        if old_path == new_path:
            old_path.write_bytes(payload)
        else:
            new_path.write_bytes(payload)
            if old_path.exists():
                old_path.unlink()
        # The caller patches manifest entries by pack index.
        new_manifest_entries[index] = {
            "file": f"packs/{new_name}",
            "sha256": digest,
            "bytes": len(payload),
            "count": len(doc.get("q", [])),
            "sections": sorted(
                {
                    q.get("s", "")
                    for q in doc.get("q", [])
                    if q.get("s")
                }
            ),
        }
        print(f"rewrote {old_path.name} -> {new_name}")

    return new_manifest_entries


def reindex_passage(conn: sqlite3.Connection, passage_id: str) -> None:
    ids = [
        row[0]
        for row in conn.execute(
            "SELECT id FROM questions WHERE passage_id = ? ORDER BY seq_in_passage, id",
            (passage_id,),
        )
    ]
    for index, qid in enumerate(ids, start=1):
        conn.execute(
            "UPDATE questions SET seq_in_passage = ? WHERE id = ?",
            (index, qid),
        )


# --------------------------------------------------------------------------
# v20 content-integrity repairs
# --------------------------------------------------------------------------

# Questions whose stem points at a stimulus ("उपर्युक्त काव्यांश / पद / पद्यांश
# / गद्यांश") that does not exist anywhere in the vault.  A candidate cannot
# answer them, so the slot is refilled with a vetted question of the same
# section.  The original rows keep their identity and form placement.
UNANSWERABLE_QUESTIONS = {
    "adbe479d06b877fa",  # utet-p1-set-b  Q49
    "8f453dc771389b4c",  # utet-p1-set-d  Q50
    "7f1d63495debe7d5",  # utet-p1-set-d  Q51
    "eaaff24a7b35f54b",  # utet-p1-set-f  Q56
    "51002bd95527682c",  # utet-p1-set-j  Q48
    "460690c7c98df82c",  # utet-p2-set-a  Q37
    "eba40fdedd5a4871",  # utet-p2-set-b  Q37
    "d7c9a1c870e3681d",  # utet-p2-set-b  Q38
    "30ec542094b9b142",  # utet-p2-set-d  Q32
    "25a9c0125e1d7a24",  # utet-p2-set-d  Q34
    "f72df3bade24ce3e",  # utet-p2-set-d  Q44
    "29bb04fab60e7f08",  # utet-p2-set-e  Q54
    "758239262d9f03e9",  # utet-p2-set-f  Q50
}

# The CTET 2020 Paper-1 prose passage was interrupted by an unrelated
# error-spotting item (Q134).  Swapping the two positions keeps the passage
# questions contiguous (Q129-Q134) so the booklet never splits a group.
PASSAGE_POSITION_SWAPS = [("ctet-p1-2020-pyq", 134, 135)]

# "उपर्युक्त काव्यांश / पद / पद्यांश / गद्यांश" - a reference to a stimulus
# that is not part of the question itself.
MISSING_STIMULUS_RE = re.compile(
    "\u0909\u092a\u0930\u094d\u092f\u0941\u0915\u094d\u0924\\s+"
    "(\u0915\u093e\u0935\u094d\u092f\u093e\u0902\u0936|\u0915\u093e\u0935\u094d\u092f|"
    "\u092a\u0926|\u092a\u0926\u094d\u092f\u093e\u0902\u0936|\u0917\u0926\u094d\u092f\u093e\u0902\u0936|"
    "\u092a\u0902\u0915\u094d\u0924\u093f\u092f\u093e\u0901)"
)


def _load_appearances(conn: sqlite3.Connection) -> list[dict]:
    rows = conn.execute(
        "SELECT a.id, a.paper_form_id, a.question_number, a.question_id, "
        "       q.q_hindi, q.section, q.exams, q.passage_id, q.difficulty "
        "FROM appearances a JOIN questions q ON q.id = a.question_id"
    ).fetchall()
    return [
        {
            "aid": row[0],
            "form": row[1],
            "qn": row[2],
            "qid": row[3],
            "stem": row[4] or "",
            "section": row[5],
            "exams": row[6],
            "pid": row[7],
            "difficulty": row[8],
        }
        for row in rows
    ]


def dedupe_paper_questions(conn: sqlite3.Connection) -> int:
    """Make sure no paper prints the same question twice.

    The mock generator sampled some questions twice inside a single paper.
    Instead of dropping questions we swap the duplicated slot with an
    equally-typed question from another paper that is used exactly once in the
    whole vault, so every paper keeps 150 *different* questions and the bank
    keeps all 9,720 questions.
    """
    rows = _load_appearances(conn)
    if not rows:
        return 0

    form_rows: dict[str, list[dict]] = {}
    stem_total: dict[str, int] = {}
    form_stems: dict[str, dict[str, int]] = {}
    for row in rows:
        form_rows.setdefault(row["form"], []).append(row)
        stem_total[row["stem"]] = stem_total.get(row["stem"], 0) + 1
        form_stems.setdefault(row["form"], {})
        form_stems[row["form"]][row["stem"]] = (
            form_stems[row["form"]].get(row["stem"], 0) + 1
        )

    # Duplicates are rows that share both the text *and* the passage.  Two
    # passage questions with the same generic wording ("What is the main idea
    # of the passage?") belong to different passages and are legitimate.
    targets: list[dict] = []
    for form in sorted(form_rows):
        groups: dict[tuple[str, str], list[dict]] = {}
        for row in sorted(
            form_rows[form], key=lambda r: (r["qn"], r["qid"], r["aid"])
        ):
            groups.setdefault((row["stem"], row["pid"] or ""), []).append(row)
        for key in sorted(groups):
            group = groups[key]
            for row in group[1:]:
                targets.append(row)

    donors = [
        row
        for row in rows
        if not row["pid"] and stem_total.get(row["stem"], 0) == 1
    ]
    donors.sort(key=lambda r: r["qid"])

    swaps = 0
    for target in targets:
        pick = None
        for donor in donors:
            if donor["aid"] == target["aid"]:
                continue
            if donor["form"] == target["form"]:
                continue
            if donor["section"] != target["section"]:
                continue
            if donor["exams"] != target["exams"]:
                continue
            if donor["stem"] in form_stems[target["form"]]:
                continue
            if target["stem"] in form_stems[donor["form"]]:
                continue
            if form_stems[donor["form"]].get(donor["stem"], 0) != 1:
                continue
            pick = donor
            break
        if pick is None:
            continue

        # Swap the two questions between their papers.
        conn.execute(
            "UPDATE appearances SET question_id = ? WHERE id = ?",
            (pick["qid"], target["aid"]),
        )
        conn.execute(
            "UPDATE appearances SET question_id = ? WHERE id = ?",
            (target["qid"], pick["aid"]),
        )

        form_stems[target["form"]][target["stem"]] -= 1
        form_stems[target["form"]][pick["stem"]] = (
            form_stems[target["form"]].get(pick["stem"], 0) + 1
        )
        form_stems[pick["form"]][pick["stem"]] -= 1
        form_stems[pick["form"]][target["stem"]] = (
            form_stems[pick["form"]].get(target["stem"], 0) + 1
        )
        target["stem"], pick["stem"] = pick["stem"], target["stem"]
        target["qid"], pick["qid"] = pick["qid"], target["qid"]
        swaps += 1

    return swaps


def fix_passage_positions(conn: sqlite3.Connection) -> int:
    """Move an interrupting question out of a passage group.

    The swap is only applied while the passage group is still split, which
    keeps the repair idempotent.
    """
    fixed = 0
    for form, first, second in PASSAGE_POSITION_SWAPS:
        rows = conn.execute(
            "SELECT a.id, a.question_number, q.passage_id FROM appearances a "
            "JOIN questions q ON q.id = a.question_id "
            "WHERE a.paper_form_id = ? AND a.question_number IN (?, ?) "
            "ORDER BY a.question_number",
            (form, first, second),
        ).fetchall()
        if len(rows) != 2:
            continue
        passage_id = rows[1][2]
        if not passage_id:
            continue
        numbers = sorted(
            r[0]
            for r in conn.execute(
                "SELECT a.question_number FROM appearances a "
                "JOIN questions q ON q.id = a.question_id "
                "WHERE a.paper_form_id = ? AND q.passage_id = ?",
                (form, passage_id),
            )
        )
        if numbers and numbers[-1] - numbers[0] + 1 == len(numbers):
            # Already contiguous - nothing to do.
            continue
        conn.execute(
            "UPDATE appearances SET question_number = ? WHERE id = ?", (second, rows[0][0])
        )
        conn.execute(
            "UPDATE appearances SET question_number = ? WHERE id = ?", (first, rows[1][0])
        )
        fixed += 1
    return fixed


def replace_unanswerable_questions(conn: sqlite3.Connection) -> int:
    """Refill slots whose stimulus is missing from the entire vault."""
    rows = _load_appearances(conn)
    if not rows:
        return 0

    by_id = {row["qid"]: row for row in rows}
    stem_total: dict[str, int] = {}
    form_stems: dict[str, set[str]] = {}
    for row in rows:
        stem_total[row["stem"]] = stem_total.get(row["stem"], 0) + 1
        form_stems.setdefault(row["form"], set()).add(row["stem"])

    replaced = 0
    for qid in sorted(UNANSWERABLE_QUESTIONS):
        target = by_id.get(qid)
        if target is None:
            continue
        # Only refill while the row still points at a stimulus that the
        # vault does not contain.  This keeps the repair idempotent.
        if not MISSING_STIMULUS_RE.search(target["stem"] or ""):
            continue
        donor = None
        for candidate in sorted(rows, key=lambda r: r["qid"]):
            if candidate["qid"] == qid:
                continue
            if candidate["pid"]:
                continue
            if candidate["section"] != target["section"]:
                continue
            if candidate["exams"] != target["exams"]:
                continue
            if candidate["qid"] in UNANSWERABLE_QUESTIONS:
                continue
            if stem_total.get(candidate["stem"], 0) != 1:
                continue
            if candidate["stem"] in form_stems[target["form"]]:
                continue
            donor = candidate
            break
        if donor is None:
            continue

        source = conn.execute(
            "SELECT q_hindi, q_english, options_hindi, options_english, answer, p_score, "
            "       topic_name, difficulty FROM questions WHERE id = ?",
            (donor["qid"],),
        ).fetchone()
        conn.execute(
            "UPDATE questions SET q_hindi = ?, q_english = ?, options_hindi = ?, "
            "options_english = ?, answer = ?, p_score = ?, topic_name = ?, difficulty = ? "
            "WHERE id = ?",
            (
                source[0],
                source[1],
                source[2],
                source[3],
                source[4],
                source[5],
                source[6],
                source[7],
                qid,
            ),
        )
        stem_total[target["stem"]] = stem_total.get(target["stem"], 0) - 1
        stem_total[donor["stem"]] = stem_total.get(donor["stem"], 0) + 1
        form_stems[target["form"]].discard(target["stem"])
        form_stems[target["form"]].add(donor["stem"])
        replaced += 1

    return replaced


def sync_official_answer_keys(conn: sqlite3.Connection) -> int:
    """Keep the printed answer key identical to the repaired question key."""
    cur = conn.execute(
        "UPDATE appearances SET official_option_id = "
        "  char(65 + (SELECT answer FROM questions q WHERE q.id = appearances.question_id)) "
        "WHERE official_option_id IS NULL OR official_option_id <> "
        "  char(65 + (SELECT answer FROM questions q WHERE q.id = appearances.question_id))"
    )
    return cur.rowcount


def normalise_modules(conn: sqlite3.Connection) -> int:
    """Store the real section codes of every paper in ``modules_json``."""
    changed = 0
    for (form,) in conn.execute("SELECT id FROM paper_forms ORDER BY id").fetchall():
        sections: list[str] = []
        for (section,) in conn.execute(
            "SELECT section FROM appearances WHERE paper_form_id = ? "
            "ORDER BY question_number, id",
            (form,),
        ).fetchall():
            if section and section not in sections:
                sections.append(section)
        payload = json.dumps(sections, ensure_ascii=False, separators=(",", ":"))
        conn.execute(
            "UPDATE paper_forms SET modules_json = ? WHERE id = ? AND modules_json <> ?",
            (payload, form, payload),
        )
        changed += 1
    return changed


def sync_topic_indexes(conn: sqlite3.Connection) -> int:
    """Align ``questions.topic_index`` with the CDN topic catalogue.

    The packs address their topics by the index of the alphabetically
    sorted topic list.  The bundled SQLite still carried a zero for every
    row, which made the column useless for offline topic filters.
    """
    topics = [
        r[0]
        for r in conn.execute(
            "SELECT DISTINCT topic_name FROM questions "
            "WHERE topic_name IS NOT NULL AND topic_name != '' ORDER BY topic_name"
        )
    ]
    topic_to_index = {topic: index for index, topic in enumerate(topics)}
    updated = 0
    for qid, topic in conn.execute(
        "SELECT id, topic_name FROM questions WHERE topic_name IS NOT NULL AND topic_name != ''"
    ).fetchall():
        index = topic_to_index.get(topic, 0)
        conn.execute(
            "UPDATE questions SET topic_index = ? WHERE id = ? AND topic_index <> ?",
            (index, qid, index),
        )
        updated += 1
    return updated


# Questions that must never be attached to a reading - they are standalone
# grammar items that were detached from a passage on purpose.
DETACH_PROTECTED = {
    "ctet-p1-2020-pyq_q134",
    "ctet-p1-2021-pyq_q128",
    "ctet-p1-2021-pyq_q135",
}

# A passage that was built by merging two different readings.  The second
# reading always starts with its own direction line.
MERGED_PASSAGE_MARKER = re.compile(
    r"(?:Direction|Read)\s*\(?\s*Q\.?\s*No\.?\s*\d+\s*(?:to|से)\s*\d+\s*\)?\s*:",
    re.IGNORECASE,
)

# Questions that clearly talk about a reading but have no reading attached.
PASSAGE_REFERENCE_PHRASES = (
    "in the given passage",
    "in the passage",
    "according to the passage",
    "the passage",
    "उपर्युक्त गद्यांश",
    "गद्यांश के आधार पर",
    "उपर्युक्त काव्यांश",
    "उपर्युक्त पद",
    "उपर्युक्त पद्यांश",
)

# Words that are too common to identify a passage.
_PASSAGE_STOP_WORDS = set(
    """according passage given below read following question questions answer based
    word words mean means meaning title most appropriate main thrust writer choose
    identify pick find select best suitable used what which who why how when where
    does did are was were the and for that this these those with without from as at
    by its their there here about into over under between during called known called
    choose suitable activity related hotel staff things thing happen happens animals
    natural particular something understand think behaviour behavior phrase
    expression compared employees values value culture corporate find means
    name question number"""
    .split()
)


def _passage_exists(conn: sqlite3.Connection, body: str) -> bool:
    if not body:
        return False
    row = conn.execute(
        "SELECT id FROM passages WHERE REPLACE(REPLACE(body, CHAR(10), ' '), CHAR(13), ' ') "
        "= REPLACE(REPLACE(?, CHAR(10), ' '), CHAR(13), ' ') LIMIT 1",
        (body,),
    ).fetchone()
    return row is not None


def split_merged_passages(conn: sqlite3.Connection) -> int:
    """Cuts a passage that accidentally swallowed the next reading.

    The merged row printed the first reading and then the second one, so the
    candidate saw the paragraph of another set of questions.
    """
    fixed = 0
    for pid, body in conn.execute("SELECT id, body FROM passages").fetchall():
        if not body:
            continue
        match = MERGED_PASSAGE_MARKER.search(body)
        if not match:
            continue
        first = body[: match.start()].rstrip()
        rest = body[match.end():]
        # The remainder starts with the instruction line of the second reading.
        parts = rest.split("\n\n", 1)
        second = parts[1].strip() if len(parts) > 1 else ""
        if second and _passage_exists(conn, second):
            conn.execute("UPDATE passages SET body = ? WHERE id = ?", (first, pid))
            fixed += 1
    return fixed


def _passage_keyword_score(words: set[str], body: str) -> tuple[int, int]:
    hits = [w for w in words if w in body]
    return sum(len(h) for h in hits), len(hits)


def attach_orphan_questions(conn: sqlite3.Connection) -> int:
    """Gives a reading back to the questions that lost it.

    Some questions talk about "the passage" but were stored without one, so
    they were impossible to answer.  The reading is found again by matching
    the answer words of the question (and of its options) against every
    passage of the bank - the word the question asks about has to be inside
    the passage.  Only a clear winner is used, so nothing is attached blindly.
    """
    passage_bodies = {
        row[0]: (row[1] or "").lower()
        for row in conn.execute("SELECT id, body FROM passages")
    }

    orphans = []
    for row in conn.execute(
        "SELECT q.id, q.q_hindi, q.q_english, q.options_hindi, q.options_english, "
        "a.paper_form_id, a.question_number "
        "FROM questions q JOIN appearances a ON a.question_id = q.id "
        "WHERE q.passage_id IS NULL"
    ).fetchall():
        text = " ".join(
            str(value or "") for value in (row[1], row[2], row[3], row[4])
        ).lower()
        if any(phrase in text for phrase in PASSAGE_REFERENCE_PHRASES):
            orphans.append(row)

    by_form: dict[str, list] = {}
    for row in orphans:
        by_form.setdefault(row[5], []).append(row)

    attached = 0
    for form, rows in by_form.items():
        rows.sort(key=lambda r: r[6])
        groups: list[list] = []
        for row in rows:
            if groups and row[6] - groups[-1][-1][6] > 3:
                groups.append([row])
            else:
                groups[-1].append(row) if groups else groups.append([row])
        if not groups:
            continue

        for group in groups:
            # The answer words of the question have to be inside the passage.
            answer_words: set[str] = set()
            for row in group:
                for field in (row[3], row[4]):
                    try:
                        options = json.loads(field or "[]")
                    except (TypeError, ValueError):
                        options = []
                    for option in options:
                        for word in re.findall(r"[A-Za-z][A-Za-z'-]{4,}", str(option or "")):
                            answer_words.add(word.strip("'").lower())
            if not answer_words:
                continue

            scored = []
            for pid, body in passage_bodies.items():
                hits = [w for w in answer_words if w in body]
                if len(hits) >= 4:
                    scored.append((len(hits), sum(len(h) for h in hits), pid))
            scored.sort(reverse=True)
            if not scored:
                continue
            best_pid = scored[0][2]

            source = conn.execute(
                "SELECT kind, dir_text, body FROM passages WHERE id = ?", (best_pid,)
            ).fetchone()
            if source is None:
                continue

            new_id = f"{form}__stim_{group[0][6]:03d}"
            conn.execute(
                "INSERT INTO passages (id, kind, dir_text, body) VALUES (?, ?, ?, ?) "
                "ON CONFLICT(id) DO UPDATE SET kind = excluded.kind, "
                "dir_text = excluded.dir_text, body = excluded.body",
                (new_id, source[0], source[1], source[2]),
            )
            for index, row in enumerate(group, start=1):
                conn.execute(
                    "UPDATE questions SET passage_id = ?, seq_in_passage = ? WHERE id = ?",
                    (new_id, index, row[0]),
                )
            attached += len(group)

    return attached

def renumber_passages(conn: sqlite3.Connection) -> int:
    """Gives every passage a clean 1..N sequence.

    The sequence is the position of the question inside its paper, so the
    booklet can print "प्रश्न 67–71" next to a reading without a gap.
    """
    fixed = 0
    passages = [r[0] for r in conn.execute("SELECT id FROM passages").fetchall()]
    for pid in passages:
        rows = conn.execute(
            "SELECT a.paper_form_id, a.question_number, q.id "
            "FROM questions q JOIN appearances a ON a.question_id = q.id "
            "WHERE q.passage_id = ? ORDER BY a.paper_form_id, a.question_number",
            (pid,),
        ).fetchall()
        for index, row in enumerate(rows, start=1):
            conn.execute(
                "UPDATE questions SET seq_in_passage = ? WHERE id = ?", (index, row[2])
            )
            fixed += 1
    return fixed


def drop_empty_passages(conn: sqlite3.Connection) -> int:
    """Removes readings that no question uses any more."""
    empty = [
        r[0]
        for r in conn.execute(
            "SELECT id FROM passages WHERE id NOT IN "
            "(SELECT passage_id FROM questions WHERE passage_id IS NOT NULL)"
        ).fetchall()
    ]
    for pid in empty:
        conn.execute("DELETE FROM passages WHERE id = ?", (pid,))
    return len(empty)


def replace_passage_orphans(conn: sqlite3.Connection) -> int:
    """Replaces question groups whose reading does not exist anywhere.

    A question that talks about "the passage" cannot be answered when the
    reading is missing - and neither can its neighbours, because they belong
    to the same reading.  The complete group is therefore replaced with self
    contained questions of the same section, so the paper stays complete and
    every printed question can be answered.
    """
    # Questions of a paper, in order.
    paper_rows: dict[str, list] = {}
    for row in conn.execute(
        "SELECT q.id, q.q_hindi, q.q_english, q.section, q.passage_id, "
        "q.options_hindi, q.options_english, a.paper_form_id, a.question_number "
        "FROM questions q JOIN appearances a ON a.question_id = q.id"
    ).fetchall():
        paper_rows.setdefault(row[7], []).append(row)

    replaced = 0
    for form, rows in paper_rows.items():
        rows.sort(key=lambda r: r[8])

        # A seed is a question that explicitly refers to a reading.
        seeds = [
            r
            for r in rows
            if any(
                phrase
                in (str(r[1] or "") + " " + str(r[2] or "")).lower()
                for phrase in PASSAGE_REFERENCE_PHRASES
            )
        ]
        handled: set[str] = set()

        for seed in seeds:
            if seed[0] in handled:
                continue
            group = [
                r
                for r in rows
                if abs(r[8] - seed[8]) <= 3
                and r[3] == seed[3]
                and r[0] not in DETACH_PROTECTED
            ]
            if not group:
                continue

            # If a member of the group still has a reading, the whole group
            # belongs to it.
            passage_ids = [r[4] for r in group if r[4]]
            if passage_ids:
                target = passage_ids[0]
                for member in group:
                    conn.execute(
                        "UPDATE questions SET passage_id = ? WHERE id = ?",
                        (target, member[0]),
                    )
                    handled.add(member[0])
                continue

            # Otherwise the reading is lost for good: replace the group with
            # self contained questions of the same section.
            used = {str(r[1] or "") for r in rows}
            used |= {str(r[2] or "") for r in rows}
            donors = []
            for candidate in conn.execute(
                "SELECT id, q_hindi, q_english, options_hindi, options_english, "
                "answer, p_score, topic_name, difficulty, years, source_tag "
                "FROM questions WHERE section = ? AND passage_id IS NULL",
                (seed[3],),
            ).fetchall():
                if str(candidate[1] or "") in used or str(candidate[2] or "") in used:
                    continue
                if not (candidate[1] or candidate[2]):
                    continue
                donors.append(candidate)
                if len(donors) >= len(group):
                    break

            if len(donors) < len(group):
                # Fall back to a self contained question of any section that
                # is not printed in this paper yet.
                for candidate in conn.execute(
                    "SELECT id, q_hindi, q_english, options_hindi, options_english, "
                    "answer, p_score, topic_name, difficulty, years, source_tag "
                    "FROM questions WHERE passage_id IS NULL AND section != ?",
                    (seed[3],),
                ).fetchall():
                    if str(candidate[1] or "") in used or str(candidate[2] or "") in used:
                        continue
                    if not (candidate[1] or candidate[2]):
                        continue
                    donors.append(candidate)
                    if len(donors) >= len(group):
                        break

            if len(donors) < len(group):
                continue

            for member, donor in zip(
                sorted(group, key=lambda r: r[8]), donors
            ):
                conn.execute(
                    "UPDATE questions SET q_hindi = ?, q_english = ?, "
                    "options_hindi = ?, options_english = ?, answer = ?, "
                    "p_score = ?, topic_name = ?, difficulty = ?, years = ?, "
                    "source_tag = ? WHERE id = ?",
                    (
                        donor[1],
                        donor[2],
                        donor[3],
                        donor[4],
                        donor[5],
                        donor[6],
                        donor[7],
                        donor[8],
                        donor[9],
                        donor[10],
                        member[0],
                    ),
                )
                handled.add(member[0])
                replaced += 1

    return replaced


# --------------------------------------------------------------------------
# v21 question-data repairs
# --------------------------------------------------------------------------
# The source dumps were imported with a shifted English column and with
# scrambled answer keys for the questions a mock paper copied from an
# official board paper.  The repairs below restore the English translation
# of every affected question and give one single, consistent answer key to
# every question that is printed more than once.

# The marker of an official board paper.  Its key wins over the key of an
# auto-generated mock paper that copied the question.
OFFICIAL_SOURCE_MARKER = "\u0906\u0927\u093f\u0915\u093e\u0930\u093f\u0915"  # adhikar


def load_options(raw):
    try:
        value = json.loads(raw or "null")
    except (TypeError, ValueError):
        return None
    return value if isinstance(value, list) else None


def _family_key(row):
    """Questions that carry the same stem and the same options are copies."""
    options = load_options(row["options_hindi"]) or []
    return (norm_lower(row["q_hindi"]), frozenset(normalize_options(options)))


def _english_is_clean(row, hindi_options, english_options):
    """True when the English side of a question still matches the Hindi one."""
    if stem_anchor_violation(row["q_hindi"] or "", row["q_english"] or ""):
        return False
    if option_anchor_violation(hindi_options, english_options):
        return False
    return True


def repair_foreign_english(conn: sqlite3.Connection) -> dict:
    """Restore the English translation of questions whose English data
    belongs to a different question.

    The English data of a question is rebuilt from a clean copy of the same
    question (a copy whose English text still carries the Latin anchor terms
    of the Hindi text).  When no clean copy exists the human verified
    table in ``vault_content_fixes`` is used.
    """
    rows = conn.execute("SELECT * FROM questions").fetchall()
    by_option_set: dict[frozenset, list] = collections.defaultdict(list)
    by_stem: dict[str, list] = collections.defaultdict(list)
    for row in rows:
        options = load_options(row["options_hindi"]) or []
        by_option_set[frozenset(normalize_options(options))].append(row)
        by_stem[norm_lower(row["q_hindi"])].append(row)

    stats = {"stem": 0, "options": 0, "unresolved": 0}
    unresolved: list[str] = []

    for row in rows:
        hindi_options = load_options(row["options_hindi"]) or []
        english_options = load_options(row["options_english"])
        stem_bad = bool(stem_anchor_violation(row["q_hindi"] or "", row["q_english"] or ""))
        options_bad = bool(option_anchor_violation(hindi_options, english_options))
        curated = FOREIGN_EN_FAMILIES.get(norm_lower(row["q_hindi"]))
        if not stem_bad and not options_bad and curated is None:
            continue

        # 1. The human verified table wins.
        new_stem = None
        new_options = None
        curated_applies = False
        if curated:
            new_stem = curated["en_stem"]
            mapping = {norm_lower(k): v for k, v in curated["options"].items()}
            # A stray separator ("/ No error" vs "No error") must not break
            # the lookup.
            mapping.update(
                {
                    norm_lower(key).lstrip("/ ").strip(): value
                    for key, value in mapping.items()
                }
            )
            candidate = []
            complete = True
            for option in hindi_options:
                value = mapping.get(norm_lower(option))
                if value is None:
                    value = mapping.get(norm_lower(option).lstrip("/ ").strip())
                if value is None:
                    complete = False
                    break
                candidate.append(value)
            if complete:
                new_options = candidate
                curated_applies = True
            else:
                # The Hindi options of this question differ from the curated
                # ones - fall back to a clean copy of the same question.
                new_stem = None

        if not stem_bad and not options_bad and not curated_applies:
            continue

        # 2. Otherwise copy the English data from a clean copy of the same
        #    question.
        if new_options is None:
            for sibling in by_option_set[frozenset(normalize_options(hindi_options))]:
                if sibling["id"] == row["id"]:
                    continue
                sibling_hi = load_options(sibling["options_hindi"]) or []
                sibling_en = load_options(sibling["options_english"])
                if not sibling_en or len(sibling_en) != len(sibling_hi):
                    continue
                if not _english_is_clean(sibling, sibling_hi, sibling_en):
                    continue
                mapping = {}
                for hi_option, en_option in zip(sibling_hi, sibling_en):
                    mapping.setdefault(norm_lower(hi_option), en_option)
                candidate = []
                complete = True
                for option in hindi_options:
                    value = mapping.get(norm_lower(option))
                    if value is None:
                        complete = False
                        break
                    candidate.append(value)
                if not complete:
                    continue
                new_options = candidate
                if new_stem is None and norm_lower(sibling["q_hindi"]) == norm_lower(row["q_hindi"]):
                    new_stem = sibling["q_english"]
                break

        if new_options is None:
            stats["unresolved"] += 1
            unresolved.append(row["id"])
            continue

        if new_stem and (stem_bad or curated_applies):
            if (row["q_english"] or "") != new_stem:
                conn.execute(
                    "UPDATE questions SET q_english = ? WHERE id = ?",
                    (new_stem, row["id"]),
                )
                stats["stem"] += 1

        if options_bad or curated_applies:
            current = load_options(row["options_english"])
            if current != new_options:
                conn.execute(
                    "UPDATE questions SET options_english = ? WHERE id = ?",
                    (
                        json.dumps(new_options, ensure_ascii=False, separators=(",", ":")),
                        row["id"],
                    ),
                )
                stats["options"] += 1

    if unresolved:
        print(f"  WARNING: English data still unresolved for {unresolved}")
    return stats


def repair_answer_key_conflicts(conn: sqlite3.Connection) -> dict:
    """Give one single answer key to every question that is printed twice.

    The same question is used in several papers.  The mock papers copied the
    question but not the key, so the vault ended up with two different keys
    for one and the same question.  The key of the official board paper wins;
    for the remaining cases a human verified override is used.
    """
    rows = conn.execute(
        "SELECT id, q_hindi, options_hindi, answer, source_tag FROM questions"
    ).fetchall()
    groups: dict[tuple, list] = collections.defaultdict(list)
    for row in rows:
        groups[_family_key(row)].append(row)

    stats = {"groups": 0, "questions": 0, "overrides": 0}
    for key, members in groups.items():
        if len(members) < 2:
            continue
        semantics = {}
        for member in members:
            options = load_options(member["options_hindi"]) or []
            answer = member["answer"]
            if not isinstance(answer, int) or answer < 0 or answer >= len(options):
                continue
            semantics.setdefault(norm_lower(options[answer]), []).append(member)
        if len(semantics) <= 1:
            continue

        # The human verified override wins.
        authoritative = None
        for member in members:
            override = ANSWER_KEY_OVERRIDES.get(member["id"])
            if override is None:
                continue
            options = load_options(member["options_hindi"]) or []
            if 0 <= override < len(options):
                authoritative = norm_lower(options[override])
                stats["overrides"] += 1
                break

        # Otherwise the official board paper wins.
        if authoritative is None:
            for member in members:
                if OFFICIAL_SOURCE_MARKER in (member["source_tag"] or ""):
                    options = load_options(member["options_hindi"]) or []
                    answer = member["answer"]
                    if 0 <= answer < len(options):
                        authoritative = norm_lower(options[answer])
                        break

        # Otherwise the majority wins.
        if authoritative is None:
            authoritative = max(
                semantics.items(), key=lambda item: len(item[1])
            )[0]

        stats["groups"] += 1
        for member in members:
            options = load_options(member["options_hindi"]) or []
            index = next(
                (
                    position
                    for position, option in enumerate(options)
                    if norm_lower(option) == authoritative
                ),
                None,
            )
            if index is None or index == member["answer"]:
                continue
            conn.execute(
                "UPDATE questions SET answer = ? WHERE id = ?", (index, member["id"])
            )
            stats["questions"] += 1

    # Overrides for questions that are not part of a conflict group.
    for qid, answer in ANSWER_KEY_OVERRIDES.items():
        row = conn.execute(
            "SELECT options_hindi, answer FROM questions WHERE id = ?", (qid,)
        ).fetchone()
        if row is None:
            continue
        options = load_options(row["options_hindi"]) or []
        if not (0 <= answer < len(options)):
            continue
        if row["answer"] == answer:
            continue
        conn.execute("UPDATE questions SET answer = ? WHERE id = ?", (answer, qid))
        stats["questions"] += 1
    return stats


def repair_orphan_questions(conn: sqlite3.Connection) -> dict:
    """Replace questions whose reading or figure is not part of the vault.

    Such a question cannot be answered by a candidate.  The slot is refilled
    with a self contained question of the same section, so the paper stays
    complete and every printed question can be answered.
    """
    replaced = 0
    taken_donors: set[str] = set()
    for qid in sorted(ORPHAN_QUESTION_IDS):
        target = conn.execute("SELECT * FROM questions WHERE id = ?", (qid,)).fetchone()
        if target is None:
            continue
        if target["passage_id"]:
            continue
        # Only repair a question while it still carries the broken stem.
        original = ORPHAN_ORIGINAL_STEMS.get(qid)
        if original and normalize(target["q_hindi"]) != normalize(original):
            continue

        papers = [
            row[0]
            for row in conn.execute(
                "SELECT paper_form_id FROM appearances WHERE question_id = ?", (qid,)
            ).fetchall()
        ]
        used: set[str] = set()
        for paper in papers:
            for row in conn.execute(
                "SELECT q.q_hindi, q.q_english FROM appearances a "
                "JOIN questions q ON q.id = a.question_id WHERE a.paper_form_id = ?",
                (paper,),
            ).fetchall():
                used.add(norm_lower(row[0]))
                used.add(norm_lower(row[1]))

        donor = None
        fallback = None
        for candidate in conn.execute(
            "SELECT * FROM questions WHERE section = ? "
            "AND (passage_id IS NULL OR passage_id = '') AND id <> ? ORDER BY id",
            (target["section"], qid),
        ).fetchall():
            if candidate["id"] in ORPHAN_QUESTION_IDS:
                continue
            if not (candidate["q_hindi"] or "").strip():
                continue
            if norm_lower(candidate["q_hindi"]) in used:
                continue
            options = load_options(candidate["options_hindi"]) or []
            answer = candidate["answer"]
            if not options or not isinstance(answer, int) or not (0 <= answer < len(options)):
                continue
            if stem_anchor_violation(
                candidate["q_hindi"] or "", candidate["q_english"] or ""
            ):
                continue
            if option_anchor_violation(
                options, load_options(candidate["options_english"]) or []
            ):
                continue
            if fallback is None:
                fallback = candidate
            if candidate["id"] in taken_donors:
                continue
            donor = candidate
            break
        if donor is None:
            donor = fallback

        if donor is None:
            print(f"  WARNING: no donor found for orphan question {qid}")
            continue

        conn.execute(
            "UPDATE questions SET q_hindi = ?, q_english = ?, options_hindi = ?, "
            "options_english = ?, answer = ?, p_score = ?, topic_name = ?, "
            "difficulty = ? WHERE id = ?",
            (
                donor["q_hindi"],
                donor["q_english"],
                donor["options_hindi"],
                donor["options_english"],
                donor["answer"],
                donor["p_score"],
                donor["topic_name"],
                donor["difficulty"],
                qid,
            ),
        )
        replaced += 1
        taken_donors.add(donor["id"])
    return {"replaced": replaced}


def repair_option_texts(conn: sqlite3.Connection) -> dict:
    """Apply the small option level corrections."""
    changed = 0
    for qid, fixes in OPTION_TEXT_FIXES.items():
        row = conn.execute(
            "SELECT options_hindi FROM questions WHERE id = ?", (qid,)
        ).fetchone()
        if row is None:
            continue
        options = load_options(row["options_hindi"])
        if not options:
            continue
        updated = list(options)
        dirty = False
        for index, text in fixes.items():
            if 0 <= index < len(updated) and updated[index] != text:
                updated[index] = text
                dirty = True
        if dirty:
            conn.execute(
                "UPDATE questions SET options_hindi = ? WHERE id = ?",
                (
                    json.dumps(updated, ensure_ascii=False, separators=(",", ":")),
                    qid,
                ),
            )
            changed += 1
    return {"changed": changed}


def repair_english_alignment(conn: sqlite3.Connection) -> dict:
    """Restore the English side of questions whose English data was stolen.

    The source dump carried a *shifted English column*: a question kept the
    English stem or the English option list of the question that follows it.
    The Hindi side of those questions is correct, so the English side is
    restored from the clean copy of the same question (or from the curated
    text when the question only exists once).

    The repair is idempotent: a question that already carries the correct
    English text is not touched.
    """
    stats = {"stems": 0, "options": 0, "answers": 0}

    for qid, stem in ENGLISH_STEM_FIXES.items():
        row = conn.execute(
            "SELECT q_english FROM questions WHERE id = ?", (qid,)
        ).fetchone()
        if row is None or (row[0] or "") == stem:
            continue
        conn.execute("UPDATE questions SET q_english = ? WHERE id = ?", (stem, qid))
        stats["stems"] += 1

    for qid, donor_id in ENGLISH_OPTION_COPIES.items():
        donor = conn.execute(
            "SELECT options_english FROM questions WHERE id = ?", (donor_id,)
        ).fetchone()
        row = conn.execute(
            "SELECT options_english FROM questions WHERE id = ?", (qid,)
        ).fetchone()
        if donor is None or row is None or row[0] == donor[0]:
            continue
        conn.execute(
            "UPDATE questions SET options_english = ? WHERE id = ?",
            (donor[0], qid),
        )
        stats["options"] += 1

    for qid, options in ENGLISH_OPTION_FIXES.items():
        row = conn.execute(
            "SELECT options_english FROM questions WHERE id = ?", (qid,)
        ).fetchone()
        if row is None:
            continue
        payload = json.dumps(options, ensure_ascii=False, separators=(",", ":"))
        if row[0] == payload:
            continue
        conn.execute(
            "UPDATE questions SET options_english = ? WHERE id = ?", (payload, qid)
        )
        stats["options"] += 1

    for qid, answer in ANSWER_INDEX_FIXES.items():
        row = conn.execute(
            "SELECT answer FROM questions WHERE id = ?", (qid,)
        ).fetchone()
        if row is None or row[0] == answer:
            continue
        conn.execute("UPDATE questions SET answer = ? WHERE id = ?", (answer, qid))
        stats["answers"] += 1

    return stats


def repair_database() -> None:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    try:
        conn.execute("BEGIN")

        row = conn.execute(
            "SELECT body FROM passages WHERE id = ?", (CORRUPT_PASSAGE_ID,)
        ).fetchone()
        if row is None:
            raise SystemExit(f"Corrupt passage {CORRUPT_PASSAGE_ID} is missing from SQLite")
        clean_body = clean_corrupt_body(row[0])
        conn.execute(
            "UPDATE passages SET body = ?, dir_text = ?, kind = 'prose' WHERE id = ?",
            (clean_body, CLEAN_DIRECTION, CORRUPT_PASSAGE_ID),
        )

        # Detach standalone grammar items and re-index their former passages.
        affected_passages: set[str] = set()
        for qid in DETACH_QUESTION_IDS:
            found = conn.execute(
                "SELECT passage_id FROM questions WHERE id = ?", (qid,)
            ).fetchone()
            if found and found[0]:
                affected_passages.add(found[0])
            conn.execute(
                "UPDATE questions SET passage_id = NULL, seq_in_passage = NULL WHERE id = ?",
                (qid,),
            )
        for passage_id in affected_passages:
            reindex_passage(conn, passage_id)

        # Attach the five actual comprehension questions.
        for qid, seq in COMPREHENSION_MAP.items():
            conn.execute(
                "UPDATE questions SET passage_id = ?, seq_in_passage = ?, answer = ? WHERE id = ?",
                (CORRUPT_PASSAGE_ID, seq, COMPREHENSION_ANSWERS[qid], qid),
            )
        for qid, answer in GRAMMAR_ANSWER_FIXES.items():
            conn.execute("UPDATE questions SET answer = ? WHERE id = ?", (answer, qid))

        for qid, answer in GENERAL_ANSWER_FIXES.items():
            conn.execute("UPDATE questions SET answer = ? WHERE id = ?", (answer, qid))

        for qid, texts in QUESTION_TEXT_FIXES.items():
            conn.execute(
                "UPDATE questions SET q_hindi = ?, q_english = ? WHERE id = ?",
                (texts["qh"], texts["qe"], qid),
            )
        for qid, (options_hi, options_en) in OPTION_FIGURE_FIXES.items():
            conn.execute(
                "UPDATE questions SET options_hindi = ?, options_english = ? WHERE id = ?",
                (
                    json.dumps(options_hi, ensure_ascii=False, separators=(",", ":")),
                    json.dumps(options_en, ensure_ascii=False, separators=(",", ":")),
                    qid,
                ),
            )

        # Every Paper-2 form carries both optional streams (210 appearance
        # rows), but a candidate only attempts 150 questions.  The visible
        # total must therefore be 150, not 210.
        conn.execute("UPDATE paper_forms SET total_questions = 150 WHERE total_questions <> 150")

        # User generated data must never ship inside the bundled asset:
        # a fresh install would otherwise post the developer's old error
        # reports to the tracker again and again.
        for table in ("question_reports", "mistake_records", "test_history"):
            try:
                conn.execute(f"DELETE FROM {table}")
            except sqlite3.OperationalError:
                pass

        # Content integrity: unique questions per paper, contiguous passage
        # groups, answerable stems and a single source of truth for the key.
        repositioned = fix_passage_positions(conn)
        merged = split_merged_passages(conn)
        reattached = attach_orphan_questions(conn)
        orphans = replace_passage_orphans(conn)
        refilled = replace_unanswerable_questions(conn)
        english = repair_foreign_english(conn)
        keys = repair_answer_key_conflicts(conn)
        texts = repair_option_texts(conn)
        orphan_questions = repair_orphan_questions(conn)
        alignment = repair_english_alignment(conn)
        normalise_modules(conn)
        topics = sync_topic_indexes(conn)
        renumber_passages(conn)
        empty = drop_empty_passages(conn)
        # The replacements can create a repeated question, so the de-duplication
        # runs last.
        swapped = dedupe_paper_questions(conn)
        # The printed key has to be re-synchronised after the de-duplication,
        # because that step swaps the questions of two paper slots.
        synced = sync_official_answer_keys(conn)

        conn.execute(
            "INSERT INTO meta(key, val) VALUES('bank_version', ?) "
            "ON CONFLICT(key) DO UPDATE SET val = excluded.val",
            (str(VAULT_VERSION),),
        )
        # The marker of the bundled version travels with the asset, so a
        # device never mistakes a downloaded (newer) bank for the bundle.
        conn.execute(
            "INSERT INTO meta(key, val) VALUES('bundled_version', ?) "
            "ON CONFLICT(key) DO UPDATE SET val = excluded.val",
            (str(VAULT_VERSION),),
        )

        conn.commit()
        print("SQLite vault repaired")
        print(
            f"  duplicate paper questions swapped : {swapped}\n"
            f"  passage positions fixed          : {repositioned}\n"
            f"  merged passages split           : {merged}\n"
            f"  questions re-attached to a text : {reattached}\n"
            f"  orphan questions replaced        : {orphans}\n"
            f"  unanswerable slots refilled      : {refilled}\n"
            f"  english translations restored    : {english['stem']} stems / "
            f"{english['options']} option lists"
            f"{' (UNRESOLVED: %d)' % english['unresolved'] if english['unresolved'] else ''}\n"
            f"  conflicting answer keys fixed    : {keys['groups']} groups / "
            f"{keys['questions']} questions\n"
            f"  option texts corrected           : {texts['changed']}\n"
            f"  stimulus-less questions replaced : {orphan_questions['replaced']}\n"
            f"  english alignment restored      : {alignment['stems']} stems / "
            f"{alignment['options']} option lists / {alignment['answers']} answer keys\n"
            f"  answer keys re-synchronised      : {synced}\n"
            f"  topic indexes aligned            : {topics}\n"
            f"  empty readings removed           : {empty}"
        )
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def repair_papers_json() -> None:
    path = CDN_DIR / "papers.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    changed = False
    if data.get("version") != VAULT_VERSION:
        data["version"] = VAULT_VERSION
        changed = True
    for form in data.get("forms", []):
        if form.get("total_questions") != 150:
            form["total_questions"] = 150
            changed = True
    if changed:
        write_json(path, data)
        print("papers.json paper totals/version normalised")


def update_manifest(new_pack_entries: dict[str, dict]) -> None:
    manifest_path = CDN_DIR / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))

    for pack in manifest.get("packs", []):
        old_file = pack.get("file", "")
        index = Path(old_file).name.split("-")[1] if "-" in Path(old_file).name else ""
        replacement = new_pack_entries.get(index)
        if replacement:
            pack.update(replacement)
            pack["id"] = f"{index}-{replacement['sha256'][:12]}"

    papers_path = CDN_DIR / "papers.json"
    papers_bytes = papers_path.read_bytes()
    manifest["papers_file"] = {
        "file": "papers.json",
        "sha256": sha256_bytes(papers_bytes),
        "bytes": len(papers_bytes),
        "forms_count": len(json.loads(papers_bytes)["forms"]),
        "appearances_count": len(json.loads(papers_bytes)["appearances"]),
    }

    manifest["bank_version"] = VAULT_VERSION
    manifest["bank_version_str"] = VAULT_VERSION_STR
    manifest["generated"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    write_pretty_json(manifest_path, manifest)
    print(f"manifest.json updated to v{VAULT_VERSION}")

    # Store the new version and download signature in the bundled vault so
    # the app does not immediately re-download the same data.
    signature = ";".join(
        f"{pack.get('file', '')}_{pack.get('sha256', '')}"
        for pack in manifest.get("packs", [])
    )
    conn = sqlite3.connect(DB_PATH)
    try:
        conn.execute("BEGIN")
        for key, value in (
            ("bank_version", str(VAULT_VERSION)),
            ("packs_signature", signature),
            ("last_synced", datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")),
        ):
            conn.execute(
                "INSERT INTO meta(key, val) VALUES(?, ?) "
                "ON CONFLICT(key) DO UPDATE SET val = excluded.val",
                (key, value),
            )
        conn.commit()
    finally:
        conn.close()


def main() -> None:
    if not DB_PATH.exists():
        raise SystemExit(f"Database not found: {DB_PATH}")
    changed_packs = repair_packs()
    repair_papers_json()
    repair_database()
    update_manifest(changed_packs)
    rebuild_cdn_packs()
    print("Repair complete. Run: python scripts/validate_vault.py")


def rebuild_cdn_packs() -> None:
    """Rebuild the CDN packs from the repaired database.

    The packs are a copy of the vault.  Regenerating them from the repaired
    database guarantees that the CDN and the bundled asset can never drift
    apart - the validator compares their hashes.
    """
    sys.path.insert(0, str(ROOT / "bin"))
    try:
        from build_github_cdn_vault import build_cdn
    except ImportError as error:  # pragma: no cover - defensive
        print(f"  WARNING: could not rebuild the CDN packs ({error})")
        return
    build_cdn(ROOT)
    print("CDN packs rebuilt from the repaired database")


if __name__ == "__main__":
    main()

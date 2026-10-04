#!/usr/bin/env python3
"""Builds production CDN packs and manifest.json from bank-v2 SQLite database.
Guarantees 100% sync consistency with the Flutter mobile app (tet_app).
"""
import hashlib
import json
import os
import shutil
import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2] # tet_repo
WORKSPACE_ROOT = REPO_ROOT.parent
APP_DB = WORKSPACE_ROOT / "tet_app" / "assets" / "database" / "tet_mock_vault.db"
if not APP_DB.exists():
    APP_DB = REPO_ROOT / "runtime" / "tet_mock_vault.db"

CDN_DIR = REPO_ROOT / "cdn"
PACKS_DIR = CDN_DIR / "packs"
CHUNK_SIZE = 200

def sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def main():
    sys.stdout.reconfigure(encoding="utf-8")
    print(f"Reading questions and passages from {APP_DB}...")
    if not APP_DB.exists():
        print(f"Error: {APP_DB} does not exist! Please run build_app_db.py first.")
        return 1

    conn = sqlite3.connect(APP_DB)
    cur = conn.cursor()

    # 1. Fetch all passages
    cur.execute("SELECT id, kind, dir_text, body FROM passages ORDER BY id")
    passages_dict = {}
    for pid, kind, dir_text, body in cur.fetchall():
        passages_dict[pid] = {
            "id": pid,
            "k": kind or "prose",
            "d": dir_text or "",
            "b": body or ""
        }
    print(f"Loaded {len(passages_dict)} passages.")

    # 2. Fetch all questions
    cur.execute("""
        SELECT id, exams, section, topic_index, topic_name, difficulty,
               q_hindi, options_hindi, q_english, options_english,
               answer, p_score, years, passage_id, seq_in_passage
        FROM questions
        ORDER BY exams, section, id
    """)
    rows = cur.fetchall()
    print(f"Loaded {len(rows)} questions.")

    # Define standard topics
    topics = [
        "बाल विकास एवं शिक्षणशास्त्र",
        "हिन्दी भाषा",
        "English Language",
        "गणित एवं शिक्षणशास्त्र",
        "पर्यावरण अध्ययन",
        "संस्कृत भाषा",
        "विज्ञान",
        "सामाजिक अध्ययन"
    ]
    section_to_tidx = {
        "cdp": 0,
        "hindi": 1,
        "english": 2,
        "math": 3,
        "evs": 4,
        "sanskrit": 5,
        "science": 6,
        "social": 7
    }

    # Prepare question objects for packing
    questions_list = []
    section_counts = {}
    for r in rows:
        qid, exams, sec, tidx, tname, diff, qh, oh, qe, oe, ans, p_score, years, pid, seq = r
        section_counts[sec] = section_counts.get(sec, 0) + 1
        t_index = section_to_tidx.get(sec, tidx or 0)
        
        oh_list = json.loads(oh) if oh else []
        oe_list = json.loads(oe) if oe else None

        q_obj = {
            "k": qid,
            "e": exams,
            "s": sec,
            "t": t_index,
            "d": diff or 2,
            "qh": qh,
            "oh": oh_list,
            "a": ans,
            "p": round(p_score, 4) if p_score else 0.85,
        }
        if qe and qe.strip():
            q_obj["qe"] = qe
        if oe_list:
            q_obj["oe"] = oe_list
        if years and years.strip():
            q_obj["y"] = years
        if pid and pid.strip():
            q_obj["pid"] = pid
        if seq is not None:
            q_obj["n"] = seq

        questions_list.append(q_obj)

    # 3. Clean and prepare packs directory
    if PACKS_DIR.exists():
        shutil.rmtree(PACKS_DIR)
    PACKS_DIR.mkdir(parents=True, exist_ok=True)

    # 4. Partition into chunked packs
    packs_manifest = []
    total_q = len(questions_list)
    pack_idx = 0

    assigned_passages = set()

    for i in range(0, total_q, CHUNK_SIZE):
        chunk = questions_list[i : i + CHUNK_SIZE]
        chunk_sections = sorted(list(set(q["s"] for q in chunk)))

        # Find passages required by questions in this chunk
        chunk_passages = []
        for q in chunk:
            pid = q.get("pid")
            if pid and pid in passages_dict and pid not in assigned_passages:
                chunk_passages.append(passages_dict[pid])
                assigned_passages.add(pid)

        pack_data = {
            "p": chunk_passages,
            "q": chunk
        }

        pack_bytes = json.dumps(pack_data, ensure_ascii=False, separators=(',', ':')).encode("utf-8")
        pack_hash = sha256_hex(pack_bytes)
        pack_short_hash = pack_hash[:12]
        pack_filename = f"packs/pack-{pack_idx:04d}-{pack_short_hash}.json"
        pack_full_path = CDN_DIR / pack_filename

        with open(pack_full_path, "wb") as f:
            f.write(pack_bytes)

        packs_manifest.append({
            "id": f"{pack_idx:04d}",
            "file": pack_filename,
            "sha256": pack_hash,
            "bytes": len(pack_bytes),
            "count": len(chunk),
            "sections": chunk_sections
        })
        pack_idx += 1

    # Any remaining passages not yet assigned put in pack 0000
    if len(assigned_passages) < len(passages_dict):
        rem_passages = [p for pid, p in passages_dict.items() if pid not in assigned_passages]
        first_pack_info = packs_manifest[0]
        first_pack_path = CDN_DIR / first_pack_info["file"]
        with open(first_pack_path, "r", encoding="utf-8") as f:
            first_data = json.load(f)
        first_data["p"].extend(rem_passages)
        new_bytes = json.dumps(first_data, ensure_ascii=False, separators=(',', ':')).encode("utf-8")
        new_hash = sha256_hex(new_bytes)
        new_filename = f"packs/pack-0000-{new_hash[:12]}.json"
        first_pack_path.unlink()
        with open(CDN_DIR / new_filename, "wb") as f:
            f.write(new_bytes)
        first_pack_info["file"] = new_filename
        first_pack_info["sha256"] = new_hash
        first_pack_info["bytes"] = len(new_bytes)

    # 5. Build manifest.json
    now_iso = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    manifest = {
        "schema": 1,
        "bank_version": 20261004,
        "generated": now_iso,
        "topics": topics,
        "total": total_q,
        "pyq_count": total_q,
        "avg_p": 0.85,
        "sections": section_counts,
        "packs": packs_manifest
    }

    manifest_path = CDN_DIR / "manifest.json"
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)

    conn.close()

    print(f"Successfully generated CDN packs and manifest:")
    print(f" - Manifest: {manifest_path}")
    print(f" - Total Packs: {len(packs_manifest)}")
    print(f" - Total Questions: {total_q}")
    print(f" - Sections: {section_counts}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())

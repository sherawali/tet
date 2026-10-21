import sqlite3
import json
import os
import hashlib
from datetime import datetime

def build_cdn():
    db_path = 'assets/database/tet_mock_vault.db'
    cdn_dir = 'cdn'
    packs_dir = os.path.join(cdn_dir, 'packs')
    os.makedirs(packs_dir, exist_ok=True)

    # 1. Connect to SQLite
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()

    # 2. Fetch Topics
    cur.execute("SELECT DISTINCT topic_name FROM questions WHERE topic_name IS NOT NULL AND topic_name != '' ORDER BY topic_name")
    topics = [r[0] for r in cur.fetchall()]
    topic_to_idx = {t: i for i, t in enumerate(topics)}

    # 3. Fetch all Passages
    cur.execute("SELECT id, kind, dir_text, body FROM passages")
    passages_dict = {}
    for r in cur.fetchall():
        pid, kind, dir_text, body = r
        passages_dict[pid] = {
            'id': pid,
            'k': kind or 'prose',
            'd': dir_text or '',
            'b': body or ''
        }

    # 4. Fetch all 9,720 questions ordered deterministically
    cur.execute("""
        SELECT id, exams, section, topic_index, topic_name, difficulty,
               q_hindi, options_hindi, q_english, options_english,
               answer, p_score, years, source_tag, passage_id, seq_in_passage
        FROM questions
        ORDER BY section, id
    """)
    rows = cur.fetchall()
    total_q = len(rows)

    print(f"Total questions to package: {total_q}")
    print(f"Total topics: {len(topics)}")
    print(f"Total passages: {len(passages_dict)}")

    # 5. Pack in chunks of 200
    chunk_size = 200
    pack_records = []
    written_pack_names = set()
    section_counts = {}

    for chunk_idx in range(0, total_q, chunk_size):
        chunk_rows = rows[chunk_idx:chunk_idx + chunk_size]
        q_list = []
        needed_pids = set()
        pack_sections = set()

        for r in chunk_rows:
            (qid, exams, section, t_idx, t_name, diff,
             qh, oh_raw, qe, oe_raw,
             ans, p_score, years, source_tag, pid, seq) = r

            section_counts[section] = section_counts.get(section, 0) + 1
            pack_sections.add(section)

            try:
                oh = json.loads(oh_raw) if oh_raw else []
            except:
                oh = []

            try:
                oe = json.loads(oe_raw) if oe_raw else None
            except:
                oe = None

            t_index = topic_to_idx.get(t_name, t_idx or 0)

            q_obj = {
                'k': qid,
                'e': exams or '',
                's': section or '',
                't': t_index,
                'd': diff if diff is not None else 2,
                'qh': qh or '',
                'oh': oh,
                'a': ans if ans is not None else 0,
            }
            if qe and qe.strip():
                q_obj['qe'] = qe
            if oe:
                q_obj['oe'] = oe
            if p_score is not None and p_score > 0:
                q_obj['p'] = p_score
            if years and years.strip():
                q_obj['y'] = years
            if pid and pid.strip():
                q_obj['pid'] = pid
                needed_pids.add(pid)
            if seq is not None:
                q_obj['n'] = seq

            q_list.append(q_obj)

        # Iterate the set in a stable order.  Otherwise Python's per-process
        # string hash seed changes the pack byte order (and therefore every
        # hash-based pack filename) on each build.
        p_list = [passages_dict[p] for p in sorted(needed_pids) if p in passages_dict]

        pack_num = chunk_idx // chunk_size
        pack_content = {
            'pack_index': pack_num,
            'count': len(q_list),
            'q': q_list,
            'p': p_list
        }

        pack_json_bytes = json.dumps(pack_content, ensure_ascii=False, separators=(',', ':')).encode('utf-8')
        sha = hashlib.sha256(pack_json_bytes).hexdigest()
        short_sha = sha[:12]
        pack_filename = f"pack-{pack_num:04d}-{short_sha}.json"
        pack_filepath = os.path.join(packs_dir, pack_filename)

        with open(pack_filepath, 'wb') as pf:
            pf.write(pack_json_bytes)
        written_pack_names.add(pack_filename)

        pack_records.append({
            'id': f"{pack_num:04d}-{short_sha}",
            'file': f"packs/{pack_filename}",
            'sha256': sha,
            'bytes': len(pack_json_bytes),
            'count': len(q_list),
            'sections': sorted(list(pack_sections))
        })

    # Remove packs left behind by earlier builds/hash changes so the folder
    # always matches the manifest exactly.
    for existing_name in os.listdir(packs_dir):
        if (
            existing_name.startswith("pack-")
            and existing_name.endswith(".json")
            and existing_name not in written_pack_names
        ):
            os.remove(os.path.join(packs_dir, existing_name))

    # 6. Extract paper_forms and appearances for full remote paper support
    cur.execute("SELECT id, exam, paper, exam_date, set_code, title, total_questions, modules_json FROM paper_forms ORDER BY id")
    forms_rows = cur.fetchall()
    forms_list = []
    for r in forms_rows:
        forms_list.append({
            'id': r[0],
            'exam': r[1],
            'paper': r[2],
            'exam_date': r[3],
            'set_code': r[4],
            'title': r[5],
            'total_questions': r[6],
            'modules_json': r[7]
        })

    cur.execute("SELECT id, question_id, paper_form_id, section, question_number, official_option_id FROM appearances ORDER BY paper_form_id, question_number")
    appearances_rows = cur.fetchall()
    appearances_list = [list(r) for r in appearances_rows]

    papers_data = {
        'version': 2026102020,
        'forms': forms_list,
        'appearances': appearances_list
    }
    papers_json_bytes = json.dumps(papers_data, ensure_ascii=False, separators=(',', ':')).encode('utf-8')
    papers_sha = hashlib.sha256(papers_json_bytes).hexdigest()
    papers_path = os.path.join(cdn_dir, 'papers.json')
    with open(papers_path, 'wb') as pf:
        pf.write(papers_json_bytes)
    print(f"Total paper forms exported: {len(forms_list)}")
    print(f"Total appearances exported: {len(appearances_list)} (File size: {len(papers_json_bytes)/1024:.1f} KB)")

    # 7. Build Manifest with remote_config
    manifest = {
        'schema': 2,
        'bank_version': 2026102020,
        'bank_version_str': '20261021_master_vault_clean_v20',
        'generated': datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'),
        'total': total_q,
        'papers_count': len(forms_list),
        'topics': topics,
        'sections': section_counts,
        'packs': pack_records,
        'papers_file': {
            'file': 'papers.json',
            'sha256': papers_sha,
            'bytes': len(papers_json_bytes),
            'forms_count': len(forms_list),
            'appearances_count': len(appearances_list)
        },
        'remote_config': {
            'free_mock_count': 1,
            'free_form_ids': [
                'utet-p1-fullmock',
                'utet-p2-set-b',
                'ctet-p1-2026-pyq',
                'ctet-p2-ms-mock-01',
                'ctet-p2-sst-mock-01'
            ],
            'paid_form_ids': [],
            'all_mocks_free': False
        }
    }

    manifest_path = os.path.join(cdn_dir, 'manifest.json')
    with open(manifest_path, 'w', encoding='utf-8') as mf:
        json.dump(manifest, mf, ensure_ascii=False, indent=2)

    # 8. Flash Messages (Keep existing bilingual messages)
    flash_path = os.path.join(cdn_dir, 'flash_messages.json')
    if not os.path.exists(flash_path):
        flash = {
            'version': 3,
            'last_updated': datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'),
            'messages': [
                {
                    'id': 'live_flash_2026_master',
                    'title': '🔥 UTET & CTET 2026: 9,720 प्रश्नों का सम्पूर्ण मास्टर बैंक लाइव!',
                    'title_en': '🔥 UTET & CTET 2026: 9,720 Question Master Vault Live!',
                    'message': 'सभी 62 ओरिजिनल पेपर्स और मॉडल सेट्स 100% प्रामाणिक हल सहित उपलब्ध हैं। OMR व CBT मोड में अभी अभ्यास करें।',
                    'message_en': 'All 62 original board papers & model mock sets available with verified pedagogical solutions. Practice in OMR or CBT mode now.',
                    'action_label': 'मॉक सीरीज़ देखें',
                    'action_label_en': 'View Mock Series',
                    'type': 'notice',
                    'dismissible': True,
                    'active': True
                }
            ]
        }
        with open(flash_path, 'w', encoding='utf-8') as ff:
            json.dump(flash, ff, ensure_ascii=False, indent=2)

    conn.close()
    print("=" * 80)
    print(f"SUCCESS: CDN VAULT CREATED AT '{cdn_dir}/'!")
    print(f"Total Questions: {total_q}")
    print(f"Total Packs Created: {len(pack_records)}")
    print(f"Sections Breakdown: {section_counts}")
    print("=" * 80)

if __name__ == '__main__':
    build_cdn()

import sqlite3
import json
import os
import hashlib
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]



DEFAULT_REMOTE_ACCESS = {
    'free_mock_count': 2,
    'free_form_ids': [
        'utet-p1-fullmock',
        'ctet-p1-2026-pyq',
    ],
    'paid_form_ids': [],
    'all_mocks_free': False,
}


def remote_access_config():
    """The free / paid lists live in `bin/remote_access.json`.

    The app reads them from the manifest, so a paper can be switched between
    free and paid without a new app release.
    """
    config = dict(DEFAULT_REMOTE_ACCESS)
    path = os.path.join(
        os.path.dirname(os.path.abspath(__file__)), 'remote_access.json'
    )
    try:
        with open(path, 'r', encoding='utf-8') as handle:
            stored = json.load(handle)
        for key in DEFAULT_REMOTE_ACCESS:
            if key in stored:
                config[key] = stored[key]
        print('Remote access config read from bin/remote_access.json')
    except Exception as error:  # the file is optional
        print(f'Remote access config not usable ({error}), using the defaults')
    return config



BASE_VERSION = 2026102020


def next_bank_version(pack_records, papers_sha, manifest_path):
    """The version of the manifest, raised when the content changed.

    The phone only downloads a new bank when the version is higher, the
    question count changed or the packs have a new signature.  A new paper
    that only adds appearances does not change the question count, so the
    version has to rise here.
    """
    old_version = BASE_VERSION
    old_signature = ''
    if os.path.exists(manifest_path):
        try:
            with open(manifest_path, 'r', encoding='utf-8') as handle:
                old = json.load(handle)
            old_version = int(old.get('bank_version') or BASE_VERSION)
            old_signature = ';'.join(
                f"{p.get('file', '')}_{p.get('sha256', '')}" for p in old.get('packs', [])
            )
            old_papers = (old.get('papers_file') or {}).get('sha256', '')
        except Exception:
            old_papers = ''
    else:
        old_papers = ''

    new_signature = ';'.join(
        f"{p.get('file', '')}_{p.get('sha256', '')}" for p in pack_records
    )
    changed = (new_signature != old_signature) or (papers_sha != old_papers)
    if changed and old_version >= BASE_VERSION:
        version = old_version + 1
        print(f'Bank content changed -> bank version {old_version} -> {version}')
        return version
    print(f'Bank content unchanged, keeping bank version {old_version}')
    return old_version


def bank_version_str(version):
    """The readable name of a bank version."""
    stamp = datetime.utcnow().strftime('%Y%m%d')
    return f'{stamp}_master_vault_clean_v{version % 100}'


def build_cdn(root=ROOT):
    root = Path(root)
    db_path = str(root / 'assets' / 'database' / 'tet_mock_vault.db')
    cdn_dir = str(root / 'cdn')
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
        # The version lives in the manifest, not here: a version inside this
        # file would change the file on every build.
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
    # The version has to rise whenever the content changes, otherwise the
    # phone says "up to date" and never downloads the new paper.
    bank_version = next_bank_version(
        pack_records, papers_sha, os.path.join(cdn_dir, 'manifest.json')
    )

    manifest = {
        'schema': 2,
        'bank_version': bank_version,
        'bank_version_str': bank_version_str(bank_version),
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
        'remote_config': remote_access_config()
    }

    manifest_path = os.path.join(cdn_dir, 'manifest.json')
    with open(manifest_path, 'w', encoding='utf-8') as mf:
        json.dump(manifest, mf, ensure_ascii=False, indent=2)

    # 8b. Keep the bundled database in sync with the packs that were just
    # written.  The app compares the stored signature with the signature of
    # the remote manifest; a stale value would make it download the packs
    # again on every start.
    signature = ';'.join(
        f"{pack.get('file', '')}_{pack.get('sha256', '')}"
        for pack in manifest['packs']
    )
    conn.execute('BEGIN')
    for key, value in (
        ('bank_version', str(manifest['bank_version'])),
        ('packs_signature', signature),
        ('last_synced', datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')),
    ):
        conn.execute(
            'INSERT INTO meta(key, val) VALUES(?, ?) '
            'ON CONFLICT(key) DO UPDATE SET val = excluded.val',
            (key, value),
        )
    conn.commit()
    print(f"Bundled database signature synchronised ({len(manifest['packs'])} packs)")

    # 8. Flash Messages - the counts are always taken from the bank, so the
    #    banner can never claim a number that the vault does not have.
    flash_path = os.path.join(cdn_dir, 'flash_messages.json')
    question_count = cur.execute("SELECT COUNT(*) FROM questions").fetchone()[0]
    paper_count = cur.execute("SELECT COUNT(*) FROM paper_forms").fetchone()[0]
    pyq_count = cur.execute(
        "SELECT COUNT(*) FROM paper_forms WHERE exam_date NOT LIKE '%Mock%'"
    ).fetchone()[0]

    def _fmt(value):
        raw = str(value)
        out = []
        for index, char in enumerate(raw):
            if index > 0 and (len(raw) - index) % 3 == 0:
                out.append(',')
            out.append(char)
        return ''.join(out)

    messages = []
    if os.path.exists(flash_path):
        try:
            with open(flash_path, 'r', encoding='utf-8') as ff:
                messages = json.load(ff).get('messages', [])
        except Exception:
            messages = []

    master = {
        'id': 'live_flash_2026_master',
        'title': f'🔥 UTET & CTET 2026: {_fmt(question_count)} प्रश्नों का सम्पूर्ण मास्टर बैंक लाइव!',
        'title_en': f'🔥 UTET & CTET 2026: {_fmt(question_count)} Question Master Vault Live!',
        'message': (
            f'सभी {paper_count} ओरिजिनल पेपर्स और मॉडल सेट्स 100% प्रामाणिक हल सहित उपलब्ध हैं। '
            'OMR व CBT मोड में अभी अभ्यास करें।'
        ),
        'message_en': (
            f'All {paper_count} original board papers & model mock sets available with '
            'verified pedagogical solutions. Practice in OMR or CBT mode now.'
        ),
        'action_label': 'मॉक सीरीज़ देखें',
        'action_label_en': 'View Mock Series',
        'type': 'notice',
        'dismissible': True,
        'active': True,
    }
    messages = [m for m in messages if m.get('id') != master['id']]
    messages.insert(0, master)

    flash = {
        'version': 3,
        'last_updated': datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'),
        'messages': messages,
    }
    with open(flash_path, 'w', encoding='utf-8') as ff:
        json.dump(flash, ff, ensure_ascii=False, indent=2)
    print(f"Flash messages refreshed: {question_count} questions, {paper_count} papers")

    conn.close()
    print("=" * 80)
    print(f"SUCCESS: CDN VAULT CREATED AT '{cdn_dir}/'!")
    print(f"Total Questions: {total_q}")
    print(f"Total Packs Created: {len(pack_records)}")
    print(f"Sections Breakdown: {section_counts}")
    print("=" * 80)

if __name__ == '__main__':
    build_cdn()

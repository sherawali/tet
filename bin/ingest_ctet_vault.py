#!/usr/bin/env python3
"""Ingests all CTET Paper 1 and Paper 2 mocks and PYQs into tet_mock_vault.db
Source directory: C:\\Users\\pujariji\\Desktop\\tetmaster\\ctet
Papers:
- CTET Paper 1 Mocks: mock-01.md to mock-10.md (10 papers x 150Q = 1,500Q)
- CTET Paper 1 Real PYQs: real-ctet-paper1-2016.md to 2026.md (8 papers x 150Q = 1,200Q)
- CTET Paper 2 MS Mocks: mock-ms-01.md to mock-ms-08.md (8 papers x 150Q = 1,200Q)
- CTET Paper 2 SST Mocks: mock-sst-01.md to mock-sst-08.md (8 papers x 150Q = 1,200Q)
Total: 34 papers · 5,100 clean questions.
"""
import sys
import os
import re
import json
import sqlite3
import hashlib
from pathlib import Path

sys.stdout.reconfigure(encoding='utf-8')

CTET_ROOT = Path(r'C:\Users\pujariji\Desktop\tetmaster\ctet')
DB_PATH = Path(r'd:\T\tet_app\assets\database\tet_mock_vault.db')

def clean_text(s):
    if not s: return ''
    t = s.strip()
    t = re.sub(r'^\*{0,2}(?:Q\d*[\.:\)]|\d{1,3}[\.:\)-])\*{0,2}\s+', '', t)
    t = re.sub(r'^\*\*(?:Q(?:uestion)?\.?|\d+[\.:]?)\*\*\s*', '', t, flags=re.I)
    t = re.sub(r'^\*+\s*', '', t)
    t = re.sub(r'\s*\*+$', '', t)
    t = re.sub(r'\[(?:UTET|CTET)[^\]]*\]', '', t, flags=re.I)
    t = re.sub(r'\s+', ' ', t).strip()
    return t

def clean_opt(s):
    if not s: return ''
    t = s.strip()
    if re.fullmatch(r'\([A-D1-4]\)', t):
        return f"Part {t}"
    # Truncate at markdown headers
    t = re.split(r'\n\s*(?:\#{1,6}\s|\*{3,}|-{3,})', t)[0].strip()
    # Truncate at section titles like ## Part II or Part II:
    t = re.split(r'\n\s*(?:##\s*)?(?:भाग|Part)\s*(?:I{1,3}|IV|V|[1-5])\b', t, flags=re.I)[0].strip()
    # Truncate at passage directives like **निम्नलिखित..., **Read the following..., *Directions:
    t = re.split(r'\n\s*(?:\*{1,2})?(?:निम्नलिखित|Read\s+the\s+following|Directions?\s*:|Passage\s*:|काव्यांश\s*को\s*पढ़कर|गद्यांश\s*को\s*पढ़कर)', t, flags=re.I)[0].strip()
    # Truncate at italic passage titles like *बावड़ी..., *बरगद..., *The Stepwells..., *The Banyan...
    t = re.split(r'(?:\n|^|\s{2,})\*[^*]+\*', t)[0].strip()
    # Truncate at answers or tags (require opening bracket for tags)
    t = re.split(r'(?:\n|^|\s{2,})(?:\*\*?(?:Ans|Answer|उत्तर)|\[(?:EN|HI|UTET|CTET)\])', t, flags=re.I)[0].strip()
    # Truncate at next Q marker (only on newline with space)
    t = re.split(r'\n\s*(?:\*\*?Q\d+[\.:]|\d{1,3}\.\s+[A-Za-z\u0900-\u097F])', t)[0].strip()
    # Strip leading markers like (A), A., 1., etc.
    t = re.sub(r'^\([A-D1-4]\)\s*', '', t)
    t = re.sub(r'^[A-D1-4][\.\:]\s+', '', t)
    t = re.sub(r'^\(?[1-4]\)?\s+', '', t)
    t = re.sub(r'^[-*]\s*', '', t)
    t = re.sub(r'\s+', ' ', t).strip()
    return t

def truncate_option_block(content):
    if not content: return ''
    cut_patterns = [
        r'\n\s*#{1,6}\s',
        r'\n\s*[-*]{3,}',
        r'\n\s*(?:\*{1,2})?(?:Passage\s*:|Directions?\s*:|निम्नलिखित|Read\s+the\s+following|काव्यांश\s*को\s*पढ़कर|गद्यांश\s*को\s*पढ़कर)',
        r'\n\s*(?:##\s*)?(?:भाग|Part)\s*(?:I{1,3}|IV|V|[1-5])\b',
        r'\n\s*\*[^*]+\*',
        r'\n\s*\*\*Q\d+\.',
        r'\n\s*\*\*Answer',
        r'\n\s*###',
        r'\n\s*\|\s*-'
    ]
    for cp in cut_patterns:
        content = re.split(cp, content, flags=re.I)[0]
    return content.strip()

def parse_mock_answers(text):
    """Parses **Q1. Answer: (D)** — *Topic* [difficulty]"""
    ans_map = {}
    topic_map = {}
    diff_map = {}
    matches = re.findall(r'\*\*Q(\d+)\.\s*Answer:\s*\(([A-D])\)\*\*(?:\s*[-—]\s*\*([^*]+)\*)?(?:\s*\[([^\]]+)\])?', text)
    for q_num, ans_char, topic, diff in matches:
        q_idx = int(q_num)
        ans_map[q_idx] = ord(ans_char.upper()) - ord('A')
        if topic: topic_map[q_idx] = topic.strip()
        if diff:
            d_str = diff.lower()
            diff_map[q_idx] = 1 if 'easy' in d_str else (3 if 'hard' in d_str else 2)
    return ans_map, topic_map, diff_map

def parse_pyq_table_answers(text):
    """Parses markdown table answers | Q | 1 | 2 | ... | Ans | A | B |"""
    ans_map = {}
    lines = text.splitlines()
    for i, line in enumerate(lines):
        if re.search(r'\|\s*Q\s*\|', line, re.I):
            q_cols = [c.strip() for c in line.split('|')[1:-1]]
            for j in range(i+1, min(i+5, len(lines))):
                if re.search(r'Ans', lines[j], re.I):
                    a_cols = [re.sub(r'[*_\s]', '', c) for c in lines[j].split('|')[1:-1]]
                    for q_str, a_str in zip(q_cols, a_cols):
                        if q_str.isdigit() and a_str in 'ABCD':
                            ans_map[int(q_str)] = ord(a_str.upper()) - ord('A')
                    break
    return ans_map

def determine_section(paper_num, q_num, stream=None):
    if paper_num == 1:
        if q_num <= 30: return 'cdp'
        elif q_num <= 60: return 'math'
        elif q_num <= 90: return 'evs'
        elif q_num <= 120: return 'lang1_hindi'
        else: return 'lang2_english'
    else: # Paper 2
        if q_num <= 30: return 'cdp'
        elif q_num <= 60: return 'lang1_hindi'
        elif q_num <= 90: return 'lang2_english'
        else: return 'math_science' if stream == 'ms' else 'social_studies'

def parse_options_from_block(block):
    """Extracts 4 options labeled (A), (B), (C), (D) from question block robustly"""
    opts_hi = ['', '', '', '']
    opts_en = ['', '', '', '']
    
    # 1. Try finding bulleted sequential options: - (A), - (B), - (C), - (D)
    bullet_matches = list(re.finditer(r'(?:^|\n)\s*[-*]\s*\(([A-D])\)\s*', block))
    if len(bullet_matches) == 4 and [m.group(1).upper() for m in bullet_matches] == ['A', 'B', 'C', 'D']:
        for i in range(4):
            start = bullet_matches[i].end()
            end = bullet_matches[i+1].start() if i < 3 else len(block)
            content = truncate_option_block(block[start:end])
            
            if ' / ' in content:
                parts = content.split(' / ', 1)
                opts_en[i] = clean_opt(parts[0])
                opts_hi[i] = clean_opt(parts[1])
            elif '\n' in content:
                lines = [l.strip() for l in content.splitlines() if l.strip()]
                en_lines = [l for l in lines if not re.search(r'[\u0900-\u097F]', l)]
                hi_lines = [l for l in lines if re.search(r'[\u0900-\u097F]', l)]
                opts_en[i] = clean_opt(' '.join(en_lines)) if en_lines else clean_opt(' '.join(lines))
                opts_hi[i] = clean_opt(' '.join(hi_lines)) if hi_lines else opts_en[i]
            else:
                cleaned = clean_opt(content)
                opts_hi[i] = cleaned
                opts_en[i] = cleaned
        return opts_hi, opts_en

    # 2. Try un-bulleted sequential options: (A), (B), (C), (D) where each starts a line
    seq_matches = list(re.finditer(r'(?:^|\n)\s*\(([A-D])\)\s*', block))
    filtered = []
    expected_idx = 0
    for m in seq_matches:
        char = m.group(1).upper()
        if expected_idx < 4 and char == 'ABCD'[expected_idx]:
            filtered.append(m)
            expected_idx += 1
            
    if len(filtered) == 4:
        for i in range(4):
            start = filtered[i].end()
            end = filtered[i+1].start() if i < 3 else len(block)
            content = truncate_option_block(block[start:end])
            
            if ' / ' in content:
                parts = content.split(' / ', 1)
                opts_en[i] = clean_opt(parts[0])
                opts_hi[i] = clean_opt(parts[1])
            elif '\n' in content:
                lines = [l.strip() for l in content.splitlines() if l.strip()]
                en_lines = [l for l in lines if not re.search(r'[\u0900-\u097F]', l)]
                hi_lines = [l for l in lines if re.search(r'[\u0900-\u097F]', l)]
                opts_en[i] = clean_opt(' '.join(en_lines)) if en_lines else clean_opt(' '.join(lines))
                opts_hi[i] = clean_opt(' '.join(hi_lines)) if hi_lines else opts_en[i]
            else:
                cleaned = clean_opt(content)
                opts_hi[i] = cleaned
                opts_en[i] = cleaned
        return opts_hi, opts_en

    # 3. Fallback to standard regex
    opt_matches = re.findall(r'(?:^|\n)\s*[-*]?\s*\(([A-D])\)\s*(.*?)(?=(?:\n\s*[-*]?\s*\([A-D]\)|\n\s*(?:[-*]{3,}|\#{1,6}\s|\*\*Passage|\*Directions|\*\*Q|\*\*Answer)|\Z))', block, re.DOTALL)
    for char, content in opt_matches:
        idx = ord(char.upper()) - ord('A')
        if 0 <= idx < 4 and not opts_hi[idx]:
            content_clean = truncate_option_block(content)
            if ' / ' in content_clean:
                parts = content_clean.split(' / ', 1)
                opts_en[idx] = clean_opt(parts[0])
                opts_hi[idx] = clean_opt(parts[1])
            elif '\n' in content_clean:
                lines = [l.strip() for l in content_clean.splitlines() if l.strip()]
                en_lines = [l for l in lines if not re.search(r'[\u0900-\u097F]', l)]
                hi_lines = [l for l in lines if re.search(r'[\u0900-\u097F]', l)]
                opts_en[idx] = clean_opt(' '.join(en_lines)) if en_lines else clean_opt(' '.join(lines))
                opts_hi[idx] = clean_opt(' '.join(hi_lines)) if hi_lines else opts_en[idx]
            else:
                cleaned = clean_opt(content_clean)
                opts_hi[idx] = cleaned
                opts_en[idx] = cleaned
                
    return opts_hi, opts_en

def parse_stems_from_block(block, sec=None):
    """Extracts Hindi and English stems from block before options"""
    # Cut off at options: look for bulleted option - (A) or sequential (A) followed by (B)
    opt_pos = re.search(r'(?:^|\n)\s*[-*]\s*\(A\)\s+', block)
    if not opt_pos:
        opt_pos = re.search(r'(?:^|\n)\s*\(A\)\s+.*?(?:^|\n)\s*\(B\)\s+', block, re.DOTALL)
    stem_part = block[:opt_pos.start()] if opt_pos else block
    
    # Strip Q-number line
    lines = [l.strip() for l in stem_part.splitlines() if l.strip()]
    cleaned_lines = []
    for l in lines:
        cleaned = re.sub(r'^\*\*Q\d+\.\*\*\s*', '', l)
        cleaned = re.sub(r'^>\s*', '', cleaned)
        if cleaned:
            cleaned_lines.append(cleaned)
            
    if not cleaned_lines:
        return 'प्रश्न', 'Question'
        
    # Split into English and Hindi lines
    hi_lines = [l for l in cleaned_lines if re.search(r'[\u0900-\u097F]', l)]
    en_lines = [l for l in cleaned_lines if not re.search(r'[\u0900-\u097F]', l)]
    
    stem_hi = clean_text(' '.join(hi_lines)) if hi_lines else clean_text(' '.join(cleaned_lines))
    stem_en = clean_text(' '.join(en_lines)) if en_lines else stem_hi
    
    if sec == 'lang1_hindi':
        stem_en = None
    elif sec == 'lang2_english':
        stem_hi = None
        
    return stem_hi, stem_en

def extract_ctet_passages(text, form_id):
    passages = []
    lines = text.splitlines()
    i = 0
    p_idx = 0
    
    while i < len(lines):
        line = lines[i].strip()
        m_mock = re.match(r'^\*\*Passage:\s*([^*]+)\*\*', line, re.I)
        m_pyq = re.match(r'^(?:\*|\*\*)?(?:निर्देश|Directions?)\b', line, re.I)
        has_kw = bool(re.search(r'(?:गद्यांश|पद्यांश|काव्यांश|कविता|कवितांश|passage|poem)', line, re.I))
        
        if m_mock:
            title = m_mock.group(1).strip()
            body_lines = []
            i += 1
            while i < len(lines) and not lines[i].strip():
                i += 1
            while i < len(lines):
                cur = lines[i].strip()
                if re.match(r'^(?:\*\*)?Q?\d{1,3}\.\s*', cur) or cur.startswith('**Passage') or cur.startswith('###') or cur.startswith('---'):
                    break
                if re.search(r'Answer the following questions', cur, re.I):
                    i += 1
                    break
                clean = re.sub(r'^>\s*', '', lines[i]).rstrip()
                body_lines.append(clean)
                i += 1
            body = '\n'.join(body_lines).strip()
            next_q = None
            for look in range(i, min(i + 15, len(lines))):
                qm = re.search(r'\*\*Q(\d+)\.\*\*', lines[look])
                if qm:
                    next_q = int(qm.group(1))
                    break
            if body and next_q:
                p_idx += 1
                is_poem = bool('कविता' in title or 'काव्यांश' in title or 'poem' in title.lower())
                passages.append({
                    'id': f'{form_id}_p{p_idx}',
                    'title': title,
                    'dir_text': f'गद्यांश: {title}' if not is_poem else f'काव्यांश: {title}',
                    'body': body,
                    'kind': 'poem' if is_poem else 'prose',
                    'q_start': next_q,
                    'q_end': next_q + 5
                })
            continue
            
        elif m_pyq and has_kw:
            dir_text = line.replace('*', '').strip()
            range_m = re.search(r'(?:प्र(?:श्न|\.)\s*(?:संख्या|सं\.)?\s*|[Qq]\.?\s*(?:Nos?\.)?\s*)?(\d{1,3})\s*(?:[–\-to]|से)\s*(\d{1,3})', dir_text)
            q_start, q_end = (None, None)
            if range_m:
                q_start, q_end = int(range_m.group(1)), int(range_m.group(2))
                
            body_lines = []
            i += 1
            while i < len(lines) and not lines[i].strip():
                i += 1
            while i < len(lines):
                cur = lines[i].strip()
                if re.match(r'^(?:\*\*)?Q?\d{1,3}\.\s*', cur) or cur.startswith('**Passage') or cur.startswith('###') or cur.startswith('---'):
                    break
                clean = re.sub(r'^>\s*', '', lines[i]).rstrip()
                body_lines.append(clean)
                i += 1
            body = '\n'.join(body_lines).strip()
            if body and q_start and q_end and 1 <= (q_end - q_start + 1) <= 10:
                p_idx += 1
                is_poem = bool(re.search(r'(?:पद्यांश|काव्यांश|कविता|कवितांश|poem)', dir_text, re.I))
                passages.append({
                    'id': f'{form_id}_p{p_idx}',
                    'title': 'संदर्भ',
                    'dir_text': dir_text,
                    'body': body,
                    'kind': 'poem' if is_poem else 'prose',
                    'q_start': q_start,
                    'q_end': q_end
                })
            continue
            
        i += 1
    return passages

def ingest_ctet_paper(conn, filepath, form_id, exam_date, set_code, title, paper_num, stream=None, is_pyq=False):
    cursor = conn.cursor()
    with open(filepath, 'r', encoding='utf-8') as f:
        text = f.read()

    # 1. Parse Answers
    if is_pyq:
        ans_map = parse_pyq_table_answers(text)
    else:
        ans_map, topic_map, diff_map = parse_mock_answers(text)
        
    # 2. Parse Passages
    passages_list = extract_ctet_passages(text, form_id)
    for p in passages_list:
        cursor.execute('''
            INSERT OR REPLACE INTO passages (id, kind, dir_text, body)
            VALUES (?, ?, ?, ?)
        ''', (p['id'], p['kind'], p['dir_text'], p['body']))

    # 3. Parse Question Blocks
    q_blocks = re.findall(r'(?:\n|^)\*\*Q(\d+)\.\*\*(.*?)(?=(?:\n\*\*Q\d+\.\*\*|\n###\s*Answer|\n\*\*Q\d+\.\s*Answer|\Z))', text, re.S)
    
    if len(q_blocks) < 150:
        print(f'  [WARNING] {filepath.name}: found only {len(q_blocks)} question blocks!')
        return False
        
    modules_json = json.dumps(["cdp", "math", "evs", "hindi", "english"] if paper_num == 1 else ["cdp", "math_science" if stream == "ms" else "social_studies", "hindi", "english"])
    
    # Insert Form
    cursor.execute('''
        INSERT OR REPLACE INTO paper_forms (id, exam, paper, exam_date, set_code, title, total_questions, modules_json)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ''', (form_id, 'ctet', paper_num, exam_date, set_code, title, 150, modules_json))

    q_count = 0


    for q_str, block in q_blocks[:150]:
        q_num = int(q_str)
        ans = ans_map.get(q_num, 0)
        sec = determine_section(paper_num, q_num, stream)
        
        stem_hi, stem_en = parse_stems_from_block(block, sec=sec)
        opts_hi, opts_en = parse_options_from_block(block)
        
        if sec == 'lang1_hindi':
            opts_en = None
        elif sec == 'lang2_english':
            opts_hi = None
            
        active_p = next((p for p in passages_list if p['q_start'] <= q_num <= p['q_end']), None)
        active_passage_id = active_p['id'] if active_p else None
        seq_in_p = (q_num - active_p['q_start'] + 1) if active_p else None
        
        q_id = f'{form_id}_q{q_num:03d}'
        top_name = topic_map.get(q_num, sec) if not is_pyq else sec
        diff = diff_map.get(q_num, 2) if not is_pyq else 2
        
        cursor.execute('''
            INSERT OR REPLACE INTO questions (
                id, exams, section, topic_index, topic_name, difficulty,
                q_hindi, options_hindi, q_english, options_english,
                answer, p_score, years, source_tag, passage_id, seq_in_passage
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            q_id,
            json.dumps(['ctet']),
            sec,
            0,
            top_name,
            diff,
            stem_hi,
            json.dumps(opts_hi, ensure_ascii=False),
            stem_en,
            json.dumps(opts_en, ensure_ascii=False),
            ans,
            0.0,
            json.dumps([exam_date]),
            'ctet',
            active_passage_id,
            seq_in_p if active_passage_id else None
        ))
        
        # Appearance
        app_id = f'{form_id}_app_{q_num:03d}'
        cursor.execute('''
            INSERT OR REPLACE INTO appearances (id, question_id, paper_form_id, section, question_number, official_option_id)
            VALUES (?, ?, ?, ?, ?, ?)
        ''', (app_id, q_id, form_id, sec, q_num, 'ABCD'[ans]))
        
        q_count += 1
        
    print(f'  ✓ Ingested {form_id}: {q_count} questions (Ans: {len(ans_map)} verified)')
    return True

def main():
    print('Starting Master CTET Ingestion into', DB_PATH)
    conn = sqlite3.connect(str(DB_PATH))
    conn.execute('PRAGMA foreign_keys = OFF')
    
    total_papers = 0
    
    # 1. CTET Paper 1 Real PYQs (8 papers)
    print('\n--- Ingesting CTET Paper 1 Real PYQs ---')
    pyq_dir = CTET_ROOT / 'ctet-paper1' / 'real-mocks' / 'hindi-L1__english-L2'
    pyq_years = ['2026', '2024', '2023', '2021', '2020', '2019', '2018', '2016']
    for yr in pyq_years:
        fp = pyq_dir / f'real-ctet-paper1-{yr}.md'
        if fp.exists():
            form_id = f'ctet-p1-{yr}-pyq'
            title = f'CTET {yr} Paper-I विगत वर्ष पेपर'
            ok = ingest_ctet_paper(conn, fp, form_id, yr, yr, title, paper_num=1, is_pyq=True)
            if ok: total_papers += 1
            
    # 2. CTET Paper 1 Fresh Mocks (10 papers)
    print('\n--- Ingesting CTET Paper 1 2026 Model Mocks ---')
    p1_mock_dir = CTET_ROOT / 'ctet-paper1' / 'mocks'
    for i in range(1, 11):
        fp = p1_mock_dir / f'mock-{i:02d}.md'
        if fp.exists():
            form_id = f'ctet-p1-mock-{i:02d}'
            set_code = f'MOCK {i:02d}'
            title = f'CTET Paper-I 2026 मॉडल पेपर {i:02d}'
            ok = ingest_ctet_paper(conn, fp, form_id, '2026-Mock', set_code, title, paper_num=1, is_pyq=False)
            if ok: total_papers += 1
            
    # 3. CTET Paper 2 Math & Science Mocks (8 papers)
    print('\n--- Ingesting CTET Paper 2 Math & Science Mocks ---')
    p2_mock_dir = CTET_ROOT / 'ctet-paper2' / 'mocks'
    for i in range(1, 9):
        fp = p2_mock_dir / f'mock-ms-{i:02d}.md'
        if fp.exists():
            form_id = f'ctet-p2-ms-mock-{i:02d}'
            set_code = f'MS-{i:02d}'
            title = f'CTET Paper-II (गणित एवं विज्ञान) मॉडल पेपर {i:02d}'
            ok = ingest_ctet_paper(conn, fp, form_id, '2026-Mock', set_code, title, paper_num=2, stream='ms', is_pyq=False)
            if ok: total_papers += 1

    # 4. CTET Paper 2 Social Studies Mocks (8 papers)
    print('\n--- Ingesting CTET Paper 2 Social Studies Mocks ---')
    for i in range(1, 9):
        fp = p2_mock_dir / f'mock-sst-{i:02d}.md'
        if fp.exists():
            form_id = f'ctet-p2-sst-mock-{i:02d}'
            set_code = f'SST-{i:02d}'
            title = f'CTET Paper-II (सामाजिक अध्ययन) मॉडल पेपर {i:02d}'
            ok = ingest_ctet_paper(conn, fp, form_id, '2026-Mock', set_code, title, paper_num=2, stream='sst', is_pyq=False)
            if ok: total_papers += 1

    # Update metadata bank_version
    conn.execute('''
        INSERT OR REPLACE INTO meta (key, val) VALUES ('bank_version', '20261018_master_vault_clean_v6')
    ''')
    conn.commit()
    
    # Audit summary
    cur = conn.cursor()
    cur.execute('SELECT exam, paper, count(*) FROM paper_forms GROUP BY exam, paper')
    print('\n=== Final Database Forms Summary ===')
    for row in cur.fetchall():
        print(f'  Exam: {row[0].upper()} | Paper: {row[1]} | Total Sets: {row[2]}')
        
    cur.execute('SELECT count(*) FROM questions')
    print(f'Total Questions in Vault: {cur.fetchone()[0]:,}')
    cur.execute('SELECT count(*) FROM appearances')
    print(f'Total Appearances: {cur.fetchone()[0]:,}')
    conn.close()
    print('\n✓ Successfully completed CTET Ingestion!')

if __name__ == '__main__':
    main()

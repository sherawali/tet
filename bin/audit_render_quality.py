#!/usr/bin/env python3
"""
audit_render_quality.py — Render-quality auditor for the TET question vault.

Finds exactly the class of bugs that break the HTML booklet / WebView rendering:
  1. Passages with missing / tiny / truncated bodies (aadha-ghadyansh).
  2. Passages whose body still contains leaked instruction lines.
  3. Questions wrongly linked / unlinked to passages (seq gaps, range mismatches).
  4. Options with stripped numeric/ratio prefixes ("4 : 11" -> ": 11").
  5. Options with stripped statement markers ("(A), (B) and (C)" -> ", (B) and (C)").
  6. Options containing leaked question text / paragraph blobs (paragraph in options).
  7. Duplicate options (lost content collisions).
  8. Options with leaked next-section headers ("Poem: ...", "गद्यांश: ...").

Usage:
    python3 bin/audit_render_quality.py [--db assets/database/tet_mock_vault.db] [--report]

Exit code 0 = clean, 1 = issues found (useful in CI).
"""
import argparse
import json
import re
import sqlite3
import sys
from collections import defaultdict

sys.stdout.reconfigure(encoding='utf-8')

DEFAULT_DB = 'assets/database/tet_mock_vault.db'

QTEXT_IN_OPTION = re.compile(
    r'(उपर्युक्त|उपरोक्त|Which\s+of\s+the\s+following|NOT\s+appropriate|'
    r'निम्नलिखित\s+में\s+से|Choose\s+the\s+correct|Select\s+the|'
    r'के\s+लिए\s+उपयुक्त|के\s+उत्तर)', re.I)
STRIPPED_RATIO = re.compile(r'^\s*[:,]')
STRIPPED_MARKER = re.compile(r'^\s*[,]\s*\(|^\s*and\s+\(|^\s*(?:और|तथा)\s*\(')
SECTION_LEAK = re.compile(r'(?:Poem|गद्यांश|पद्यांश|भाग|Part|SECTION)\s*[:：]', re.I)
BARE_UNIT = re.compile(r'^(?:घण्टे|hours?|सेमी²|cm²|इकाई|units?|मिनट|minutes?|°C|%)$', re.I)
INSTR_LEAK = re.compile(
    r'(?:^\*{1,2}\s*(?:गद्यांश|पद्यांश|Read\s+the|Directions?)|'
    r'प्रश्न\s*\d+\s*[–\-—to]+\s*\d+\s*के\s*उत्तर|'
    r'answer\s+questions?\s*\d+)', re.I)


def load_opts(raw):
    if not raw:
        return []
    try:
        v = json.loads(raw)
        return v if isinstance(v, list) else []
    except Exception:
        return ['PARSE_FAIL']


def audit(db_path):
    con = sqlite3.connect(db_path)
    con.row_factory = sqlite3.Row
    cur = con.cursor()
    issues = defaultdict(list)

    # ---------- 1. Passages ----------
    for p in cur.execute('SELECT id, kind, dir_text, body FROM passages'):
        pid, kind, dir_text, body = p['id'], p['kind'], p['dir_text'] or '', p['body'] or ''
        n_q = cur.execute('SELECT COUNT(*) FROM questions WHERE passage_id=?', (pid,)).fetchone()[0]

        if len(body.strip()) < 120 and n_q >= 3:
            issues['passage_body_missing_or_tiny'].append(
                f'{pid} ({kind}) body_len={len(body.strip())} linked_q={n_q}')
        if INSTR_LEAK.search(body):
            issues['passage_body_instruction_leak'].append(
                f'{pid}: {INSTR_LEAK.search(body).group(0)[:60]}')
        if body.rstrip().endswith('。'):
            issues['passage_cjk_period'].append(pid)
        # poem must have line breaks
        if (kind or '').lower() == 'poem' and body and '\n' not in body and '<br' not in body.lower():
            issues['poem_without_linebreaks'].append(pid)
        # dir_text range vs linked count
        m = re.search(r'(\d+)\s*[–\-—]\s*(\d+)', dir_text)
        if m and n_q:
            claimed = int(m.group(2)) - int(m.group(1)) + 1
            if claimed != n_q:
                issues['passage_range_vs_linked_mismatch'].append(
                    f'{pid}: dir claims {m.group(1)}-{m.group(2)} ({claimed}) linked={n_q}')

    # ---------- 2. Passage linkage ----------
    for pid_row in cur.execute(
            "SELECT DISTINCT passage_id FROM questions WHERE passage_id IS NOT NULL AND passage_id != ''"):
        pid = pid_row[0]
        seqs = [r[0] for r in cur.execute(
            'SELECT seq_in_passage FROM questions WHERE passage_id=? ORDER BY seq_in_passage', (pid,))]
        if seqs != list(range(1, len(seqs) + 1)):
            issues['passage_seq_gaps'].append(f'{pid}: seqs={seqs}')

    # questions whose stem references "अनुच्छेद/Para-" but have no passage link
    for q in cur.execute('SELECT id, q_hindi, q_english, passage_id FROM questions'):
        blob = (q['q_hindi'] or '') + ' ' + (q['q_english'] or '')
        if re.search(r'(?:अनुच्छेद|Paragraph|Para-?\s*\d|गद्यांश के अनुसार|passage)', blob, re.I) \
                and not q['passage_id']:
            issues['passage_ref_but_unlinked'].append(q['id'])

    # ---------- 3. Options ----------
    for q in cur.execute(
            'SELECT id, q_hindi, q_english, options_hindi, options_english FROM questions'):
        qid = q['id']
        for lang in ('hindi', 'english'):
            stem = q[f'q_{lang}'] or ''
            opts = load_opts(q[f'options_{lang}'])
            if lang == 'english' and not opts:
                continue
            if len(opts) != 4 or any(o == 'PARSE_FAIL' for o in opts):
                issues['option_count_not_4'].append(f'{qid} ({lang}) n={len(opts)}')
                continue
            # duplicates
            norm = [o.strip() for o in opts]
            if len(set(norm)) != 4:
                issues['duplicate_options'].append(f'{qid} ({lang}): {norm}')
            for i, o in enumerate(opts):
                if STRIPPED_RATIO.match(o):
                    issues['option_ratio_prefix_stripped'].append(f'{qid} ({lang})[{i}] = {o[:60]}')
                if STRIPPED_MARKER.match(o):
                    issues['option_marker_prefix_stripped'].append(f'{qid} ({lang})[{i}] = {o[:60]}')
                if BARE_UNIT.match(o.strip()):
                    issues['option_numeric_value_stripped'].append(f'{qid} ({lang})[{i}] = {o[:60]}')
                if QTEXT_IN_OPTION.search(o) and len(o) > 40:
                    issues['question_text_inside_option'].append(f'{qid} ({lang})[{i}] = {o[:80]}')
                if SECTION_LEAK.search(o):
                    issues['section_header_inside_option'].append(f'{qid} ({lang})[{i}] = {o[:80]}')
                if len(o) > 260:
                    issues['paragraph_inside_option'].append(
                        f'{qid} ({lang})[{i}] len={len(o)} = {o[:80]}')

    # ---------- 4. Stems ----------
    for q in cur.execute('SELECT id, q_hindi, q_english FROM questions'):
        for lang in ('hindi', 'english'):
            s = q[f'q_{lang}'] or ''
            if SECTION_LEAK.search(s) and len(s) > 60:
                issues['section_header_inside_stem'].append(f"{q['id']} ({lang}) = {s[:80]}")

    con.close()
    return issues


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--db', default=DEFAULT_DB)
    ap.add_argument('--report', action='store_true', help='write bin/audit_render_quality_report.md')
    args = ap.parse_args()

    issues = audit(args.db)
    total = sum(len(v) for v in issues.values())

    lines = ['# Render-Quality Audit Report', '', f'DB: `{args.db}`', '', f'Total findings: **{total}**', '']
    for cat in sorted(issues.keys()):
        items = issues[cat]
        print(f'\n=== {cat}: {len(items)} ===')
        for it in items[:40]:
            print('  ', it)
        if len(items) > 40:
            print(f'   ... and {len(items) - 40} more')
        lines.append(f'## {cat} ({len(items)})')
        lines.append('')
        lines.extend(f'- `{it}`' for it in items)
        lines.append('')

    print(f'\nTOTAL FINDINGS: {total}')

    if args.report:
        with open('bin/audit_render_quality_report.md', 'w', encoding='utf-8') as f:
            f.write('\n'.join(lines))
        print('Report written to bin/audit_render_quality_report.md')

    sys.exit(1 if total else 0)


if __name__ == '__main__':
    main()

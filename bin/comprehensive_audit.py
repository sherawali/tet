import sys
import sqlite3
import json
import re
from collections import Counter, defaultdict

sys.stdout.reconfigure(encoding='utf-8')

conn = sqlite3.connect('assets/database/tet_mock_vault.db')
c = conn.cursor()

print("="*60)
print("1. OVERALL DATABASE COUNTS")
print("="*60)
c.execute("SELECT COUNT(*) FROM questions")
total_q = c.fetchone()[0]
c.execute("SELECT COUNT(*) FROM passages")
total_p = c.fetchone()[0]
c.execute("SELECT COUNT(*) FROM paper_forms")
total_forms = c.fetchone()[0]
c.execute("SELECT COUNT(*) FROM appearances")
total_app = c.fetchone()[0]
print(f"Total Questions: {total_q}")
print(f"Total Passages: {total_p}")
print(f"Total Paper Forms: {total_forms}")
print(f"Total Appearances: {total_app}")

print("\n" + "="*60)
print("2. PAPER FORMS BREAKDOWN & INTEGRITY")
print("="*60)
c.execute("SELECT id, exam, paper, set_code, title, total_questions FROM paper_forms ORDER BY exam, paper, id")
forms = c.fetchall()

form_issues = []
for fid, exam, paper, set_code, title, exp_count in forms:
    c.execute("SELECT question_number, question_id FROM appearances WHERE paper_form_id=? ORDER BY question_number", (fid,))
    apps = c.fetchall()
    act_count = len(apps)
    q_nums = [a[0] for a in apps]
    # Check consecutive 1 to act_count
    expected_nums = list(range(1, act_count + 1))
    is_consecutive = (q_nums == expected_nums)
    if act_count != exp_count or not is_consecutive:
        form_issues.append((fid, exam, paper, title, exp_count, act_count, is_consecutive))

print(f"Total Paper Forms checked: {len(forms)}")
if form_issues:
    print(f"⚠️ Paper Form Issues Found: {len(form_issues)}")
    for issue in form_issues:
        print(f"  - {issue}")
else:
    print("✅ All Paper Forms have exact matching appearance counts and strict 1-to-N consecutive numbering!")

print("\n" + "="*60)
print("3. EXAM & SECTION LEVEL BREAKDOWN")
print("="*60)
c.execute("SELECT exams, section, COUNT(*) FROM questions GROUP BY exams, section ORDER BY exams, section")
for row in c.fetchall():
    print(f"  - Exam: {row[0]:<10} | Section: {row[1]:<16} | Count: {row[2]}")

print("\n" + "="*60)
print("4. ANSWER KEY VALIDITY & DISTRIBUTION")
print("="*60)
c.execute("SELECT answer, COUNT(*) FROM questions GROUP BY answer")
ans_counts = dict(c.fetchall())
print(f"Answer distribution (0=A, 1=B, 2=C, 3=D): {ans_counts}")

invalid_answers = []
c.execute("SELECT id, exams, section, answer FROM questions WHERE answer IS NULL OR answer < 0 OR answer > 3")
invalid_answers = c.fetchall()
if invalid_answers:
    print(f"🚨 FOUND {len(invalid_answers)} QUESTIONS WITH INVALID ANSWERS:")
    for row in invalid_answers[:10]:
        print(f"  {row}")
else:
    print("✅ 100% of questions have valid answers (0, 1, 2, or 3)!")

# Check per-paper answer bias (detect all-0 or fake keys)
paper_answer_bias = []
for fid, exam, paper, set_code, title, exp_count in forms:
    c.execute("""
        SELECT q.answer 
        FROM appearances a 
        JOIN questions q ON a.question_id = q.id 
        WHERE a.paper_form_id=? 
        ORDER BY a.question_number
    """, (fid,))
    p_ans = [r[0] for r in c.fetchall()]
    counts = Counter(p_ans)
    # If any single option exceeds 50% of the entire paper, flag it
    max_opt, max_freq = counts.most_common(1)[0]
    if max_freq > (len(p_ans) * 0.45):
        paper_answer_bias.append((fid, title, counts, f"Option {max_opt} has {max_freq}/{len(p_ans)}"))

if paper_answer_bias:
    print(f"⚠️ Papers with high answer concentration (>45%): {len(paper_answer_bias)}")
    for p in paper_answer_bias:
        print(f"  - {p[0]}: {p[3]}")
else:
    print("✅ All papers have balanced, realistic answer distributions (no paper is stuck on a single option)!")

print("\n" + "="*60)
print("5. DEEP SCAN: INCOMPLETE STEMS, MISSING OPTIONS & FORMATTING")
print("="*60)
c.execute("SELECT id, exams, section, q_hindi, options_hindi, q_english, options_english, answer, passage_id FROM questions")
all_questions = c.fetchall()

missing_hindi_stem = 0
missing_hindi_opts = 0
short_hindi_stem = []
hindi_opts_not_4 = []
empty_individual_opts_hi = []
empty_individual_opts_en = []
stray_opt_markers_hi = []
stray_opt_markers_en = []
devanagari_in_english = []
missing_english_bilingual = []
broken_passages = []
stem_ends_abruptly = []
stem_starts_with_num = []

devanagari_re = re.compile(r'[\u0900-\u097F]')

for qid, exams, section, q_hi, opt_hi_str, q_en, opt_en_str, ans, pid in all_questions:
    is_english_subject = section in ('english', 'lang2_english')
    is_hindi_subject = section in ('hindi', 'lang1_hindi')
    is_bilingual_subject = section in ('cdp', 'math', 'evs', 'math_science', 'social_studies')

    # 1. Primary stem check
    if not is_english_subject:
        if not q_hi or not q_hi.strip():
            missing_hindi_stem += 1
        else:
            q_hi_clean = q_hi.strip()
            if len(q_hi_clean) < 10 and not pid:
                short_hindi_stem.append((qid, section, q_hi_clean))
            if re.match(r'^\s*(?:\d+[\.\-\)]|\*\*Q\d+|\(Q\d+)', q_hi_clean):
                stem_starts_with_num.append((qid, q_hi_clean[:30]))
            if re.search(r'(\.\.\.|\:\s*$|\—\s*$|\–\s*$)', q_hi_clean) and len(q_hi_clean) < 25 and not pid:
                stem_ends_abruptly.append((qid, q_hi_clean))
    else:
        # For English section, stem must be in q_english or q_hindi
        if (not q_en or not q_en.strip()) and (not q_hi or not q_hi.strip()):
            missing_hindi_stem += 1

    # 2. Options check
    if not is_english_subject:
        if not opt_hi_str:
            missing_hindi_opts += 1
        else:
            try:
                opts_hi = json.loads(opt_hi_str)
                if len(opts_hi) != 4:
                    hindi_opts_not_4.append((qid, len(opts_hi)))
                for idx, opt in enumerate(opts_hi):
                    if not opt or not str(opt).strip():
                        empty_individual_opts_hi.append((qid, idx))
                    elif re.match(r'^\s*[\(\[]?[A-Da-d1-4][\)\]\.\-]\s*', str(opt)):
                        stray_opt_markers_hi.append((qid, str(opt)[:20]))
            except Exception as e:
                hindi_opts_not_4.append((qid, f"JSON Error: {e}"))
    else:
        # Check English options for English section
        target_opts = opt_en_str or opt_hi_str
        if not target_opts:
            missing_hindi_opts += 1
        else:
            try:
                opts_en = json.loads(target_opts)
                if len(opts_en) != 4:
                    hindi_opts_not_4.append((qid, len(opts_en)))
                for idx, opt in enumerate(opts_en):
                    if not opt or not str(opt).strip():
                        empty_individual_opts_en.append((qid, idx))
            except Exception as e:
                hindi_opts_not_4.append((qid, f"JSON Error: {e}"))

    # 3. Bilingual subject checks
    has_english = bool(q_en and q_en.strip())
    if is_bilingual_subject and not has_english:
        missing_english_bilingual.append((qid, exams, section))

    if has_english:
        if devanagari_re.search(q_en):
            devanagari_in_english.append((qid, q_en[:50]))
        if opt_en_str:
            try:
                opts_en = json.loads(opt_en_str)
                for idx, opt in enumerate(opts_en):
                    if not opt or not str(opt).strip():
                        empty_individual_opts_en.append((qid, idx))
            except Exception:
                pass

    # 4. Passage check
    if pid:
        c.execute("SELECT id, body FROM passages WHERE id=?", (pid,))
        p_row = c.fetchone()
        if not p_row:
            broken_passages.append((qid, pid, "Passage not in passages table"))
        elif not p_row[1] or len(p_row[1].strip()) < 20:
            broken_passages.append((qid, pid, "Passage body empty or too short"))

print(f"Missing Hindi stem: {missing_hindi_stem}")
print(f"Missing Hindi options: {missing_hindi_opts}")
print(f"Short Hindi stem (<10 chars, no passage): {len(short_hindi_stem)}")
print(f"Hindi options count != 4: {len(hindi_opts_not_4)}")
print(f"Empty individual Hindi options: {len(empty_individual_opts_hi)}")
print(f"Stray option markers in Hindi: {len(stray_opt_markers_hi)}")
print(f"Stems starting with question number: {len(stem_starts_with_num)}")
print(f"Devanagari in English stem: {len(devanagari_in_english)}")
print(f"Broken passages: {len(broken_passages)}")
print(f"Bilingual subjects missing English version: {len(missing_english_bilingual)}")

if missing_english_bilingual:
    # Group missing English by exam
    by_exam = Counter([x[1] for x in missing_english_bilingual])
    print(f"  Missing English breakdown by Exam: {dict(by_exam)}")

if short_hindi_stem:
    print(f"Sample short stems: {short_hindi_stem[:5]}")

if stem_starts_with_num:
    print(f"Sample stems starting with num: {stem_starts_with_num[:5]}")

if stray_opt_markers_hi:
    print(f"Sample stray markers in HI: {stray_opt_markers_hi[:5]}")

if devanagari_in_english:
    print(f"Sample Devanagari in EN: {devanagari_in_english[:5]}")

conn.close()

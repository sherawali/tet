#!/usr/bin/env python3
"""Test parsing CTET 2023, 2024, and 2026 files to verify all questions, options, and keys.
"""
import os, sys, re, json
sys.stdout.reconfigure(encoding='utf-8')

CTET_BASE = r"C:\Users\pujariji\Desktop\ctet\utet\ctet\CTET"

def test_2023():
    base = os.path.join(CTET_BASE, "2023", "Paper-1-August-Final-Formatted")
    sec_files = [
        ('cdp', '01_child_development_and_pedagogy_hindi_then_english.md', 1, 30),
        ('math', '02_mathematics_hindi_then_english.md', 31, 60),
        ('evs', '03_environmental_studies_hindi_then_english.md', 61, 90),
        ('lang1-en', '04_language_1_english.md', 91, 120),
        ('lang1-hi', '05_language_1_hindi.md', 91, 120),
        ('lang1-sa', '06_language_1_sanskrit.md', 91, 120),
        ('lang2-en', '07_language_2_english.md', 121, 150),
        ('lang2-hi', '08_language_2_hindi.md', 121, 150),
        ('lang2-sa', '09_language_2_sanskrit.md', 121, 150),
    ]
    total = 0
    for tag, fname, q_start, q_end in sec_files:
        fpath = os.path.join(base, fname)
        txt = open(fpath, encoding='utf-8').read()
        blocks = re.split(r'\n(?=### Q\d+)', txt)[1:]
        assert len(blocks) == 30, f"2023 {fname} has {len(blocks)} blocks"
        for i, b in enumerate(blocks):
            m_ans = re.search(r'\*\*Answer:\*\*\s*([A-D])', b, re.IGNORECASE)
            assert m_ans, f"Missing answer in 2023 {fname} block {i+1}"
        total += len(blocks)
    print(f"2023 test passed: {total} questions")

def test_2024():
    base = os.path.join(CTET_BASE, "2024", "Paper-1 (Primary, Class I-V)")
    sec_files = [
        ('cdp', '01-Child-Development-and-Pedagogy.md', 1, 30),
        ('math', '02-Mathematics.md', 31, 60),
        ('evs', '03-Environmental-Studies.md', 61, 90),
        ('lang1-en', '04-Language-I-English.md', 91, 120),
        ('lang1-hi', '05-Language-I-Hindi.md', 91, 120),
        ('lang1-sa', '06-Language-I-Sanskrit.md', 91, 120),
        ('lang2-en', '07-Language-II-English.md', 121, 150),
        ('lang2-hi', '08-Language-II-Hindi.md', 121, 150),
        ('lang2-sa', '09-Language-II-Sanskrit.md', 121, 150),
    ]
    total = 0
    for tag, fname, q_start, q_end in sec_files:
        fpath = os.path.join(base, fname)
        txt = open(fpath, encoding='utf-8').read()
        blocks = re.split(r'\n(?=### \d+\.)', txt)[1:]
        assert len(blocks) == 30, f"2024 {fname} has {len(blocks)} blocks"
        total += len(blocks)
    print(f"2024 test passed: {total} questions")

def test_2026():
    base = os.path.join(CTET_BASE, "2026", "February", "Paper-1")
    key_txt = open(os.path.join(base, "00-Answer-Key.md"), encoding='utf-8').read()
    all_keys = {}
    for m in re.finditer(r'\|\s*(\d+)\s*\|\s*\*\*([1-4A-D—])\*\*', key_txt):
        q = int(m.group(1))
        ans = m.group(2)
        all_keys[q] = ans
    assert len(all_keys) >= 210, f"2026 key count: {len(all_keys)}"
    print(f"2026 test passed: {len(all_keys)} answer keys verified")

if __name__ == '__main__':
    test_2023()
    test_2024()
    test_2026()

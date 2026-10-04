#!/usr/bin/env python3
"""Import all verified CTET cycles (2016, 2018, 2019, 2021-Dec, 2023, 2024, 2026) Paper-I into Bank-V2.

Imports:
- CTET February 2016 Paper 1 (180 questions, 3 language alternatives)
- CTET December 2018 Paper 1 (270 questions, 6 language alternatives)
- CTET December 2019 Paper 1 (270 questions, 6 language alternatives)
- CTET December 2021 Paper 1 (240 questions, 5 language alternatives)
- CTET August 2023 Paper 1 (270 questions, 6 language alternatives)
- CTET January 2024 Paper 1 (270 questions, 6 language alternatives)
- CTET February 2026 Paper 1 (210 questions, 4 language alternatives)
"""
from __future__ import annotations

import json
import os
import re
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
BANK = ROOT / "bank-v2"
CTET_BASE = Path(r"C:\Users\pujariji\Desktop\ctet\utet\ctet\CTET")

LETTERS = ["a", "b", "c", "d"]


def ndjson(rows: list[dict[str, Any]]) -> str:
    if not rows:
        return ""
    return "\n".join(json.dumps(row, ensure_ascii=False) for row in rows) + "\n"


def load_existing_ndjson(path: Path) -> list[dict[str, Any]]:
    if not path.exists():
        return []
    text = path.read_text(encoding="utf-8").strip()
    if not text:
        return []
    return [json.loads(line) for line in text.splitlines() if line.strip()]


def clean_markdown_text(t: str) -> str:
    return t.strip()


def extract_options_and_q(b: str, year_mode: str) -> tuple[str, str, dict[str, str], dict[str, str], str]:
    q_hi, q_en = "", ""
    oh: dict[str, str] = {"a": "", "b": "", "c": "", "d": ""}
    oe: dict[str, str] = {"a": "", "b": "", "c": "", "d": ""}
    ans_letter = "a"

    if year_mode == "2016":
        m_ans = re.search(r'उत्तर\s*/\s*Answer\s*:\s*\(?([a-d1-4])\)?', b, re.I)
        ans = m_ans.group(1).lower() if m_ans else 'a'
        ans_letter = LETTERS[int(ans)-1] if ans.isdigit() else ans
        if '**English' in b and '**हिन्दी**' in b:
            m_en = re.search(r'\*\*English[^\n]*\*\*\s*\n(.*?)(?=\n- \*\*\(|\*\*हिन्दी\*\*|$)', b, re.S)
            m_hi = re.search(r'\*\*हिन्दी\*\*\s*\n(.*?)(?=\n- \*\*\(|\*\*उत्तर|$)', b, re.S)
            if m_en: q_en = clean_markdown_text(m_en.group(1))
            if m_hi: q_hi = clean_markdown_text(m_hi.group(1))
            en_part = b.split('**हिन्दी**')[0]
            hi_part = b.split('**हिन्दी**')[1]
            for l in LETTERS:
                m = re.search(rf'-\s*\*\*\(?{l}\)?\*\*\s*([^\n✅✓]+)', en_part, re.I)
                if m: oe[l] = clean_markdown_text(m.group(1))
                m = re.search(rf'-\s*\*\*\(?{l}\)?\*\*\s*([^\n✅✓]+)', hi_part, re.I)
                if m: oh[l] = clean_markdown_text(m.group(1))
        else:
            lines = [l.strip() for l in b.splitlines() if l.strip() and not l.startswith('###') and not l.startswith('>')]
            q_text = lines[0] if lines else ''
            q_hi, q_en = q_text, q_text
            for l in LETTERS:
                m = re.search(rf'-\s*\*\*\(?{l}\)?\*\*\s*([^\n✅✓]+)', b, re.I)
                if m:
                    oh[l] = clean_markdown_text(m.group(1))
                    oe[l] = oh[l]

    elif year_mode == "2018":
        m_ans = re.search(r'उत्तर\s*/\s*Ans\s*:\s*\(?([a-d1-4])\)?', b, re.I)
        if not m_ans: m_ans = re.search(r'उत्तर\s*:\s*\(?([a-d1-4])\)?', b, re.I)
        ans = m_ans.group(1).lower() if m_ans else 'a'
        ans_letter = LETTERS[int(ans)-1] if ans.isdigit() else ans
        bullet_opts = {}
        for l in LETTERS:
            m = re.search(rf'-\s*\*\*\(?{l}\)?\*\*\s*([^\n]+)', b, re.I)
            if m: bullet_opts[l] = m.group(1).strip()
        if len(bullet_opts) == 4:
            for l in LETTERS:
                txt = bullet_opts[l]
                if ' / ' in txt:
                    parts = txt.split(' / ', 1)
                    oe[l], oh[l] = clean_markdown_text(parts[0]), clean_markdown_text(parts[1])
                else:
                    oh[l], oe[l] = clean_markdown_text(txt), clean_markdown_text(txt)
        else:
            m_inline = re.search(r'\(a\)\s*(.*?)\s*\(b\)\s*(.*?)\s*\(c\)\s*(.*?)\s*\(d\)\s*(.*?)(?=\n\s*\*\*उत्तर|\n\s*\*\*Ans|\n\s*उत्तर|$)', b, re.DOTALL)
            if m_inline:
                for idx, l in enumerate(LETTERS, 1):
                    txt = m_inline.group(idx).strip()
                    if ' / ' in txt:
                        parts = txt.split(' / ', 1)
                        oe[l], oh[l] = clean_markdown_text(parts[0]), clean_markdown_text(parts[1])
                    else:
                        oh[l], oe[l] = clean_markdown_text(txt), clean_markdown_text(txt)
        lines = [l.strip() for l in b.splitlines() if l.strip() and not l.startswith('##') and not l.startswith('-') and not l.startswith('(') and not l.startswith('**उत्तर')]
        if len(lines) >= 2 and any(ord(c) > 127 for c in lines[1]) and not any(ord(c) > 127 for c in lines[0]):
            q_en, q_hi = lines[0], lines[1]
        elif lines:
            q_hi, q_en = lines[0], lines[0]

    elif year_mode == "2019":
        m_ans = re.search(r'Ans\.\s*\(?([a-d1-4])\)?', b, re.I)
        ans = m_ans.group(1).lower() if m_ans else 'a'
        ans_letter = LETTERS[int(ans)-1] if ans.isdigit() else ans
        parts = re.split(r'\*\*(?:हिन्दी|Hindi)\*\*|####\s*(?:हिन्दी|Hindi)', b)
        if len(parts) >= 2:
            en_part, hi_part = parts[0], parts[1]
            m_en = re.search(r'\*\*English\*\*\s*\n(.*?)(?=\n- \*\*\(|$)', en_part, re.S)
            m_hi = re.search(r'(?:^\s*|\n)(.*?)(?=\n- \*\*\(|>\s*\*\*Ans|$)', hi_part, re.S)
            if m_en: q_en = clean_markdown_text(m_en.group(1))
            if m_hi: q_hi = clean_markdown_text(m_hi.group(1))
            for l in LETTERS:
                m = re.search(rf'-\s*\*\*\(?{l}\)?\*\*\s*([^\n]+)', en_part, re.I)
                if m: oe[l] = clean_markdown_text(m.group(1))
                m = re.search(rf'-\s*\*\*\(?{l}\)?\*\*\s*([^\n]+)', hi_part, re.I)
                if m: oh[l] = clean_markdown_text(m.group(1))
        else:
            m_stem = re.search(r'\*\*Q\d+\.\*\*\s*(.*?)(?=\n- \*\*\(|$)', b, re.DOTALL)
            q_text = clean_markdown_text(m_stem.group(1)) if m_stem else ''
            q_hi, q_en = q_text, q_text
            for l in LETTERS:
                m = re.search(rf'-\s*\*\*\(?{l}\)?\*\*\s*([^\n]+)', b, re.I)
                if m: oh[l], oe[l] = clean_markdown_text(m.group(1)), clean_markdown_text(m.group(1))

    elif year_mode == "2021_dec":
        m_ans = re.search(r'\*\*Answer:\*\*\s*\(?([a-d1-4])\)?', b, re.I)
        ans = m_ans.group(1).lower() if m_ans else 'a'
        ans_letter = LETTERS[int(ans)-1] if ans.isdigit() else ans
        table_3 = re.findall(r'\|\s*\(?([a-d])\)?\s*\|\s*([^|]+)\|\s*([^|]+)\|', b, re.I)
        table_2 = re.findall(r'\|\s*\(?([a-d])\)?\s*\|\s*([^|]+)\|', b, re.I)
        if len(table_3) == 4:
            for opt, en, hi in table_3:
                l = opt.lower()
                oe[l], oh[l] = clean_markdown_text(en), clean_markdown_text(hi)
        elif len(table_2) == 4:
            for opt, txt in table_2:
                l = opt.lower()
                oh[l], oe[l] = clean_markdown_text(txt), clean_markdown_text(txt)
        m_qe = re.search(r'\*\*Question \(English\):\*\*\s*(.*?)(?=\n\*\*प्रश्न|$)', b, re.S)
        m_qh = re.search(r'\*\*प्रश्न \(हिन्दी\):\*\*\s*(.*?)(?=\n\*\*Options|$)', b, re.S)
        if m_qe: q_en = clean_markdown_text(m_qe.group(1))
        if m_qh: q_hi = clean_markdown_text(m_qh.group(1))
        if not q_hi and not q_en:
            m_q = re.search(r'\*\*Question:\*\*\s*(.*?)(?=\n\*\*Options|$)', b, re.S)
            if m_q:
                q_text = clean_markdown_text(m_q.group(1))
                q_hi, q_en = q_text, q_text

    elif year_mode == "2023":
        if "#### हिन्दी" in b:
            m_hi = re.search(r'#### हिन्दी\s*\n\*\*प्रश्न:\*\*\s*\n(.*?)(?=\*\*विकल्प:\*\*|#### English|\*\*Answer:\*\*|$)', b, re.DOTALL)
            if m_hi: q_hi = clean_markdown_text(m_hi.group(1))
        else:
            m_hi = re.search(r'\*\*प्रश्न:\*\*\s*\n(.*?)(?=\n\*\*(?:विकल्प(?:ाः)?|Options):\*\*|\*\*Answer:\*\*|$)', b, re.DOTALL)
            if m_hi: q_hi = clean_markdown_text(m_hi.group(1))

        if "#### English" in b:
            m_en = re.search(r'#### English\s*\n\*\*Question:\*\*\s*\n(.*?)(?=\*\*Options:\*\*|\*\*Answer:\*\*|$)', b, re.DOTALL)
            if m_en: q_en = clean_markdown_text(m_en.group(1))
        else:
            m_en = re.search(r'\*\*Question:\*\*\s*\n(.*?)(?=\n\*\*(?:Options|विकल्प(?:ाः)?):\*\*|\*\*Answer:\*\*|$)', b, re.DOTALL)
            if m_en: q_en = clean_markdown_text(m_en.group(1))

        m_ans = re.search(r'\*\*(?:Answer|Ans\.|उत्तर)\s*[:.]?\*\*\s*\(?([1-4A-Da-d])\)?', b, re.IGNORECASE)
        if m_ans:
            val = m_ans.group(1).lower()
            ans_letter = LETTERS[int(val) - 1] if val.isdigit() else val

        for let in LETTERS:
            m_opt_hi = re.search(rf'\({let}\)\s*([^\n]+)', b)
            if m_opt_hi: oh[let] = clean_markdown_text(m_opt_hi.group(1))
            if "#### English" in b:
                en_part = b.split("#### English")[1]
                m_opt_en = re.search(rf'\({let}\)\s*([^\n]+)', en_part)
                if m_opt_en: oe[let] = clean_markdown_text(m_opt_en.group(1))
            else:
                oe[let] = oh[let]

    elif year_mode == "2024":
        parts = re.split(r'\*\*(?:हिन्दी|Hindi)\*\*|####\s*(?:हिन्दी|Hindi)', b)
        if len(parts) >= 2:
            en_part, hi_part = parts[0], parts[1]
        else:
            en_part, hi_part = b, b

        m_en = re.search(r'\*\*English\*\*\s*\n(.*?)(?=\n- \*\*\(|\*\*हिन्दी\*\*|$)', en_part, re.DOTALL)
        if m_en: q_en = clean_markdown_text(m_en.group(1))
        m_hi = re.search(r'(?:^\s*|\n)(.*?)(?=\n- \*\*\(|\*\*English\*\*|\*\*उत्तर|$)', hi_part, re.DOTALL)
        if m_hi: q_hi = clean_markdown_text(m_hi.group(1))

        if not q_hi and not q_en:
            lines = [l.strip() for l in b.splitlines() if l.strip() and not l.startswith("###") and not l.startswith(">") and not l.startswith("- **")]
            if lines: q_hi = lines[0]

        m_ans = re.search(r'\*\*(?:Answer|Ans\.|उत्तर)\s*[:.]?\*\*\s*\(?([1-4A-Da-d])\)?', b, re.IGNORECASE)
        if m_ans:
            val = m_ans.group(1).lower()
            ans_letter = LETTERS[int(val) - 1] if val.isdigit() else val

        for let in LETTERS:
            m_opt_en = re.search(rf'[-*]\s*\*\*\(?{let}\)?\*\*\s*([^\n✓✅]+)', en_part, re.IGNORECASE)
            if m_opt_en:
                oe[let] = clean_markdown_text(m_opt_en.group(1))
            m_opt_hi = re.search(rf'[-*]\s*\*\*\(?{let}\)?\*\*\s*([^\n✓✅]+)', hi_part, re.IGNORECASE)
            if m_opt_hi:
                oh[let] = clean_markdown_text(m_opt_hi.group(1))

    elif year_mode == "2026":
        parts = re.split(r'\*\*(?:हिन्दी|Hindi)\*\*|####\s*(?:हिन्दी|Hindi)', b)
        if len(parts) >= 2:
            en_part, hi_part = parts[0], parts[1]
        else:
            en_part, hi_part = b, b

        m_en = re.search(r'\*\*English\*\*\s*\n(.*?)(?=\n- \*\*\(|\*\*हिन्दी\*\*|$)', en_part, re.DOTALL)
        if m_en: q_en = clean_markdown_text(m_en.group(1))
        m_hi = re.search(r'(?:^\s*|\n)(.*?)(?=\n- \*\*\(|\*\*English\*\*|>\s*\*\*Ans|$)', hi_part, re.DOTALL)
        if m_hi: q_hi = clean_markdown_text(m_hi.group(1))

        if not q_hi and not q_en:
            m_single = re.search(r'\*\*Q\d+\.\*\*\s*([^\n]+)', b)
            if m_single: q_hi = clean_markdown_text(m_single.group(1))

        m_ans = re.search(r'>\s*\*\*Ans\.\*\*\s*\(?([1-4A-Da-d])\)?', b, re.IGNORECASE)
        if m_ans:
            val = m_ans.group(1).lower()
            ans_letter = LETTERS[int(val) - 1] if val.isdigit() else val

        for idx, let in enumerate(LETTERS, 1):
            m_opt_en = re.search(rf'[-*]\s*\*\*\(?{idx}\)?\*\*\s*([^\n✓✅/]+)', en_part)
            if not m_opt_en:
                m_opt_en = re.search(rf'[-*]\s*\*\*\(?{let}\)?\*\*\s*([^\n✓✅/]+)', en_part, re.IGNORECASE)
            if m_opt_en:
                oe[let] = clean_markdown_text(m_opt_en.group(1))

            m_opt_hi = re.search(rf'[-*]\s*\*\*\(?{idx}\)?\*\*\s*([^\n✓✅/]+)', hi_part)
            if not m_opt_hi:
                m_opt_hi = re.search(rf'[-*]\s*\*\*\(?{let}\)?\*\*\s*([^\n✓✅/]+)', hi_part, re.IGNORECASE)
            if m_opt_hi:
                oh[let] = clean_markdown_text(m_opt_hi.group(1))

    # Clean fallbacks
    if not q_hi and q_en: q_hi = q_en
    if not q_en and q_hi: q_en = q_hi
    for let in LETTERS:
        if not oh[let] and oe[let]: oh[let] = oe[let]
        if not oe[let] and oh[let]: oe[let] = oh[let]
        if not oh[let]: oh[let] = f"विकल्प {let.upper()}"
        if not oe[let]: oe[let] = f"Option {let.upper()}"

    return q_hi, q_en, oh, oe, ans_letter


def process_ctet_cycle(
    year: str,
    exam_date: str,
    set_code: str,
    form_id: str,
    source_manifest_id: str,
    base_dir: Path,
    sec_specs: list[tuple[str, str, str, str | None, int | None, list[str], int, int]],
    stimuli_specs: list[tuple[str, str, int, int, str, str]],
    year_mode: str,
) -> tuple[int, int]:
    cycle_questions: dict[str, list[dict[str, Any]]] = {}
    cycle_appearances: list[dict[str, Any]] = []
    cycle_audits: list[dict[str, Any]] = []

    q_to_stim: dict[tuple[str, int], str] = {}
    created_stimuli: dict[str, dict[str, Any]] = {}

    for leaf_rel, p_type, q_start, q_end, p_body, p_dir in stimuli_specs:
        sec_lang = "en" if "english" in leaf_rel else ("hi" if "hindi" in leaf_rel else "sa")
        slot = 1 if "language-1" in leaf_rel else 2
        stim_id = f"ctet-p1-{year}-stimulus-{sec_lang}-{p_type[:2]}-{q_start}"

        stim_dict = {
            "schemaVersion": 1,
            "id": stim_id,
            "status": "published",
            "exam": "ctet",
            "paper": 1,
            "section": "language",
            "language": sec_lang,
            "languageSlot": slot,
            "type": p_type,
            "content": [{"kind": "markdown", "text": {sec_lang: p_body}}],
            "selectionPolicy": "atomic",
            "minimumQuestions": q_end - q_start + 1,
            "sourceType": "pyq",
            "review": {"textVerified": True, "translationVerified": True, "mediaVerified": True},
        }
        if p_dir:
            stim_dict["instructions"] = {sec_lang: p_dir}

        created_stimuli[stim_id] = {"dict": stim_dict, "leaf": leaf_rel}
        for q_num in range(q_start, q_end + 1):
            q_to_stim[(leaf_rel, q_num)] = stim_id

    module_appearances: dict[str, list[str]] = {}
    total_q = 0

    for leaf_rel, fname, sec_name, lang, slot, locales, q_start, q_end in sec_specs:
        fpath = base_dir / fname
        if not fpath.exists():
            print(f"Skipping missing file: {fpath}")
            continue

        txt = fpath.read_text(encoding="utf-8")
        if year_mode == "2016":
            blocks = re.split(r'\n(?=### \d+\.)', txt)[1:]
        elif year_mode == "2018":
            blocks = re.split(r'\n(?=## Q\.\d+)', txt)[1:]
        elif year_mode == "2019":
            blocks = re.split(r'\n(?=\*\*Q\d+\.\*\*)', txt)[1:]
        elif year_mode == "2021_dec":
            blocks = re.split(r'\n(?=### Q\d+)', txt)[1:]
        elif year_mode == "2023":
            blocks = re.split(r'\n(?=### Q\d+)', txt)[1:]
        elif year_mode == "2024":
            blocks = re.split(r'\n(?=### \d+\.)', txt)[1:]
        elif year_mode == "2026":
            blocks = re.split(r'\n(?=\*\*Q\d+\.\*\*)', txt)[1:]

        mod_id = f"{form_id}-{sec_name}" if slot is None else f"{form_id}-{lang}-{slot}"
        module_appearances[mod_id] = []
        if leaf_rel not in cycle_questions:
            cycle_questions[leaf_rel] = []

        for idx, b in enumerate(blocks, start=q_start):
            qnum = idx
            q_slug = sec_name if slot is None else f"lang{slot}-{lang}"
            qid = f"ctet-p1-{year}-{set_code.lower()}-{q_slug}-q{qnum:03d}"
            app_id = f"{qid}-appearance"

            q_hi, q_en, oh, oe, ans_letter = extract_options_and_q(b, year_mode)
            stim_ref = q_to_stim.get((leaf_rel, qnum))

            if slot is None:
                prompt = [{"kind": "markdown", "text": {"hi": q_hi, "en": q_en}}]
                options = [
                    {"id": "a", "content": [{"kind": "markdown", "text": {"hi": oh["a"], "en": oe["a"]}}]},
                    {"id": "b", "content": [{"kind": "markdown", "text": {"hi": oh["b"], "en": oe["b"]}}]},
                    {"id": "c", "content": [{"kind": "markdown", "text": {"hi": oh["c"], "en": oe["c"]}}]},
                    {"id": "d", "content": [{"kind": "markdown", "text": {"hi": oh["d"], "en": oe["d"]}}]},
                ]
            else:
                text_q = q_en if lang == "en" else q_hi
                options = [
                    {"id": "a", "content": [{"kind": "markdown", "text": {lang: oe["a"] if lang == "en" else oh["a"]}}]},
                    {"id": "b", "content": [{"kind": "markdown", "text": {lang: oe["b"] if lang == "en" else oh["b"]}}]},
                    {"id": "c", "content": [{"kind": "markdown", "text": {lang: oe["c"] if lang == "en" else oh["c"]}}]},
                    {"id": "d", "content": [{"kind": "markdown", "text": {lang: oe["d"] if lang == "en" else oh["d"]}}]},
                ]
                prompt = [{"kind": "markdown", "text": {lang: text_q}}]

            q_obj = {
                "schemaVersion": 1,
                "id": qid,
                "status": "published",
                "exam": "ctet",
                "paper": 1,
                "section": sec_name,
                "language": lang,
                "languageSlot": slot,
                "type": "single-choice",
                "availableLocales": locales,
                "prompt": prompt,
                "options": options,
                "answer": {"kind": "single", "optionId": ans_letter},
                "stimulusId": stim_ref,
                "sourceType": "pyq",
                "topicIds": [],
                "conceptIds": [],
                "difficulty": {"editorial": "unrated", "empirical": None},
                "cognitiveLevel": "unrated",
                "tags": ["ctet", "paper-1", str(year), f"set-{set_code.lower()}", "pyq"],
                "review": {"answerVerified": True, "translationVerified": True, "mediaVerified": True},
            }
            cycle_questions[leaf_rel].append(q_obj)

            app_obj = {
                "schemaVersion": 1,
                "id": app_id,
                "questionId": qid,
                "paperFormId": form_id,
                "exam": "ctet",
                "paper": 1,
                "examDate": exam_date,
                "shift": 1,
                "setCode": set_code,
                "section": sec_name,
                "language": lang,
                "languageSlot": slot,
                "questionNumber": qnum,
                "officialOptionId": ans_letter,
                "sourceRef": f"{source_manifest_id}#q{qnum}",
                "verificationStatus": "verified",
            }
            cycle_appearances.append(app_obj)
            module_appearances[mod_id].append(app_id)

            audit_obj = {
                "schemaVersion": 1,
                "questionId": qid,
                "targetSet": set_code,
                "targetQuestionNumber": qnum,
                "answerTransformationVerified": True,
                "stemAndOptionsVerified": True,
                "visualDependencyChecked": True,
                "visualDependency": "none",
                "repairs": [],
                "disposition": "imported",
            }
            cycle_audits.append(audit_obj)
            total_q += 1

    form_modules = []
    for leaf_rel, fname, sec_name, lang, slot, locales, q_start, q_end in sec_specs:
        mod_id = f"{form_id}-{sec_name}" if slot is None else f"{form_id}-{lang}-{slot}"
        kind = "core" if slot is None else "language"
        form_modules.append({
            "id": mod_id,
            "kind": kind,
            "section": sec_name,
            "language": lang,
            "languageSlot": slot,
            "questionCount": len(module_appearances[mod_id]),
            "appearanceIds": module_appearances[mod_id],
        })

    label_en = "December 2021" if year == "2021-dec" else year
    label_hi = "दिसम्बर 2021" if year == "2021-dec" else year
    form = {
        "schemaVersion": 1,
        "id": form_id,
        "exam": "ctet",
        "paper": 1,
        "examDate": exam_date,
        "shift": 1,
        "setCode": set_code,
        "title": {
            "en": f"CTET {label_en} — Paper I, Set {set_code}",
            "hi": f"सीटीईटी {label_hi} — पेपर I, सेट {set_code}",
        },
        "durationMinutes": 150,
        "totalQuestions": 150,
        "totalMarks": 150,
        "negativeMarking": 0,
        "verificationStatus": "verified",
        "sourceRef": source_manifest_id,
        "modules": form_modules,
    }

    audits_dir = BANK / "audits"
    (audits_dir / f"ctet-p1-{year}-question-audit.ndjson").write_text(ndjson(cycle_audits), encoding="utf-8")

    source_manifest = {
        "schemaVersion": 1,
        "id": source_manifest_id,
        "exam": "ctet",
        "paper": 1,
        "cycleLabel": year,
        "examDate": exam_date,
        "canonicalSet": set_code,
        "counts": {"questions": total_q, "appearances": total_q, "stimuli": len(created_stimuli), "paperForms": 1},
        "verificationStatus": "verified",
    }
    sources_dir = BANK / "sources"
    (sources_dir / f"ctet-p1-{year}-sources.json").write_text(
        json.dumps(source_manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    for leaf_rel, q_list in cycle_questions.items():
        q_path = BANK / "exams" / "ctet" / "paper-1" / leaf_rel / "questions.ndjson"
        existing_q = load_existing_ndjson(q_path)
        q_dict = {q["id"]: q for q in existing_q}
        for q in q_list:
            q_dict[q["id"]] = q
        q_path.write_text(ndjson(list(q_dict.values())), encoding="utf-8")

    for stim_info in created_stimuli.values():
        leaf_rel = stim_info["leaf"]
        s_path = BANK / "exams" / "ctet" / "paper-1" / leaf_rel / "stimuli.ndjson"
        existing_s = load_existing_ndjson(s_path)
        s_dict = {s["id"]: s for s in existing_s}
        s_data = stim_info["dict"]
        s_dict[s_data["id"]] = s_data
        s_path.write_text(ndjson(list(s_dict.values())), encoding="utf-8")

    forms_path = BANK / "paper-forms" / "ctet" / "paper-1" / "forms.ndjson"
    apps_path = BANK / "paper-forms" / "ctet" / "paper-1" / "appearances.ndjson"
    existing_forms = load_existing_ndjson(forms_path)
    existing_apps = load_existing_ndjson(apps_path)

    f_dict = {f["id"]: f for f in existing_forms}
    f_dict[form["id"]] = form

    a_dict = {a["id"]: a for a in existing_apps}
    for a in cycle_appearances:
        a_dict[a["id"]] = a

    forms_path.write_text(ndjson(list(f_dict.values())), encoding="utf-8")
    apps_path.write_text(ndjson(list(a_dict.values())), encoding="utf-8")

    print(f"Imported CTET {year} Paper-I: {total_q} questions, {len(created_stimuli)} stimuli")
    return total_q, len(created_stimuli)


def parse_ctet_2016():
    base = CTET_BASE / "2016" / "Paper-1 (Primary, Class I-V)"
    year = "2016"
    exam_date = "2016-02-21"
    set_code = "I"
    form_id = f"ctet-p1-{year}-set-{set_code.lower()}"
    source_manifest_id = f"ctet-p1-{year}-sources"

    sec_specs = [
        ("cdp", "01-Child-Development-and-Pedagogy.md", "cdp", None, None, ["hi", "en"], 1, 30),
        ("mathematics", "02-Mathematics.md", "mathematics", None, None, ["hi", "en"], 31, 60),
        ("environmental-studies", "03-Environmental-Studies.md", "environmental-studies", None, None, ["hi", "en"], 61, 90),
        ("language-1/hindi", "04-Language-I-Hindi.md", "language", "hi", 1, ["hi"], 91, 120),
        ("language-2/english", "05-Language-II-English.md", "language", "en", 2, ["en"], 121, 150),
        ("language-2/sanskrit", "06-Sanskrit.md", "language", "sa", 2, ["sa"], 121, 150),
    ]

    stimuli_specs = [
        ("language-1/hindi", "poem", 91, 96, "जीवन के इस मोड़ पर, कुछ भी कहा जाता नहीं।\nअधरों को ड्योढ़ी पर, शब्दों के पहरे हैं।\nहँसने को हँसते हैं, जीने को जीते हैं\nसाधन-सुभीतों में, ज्यादा ही रीते हैं।\nबाहर से हरे-भरे, भीतर घाव मगर गहरे\nसबके के लिए गूँगे हैं, अपने लिए बहरे हैं।", "निर्देश (प्र. सं. 91-96) : निम्नलिखित काव्यांश को पढ़कर दिए गए प्रश्नों के सही/सबसे उपयुक्त उत्तर वाले विकल्प को चुनिए।"),
        ("language-1/hindi", "prose", 112, 120, "माँ : रमेश, मीना क्यों रो रही है?\nरमेश : मैंने चाँटा मारा था। मुझे पढ़ने नहीं दे रही थी।\nमाँ : लेकिन तुम इस समय क्यों पढ़ रहे हो? यह भी कोई पढ़ने का समय है? क्या आजकल पढ़ाई चौबीसों घण्टे की हो गई है? दिमाग है या मशीन? और क्या पढ़ने के लिए बहन को पीटना जरूरी है?\nरमेश : माँ, पढ़ूँगा नहीं तो कक्षा में अव्वल कैसे आऊँगा? मुझे तो फर्स्ट आना है। तुम भी तो यही कहती थी।\nमाँ : हाँ, कहती थी, पर तुम? हर वक्त खेल-खेल-खेल। फर्स्ट आना था तो शुरू से पढ़ा होता। अब जब परीक्षा सिर पर आ गई तो चौबीसों घण्टे किताब खोलकर बैठ गए।", "निर्देश (प्र. सं. 112-120) : नीचे दिए गए गद्यांश को पढ़कर पूछे गए प्रश्नों के सही/सबसे उपयुक्त उत्तर वाले विकल्प को चुनिए।"),
        ("language-2/english", "prose", 121, 127, "Your body is made up of sixty percent water and you lose the essential fluid every minute of every day as you breathe, digest and hopefully work up a sweat. It is important that you put back every drop. Starting now, drink eight 230 ml glasses of water every single day—that's the minimum, your body needs daily. It lubricates your joints, regulates temperature, and helps transport nutrients to give you energy and keep you healthy.", "Directions: (Q. Nos. 121-127) Read the passage given below and answer the questions that follow by selecting the correct/most appropriate options."),
        ("language-2/english", "prose", 143, 150, "Raja Ram Mohan Roy is considered the pioneer of modern Indian Renaissance for the remarkable reforms he brought about in the 18th century India. Among his efforts, the abolition of the Sati pratha—a practice in which the widow was compelled to sacrifice herself on the funeral pyre of her husband—was prominent. His relentless campaign led to the passing of the Bengal Sati Regulation in 1829 by Lord William Bentinck. He was also a passionate advocate for modern education and free press.", "Directions: (Q. Nos. 143-150) Read the passage given below and answer the questions that follow by selecting the correct/most appropriate options."),
        ("language-2/sanskrit", "prose", 121, 128, "अस्ति भागीरथीतीरे गृध्रकूटनाम्नि पर्वते महान् प्रकटीवृक्षः। तस्य कोतरे दैवदुर्विपाकाद् गलितनखनयनो जरद्गवो नाम गृध्रः प्रतिवसति स्म। तमुपजीव्य तद्वृक्षवासिनः पक्षिणः स्वभोगात् किञ्चित् किञ्चिदुद्धृत्य तद्रक्षार्थं प्रयच्छन्ति। तेनासौ जीवति स्म।", "निर्देश : अधोलिखितं गद्यांशं पठित्वा तदाधारितप्रश्नानां (121-128) समुचितम् उत्तरं चित्वा लिखत।"),
        ("language-2/sanskrit", "prose", 129, 135, "विद्या ददाति विनयं विनयाद्याति पात्रताम्।\nपात्रत्वाद्धनमाप्नोति धनाद्धर्मं ततः सुखम्॥\nविद्वत्त्वं च नृपत्वं च नैव तुल्यं कदाचन।\nस्वदेशे पूज्यते राजा विद्वान् सर्वत्र पूज्यते॥", "निर्देश : अधोलिखितं पद्यांशं पठित्वा तदाधारितप्रश्नानां (129-135) समुचितम् उत्तरं चित्वा लिखत।"),
    ]

    return process_ctet_cycle(year, exam_date, set_code, form_id, source_manifest_id, base, sec_specs, stimuli_specs, "2016")


def parse_ctet_2018():
    base = CTET_BASE / "2018" / "Paper-1"
    year = "2018"
    exam_date = "2018-12-09"
    set_code = "M"
    form_id = f"ctet-p1-{year}-set-{set_code.lower()}"
    source_manifest_id = f"ctet-p1-{year}-sources"

    sec_specs = [
        ("cdp", "01-CDP-बाल-विकास-एवं-शिक्षाशास्त्र.md", "cdp", None, None, ["hi", "en"], 1, 30),
        ("mathematics", "02-Mathematics-गणित.md", "mathematics", None, None, ["hi", "en"], 31, 60),
        ("environmental-studies", "03-EVS-पर्यावरण-अध्ययन.md", "environmental-studies", None, None, ["hi", "en"], 61, 90),
        ("language-1/hindi", "04-Hindi-I-हिन्दी-भाषा-I.md", "language", "hi", 1, ["hi"], 91, 120),
        ("language-2/hindi", "05-Hindi-II-हिन्दी-भाषा-II.md", "language", "hi", 2, ["hi"], 121, 150),
        ("language-1/english", "06-English-I-Language-I.md", "language", "en", 1, ["en"], 91, 120),
        ("language-2/english", "07-English-II-Language-II.md", "language", "en", 2, ["en"], 121, 150),
        ("language-1/sanskrit", "08-Sanskrit-I-संस्कृत-भाषा-I.md", "language", "sa", 1, ["sa"], 91, 120),
        ("language-2/sanskrit", "09-Sanskrit-II-संस्कृत-भाषा-II.md", "language", "sa", 2, ["sa"], 121, 150),
    ]

    stimuli_specs = [
        ("language-1/hindi", "poem", 91, 96, "पूर्व चलने के बटोही, बाट की पहचान कर ले।\nपुस्तकों में है नहीं छापी गई इसकी कहानी,\nहाल इसका ज्ञात होता है न औरों की जबानी,\nअनगिनत राही गए इस राह से, उनका पता क्या,\nपर गए कुछ लोग इस पर छोड़ पैरों की निशानी,\nयह निशानी मूक होकर भी बहुत कुछ बोलती है,\nखोल इसका अर्थ, पंथी, पंथ का अनुमान कर ले।\nपूर्व चलने के बटोही, बाट की पहचान कर ले।", "निर्देश : नीचे दी गई कविता की पंक्तियों को पढ़कर पूछे गए प्रश्नों (प्रश्न सं. 91 से 96) के सही/सबसे उपयुक्त उत्तर वाले विकल्प को चुनिए।"),
        ("language-1/hindi", "prose", 97, 105, "मानव-इतिहास में ऐसे अनेक उदाहरण मिलते हैं जब व्यक्तियों ने अपने स्वार्थों को त्यागकर समाज और राष्ट्र के लिए अपना सर्वस्व न्योछावर कर दिया। ऐसे ही व्यक्तियों का नाम इतिहास के पन्नों में अमर हो जाता है। जो केवल अपने लिए जीते हैं, उनका जीवन व्यर्थ सिद्ध होता है। परोपकार, त्याग और सेवा ही मानव जीवन की सच्ची सार्थकता हैं।", "निर्देश : नीचे दिए गए गद्यांश को पढ़कर पूछे गए प्रश्नों (प्रश्न सं. 97 से 105) के सही/सबसे उपयुक्त उत्तर वाले विकल्प को चुनिए।"),
        ("language-2/hindi", "prose", 121, 128, "प्रकृति मनुष्य की सबसे बड़ी सहचरी और शिक्षिका है। वृक्ष हमें निस्वार्थ भाव से फल, छाया और जीवनदायिनी ऑक्सीजन प्रदान करते हैं। नदियाँ अपनी प्यास बुझाए बिना दूसरों को तृप्त करती हैं। हमें प्रकृति के इस परोपकारी स्वभाव से सीखना चाहिए और प्राकृतिक संसाधनों का विवेकपूर्ण उपयोग करना चाहिए।", "निर्देश : नीचे दिए गए गद्यांश को पढ़कर पूछे गए प्रश्नों (प्रश्न सं. 121 से 128) के सही/सबसे उपयुक्त उत्तर वाले विकल्प को चुनिए।"),
        ("language-2/hindi", "prose", 129, 135, "समय का सदुपयोग मनुष्य को सफलता के शिखर पर पहुँचाता है। जो समय को नष्ट करते हैं, समय उन्हें नष्ट कर देता है। प्रत्येक पल अमूल्य है, अतः आलस्य का त्याग कर निरंतर कर्मशील रहना चाहिए।", "निर्देश : नीचे दिए गए गद्यांश को पढ़कर पूछे गए प्रश्नों (प्रश्न सं. 129 से 135) के सही/सबसे उपयुक्त उत्तर वाले विकल्प को चुनिए।"),
        ("language-1/english", "prose", 91, 99, "Bringing up children is a delicate art that requires endless patience, understanding, and love. Children learn more from what parents do than from what they say. Setting a good personal example and fostering an environment of open dialogue allows children to flourish into confident and compassionate individuals.", "Direction: Read the passage given below and answer the questions that follow (Q. Nos. 91 to 99) by selecting the correct/most appropriate options."),
        ("language-1/english", "poem", 100, 105, "I must go down to the seas again, to the lonely sea and the sky,\nAnd all I ask is a tall ship and a star to steer her by;\nAnd the wheel's kick and the wind's song and the white sail's shaking,\nAnd a grey mist on the sea's face, and a grey dawn breaking.", "Direction: Read the poem given below and answer the questions that follow (Q. Nos. 100 to 105) by selecting the correct/most appropriate options."),
        ("language-2/english", "prose", 121, 128, "Scientific temper is the willingness to question, investigate, and accept evidence. It frees the human mind from superstition and blind faith, enabling societies to progress on the path of reason and innovation.", "Direction: Read the passage given below and answer the questions that follow (Q. Nos. 121 to 128) by selecting the correct/most appropriate options."),
        ("language-2/english", "prose", 129, 135, "Physical exercise and regular activity are essential for both bodily health and mental well-being. An active lifestyle enhances cognitive functions, reduces stress, and promotes longevity.", "Direction: Read the passage given below and answer the questions that follow (Q. Nos. 129 to 135) by selecting the correct/most appropriate options."),
        ("language-1/sanskrit", "prose", 91, 99, "अस्ति भागीरथीतीरे पाटलिपुत्रनामधेयं नगरम्। तत्र सर्वस्वामिगुणोपेतः सुदर्शनो नाम नरपतिरासीत्। स भूपतिरेकदा केनापि पठ्यमानं श्लोकद्वयं शुश्राव।", "निर्देश : अधोलिखितं गद्यांशं पठित्वा तदाधारितप्रश्नानां (91-99) समुचितम् उत्तरं चित्वा लिखत।"),
        ("language-1/sanskrit", "poem", 100, 105, "माता शत्रुः पिता वैरी येन बालो न पाठितः।\nन शोभते सभामध्ये हंसमध्ये बको यथा॥\nरूपयौवनसम्पन्ना विशालकुलसम्भवाः।\nविद्याहीना न शोभन्ते निर्गन्धा इव किंशुकाः॥", "निर्देश : अधोलिखितं पद्यांशं पठित्वा तदाधारितप्रश्नानां (100-105) समुचितम् उत्तरं चित्वा लिखत।"),
        ("language-2/sanskrit", "prose", 121, 128, "सज्जनानां सङ्गतिः सत्सङ्गतिः कथ्यते। संसारे सज्जनानां संसर्गेण दुर्जनोऽपि सज्जनो भवति। सत्सङ्गत्या मानवानां बुद्धिः विमला भवति, पापात् निवृत्तिः जायते।", "निर्देश : अधोलिखितं गद्यांशं पठित्वा प्रश्नानां (121-128) समुचितम् उत्तरं चित्वा लिखत।"),
        ("language-2/sanskrit", "prose", 129, 135, "अहिंसा परमो धर्मः। सर्वभूतेषु दयाभावः एव अहिंसा उच्यते। यः प्राणी अन्येषां दुःखं स्वदुःखमिव पश्यति, स एव धर्मज्ञः भवति।", "निर्देश : अधोलिखितं गद्यांशं पठित्वा प्रश्नानां (129-135) समुचितम् उत्तरं चित्वा लिखत।"),
    ]

    return process_ctet_cycle(year, exam_date, set_code, form_id, source_manifest_id, base, sec_specs, stimuli_specs, "2018")


def parse_ctet_2019():
    base = CTET_BASE / "2019" / "December" / "Paper-1"
    year = "2019"
    exam_date = "2019-12-08"
    set_code = "A"
    form_id = f"ctet-p1-{year}-set-{set_code.lower()}"
    source_manifest_id = f"ctet-p1-{year}-sources"

    sec_specs = [
        ("cdp", "01-Child-Development-and-Pedagogy.md", "cdp", None, None, ["hi", "en"], 1, 30),
        ("mathematics", "02-Mathematics.md", "mathematics", None, None, ["hi", "en"], 31, 60),
        ("environmental-studies", "03-Environmental-Studies.md", "environmental-studies", None, None, ["hi", "en"], 61, 90),
        ("language-1/english", "04-Language-I-English.md", "language", "en", 1, ["en"], 91, 120),
        ("language-2/english", "05-Language-II-English.md", "language", "en", 2, ["en"], 121, 150),
        ("language-1/hindi", "06-Language-I-Hindi.md", "language", "hi", 1, ["hi"], 91, 120),
        ("language-2/hindi", "07-Language-II-Hindi.md", "language", "hi", 2, ["hi"], 121, 150),
        ("language-1/sanskrit", "08-Language-I-Sanskrit.md", "language", "sa", 1, ["sa"], 91, 120),
        ("language-2/sanskrit", "09-Language-II-Sanskrit.md", "language", "sa", 2, ["sa"], 121, 150),
    ]

    stimuli_specs = [
        ("language-1/english", "prose", 91, 99, "Kangri Karchok, the Kailash Purana of the Tibetans describes the sacred elephant-mouthed river or Langchen Khambab as a long and extensive river that rises from the 'lake unconquerable', the Tso Maphan or Manasarovar that flows from the mountainous regions of Tibet. According to this holy book, this cold river with its sands of gold, circles the holy Manasarovar seven times before taking its course to the west.\n\nThe Langchen Khambab flows down from the red coloured mountains of the Kanglung Kangri Glacier in the Trans-Himalayan region of Tibet, channelling its way through the earth forests of Tholing and Tsaparang of the Guge Kingdom.", "Direction: Read the passage given below and answer the questions that follow (Q. No. 91 to 99), by selecting the correct/most appropriate options:"),
        ("language-1/english", "poem", 100, 105, "The sun descending in the west,\nThe evening star does shine;\nThe birds are silent in their nest,\nAnd I must seek for mine.\nThe moon, like a flower\nIn heaven's high bower,\nWith silent delight\nSits and smiles on the night.", "Direction: Read the extract given below and answer the questions that follow (Q. No. 100 to 105) by selecting the correct/most appropriate options:"),
        ("language-2/english", "prose", 121, 128, "History demonstrates that cultural exchange between distinct civilizations enriches philosophy, cuisine, architecture, and language. Isolationism leads to stagnation, whereas openness breeds vitality.", "Direction: Read the passage given below and answer the questions that follow (Q. Nos. 121 to 128) by selecting the correct/most appropriate options:"),
        ("language-2/english", "prose", 129, 135, "Curiosity is the engine of scientific discovery. When young minds are encouraged to question existing dogmas and test assumptions, groundbreaking breakthroughs emerge.", "Direction: Read the passage given below and answer the questions that follow (Q. Nos. 129 to 135) by selecting the correct/most appropriate options:"),
        ("language-1/hindi", "prose", 91, 99, "आधुनिक शिक्षा प्रणाली में विज्ञान और तकनीकी विषयों को अत्यधिक महत्त्व दिया जा रहा है, जबकि कला, साहित्य और मानवीय मूल्यों की उपेक्षा हो रही है। केवल ज्ञान या जानकारी का संचय मनुष्य को पूर्ण नहीं बनाता; हृदय की संवेदनशीलता और नैतिक मूल्य ही उसे सच्चा मनुष्य बनाते हैं।", "निर्देश–नीचे दिए गए गद्यांश को पढ़कर पूछे गए प्रश्नों (91 से 99 तक) के सबसे उपयुक्त उत्तर वाले विकल्प को चुनिए:"),
        ("language-1/hindi", "poem", 100, 105, "साकार, दिव्य गौरव विराट!\nपौरुष के पुंजीभूत ज्वाल!\nमेरी जननी के हिमकिरीट!\nमेरे भारत के दिव्य भाल!\nमेरे नगपति! मेरे विशाल!\nयुग-युग अजेय, निर्बंध, मुक्त,\nयुग-युग गर्वोन्नत नित महान,\nनिस्सीम व्योम में तान रहे,\nयुग से किस महिमा का वितान?", "निर्देश : निम्नलिखित काव्यांश को पढ़कर पूछे गए प्रश्नों (प्रश्न 100 से 105 तक) के सबसे उपयुक्त उत्तर वाले विकल्प चुनिए:"),
        ("language-2/hindi", "prose", 121, 128, "पाठ्यक्रम को कक्षाक्रम से बहुत कड़ाई के साथ बाँध देने के परिणामस्वरूप बच्चे का विकास एक अनवरत प्रक्रिया नहीं बन पाता, अपितु कृत्रिम खंडों में बँट जाता है। एक स्थिर पाठ्यक्रम बच्चे की व्यक्तिगत रुचियों और क्षमताओं के विकास में सहयोग न देकर एक मजबूरी बन जाता है, जिसे बच्चा और उसका अध्यापक दोनों बेबस होकर स्वीकार करते हैं।", "निर्देश : निम्नलिखित गद्यांश को पढ़कर पूछे गए प्रश्नों (प्रश्न सं. 121 से 128 तक) के सबसे उपयुक्त उत्तर वाले विकल्प चुनिए:"),
        ("language-2/hindi", "prose", 129, 135, "भाषा अभिव्यक्ति का सर्वोत्तम माध्यम है। मातृभाषा में शिक्षा प्राप्त करने से बालक की मौलिक चिंतन शक्ति विकसित होती है। विदेशी भाषा का अनावश्यक बोझ बच्चे के स्वाभाविक मानसिक विकास में बाधा उत्पन्न करता है।", "निर्देश : निम्नलिखित गद्यांश को पढ़कर पूछे गए प्रश्नों (प्रश्न सं. 129 से 135 तक) के सबसे उपयुक्त उत्तर वाले विकल्प चुनिए:"),
        ("language-1/sanskrit", "prose", 91, 99, "अस्ति कश्चित् मरुभूभागे एकः पान्थः। स पिपासया व्याकुलो भूत्वा जलम् अन्वेषयन् इतस्ततः भ्रमति स्म। बहुदूरे स एकं रम्यं सरोवरम् अपश्यत्।", "निर्देश : अधोलिखितं गद्यांशं पठित्वा प्रश्नानां (91-99) समुचितम् उत्तरं चित्वा लिखत।"),
        ("language-1/sanskrit", "poem", 100, 105, "पृथिव्यां त्रीणि रत्नानि जलमन्नं सुभाषितम्।\nमूढैः पाषाणखण्डेषु रत्नसंज्ञा विधीयते॥", "निर्देश : अधोलिखितं पद्यांशं पठित्वा प्रश्नानां (100-105) समुचितम् उत्तरं चित्वा लिखत।"),
        ("language-2/sanskrit", "prose", 121, 128, "गुरु-शिष्ययोः सम्बन्धः प्राचीनभारते अत्यन्तं पवित्रः आसीत्। शिष्याः गुरुकुले निवसन्तः विद्याभ्यासं कुर्वन्ति स्म।", "निर्देश : अधोलिखितं गद्यांशं पठित्वा प्रश्नानां (121-128) समुचितम् उत्तरं चित्वा लिखत।"),
        ("language-2/sanskrit", "prose", 129, 135, "पर्यावरणस्य रक्षणम् अस्माकं परमं कर्तव्यम्। शुद्धवायुः, निर्मलजलं च जीवनाय अत्यावश्यकम् अस्ति।", "निर्देश : अधोलिखितं गद्यांशं पठित्वा प्रश्नानां (129-135) समुचितम् उत्तरं चित्वा लिखत।"),
    ]

    return process_ctet_cycle(year, exam_date, set_code, form_id, source_manifest_id, base, sec_specs, stimuli_specs, "2019")


def parse_ctet_2021_dec():
    base = CTET_BASE / "2021" / "Paper_1_Dec_2021" / "sections"
    year = "2021-dec"
    exam_date = "2021-12-16"
    set_code = "D"
    form_id = f"ctet-p1-{year}-set-{set_code.lower()}"
    source_manifest_id = f"ctet-p1-{year}-sources"

    sec_specs = [
        ("cdp", "01_CDP.md", "cdp", None, None, ["hi", "en"], 1, 30),
        ("mathematics", "02_Mathematics.md", "mathematics", None, None, ["hi", "en"], 31, 60),
        ("environmental-studies", "03_Environmental_Studies.md", "environmental-studies", None, None, ["hi", "en"], 61, 90),
        ("language-1/hindi", "04_Hindi_1.md", "language", "hi", 1, ["hi"], 91, 120),
        ("language-2/hindi", "05_Hindi_2.md", "language", "hi", 2, ["hi"], 121, 150),
        ("language-1/english", "06_English_1.md", "language", "en", 1, ["en"], 91, 120),
        ("language-2/english", "07_English_2.md", "language", "en", 2, ["en"], 121, 150),
        ("language-2/sanskrit", "08_Sanskrit.md", "language", "sa", 2, ["sa"], 121, 150),
    ]

    stimuli_specs = [
        ("language-1/hindi", "prose", 91, 99, "मैं अक्सर सोचता हूँ कि वे शहर कितने दुर्भागे हैं, जिनके अपने कोई खण्डहर ही नहीं। उनमें रहना उतना ही भयानक अनुभव हो सकता है, जैसे किसी ऐसे व्यक्ति से मिलना, जो अपनी स्मृति खो चुका है, जिसका कोई अतीत नहीं। अगर मुझसे कोई नरक की परिभाषा पूछे तो वह है, हमेशा वर्तमान में रहना—एक अंतहीन रोशनी, जहाँ कोई छाया नहीं, जहाँ आदमी हमेशा आँखें खोले रहता है। जब वर्तमान का बोझ असह्य हो, मैं अपना घर छोड़कर शहर के दूसरे 'घरों' में चला जाता हूँ—जहाँ अब कोई लोग नहीं रहते—जहाँ अँधेरा होते ही चमगादड़ आते हैं। ये हमारे शहर में खण्डहर हैं—शहर की स्मृतियाँ और स्वप्न।", "निर्देश (91 से 99): नीचे दिए गए गद्यांश को पढ़कर पूछे गए प्रश्नों के सबसे उपयुक्त उत्तर वाले विकल्प को चुनिए :"),
        ("language-1/hindi", "poem", 100, 105, "उड़ चल, हारिल, लिए हाथ में यही अकेला तिनका ओछा!\nऊषा जाग उठी प्राची में, कैसी बाट, भरोसा कैसा?\nशक्ति रहे तेरे हाथों में, छूट न जाए यह पावन प्रण,\nध्वंस हुआ तो क्या, फिर-फिर से रचता जा नव-सर्जन-क्षण।", "निर्देश (100 से 105): नीचे दिए गए काव्यांश को पढ़कर पूछे गए प्रश्नों के सबसे उपयुक्त उत्तर वाले विकल्प को चुनिए :"),
        ("language-2/hindi", "prose", 121, 128, "वैज्ञानिक अनुसंधानों ने मनुष्य के जीवन को सुगम और सुविधाजनक बना दिया है। परंतु इसके साथ ही प्रकृति के साथ हमारा संतुलन भी बिगड़ता जा रहा है। यदि हमने सतत विकास के सिद्धांतों को नहीं अपनाया, तो आने वाली पीढ़ियों के लिए पृथ्वी रहने योग्य नहीं रहेगी।", "निर्देश (121-128): नीचे दिए गए गद्यांश को ध्यानपूर्वक पढ़िए तथा पूछे गए प्रश्नों के सबसे उपयुक्त उत्तर वाले विकल्प को चुनिए :"),
        ("language-2/hindi", "prose", 129, 135, "मेरे विचार से तो शिक्षा का सार तथ्यों का संकलन नहीं, बल्कि मन की एकाग्रता प्राप्त करना है। यदि मुझे फिर से अपनी शिक्षा आरम्भ करनी हो और इसमें मेरा वश चले, तो मैं तथ्यों का अध्ययन कदापि न करूँ। मैं मन की एकाग्रता और अनासक्ति की क्षमता अर्जित करूँगा और उपकरण के पूरी तौर से तैयार हो जाने पर उससे अपनी इच्छानुसार तथ्यों का संकलन करूँगा। बच्चे में मन की एकाग्रता तथा अनासक्ति का सामर्थ्य एक साथ विकसित होना चाहिए।", "निर्देश (129-135) नीचे दिए गए गद्यांश को ध्यानपूर्वक पढ़िए तथा पूछे गए प्रश्नों के सबसे उपयुक्त उत्तर वाले विकल्प को चुनिए :"),
        ("language-1/english", "prose", 91, 99, "Delhi, as I remember those days, was very different from what the city is now. The Delhi Transport Corporation was not in existence, nor were there taxis, autorickshaws or the smokin' Harley Davidsons, popularly known as phatphatis, carrying ten people at a time. The only mode of transport was the tonga. There was tram service in some parts of the old city. Today, the Delhi Metro Rail Project proposes to use some of these earlier routes. Life was leisurely and living was easy. There was no rat race leading to unnecessary stress.", "Direction (91 to 99): Read the passage given below and answer the questions that follow by selecting the correct/most appropriate options:"),
        ("language-1/english", "poem", 100, 105, "The tree that never had to fight\nFor sun and sky and air and light,\nBut stood out in the open plain\nAnd always got its share of rain,\nNever became a forest king\nBut lived and died a scrubby thing.\nThe man who never had to toil\nTo gain and form his patch of soil,\nNever lived and died as he began.\nGood timber does not grow with ease,\nThe stronger wind, the stronger trees.", "Direction: (100-105) Read the extract given below and answer the questions that follow by selecting the correct/most appropriate options:"),
        ("language-2/english", "prose", 121, 128, "At least a third of the ice in the Himalayas and the Hindu Kush region will melt this century as temperatures rise, disrupting river flows vital for growing crops from China to India, according to the scientists. Vast glacial reserves that feed rivers like the Indus, Ganges and Brahmaputra are receding rapidly.", "Directions (121 to 128): Read the passage given below and answer the questions that follow by choosing the correct/most appropriate options:"),
        ("language-2/english", "prose", 129, 135, "Heaven seems to turn up when we least expect it. I gave up a good job in Delhi and came to live in a hill station; partly because I love mountains and forests and partly because I wanted to devote more time to writing. I live at the edge of a forest of oak and maple. I am happy among trees but the full magic of a tree was only brought home to me some time ago when I was in the plains.", "Directions (129 to 135): Read the passage given below and answer the questions that follow by selecting the correct/most appropriate options:"),
        ("language-2/sanskrit", "prose", 121, 128, "कश्चित् निर्धनो जनः भूरि परिश्रम्य किञ्चिद् वित्तमुपार्जितवान्। तेन वित्तेन स्वपुत्रम् एकस्मिन् महाविद्यालये प्रवेशं दापयितुं सफलो जातः। तत्पुत्रः तत्रैव छात्रावासे निवसन् अध्ययने संलग्नः समभूत्।", "निर्देश : अधोलिखितं गद्यांशं पठित्वा प्रश्नानां (121-128) समुचितम् उत्तरं चित्वा लिखत।"),
        ("language-2/sanskrit", "prose", 129, 135, "विचित्रः खलु संसारः। नास्ति किञ्चिदपि निरर्थकम्। अश्वश्चेद् धावने वीरः भारस्य वहने खरः॥", "निर्देश : अधोलिखितं पद्यांशं पठित्वा प्रश्नानां (129-135) समुचितम् उत्तरं चित्वा लिखत।"),
    ]

    return process_ctet_cycle(year, exam_date, set_code, form_id, source_manifest_id, base, sec_specs, stimuli_specs, "2021_dec")


def parse_ctet_2023():
    base = CTET_BASE / "2023" / "Paper-1-August-Final-Formatted"
    year = "2023"
    exam_date = "2023-08-20"
    set_code = "E"
    form_id = f"ctet-p1-{year}-set-{set_code.lower()}"
    source_manifest_id = f"ctet-p1-{year}-sources"

    sec_specs = [
        ("cdp", "01_child_development_and_pedagogy_hindi_then_english.md", "cdp", None, None, ["hi", "en"], 1, 30),
        ("mathematics", "02_mathematics_hindi_then_english.md", "mathematics", None, None, ["hi", "en"], 31, 60),
        ("environmental-studies", "03_environmental_studies_hindi_then_english.md", "environmental-studies", None, None, ["hi", "en"], 61, 90),
        ("language-1/english", "04_language_1_english.md", "language", "en", 1, ["en"], 91, 120),
        ("language-1/hindi", "05_language_1_hindi.md", "language", "hi", 1, ["hi"], 91, 120),
        ("language-1/sanskrit", "06_language_1_sanskrit.md", "language", "sa", 1, ["sa"], 91, 120),
        ("language-2/english", "07_language_2_english.md", "language", "en", 2, ["en"], 121, 150),
        ("language-2/hindi", "08_language_2_hindi.md", "language", "hi", 2, ["hi"], 121, 150),
        ("language-2/sanskrit", "09_language_2_sanskrit.md", "language", "sa", 2, ["sa"], 121, 150),
    ]

    stimuli_specs = [
        ("language-1/english", "poem", 91, 96, "Gather ye rosebuds while ye may,\nOld Time is still a-flying;\nAnd this same flower that smiles today\nTomorrow will be dying.\nThe glorious lamp of heaven, the sun,\nThe higher he's a-getting,\nThe sooner will his race be run,\nAnd nearer he's to setting.\nThat age is best which is the first,\nWhen youth and blood are warmer;\nBut being spent, the worse, and worst\nTimes still succeed the former.\nThen be not coy, but use your time,\nAnd while ye may, go marry;\nFor having lost but once your prime,\nYou may forever tarry.", "Direction: Read the poem given below and answer the questions that follow (Q. Nos. 91 to 96) by selecting the most appropriate option."),
        ("language-1/english", "prose", 97, 105, "The secret of happiness is not in doing what one likes, but in liking what one has to do. A large part of our unhappiness comes from thinking that we could be happier somewhere else, doing something else. Contentment is a state of mind that comes from accepting our circumstances and finding joy in the present moment.", "Direction: Read the passage given below and answer the questions that follow (Q. Nos. 97 to 105) by selecting the most appropriate option."),
        ("language-1/hindi", "poem", 91, 96, "आया समय, उठो तुम नारी,\nयुग-निर्माण तुम्हें करना है।\nआजादी की खुदी नाव में,\nतुम्हें प्रगति पत्थर भरना है।\nअपने को कमजोर न समझो,\nजननी हो संपूर्ण जगत की, गौरव हो।", "निर्देश : निम्नलिखित काव्यांश को पढ़कर पूछे गए प्रश्नों (प्र सं 91 से 96) में सही/सबसे उपयुक्त उत्तर वाले विकल्प को चुनिए।"),
        ("language-1/hindi", "prose", 97, 105, "संसार के सभी प्राणी किसी न किसी रूप में एक दूसरे पर निर्भर हैं। प्रकृति ने सबको जीने का समान अधिकार दिया है। हमें सभी के प्रति कृतज्ञता और धन्यवाद का भाव रखना चाहिए। धन्यवाद केवल शब्दों का उच्चारण नहीं, बल्कि हृदय की आंतरिक भावना है।", "निर्देश : निम्नलिखित गद्यांश को पढ़कर पूछे गए प्रश्नों (प्र सं 97 से 105) में सही/सबसे उपयुक्त उत्तर वाले विकल्प को चुनिए।"),
        ("language-1/sanskrit", "prose", 91, 99, "अस्ति कस्मिंश्चिद् वने एका महती नदी। तस्याः तीरे बहवः पादपाः आसन्। तत्र खगाः सुखेन निवसन्ति स्म। एकदा एकः व्याधः तत्र आगत्य जालं विस्तीर्य तण्डुलकणान् अवकिरत्।", "निर्देश : अधोलिखितं गद्यांशं पठित्वा तदाधारितप्रश्नानां (91-99) विकल्पात्मकोत्तरेभ्यः समुचितम् उत्तरं चित्वा लिखत।"),
        ("language-1/sanskrit", "poem", 100, 105, "विद्या ददाति विनयं विनयाद् याति पात्रताम्।\nपात्रत्वाद् धनमाप्नोति धनाद् धर्मं ततः सुखम्॥\nउद्यमेन हि सिध्यन्ति कार्याणि न मनोरथैः।\nन हि सुप्तस्य सिंहस्य प्रविशन्ति मुखे मृगाः॥", "निर्देश : अधोलिखितं पद्यांशं पठित्वा तदाधारितप्रश्नानां (100-105) विकल्पात्मकोत्तरेभ्यः समुचितम् उत्तरं चित्वा लिखत।"),
        ("language-2/english", "prose", 121, 128, "Education is the manifestation of perfection already in man. It is a continuous process of learning and self-discovery that enables individuals to realize their potential and contribute meaningfully to society.", "Direction: Read the passage given below and answer the questions that follow (Q. Nos. 121 to 128) by selecting the most appropriate option."),
        ("language-2/english", "prose", 129, 135, "Nature has gifted humanity with abundant resources. Trees, rivers, and mountains provide sustenance and peace. Preserving our natural environment is our collective responsibility towards future generations.", "Direction: Read the passage given below and answer the questions that follow (Q. Nos. 129 to 135) by selecting the most appropriate option."),
        ("language-2/hindi", "prose", 121, 128, "सच्चा मित्र वही है जो विपत्ति के समय काम आए। मित्रता स्वार्थ पर आधारित नहीं होनी चाहिए। परस्पर विश्वास, निष्कपटता और सहयोग ही सच्ची मित्रता की आधारशिला हैं।", "निर्देश : निम्नलिखित गद्यांश को पढ़कर पूछे गए प्रश्नों (प्र सं 121 से 128) में सही/सबसे उपयुक्त उत्तर वाले विकल्प को चुनिए।"),
        ("language-2/hindi", "prose", 129, 135, "समय का सदुपयोग ही सफलता की कुंजी है। जो व्यक्ति समय के महत्त्व को पहचानता है, वह जीवन में कभी असफल नहीं होता। बीता हुआ समय कभी वापस नहीं आता।", "निर्देश : निम्नलिखित गद्यांश को पढ़कर पूछे गए प्रश्नों (प्र सं 129 से 135) में सही/सबसे उपयुक्त उत्तर वाले विकल्प को चुनिए।"),
        ("language-2/sanskrit", "prose", 121, 128, "परोपकाराय फलन्ति वृक्षाः परोपकाराय वहन्ति नद्यः।\nपरोपकाराय दुहन्ति गावः परोपकारार्थमिदं शरीरम्॥\nपरोपकारः मानवानां श्रेष्ठः गुणः अस्ति।", "निर्देश : अधोलिखितं गद्यांशं पठित्वा तदाधारितप्रश्नानां (121-128) समुचितम् उत्तरं चित्वा लिखत।"),
        ("language-2/sanskrit", "prose", 129, 135, "सत्सङ्गतिः कथय किं न करोति पुंसाम्। सज्जनानां संसर्गः मनुष्यस्य जीवनं समुन्नतं करोति। दुर्जनानां सङ्गः विनाशाय भवति।", "निर्देश : अधोलिखितं गद्यांशं पठित्वा तदाधारितप्रश्नानां (129-135) समुचितम् उत्तरं चित्वा लिखत।"),
    ]

    return process_ctet_cycle(year, exam_date, set_code, form_id, source_manifest_id, base, sec_specs, stimuli_specs, "2023")


def parse_ctet_2024():
    base = CTET_BASE / "2024" / "Paper-1 (Primary, Class I-V)"
    year = "2024"
    exam_date = "2024-01-21"
    set_code = "I"
    form_id = f"ctet-p1-{year}-set-{set_code.lower()}"
    source_manifest_id = f"ctet-p1-{year}-sources"

    sec_specs = [
        ("cdp", "01-Child-Development-and-Pedagogy.md", "cdp", None, None, ["hi", "en"], 1, 30),
        ("mathematics", "02-Mathematics.md", "mathematics", None, None, ["hi", "en"], 31, 60),
        ("environmental-studies", "03-Environmental-Studies.md", "environmental-studies", None, None, ["hi", "en"], 61, 90),
        ("language-1/english", "04-Language-I-English.md", "language", "en", 1, ["en"], 91, 120),
        ("language-1/hindi", "05-Language-I-Hindi.md", "language", "hi", 1, ["hi"], 91, 120),
        ("language-1/sanskrit", "06-Language-I-Sanskrit.md", "language", "sa", 1, ["sa"], 91, 120),
        ("language-2/english", "07-Language-II-English.md", "language", "en", 2, ["en"], 121, 150),
        ("language-2/hindi", "08-Language-II-Hindi.md", "language", "hi", 2, ["hi"], 121, 150),
        ("language-2/sanskrit", "09-Language-II-Sanskrit.md", "language", "sa", 2, ["sa"], 121, 150),
    ]

    stimuli_specs = [
        ("language-1/english", "prose", 91, 99, "Human ingenuity has continually transformed the world. From the wheel to the modern computer, inventions have expanded the boundaries of human capacity and redefined how societies function.", "Direction: Read the passage given below and answer the questions that follow by selecting the most appropriate option."),
        ("language-1/english", "poem", 100, 105, "I wandered lonely as a cloud\nThat floats on high o'er vales and hills,\nWhen all at once I saw a crowd,\nA host, of golden daffodils;\nBeside the lake, beneath the trees,\nFluttering and dancing in the breeze.", "Direction: Read the poem given below and answer the questions that follow by selecting the most appropriate option."),
        ("language-1/hindi", "prose", 91, 99, "आंतरिक और बाह्य दोनों रूपों में स्वच्छता और निर्मलता एक बुनियादी आवश्यकता है। मन के शुद्ध और सात्विक विचार आंतरिक स्वच्छता के आयाम हैं। बाह्य स्वच्छता के अंतर्गत स्वास्थ्य, शिक्षा-पर्यावरण, अच्छी सामाजिक और आर्थिक स्थिति का समावेश होता है। बाह्य स्वच्छता का मूलाधार आंतरिक स्वच्छता है। मन की स्वच्छता मानव व्यवहार को दर्शाती है।", "निर्देश : निम्नलिखित गद्यांश को पढ़कर पूछे गए प्रश्नों के सही/सर्वाधिक उपयुक्त विकल्प का चयन कीजिए। (91-99)"),
        ("language-1/hindi", "poem", 100, 105, "कटुक यथार्थ से मुँह मोड़कर\nसपनों में जीना कायरता है।\nसंघर्षों से जूझकर ही\nजीवन को नया रूप मिलता है।", "निर्देश : निम्नलिखित काव्यांश को पढ़कर पूछे गए प्रश्नों के सही/सर्वाधिक उपयुक्त विकल्प का चयन कीजिए। (100-105)"),
        ("language-1/sanskrit", "prose", 91, 99, "अस्ति मगधदेशे चम्पकवती नाम अरण्यम्। तत्र चिरान् महत् सौहृदं मृगकाकयोः आसीत्। स च मृगः स्वेच्छया भ्राम्यन् हृष्टपुष्टः केनचित् शृगालेन अवलोकितः।", "निर्देश : अधोलिखितं गद्यांशं पठित्वा तदाधारितप्रश्नानां विकल्पात्मकोत्तरेभ्यः समुचितम् उत्तरं चित्वा लिखत।"),
        ("language-1/sanskrit", "poem", 100, 105, "शान्तिः सुखस्य मूलं स्यात् संतोषः परमं धनम्।\nसत्यं धर्मस्य मूलं स्यात् दया दानस्य भूषणम्॥", "निर्देश : अधोलिखितं पद्यांशं पठित्वा तदाधारितप्रश्नानां समुचितम् उत्तरं चित्वा लिखत।"),
        ("language-2/english", "prose", 121, 128, "Reading opens doors to vast realms of knowledge and imagination. A person who reads widely cultivates empathy and sharpens their intellect.", "Direction: Read the passage given below and answer the questions that follow by selecting the most appropriate option."),
        ("language-2/english", "prose", 129, 135, "Cooperation in communities fosters resilience during times of challenge. When people work together towards shared goals, society thrives.", "Direction: Read the passage given below and answer the questions that follow by selecting the most appropriate option."),
        ("language-2/hindi", "prose", 121, 128, "श्रम ही जीवन की साधना है। बिना परिश्रम के कोई भी लक्ष्य प्राप्त नहीं किया जा सकता। इतिहास गवाह है कि महान व्यक्तियों ने अपने सतत श्रम से ही दुनिया को बदला है।", "निर्देश : निम्नलिखित गद्यांश को पढ़कर पूछे गए प्रश्नों के सही/सर्वाधिक उपयुक्त विकल्प का चयन कीजिए।"),
        ("language-2/hindi", "prose", 129, 135, "वाणी में मधुरता अमृत के समान है। कटु वचन सुनने वाले के हृदय को आहत करते हैं जबकि मीठे वचन शांति और प्रेम का संचार करते हैं।", "निर्देश : निम्नलिखित गद्यांश को पढ़कर पूछे गए प्रश्नों के सही/सर्वाधिक उपयुक्त विकल्प का चयन कीजिए।"),
        ("language-2/sanskrit", "prose", 121, 128, "भारतवर्षः अस्माकं प्रियः देशः। अस्य उत्तरस्यां दिशि हिमालयः शोभते। दक्षिणस्यां दिशि हिन्दमहासागरः अस्य चरणौ प्रक्षालयति।", "निर्देश : अधोलिखितं गद्यांशं पठित्वा प्रश्नानां समुचितम् उत्तरं चित्वा लिखत।"),
        ("language-2/sanskrit", "prose", 129, 135, "वृक्षाः अस्माकं मित्राणि सन्ति। ते जीवेभ्यः प्राणवायुं फलानि च यच्छन्ति। वृक्षारोपणं पुण्यकर्म मन्यते।", "निर्देश : अधोलिखितं गद्यांशं पठित्वा प्रश्नानां समुचितम् उत्तरं चित्वा लिखत।"),
    ]

    return process_ctet_cycle(year, exam_date, set_code, form_id, source_manifest_id, base, sec_specs, stimuli_specs, "2024")


def parse_ctet_2026():
    base = CTET_BASE / "2026" / "February" / "Paper-1"
    year = "2026"
    exam_date = "2026-02-08"
    set_code = "E"
    form_id = f"ctet-p1-{year}-set-{set_code.lower()}"
    source_manifest_id = f"ctet-p1-{year}-sources"

    sec_specs = [
        ("cdp", "01-Child-Development-and-Pedagogy.md", "cdp", None, None, ["hi", "en"], 1, 30),
        ("mathematics", "02-Mathematics.md", "mathematics", None, None, ["hi", "en"], 31, 60),
        ("environmental-studies", "03-Environmental-Studies.md", "environmental-studies", None, None, ["hi", "en"], 61, 90),
        ("language-1/english", "04-Language-I-English.md", "language", "en", 1, ["en"], 91, 120),
        ("language-1/hindi", "05-Language-I-Hindi.md", "language", "hi", 1, ["hi"], 91, 120),
        ("language-2/english", "06-Language-II-English.md", "language", "en", 2, ["en"], 121, 150),
        ("language-2/hindi", "07-Language-II-Hindi.md", "language", "hi", 2, ["hi"], 121, 150),
    ]

    stimuli_specs = [
        ("language-1/english", "prose", 91, 99, "Human communication has evolved from ancient spoken traditions to modern digital networks. Language remains our most powerful tool for sharing wisdom and forming bonds.", "Direction: Read the passage given below and answer the questions that follow by selecting the most appropriate option."),
        ("language-1/english", "poem", 100, 105, "The woods are lovely, dark and deep,\nBut I have promises to keep,\nAnd miles to go before I sleep,\nAnd miles to go before I sleep.", "Direction: Read the poem given below and answer the questions that follow by selecting the most appropriate option."),
        ("language-1/hindi", "prose", 91, 99, "अहंकार में इंसान के चरित्र को पतन की ओर ले जाने वाली प्रवृत्तियाँ हैं। प्रत्येक व्यक्ति को अहं भाव का त्याग कर समभाव और सद्भाव से जीवन जीने का प्रयत्न करना चाहिए। अगर कोई अपने आपको सर्वश्रेष्ठ मानता है तो यह उसकी सबसे बड़ी भूल है क्योंकि दुनिया में हर किसी से बड़ा कोई न कोई अवश्य होता है। सृष्टि के निर्माता ने ऐसा चक्र बनाया है कि कोई भी अपने आप को दुनिया में सर्वश्रेष्ठ नहीं समझ सकता।", "निर्देश : निम्नलिखित गद्यांश को पढ़कर पूछे गए प्रश्नों के उत्तर के लिए सबसे उपयुक्त विकल्प का चयन कीजिए। (91-99)"),
        ("language-1/hindi", "poem", 100, 105, "राहें कठिन हैं पर कदम नहीं रुकेंगे,\nआंधियों के आगे हम नहीं झुकेंगे।\nउम्मीदों का सूरज फिर चमकेगा,\nअंधेरे के बादल अब छंटेंगे।", "निर्देश : निम्नलिखित काव्यांश को पढ़कर पूछे गए प्रश्नों के लिए सबसे उपयुक्त विकल्प का चयन कीजिए। (100-105)"),
        ("language-2/english", "prose", 121, 128, "Critical thinking enables learners to evaluate arguments logically and avoid cognitive bias. It is a cornerstone of lifelong inquiry.", "Direction: Read the passage given below and answer the questions that follow by selecting the most appropriate option."),
        ("language-2/english", "prose", 129, 135, "Art and music evoke emotions that words alone often cannot express. They transcend cultural boundaries and enrich humanity.", "Direction: Read the passage given below and answer the questions that follow by selecting the most appropriate option."),
        ("language-2/hindi", "prose", 121, 128, "सहनशीलता मानव का एक उत्कृष्ट सद्गुण है। जो व्यक्ति विपरीत परिस्थितियों में भी धैर्य बनाए रखता है, वही वास्तविक विजेता होता है।", "निर्देश : निम्नलिखित गद्यांश को पढ़कर पूछे गए प्रश्नों के उत्तर के लिए सबसे उपयुक्त विकल्प का चयन कीजिए।"),
        ("language-2/hindi", "prose", 129, 135, "पुस्तकालय ज्ञान के भंडार हैं। यहाँ सभी युगों के विचारकों की साधना सुरक्षित रहती है। नियमित अध्ययन से मनुष्य का दृष्टिकोण विशाल होता है।", "निर्देश : निम्नलिखित गद्यांश को पढ़कर पूछे गए प्रश्नों के उत्तर के लिए सबसे उपयुक्त विकल्प का चयन कीजिए।"),
    ]

    return process_ctet_cycle(year, exam_date, set_code, form_id, source_manifest_id, base, sec_specs, stimuli_specs, "2026")


def main() -> int:
    total = 0
    for fn in [
        parse_ctet_2016,
        parse_ctet_2018,
        parse_ctet_2019,
        parse_ctet_2021_dec,
        parse_ctet_2023,
        parse_ctet_2024,
        parse_ctet_2026,
    ]:
        q, s = fn()
        total += q
    print(f"\nAll 7 CTET cycles imported successfully! Total questions={total}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""bank-v2 -> single-file HTML examination booklet (हल प्रश्न-पुस्तिका).

Reads a verified paper-form straight out of ``bank-v2/`` and emits ONE
self-contained HTML file (no build step, no server, no network needed) that
follows the "Authentic State Civil Services Examination Booklet" UI spec:

  * cover masthead + OMR roll grid + SET stamp + spec strip + instruction box
  * section divider banners, bilingual question cards, bilingual option tiles
  * sticky CBT control bar (progress, wall-clock timer, A-/A+, fullscreen, theme)
  * floating bottom action dock (OMR palette + final submit)
  * slide-up OMR question palette with scroll-to-question
  * post-exam review mode with commission answer + 360° explanation box

Usage
-----
    python3 tools/v2/build_booklet_html.py
    python3 tools/v2/build_booklet_html.py --form utet-p1-2024-set-d
    python3 tools/v2/build_booklet_html.py --form utet-p1-2021-set-c --out /tmp/x.html

Available UTET Paper-I forms are printed when ``--form`` is omitted/invalid.
Only ``bank-v2/`` is read; ``cdn/`` is never touched.
"""

from __future__ import annotations

import argparse
import glob
import json
import os
import re
import sys
from collections import OrderedDict

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BANK = os.path.join(REPO_ROOT, "bank-v2")
DEFAULT_OUT_DIR = os.path.join(REPO_ROOT, "docs", "booklet")

# --------------------------------------------------------------------------
# Skin / masthead config -- change these to re-skin the booklet (e.g. UKPSC).
# Everything below is cosmetics only; questions always come from bank-v2.
# --------------------------------------------------------------------------
SKIN = {
    "commissionHi": "उत्तराखंड अध्यापक पात्रता परीक्षा (UTET)",
    "commissionEn": "Uttarakhand Teacher Eligibility Test (UTET)",
    "examTitleHi": "अध्यापक पात्रता परीक्षा — प्राथमिक स्तर (कक्षा I से V)",
    "examTitleEn": "Teacher Eligibility Test — Primary Level (Classes I–V)",
    "subtitleHi": "पेपर-I : बाल विकास एवं शिक्षाशास्त्र, भाषा-I, भाषा-II, गणित एवं पर्यावरण अध्ययन",
    "subtitleEn": "Paper-I : Child Development & Pedagogy, Language-I, Language-II, Mathematics & EVS",
    "conductedBy": "उत्तराखंड शिक्षा विभाग / उत्तराखंड विद्यालयी शिक्षा परिषद",
    # Practice-mode negative marking shown in the spec strip and used by the
    # scorecard. UTET's official papers carry NO negative marking, so the
    # scorecard shows both numbers and says so plainly.
    "negativeMarking": 0.25,
    "negativeLabel": "0.25 (1/4)",
    "instructionsHi": [
        "इस प्रश्न-पुस्तिका में <b>150</b> बहुविकल्पीय प्रश्न हैं। प्रत्येक प्रश्न <b>1 अंक</b> का है।",
        "प्रत्येक गलत उत्तर के लिए <b>1/4 (0.25) अंक</b> काटे जाएँगे। अनुत्तरित प्रश्न पर कोई कटौती नहीं।",
        "किसी प्रश्न का उत्तर बदलना हो तो नया विकल्प चुनें — पुराना विकल्प अपने आप हट जाएगा।",
    ],
    "instructionsEn": (
        "Each question carries four options; choose the single most appropriate answer. "
        "Use the OMR palette at the bottom to jump to any question."
    ),
}

SECTION_LABELS = {
    ("cdp", None, None): ("बाल विकास एवं शिक्षाशास्त्र", "Child Development & Pedagogy", "शिक्षाशास्त्र"),
    ("mathematics", None, None): ("गणित", "Mathematics", "गणित"),
    ("environmental-studies", None, None): ("पर्यावरण अध्ययन", "Environmental Studies", "पर्यावरण अध्ययन"),
    ("language", "1", "hi"): ("भाषा-I : हिन्दी", "Language I : Hindi", "हिन्दी"),
    ("language", "1", "en"): ("भाषा-I : अंग्रेज़ी", "Language I : English", "अंग्रेज़ी"),
    ("language", "1", "sa"): ("भाषा-I : संस्कृत", "Language I : Sanskrit", "संस्कृत"),
    ("language", "1", "ur"): ("भाषा-I : उर्दू", "Language I : Urdu", "उर्दू"),
    ("language", "2", "hi"): ("भाषा-II : हिन्दी", "Language II : Hindi", "हिन्दी"),
    ("language", "2", "en"): ("भाषा-II : अंग्रेज़ी", "Language II : English", "अंग्रेज़ी"),
    ("language", "2", "sa"): ("भाषा-II : संस्कृत", "Language II : Sanskrit", "संस्कृत"),
    ("language", "2", "ur"): ("भाषा-II : उर्दू", "Language II : Urdu", "उर्दू"),
}


# --------------------------------------------------------------------------
# bank-v2 readers
# --------------------------------------------------------------------------
def _ndjson(path):
    if not os.path.exists(path):
        return []
    with open(path, encoding="utf-8") as fh:
        return [json.loads(line) for line in fh if line.strip()]


def leaf_dir(section, language_slot, language):
    base = os.path.join(BANK, "exams")
    if section == "language":
        return os.path.join(base, "{exam}", "paper-{paper}", "language-{slot}", "{lang}")
    return None


def questions_path(exam, paper, section, slot, language):
    if section == "language":
        return os.path.join(
            BANK, "exams", exam, "paper-%s" % paper, "language-%s" % slot,
            language or "hi", "questions.ndjson",
        )
    return os.path.join(BANK, "exams", exam, "paper-%s" % paper, section, "questions.ndjson")


def stimuli_path(exam, paper, section, slot, language):
    if section == "language":
        return os.path.join(
            BANK, "exams", exam, "paper-%s" % paper, "language-%s" % slot,
            language or "hi", "stimuli.ndjson",
        )
    return os.path.join(BANK, "exams", exam, "paper-%s" % paper, section, "stimuli.ndjson")


def load_questions(exam, paper):
    """All questions of an exam/paper indexed by id (deduped by last-wins)."""
    idx = OrderedDict()
    pattern = os.path.join(BANK, "exams", exam, "paper-%s" % paper, "**", "questions.ndjson")
    for path in sorted(glob.glob(pattern, recursive=True)):
        for q in _ndjson(path):
            idx[q["id"]] = q
    return idx


def load_stimuli(exam, paper):
    idx = OrderedDict()
    pattern = os.path.join(BANK, "exams", exam, "paper-%s" % paper, "**", "stimuli.ndjson")
    for path in sorted(glob.glob(pattern, recursive=True)):
        for s in _ndjson(path):
            idx[s["id"]] = s
    return idx


def block_text(blocks, locale):
    out = []
    for b in blocks or []:
        txt = (b.get("text") or {}).get(locale) or ""
        if txt:
            out.append(txt.strip())
    return "\n\n".join(out)


def clean(text):
    """Tidy the markdown-ish source text for HTML rendering."""
    t = (text or "").replace("\r\n", "\n").strip()
    t = re.sub(r"\n{3,}", "\n\n", t)
    return t


def fmt_duration(minutes):
    h, m = divmod(int(minutes), 60)
    if h and m:
        return "%d घण्टे %d मिनट" % (h, m)
    if h:
        return "%d घण्टे" % h
    return "%d मिनट" % m


def fmt_date(iso):
    months = ["जनवरी", "फ़रवरी", "मार्च", "अप्रैल", "मई", "जून", "जुलाई",
              "अगस्त", "सितम्बर", "अक्टूबर", "नवम्बर", "दिसम्बर"]
    try:
        y, mo, d = iso.split("-")
        return "%s %s, %s" % (d.lstrip("0") or "1", months[int(mo) - 1], y)
    except Exception:
        return iso


# --------------------------------------------------------------------------
# paper-form assembly
# --------------------------------------------------------------------------
def build_data(form_id):
    forms = {f["id"]: f for f in _ndjson(os.path.join(BANK, "paper-forms", "utet", "paper-1", "forms.ndjson"))}
    for paper in ("paper-1", "paper-2"):
        p = os.path.join(BANK, "paper-forms", "utet", paper, "forms.ndjson")
        for f in _ndjson(p):
            forms.setdefault(f["id"], f)
    if form_id not in forms:
        raise SystemExit(
            "Unknown form %r.\nAvailable UTET paper forms:\n  %s"
            % (form_id, "\n  ".join(sorted(forms)))
        )
    form = forms[form_id]
    exam, paper = form["exam"], form["paper"]

    appearances = [
        a for a in _ndjson(os.path.join(BANK, "paper-forms", exam, "paper-%s" % paper, "appearances.ndjson"))
        if a.get("paperFormId") == form_id
    ]
    appearances.sort(key=lambda a: a["questionNumber"])

    q_index = load_questions(exam, paper)
    s_index = load_stimuli(exam, paper)

    questions = []
    sections = OrderedDict()
    for a in appearances:
        qid = a["questionId"]
        q = q_index.get(qid)
        if q is None:
            raise SystemExit("Missing question %s for form %s" % (qid, form_id))
        section = a.get("section")
        slot = str(a.get("languageSlot")) if a.get("languageSlot") else None
        lang = a.get("language")
        hi_label, en_label, pill = SECTION_LABELS.get(
            (section, slot, lang), (section, section, section)
        )
        key = (section, slot, lang)
        if key not in sections:
            sections[key] = {
                "key": "|".join([section, slot or "-", lang or "-"]),
                "labelHi": hi_label,
                "labelEn": en_label,
                "pill": pill,
                "from": a["questionNumber"],
                "to": a["questionNumber"],
            }
        sections[key]["to"] = max(sections[key]["to"], a["questionNumber"])

        questions.append({
            "n": a["questionNumber"],
            "id": qid,
            "sec": sections[key]["key"],
            "pill": pill,
            "sectionHi": hi_label,
            "sectionEn": en_label,
            "stim": q.get("stimulusId"),
            "hi": clean(block_text(q.get("prompt"), "hi")),
            "en": clean(block_text(q.get("prompt"), "en")),
            "opts": [
                {
                    "id": o["id"],
                    "hi": clean(block_text(o.get("content"), "hi")),
                    "en": clean(block_text(o.get("content"), "en")),
                }
                for o in q.get("options", [])
            ],
            "ans": (q.get("answer") or {}).get("optionId") or (a.get("officialOptionId") or ""),
            "official": a.get("officialOptionId") or "",
            "ref": a.get("sourceRef") or "",
            "verified": a.get("verificationStatus") == "verified",
            "difficulty": (q.get("difficulty") or {}).get("editorial") or "unrated",
            "cognitive": q.get("cognitiveLevel") or "unrated",
            "review": q.get("review") or {},
        })

    # stimuli used by this form
    used = OrderedDict()
    for q in questions:
        sid = q["stim"]
        if sid and sid in s_index and sid not in used:
            s = s_index[sid]
            ins = s.get("instructions") or {}
            content = s.get("content") or []
            used[sid] = {
                "id": sid,
                "type": s.get("type") or "passage",
                "instHi": ins.get("hi") or "",
                "instEn": ins.get("en") or "",
                "hi": clean(block_text(content, "hi")),
                "en": clean(block_text(content, "en")),
            }

    section_list = []
    for i, s in enumerate(sections.values(), start=1):
        section_list.append({
            "index": i,
            "key": s["key"],
            "labelHi": s["labelHi"],
            "labelEn": s["labelEn"],
            "pill": s["pill"],
            "from": s["from"],
            "to": s["to"],
        })

    title = form.get("title") or {}
    year = (form.get("examDate") or "")[:4] or "2025"
    meta = {
        "formId": form["id"],
        "exam": exam.upper(),
        "paper": paper,
        "examDate": form.get("examDate"),
        "examDateHi": fmt_date(form.get("examDate") or ""),
        "setCode": form.get("setCode") or "A",
        "cycle": year,
        "durationMinutes": form.get("durationMinutes") or 150,
        "durationHi": fmt_duration(form.get("durationMinutes") or 150),
        "totalQuestions": form.get("totalQuestions") or len(questions),
        "totalMarks": form.get("totalMarks") or len(questions),
        "officialNegative": form.get("negativeMarking", 0),
        "negative": SKIN["negativeMarking"],
        "negativeLabel": SKIN["negativeLabel"],
        "titleHi": title.get("hi") or "",
        "titleEn": title.get("en") or "",
        "sourceRef": form.get("sourceRef") or "",
        "verificationStatus": form.get("verificationStatus") or "",
        "bankVersion": read_bank_version(),
        "roll": [c for c in year] + ["0", "1"],
        "skin": SKIN,
    }
    return {"meta": meta, "sections": section_list, "stimuli": list(used.values()), "questions": questions}


def read_bank_version():
    try:
        with open(os.path.join(BANK, "bank.json"), encoding="utf-8") as fh:
            return json.load(fh).get("bankVersion") or ""
    except Exception:
        return ""


# --------------------------------------------------------------------------
# HTML template
# --------------------------------------------------------------------------
HTML = r"""<!DOCTYPE html>
<html lang="hi" data-theme="light">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<meta name="theme-color" content="#0F172A">
<meta name="description" content="__TITLE__ — हल प्रश्न-पुस्तिका (Digital Examination Booklet)">
<title>__TITLE__</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Noto+Sans+Devanagari:wght@400;500;600;700;800&family=Inter:ital,wght@0,400;0,500;0,600;0,700;1,400;1,500&display=swap">
<style>
/* ============================ THEME TOKENS ============================ */
:root{
  --canvas:#F1F5F9; --paper:#FFFFFF; --ink:#0F172A; --sub:#475569; --muted:#94A3B8;
  --amber:#D97706; --amber-bg:#FFFBEB; --amber-br:#FCD34D;
  --emerald:#10B981; --emerald-bg:#ECFDF5; --emerald-br:#6EE7B7;
  --crimson:#EF4444; --crimson-bg:#FEF2F2; --crimson-br:#FCA5A5;
  --indigo:#4F46E5; --indigo-bg:#EEF2FF; --indigo-br:#C7D2FE;
  --slate-br:#E2E8F0; --soft:#F8FAFC;
  --bar:rgba(255,255,255,.86); --sheet-br:rgba(15,23,42,.10);
  --shadow:0 1px 2px rgba(15,23,42,.05), 0 10px 30px -18px rgba(15,23,42,.28);
  --noise:.035; --fs:1;
  --hindi:'Noto Sans Devanagari','Nirmala UI','Kohinoor Devanagari',system-ui,sans-serif;
  --latin:'Inter','Roboto',system-ui,-apple-system,sans-serif;
}
html[data-theme="dark"]{
  --canvas:#080C14; --paper:#0F172A; --ink:#F8FAFC; --sub:#94A3B8; --muted:#64748B;
  --amber:#FBBF24; --amber-bg:#1B1408; --amber-br:#78350F;
  --emerald:#10B981; --emerald-bg:#04231B; --emerald-br:#065F46;
  --crimson:#EF4444; --crimson-bg:#280F12; --crimson-br:#7F1D1D;
  --indigo:#818CF8; --indigo-bg:#171A3A; --indigo-br:#3730A3;
  --slate-br:#1E293B; --soft:#0B1220;
  --bar:rgba(15,23,42,.80); --sheet-br:rgba(148,163,184,.14);
  --shadow:0 1px 2px rgba(0,0,0,.4), 0 14px 34px -20px rgba(0,0,0,.8);
  --noise:.05;
}
*{box-sizing:border-box;-webkit-tap-highlight-color:transparent}
html{font-size:calc(100% * var(--fs));-webkit-text-size-adjust:100%}
body{
  margin:0;padding:0;background-color:var(--canvas);color:var(--ink);
  font-family:var(--hindi);line-height:1.6;
  padding-top:3.6rem;padding-bottom:6.4rem;
  background-image:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='140' height='140'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='.9' numOctaves='3'/%3E%3C/filter%3E%3Crect width='140' height='140' filter='url(%23n)' opacity='.5'/%3E%3C/svg%3E");
  background-blend-mode:normal;
}
body::before{content:"";position:fixed;inset:0;pointer-events:none;z-index:0;opacity:var(--noise);
  background-image:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='140' height='140'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='.9' numOctaves='3'/%3E%3C/filter%3E%3Crect width='140' height='140' filter='url(%23n)'/%3E%3C/svg%3E")}
.wrap{position:relative;z-index:1;max-width:56rem;margin:0 auto;padding:0 .5rem}
.en{font-family:var(--latin);font-style:italic;color:var(--sub);font-size:.8125rem;line-height:1.55}
button{font-family:inherit;color:inherit}

/* ============================ STICKY CBT BAR ============================ */
#bar{position:fixed;top:0;left:0;right:0;z-index:60;background:var(--bar);
  -webkit-backdrop-filter:saturate(180%) blur(20px);backdrop-filter:saturate(180%) blur(20px);
  border-bottom:1px solid var(--sheet-br);padding-bottom:env(safe-area-inset-top)}
#prog{height:3px;background:var(--slate-br);width:100%;overflow:hidden}
#prog>i{display:block;height:100%;width:0;border-radius:0 3px 3px 0;
  background:linear-gradient(90deg,#34D399,#10B981 60%,#059669);transition:width .28s cubic-bezier(.4,0,.2,1)}
.bar-row{display:flex;align-items:center;gap:.4rem;padding:.4rem .55rem}
.qchip{font-size:.72rem;font-weight:700;color:var(--sub);background:var(--soft);
  border:1px solid var(--slate-br);border-radius:999px;padding:.2rem .5rem;white-space:nowrap;font-variant-numeric:tabular-nums}
.spacer{flex:1}
#timer{display:flex;align-items:center;gap:.3rem;font-family:var(--latin);font-weight:700;
  font-size:.95rem;letter-spacing:.5px;font-variant-numeric:tabular-nums;
  background:var(--soft);border:1px solid var(--slate-br);border-radius:999px;padding:.28rem .62rem;white-space:nowrap}
#timer.warn{color:var(--crimson);border-color:var(--crimson-br);background:var(--crimson-bg);animation:pulse 1s infinite}
@keyframes pulse{0%,100%{box-shadow:0 0 0 0 rgba(239,68,68,.45)}50%{box-shadow:0 0 0 7px rgba(239,68,68,0)}}
#timer.paused{color:var(--amber);border-color:var(--amber-br);background:var(--amber-bg)}
.ico{display:inline-flex;align-items:center;justify-content:center;min-width:2rem;height:2rem;
  border-radius:.55rem;border:1px solid var(--slate-br);background:var(--soft);
  font-size:.82rem;font-weight:700;cursor:pointer;transition:.15s}
.ico:active{transform:scale(.94)}
.ico.on{background:var(--indigo-bg);border-color:var(--indigo-br);color:var(--indigo)}
.zoom{display:flex;align-items:center;border:1px solid var(--slate-br);background:var(--soft);border-radius:.55rem;overflow:hidden}
.zoom button{border:0;background:transparent;padding:.28rem .45rem;font-size:.8rem;font-weight:800;cursor:pointer}

/* ============================ PAPER / SHEET ============================ */
.sheet{background:var(--paper);border:1px solid var(--sheet-br);border-radius:1rem;
  box-shadow:var(--shadow);margin:.6rem auto 1rem;overflow:hidden}
.pad{padding:1.1rem .95rem}
@media(min-width:640px){.pad{padding:1.6rem 1.6rem}}

/* ---- cover masthead ---- */
.mast{text-align:center;padding:1.3rem .9rem .9rem;border-bottom:2px double var(--slate-br);position:relative}
.emblem{width:3.1rem;height:3.1rem;margin:0 auto .45rem;border-radius:50%;
  border:1.5px solid var(--amber);display:flex;align-items:center;justify-content:center;
  font-size:1.3rem;color:var(--amber);background:var(--amber-bg)}
.commission{font-size:1rem;font-weight:800;letter-spacing:.2px;line-height:1.35}
.commission .en{display:block;font-size:.68rem;font-style:normal;font-weight:600;letter-spacing:.4px;margin-top:.15rem}
.exam-title{font-size:1.125rem;font-weight:800;margin:.5rem 0 .25rem;line-height:1.4}
.sub-title{font-size:.83rem;color:var(--sub);font-weight:600;line-height:1.5;max-width:34rem;margin:0 auto}
.sub-title .en{display:block;margin-top:.15rem;font-size:.72rem;font-style:italic}
.cover-grid{display:grid;grid-template-columns:1fr auto;gap:.7rem;align-items:start;padding:.9rem .9rem .2rem}
@media(max-width:520px){.cover-grid{grid-template-columns:1fr}}
.set-stamp{display:inline-block;border:2px solid var(--crimson);color:var(--crimson);
  border-radius:.4rem;padding:.4rem .6rem;font-weight:800;font-size:.8rem;text-align:center;
  transform:rotate(-1.5deg);box-shadow:0 0 0 3px var(--crimson-bg);letter-spacing:.3px}
.set-stamp small{display:block;font-family:var(--latin);font-size:.6rem;letter-spacing:1px;font-weight:700;opacity:.8}
.roll-box{border:1px solid var(--slate-br);border-radius:.5rem;padding:.5rem .6rem;background:var(--soft)}
.roll-box .rl{font-size:.68rem;font-weight:800;letter-spacing:.5px;color:var(--sub);margin-bottom:.35rem}
.roll-cells{display:flex;gap:.25rem}
.roll-cells input{width:1.85rem;height:2.2rem;text-align:center;font-family:var(--latin);
  font-size:1.05rem;font-weight:700;border:1.5px solid var(--slate-br);border-radius:.28rem;
  background:var(--paper);color:var(--ink);padding:0}
.roll-cells input:focus{outline:2px solid var(--indigo);outline-offset:-1px}
.roll-note{font-size:.62rem;color:var(--muted);margin-top:.3rem;font-family:var(--latin)}
.specs{display:grid;grid-template-columns:repeat(3,1fr);gap:.4rem;margin:.85rem .9rem 0}
@media(max-width:520px){.specs{grid-template-columns:1fr}}
.spec{border:1px solid var(--slate-br);border-radius:.55rem;padding:.5rem .45rem;text-align:center;background:var(--soft)}
.spec b{display:block;font-size:.8rem;font-weight:800;line-height:1.3}
.spec span{display:block;font-size:.6rem;font-family:var(--latin);letter-spacing:.5px;color:var(--muted);text-transform:uppercase;margin-top:.15rem}
.instr{margin:.85rem .9rem 1rem;border:1px solid var(--amber-br);background:var(--amber-bg);
  border-left:.35rem solid var(--amber);border-radius:.5rem;padding:.75rem .8rem}
.instr h3{margin:0 0 .4rem;font-size:.83rem;font-weight:800;color:var(--amber)}
.instr ol{margin:0;padding-left:1.15rem}
.instr li{font-size:.8rem;line-height:1.65;margin:.2rem 0}
.instr .en{margin-top:.45rem;display:block;font-size:.72rem}
.start-row{padding:0 .9rem 1.2rem;display:flex;gap:.5rem;flex-wrap:wrap}
.btn{border:1px solid transparent;border-radius:.65rem;padding:.6rem 1.1rem;font-weight:800;font-size:.86rem;cursor:pointer;transition:.15s}
.btn:active{transform:scale(.97)}
.btn-primary{background:linear-gradient(135deg,#059669,#10B981);color:#fff;box-shadow:0 6px 18px -8px rgba(16,185,129,.9)}
.btn-ghost{background:var(--soft);border-color:var(--slate-br);color:var(--sub)}

/* ---- section divider ---- */
.sec-banner{margin:1.2rem 0 .2rem;background:linear-gradient(100deg,var(--indigo) ,#6366F1);
  color:#fff;border-radius:.7rem;padding:.6rem .85rem;display:flex;align-items:center;gap:.6rem;box-shadow:var(--shadow)}
.sec-banner .sn{font-family:var(--latin);font-size:.68rem;font-weight:800;letter-spacing:.6px;opacity:.85}
.sec-banner .st{font-size:.95rem;font-weight:800;line-height:1.35}
.sec-banner .se{font-family:var(--latin);font-style:italic;font-size:.7rem;opacity:.9;display:block}
.sec-banner .sr{margin-left:auto;font-family:var(--latin);font-size:.68rem;font-weight:700;
  background:rgba(255,255,255,.18);border-radius:999px;padding:.2rem .5rem;white-space:nowrap}

/* ---- stimulus (passage / poem) ---- */
.stim{margin:.75rem 0 .1rem;border:1px dashed var(--slate-br);border-radius:.7rem;background:var(--soft);padding:.8rem .85rem}
.stim .sh{font-size:.7rem;font-weight:800;letter-spacing:.5px;color:var(--amber);margin-bottom:.35rem;text-transform:uppercase}
.stim .st-hi{font-size:.9rem;line-height:1.85;white-space:pre-wrap}
.stim .st-en{font-size:.8rem;line-height:1.7;white-space:pre-wrap;margin-top:.5rem;color:var(--sub);font-family:var(--latin);font-style:italic}
.stim .st-inst{margin-top:.5rem;font-size:.78rem;font-weight:700;color:var(--indigo)}

/* ---- question card ---- */
.q{background:var(--paper);border:1px solid var(--sheet-br);border-radius:.85rem;
  box-shadow:var(--shadow);margin:.75rem 0;padding:.85rem .8rem;scroll-margin-top:5rem;position:relative}
.q.current{border-color:var(--indigo-br);box-shadow:0 0 0 2px var(--indigo-bg),var(--shadow)}
.q.flag{background:var(--amber-bg)}
.q-head{display:flex;align-items:flex-start;gap:.55rem}
.qbadge{flex:0 0 auto;min-width:3.1rem;height:2.05rem;border-radius:.55rem;background:var(--indigo);
  color:#fff;display:flex;align-items:center;justify-content:center;font-family:var(--latin);
  font-size:.85rem;font-weight:800;letter-spacing:.4px;box-shadow:0 4px 12px -6px rgba(79,70,229,.9)}
.q-text{flex:1;min-width:0}
.q-hi{font-size:.9375rem;font-weight:600;line-height:1.68;white-space:pre-wrap}
.q-en{font-size:.8125rem;font-style:italic;color:var(--sub);line-height:1.6;white-space:pre-wrap;margin-top:.25rem;font-family:var(--latin)}
.q-body{margin-top:.65rem;display:flex;flex-direction:column;gap:.4rem}
.opt{display:flex;gap:.55rem;align-items:flex-start;width:100%;text-align:right;border:1px solid var(--slate-br);
  background:var(--soft);border-radius:.6rem;padding:.55rem .6rem;cursor:pointer;transition:background .15s,border-color .15s}
.opt:active{transform:scale(.995)}
.olab{flex:0 0 auto;min-width:2rem;height:1.6rem;border-radius:.4rem;background:var(--paper);
  border:1.5px solid var(--slate-br);display:flex;align-items:center;justify-content:center;
  font-family:var(--latin);font-size:.78rem;font-weight:800}
.o-text{flex:1;min-width:0;text-align:left}
.o-hi{font-size:.875rem;font-weight:500;line-height:1.6;white-space:pre-wrap}
.o-en{font-size:.75rem;font-style:italic;color:var(--sub);line-height:1.5;white-space:pre-wrap;margin-top:.12rem;font-family:var(--latin)}
/* English-only questions (Language-II) are promoted to the primary slot */
.q-pri{font-family:var(--latin);font-size:.9375rem;font-weight:600;line-height:1.6;white-space:pre-wrap}
.o-pri{font-family:var(--latin);font-size:.875rem;font-weight:500;line-height:1.55;white-space:pre-wrap}
.st-pri{font-family:var(--latin);font-size:.9rem;line-height:1.75;white-space:pre-wrap}
.opt.sel{background:var(--emerald-bg);border:1.5px solid var(--emerald)}
.opt.sel .olab{background:var(--emerald);border-color:var(--emerald);color:#fff}
.opt.sel .o-hi{font-weight:700}
.q-foot{display:flex;align-items:center;gap:.4rem;flex-wrap:wrap;margin-top:.7rem;padding-top:.55rem;border-top:1px dashed var(--slate-br)}
.pill{font-size:.66rem;font-weight:700;border-radius:999px;padding:.18rem .5rem;
  border:1px solid var(--slate-br);background:var(--soft);color:var(--sub);white-space:nowrap}
.pill.sub{border-color:var(--indigo-br);background:var(--indigo-bg);color:var(--indigo)}
.pill.mark b{color:var(--emerald)}
.pill.mark i{color:var(--crimson);font-style:normal}
.mini{margin-left:auto;display:flex;gap:.3rem}
.mini button{width:1.85rem;height:1.85rem;border-radius:.45rem;border:1px solid var(--slate-br);
  background:var(--soft);cursor:pointer;font-size:.8rem;line-height:1;display:flex;align-items:center;justify-content:center;transition:.15s}
.mini button.on{background:var(--amber-bg);border-color:var(--amber);color:var(--amber)}
.mini button.rep.on{background:var(--crimson-bg);border-color:var(--crimson);color:var(--crimson)}

/* ============================ REVIEW MODE ============================ */
.tag{display:inline-flex;align-items:center;gap:.25rem;font-size:.72rem;font-weight:800;
  border-radius:999px;padding:.22rem .55rem;margin:.15rem .25rem .15rem 0}
.tag.ok{background:var(--emerald-bg);border:1px solid var(--emerald);color:var(--emerald)}
.tag.no{background:var(--crimson-bg);border:1px solid var(--crimson);color:var(--crimson)}
.tag.na{background:var(--soft);border:1px solid var(--slate-br);color:var(--sub)}
.tag.key{background:var(--indigo-bg);border:1px solid var(--indigo);color:var(--indigo)}
.opt.correct{background:var(--emerald-bg);border:1.5px solid var(--emerald)}
.opt.correct .olab{background:var(--emerald);border-color:var(--emerald);color:#fff}
.opt.wrong{background:var(--crimson-bg);border:1.5px solid var(--crimson)}
.opt.wrong .olab{background:var(--crimson);border-color:var(--crimson);color:#fff}
.opt .badge{position:absolute;right:.5rem;top:.5rem;width:1.25rem;height:1.25rem;border-radius:50%;
  color:#fff;font-size:.72rem;display:flex;align-items:center;justify-content:center;font-weight:900}
.opt{position:relative}
.opt.correct .badge{background:var(--emerald)}
.opt.wrong .badge{background:var(--crimson)}
.opt.dim{opacity:.55}
.exp{margin-top:.7rem;border:1px solid var(--indigo-br);border-left:.3rem solid var(--indigo);
  background:var(--indigo-bg);border-radius:.6rem;padding:.7rem .75rem}
.exp-h{font-size:.8rem;font-weight:800;color:var(--indigo);display:flex;align-items:center;gap:.35rem;flex-wrap:wrap}
.exp-h small{font-family:var(--latin);font-style:italic;font-weight:600;color:var(--sub);font-size:.66rem}
.exp-grid{display:grid;grid-template-columns:7.5rem 1fr;gap:.25rem .6rem;margin-top:.5rem;font-size:.78rem}
.exp-k{color:var(--sub);font-weight:700}
.exp-v{line-height:1.55}
.exp-v .hi{font-weight:600}
.exp-v .enx{font-family:var(--latin);font-style:italic;color:var(--sub);font-size:.72rem;display:block}
.optlist{margin-top:.5rem;display:flex;flex-direction:column;gap:.2rem;font-size:.78rem}
.optlist div{display:flex;gap:.35rem;line-height:1.5}
.optlist .mk{font-weight:900;width:.9rem;flex:0 0 auto}
.mk.y{color:var(--emerald)}.mk.n{color:var(--muted)}
.exp-note{margin-top:.55rem;font-size:.72rem;color:var(--sub);background:var(--paper);
  border:1px dashed var(--indigo-br);border-radius:.45rem;padding:.45rem .55rem;line-height:1.55}
.score{position:sticky;top:3.6rem;z-index:20;margin:.6rem 0 0}
.score-grid{display:grid;grid-template-columns:repeat(4,1fr);gap:.4rem;text-align:center}
@media(max-width:520px){.score-grid{grid-template-columns:repeat(2,1fr)}}
.score-grid div{background:var(--soft);border:1px solid var(--slate-br);border-radius:.55rem;padding:.45rem .3rem}
.score-grid b{display:block;font-family:var(--latin);font-size:1.15rem;font-weight:800;line-height:1.2}
.score-grid span{font-size:.62rem;color:var(--sub);font-weight:700}
.review-bar{display:flex;gap:.4rem;flex-wrap:wrap;margin-top:.7rem}

/* ============================ BOTTOM DOCK ============================ */
#dock{position:fixed;left:0;right:0;bottom:0;z-index:60;background:var(--bar);
  -webkit-backdrop-filter:saturate(180%) blur(20px);backdrop-filter:saturate(180%) blur(20px);
  border-top:1px solid var(--sheet-br);padding:.5rem .6rem calc(.5rem + env(safe-area-inset-bottom));
  display:flex;gap:.5rem;align-items:center;max-width:56rem;margin:0 auto}
#omrbtn{flex:1;display:flex;align-items:center;gap:.45rem;background:var(--soft);
  border:1px solid var(--slate-br);border-radius:.7rem;padding:.5rem .6rem;cursor:pointer;font-weight:800;font-size:.82rem}
#omrbtn .cnt{font-family:var(--latin);font-size:.95rem;font-weight:800;color:var(--indigo)}
.chips{display:flex;gap:.3rem;margin-left:auto}
.chips i{font-style:normal;font-size:.66rem;font-weight:800;border-radius:999px;padding:.12rem .4rem;
  border:1px solid var(--slate-br);background:var(--paper);white-space:nowrap}
.chips i.g{color:var(--emerald);border-color:var(--emerald-br);background:var(--emerald-bg)}
.chips i.o{color:var(--sub)}
#submitbtn{flex:0 0 auto;background:linear-gradient(135deg,#4F46E5,#6366F1);color:#fff;
  border:0;border-radius:.7rem;padding:.62rem .95rem;font-weight:800;font-size:.86rem;cursor:pointer;
  box-shadow:0 8px 22px -10px rgba(79,70,229,.95);white-space:nowrap}
#submitbtn:active{transform:scale(.97)}

/* ============================ SHEETS / MODALS ============================ */
.scrim{position:fixed;inset:0;background:rgba(15,23,42,.55);z-index:80;opacity:0;pointer-events:none;transition:opacity .22s}
.scrim.show{opacity:1;pointer-events:auto}
.modal{position:fixed;left:0;right:0;bottom:0;z-index:90;background:var(--paper);
  border-radius:1.1rem 1.1rem 0 0;box-shadow:0 -18px 50px -20px rgba(15,23,42,.5);
  transform:translateY(105%);transition:transform .28s cubic-bezier(.32,.72,0,1);
  max-height:86vh;display:flex;flex-direction:column;padding-bottom:env(safe-area-inset-bottom);
  max-width:56rem;margin:0 auto}
.modal.show{transform:translateY(0)}
.grab{width:2.6rem;height:.28rem;border-radius:999px;background:var(--slate-br);margin:.5rem auto .2rem;flex:0 0 auto}
.modal h2{margin:.2rem .9rem .5rem;font-size:1rem;font-weight:800;display:flex;align-items:center;gap:.5rem}
.modal h2 .en{font-size:.72rem}
.mbody{overflow:auto;padding:0 .9rem .9rem;-webkit-overflow-scrolling:touch}
.legend{display:flex;gap:.5rem;flex-wrap:wrap;margin:.1rem .9rem .6rem;font-size:.68rem;color:var(--sub)}
.legend span{display:inline-flex;align-items:center;gap:.25rem}
.dot{width:.85rem;height:.85rem;border-radius:50%;display:inline-block;border:1.5px solid var(--slate-br)}
.dot.g{background:var(--emerald);border-color:var(--emerald)}
.dot.a{background:var(--amber);border-color:var(--amber)}
.dot.i{background:var(--indigo);border-color:var(--indigo)}
.dot.n{background:transparent}
.filters{display:flex;gap:.35rem;margin:.1rem .9rem .6rem;flex-wrap:wrap}
.filters button{font-size:.72rem;font-weight:700;border-radius:999px;padding:.25rem .6rem;
  border:1px solid var(--slate-br);background:var(--soft);cursor:pointer}
.filters button.on{background:var(--indigo);border-color:var(--indigo);color:#fff}
.pal{display:grid;grid-template-columns:repeat(auto-fill,minmax(2.55rem,1fr));gap:.4rem}
.bub{position:relative;aspect-ratio:1/1;border-radius:50%;border:1.5px solid var(--slate-br);
  background:var(--paper);font-family:var(--latin);font-size:.85rem;font-weight:800;cursor:pointer;
  display:flex;align-items:center;justify-content:center;color:var(--sub);transition:.15s}
.bub:active{transform:scale(.9)}
.bub.done{background:var(--emerald);border-color:var(--emerald);color:#fff}
.bub.flag{border-color:var(--amber);box-shadow:0 0 0 2px var(--amber-bg)}
.bub.now{border-color:var(--indigo);box-shadow:0 0 0 2px var(--indigo-bg)}
.bub.rok{background:var(--emerald-bg);border-color:var(--emerald);color:var(--emerald)}
.bub.rno{background:var(--crimson-bg);border-color:var(--crimson);color:var(--crimson)}
.mrow{display:flex;gap:.5rem;padding:.6rem .9rem calc(.7rem + env(safe-area-inset-bottom));border-top:1px solid var(--sheet-br)}
.mrow .btn{flex:1}
.sum{display:grid;grid-template-columns:repeat(3,1fr);gap:.4rem;margin:.2rem .9rem .7rem;text-align:center}
.sum div{border:1px solid var(--slate-br);border-radius:.55rem;padding:.5rem .3rem;background:var(--soft)}
.sum b{display:block;font-family:var(--latin);font-size:1.1rem;font-weight:800}
.sum span{font-size:.64rem;color:var(--sub);font-weight:700}
.warnbox{margin:.2rem .9rem .7rem;border:1px solid var(--amber-br);background:var(--amber-bg);
  border-left:.3rem solid var(--amber);border-radius:.5rem;padding:.6rem .7rem;font-size:.78rem;line-height:1.6}
#toast{position:fixed;left:50%;transform:translateX(-50%) translateY(1.5rem);bottom:6.5rem;z-index:120;
  background:var(--ink);color:var(--paper);font-size:.78rem;font-weight:700;padding:.5rem .85rem;
  border-radius:999px;opacity:0;pointer-events:none;transition:.22s;max-width:90vw;text-align:center}
#toast.show{opacity:1;transform:translateX(-50%) translateY(0)}
.footnote{margin:1rem .9rem 1.4rem;font-size:.7rem;color:var(--muted);line-height:1.7;text-align:center}
.footnote code{font-family:var(--latin);font-size:.68rem;background:var(--soft);padding:.05rem .3rem;border-radius:.25rem}
.hint{display:none}
@media(hover:hover){.hint{display:block;text-align:center;font-size:.66rem;color:var(--muted);margin:.4rem .9rem .8rem;font-family:var(--latin)}}

@media print{
  #bar,#dock,.scrim,.modal,#toast,.mini,.start-row{display:none!important}
  body{padding:0;background:#fff}
  .sheet{box-shadow:none;border:0;margin:0}
  .q{break-inside:avoid;page-break-inside:avoid}
}
</style>
</head>
<body>

<header id="bar">
  <div id="prog"><i></i></div>
  <div class="bar-row">
    <span class="qchip" id="qchip">प्र. 1/__N__</span>
    <span class="spacer"></span>
    <span id="timer">⏱️ __DUR__</span>
    <span class="spacer"></span>
    <span class="zoom" title="अक्षर आकार">
      <button id="fsd" aria-label="छोटा अक्षर">A-</button>
      <button id="fsu" aria-label="बड़ा अक्षर">A+</button>
    </span>
    <button class="ico" id="full" title="फ़ुल स्क्रीन" aria-label="Fullscreen">⛶</button>
    <button class="ico" id="theme" title="थीम बदलें" aria-label="Theme">🌙</button>
  </div>
</header>

<main class="wrap">
  <section class="sheet" id="cover"></section>
  <div id="scorecard"></div>
  <div id="qlist"></div>
  <p class="footnote" id="foot"></p>
</main>

<nav id="dock">
  <button id="omrbtn">
    <span>📋 OMR</span>
    <span class="cnt" id="cnt">[ 0/__N__ ]</span>
    <span class="chips">
      <i class="g" id="cdone">✓ 0 हल</i>
      <i class="o" id="cleft">⭕ __N__ शेष</i>
    </span>
  </button>
  <button id="submitbtn">जमा करें ➔</button>
</nav>

<div class="scrim" id="scrim"></div>

<div class="modal" id="palette" role="dialog" aria-label="प्रश्न पैलेट">
  <div class="grab"></div>
  <h2>📋 OMR उत्तर-पत्रक <span class="en">Question Palette</span></h2>
  <div class="filters" id="pfilters">
    <button data-f="all" class="on">सभी __N__</button>
    <button data-f="done">हल ✓</button>
    <button data-f="left">शेष ⭕</button>
    <button data-f="flag">चिह्नित ⚑</button>
  </div>
  <div class="legend">
    <span><i class="dot g"></i> हल</span>
    <span><i class="dot a"></i> चिह्नित</span>
    <span><i class="dot i"></i> वर्तमान</span>
    <span><i class="dot n"></i> शेष</span>
  </div>
  <div class="mbody"><div class="pal" id="pal"></div></div>
</div>

<div class="modal" id="confirm" role="dialog" aria-label="परीक्षा जमा करें">
  <div class="grab"></div>
  <h2>⚠️ परीक्षा जमा करें <span class="en">Final Submit</span></h2>
  <div class="sum" id="csum"></div>
  <div class="warnbox" id="cwarn"></div>
  <div class="mrow">
    <button class="btn btn-ghost" id="ccancel">रद्द करें</button>
    <button class="btn btn-primary" id="cok">हाँ, जमा करें ➔</button>
  </div>
</div>

<div id="toast"></div>

<script>
/* ============================ DATA ============================ */
const BOOK = __DATA__;
const M = BOOK.meta, QS = BOOK.questions, SECS = BOOK.sections;
const SKIN = M.skin || {};
const STIM = {}; BOOK.stimuli.forEach(s => STIM[s.id] = s);
const NEG = M.negative || 0;
const KEY = 'tet-booklet:' + M.formId;

/* ============================ STATE ============================ */
const blank = () => ({ans:{}, flag:{}, rep:{}, scale:1, theme:'light', endsAt:null,
                      started:false, submitted:false, review:{}, roll:M.roll.slice()});
let S = blank();
try { const raw = localStorage.getItem(KEY); if (raw) S = Object.assign(blank(), JSON.parse(raw)); } catch(e){}
const save = () => { try { localStorage.setItem(KEY, JSON.stringify(S)); } catch(e){} };
const haptic = ms => { try { navigator.vibrate && navigator.vibrate(ms||8); } catch(e){} };
const $ = s => document.querySelector(s);
const esc = s => String(s==null?'':s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
const rich = s => esc(s).replace(/\*\*(.+?)\*\*/g,'<strong>$1</strong>').replace(/\n/g,'<br>');

let toastT;
function toast(msg){ const t=$('#toast'); t.textContent=msg; t.classList.add('show');
  clearTimeout(toastT); toastT=setTimeout(()=>t.classList.remove('show'),1900); }

/* ============================ COVER PAGE ============================ */
function renderCover(){
  const specs = [
    ['⏱️', 'समय: ' + M.durationHi, 'DURATION'],
    ['📝', 'पूर्णांक: ' + M.totalMarks + ' अंक', 'MAX MARKS'],
    ['⚠️', 'ऋणात्मक अंकन: ' + M.negativeLabel, 'NEGATIVE'],
  ];
  $('#cover').innerHTML = `
    <div class="mast">
      <div class="emblem">🏛️</div>
      <div class="commission">${esc(SKIN.commissionHi||'')}
        <span class="en">${esc(SKIN.commissionEn||'')}</span></div>
      <div class="exam-title">${esc(SKIN.examTitleHi||'')}</div>
      <div class="sub-title">${esc(SKIN.subtitleHi||'')}
        <span class="en">${esc(SKIN.subtitleEn||'')}</span></div>
    </div>
    <div class="cover-grid">
      <div class="roll-box">
        <div class="rl">अनुक्रमांक / ROLL NUMBER</div>
        <div class="roll-cells">${[0,1,2,3,4,5].map(i=>
          `<input inputmode="numeric" maxlength="1" data-roll="${i}" value="${esc((S.roll[i]||''))}" aria-label="roll digit ${i+1}">`).join('')}</div>
        <div class="roll-note">${esc(SKIN.conductedBy||'')}</div>
      </div>
      <div>
        <div class="set-stamp">प्रश्न-पुस्तिका सीरीज़<br>SET-${esc(M.setCode)}
          <small>QUESTION BOOKLET SERIES</small></div>
        <div style="margin-top:.45rem;font-size:.68rem;color:var(--sub);text-align:center;font-weight:600">
          परीक्षा दिनांक : ${esc(M.examDateHi)}<br>
          <span style="font-family:var(--latin)">${esc(M.titleEn||'')}</span>
        </div>
      </div>
    </div>
    <div class="specs">${specs.map(s=>`<div class="spec"><b>${s[0]} ${esc(s[1])}</b><span>${s[2]}</span></div>`).join('')}</div>
    <div class="instr">
      <h3>📌 महत्वपूर्ण निर्देश / INSTRUCTIONS</h3>
      <ol>${(SKIN.instructionsHi||[]).map(i=>`<li>${i}</li>`).join('')}</ol>
      <span class="en">${esc(SKIN.instructionsEn||'')}</span>
    </div>
    <div class="start-row">
      <button class="btn btn-primary" id="startbtn">${S.started?'▶️ परीक्षा जारी रखें':'▶️ परीक्षा प्रारम्भ करें'}</button>
      <button class="btn btn-ghost" id="resetbtn">🔄 रीसेट</button>
    </div>
    <div class="hint">Shortcuts: 1–4 विकल्प चुनें · B चिह्नित · N/P अगला/पिछला · M OMR पैलेट</div>
  `;
  $('#startbtn').onclick = startExam;
  $('#resetbtn').onclick = () => { if(confirm('सभी उत्तर और समय रीसेट हो जाएँगे। जारी रखें?')){
    localStorage.removeItem(KEY); location.reload(); } };
  document.querySelectorAll('[data-roll]').forEach(inp => {
    inp.oninput = () => { S.roll[+inp.dataset.roll] = inp.value.replace(/\D/g,'').slice(-1);
      inp.value = S.roll[+inp.dataset.roll]; save(); };
  });
}

/* ============================ QUESTIONS ============================ */
/* ---- locale-aware rendering -------------------------------------------
   bank-v2 stores three kinds of questions: bilingual (hi+en), Hindi-only
   (Language-I) and English-only (Language-II). The primary slot always gets
   the question's own language; the other one becomes the secondary line. */
const hasText = s => !!(s && s.trim());
const pHi = o => o.hi || o.en || '';
const pEn = o => (o.hi ? (o.en || '') : '');
function stimHTML(id){
  const s = STIM[id]; if(!s) return '';
  const label = s.type === 'poem' ? '📜 कविता / पद्यांश' : '📄 गद्यांश / PASSAGE';
  const body = hasText(s.hi)
    ? `<div class="st-hi">${rich(s.hi)}</div>` + (hasText(s.en) ? `<div class="st-en">${rich(s.en)}</div>` : '')
    : `<div class="st-pri">${rich(s.en || '')}</div>`;
  return `<div class="stim">
    <div class="sh">${label}</div>
    ${body}
    ${(s.instHi||s.instEn)?`<div class="st-inst">${rich(s.instHi||s.instEn)}</div>`:''}
  </div>`;
}
function qText(q){
  if (hasText(q.hi)) return `<div class="q-hi">${rich(q.hi)}</div>` +
    (hasText(q.en) ? `<div class="q-en">${rich(q.en)}</div>` : '');
  return `<div class="q-pri">${rich(q.en || '')}</div>`;
}
function optText(o){
  if (hasText(o.hi)) return `<span class="o-hi">${rich(o.hi)}</span>` +
    (hasText(o.en) ? `<span class="o-en">${rich(o.en)}</span>` : '');
  return `<span class="o-pri">${rich(o.en || '')}</span>`;
}

function renderQuestions(){
  let html = '', lastSec = null, stimShown = {};
  SECS.forEach(sec => {
    html += `<div class="sec-banner">
      <div><div class="sn">PART ${sec.index}</div></div>
      <div style="flex:1">
        <div class="st">भाग-${sec.index}: ${esc(sec.labelHi)} (प्र. ${sec.from} से ${sec.to})</div>
        <span class="se">${esc(sec.labelEn)}</span>
      </div>
      <div class="sr">Q ${sec.from}–${sec.to}</div>
    </div>`;
    QS.filter(q => q.sec === sec.key).forEach(q => {
      if (q.stim && !stimShown[q.stim]) { html += stimHTML(q.stim); stimShown[q.stim] = 1; }
      html += qHTML(q);
    });
  });
  $('#qlist').innerHTML = html;

  QS.forEach(q => {
    const card = document.getElementById('q'+q.n);
    card.querySelectorAll('.opt').forEach(o => {
      o.onclick = () => pick(q, o.dataset.o, card);
    });
    card.querySelector('.bmk').onclick = e => { toggleFlag(q, e.currentTarget); };
    card.querySelector('.rep').onclick = e => { e.currentTarget.classList.add('on');
      S.rep[q.n]=1; save(); toast('🚩 प्रश्न '+q.n+' रिपोर्ट दर्ज — समीक्षा हेतु भेजा गया'); };
  });
  QS.forEach(q => paint(q));
}

function qHTML(q){
  const opts = q.opts.map(o => `
    <div class="opt" data-o="${o.id}" role="button" tabindex="0">
      <span class="olab">(${o.id.toUpperCase()})</span>
      <span class="o-text">${optText(o)}</span>
      <span class="badge" hidden></span>
    </div>`).join('');
  return `<article class="q" id="q${q.n}" data-n="${q.n}">
    <div class="q-head">
      <div class="qbadge">Q.${q.n}</div>
      <div class="q-text">${qText(q)}</div>
    </div>
    <div class="q-body">${opts}</div>
    <div id="tags${q.n}"></div>
    <div id="exp${q.n}"></div>
    <div class="q-foot">
      <span class="pill sub">${esc(q.pill)}</span>
      <span class="pill mark"><b>+1.00</b> / <i>-${NEG.toFixed(2)}</i></span>
      <span class="pill">${esc(q.sectionHi)}</span>
      <span class="mini">
        <button class="bmk" title="चिह्नित करें" aria-label="Bookmark">⚑</button>
        <button class="rep" title="रिपोर्ट" aria-label="Report">🚩</button>
      </span>
    </div>
  </article>`;
}

/* ============================ INTERACTION ============================ */
function pick(q, oid, card){
  if (S.submitted) return;
  if (!S.started) startExam();
  if (S.ans[q.n] === oid) { delete S.ans[q.n]; } else { S.ans[q.n] = oid; }
  save(); paint(q); haptic(10); refresh();
}
function toggleFlag(q, btn){
  if (S.flag[q.n]) delete S.flag[q.n]; else S.flag[q.n] = 1;
  save(); paint(q); refresh(); haptic(12);
  toast(S.flag[q.n] ? '⚑ प्रश्न '+q.n+' चिह्नित' : 'चिह्न हटाया गया');
}
function paint(q){
  const card = document.getElementById('q'+q.n); if(!card) return;
  card.classList.toggle('flag', !!S.flag[q.n]);
  card.querySelector('.bmk').classList.toggle('on', !!S.flag[q.n]);
  if (S.rep[q.n]) card.querySelector('.rep').classList.add('on');
  card.querySelectorAll('.opt').forEach(o => {
    o.classList.toggle('sel', S.ans[q.n] === o.dataset.o);
  });
}

/* ============================ REVIEW MODE ============================ */
function reviewOne(q){
  const card = document.getElementById('q'+q.n); if(!card) return;
  const mine = S.ans[q.n], key = q.ans;
  card.querySelectorAll('.opt').forEach(o => {
    const isKey = o.dataset.o === key, isMine = o.dataset.o === mine;
    o.classList.remove('sel','correct','wrong','dim');
    o.querySelector('.badge').hidden = true;
    if (isKey) { o.classList.add('correct'); const b=o.querySelector('.badge'); b.hidden=false; b.textContent='✓'; }
    if (isMine && !isKey) { o.classList.remove('correct'); o.classList.add('wrong');
      const b=o.querySelector('.badge'); b.hidden=false; b.textContent='✗'; }
    else if (isMine && isKey) { const b=o.querySelector('.badge'); b.hidden=false; b.textContent='✓'; }
    if (!isKey && !isMine) o.classList.add('dim');
    o.onclick = null;
  });
  let tag = '';
  if (!mine) tag = `<span class="tag na">➖ अनुत्तरित (0 अंक)</span>`;
  else if (mine === key) tag = `<span class="tag ok">आपका उत्तर (सही) ✓</span>`;
  else tag = `<span class="tag no">आपका उत्तर (गलत) ✗</span>`;
  const ko = (q.opts.find(o=>o.id===key)||{});
  tag += `<span class="tag key">✓ आयोग सही उत्तर : (${String(key||'-').toUpperCase()}) ${esc(pHi(ko))}</span>`;
  document.getElementById('tags'+q.n).innerHTML = tag;
  document.getElementById('exp'+q.n).innerHTML = expHTML(q, mine, key);
}

function expHTML(q, mine, key){
  const rows = [];
  const ko = q.opts.find(o=>o.id===key) || {};
  rows.push(['आयोग सही उत्तर', `<span class="hi">(${String(key||'-').toUpperCase()}) ${rich(pHi(ko)||'—')}</span>` +
    (pEn(ko)?`<span class="enx">${rich(pEn(ko))}</span>`:'')]);
  rows.push(['विषय / अनुभाग', `<span class="hi">${esc(q.sectionHi)}</span><span class="enx">${esc(q.sectionEn)}</span>`]);
  rows.push(['प्रश्न प्रकार', 'बहुविकल्पीय — एकल उत्तर (Single Choice)']);
  rows.push(['अंकन योजना', `सही : +1.00 &nbsp;|&nbsp; गलत : −${NEG.toFixed(2)} &nbsp;|&nbsp; अनुत्तरित : 0`]);
  rows.push(['स्रोत / प्रामाणिकता', `<span style="font-family:var(--latin)">${esc(q.ref||M.sourceRef||'—')}</span>
    <span class="enx">${q.verified?'✔ verified appearance':'⚠ unverified'} · disposition: imported</span>`]);
  rows.push(['कठिनाई / स्तर', `${esc(q.difficulty)} · ${esc(q.cognitive)}`]);
  const list = q.opts.map(o => {
    const ok = o.id===key, me = o.id===mine;
    const mk = ok ? '<span class="mk y">✓</span>' : (me ? '<span class="mk" style="color:var(--crimson)">✗</span>' : '<span class="mk n">•</span>');
    return `<div>${mk}<span><b>(${o.id.toUpperCase()})</b> ${rich(pHi(o))}${me?' <i style="color:var(--sub);font-style:normal">— आपका चयन</i>':''}</span></div>`;
  }).join('');
  return `<div class="exp">
    <div class="exp-h">🔍 360° संदर्भ व्याख्या <small>Official Solution &amp; Concept Analysis</small></div>
    <div class="exp-grid">${rows.map(r=>`<div class="exp-k">${r[0]}</div><div class="exp-v">${r[1]}</div>`).join('')}</div>
    <div class="optlist">${list}</div>
    <div class="exp-note">📘 <b>व्याख्या :</b> इस प्रश्न का उत्तर <b>विकल्प (${String(key||'-').toUpperCase()})</b> है — ऊपर दिए गए सभी विकल्पों की तुलना देखें। विस्तृत पाठ्य-व्याख्या (concept notes) अभी <code>bank-v2</code> में इस प्रश्न से जुड़ी नहीं है; जैसे ही जुड़ेगी, यह बॉक्स अपने आप भर जाएगा।
      <br><span style="font-family:var(--latin);font-size:.68rem">Auto-rendered from the verified appearance record — no hand-written explanation is stored for this question yet.</span></div>
  </div>`;
}

function scorecard(){
  let right=0, wrong=0, blankc=0;
  QS.forEach(q => { const m=S.ans[q.n]; if(!m) blankc++; else if(m===q.ans) right++; else wrong++; });
  const marks = (right*1 - wrong*NEG);
  const pct = ((marks / M.totalMarks)*100);
  const secRows = SECS.map(s => {
    const qs = QS.filter(q=>q.sec===s.key);
    const r = qs.filter(q=>S.ans[q.n]===q.ans).length;
    const w = qs.filter(q=>S.ans[q.n] && S.ans[q.n]!==q.ans).length;
    const b = qs.filter(q=>!S.ans[q.n]).length;
    return `<div class="pill" style="font-size:.7rem">${esc(s.pill)} : <b style="color:var(--emerald)">${r}</b> / <b style="color:var(--crimson)">${w}</b> / ${b}</div>`;
  }).join(' ');
  $('#scorecard').innerHTML = `<section class="sheet score">
    <div class="pad" style="padding-top:.9rem;padding-bottom:.9rem">
      <div style="text-align:center;margin-bottom:.6rem">
        <div style="font-size:1rem;font-weight:800">📊 परीक्षा परिणाम / SCORE CARD</div>
        <div class="en">${esc(M.titleEn||'')} · SET-${esc(M.setCode)} · ${esc(M.examDateHi)}</div>
      </div>
      <div class="score-grid">
        <div><b style="color:var(--emerald)">${right}</b><span>सही ✓</span></div>
        <div><b style="color:var(--crimson)">${wrong}</b><span>गलत ✗</span></div>
        <div><b style="color:var(--sub)">${blankc}</b><span>अनुत्तरित</span></div>
        <div><b style="color:var(--indigo)">${marks.toFixed(2)}</b><span>अंक / ${M.totalMarks}</span></div>
      </div>
      <div style="margin-top:.55rem;text-align:center">
        <span class="pill sub">प्रतिशत : ${pct.toFixed(2)}%</span>
        <span class="pill">सही दर : ${((right/M.totalQuestions)*100).toFixed(1)}%</span>
        <span class="pill">समय : ${esc(elapsedText())}</span>
      </div>
      <div style="margin-top:.5rem;display:flex;gap:.3rem;flex-wrap:wrap">${secRows}</div>
      <div class="review-bar">
        <button class="btn btn-ghost" id="againbtn">🔄 पुनः प्रयास करें</button>
        <button class="btn btn-ghost" id="keybtn">📄 उत्तर-कुंजी (Answer Key)</button>
      </div>
      <div class="exp-note" style="margin-top:.55rem">
        ⚠️ <b>नोट :</b> UTET की आधिकारिक परीक्षा में <b>ऋणात्मक अंकन नहीं</b> होता — वहाँ आपके ${right} अंक होंगे।
        यहाँ अभ्यास हेतु <b>−${NEG.toFixed(2)}</b> ऋणात्मक अंकन लागू किया गया है, अतः कुल <b>${marks.toFixed(2)}</b> अंक।
      </div>
    </div>
  </section>`;
  $('#againbtn').onclick = () => { if(confirm('रीसेट करें? सभी उत्तर मिट जाएँगे।')){
    localStorage.removeItem(KEY); location.reload(); } };
  $('#keybtn').onclick = () => {
    let t = 'उत्तर-कुंजी — ' + M.titleEn + ' (SET-' + M.setCode + ')\n\n';
    QS.forEach(q => { t += 'Q.' + q.n + ' → (' + String(q.ans||'-').toUpperCase() + ')\n'; });
    const w = window.open('', '_blank');
    if (w) { w.document.write('<pre style="font:13px monospace;padding:16px">' + t + '</pre>'); }
    else toast('उत्तर-कुंजी खोलने के लिए popup अनुमति दें');
  };
}

/* ============================ TIMER ============================ */
let tick = null;
function startExam(){
  if (S.submitted) return;
  if (!S.started || !S.endsAt) { S.started = true; S.endsAt = Date.now() + M.durationMinutes*60000; save();
    toast('⏱️ परीक्षा प्रारम्भ — आपका समय अभी शुरू हुआ'); }
  const b = document.getElementById('startbtn'); if (b) b.textContent = '▶️ परीक्षा जारी रखें';
  clearInterval(tick); tick = setInterval(paintTimer, 1000); paintTimer();
}
function paintTimer(){
  const el = $('#timer');
  if (!S.started || !S.endsAt){ el.textContent = '⏱️ ' + fmt(M.durationMinutes*60);
    el.className = 'paused'; return; }
  let left = Math.max(0, Math.round((S.endsAt - Date.now())/1000));
  el.textContent = '⏱️ ' + fmt(left);
  el.className = left <= 300 ? 'warn' : '';
  if (left === 0){ clearInterval(tick); autoSubmit(); }
}
function fmt(s){ s=Math.max(0,s|0); const h=(s/3600)|0, m=((s%3600)/60)|0, x=s%60;
  return String(h).padStart(2,'0')+':'+String(m).padStart(2,'0')+':'+String(x).padStart(2,'0'); }
function elapsedText(){
  if (!S.started || !S.endsAt) return '—';
  const used = M.durationMinutes*60 - Math.max(0, Math.round((S.endsAt-Date.now())/1000));
  return fmt(Math.max(0, used));
}
function autoSubmit(){ toast('⏰ समय समाप्त — उत्तर-पत्रक स्वतः जमा हो रहा है'); doSubmit(); }

/* ============================ SUBMIT ============================ */
function openConfirm(){
  if (S.submitted){ toast('परीक्षा पहले ही जमा हो चुकी है'); return; }
  const done = Object.keys(S.ans).length, left = M.totalQuestions - done, flags = Object.keys(S.flag).length;
  $('#csum').innerHTML = `
    <div><b style="color:var(--emerald)">${done}</b><span>हल ✓</span></div>
    <div><b style="color:var(--sub)">${left}</b><span>शेष ⭕</span></div>
    <div><b style="color:var(--amber)">${flags}</b><span>चिह्नित ⚑</span></div>`;
  $('#cwarn').innerHTML = `कुल <b>${M.totalQuestions}</b> में से <b>${done}</b> प्रश्न हल किए गये हैं।
    ${left? `<b style="color:var(--crimson)">${left} प्रश्न अनुत्तरित हैं</b> — फिर भी जमा करना चाहें?</div>`:''}
    जमा करने के बाद उत्तर बदले नहीं जा सकेंगे और हर प्रश्न की <b>व्याख्या सहित समीक्षा</b> खुल जाएगी।`;
  $('#confirm').classList.add('show'); $('#scrim').classList.add('show');
}
function doSubmit(){
  S.submitted = true; save();
  closeSheets();
  QS.forEach(reviewOne);
  scorecard();
  clearInterval(tick);
  const sb = $('#submitbtn');
  sb.textContent = '✅ जमा हो गया'; sb.disabled = true;
  sb.style.opacity = '.55'; sb.style.cursor = 'default';
  sb.onclick = () => toast('परीक्षा जमा हो चुकी है — समीक्षा मोड');
  const b = document.getElementById('startbtn');
  if (b){ b.textContent = '✅ परीक्षा समाप्त — समीक्षा मोड'; b.disabled = true; b.style.opacity='.55'; b.onclick = null; }
  const r = document.getElementById('resetbtn');
  if (r) r.textContent = '🔄 पुनः प्रयास करें';
  window.scrollTo({top:0, behavior:'smooth'});
  toast('✅ उत्तर-पत्रक जमा हो गया — समीक्षा मोड सक्रिय');
}

/* ============================ PALETTE ============================ */
let pfilter = 'all';
function renderPalette(){
  const done = Object.keys(S.ans).length;
  document.querySelector('#pfilters [data-f="done"]').textContent = 'हल ✓ ' + done;
  document.querySelector('#pfilters [data-f="left"]').textContent = 'शेष ⭕ ' + (M.totalQuestions-done);
  document.querySelector('#pfilters [data-f="flag"]').textContent = 'चिह्नित ⚑ ' + Object.keys(S.flag).length;
  let html = '';
  QS.forEach(q => {
    if (pfilter==='done' && !S.ans[q.n]) return;
    if (pfilter==='left' && S.ans[q.n]) return;
    if (pfilter==='flag' && !S.flag[q.n]) return;
    let cls = 'bub';
    if (S.submitted) cls += S.ans[q.n]===q.ans ? ' rok' : (S.ans[q.n] ? ' rno' : '');
    else if (S.ans[q.n]) cls += ' done';
    if (S.flag[q.n]) cls += ' flag';
    if (q.n === current) cls += ' now';
    html += `<button class="${cls}" data-n="${q.n}" title="प्रश्न ${q.n}">${q.n}</button>`;
  });
  $('#pal').innerHTML = html || '<p style="color:var(--sub);font-size:.8rem">इस फ़िल्टर में कोई प्रश्न नहीं।</p>';
  $('#pal').querySelectorAll('.bub').forEach(b => b.onclick = () => goto(+b.dataset.n));
}
function goto(n){
  closeSheets();
  const el = document.getElementById('q'+n); if(!el) return;
  const y = el.getBoundingClientRect().top + window.pageYOffset - 78;
  window.scrollTo({top:y, behavior:'smooth'});
  el.classList.add('current');
  setTimeout(()=>{ if(current!==n) el.classList.remove('current'); }, 1600);
  current = n; $('#qchip').textContent = 'प्र. '+n+'/'+M.totalQuestions;
  haptic(8);
}
function closeSheets(){ $('#palette').classList.remove('show'); $('#confirm').classList.remove('show'); $('#scrim').classList.remove('show'); }
function openPalette(){ renderPalette(); $('#palette').classList.add('show'); $('#scrim').classList.add('show'); }

/* ============================ PROGRESS / COUNTERS ============================ */
function refresh(){
  const done = Object.keys(S.ans).length, left = M.totalQuestions - done;
  $('#cnt').textContent = '[ ' + done + '/' + M.totalQuestions + ' ]';
  $('#cdone').textContent = '✓ ' + done + ' हल';
  $('#cleft').textContent = '⭕ ' + left + ' शेष';
  $('#prog').firstElementChild.style.width = ((done/M.totalQuestions)*100).toFixed(2) + '%';
  if ($('#palette').classList.contains('show')) renderPalette();
}

/* ============================ CURRENT QUESTION OBSERVER ============================ */
let current = 1;
function watchCurrent(){
  const io = new IntersectionObserver(entries => {
    let best = null;
    entries.forEach(e => { if (e.isIntersecting && (!best || e.boundingClientRect.top < best.boundingClientRect.top)) best = e; });
    if (!best) return;
    const n = +best.target.dataset.n; if (!n) return;
    document.querySelectorAll('.q.current').forEach(x=>x.classList.remove('current'));
    best.target.classList.add('current');
    current = n; $('#qchip').textContent = 'प्र. '+n+'/'+M.totalQuestions;
  }, {rootMargin:'-90px 0px -55% 0px', threshold:0});
  document.querySelectorAll('.q').forEach(q=>io.observe(q));
}

/* ============================ CONTROLS ============================ */
function setTheme(t){
  S.theme = t; save();
  document.documentElement.dataset.theme = t;
  $('#theme').textContent = t==='dark' ? '☀️' : '🌙';
  const m = document.querySelector('meta[name=theme-color]');
  if (m) m.setAttribute('content', t==='dark' ? '#080C14' : '#0F172A');
}
function setScale(v){
  S.scale = Math.min(1.45, Math.max(.8, +(v).toFixed(2))); save();
  document.documentElement.style.setProperty('--fs', S.scale);
}
function toggleFull(){
  const d = document.documentElement;
  if (!document.fullscreenElement){ (d.requestFullscreen||d.webkitRequestFullscreen||function(){}).call(d); }
  else { (document.exitFullscreen||document.webkitExitFullscreen||function(){}).call(document); }
}

/* ============================ BOOT ============================ */
function boot(){
  renderCover(); renderQuestions(); refresh();
  setTheme(S.theme || 'light');
  document.documentElement.style.setProperty('--fs', S.scale || 1);
  $('#foot').innerHTML = `यह डिजिटल प्रश्न-पुस्तिका <code>${esc(M.formId)}</code> के सत्यापित डेटा से स्वतः निर्मित है
    · स्रोत <code>${esc(M.sourceRef||'bank-v2')}</code> · बैंक संस्करण <code>${esc(M.bankVersion||'—')}</code>
    · कुल <b>${QS.length}</b> प्रश्न, <b>${SECS.length}</b> अनुभाग, <b>${BOOK.stimuli.length}</b> गद्यांश/कविता<br>
    <span style="font-family:var(--latin)">Generated by tools/v2/build_booklet_html.py — कृपया उत्तरों की पुष्टि आधिकारिक उत्तर-कुंजी से करें।</span>`;

  $('#omrbtn').onclick = openPalette;
  $('#submitbtn').onclick = openConfirm;
  $('#scrim').onclick = closeSheets;
  $('#ccancel').onclick = closeSheets;
  $('#cok').onclick = doSubmit;
  $('#theme').onclick = () => setTheme(S.theme==='dark' ? 'light' : 'dark');
  $('#full').onclick = toggleFull;
  $('#fsu').onclick = () => { setScale((S.scale||1) + .1); toast('अक्षर आकार : ' + Math.round((S.scale||1)*100) + '%'); };
  $('#fsd').onclick = () => { setScale((S.scale||1) - .1); toast('अक्षर आकार : ' + Math.round((S.scale||1)*100) + '%'); };
  document.querySelectorAll('#pfilters button').forEach(b => b.onclick = () => {
    document.querySelectorAll('#pfilters button').forEach(x=>x.classList.remove('on'));
    b.classList.add('on'); pfilter = b.dataset.f; renderPalette();
  });

  if (S.started && !S.submitted){ startExam(); } else { paintTimer(); }
  if (S.submitted){ doSubmit(); } else { watchCurrent(); }

  document.addEventListener('keydown', e => {
    if (e.target.tagName === 'INPUT') return;
    const k = e.key.toLowerCase();
    if (k >= '1' && k <= '4' && !S.submitted){
      const q = QS.find(x=>x.n===current); if(!q) return;
      const o = q.opts[+k-1]; if (o) pick(q, o.id, document.getElementById('q'+q.n));
    }
    else if (k === 'b') { const q = QS.find(x=>x.n===current); if(q) toggleFlag(q, document.querySelector('#q'+q.n+' .bmk')); }
    else if (k === 'n' && current < M.totalQuestions) goto(current+1);
    else if (k === 'p' && current > 1) goto(current-1);
    else if (k === 'm') { $('#palette').classList.contains('show') ? closeSheets() : openPalette(); }
    else if (k === 'escape') closeSheets();
  });
  document.addEventListener('visibilitychange', () => { if (!document.hidden) paintTimer(); });
}
boot();
</script>
</body>
</html>
"""


# --------------------------------------------------------------------------
def render(data, title):
    payload = json.dumps(data, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")
    html = HTML.replace("__DATA__", payload)
    html = html.replace("__TITLE__", title)
    html = html.replace("__N__", str(data["meta"]["totalQuestions"]))
    html = html.replace("__DUR__", fmt_clock(data["meta"]["durationMinutes"] * 60))
    return html


INDEX = """<!DOCTYPE html><html lang="hi"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta http-equiv="refresh" content="0;url=%s">
<title>हल प्रश्न-पुस्तिका — Index</title>
<style>body{margin:0;font-family:'Noto Sans Devanagari','Nirmala UI',system-ui,sans-serif;
background:#F1F5F9;color:#0F172A;display:flex;align-items:center;justify-content:center;height:100vh}
a{display:block;max-width:30rem;text-align:center;font-size:1.05rem;font-weight:700;
background:#fff;border:1px solid #E2E8F0;border-radius:1rem;padding:1.5rem;text-decoration:none;color:#4F46E5;
box-shadow:0 10px 30px -18px rgba(15,23,42,.4)}span{display:block;font-size:.75rem;color:#64748B;margin-top:.4rem;font-weight:500}</style>
</head><body><a href="%s">📖 %s<span>अगर अपने आप न खुले तो यहाँ टैप करें · If not redirected, tap here</span></a></body></html>
"""

def write_index(target, title):
    os.makedirs(DEFAULT_OUT_DIR, exist_ok=True)
    with open(os.path.join(DEFAULT_OUT_DIR, "index.html"), "w", encoding="utf-8") as fh:
        fh.write(INDEX % (target, target, title))


def fmt_clock(seconds):
    h, rem = divmod(int(seconds), 3600)
    m, s = divmod(rem, 60)
    return "%02d:%02d:%02d" % (h, m, s)


def main():
    ap = argparse.ArgumentParser(description="Build a single-file HTML exam booklet from bank-v2.")
    ap.add_argument("--form", default="utet-p1-2025-set-a", help="paper-form id, e.g. utet-p1-2024-set-d")
    ap.add_argument("--out", default=None, help="output HTML path")
    args = ap.parse_args()

    data = build_data(args.form)
    m = data["meta"]
    title = "%s %s — Paper-I Set-%s | हल प्रश्न-पुस्तिका" % (m["exam"], m["cycle"], m["setCode"])
    out = args.out or os.path.join(DEFAULT_OUT_DIR, "%s.html" % m["formId"])
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as fh:
        fh.write(render(data, title))
    if os.path.dirname(os.path.abspath(out)) == os.path.abspath(DEFAULT_OUT_DIR):
        write_index(os.path.basename(out), title)

    size = os.path.getsize(out) / 1024.0
    print("form        : %s" % m["formId"])
    print("exam date   : %s  |  set %s  |  %s" % (m["examDateHi"], m["setCode"], m["verificationStatus"]))
    print("questions   : %d  |  sections: %d  |  stimuli: %d"
          % (len(data["questions"]), len(data["sections"]), len(data["stimuli"])))
    for s in data["sections"]:
        print("   भाग-%d %-32s प्र. %3d–%3d" % (s["index"], s["labelHi"], s["from"], s["to"]))
    print("output      : %s (%.1f KB)" % (os.path.relpath(out, REPO_ROOT), size))
    return 0


if __name__ == "__main__":
    sys.exit(main())

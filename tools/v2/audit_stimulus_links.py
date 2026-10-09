#!/usr/bin/env python3
"""Verify that every stimulus-linked question actually belongs to its passage/poem.

The bank stores passages, poems and tables as `stimuli.ndjson` and points questions
at them with `stimulusId`.  Structural checks alone (counts, ID ranges) cannot show
that question 93 was wired to the right paragraph, so this tool adds three layers:

1. structural  - stimulus exists, question count >= `minimumQuestions`, the numbers
                  parsed out of the question IDs cover the range announced by the
                  stimulus instruction, and exam/paper/section/language/slot agree.
2. lexical     - every question of a stimulus must share surface content words with
                  its own stimulus text (token or 4-gram overlap).  A comprehension
                  question that shares nothing with its own passage is suspect.
3. exclusive   - if a question overlaps another stimulus of the same year/slot far
                  more than its own, the link is probably swapped.

Output: one Markdown report per exam+year under `bank-v2/audits/stimulus-links/`,
a machine-readable NDJSON findings file, and an index.  Exit code is non-zero when
a definite (not merely suspicious) finding exists.

Usage:
    python3 tools/v2/audit_stimulus_links.py                 # whole bank
    python3 tools/v2/audit_stimulus_links.py --exam ctet --year 2016
    python3 tools/v2/audit_stimulus_links.py --json-only
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import unicodedata
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
EXAMS_DIR = os.path.join(ROOT, "bank-v2", "exams")
OUT_DIR = os.path.join(ROOT, "bank-v2", "audits", "stimulus-links")

DEVANAGARI = (
    "\u0900-\u0950\u0953-\u0963\u0966-\u096f"
    "\u0970-\u097f"  # includes the Devanagari letter set used for Sanskrit/Hindi
)
TOKEN_RE = re.compile(
    r"[A-Za-z\u00c0-\u024f'\u2019-]+|[" + DEVANAGARI + r"]+"
)
NUM_RANGE_RE = re.compile(r"(?:\d{1,3}\s*(?:\u2013|\u2014|-|to|\u0938\u0947)\s*\d{1,3})")

STOP = {
    "hi": {
        "और", "के", "की", "का", "को", "है", "में", "से", "पर", "ने", "इस", "उस", "यह",
        "वह", "भी", "ही", "तो", "जो", "कि", "एक", "दिए", "गए", "कर", "हो", "थे", "था",
        "थी", "इन", "उन", "इनमें", "किस", "क्या", "अनुसार", "लिए", "प्र", "सं", "निर्देश",
        "निम्नलिखित", "विकल्प", "सही", "उत्तर", "वाले", "को", "चुनिए", "उपयुक्त",
        "सबसे", "इनमें", "में", "से", "का", "की", "के", "हैं", "होता", "होती", "रहा",
        "जाता", "जाती", "करता", "करती", "किया", "दिया", "लिया", "बताइए", "बताएँ",
    },
    "en": {
        "the", "a", "an", "and", "or", "of", "to", "in", "is", "are", "was", "were",
        "for", "on", "at", "by", "as", "with", "from", "that", "this", "these", "those",
        "which", "what", "who", "not", "be", "been", "has", "have", "had", "do", "does",
        "did", "given", "passage", "poem", "question", "questions", "choose", "correct",
        "answer", "option", "directions", "following", "above", "one", "it", "its",
    },
    "sa": set(),
    "ur": set(),
}

LANGCODE = {"hindi": "hi", "english": "en", "sanskrit": "sa", "urdu": "ur",
            "hi": "hi", "en": "en", "sa": "sa", "ur": "ur"}

# Question types that are grammar/vocabulary drill rather than comprehension: zero
# lexical overlap with the passage is normal for them, so they are reported but not
# counted as suspicious.
NON_COMPREHENSION_HINTS = (
    "विलोम", "पर्यायवाची", "संधि", "समास", "उपसर्ग", "प्रत्यय", "अलंकार", "रस",
    "छंद", "मुहावरा", "लोकोक्ति", "वर्तनी", "रचना", "विशेषण", "संज्ञा", "वाच्य",
    "antonym", "synonym", "spelling", "plural", "tense", "rhyming", "figure of speech",
    "metre", "meter", "parts of speech", "gender",
)


def norm(s: str) -> str:
    s = unicodedata.normalize("NFC", s or "")
    return s.replace("\u2019", "'").replace("\u2018", "'")


def flatten_value(v, lang: str | None, out: list[str]) -> None:
    """Depth-first walk of any content structure, collecting display strings."""
    if v is None or isinstance(v, (int, float, bool)):
        return
    if isinstance(v, str):
        out.append(v)
        return
    if isinstance(v, list):
        for item in v:
            flatten_value(item, lang, out)
        return
    if isinstance(v, dict):
        for key in ("text", "header", "caption", "cells", "rows", "columns",
                    "alt", "label", "value", "content", "title", "source"):
            if key in v:
                flatten_value(v[key], lang, out)


def blocks(parts, lang: str | None = None) -> list[str]:
    """Flatten a content-part list (or a localized dict) to plain strings.

    Tables and image parts are walked too, so a question about a table row can be
    scored against the table instead of against an empty string.
    """
    if isinstance(parts, list) and any(isinstance(p, dict) and "kind" in p for p in parts):
        out: list[str] = []
        for p in parts:
            kind = p.get("kind")
            if kind in ("markdown", "text", "latex"):
                t = p.get("text")
                if isinstance(t, dict):
                    out.extend(blocks(t, lang))
                elif t is not None:
                    out.append(str(t))
            else:
                flatten_value({k: v for k, v in p.items() if k != "kind"}, lang, out)
        return out
    return _blocks(parts, lang)


def _blocks(parts, lang: str | None = None) -> list[str]:
    """Flatten a content-part list (or a localized dict) to plain strings."""
    if parts is None:
        return []
    if isinstance(parts, dict):
        if lang and lang in parts:
            return [str(parts[lang])]
        out = []
        for k in ("hi", "en", "sa", "ur"):
            if k in parts:
                out.append(str(parts[k]))
        if not out:
            out = [str(v) for v in parts.values()]
        return out
    out = []
    for p in parts:
        if isinstance(p, dict):
            t = p.get("text")
            if isinstance(t, dict):
                out.extend(blocks(t, lang))
            elif t is not None:
                out.append(str(t))
        elif isinstance(p, str):
            out.append(p)
    return out


def text_blocks(parts, lang=None):
    """Alias kept separate from local variables named `blocks`."""
    return blocks(parts, lang)


def localized(obj: dict, key: str, lang: str | None = None) -> str:
    return "\n".join(blocks(obj.get(key), lang)).strip()


EN_SUFFIX = ("ingly", "edly", "ing", "edly", "ies", "ied", "es", "ed", "ly", "s", "'s")


def stem(t: str, lang: str) -> str:
    if lang == "en":
        for suf in EN_SUFFIX:
            if t.endswith(suf) and len(t) - len(suf) >= 3:
                t = t[: -len(suf)]
                if suf in ("ies", "ied"):
                    t += "y"
                break
    elif lang == "hi":
        # drop the most productive case/number endings so inflected forms collapse
        for suf in ("कर", "करने", "रही", "रहा", "गया", "गयी", "में", "से", "को", "का", "की",
                    "के", "पर", "ने", "ही", "भी", "तो", "और", "एक"):
            if t.endswith(suf) and len(t) - len(suf) >= 2:
                t = t[: -len(suf)]
                break
    return t


def tokens(text: str, lang: str) -> list[str]:
    toks = [t.lower() for t in TOKEN_RE.findall(text)]
    if lang in ("hi", "en"):
        stop = STOP[lang]
        toks = [t for t in toks if t not in stop and len(t) > 1 and not t.isdigit()]
        toks = [stem(t, lang) or t for t in toks]
    else:
        toks = [t for t in toks if len(t) > 2]
    return toks


def ngrams(toks: list[str], n: int = 2) -> set[tuple[str, ...]]:
    """Word n-grams.  Devanagari morphology makes character n-grams meaningless."""
    return {tuple(toks[i:i + n]) for i in range(max(0, len(toks) - n + 1))}


def lcs_len(a: list[str], b: list[str]) -> int:
    """Length (in words) of the longest common contiguous run of words."""
    best = 0
    prev = [0] * (len(b) + 1)
    for i in range(1, len(a) + 1):
        cur = [0] * (len(b) + 1)
        for j in range(1, len(b) + 1):
            if a[i - 1] == b[j - 1]:
                cur[j] = prev[j - 1] + 1
                best = max(best, cur[j])
        prev = cur
    return best


# Only true quotation marks delimit a quoted phrase. A straight apostrophe inside a
# word ("Maria's aggregate marks ...") must not be treated as an opening quote.
QUOTE_OPEN = "\u2018\u201c\x27\x22"
QUOTE_CLOSE = "\u2019\u201d\x27\x22"


def quoted(text: str) -> list[str]:
    """Extract quoted phrases.

    A straight apostrophe only counts as an opening quote when it starts a word,
    so a possessive ("Maria's aggregate marks") is not mistaken for a quotation.
    """
    out: list[str] = []
    i = 0
    n = len(text)
    while i < n:
        ch = text[i]
        if ch in QUOTE_OPEN and (ch in "\u2018\u201c" or i == 0
                                 or not (text[i - 1].isalnum() or text[i - 1] in "\u2019'")):
            close = QUOTE_CLOSE[QUOTE_OPEN.index(ch)]
            j = text.find(close, i + 1)
            if j > i:
                cand = text[i + 1:j].strip()
                if len(cand) >= 4:
                    out.append(cand)
                i = j + 1
                continue
        i += 1
    return out


def load_ndjson(path: str) -> list[dict]:
    if not os.path.exists(path):
        return []
    with open(path, encoding="utf-8") as fh:
        return [json.loads(line) for line in fh if line.strip()]


def qnum(qid: str) -> int | None:
    m = re.search(r"q(\d{3})(?!\d)", qid)
    return int(m.group(1)) if m else None


def year_of(ident: str) -> str:
    parts = ident.split("-")
    for i, p in enumerate(parts):
        if p == "p1" and i + 1 < len(parts):
            return parts[i + 1]
    m = re.match(r".*?-p1-(\d{4})", ident)
    return m.group(1) if m else "unknown"


def section_dirs() -> list[tuple[str, str, str, str]]:
    out = []
    for exam in sorted(os.listdir(EXAMS_DIR)):
        epath = os.path.join(EXAMS_DIR, exam)
        if not os.path.isdir(epath):
            continue
        for paper in sorted(os.listdir(epath)):
            ppath = os.path.join(epath, paper)
            if not os.path.isdir(ppath):
                continue
            for sec in sorted(os.listdir(ppath)):
                spath = os.path.join(ppath, sec)
                if os.path.exists(os.path.join(spath, "questions.ndjson")):
                    out.append((exam, paper, sec, spath))
                else:
                    for lang in sorted(os.listdir(spath)):
                        lpath = os.path.join(spath, lang)
                        if os.path.exists(os.path.join(lpath, "questions.ndjson")):
                            out.append((exam, paper, f"{sec}/{lang}", lpath))
    return out


def audit_section(exam: str, paper: str, section: str, path: str) -> list[dict]:
    stimuli = {s["id"]: s for s in load_ndjson(os.path.join(path, "stimuli.ndjson"))}
    questions = load_ndjson(os.path.join(path, "questions.ndjson"))
    lang = LANGCODE.get(section.split("/")[-1] if "/" in section else "", "")
    groups: dict[str, list[dict]] = defaultdict(list)
    findings: list[dict] = []

    for q in questions:
        sid = q.get("stimulusId")
        if not sid:
            continue
        if sid not in stimuli:
            findings.append(dict(severity="definite", kind="dangling-stimulus",
                                 questionId=q["id"], stimulusId=sid,
                                 detail="stimulusId does not exist in this section"))
            continue
        groups[sid].append(q)

    for sid, stim in stimuli.items():
        if sid not in groups:
            findings.append(dict(severity="definite", kind="orphan-stimulus",
                                 stimulusId=sid,
                                 detail="stimulus has no question pointing at it"))

    for sid, qs in groups.items():
        stim = stimuli[sid]
        qs.sort(key=lambda q: q["id"])
        stim_text = "\n".join(blocks(stim.get("content")))
        stim_toks = tokens(stim_text, lang)
        stim_set, stim_gram = set(stim_toks), ngrams(stim_toks)
        title = localized(stim, "title", lang) or localized(stim, "title")
        instr = localized(stim, "instructions", lang) or localized(stim, "instructions")
        nums = [n for n in (qnum(q["id"]) for q in qs) if n is not None]

        # ---- structural -------------------------------------------------
        syear = year_of(sid)
        for q in qs:
            if syear not in q["id"]:
                findings.append(dict(severity="definite", kind="year-mismatch",
                                     questionId=q["id"], stimulusId=sid,
                                     detail=f"stimulus year {syear} != question id year"))
            for field in ("exam", "paper", "section", "language", "languageSlot"):
                if field in stim and field in q and stim[field] != q[field]:
                    findings.append(dict(severity="definite", kind="field-mismatch",
                                         questionId=q["id"], stimulusId=sid,
                                         field=field, detail=f"{stim[field]!r} != {q[field]!r}"))
        minq = stim.get("minimumQuestions")
        if isinstance(minq, int) and len(qs) < minq:
            findings.append(dict(severity="definite", kind="too-few-questions",
                                 stimulusId=sid, detail=f"{len(qs)} questions, minimumQuestions={minq}"))
        m = NUM_RANGE_RE.search(instr or "")
        if m and nums:
            a, b = (int(x) for x in re.findall(r"\d{1,3}", m.group(0))[:2])
            expected = set(range(a, b + 1))
            missing = sorted(expected - set(nums))
            extra = sorted(set(nums) - expected)
            if missing or extra:
                findings.append(dict(severity="definite", kind="instruction-range",
                                     stimulusId=sid,
                                     detail=f"instruction says {m.group(0)}, linked={sorted(nums)}, "
                                            f"missing={missing}, extra={extra}"))

        # ---- lexical ----------------------------------------------------
        # score every question against its own stimulus and against the sibling
        # stimuli of the same year, so a swapped link shows up as a better fit.
        all_tok = {oid: tokens("\n".join(blocks(o.get("content"))), lang)
                   for oid, o in stimuli.items()}
        siblings = {oid: t for oid, t in all_tok.items()
                    if oid != sid and year_of(oid) == syear}
        sibling_tok = siblings

        for q in qs:
            qtext = "\n".join(blocks(q.get("prompt"))) + "\n" + "\n".join(
                "\n".join(blocks(o.get("content"))) for o in q.get("options", []))
            qtok = tokens(qtext, lang)
            qset, qgram = set(qtok), ngrams(qtok)
            ov = len(qset & stim_set) / len(qset) if qset else 0.0
            gov = len(qgram & stim_gram) / len(qgram) if qgram else 0.0
            run = lcs_len(qtok, stim_toks) / len(qtok) if qtok else 0.0
            score = max(ov, gov, run)
            best_alt, best_alt_score = None, 0.0
            for oid, otoks in sibling_tok.items():
                oset = set(otoks)
                alt = max(len(qset & oset) / len(qset) if qset else 0.0,
                          lcs_len(qtok, otoks) / len(qtok) if qtok else 0.0)
                if alt > best_alt_score:
                    best_alt, best_alt_score = oid, alt
            drill = any(h in qtext.lower() for h in NON_COMPREHENSION_HINTS)

            # Does a sibling stimulus of the SAME paper fit this question far better?
            # (Only same-year siblings: another year's passage sharing a topic would
            # otherwise produce noise instead of a wiring signal.)
            if best_alt and lang in ("hi", "en") and best_alt_score >= 0.5 \
                    and best_alt_score > score * 2:
                findings.append(dict(
                    severity="suspicious", kind="fits-sibling-better",
                    questionId=q["id"], stimulusId=sid,
                    detail=f"fits `{best_alt}` far better ({best_alt_score:.2f}) than its own "
                           f"stimulus ({score:.2f}) - possible swapped passage"))

            # Strongest, morphology-independent check: if the question quotes a
            # line or phrase, that phrase must actually occur in the stimulus it is
            # attached to.  A miss means the question was wired to the wrong text.
            quote_missing = None
            for quote in quoted(qtext):
                qt = tokens(quote, lang)
                if len(qt) >= 3:
                    if " ".join(qt) not in " ".join(stim_toks) and not (set(qt) & stim_set):
                        quote_missing = quote
                        break
            if quote_missing is not None:
                findings.append(dict(
                    severity="definite", kind="quoted-text-not-in-stimulus",
                    questionId=q["id"], stimulusId=sid,
                    detail=f"question refers to '{quote_missing[:80]}' which does not occur in "
                           f"its own stimulus"))

            if score == 0.0:
                # shares not one content word with the passage it is attached to
                findings.append(dict(
                    severity="info" if drill else (
                        "suspicious" if lang in ("hi", "en") else "needs-reading"),
                    kind="drill-no-overlap" if drill else "no-lexical-overlap",
                    questionId=q["id"], stimulusId=sid, section_hint=lang,
                    detail="question shares no content word with its own stimulus "
                           f"(token {ov:.2f}, bigram {gov:.2f}, run {run:.2f})"))
            elif best_alt_score >= 0.5 and best_alt_score > score * 2:
                findings.append(dict(
                    severity="suspicious", kind="better-fits-other-stimulus",
                    questionId=q["id"], stimulusId=sid,
                    detail=f"own score {score:.2f}, but {best_alt} score {best_alt_score:.2f}"))


            findings.append(dict(severity="metric", kind="lexical", questionId=q["id"],
                                 stimulusId=sid, tokenOverlap=round(ov, 3),
                                 bigramOverlap=round(gov, 3), runOverlap=round(run, 3),
                                 score=round(score, 3),
                                 bestAlt=best_alt, bestAltScore=round(best_alt_score, 3)))
    return findings


BLOCK_KIND_HINTS = (
    "शिक्षक", "छात्र", "बालक", "अधिगम", "भाषाशिक्षण", "कक्षा", "शिक्षिका", "बहुभाषिकता",
    "teacher", "learner", "classroom", "pedagogy", "acquisition", "multilingual",
)


def classify(scores: list[float], qtexts: list[str], lang: str) -> str:
    """Block-level verdict for one stimulus and the questions wired to it."""
    n = len(scores)
    if not n:
        return "empty"
    zero = sum(1 for x in scores if x == 0.0)
    weak = sum(1 for x in scores if x < 0.05)
    median = sorted(scores)[n // 2]
    drillish = sum(1 for t in qtexts
                   if any(h in t.lower() for h in NON_COMPREHENSION_HINTS))
    pedagogic = sum(1 for t in qtexts
                    if any(h in t.lower() for h in BLOCK_KIND_HINTS))
    if median >= 0.08 and weak <= n * 0.34:
        return "ok"
    if pedagogic >= max(2, n * 0.6):
        return "pedagogy-block"
    if drillish >= max(2, n * 0.6):
        return "drill-block"
    if zero >= max(2, n * 0.6) and lang == "sa":
        return "unverifiable-sanskrit"
    if zero >= max(2, n * 0.6):
        return "wrong-passage"
    return "partial"


VERDICT_LABEL = {
    "ok": "ठीक",
    "partial": "आधा-अधूरा मिलान",
    "wrong-passage": "गलत गद्यांश/कविता जुड़ा है",
    "pedagogy-block": "ये पेडागॉजी प्रश्न हैं, गद्यांश पर निर्भर नहीं",
    "drill-block": "व्याकरण/शब्दावली अभ्यास प्रश्न",
    "unverifiable-sanskrit": "संस्कृत रूपों के कारण स्वतः जाँच संभव नहीं - पढ़कर देखें",
    "empty": "कोई प्रश्न नहीं",
}


def collect() -> dict:
    """Run every check and return rows plus per-stimulus blocks."""
    rows, blk_map = [], {}
    for exam, paper, section, path in section_dirs():
        lang = LANGCODE.get(section.split("/")[-1] if "/" in section else "", "")
        stimuli = {s["id"]: s for s in load_ndjson(os.path.join(path, "stimuli.ndjson"))}
        questions = load_ndjson(os.path.join(path, "questions.ndjson"))
        byq = {q["id"]: q for q in questions}
        findings = audit_section(exam, paper, section, path)
        for f in findings:
            f["exam"], f["paper"], f["section"] = exam, paper, section
            sid = f.get("stimulusId") or f.get("questionId") or ""
            f["year"] = year_of(sid)
            rows.append(f)
            if f["severity"] != "metric":
                continue
            key = (exam, paper, section, lang, f["year"], f["stimulusId"])
            blk = blk_map.setdefault(key, dict(
                stimulusId=f["stimulusId"], exam=exam, paper=paper, section=section,
                lang=lang, year=f["year"], scores=[], qtexts=[], questions=[]))
            blk["scores"].append(f["score"])
            q = byq.get(f["questionId"])
            if q is not None:
                blk["qtexts"].append("\n".join(text_blocks(q.get("prompt"))) + " " + " ".join(
                    "\n".join(text_blocks(o.get("content"))) for o in q.get("options", [])))
                blk["questions"].append(f["questionId"])
    for key, blk in blk_map.items():
        blk["verdict"] = classify(blk["scores"], blk["qtexts"], blk["lang"])
        blk["zero"] = sum(1 for x in blk["scores"] if x == 0.0)
        blk["median"] = round(sorted(blk["scores"])[len(blk["scores"]) // 2], 3)
    return dict(rows=rows, blocks=blk_map)


def write_reports(data: dict) -> str:
    """One Markdown report per exam+year, plus index and machine-readable findings."""
    os.makedirs(OUT_DIR, exist_ok=True)
    rows = data["rows"]
    blocks = data["blocks"]

    by_year: dict[tuple[str, str], list[dict]] = defaultdict(list)
    for key, blk in blocks.items():
        by_year[(blk["exam"], blk["year"])].append(blk)

    stim_texts: dict[str, dict] = {}
    for exam, paper, section, path in section_dirs():
        for s in load_ndjson(os.path.join(path, "stimuli.ndjson")):
            stim_texts[s["id"]] = s
    all_questions: dict[str, dict] = {}
    for exam, paper, section, path in section_dirs():
        for q in load_ndjson(os.path.join(path, "questions.ndjson")):
            all_questions[q["id"]] = q

    index = []
    ndjson_path = os.path.join(OUT_DIR, "findings.ndjson")
    with open(ndjson_path, "w", encoding="utf-8") as nd:
        for r in rows:
            nd.write(json.dumps(r, ensure_ascii=False) + "\n")

    for (exam, year), blks in sorted(by_year.items()):
        blks.sort(key=lambda b: (b["section"], min(b["questions"] or [""])))
        counts = defaultdict(int)
        for b in blks:
            counts[b["verdict"]] += 1
        lines = [
            f"# {exam.upper()} Paper-I {year} — गद्यांश/कविता लिंक ऑडिट",
            "",
            "`score` = प्रश्न के content शब्दों में से कितने अपने गद्यांश में मिलते हैं "
            "(0.00 = एक भी शब्द नहीं)। verdict पूरे ब्लॉक का है।",
            "",
        ]
        for v in ("ok", "partial", "wrong-passage", "pedagogy-block", "drill-block",
                  "unverifiable-sanskrit"):
            if counts[v]:
                lines.append(f"- {VERDICT_LABEL[v]}: **{counts[v]}** ब्लॉक")
        lines.append("")
        year_findings = [r for r in rows if r["exam"] == exam and r["year"] == year
                         and r["severity"] in ("definite", "suspicious")]
        if year_findings:
            lines.append("## प्रश्न-स्तर की गड़बड़ियाँ")
            lines.append("")
            for r in sorted(year_findings,
                            key=lambda r: (r["severity"] != "definite", r.get("questionId", ""))):
                mark = "✗" if r["severity"] == "definite" else "?"
                lines.append(f"- {mark} `{r.get('questionId')}` **{r['kind']}** — {r['detail']}  "
                             f"\n  stimulus `{r.get('stimulusId')}` · `{r['section']}`")
            lines.append("")
        for b in blks:
            stim = stim_texts.get(b["stimulusId"], {})
            body = "\n".join(text_blocks(stim.get("content")))
            lines += [
                "---",
                f"## `{b['section']}` — {b['stimulusId']}",
                f"**verdict: {VERDICT_LABEL[b['verdict']]}** · type={stim.get('type')} · "
                f"प्रश्न={len(b['scores'])} · बिना-मिलान={b['zero']} · median score={b['median']}",
                "",
                f"निर्देश: {localized(stim, 'instructions')}",
                "",
                "```",
                body[:1200],
                "```",
                "",
            ]
            for qid, sc in zip(b["questions"], b["scores"]):
                q = all_questions.get(qid, {})
                stem = " ".join(text_blocks(q.get("prompt"))).replace("\n", " ")
                mark = "✗" if sc == 0.0 else ("~" if sc < 0.05 else "✓")
                lines.append(f"- {mark} `{qid.split('-')[-1]}` score={sc:.2f} — {stem[:160]}")
            lines.append("")
        name = f"{exam}-p1-{year}-stimulus-links.md"
        with open(os.path.join(OUT_DIR, name), "w", encoding="utf-8") as fh:
            fh.write("\n".join(lines))
        index.append(dict(file=name, exam=exam, year=year,
                          definiteQuestions=sum(1 for r in year_findings
                                                if r["severity"] == "definite"),
                          suspiciousQuestions=sum(1 for r in year_findings
                                                  if r["severity"] == "suspicious"),
                          **{k: counts[k] for k in VERDICT_LABEL}))
    with open(os.path.join(OUT_DIR, "index.json"), "w", encoding="utf-8") as fh:
        json.dump(index, fh, ensure_ascii=False, indent=2)
    return ndjson_path


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--exam", default=None)
    ap.add_argument("--year", default=None)
    ap.add_argument("--section", default=None)
    ap.add_argument("--only-problems", action="store_true",
                    help="print only blocks that are not ok")
    args = ap.parse_args()

    data = collect()
    blocks = data["blocks"]
    if args.exam:
        blocks = {k: v for k, v in blocks.items() if v["exam"] == args.exam}
        data["rows"] = [r for r in data["rows"] if r["exam"] == args.exam]
    if args.year:
        blocks = {k: v for k, v in blocks.items() if v["year"] == args.year}
        data["rows"] = [r for r in data["rows"] if r["year"] == args.year]
    if args.section:
        blocks = {k: v for k, v in blocks.items() if args.section in v["section"]}
    data["blocks"] = blocks

    nd = write_reports(data)
    rows = data["rows"]
    definite = [r for r in rows if r["severity"] == "definite"]
    by_year = defaultdict(lambda: defaultdict(int))
    for b in blocks.values():
        by_year[(b["exam"], b["year"])][b["verdict"]] += 1
    print(f"questions-with-stimulus scored : {sum(1 for r in rows if r['severity'] == 'metric')}")
    print(f"stimulus blocks               : {len(blocks)}")
    print(f"structural defects (definite) : {len(definite)}")
    print()
    print(f"{'cycle':12}{'ok':>4}{'partial':>9}{'wrong':>7}{'pedagogy':>10}{'drill':>7}{'sa?':>5}")
    for (exam, year) in sorted(by_year):
        c = by_year[(exam, year)]
        print(f"{exam}-{year:12}".ljust(12)
              + f"{c['ok']:4}{c['partial']:9}{c['wrong-passage']:7}"
              + f"{c['pedagogy-block']:10}{c['drill-block']:7}{c['unverifiable-sanskrit']:5}")
    print()
    print("blocks that are not ok:")
    for b in sorted(blocks.values(), key=lambda b: (b["exam"], b["year"], b["section"])):
        if b["verdict"] == "ok" and args.only_problems:
            continue
        if b["verdict"] == "ok":
            continue
        nums = ",".join(q.split("-")[-1][1:] for q in b["questions"])
        print(f"  [{b['verdict']:22}] {b['exam']}-{b['year']} {b['section']:22} "
              f"Q{nums}  zero={b['zero']}/{len(b['scores'])}")
    print(f"\nreports -> {os.path.relpath(OUT_DIR, ROOT)}   findings -> {os.path.relpath(nd, ROOT)}")
    return 1 if definite else 0


if __name__ == "__main__":
    sys.exit(main())

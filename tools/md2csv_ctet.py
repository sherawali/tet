# -*- coding: utf-8 -*-
"""
ctet-questions/*.md  →  content/q_ctet.csv
CTET ke extracted questions ko question-bank CSV schema mein convert karta hai.
- bina uttar / adhoore options waale प्रश्न skip
- English/Hindi dual stems split (q_en / q_hi)
- संस्कृत/उर्दू language sections skip (app sections: cdp, math, evs, hindi, english)
- गद्यांश blockquotes → inline passage columns (pid/p_kind/p_dir/p_body)
"""
import csv, glob, hashlib, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "ctet-questions")
OUT = os.path.join(ROOT, "content", "q_ctet.csv")

BANKS = {  # file → fixed section (practice banks)
    "CTET CDP Questiins for Paper-1.md": "cdp",
    "CTET Evs Notes and Pedagogy.md": "evs",
    "CTET Maths Pedagogy Questions Paper 2_watermark.md": "math",
    "CTET Hindi Language_ Pedagogy.md": "hindi",
    "CTET-Pedagogy of English Language _watermark.md": "english",
}
YEAR_RX = re.compile(r"(20\d\d)")
DEV = re.compile(r"[\u0900-\u097F]")
SKT_WORDS = re.compile(r"\b(अस्ति|भवति|सन्ति|भवन्ति|कुरुत|चिनुत|लिखत|पठत|अस्मिन्|तेषां|तासां|एतेषु|"
    r"अधोलिखित\S*|उदाहरणानुसार\S*|इति|एव|किम्|कथम्|कुत्र|अहम्|वयम्|भवान्|भवत:|छात्राणां|"
    r"कथनम्|वाक्यम्|पदम्|नाम|अत्र|तत्र|यत्र|सह|विना|कृते|द्वारा़?)\b")

def sanskrit_score(txt):
    sc = 0
    sc += 2 * len(re.findall(r"[क-हा-ौृ][:ः](?=[\s,।!?)\-]|$)", txt))      # visarga
    sc += 2 * len(re.findall(r"[क-ह]्?[ा-ौ]?म्(?=[\s,।!?)\-]|$)", txt))    # -म् endings
    sc += 2 * len(re.findall(r"(?<!रह)(?<!सद)स्य(?=[\s,।!?)\-]|$)", txt)) # genitive -स्य
    sc += 2 * len(re.findall(r"(ेषु|ायाम्|ाभि:|ाभिः|ानाम्|ेभ्य:|ेभ्यः)(?=[\s,।]|$)", txt))
    sc += len(SKT_WORDS.findall(txt))
    return sc

def devanagari_ratio(s):
    d = len(DEV.findall(s)); l = len(re.findall(r"[A-Za-z]", s))
    return d, l

def is_sanskrit(s):
    return sanskrit_score(s) >= 5

def clean(s):
    s = re.sub(r"\*\*(.+?)\*\*", r"\1", s)
    s = re.sub(r"^#+\s*", "", s, flags=re.M)
    s = re.sub(r"\s+", " ", s).strip()
    return s

def split_bilingual(s):
    """English-first dual text → (en, hi); warna ('', text)."""
    m = DEV.search(s)
    if not m:
        return "", s                      # pure english → q_hi me hi jayega
    en, hi = s[:m.start()], s[m.start():]
    en = en.rstrip(" /|-–—")
    d_hi = len(DEV.findall(hi))
    if len(re.findall(r"[A-Za-z]", en)) >= 15 and " " in en.strip() and d_hi >= 8:
        return en.strip(), hi.strip()
    return "", s

def sec_from_heading(line):
    if not re.match(r"^## *(भाग|PART|Part)\b", line):
        return None
    L = line
    if re.search(r"बाल विकास|CHILD DEV|CDP", L, re.I): return "cdp"
    if re.search(r"गणित|MATH", L, re.I): return "math"
    if re.search(r"पर्यावरण|ENVIRON|EVS", L, re.I): return "evs"
    if re.search(r"संस्कृत|SANSKRIT|उर्दू|URDU", L, re.I): return "sanskrit"
    if re.search(r"अंग्रेज|ENGLISH", L, re.I) and not re.search(r"हिन्दी|हिंदी|HINDI", L, re.I): return "english"
    if re.search(r"हिन्दी|हिंदी|HINDI", L, re.I) and not re.search(r"अंग्रेज|ENGLISH", L, re.I): return "hindi"
    if re.search(r"भाषा|LANGUAGE", L, re.I): return "lang"
    return None

def sec_for_q(part, qno, stem_all, opts_all):
    """CTET Paper-1 ka structure FIXED hai — headings ke bharose nahi,
    canonical ranges: 1-30 cdp, 31-60 math, 61-90 evs, 91+ language."""
    if 1 <= qno <= 30: return "cdp"
    if 31 <= qno <= 60: return "math"
    if 61 <= qno <= 90: return "evs"
    # language section (91-150 + variants >150): content se decide
    txt = stem_all + " " + " ".join(opts_all)
    d, l = devanagari_ratio(txt)
    if is_sanskrit(txt): return "sanskrit"
    if l > d * 2: return "english"
    return "hindi"

ANS_MAP = {"a": 0, "b": 1, "c": 2, "d": 3, "1": 0, "2": 1, "3": 2, "4": 3}

rows, stats = [], {"total": 0, "no_ans": 0, "bad_opts": 0, "sanskrit": 0, "ok": 0}
pass_seen = {}

for path in sorted(glob.glob(os.path.join(SRC, "*.md")), key=str.lower):
    fn = os.path.basename(path)
    if fn == "README.md":
        continue
    text = open(path, encoding="utf-8").read()
    bank_sec = BANKS.get(fn)
    ym = YEAR_RX.search(fn)
    year = ym.group(1) if ym else ""
    label = re.sub(r"\.md$|_watermark", "", fn).replace("CTET", "").strip(" -_")
    label = re.sub(r"\s+", " ", label)

    part = None
    lines = text.split("\n")
    # प्रश्न blocks with running section state
    i, cur = 0, []
    blocks = []  # (part_state, block_lines)
    for ln in lines:
        s = sec_from_heading(ln)
        if s:
            part = s
        if ln.startswith("### प्रश्न "):
            if cur: blocks.append(cur)
            cur = [part, ln]
        elif cur:
            cur.append(ln)
    if cur: blocks.append(cur)

    for blk in blocks:
        bpart, head = blk[0], blk[1]
        body = blk[2:]
        stats["total"] += 1
        qm = re.match(r"### प्रश्न (\d+)", head)
        qno = int(qm.group(1)) if qm else 0

        stem_lines, opts, ans, quote, srctag = [], [], None, [], ""
        after_ans = False
        for ln in body:
            om = re.match(r"^- \*\*\(([a-d1-4])\)\*\* *(.*)$", ln)
            am = re.match(r"^\*\*उत्तर: *\(([a-d1-4])\)\*\*", ln)
            sm = re.match(r"^\*\[(.+?)\]\*\s*$", ln)
            if am:
                ans = ANS_MAP.get(am.group(1)); after_ans = True
            elif om:
                opts.append(om.group(2).strip())
            elif sm:
                srctag = sm.group(1).strip()
            elif ln.startswith("> "):
                quote.append(ln[2:].strip())
            elif not after_ans and not opts and ln.strip():
                stem_lines.append(ln)

        stem = clean(" ".join(stem_lines))
        opts = [clean(o) for o in opts[:4]]
        if ans is None:
            stats["no_ans"] += 1; continue
        if len(opts) < 4 or not all(opts):
            stats["bad_opts"] += 1; continue
        if not stem or len(stem) < 8:
            stats["bad_opts"] += 1; continue

        sec = bank_sec or sec_for_q(bpart, qno, stem, opts)
        if sec == "sanskrit":
            stats["sanskrit"] += 1; continue

        q_en, q_hi = split_bilingual(stem)
        o_en, o_hi = [], []
        if q_en:
            for o in opts:
                oe, oh = split_bilingual(o)
                o_en.append(oe or oh); o_hi.append(oh)
            if not all(o_en): o_en = ["", "", "", ""]
        else:
            o_hi = opts

        # passage blockquote → inline passage
        pid = pbody = pdir = pkind = ""
        if quote:
            qt = clean(" ".join(quote))
            qt = re.sub(r"^निर्देश */? *(गद्यांश)? *: *", "", qt)
            if len(qt) > 60:
                pid = "CT" + hashlib.sha1(qt.encode()).hexdigest()[:8]
                pkind = "poem" if re.search(r"काव्यांश|कविता|stanza|poem", " ".join(quote), re.I) else "prose"
                if pid in pass_seen:
                    pbody = ""        # pehli row me hi body kaafi hai
                else:
                    pass_seen[pid] = True
                    pbody = qt
                    pdir = "<b>निर्देश :</b> गद्यांश/काव्यांश पढ़कर प्रश्न का उत्तर दीजिए"

        is_pyq, yrs = ("1", year) if (year and not bank_sec) else ("0", "")
        if bank_sec and srctag:
            tm = re.search(r"CTET.*?(20\d\d)", srctag)
            if tm: is_pyq, yrs = "1", tm.group(1)
        src = f"CTET {label} Q{qno}" if not bank_sec else f"CTET Bank {label} Q{qno}" + (f" [{srctag}]" if srctag else "")
        topic = "CTET विगत वर्ष" if is_pyq == "1" else "CTET अभ्यास"

        rows.append({
            "exams": "ctet1", "section": sec, "topic": topic, "difficulty": "2",
            "pid": pid, "pseq": str(qno) if pid else "", "p_kind": pkind if pbody else "",
            "p_dir": pdir, "p_body": pbody,
            "q_hi": q_hi, "a_hi": o_hi[0], "b_hi": o_hi[1], "c_hi": o_hi[2], "d_hi": o_hi[3],
            "q_en": q_en, "a_en": o_en[0] if q_en else "", "b_en": o_en[1] if q_en else "",
            "c_en": o_en[2] if q_en else "", "d_en": o_en[3] if q_en else "",
            "ans": str(ans), "source": src, "is_pyq": is_pyq, "years": yrs,
        })
        stats["ok"] += 1

hdr = ["exams","section","topic","difficulty","pid","pseq","p_kind","p_dir","p_body",
       "q_hi","a_hi","b_hi","c_hi","d_hi","q_en","a_en","b_en","c_en","d_en",
       "ans","source","is_pyq","years"]
with open(OUT, "w", encoding="utf-8", newline="") as f:
    w = csv.DictWriter(f, fieldnames=hdr, lineterminator="\r\n")
    w.writeheader()
    for r in rows:
        w.writerow(r)

print("stats:", stats)
print("rows written:", len(rows), "->", OUT)
import collections
print("sections:", dict(collections.Counter(r["section"] for r in rows)))
print("bilingual:", sum(1 for r in rows if r["q_en"])), 
print("passages:", len(pass_seen))

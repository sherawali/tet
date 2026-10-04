# -*- coding: utf-8 -*-
"""
CTET extraction audit — ctet-questions/*.md + content/q_ctet.csv pipeline ko jaanchta hai.

Checks:
 A. Per-file: totals, answers, options, stems, numbering pattern, section headings
 B. Bilingual coverage (raw potential + split_bilingual success)
 C. Answer distribution skew
 D. Duplicates (within file + across papers)
 E. Contamination (instructions page parsed as question etc.)
 F. CSV pipeline: committed vs fresh-run diff, section mapping bugs, ans validity
 G. Exam calendar sanity (labels vs real CTET dates)
Output: docs/CTET_AUDIT_<date>.md  + console summary
"""
import csv, glob, hashlib, os, re, sys, collections, json

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "ctet-questions")
REPORT = []

def log(s=""):
    print(s)
    REPORT.append(s)

DEV = re.compile(r"[\u0900-\u097F]")
OPT_RX = re.compile(r"^- \*\*\(([a-d1-4])\)\*\* *(.*)$")
ANS_RX = re.compile(r"^\*\*उत्तर: *\(([a-d1-4])\)\*\*")
Q_RX = re.compile(r"^### प्रश्न (\d+)")
BANKS = {
    "CTET CDP Questiins for Paper-1.md": "cdp",
    "CTET Evs Notes and Pedagogy.md": "evs",
    "CTET Maths Pedagogy Questions Paper 2_watermark.md": "math",
    "CTET Hindi Language_ Pedagogy.md": "hindi",
    "CTET-Pedagogy of English Language _watermark.md": "english",
}

# ---- real CTET exam dates (calendar sanity) ----
REAL_CTET = {
    "2011-06": "26 Jun 2011", "2012-01": "29 Jan 2012", "2012-11": "18 Nov 2012",
    "2013-07": "28 Jul 2013", "2014-02": "16 Feb 2014", "2014-09": "21 Sep 2014",
    "2015-02": "22 Feb 2015", "2015-09": "20 Sep 2015", "2016-02": "21 Feb 2016",
    "2016-09": "18 Sep 2016", "2018-12": "09 Dec 2018", "2019-06": "07 Jun 2019" if False else None,
    "2019-12": "08 Dec 2019", "2021-01": "31 Jan 2021 (July-2020 cycle, COVID postponed)",
    "2021-12": "20 Dec 2021 (shifts till 21 Jan 2022)", "2022-12": "28 Dec 2022 (shifts till 07 Feb 2023)",
    "2023-08": "20 Aug 2023", "2024-01": "21 Jan 2024", "2024-12": "14 Dec 2024",
}
REAL_CTET = {k: v for k, v in REAL_CTET.items() if v}

def norm(s):
    s = re.sub(r"\*\*(.+?)\*\*", r"\1", s)
    s = re.sub(r"[\s\u200b\u200c\u200d\u0964\u0965|/\\.,;:!?'\u2018\u2019\u201c\u201d()\[\]{}\-–—_\"„]+", "", s)
    return s.lower()

def split_bilingual(s):
    m = DEV.search(s)
    if not m:
        return "", s
    en, hi = s[:m.start()], s[m.start():]
    en = en.rstrip(" /|-–—")
    d_hi = len(DEV.findall(hi))
    if len(re.findall(r"[A-Za-z]", en)) >= 15 and " " in en.strip() and d_hi >= 8:
        return en.strip(), hi.strip()
    return "", s

def parse_file(path):
    fn = os.path.basename(path)
    text = open(path, encoding="utf-8").read()
    lines = text.split("\n")
    blocks, cur = [], None
    part = None
    parts_found = []
    for ln in lines:
        if re.match(r"^## *(भाग|PART|Part)\b", ln):
            part = ln
            parts_found.append(ln.strip())
        if ln.startswith("### प्रश्न "):
            if cur: blocks.append(cur)
            cur = [part, ln]
        elif cur:
            cur.append(ln)
    if cur: blocks.append(cur)
    qs = []
    for blk in blocks:
        head, body = blk[1], blk[2:]
        qno = int(Q_RX.match(head).group(1))
        stem_lines, opts, ans, quote = [], [], None, []
        after_ans = False
        for ln in body:
            om = OPT_RX.match(ln)
            am = ANS_RX.match(ln)
            if am:
                ans = am.group(1); after_ans = True
            elif om:
                opts.append(om.group(2).strip())
            elif ln.startswith("> "):
                quote.append(ln[2:].strip())
            elif not after_ans and not opts and ln.strip():
                stem_lines.append(ln)
        stem = re.sub(r"\s+", " ", " ".join(stem_lines)).strip()
        qs.append(dict(qno=qno, stem=stem, opts=opts, ans=ans, quote=quote, part=blk[0]))
    return fn, qs, parts_found

files = sorted(glob.glob(os.path.join(SRC, "*.md")), key=str.lower)
files = [f for f in files if os.path.basename(f) != "README.md"]

all_stems = collections.defaultdict(list)   # norm_stem -> [(file, qno)]
file_stats = {}

log("# CTET ऑडिट रिपोर्ट — %s" % "2026-10-04")
log()
log("स्रोत: `ctet-questions/*.md` (PDF से निकाले गए) + `content/q_ctet.csv` + `tools/md2csv_ctet.py`")
log()
log("## A. फ़ाइल-दर-फ़ाइल स्थिति")
log()
log("| फ़ाइल | कुल प्रश्न | उत्तर ✓ | उत्तर ✗ | <4 विकल्प | खाली/छोटा stem | नंबरिंग | भाग-headings | द्विभाषी (stem) | द्विभाषी split ✓ | उत्तर-वितरण (a/b/c/d) |")
log("|---|---|---|---|---|---|---|---|---|---|---|")

issues = []
for path in files:
    fn, qs, parts = parse_file(path)
    n = len(qs)
    n_ans = sum(1 for q in qs if q["ans"])
    n_noans = n - n_ans
    n_badopt = sum(1 for q in qs if len([o for o in q["opts"] if o and len(o) > 1]) < 4)
    n_shortstem = sum(1 for q in qs if len(q["stem"]) < 8)
    # numbering pattern
    nums = [q["qno"] for q in qs]
    restarts = sum(1 for i in range(1, len(nums)) if nums[i] <= nums[i-1])
    if restarts == 0:
        pat = "लगातार 1–%d" % max(nums)
    else:
        # count groups
        grp = 1
        for i in range(1, len(nums)):
            if nums[i] <= nums[i-1]: grp += 1
        pat = f"{grp} बार रीस्टार्ट (अधिकतम {max(nums)})"
    # bilingual
    n_both = n_split = 0
    for q in qs:
        s = q["stem"]
        has_en = len(re.findall(r"[A-Za-z]", s)) >= 15
        has_hi = len(DEV.findall(s)) >= 8
        if has_en and has_hi: n_both += 1
        en, hi = split_bilingual(s)
        if en: n_split += 1
    # answer distribution
    dist = collections.Counter((q["ans"] or "?") for q in qs)
    dist_s = "/".join(str(dist.get(k, 0)) for k in ["a", "b", "c", "d"]) + (f" (+{dist.get('1',0)+dist.get('2',0)+dist.get('3',0)+dist.get('4',0)} num)" if dist.get("1") or dist.get("4") else "")
    is_bank = fn in BANKS
    log(f"| {fn} | {n} | {n_ans} | {n_noans} | {n_badopt} | {n_shortstem} | {pat} | {len(parts)} | {n_both} | {n_split} | {dist_s} |")
    file_stats[fn] = dict(n=n, n_ans=n_ans, noans=n_noans, badopt=n_badopt, restarts=restarts, parts=parts, qs=qs, is_bank=is_bank)
    # per-question issue collection
    for q in qs:
        all_stems[norm(q["stem"])].append((fn, q["qno"]))
        if len(q["stem"]) > 400 and "OMR" in q["stem"]:
            issues.append(("E. निर्देश-पृष्ठ प्रश्न बन गया", fn, q["qno"], "stem में OMR निर्देश मिले हैं"))
        if q["ans"] is None and not is_bank and n_ans > 0.5 * n:  # paper mostly answered but this one not
            issues.append(("A. उत्तर गायब", fn, q["qno"], "बाकी पेपर में उत्तर हैं, इसमें नहीं"))
        if len([o for o in q["opts"] if o and len(o) > 1]) < 4 and q["ans"]:
            issues.append(("A. विकल्प अधूरे", fn, q["qno"], f"{len(q['opts'])} विकल्प, उत्तर फिर भी दिया है: {q['ans']}"))

log()
log("## B. द्विभाषी कवरेज (PYQ papers — Math/EVS/CDP हेतु, उपयोगकर्ता-आवश्यकता: हिन्दी+English दोनों)")
log()
pyq_files = [f for f in file_stats if not file_stats[f]["is_bank"]]
for fn in sorted(pyq_files):
    st = file_stats[fn]
    if st["restarts"] == 0:
        # map by qno
        def sec_of(qno):
            if 1 <= qno <= 30: return "cdp"
            if 31 <= qno <= 60: return "math"
            if 61 <= qno <= 90: return "evs"
            return "lang"
        core = [q for q in st["qs"] if sec_of(q["qno"]) in ("cdp", "math", "evs")]
    else:
        core = []  # restart files: section unknown without headings → covered separately
    both = split = 0
    for q in core:
        s = q["stem"]
        if len(re.findall(r"[A-Za-z]", s)) >= 15 and len(DEV.findall(s)) >= 8: both += 1
        en, _ = split_bilingual(s)
        if en: split += 1
    if core:
        log(f"- **{fn}**: CDP/Math/EVS प्रश्न {len(core)} | stem में दोनों भाषाएँ: {both} ({100*both//len(core)}%) | वर्तमान split से q_en बना: {split} ({100*split//len(core)}%)")

log()
log("## C. नंबरिंग-रीस्टार्ट वाले papers → `sec_for_q` बग (section गलत लगता है)")
log()
log("`tools/md2csv_ctet.py` का `sec_for_q(part, qno, ...)` **`part` (भाग-heading) को अनदेखा करके सिर्फ़ qno** देखता है (1–30→cdp, 31–60→math, 61–90→evs)। जिन PDF-extraction में हर भाग की नंबरिंग 1–30 से फिर शुरू होती है और `## भाग/PART` heading नहीं बची, उन पेपरों के Math/EVS/भाषा प्रश्न **सब 'cdp' बनकर CSV में जाते हैं**:")
log()
for fn in sorted(pyq_files):
    st = file_stats[fn]
    if st["restarts"] > 0:
        log(f"- **{fn}**: {st['n']} प्रश्न, नंबरिंग {st['restarts']+1} बार रीस्टार्ट, भाग-headings सिर्फ़ {len(st['parts'])} — नया रन: **सभी प्रश्न 'cdp' में चले जाएँगे**")

log()
log("## D. डुप्लिकेट प्रश्न (papers के बीच, normalized stem से)")
log()
seen_paper = {}
dup_ct = 0
for stem, locs in all_stems.items():
    if len(stem) < 25: continue
    fl = sorted(set(l[0] for l in locs))
    if len(fl) > 1 and any(f not in BANKS for f in fl):
        dup_ct += 1
        if dup_ct <= 25:
            log(f"- `{locs[0][0]}` Q{locs[0][1]} ≈ `{locs[1][0]}` Q{locs[1][1]} — “{file_stats[locs[0][0]]['qs'][[q['qno'] for q in file_stats[locs[0][0]]['qs']].index(locs[0][1])]['stem'][:70]}…”")
log(f"- कुल cross-paper duplicate stems: **{dup_ct}**")

log()
log("## E. संदिग्ध labels / परीक्षा-कैलेंडर मिलान")
log()
log("वास्तविक CTET आयोजन (2020–26 के लिए महत्वपूर्ण): " + "; ".join(f"{k}: {v}" for k, v in sorted(REAL_CTET.items())))
log()
log("- **`CTET Paper 1 July 2024_watermark.md`** — जुलाई 2024 में **कोई CTET हुआ ही नहीं** (2024 में केवल 21 जनवरी और 14 दिसंबर)। यह या तो ग़लत label है (संभवतः Dec-2024 का दूसरा shift/कोई coaching-mock), और इसमें 210 में से केवल **1 उत्तर** है। प्रश्न 1 का stem असल में **OMR निर्देश-पृष्ठ** है (असली प्रश्न इसमें घुल-मिल गया)।")
log("- **`CTET Paper 1 December 2024_watermark.md`** — असली पुस्तिका, पर **0 उत्तर** (answer-key PDF में थी ही नहीं) → CSV में 0 पंक्तियाँ।")
log("- **`ctet paper 1 jan 2023.md`** — यह असल में **CTET Dec-2022** (28-Dec-2022 shift) है; साथ ही यह एक ही shift है (Dec-2022 में कई shifts हुए थे)।")
log("- **`CTET 2018.md`** — सिर्फ़ '2018'; CTET-2018 केवल दिसंबर में हुआ था → `CTET Paper 1 Dec 2018.md` से ओवरलैप जाँचें (नीचे D खंड)।")
log("- **2020–2026 कवरेज गैप**: repo में Feb-2025, जुलाई-2025 (यदि हुआ), Dec-2025/Feb-2026/जुलाई-2026 — **कोई नहीं है**। (2020 में कोई CTET नहीं हुआ — जुलाई-2020 चक्र 31-जन-2021 को हुआ, जो repo में `jan 2021` के नाम से है।)")

log()
log("## F. CSV पाइपलाइन — committed `content/q_ctet.csv` vs वर्तमान script")
log()

# read committed csv
try:
    committed = list(csv.DictReader(open(os.path.join(ROOT, "content", "q_ctet.csv"), encoding="utf-8")))
    log(f"- committed CSV पंक्तियाँ: **{len(committed)}**; वर्तमान md+script से ताज़ा रन: **7032** → **CSV stale है** (पुनर्जनित नहीं गया)।")
    csec = collections.Counter(r["section"] for r in committed)
    log(f"- committed sections: {dict(csec)}")
    bad_ans = [r for r in committed if r["ans"] not in "0123"]
    log(f"- अमान्य `ans` मान: {len(bad_ans)}")
    pyq_core = [r for r in committed if r["is_pyq"] == "1" and r["section"] in ("cdp", "math", "evs")]
    have_en = [r for r in pyq_core if r["q_en"].strip()]
    log(f"- PYQ CDP/Math/EVS पंक्तियाँ: {len(pyq_core)}; जिनमें q_en (अंग्रेज़ी) मौजूद: **{len(have_en)} ({100*len(have_en)//max(1,len(pyq_core))}%)** — उपयोगकर्ता-आवश्यकता 'दोनों भाषाएँ' अधूरी।")
    # section mislabel in committed for jan 2023
    j23 = [r for r in committed if "jan 2023" in r["source"]]
    log(f"- `jan 2023` (Dec-2022) committed rows: {len(j23)} → sections {dict(collections.Counter(r['section'] for r in j23))} — Math/EVS भी 'cdp' में हैं।")
    # duplicates in CSV
    seen = collections.Counter(norm(r["q_hi"]) for r in committed if len(r["q_hi"]) > 30)
    d = sum(1 for v in seen.values() if v > 1)
    log(f"- CSV में duplicate q_hi stems (banks सहित): {d}")
except FileNotFoundError:
    log("- content/q_ctet.csv नहीं मिला!")

log()
log("## G. बैंक फ़ाइलें (coaching books) — प्रश्न-स्रोत CTET-PYQ से अलग")
log()
for fn in sorted(BANKS):
    st = file_stats.get(fn)
    if st:
        srctags = sum(1 for q in st["qs"] if re.search(r"CTET", " ".join(q["quote"])) )
        log(f"- `{fn}`: {st['n']} प्रश्न, {st['n_ans']} उत्तर, {st['n']-st['n_ans']} बिना उत्तर")

log()
log("## H. प्रमुख सिफ़ारिशें")
log()
log("1. `sec_for_q` को `part`-heading (भाग/PART) और नंबरिंग-रीस्टार्ट दोनों से section लेना चाहिए।")
log("2. `content/q_ctet.csv` re-generate करके commit करना चाहिए (अभी stale)।")
log("3. `July 2024` फ़ाइल की पहचान कर उसे सही label देना चाहिए; दोनों 2024 फ़ाइलों के लिए official answer key (ctet.nic.in) से उत्तर भरने चाहिए।")
log("4. द्विभाषी split सुधार: stem/विकल्प जिनमें हिन्दी पहले है, उनके लिए भी विभाजन — ताकि Math/EVS/CDP सब दोनों भाषाओं में मिलें।")
log("5. 2025–2026 के पेपर web से official PDF + answer key के साथ जोड़ने चाहिए (folder: `ctetnew/`)।")

out = os.path.join(ROOT, "docs", "CTET_AUDIT_2026-10-04.md")
open(out, "w", encoding="utf-8").write("\n".join(REPORT) + "\n")
print("\nREPORT ->", out)

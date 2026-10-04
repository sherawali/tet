# -*- coding: utf-8 -*-
"""
ctetnew/ builder — Phase 1: 2021–2024 papers (repo md extractions + OFFICIAL final keys)

Har exam ke liye:
  ctetnew/<exam>/paper1.json   — structured (bilingual Q, options, official ans, explanation)
  ctetnew/<exam>/paper1.md     — human-readable bilingual
+ ctetnew/all_questions.csv    — repo q_ctet.csv schema me sab
+ ctetnew/_build_report.json   — kya-kya mila/fix kiya

Answers: official final key (ctet.nic.in) — authoritative.
Dropped questions (key=9) aur combo-answers (A..F/Z legend) note kiye jaate hain.
"""
import csv, json, os, re, collections

KEYS = json.load(open("ctetnew/_sources/keys_parsed.json", encoding="utf-8"))
SRC = "ctet-questions"
OUTROOT = "ctetnew"

DEV = re.compile(r"[\u0900-\u097F]")
ANS_MAP = {"a": 0, "b": 1, "c": 2, "d": 3, "1": 0, "2": 1, "3": 2, "4": 3}

SKT_WORDS = re.compile(r"(अस्ति|भवति|सन्ति|भवन्ति|कुरुत|अस्मिन्|तेषां|अधोलिखित\S*|उदाहरणानुसार\S*|इति|एव|किम्|कथम्|कुत्र|अहम्|वयम्|कथनम्|वाक्यम्|पदम्)")
def sanskrit_score(t):
    sc = 0
    sc += 2 * len(re.findall(r"[क-ह]्?[ा-ौ]?[:ः](?=[\s,।!?)\-]|$)", t))
    sc += 2 * len(re.findall(r"[क-ह]्?[ा-ौ]?म्(?=[\s,।!?)\-]|$)", t))
    sc += len(SKT_WORDS.findall(t))
    return sc

def clean(s):
    s = re.sub(r"\*\*(.+?)\*\*", r"\1", s)
    return re.sub(r"\s+", " ", s).strip()

def split_bilingual(s):
    """'English हिन्दी' → (en, hi); 'हिन्दी English' → (en, hi); warna ('', s)."""
    m = DEV.search(s)
    if not m:
        return "", s
    en, hi = s[:m.start()].rstrip(" /|-–—"), s[m.start():]
    if len(re.findall(r"[A-Za-z]", en)) >= 12 and " " in en.strip() and len(DEV.findall(hi)) >= 6:
        return en.strip(), hi.strip()
    # Hindi-first: Devanagari ... phir English?
    lm = None
    for m2 in re.finditer(r"[A-Za-z][A-Za-z ,''\"-]{25,}", s):
        lm = m2
        break
    if lm and lm.start() > 10:
        hi_part = s[:lm.start()].rstrip(" /|-–—")
        en_part = s[lm.start():]
        if len(DEV.findall(hi_part)) >= 8 and len(re.findall(r"[A-Za-z]", en_part)) >= 15:
            return en_part.strip(), hi_part.strip()
    return "", s

def parse_md(path):
    text = open(path, encoding="utf-8").read()
    blocks, cur = [], None
    for ln in text.split("\n"):
        if ln.startswith("### प्रश्न "):
            if cur: blocks.append(cur)
            cur = [ln]
        elif cur: cur.append(ln)
    if cur: blocks.append(cur)
    qs = []
    for b in blocks:
        qno = int(re.match(r"### प्रश्न (\d+)", b[0]).group(1))
        stem, opts, ans, expl = [], [], None, []
        after_ans = False
        for l in b[1:]:
            am = re.match(r"^\*\*उत्तर: *\(([a-d1-4])\)\*\*", l)
            om = re.match(r"^- \*\*\(([a-d1-4])\)\*\* *(.*)$", l)
            if am and ans is None:
                ans = ANS_MAP.get(am.group(1)); after_ans = True
            elif om:
                opts.append(clean(om.group(2)))
            elif l.startswith("> "):
                pass  # passage (language sections) — alag se handle
            elif after_ans and l.strip():
                expl.append(l.strip())
            elif not opts and l.strip():
                stem.append(l)
        qs.append(dict(qno=qno, stem=clean(" ".join(stem)), opts=opts, ans=ans,
                       expl=clean(" ".join(expl))))
    return qs

def runs_of(qs):
    """blocks ko runs me todo (numbering restart)."""
    out, cur, prev = [], [], None
    for q in qs:
        if prev is not None and q["qno"] <= prev:
            out.append(cur); cur = []
        cur.append(q); prev = q["qno"]
    out.append(cur)
    return out

def lang_of(run):
    txt = " ".join(q["stem"] + " " + " ".join(q["opts"]) for q in run)
    d = len(DEV.findall(txt)); l = len(re.findall(r"[A-Za-z]", txt))
    skt = sum(sanskrit_score(q["stem"]) for q in run) / max(1, len(run))
    if skt >= 3.0 and d > l:
        return "sanskrit"
    if d > l * 2:
        return "hindi"
    if l > d * 2:
        return "english"
    return "bilingual"

# ---------------------------------------------------------------- exams spec
# layout: base run me 1-90 cdp/math/evs. Language runs hote hain:
#   'base' = pehli run (1-120/1-150), baaki runs extra language versions
EXAMS = [
    dict(id="2021-01", name="CTET January 2021 (Paper 1)", date="31/01/2021",
         md="CTET Paper 1 jan 2021.md", kexam="jan2021_p1", kset="K",
         note="July-2020 cycle COVID-postponed; Set K"),
    dict(id="2021-12", name="CTET December 2021 (Paper 1)", date="31/12/2021",
         md="CTET Paper 1 dec 2021.md", kexam="dec2021_p1_final_key_en", kset="31/12/2021",
         note="Dec-2021 cycle (shifts Dec-2021–Jan-2022); booklet of 31-Dec-2021"),
    dict(id="2022-12", name="CTET December 2022 (Paper 1)", date="13/01/2023",
         md="ctet paper 1 jan 2023.md", kexam="dec2022", kset="13/01/2023",
         note="Dec-2022 cycle (shifts Dec-2022–Feb-2023); booklet of 13-Jan-2023 (Paper 1)",
         restart_layout=True),
    dict(id="2023-08", name="CTET August 2023 (Paper 1)", date="20/08/2023",
         md="ctet paper 1 aug 2023.md", kexam="aug2023_p1", kset="D",
         note="Set D"),
    dict(id="2024-01", name="CTET January 2024 (Paper 1)", date="21/01/2024",
         md="ctet paper 1 jan 2024.md", kexam="jan2024_p1", kset="I",  # set-I: 90/90 perfect match
         note="Set (auto-detect)"),
    dict(id="2024-07", name="CTET July 2024 (Paper 1)", date="07/07/2024",
         md="CTET Paper 1 July 2024_watermark.md", kexam="july2024_p1", kset="A",
         note="Booklet code A"),
    dict(id="2024-12", name="CTET December 2024 (Paper 1)", date="14/12/2024",
         md="CTET Paper 1 December 2024_watermark.md", kexam="dec2024_p1", kset="H",
         note="Booklet code H"),
]

SECTION_OF = lambda qno: ("cdp" if qno <= 30 else "math" if qno <= 60 else "evs" if qno <= 90 else None)

def resolve_combo(stem, opts, combo):
    """combo '1,2'/'2,4'/'ALL' — options me '1 and 2' jaisa option dhoondo."""
    if combo in ("1,2", "1,3", "1,4", "2,3", "2,4", "3,4"):
        want = combo.split(",")
        for i, o in enumerate(opts):
            digits = re.findall(r"\b([1-4])\b", o)
            if len(set(digits) & set(want)) == 2 and len(digits) <= 3:
                return i
    return None

def build_exam(ex):
    qs = parse_md(os.path.join(SRC, ex["md"]))
    runs = runs_of(qs)
    key = KEYS[ex["kexam"]][ex["kset"]] if ex["kset"] else None

    # ---- core 1-90
    if ex.get("restart_layout"):
        # 5 runs × 30: cdp, math, evs, lang1, lang2
        core = []
        for ri, r in enumerate(runs[:3]):
            for i, q in enumerate(r):
                q = dict(q)
                q["official_qno"] = ri * 30 + i + 1
                core.append(q)
        lang_runs = runs[3:]
    else:
        core = []
        for q in qs:
            if 1 <= q["qno"] <= 90:
                q = dict(q); q["official_qno"] = q["qno"]
                core.append(q)
        lang_runs = [r for r in runs[1:]] if len(runs) > 1 else []

    # ---- language chunks: har run ke 91-120 / 121-150 hisse alag classify karo
    chunks = []            # (lo, hi, kind, [q...])
    for ri, r in enumerate(runs):
        if ex.get("restart_layout") and ri < 3:
            continue        # restart layout: pehli 3 runs = core (cdp/math/evs)
        groups = collections.defaultdict(list)
        for q in r:
            if ex.get("restart_layout"):
                groups[0 if ri == 3 else 1].append(q)
            else:
                if 91 <= q["qno"] <= 120:
                    groups[0].append(q)
                elif 121 <= q["qno"] <= 150:
                    groups[1].append(q)
        for rng, blk in groups.items():
            if not blk:
                continue
            txt = " ".join(q["stem"] + " " + " ".join(q["opts"]) for q in blk)
            d = len(DEV.findall(txt)); l = len(re.findall(r"[A-Za-z]", txt))
            skt = sum(sanskrit_score(q["stem"]) for q in blk) / len(blk)
            kind = ("sanskrit" if skt >= 3.0 and d > l else
                    "hindi" if d > l else "english")
            lo, hi = (91, 120) if rng == 0 else (121, 150)
            chunks.append((lo, hi, kind, blk))

    def take_lang(start, end, kind):
        best = None
        for lo, hi, k, blk in chunks:
            if lo == start and hi == end and k == kind:
                if best is None or len(blk) > len(best[3]):
                    best = (lo, hi, k, blk)
        if not best:
            return []
        blk = best[3]
        return [(start + i, q, kind) for i, q in enumerate(blk)]

    out_questions = []
    report = collections.Counter()
    flags = []

    for q in core:
        oq = q["official_qno"]
        sec = SECTION_OF(oq)
        kans = key["main"].get(str(oq)) if key else None
        book_ans = q["ans"]
        ans, ans_note, ans_accepted = None, "", None
        if kans is None:
            ans, ans_note = None, "प्रश्न निरस्त — सभी को अंक (official key: 9)"
        elif isinstance(kans, str) and kans in ("1,2", "1,3", "1,4", "2,3", "2,4", "3,4"):
            acc = [int(x) - 1 for x in kans.split(",")]
            ans = acc[0]
            ans_accepted = acc
            ans_note = f"अधिकारिक key: विकल्प {' व '.join(str(a+1) for a in acc)} दोनों मान्य"
        elif isinstance(kans, str) and kans == "ALL":
            ans, ans_note = None, "अधिकारिक key: सभी विकल्प मान्य (Z=ALL) — सभी को अंक"
        else:
            ans = int(kans)
        if book_ans is not None and ans is not None and book_ans != ans:
            report["book_vs_official_mismatch"] += 1
            flags.append(f"Q{oq}: book={book_ans+1} official={ans+1}")
        q_en, q_hi = split_bilingual(q["stem"])
        o_en, o_hi = [], []
        for o in q["opts"][:4]:
            oe, oh = split_bilingual(o)
            o_en.append(oe if oe else oh)
            o_hi.append(oh)
        if q_en and len(o_en) == 4 and not all(o_en):
            o_en = ["", "", "", ""]
        out_questions.append(dict(
            qno=oq, section=sec,
            q_en=q_en, q_hi=q_hi if q_hi else q["stem"],
            options_en=o_en if q_en else [], options_hi=o_hi,
            ans=ans, ans_note=ans_note, ans_accepted=ans_accepted,
            book_ans=book_ans,
            explanation=q["expl"] if q["expl"] else "",
            n_opts=len(q["opts"]),
        ))
        if not q["stem"] or len(q["stem"]) < 8:
            report["broken_stem"] += 1
            flags.append(f"Q{oq}: stem damaged ('{q['stem'][:30]}')")
        if len(q["opts"]) < 4:
            report["bad_opts"] += 1
            flags.append(f"Q{oq}: sirf {len(q['opts'])} विकल्प")

    # ---- language sections (Hindi Lang-I 91-120, English Lang-II 121-150)
    lang_out = []
    for label, start, end, kind, keylang in [
        ("lang1_hindi", 91, 120, "hindi", "HINDI"),
        ("lang2_english", 121, 150, "english", "ENGLISH"),
    ]:
        blocks = take_lang(start, end, kind)
        for n, q, _ in sorted(blocks, key=lambda t: t[0]):
            kq = key["langs"].get(keylang, {}).get(str(n)) if key else None
            ans = int(kq) if kq is not None and str(kq).isdigit() else None
            lang_out.append(dict(qno=n, section=label, q_en=q["stem"], q_hi="",
                                 options_en=q["opts"], options_hi=[],
                                 ans=ans, ans_note="", book_ans=q["ans"], explanation=q["expl"],
                                 n_opts=len(q["opts"])))
            if ans is None and kq is not None:
                lang_out[-1]["ans_note"] = f"key={kq}"

    return out_questions, lang_out, report, flags

# ------------------------------------------------------------- manual repairs
# Raw PDF-extraction me kuch questions toote the. Ye overrides final built question par
# lagte hain (source: official paper / testbook-verified options — _build_report me note).
REPAIRS = {
    ("2021-01", 71): dict(
        q_hi="आपका घर X पर स्थित है तथा आपका विद्यालय Y पर स्थित है। यद्यपि आपका विद्यालय ठीक सामने है परन्तु बीच में व्यस्त राजमार्ग होने के कारण आप सीधे नहीं जा सकते हैं। अतः पहले आप ठीक दक्षिण में 125 m दूर जाते हैं, फिर ठीक पूर्व में 100 m लम्बा सुरंग पथ पार करते हैं और अन्त में आप ठीक उत्तर में 125 m दूरी पर Y पर अपने विद्यालय पहुँचते हैं। Y पर विद्यालय के सापेक्ष X पर आपका घर कहाँ स्थित है?",
        q_en="Your house is located at X and your school is located at Y. Although your school is just opposite but you cannot go straight because of the busy highway in between. So, you first go 125 m due south, then cross a 100 m long subway which is due east and finally reach your school at Y which is 125 m due north. With respect to school at Y, your house at X is :",
        options_hi=["100 m ठीक पश्चिम", "125 m ठीक उत्तर", "125 m ठीक दक्षिण", "100 m ठीक पूर्व"],
        options_en=["100 m due west", "125 m due north", "125 m due south", "100 m due east"],
        explanation="घर X से 125 m दक्षिण, फिर 100 m पूर्व, फिर 125 m उत्तर चलने पर विद्यालय Y, घर से 100 m पूर्व में है। अतः विद्यालय के सापेक्ष घर 100 m पश्चिम में है।",
        repair_note="options raw text me stem/explanation me inline the; official Set-K key se ans (a) सत्यापित",
    ),
    ("2022-12", 44): dict(
        q_hi="प्रथम दस विषम अभाज्य संख्याओं का माध्य है :",
        q_en="The mean of first ten odd prime numbers is :",
        options_hi=["12.9", "15.8", "17.8", "16.8"],
        options_en=["12.9", "15.8", "17.8", "16.8"],
        explanation="प्रथम 10 विषम अभाज्य संख्याएँ: 3, 5, 7, 11, 13, 17, 19, 23, 29, 31 → योग = 158 → माध्य = 158/10 = 15.8",
        repair_note="options extraction me toote the; official key (13-Jan-2023) ans (b)=15.8 सत्यापित",
    ),
    ("2022-12", 45): dict(
        q_hi="गणित के एक टेस्ट में 30 विद्यार्थियों द्वारा प्राप्त किए गए अंक नीचे दिए गए हैं : 7, 1, 3, 6, 5, 5, 5, 0, 7, 8, 1, 9, 0, 5, 8, 3, 1, 8, 10, 10, 4, 3, 8, 6, 8, 9, 2, 1, 0, 4 । 5 से अधिक या उसके बराबर अंक प्राप्त करने वाले विद्यार्थियों की संख्या है :",
        q_en="The marks obtained by 30 students in a mathematics test are as shown below : 7, 1, 3, 6, 5, 5, 5, 0, 7, 8, 1, 9, 0, 5, 8, 3, 1, 8, 10, 10, 4, 3, 8, 6, 8, 9, 2, 1, 0, 4. The number of students obtaining more than or equal to 5 marks is :",
        options_hi=["17", "16", "15", "13"],
        options_en=["17", "16", "15", "13"],
        explanation="आरोही क्रम: 0,0,0,1,1,1,1,2,3,3,3,4,4,5,5,5,5,6,6,7,7,8,8,8,8,8,9,9,10,10 → 5 या अधिक अंक वाले = 17 विद्यार्थी।",
        repair_note="stem extraction me kho gaya tha (block-shift); book ke explanation se पुनर्निर्मित; official key ans (a)=17 सत्यापित",
    ),
}

def apply_repairs(ex, questions, flags, rep):
    did = []
    for q in questions:
        r_ = REPAIRS.get((ex["id"], q["qno"]))
        if not r_:
            continue
        q.update({k: v for k, v in r_.items() if k != "repair_note"})
        q["n_opts"] = len(q["options_hi"])
        q["book_ans"] = None
        q["ans_note"] = (q.get("ans_note") or "") + " | repair: " + r_["repair_note"]
        did.append(q["qno"])
    if did:
        flags[:] = [f for f in flags if not any(f.startswith(f"Q{n}:") for n in did)]
        rep["repaired_manually"] = len(did)
        for n in did:
            for k in ("bad_opts", "broken_stem", "book_vs_official_mismatch"):
                if rep.get(k):
                    rep[k] -= 1
    return did


# ------------------------------------------------------------------ outputs
CSV_HDR = ["exams", "section", "topic", "difficulty", "pid", "pseq", "p_kind", "p_dir", "p_body",
           "q_hi", "a_hi", "b_hi", "c_hi", "d_hi", "q_en", "a_en", "b_en", "c_en", "d_en",
           "ans", "source", "is_pyq", "years"]

all_rows = []
master_report = {}
for ex in EXAMS:
    core, langs, rep, flags = build_exam(ex)
    repaired = apply_repairs(ex, core + langs, flags, rep)
    d = os.path.join(OUTROOT, ex["id"])
    os.makedirs(d, exist_ok=True)
    meta = dict(id=ex["id"], name=ex["name"], exam_date=ex["date"], paper="1",
                booklet_set=ex["kset"], note=ex["note"],
                answer_source="CBSE official final answer key (ctet.nic.in)",
                question_source=f"ctet-questions/{ex['md']} (PDF extraction, verified vs official key)",
                n_cdp=len([q for q in core if q["section"] == "cdp"]),
                n_math=len([q for q in core if q["section"] == "math"]),
                n_evs=len([q for q in core if q["section"] == "evs"]),
                n_lang=len(langs), flags=flags)
    with open(os.path.join(d, "paper1.json"), "w", encoding="utf-8") as f:
        json.dump(dict(meta=meta, questions=core + langs), f, ensure_ascii=False, indent=1)

    # markdown
    md = [f"# {ex['name']}", "",
          f"- **परीक्षा तिथि:** {ex['date']}  |  **Booklet/Set:** {ex['kset']}  |  {ex['note']}",
          "- **उत्तर:** CBSE अधिकारिक final answer key (ctet.nic.in) से",
          f"- प्रश्न: CDP {meta['n_cdp']} + Math {meta['n_math']} + EVS {meta['n_evs']} + भाषा {meta['n_lang']}",
          ""]
    secnames = {"cdp": "PART I — बाल विकास व शिक्षाशास्त्र / Child Development & Pedagogy (Q1–30)",
                "math": "PART II — गणित / Mathematics (Q31–60)",
                "evs": "PART III — पर्यावरण अध्ययन / Environmental Studies (Q61–90)",
                "lang1_hindi": "PART IV — भाषा-I हिन्दी (Q91–120)",
                "lang2_english": "PART V — भाषा-II अंग्रेज़ी (Q121–150)"}
    cur = None
    for q in core + langs:
        if q["section"] != cur:
            cur = q["section"]
            md += ["", "## " + secnames.get(cur, cur), ""]
        md.append(f"### प्रश्न {q['qno']}")
        md.append("")
        if q["q_en"] and q["q_hi"] and q["q_en"] != q["q_hi"]:
            md.append(f"**EN:** {q['q_en']}")
            md.append("")
            md.append(f"**HI:** {q['q_hi']}")
        else:
            md.append(q["q_hi"] or q["q_en"])
        md.append("")
        if q["options_hi"] and q["options_en"] and any(q["options_en"]):
            for i, (oh, oe) in enumerate(zip(q["options_hi"], q["options_en"])):
                md.append(f"- **({i+1})** {oh}")
                md.append(f"  - *EN:* {oe}")
        else:
            opts = q["options_hi"] or q["options_en"]
            for i, o in enumerate(opts):
                md.append(f"- **({i+1})** {o}")
        md.append("")
        if q["ans"] is not None:
            md.append(f"**उत्तर: ({q['ans']+1})**" + (f" — {q['ans_note']}" if q["ans_note"] else ""))
        else:
            md.append(f"**उत्तर: —** ({q['ans_note'] or 'unknown'})")
        if q.get("book_ans") is not None and q["ans"] is not None and q["book_ans"] != q["ans"]:
            md.append(f"> ⚠️ स्रोत-पुस्तक का उत्तर ({q['book_ans']+1}) अधिकारिक key से भिन्न था — अधिकारिक ही रखा गया।")
        if q.get("explanation"):
            md.append("")
            md.append(f"**व्याख्या:** {q['explanation'][:1200]}")
        md.append("")
    open(os.path.join(d, "paper1.md"), "w", encoding="utf-8").write("\n".join(md))

    # CSV rows (repo schema)
    for q in core + langs:
        sec = q["section"]
        if sec == "lang1_hindi": sec = "hindi"
        if sec == "lang2_english": sec = "english"
        o_hi = (q["options_hi"] + [""] * 4)[:4]
        o_en = (q["options_en"] + [""] * 4)[:4] if any(q["options_en"]) else ["", "", "", ""]
        all_rows.append({
            "exams": "ctet1", "section": sec, "topic": "CTET विगत वर्ष", "difficulty": "2",
            "pid": "", "pseq": str(q["qno"]), "p_kind": "", "p_dir": "", "p_body": "",
            "q_hi": q["q_hi"] or q["q_en"], "a_hi": o_hi[0], "b_hi": o_hi[1], "c_hi": o_hi[2], "d_hi": o_hi[3],
            "q_en": q["q_en"] if q["q_en"] != q["q_hi"] else "", "a_en": o_en[0], "b_en": o_en[1],
            "c_en": o_en[2], "d_en": o_en[3],
            "ans": str(q["ans"]) if q["ans"] is not None else "",
            "source": f"CTET {ex['id']} Q{q['qno']}", "is_pyq": "1", "years": ex["id"],
        })

    master_report[ex["id"]] = dict(meta=meta, report=dict(rep), flags=flags)
    print(f"[{ex['id']}] core={len(core)} lang={len(langs)} {dict(rep)}")
    for fl in flags[:10]:
        print("   ⚠", fl)

os.makedirs(OUTROOT, exist_ok=True)
with open(os.path.join(OUTROOT, "all_questions.csv"), "w", encoding="utf-8", newline="") as f:
    w = csv.DictWriter(f, fieldnames=CSV_HDR, lineterminator="\r\n")
    w.writeheader()
    for r in all_rows:
        if r["ans"] != "":      # ans unknown wale CSV me nahi (app requirement)
            w.writerow(r)
with open(os.path.join(OUTROOT, "_build_report.json"), "w", encoding="utf-8") as f:
    json.dump(master_report, f, ensure_ascii=False, indent=1)
print("total csv rows:", sum(1 for r in all_rows if r["ans"] != ""))

# -*- coding: utf-8 -*-
"""
Repo ke CTET md-extractions ko official final keys se match karta hai:
- kaunsa booklet-set/paper hai (answer-pattern correlation se)
- extracted answers kitne sahi hain (official key vs md answers)
Output: ctetnew/_sources/set_matches.json + console report
"""
import json, os, re, collections

KEYS = json.load(open("ctetnew/_sources/keys_parsed.json", encoding="utf-8"))
SRC = "ctet-questions"

ANS_MAP = {"a": 0, "b": 1, "c": 2, "d": 3, "1": 0, "2": 1, "3": 2, "4": 3}

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
        ans = None
        opts = []
        stem = []
        for l in b[1:]:
            am = re.match(r"^\*\*उत्तर: *\(([a-d1-4])\)\*\*", l)
            om = re.match(r"^- \*\*\(([a-d1-4])\)\*\* *(.*)$", l)
            if am and ans is None:
                ans = ANS_MAP.get(am.group(1))
            elif om:
                opts.append(om.group(2).strip())
            elif not opts and l.strip() and ans is None:
                stem.append(l)
        qs.append(dict(qno=qno, ans=ans, opts=opts, stem=" ".join(stem).strip()))
    return qs

def core_answers(qs, mode):
    """repo question-block list → {official_qno: ans} sirf 1-90 ke liye.
    mode: 'continuous' (Q1-90 seedhe) | 'restart' (5×30 blocks: 1-30 cdp,31-60 math,61-90 evs)"""
    out = {}
    if mode == "continuous":
        for q in qs:
            if 1 <= q["qno"] <= 90 and q["ans"] is not None:
                out[q["qno"]] = q["ans"]
    else:
        for i, q in enumerate(qs[:90]):
            if q["ans"] is not None:
                out[i + 1] = q["ans"]
    return out

PAPERS = [
    # (md file, key exam in keys_parsed, candidate sets ya date, mode, known set)
    ("CTET Paper 1 jan 2021.md", "jan2021_p1", ["I", "J", "K", "L", "Q", "R", "S", "T"], "continuous", None),
    ("CTET Paper 1 dec 2021.md", "dec2021_p1_final_key_en", ["31/12/2021"], "continuous", None),
    ("ctet paper 1 jan 2023.md", "dec2022", ["13/01/2023"], "restart", None),
    ("ctet paper 1 aug 2023.md", "aug2023_p1", ["A", "B", "C", "D"], "continuous", None),
    ("ctet paper 1 jan 2024.md", "jan2024_p1", ["I", "J", "K", "L"], "continuous", None),
    ("CTET Paper 1 July 2024_watermark.md", "july2024_p1", ["A", "B", "C", "D"], "continuous", "A"),
    ("CTET Paper 1 December 2024_watermark.md", "dec2024_p1", ["H", "I", "J", "K"], "continuous", "H"),
]

report = {}
for fn, kexam, cands, mode, known in PAPERS:
    qs = parse_md(os.path.join(SRC, fn))
    mine = core_answers(qs, mode)
    best, best_rate, detail = None, -1, {}
    rates = {}
    for cand in cands:
        key = KEYS.get(kexam, {}).get(cand)
        if not key or not key["main"]:
            rates[cand] = None
            continue
        agree = disagree = na = 0
        for qno, my_ans in sorted(mine.items()):
            k = key["main"].get(str(qno), key["main"].get(qno))
            if k is None or (isinstance(k, str) and ("," in k or k == "ALL")):
                na += 1
            elif int(k) == my_ans:
                agree += 1
            else:
                disagree += 1
                detail.setdefault(cand, []).append((qno, my_ans, k))
        tot = agree + disagree
        rate = agree / tot if tot else 0
        rates[cand] = round(rate, 3)
        if rate > best_rate:
            best, best_rate = cand, rate
    match = known or (best if best_rate and best_rate > 0.7 else None)
    report[fn] = dict(key_exam=kexam, rates=rates, matched_set=match, match_rate=rates.get(match),
                      n_answered=len(mine), mismatches=detail.get(match, [])[:40])
    print(f"\n== {fn}")
    print(f"   candidates: {rates}")
    print(f"   → matched set: {match} (rate={rates.get(match)}) | answered={len(mine)} | mismatches={len(detail.get(match, []))}")
    if detail.get(match):
        print("   mismatches (qno, md_ans, official):", detail[match][:25])

with open("ctetnew/_sources/set_matches.json", "w", encoding="utf-8") as f:
    json.dump(report, f, ensure_ascii=False, indent=1)
print("\n→ ctetnew/_sources/set_matches.json")

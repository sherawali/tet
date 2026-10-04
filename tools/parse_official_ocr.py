# -*- coding: utf-8 -*-
"""
Official Eng+Hin booklet OCR → questions (parser v3 — run-anchors + quad-pairs).

Design:
  1. line-start numbers `^N.` se INCREASING RUNS banao (len>=15): [1-90],[91-120],[91-120],[121-150],[121-150]
     → sections canonical order me: core, lang1_en, lang1_hi, lang2_en, lang2_hi
  2. har number ke beech ka block: usme jitne (en,hi) option-quad PAIRS hain, utne questions
     (batched numbers / missed numbers self-heal ho jaate hain)
  3. block ke andar: [EN stem] (1..4) [HI stem] (1..4) — Devanagari-line splits se alag

Output: ctetnew/_sources/ocr_parsed.json + ocr_parse_report.json
"""
import json, os, re

SRC = "ctetnew/_sources/qps"
DEV = re.compile(r"[\u0900-\u097F]")
LAT = re.compile(r"[A-Za-z]")

PAPERS = {
    "2026-02-07": dict(ocr="feb2026_07feb_S_ocr.txt", set="S", key="feb2026_p1_07feb"),
    "2026-02-08": dict(ocr="feb2026_08feb_C_ocr.txt", set="C", key="feb2026_p1_08feb"),
    "2024-07":    dict(ocr="july2024_A_ocr.txt",     set="A", key="july2024_p1"),
    "2024-12":    dict(ocr="dec2024_H_ocr.txt",      set="H", key="dec2024_p1"),
}

ROUGH = re.compile(r"(?i)space for rough work|रफ़? ?कार्य के लिए जगह|रफ कार्य")

def fix_stacked_markers(t):
    """OCR kabhi-kabhi option-markers ko alag lines par tod deta hai:
       ') text1\n) text2\n) text3\n) text4' + '(1\n(2\n(3\n(4\n' → proper '(1) text1...'"""
    out = []
    i = 0
    pat_stack = re.compile(r"\(\s*1\s*\n\s*\(\s*2\s*\n\s*\(\s*3\s*\n\s*\(\s*4\s*\n")
    lines = t.split("\n")
    n = len(lines)
    j = 0
    while j < n:
        ln = lines[j]
        m = pat_stack.match("\n".join(lines[j:j + 4]) + "\n") or (
            j + 4 <= n and re.match(r"^\(\s*1\s*$", ln) and re.match(r"^\(\s*2\s*$", lines[j+1] if j+1 < n else "")
            and re.match(r"^\(\s*3\s*$", lines[j+2] if j+2 < n else "")
            and re.match(r"^\(\s*4\s*$", lines[j+3] if j+3 < n else ""))
        if m:
            # peeche 4 ')' se shuru hone wali option-lines dhoondo
            k = len(out) - 1
            idxs = []
            while k >= 0 and len(idxs) < 4:
                if re.match(r"^\)\s*\S", out[k]):
                    idxs.append(k)
                elif out[k].strip() == "":
                    pass
                else:
                    break
                k -= 1
            if len(idxs) == 4:
                for num, oi in zip("1234", reversed(idxs)):
                    out[oi] = f"({num})" + out[oi][1:].lstrip()
                j += 4
                continue
        out.append(ln)
        j += 1
    t2 = "\n".join(out)
    # '(1\n)' jaishe toote markers jodo
    t2 = re.sub(r"\(\s*([1-4])\s*\n\s*\)", r"(\1)", t2)
    t2 = re.sub(r"\(\s*([1-4])\s*\n\s*\(", r"(\1) (", t2)
    return t2

def clean(t):
    lines = []
    for ln in t.split("\n"):
        ln = re.sub(r"\s*[A-Z]{2,4}[-–]?\d{0,2}[-–]?I{0,3}\s*\(?[A-Z]\)?\s*/\s*P\s*1?\s*\d{1,3}\s*$", "", ln)
        ln = re.sub(r"\s*/\s*P\s*1\s*\d{1,3}\s*$", "", ln)
        ln = re.sub(r"^\s*P\s*[-|lI]?\s*\d{1,3}\s*$", "", ln)
        if ROUGH.search(ln):
            continue
        lines.append(ln.rstrip())
    return fix_stacked_markers("\n".join(lines))

def is_dev_line(ln):
    d = len(DEV.findall(ln)); l = len(LAT.findall(ln))
    return d >= 3 and d > l

def split_lat_prefix(txt):
    lines = txt.split("\n")
    for i, ln in enumerate(lines):
        if is_dev_line(ln):
            return "\n".join(lines[:i]).strip(), "\n".join(lines[i:]).strip()
    return txt.strip(), ""

def split_dev_prefix(txt):
    lines = txt.split("\n")
    last = -1
    for i, ln in enumerate(lines):
        if is_dev_line(ln):
            last = i
    if last < 0:
        return "", txt.strip()
    return "\n".join(lines[:last + 1]).strip(), "\n".join(lines[last + 1:]).strip()

OPTM = re.compile(r"\(\s*([1-4])\s*\)")

def walk_quads(seg):
    out, want, cur = [], 1, []
    for m in OPTM.finditer(seg):
        d = int(m.group(1))
        if d == want:
            cur.append(m); want += 1
            if want == 5:
                out.append(tuple(cur)); want, cur = 1, []
        elif d == 1:
            cur, want = [m], 2
    return out

def tidy(x):
    return re.sub(r"\s+", " ", x).strip(" -|.").strip()

def parse_pairs(seg, start, end):
    """[start,end) me se question-list: har question = [pre-stem][en-quad][hi-quad]."""
    quads = walk_quads(seg)
    if not quads:
        return []
    pairs = []
    for i in range(0, len(quads) - 0):
        pass
    i = 0
    while i < len(quads) - 1:
        enq, hiq = quads[i], quads[i + 1]
        # sanity: en quad ke baad hi quad hi aata hai (alternation)
        pairs.append((enq, hiq))
        i += 2
    out = []
    for k, (enq, hiq) in enumerate(pairs):
        nxt = pairs[k + 1][0][0].start() if k + 1 < len(pairs) else len(seg)
        pre = seg[0 if k == 0 else pairs[k - 1][1][3].end():enq[0].start()]
        devpre, stem_en = split_dev_prefix(pre)
        if not stem_en:
            stem_en = pre
        opts_en = [seg[enq[j].end():enq[j + 1].start()] for j in range(3)]
        span4 = seg[enq[3].end():hiq[0].start()]
        lat4, dev4 = split_lat_prefix(span4)
        opts_en.append(lat4)
        stem_hi = dev4
        opts_hi = [seg[hiq[j].end():hiq[j + 1].start()] for j in range(3)]
        span_h4 = seg[hiq[3].end():nxt]
        devh4, _ = split_dev_prefix(span_h4)
        opts_hi.append(devh4 if devh4 else span_h4)
        out.append(dict(stem_en=tidy(stem_en), opts_en=[tidy(o) for o in opts_en],
                        stem_hi=tidy(stem_hi), opts_hi=[tidy(o) for o in opts_hi]))
    return out

def parse_single(seg):
    """single-language section (lang): har quad = ek question."""
    quads = walk_quads(seg)
    out = []
    prev_end = 0
    for q in quads:
        stem = seg[prev_end:q[0].start()]
        opts = [seg[q[j].end():q[j + 1].start()] for j in range(3)]
        opts.append(seg[q[3].end():len(seg)])
        out.append(dict(stem=tidy(stem), opts=[tidy(o) for o in opts]))
        prev_end = q[3].end()
    # aakhri opt-4 me aage ka text jud sakta hai — re.split at next-number anyway
    return out

NUMRE = re.compile(r"(?m)^(\d{1,3})[\.\)]\s*")

def build_runs(t):
    """maximal increasing number-runs (sirf reset par break; min len 6)."""
    items = [(int(m.group(1)), m.start(), m.end()) for m in NUMRE.finditer(t)]
    runs, cur = [], []
    for n, pos, end in items:
        if not cur or n > cur[-1][0]:
            cur.append((n, pos, end))
        else:
            if len(cur) >= 6:
                runs.append(cur)
            cur = [(n, pos, end)]
    if len(cur) >= 6:
        runs.append(cur)
    return runs

SECTIONS = [("core", 1, 90), ("lang1_en", 91, 120), ("lang1_hi", 91, 120),
            ("lang2_en", 121, 150), ("lang2_hi", 121, 150)]

def walk_sections(t):
    """numbers ko canonical section-stream me daalo.
    → {tag: [(n, pos, end), ...]} + har section ka pehla anchor pos."""
    dm = re.search(r"(?im)^Direction\s*:.{0,140}?\b1\s*(to|to|—|-|–)\s*30\b", t)
    core_from = dm.start() if dm else 0
    items = [(int(m.group(1)), m.start(), m.end()) for m in NUMRE.finditer(t)
             if m.start() >= core_from]
    res = {tag: [] for tag, _, _ in SECTIONS}
    si = 0
    expected = 1
    for n, pos, end in items:
        tag, lo, hi = SECTIONS[si]
        nxt = SECTIONS[si + 1] if si + 1 < 5 else None
        if lo <= n <= hi and n >= expected - 1 and n <= hi:
            res[tag].append((n, pos, end))
            expected = n + 1 if n + 1 <= hi else hi + 1
        elif nxt and len(res[tag]) >= 20 and nxt[1] <= n <= nxt[2]:
            si += 1
            expected = n + 1
            res[nxt[0]].append((n, pos, end))
        elif nxt and nxt[1] <= n <= nxt[2] and len(res[tag]) >= 20:
            si += 1
            res[nxt[0]].append((n, pos, end))
            expected = n + 1
        # else: garbage — skip
    return res

def parse_paper(raw):
    t = clean(raw)
    res = walk_sections(t)
    out, meta = [], []
    order = [x for x in SECTIONS if res[x[0]]]
    for idx, (tag, tlo, thi) in enumerate(order):
        r = res[tag]
        seg_start = r[0][1]
        seg_end = order[idx + 1][2] and res[order[idx + 1][0]][0][1] if idx + 1 < len(order) else len(t)
        seg_end = res[order[idx + 1][0]][0][1] if idx + 1 < len(order) else len(t)
        seg = t[seg_start:seg_end]
        qs = []
        expected = tlo
        preamble = seg[:r[0][2] - seg_start]
        for bi in range(len(r)):
            n, pos, end = r[bi]
            bstart = end - seg_start
            bend = (r[bi + 1][1] - seg_start) if bi + 1 < len(r) else len(seg)
            block = seg[bstart:bend]
            if not block.strip():
                continue
            if tag == "core":
                pairs = parse_pairs(block, 0, len(block))
            else:
                singles = parse_single(block)
                pairs = [dict(stem_en=("" if tag.endswith("_hi") else x["stem"]),
                              opts_en=([] if tag.endswith("_hi") else x["opts"]),
                              stem_hi=(x["stem"] if tag.endswith("_hi") else ""),
                              opts_hi=(x["opts"] if tag.endswith("_hi") else []))
                         for x in singles]
            if not pairs:
                continue
            if n == expected:
                start_no = n
            elif expected < n:
                start_no = expected
            elif n <= expected <= n + len(pairs) - 1:
                start_no = n
            else:
                start_no = max(tlo, n - len(pairs) + 1)
            for k, pr in enumerate(pairs):
                q = dict(pr)
                q["qno"] = start_no + k
                q["sec"] = None if tag == "core" else tag
                if bi == 0 and k == 0 and preamble.strip():
                    lat, _ = split_lat_prefix(preamble)
                    dev, _ = split_dev_prefix(preamble)
                    if lat:
                        q["stem_en"] = tidy(lat) + " " + q["stem_en"]
                    if dev:
                        q["stem_hi"] = tidy(dev) + " " + q["stem_hi"]
                qs.append(q)
            expected = start_no + len(pairs)
        meta.append(dict(sec=tag, found=len(qs), anchors=f"{r[0][0]}-{r[-1][0]}"))
        out.extend(qs)
    return out, meta

def main():
    keys = json.load(open("ctetnew/_sources/keys_parsed.json", encoding="utf-8"))
    allp, report = {}, {}
    for pid, spec in PAPERS.items():
        path = os.path.join(SRC, spec["ocr"])
        if not os.path.exists(path):
            continue
        qs, meta = parse_paper(open(path, encoding="utf-8").read())
        if spec.get("key") and spec.get("set"):
            key = keys[spec["key"]][spec["set"]]
            for q in qs:
                if not q["sec"]:
                    q["ans"] = key["main"].get(str(q["qno"]))
                elif q["sec"] == "lang1_hi":
                    q["ans"] = key["langs"].get("HINDI", {}).get(str(q["qno"]))
                elif q["sec"] == "lang2_en":
                    q["ans"] = key["langs"].get("ENGLISH", {}).get(str(q["qno"]))
                else:
                    q["ans"] = None
        core = [q for q in qs if not q["sec"]]
        full = sum(1 for q in qs if len(q["opts_en"]) == 4 and len(q["opts_hi"]) == 4
                   and all(len(o) > 0 for o in q["opts_en"] + q["opts_hi"]))
        qset = sorted(set(q["qno"] for q in core))
        report[pid] = dict(meta=meta, total=len(qs), full=full,
                           core_qnos="1-90" if qset == list(range(1, 91)) else str(qset))
        allp[pid] = qs
        print(f"[{pid}] core={len(core)} (qnos {report[pid]['core_qnos'][:20]}...) total={len(qs)} full={full}")
        print("     meta:", meta)
    json.dump(allp, open("ctetnew/_sources/ocr_parsed.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    json.dump(report, open("ctetnew/_sources/ocr_parse_report.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)

if __name__ == "__main__":
    main()

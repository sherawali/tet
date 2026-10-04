# -*- coding: utf-8 -*-
"""
Official CTET final answer-key parser.
ctetnew/_sources/keys/*.txt  →  ctetnew/_sources/keys_parsed.json

Formats:
  A) "Set :- X PAPER-I MAIN" / "Set :- X PAPER-I (MAIN)" / "Set :- X PAPER-I-01-English"
     (jan2021, aug2023, july2024, dec2024, jan2024, feb2026_*)
  B) "Exam Date: DD/MM/YYYY PAPER-I -MAIN" / "... PAPER-I NN-LANG"   (dec2021)
  C) "Exam date : DD.MM.YYYY Exam Shift : Morning" + rows "NNN SECTION ans"
     (dec2022 — ek hi date ke saare Morning pages EK booklet/set ke hote hain)

Answer values: "1"-"4" → 0-3; "A".."F"/"Z" → combo-letters (A=(1,2) B=(1,3) C=(1,4)
D=(2,3) E=(2,4) F=(3,4) Z=ALL); 9 → dropped (None).
"""
import json, os, re, glob

SRC = os.path.join("ctetnew", "_sources", "keys")
OUT = os.path.join("ctetnew", "_sources", "keys_parsed.json")

COMBO = {"A": "1,2", "B": "1,3", "C": "1,4", "D": "2,3", "E": "2,4", "F": "3,4", "Z": "ALL"}

def norm_ans(v):
    v = v.strip().strip("*").strip().strip("()").strip()
    if v in ("1", "2", "3", "4"):
        return str(int(v) - 1)          # 0-3 index
    if v in COMBO:
        return COMBO[v]                  # combo — question text se map karna hoga
    if v == "9":
        return None                      # dropped / sabko marks
    return v                              # "1,2" jaisa raw

NOISE = {"QNO", "ANS", "Qno", "ANSWER", "KEY", "key", "Description", "Page", "No.",
         "Set", ":-", "PAPER-I", "CTET", "FINAL", "Final", "Publish", "Date:", "Med:", "Eng", "Hindi"}

def parse_pairs(lines):
    """lines me 'qno ans qno ans ...' sequence — pairs banao."""
    out = {}
    toks = []
    for ln in lines:
        ln = ln.replace("|", " ").replace("-----", " ")
        if ln.strip().startswith("=====") or re.match(r"Page\s+No", ln.strip()):
            continue
        ln = re.sub(r"\bEXAM[-\d/]+\b", " ", ln)
        ln = re.sub(r"\b\d{2}/\d{2}/\d{4}\b", " ", ln)
        toks += ln.split()
    i = 0
    while i < len(toks) - 1:
        a, b = toks[i], toks[i + 1]
        if re.fullmatch(r"\d{1,3}", a) and (re.fullmatch(r"[1-49]", b) or b in COMBO
                                            or re.fullmatch(r"[1-4],[1-4]", b)):
            q = int(a)
            if q not in out:
                out[q] = norm_ans(b)
            i += 2
        else:
            i += 1
    return out

# ---------------------------------------------------------------- format A
def parse_format_a(path):
    txt = open(path, encoding="utf-8").read()
    sets = {}
    hdr = re.compile(r"Set\s*:-\s*([A-Z0-9]+)\s+PAPER-I[\s\-]*\(?\s*(?:(\d{2})-)?(MAIN|[A-Za-z]+)", re.I)
    marks = []
    for m in hdr.finditer(txt):
        sec = m.group(3).upper()
        marks.append((m.start(), m.group(1), sec))
    for idx, (pos, s, sec) in enumerate(marks):
        end = marks[idx + 1][0] if idx + 1 < len(marks) else len(txt)
        body = txt[pos:end]
        k = body.upper().find(sec, body.upper().find("PAPER-I"))
        if k < 0:
            k = body.upper().find(sec)
        body = body[k + len(sec):]
        pairs = parse_pairs(body.split("\n"))
        d = sets.setdefault(s, {"main": {}, "langs": {}})
        if sec == "MAIN":
            d["main"].update(pairs)
        else:
            d["langs"].setdefault(sec, {}).update(pairs)
    return sets

# ---------------------------------------------------------------- format B
def parse_format_b(path):
    txt = open(path, encoding="utf-8").read()
    out = {}
    marks = []
    for m in re.finditer(r"Exam Date:\s*([\d/]+)\s+PAPER-I\s+(-MAIN|[\d]+-[A-Z]+)", txt):
        marks.append((m.start(), m.group(1), m.group(2)))
    for idx, (pos, date, sec) in enumerate(marks):
        end = marks[idx + 1][0] if idx + 1 < len(marks) else len(txt)
        body = txt[pos:end]
        j = body.index(sec)
        body = body[j + len(sec):]
        pairs = parse_pairs(body.split("\n"))
        d = out.setdefault(date, {"main": {}, "langs": {}})
        if sec == "-MAIN":
            d["main"].update(pairs)
        else:
            lang = sec.split("-", 1)[1]
            d["langs"].setdefault(lang, {}).update(pairs)
    return out

# ---------------------------------------------------------------- format C
def parse_format_c(path):
    """dec2022: Morning pages = Paper-1; ek date ke saare pages merge (ek booklet)."""
    txt = open(path, encoding="utf-8").read()
    marks = list(re.finditer(r"Exam date\s*:\s*([\d.]+)\s+Exam Shift\s*:\s*(Morning|Evening)", txt))
    out = {}
    for idx, m in enumerate(marks):
        if m.group(2) != "Morning":
            continue
        end = marks[idx + 1].start() if idx + 1 < len(marks) else len(txt)
        body = txt[m.end():end]
        name = m.group(1).replace(".", "/")
        d = out.setdefault(name, {"main": {}, "langs": {}})
        for ln in body.split("\n"):
            toks = ln.replace("|", " ").split()
            j = 0
            while j < len(toks) - 2:
                if re.fullmatch(r"\d{3}", toks[j]) and re.fullmatch(r"[A-Z]+", toks[j + 1]) \
                   and (re.fullmatch(r"[1-49]", toks[j + 2]) or "," in toks[j + 2]):
                    q = int(toks[j])
                    sec, a = toks[j + 1], norm_ans(toks[j + 2])
                    if sec in ("CDP", "MATHS", "EVS"):
                        d["main"].setdefault(q, a)
                    else:
                        d["langs"].setdefault(sec, {}).setdefault(q, a)
                    j += 3
                else:
                    j += 1
    return out

ALL = {}
for path in sorted(glob.glob(os.path.join(SRC, "*.txt"))):
    fn = os.path.basename(path)
    exam = fn.replace("_final_key.txt", "").replace(".txt", "")
    if exam in ALL:                       # dec2021 en/hi — pehla kaafi
        continue
    if "dec2021" in fn:
        ALL[exam] = parse_format_b(path)
    elif "dec2022" in fn:
        ALL[exam] = parse_format_c(path)
    else:
        ALL[exam] = parse_format_a(path)

with open(OUT, "w", encoding="utf-8") as f:
    json.dump(ALL, f, ensure_ascii=False, indent=1)

# ------------------------------------------------------------------- summary
ok = True
for exam, sets in ALL.items():
    line = [f"{exam}: {len(sets)} sets"]
    for s, d in sorted(sets.items()):
        nm = len(d["main"])
        nl = {k: len(v) for k, v in d["langs"].items() if v}
        mainok = "✓" if nm == 90 else ("!" if nm else "✗")
        line.append(f"  {s}: main{mainok}{nm} langs[{','.join(k for k in list(nl)[:4])}]")
        if nm not in (90,):
            ok = False
    print("\n".join(line))
print("ALL MAIN=90:", ok)

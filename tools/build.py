# -*- coding: utf-8 -*-
"""
CSV  →  immutable packs + manifest
तू सिर्फ़ content/*.csv में पंक्तियाँ जोड़ेगा। बाकी सब ये करेगा।
"""
import csv,json,hashlib,os,glob,sys,re
sys.stdout.reconfigure(encoding='utf-8')
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from pscore import p_score


ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONTENT=os.path.join(ROOT,"content"); DIST=os.path.join(ROOT,"cdn")
PACKS=os.path.join(DIST,"packs"); os.makedirs(PACKS,exist_ok=True)
CHUNK=200                      # हर pack में कितने प्रश्न

def norm(s): return re.sub(r'\s+','',(s or '')).lower()
def fp(r):   return hashlib.sha1((norm(r.get('exams',''))+norm(r['q_hi'])+norm(r['q_en'])+norm(r['a_hi'])).encode()).hexdigest()[:16]
def sha(b):  return hashlib.sha256(b).hexdigest()

# ── 1. passages पढ़ो ───────────────────────────────────────────
passages={}
pf=os.path.join(CONTENT,"passages.csv")
if os.path.exists(pf):
    for r in csv.DictReader(open(pf,encoding="utf-8")):
        if r.get("pid"): passages[r["pid"]]={"id":r["pid"],"k":r["kind"],"d":r["dir_text"],"b":r["body"]}

# ── 2. सारे question CSV पढ़ो, duplicate हटाओ ──────────────────
#     (गद्यांश सीधे उसी CSV में भी लिखा जा सकता है — p_kind/p_dir/p_body)
rows=[];seen={};dups=[];errs=[]
TOPICS=[]
for f in sorted(glob.glob(os.path.join(CONTENT,"q_*.csv"))):
    for ln,r in enumerate(csv.DictReader(open(f,encoding="utf-8")),2):
        if not (r.get("q_hi") or "").strip(): continue
        try: ans=int(r["ans"])
        except: errs.append(f"{os.path.basename(f)}:{ln} ans गलत"); continue
        if ans not in (0,1,2,3): errs.append(f"{os.path.basename(f)}:{ln} ans 0-3 होना चाहिए"); continue
        o_hi=[r.get(k,"").strip() for k in ("a_hi","b_hi","c_hi","d_hi")]
        if not all(o_hi): errs.append(f"{os.path.basename(f)}:{ln} विकल्प अधूरे"); continue
        # गद्यांश उसी पंक्ति में दिया हो तो यहीं दर्ज कर लो
        if r.get("pid") and (r.get("p_body") or "").strip() and r["pid"] not in passages:
            passages[r["pid"]]={"id":r["pid"],"k":(r.get("p_kind") or "prose").strip(),
                                "d":(r.get("p_dir") or "").strip(),"b":r["p_body"].strip()}
        k=fp(r)
        if k in seen: dups.append((os.path.basename(f),ln,seen[k])); continue
        seen[k]=f"{os.path.basename(f)}:{ln}"
        t=r["topic"].strip()
        if t not in TOPICS: TOPICS.append(t)
        o_en=[r.get(x,"").strip() for x in ("a_en","b_en","c_en","d_en")]
        o_en_safe = [e if e else h for e, h in zip(o_en, o_hi)]
        bi=1 if (r.get("q_en") or "").strip() else 0
        rows.append({"k":k,"e":r["exams"].strip(),"s":r["section"].strip(),"t":TOPICS.index(t),
                     "d":int(r.get("difficulty") or 2),
                     "qh":r["q_hi"].strip(),"oh":o_hi,
                     **({"qe":r["q_en"].strip(),"oe":o_en_safe} if bi else {}),
                     "a":ans,
                     "n":(lambda ps,m:int(ps) if ps else (int(m.group(1)) if m else 0))((r.get("pseq") or "").strip(), re.search(r' Q(\d+)',r.get("source") or '')),
                     **({"pid":r["pid"]} if r.get("pid") else {}),
                     "_yrs":[y.strip() for y in (r.get("years") or "").split(",") if y.strip()],
                     "_pyq":1 if (r.get("is_pyq") or "0").strip()=="1" else 0})

orphan=sorted({r["pid"] for r in rows if "pid" in r and r["pid"] not in passages})
if orphan: errs.append(f"इन गद्यांशों का टेक्स्ट कहीं नहीं मिला: {', '.join(orphan)}")

if errs:
    print("❌ गलतियाँ मिलीं — ठीक करो :");  [print("   ",e) for e in errs[:20]];  sys.exit(1)

# ── हर टॉपिक कितने अलग वर्षों में आया, खुद गिनो ──
TOPIC_YEARS={}
for r in rows:
    TOPIC_YEARS.setdefault(r["t"],set()).update(r.get("_yrs",[]))
# ── हर प्रश्न को «आने की संभावना» का अंक दो ──
for r in rows:
    r["p"]=p_score(r.get("_yrs",[]), len(TOPIC_YEARS.get(r["t"],())), r.get("_pyq",0)==1)
    if r.get("_pyq"): r["y"]=",".join(r["_yrs"])
    r.pop("_yrs",None); r.pop("_pyq",None)

# स्थिर क्रम = स्थिर packs · pid-group साथ-साथ, असली पेपर-क्रम (n) में
_gmin={}
for r in rows:
    if r.get("pid"):
        _gmin[r["pid"]]=min(_gmin.get(r["pid"],10**9), r.get("n",0))
def _ordkey(r):
    pid=r.get("pid")
    gn=_gmin[pid] if pid else r.get("n",0)
    return (r["s"], gn, pid or "", r.get("n",0), r["k"])
rows.sort(key=_ordkey)

# ── 3. immutable packs में बाँटो ──────────────────────────────
packs=[]
for i in range(0,len(rows),CHUNK):
    part=rows[i:i+CHUNK]
    pids=sorted({r["pid"] for r in part if "pid" in r})
    body={"v":1,"p":[passages[p] for p in pids if p in passages],"q":part}
    raw=json.dumps(body,ensure_ascii=False,separators=(",",":")).encode()
    h=sha(raw)[:12]
    name=f"pack-{i//CHUNK:04d}-{h}.json"       # नाम में hash = हमेशा immutable
    open(os.path.join(PACKS,name),"wb").write(raw)
    packs.append({"id":f"{i//CHUNK:04d}","file":f"packs/{name}","sha256":sha(raw),
                  "bytes":len(raw),"count":len(part),
                  "sections":sorted({r["s"] for r in part})})

# ── 4. manifest ───────────────────────────────────────────────
ver=int(os.environ.get("BANK_VERSION","0")) or (max([int(p["id"]) for p in packs])+1 if packs else 0)
man={"schema":1,"bank_version":ver,"generated":os.environ.get("BUILD_TIME","local"),
     "topics":TOPICS,"total":len(rows),
     "pyq_count":sum(1 for r in rows if r.get("y")),
     "avg_p":round(sum(r["p"] for r in rows)/max(len(rows),1),4),
     "sections":{s:sum(1 for r in rows if r["s"]==s) for s in sorted({r["s"] for r in rows})},
     "packs":packs}
mraw=json.dumps(man,ensure_ascii=False,separators=(",",":")).encode()
open(os.path.join(DIST,"manifest.json"),"wb").write(mraw)

# पुराने pack हटाओ जो अब manifest में नहीं
keep={os.path.basename(p["file"]) for p in packs}
for f in os.listdir(PACKS):
    if f not in keep: os.remove(os.path.join(PACKS,f))

import gzip
gz=sum(len(gzip.compress(open(os.path.join(PACKS,os.path.basename(p['file'])),'rb').read())) for p in packs)
print(f"✅ बना : {len(rows)} प्रश्न · {len(packs)} pack · manifest {len(mraw)} B")
print(f"   कुल डाउनलोड : {sum(p['bytes'] for p in packs)/1024:.0f} KB  →  gzip के बाद {gz/1024:.0f} KB")
if dups: print(f"   ⚠ {len(dups)} डुप्लिकेट अपने-आप हटाए")
for s,c in man["sections"].items(): print(f"   {s:9s} {c:4d}")

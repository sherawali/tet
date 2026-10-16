#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
UTET Paper-I के असली PYQ से पूरे मॉक पेपर (HTML) बनाने वाला टूल।

यह क्या करता है
---------------
`bank-v2/exams/utet/paper-1/` में 6 असली पेपर रखे हैं —
2020, 2021, 2022, 2024, 2025, 2026 (हर साल 150 प्रश्न, कुल 900)।
यह टूल उन्हीं 900 असली प्रश्नों को मिलाकर 6 पूरे मॉक पेपर बनाता है।

चयन के नियम (कोई random नहीं — हर बार यही नतीजा)
-------------------------------------------------
1. हर मॉक = असली पेपर जैसा : 150 प्रश्न, 150 अंक, 2 घण्टे 30 मिनट, कोई ऋणात्मक अंकन नहीं।
   खण्ड I CDP (30) · II हिन्दी-I (30) · III English-II (30) · IV गणित (30) · V EVS (30)
2. हर खण्ड में हर साल से बराबर 5 प्रश्न  →  6 साल × 5 = 30।
3. गद्यांश/कविता कभी नहीं टूटती — पूरा समूह एक साथ (selectionPolicy: atomic)।
   भाषा खण्डों में हर मॉक को ठीक 2 गद्यांश मिलते हैं, बिल्कुल असली पेपर जैसे।
4. कोई प्रश्न दो मॉक में नहीं जाता — 900 के 900 प्रश्न बराबर बँट जाते हैं।
5. क्रम : नया साल पहले (2026 → 2020), उसी साल में गद्यांश पहले, फिर मूल क्रम।
6. हर प्रश्न पर उसका स्रोत लिखा रहता है — साल, सेट, असली पेपर की प्रश्न-संख्या, प्रश्न-ID।

आउटपुट
------
mocks/utet/index.html        — सब मॉक की सूची
mocks/utet/mock-01.html … 06 — पूरे पेपर (offline, एक ही फाइल)
mocks/utet/provenance.csv    — कौन-सा प्रश्न किस साल से आया (पूरी तालिका)

चलाना
-----
python3 tools/v2/build_utet_mock_html.py
"""

from __future__ import annotations

import csv
import json
import re
from collections import OrderedDict, defaultdict
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BANK = ROOT / "bank-v2" / "exams" / "utet" / "paper-1"
AUDITS = ROOT / "bank-v2" / "audits"
SOURCES = ROOT / "bank-v2" / "sources"
OUT = ROOT / "mocks" / "utet"

MOCK_COUNT = 6
PER_YEAR = 5  # हर खण्ड में हर साल से कितने प्रश्न

# असली पेपर का क्रम — यही खण्ड-क्रम मॉक में भी रहेगा
SECTIONS = [
    ("cdp", "बाल विकास एवं शिक्षाशास्त्र", "Child Development and Pedagogy", 1, 30),
    ("language-1/hindi", "हिन्दी (भाषा-I)", "Hindi (Language-I)", 31, 60),
    ("language-2/english", "अंग्रेज़ी (भाषा-II)", "English (Language-II)", 61, 90),
    ("mathematics", "गणित", "Mathematics", 91, 120),
    ("environmental-studies", "पर्यावरण अध्ययन", "Environmental Studies", 121, 150),
]

SECTION_NUMERAL = ["I", "II", "III", "IV", "V"]


def load_cycles():
    """साल → परीक्षा-तिथि / सेट, sources/*.json से।"""
    cycles = {}
    for path in sorted(SOURCES.glob("utet-p1-*-sources.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        cycles[str(data["cycleLabel"])] = {
            "year": str(data["cycleLabel"]),
            "date": data["examDate"],
            "set": data["canonicalSet"],
            "status": data["verificationStatus"],
        }
    return OrderedDict(sorted(cycles.items(), key=lambda kv: kv[0]))


def load_audit(year):
    """questionId → असली पेपर की प्रश्न-संख्या।"""
    path = AUDITS / f"utet-p1-{year}-question-audit.ndjson"
    out = {}
    if not path.exists():
        return out
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        row = json.loads(line)
        out[row["questionId"]] = int(row["targetQuestionNumber"])
    return out


def texts(blocks):
    """contentBlocks → {"hi": "...", "en": "..."} (खाली लोकैल छोड़ देता है)"""
    merged = {}
    for block in blocks:
        for loc, text in block.get("text", {}).items():
            merged[loc] = (merged.get(loc, "") + "\n" + text).strip() if merged.get(loc) else text
    return {k: v for k, v in merged.items() if v}


def load_section(rel):
    folder = BANK / rel
    stimuli = {}
    for line in (folder / "stimuli.ndjson").read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        st = json.loads(line)
        body = texts(st["content"])
        for loc in body:  # अंत का "---" separator artifact हटाओ
            body[loc] = re.sub(r"\n*-{3,}\s*$", "", body[loc]).strip()
        stimuli[st["id"]] = {
            "d": texts([{"text": st.get("instructions", {})}]) if st.get("instructions") else {},
            "t": body,
            "ty": st.get("type", "prose"),
            "lang": st.get("language"),
        }

    questions = []
    for line in (folder / "questions.ndjson").read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        q = json.loads(line)
        year = q["id"].split("-")[2]
        questions.append(
            {
                "id": q["id"],
                "year": year,
                "set": next((t.split("-", 1)[1].upper() for t in q["tags"] if t.startswith("set-")), ""),
                "p": texts(q["prompt"]),
                "o": [{"k": o["id"], "t": texts(o["content"])} for o in q["options"]],
                "a": q["answer"].get("optionId"),
                "st": q.get("stimulusId"),
            }
        )
    return questions, stimuli


def group_by_year(questions):
    years = defaultdict(list)
    for q in questions:
        years[q["year"]].append(q)
    for year in years:
        years[year].sort(key=lambda q: q["qno"])
    return OrderedDict(sorted(years.items(), reverse=True))  # नया साल पहले


def split_year(items):
    """एक साल के प्रश्न → (गद्यांश-समूहों की सूची, अकेले प्रश्नों की सूची)"""
    groups = OrderedDict()
    singles = []
    for q in items:
        if q["st"]:
            groups.setdefault(q["st"], []).append(q)
        else:
            singles.append(q)
    return list(groups.values()), singles


def build_selection(by_year):
    """
    6 मॉक के लिए चयन। हर मॉक-साल में ठीक PER_YEAR प्रश्न।
    गद्यांश समूह अटूट रहते हैं; हर मॉक को भाषा खण्ड में ठीक 2 समूह मिलते हैं।
    लौटता है: mocks[mock_index][year] = [प्रश्न]  (पेपर के क्रम में)
    """
    year_list = list(by_year.keys())  # नया → पुराना
    n_years = len(year_list)
    assert n_years == MOCK_COUNT, f"{n_years} साल हैं, {MOCK_COUNT} मॉक नहीं बन सकते"

    # हर मॉक-साल के लिए खाली टोकरी
    picked = [[[] for _ in range(n_years)] for _ in range(MOCK_COUNT)]
    group_slot = [[None] * n_years for _ in range(MOCK_COUNT)]  # mock×year → समूह (या None)

    all_groups = {}
    all_singles = {}
    for yi, year in enumerate(year_list):
        groups, singles = split_year(by_year[year])
        all_groups[year] = groups
        all_singles[year] = singles

    # गद्यांश समूह बाँटो : हर साल के 2 समूह, 2 अलग मॉक में
    # (CDP/गणित/EVS में गद्यांश होते ही नहीं — वहाँ यह खाली रहता है)
    has_groups = any(all_groups[y] for y in year_list)
    if has_groups:
        for year in year_list:
            assert len(all_groups[year]) == 2, f"{year} में {len(all_groups[year])} गद्यांश समूह हैं, 2 चाहिए"
    for yi, year in enumerate(year_list):
        for k, grp in enumerate(all_groups[year]):
            mi = (2 * k + yi) % MOCK_COUNT
            assert group_slot[mi][yi] is None, "गद्यांश की टक्कर"
            group_slot[mi][yi] = grp

    # अब हर मॉक-साल में समूह + बाकी अकेले प्रश्न (क्रम से, कोई random नहीं)
    cursor = {year: 0 for year in year_list}
    for mi in range(MOCK_COUNT):
        for yi, year in enumerate(year_list):
            grp = group_slot[mi][yi]
            need = PER_YEAR
            bucket = []
            if grp:
                bucket.extend(grp)
                need -= len(grp)
            if need > 0:
                take = all_singles[year][cursor[year] : cursor[year] + need]
                cursor[year] += len(take)
                bucket.extend(take)
            picked[mi][yi] = bucket

    # बचा हुआ कुछ नहीं रहना चाहिए
    for year in year_list:
        left = len(all_singles[year]) - cursor[year]
        assert left == 0, f"{year}: {left} प्रश्न बिना बँटे बचे"
    return picked, year_list


def duplicate_years(by_year):
    """वही stem जो किसी और साल भी आया — id → [दूसरे साल]"""
    seen = defaultdict(list)
    for year, items in by_year.items():
        for q in items:
            key = (q["p"].get("hi") or q["p"].get("en") or "").strip()
            seen[key].append((year, q["id"]))
    dup = {}
    for key, hits in seen.items():
        if len(hits) > 1:
            for year, qid in hits:
                dup[qid] = sorted(y for y, _ in hits if y != year)
    return dup


def main():
    cycles = load_cycles()
    years_sorted = list(cycles.keys())

    audits = {y: load_audit(y) for y in years_sorted}

    bank = {}
    stimuli_all = {}
    for rel, _hi, _en, _a, _b in SECTIONS:
        qs, stims = load_section(rel)
        for q in qs:
            q["qno"] = audits[q["year"]].get(q["id"], 0)
        by_year = group_by_year(qs)
        bank[rel] = {"by_year": by_year, "dup": duplicate_years(by_year)}
        stimuli_all[rel] = stims

    # ---- चयन ----
    selections = {}
    for rel, *_ in SECTIONS:
        picked, year_list = build_selection(bank[rel]["by_year"])
        selections[rel] = (picked, year_list)

    # ---- हर मॉक की फ़ाइल ----
    OUT.mkdir(parents=True, exist_ok=True)
    generated = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    prov_rows = []
    mock_summary = []

    for mi in range(MOCK_COUNT):
        questions = []
        used_stim = {}
        n = 0
        for si, (rel, hi, en, q_start, q_end) in enumerate(SECTIONS):
            picked, year_list = selections[rel]
            for yi, year in enumerate(year_list):  # नया साल पहले
                for q in picked[mi][yi]:
                    n += 1
                    stims = stimuli_all[rel]
                    rec = {
                        "n": n,
                        "sec": si,
                        "id": q["id"],
                        "y": year,
                        "set": q["set"],
                        "date": cycles[year]["date"],
                        "qno": q["qno"],
                        "p": q["p"],
                        "o": q["o"],
                        "a": q["a"],
                        "st": q["st"],
                    }
                    dup = bank[rel]["dup"].get(q["id"])
                    if dup:
                        rec["dup"] = dup
                    if q["st"]:
                        used_stim[q["st"]] = stims[q["st"]]
                    questions.append(rec)
                    prov_rows.append(
                        {
                            "mock": f"M-{mi + 1:02d}",
                            "paper_qno": n,
                            "section": rel,
                            "section_hi": hi,
                            "source_cycle": year,
                            "exam_date": cycles[year]["date"],
                            "set": q["set"],
                            "original_qno": q["qno"],
                            "question_id": q["id"],
                            "stimulus_id": q["st"] or "",
                            "correct_option": q["a"],
                        }
                    )

        # स्रोत-वितरण (हर साल से कितने प्रश्न)
        dist = defaultdict(int)
        sec_dist = defaultdict(lambda: defaultdict(int))
        for rec in questions:
            dist[rec["y"]] += 1
            sec_dist[SECTIONS[rec["sec"]][0]][rec["y"]] += 1

        meta = {
            "id": f"utet-p1-mock-{mi + 1:02d}",
            "label": f"मॉक {mi + 1} / Mock {mi + 1}",
            "code": f"M-{mi + 1:02d}",
            "generated": generated,
            "duration": 150,
            "total": len(questions),
            "cycles": [
                {**cycles[y], "count": dist[y], "sections": {s: sec_dist[s][y] for s, *_ in SECTIONS}}
                for y in years_sorted
            ],
            "sections": [
                {"hi": hi, "en": en, "num": SECTION_NUMERAL[si], "from": q_start, "to": q_end}
                for si, (rel, hi, en, q_start, q_end) in enumerate(SECTIONS)
            ],
        }

        payload = {"meta": meta, "q": questions, "st": used_stim}
        path = OUT / f"mock-{mi + 1:02d}.html"
        html = (
            TEMPLATE.replace("/*__DATA__*/null", json.dumps(payload, ensure_ascii=False).replace("</", "<\/"))
            .replace("__MOCK_CODE__", meta["code"])
            .replace("__MOCK_LABEL__", meta["label"])
            .replace("__GENERATED__", generated)
        )
        path.write_text(html, encoding="utf-8")
        mock_summary.append((meta, path))
        print(f"  {path.relative_to(ROOT)}  —  {len(questions)} प्रश्न, {len(used_stim)} गद्यांश")

    # ---- provenance.csv ----
    csv_path = OUT / "provenance.csv"
    with csv_path.open("w", newline="", encoding="utf-8-sig") as fh:
        writer = csv.DictWriter(fh, fieldnames=list(prov_rows[0].keys()))
        writer.writeheader()
        writer.writerows(prov_rows)
    print(f"  {csv_path.relative_to(ROOT)}  —  {len(prov_rows)} पंक्तियाँ")

    # ---- index.html ----
    (OUT / "index.html").write_text(build_index(mock_summary, years_sorted, generated), encoding="utf-8")
    print(f"  {(OUT / 'index.html').relative_to(ROOT)}")

    # ---- जाँच ----
    print("\nजाँच:")
    print(f"  कुल प्रश्न बँटे      : {len(prov_rows)}")
    uniq = {r["question_id"] for r in prov_rows}
    assert len(uniq) == len(prov_rows), "कोई प्रश्न दो मॉक में चला गया"
    print(f"  अलग प्रश्न-ID       : {len(uniq)}  (दोहराव नहीं)")

    # बैंक के पूरे प्रश्न बँटे हैं, कुछ बचा नहीं
    bank_ids = set()
    for rel, *_ in SECTIONS:
        for items in bank[rel]["by_year"].values():
            bank_ids.update(q["id"] for q in items)
    assert bank_ids == uniq, f"बैंक में {len(bank_ids)} हैं, बँटे {len(uniq)}"
    print(f"  बैंक के कुल प्रश्न  : {len(bank_ids)} — सब बँट गए, कुछ बचा नहीं")

    # उत्तर और मूल प्रश्न-संख्या बैंक से मेल खाती है
    truth = {}
    for rel, *_ in SECTIONS:
        for items in bank[rel]["by_year"].values():
            for q in items:
                truth[q["id"]] = (q["a"], q["qno"], q["st"])
    for r in prov_rows:
        a, qno, st = truth[r["question_id"]]
        assert (r["correct_option"], r["original_qno"], r["stimulus_id"] or None) == (a, qno, st), r["question_id"]
    print("  उत्तर + मूल प्रश्न-संख्या : बैंक से पूरी मेल")

    # हर खण्ड में हर मॉक में 30, हर साल से 5
    for rel, hi, en, a, b in SECTIONS:
        per_mock = defaultdict(int)
        per_mock_year = defaultdict(int)
        for r in prov_rows:
            if r["section"] == rel:
                per_mock[r["mock"]] += 1
                per_mock_year[(r["mock"], r["source_cycle"])] += 1
        assert set(per_mock.values()) == {30}, f"{hi}: {dict(per_mock)}"
        assert set(per_mock_year.values()) == {PER_YEAR}, f"{hi}: साल-वार बँटवारा गड़बड़"
        print(f"  {hi:<26} : हर मॉक में 30 · हर साल से {PER_YEAR}")

    # गद्यांश समूह पेपर में लगातार हैं (कभी टूटे नहीं)
    for mi in range(MOCK_COUNT):
        seq = [r for r in prov_rows if r["mock"] == f"M-{mi + 1:02d}"]
        seen_at = {}
        for r in seq:
            if not r["stimulus_id"]:
                continue
            if r["stimulus_id"] in seen_at:
                assert r["paper_qno"] == seen_at[r["stimulus_id"]] + 1, (
                    f"{r['mock']} में गद्यांश {r['stimulus_id']} टूट गया"
                )
            seen_at[r["stimulus_id"]] = r["paper_qno"]
    # हर मॉक में भाषा खण्डों के गद्यांश गिनो
    for mi in range(MOCK_COUNT):
        g = defaultdict(set)
        for r in prov_rows:
            if r["mock"] == f"M-{mi + 1:02d}" and r["stimulus_id"]:
                g[r["section"]].add(r["stimulus_id"])
        assert len(g["language-1/hindi"]) == 2 and len(g["language-2/english"]) == 2, dict(g)
    print("  गद्यांश समूह          : कहीं नहीं टूटे · हर मॉक में 2 हिन्दी + 2 English")
    return 0


def build_index(mocks, years, generated):
    cards = []
    for meta, path in mocks:
        chips = " ".join(
            f'<span class="chip y{c["year"]}">{c["year"]} · {c["count"]}</span>' for c in meta["cycles"]
        )
        cards.append(
            f"""
      <a class="card" href="{path.name}">
        <div class="card-top">
          <span class="code">{meta['code']}</span>
          <span class="qcount">{meta['total']} प्रश्न · {meta['duration']} मिनट</span>
        </div>
        <h3>UTET Paper-I · {meta['label']}</h3>
        <p class="sub">बाल विकास एवं शिक्षाशास्त्र 30 · हिन्दी-I 30 · English-II 30 · गणित 30 · पर्यावरण अध्ययन 30</p>
        <div class="chips">{chips}</div>
        <span class="go">पेपर खोलो →</span>
      </a>"""
        )

    rows = []
    for meta, _ in mocks:
        cells = "".join(f"<td>{c['count']}</td>" for c in meta["cycles"])
        rows.append(f"<tr><th>{meta['code']}</th>{cells}<td><b>{meta['total']}</b></td></tr>")
    year_head = "".join(f"<th>{y}</th>" for y in years)

    return INDEX_TEMPLATE.replace("__CARDS__", "".join(cards)).replace(
        "__ROWS__", "".join(rows)
    ).replace("__YEAR_HEAD__", year_head).replace("__GENERATED__", generated).replace(
        "__TOTAL__", str(sum(m["total"] for m, _ in mocks))
    )


# ---------------------------------------------------------------------------
# पेपर का HTML ढाँचा
# ---------------------------------------------------------------------------
TEMPLATE = r"""<!DOCTYPE html>
<html lang="hi">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>UTET Paper-I · __MOCK_CODE__ — असली PYQ मॉक</title>
<style>
:root{
  --bg:#f4f6fb; --card:#fff; --ink:#141a2b; --soft:#5b6479; --line:#e3e8f2;
  --brand:#1f4fd8; --brand-soft:#eaf0ff; --ok:#0f8a4d; --bad:#c8262b; --warn:#b8860b;
  --y2026:#c8262b; --y2025:#e0731a; --y2024:#b8860b; --y2022:#0f8a4d; --y2021:#1f4fd8; --y2020:#6b7280;
}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);
  font-family:"Noto Sans Devanagari","Nirmala UI","Mangal",system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;
  font-size:16px;line-height:1.65;-webkit-text-size-adjust:100%}
a{color:var(--brand)}
.wrap{max-width:1180px;margin:0 auto;padding:0 14px 80px}
header.top{position:sticky;top:0;z-index:40;background:#0f1a3d;color:#fff;padding:10px 14px;
  display:flex;gap:12px;align-items:center;flex-wrap:wrap;box-shadow:0 2px 10px rgba(0,0,0,.18)}
header.top .tt{font-weight:700;font-size:15px}
header.top .tt small{display:block;font-weight:400;opacity:.75;font-size:11.5px}
.clock{margin-left:auto;font-variant-numeric:tabular-nums;background:#1b2a5e;padding:5px 12px;border-radius:999px;
  font-weight:700;font-size:15px}
.clock.low{background:#c8262b}
.langbtns{display:flex;gap:4px;background:#1b2a5e;border-radius:999px;padding:3px}
.langbtns button{border:0;background:transparent;color:#cfd8f5;font:inherit;font-size:13px;padding:4px 11px;border-radius:999px;cursor:pointer}
.langbtns button.on{background:#fff;color:#0f1a3d;font-weight:700}
button.act{border:0;background:var(--brand);color:#fff;font:inherit;font-weight:700;font-size:14px;
  padding:8px 16px;border-radius:10px;cursor:pointer}
button.ghost{background:transparent;border:1px solid #3d4d85;color:#dbe3ff}
.notice{background:#fff8e1;border:1px solid #f0dca0;border-radius:12px;padding:12px 14px;margin:16px 0;font-size:14.5px}
.notice b{color:#8a6100}
.intro{background:var(--card);border:1px solid var(--line);border-radius:14px;padding:16px 18px;margin:16px 0}
.intro h1{margin:0 0 6px;font-size:20px}
.intro .meta{color:var(--soft);font-size:13.5px;margin-bottom:10px}
.intro ol{margin:8px 0 0;padding-left:22px;font-size:14px;color:#2a3350}
.intro .en{color:var(--soft);font-size:13px}
.grid{display:grid;grid-template-columns:1fr 250px;gap:18px;align-items:start}
@media(max-width:900px){.grid{grid-template-columns:1fr}.side{position:static!important;max-height:none!important}}
.side{position:sticky;top:64px;max-height:calc(100vh - 80px);overflow:auto;background:var(--card);
  border:1px solid var(--line);border-radius:14px;padding:12px}
.side h4{margin:2px 0 8px;font-size:13px;text-transform:uppercase;letter-spacing:.04em;color:var(--soft)}
.pal{display:grid;grid-template-columns:repeat(auto-fill,minmax(34px,1fr));gap:5px}
.pal button{border:1px solid var(--line);background:#fff;border-radius:8px;font:inherit;font-size:12.5px;
  padding:5px 0;cursor:pointer;color:#333}
.pal button.done{background:#e7f7ee;border-color:#a8e0c0;color:#0f6b3d;font-weight:700}
.pal button.flag{background:#fff3e0;border-color:#f0c48a;color:#9a5b00;font-weight:700}
.pal button.cur{outline:2px solid var(--brand)}
.legend{font-size:11.5px;color:var(--soft);margin-top:10px;line-height:1.9}
.legend i{display:inline-block;width:11px;height:11px;border-radius:3px;margin-right:5px;vertical-align:-1px}
section.sec{background:var(--card);border:1px solid var(--line);border-radius:14px;margin:18px 0;overflow:hidden}
section.sec>h2{margin:0;padding:12px 16px;background:linear-gradient(180deg,#f7f9ff,#eef3ff);
  border-bottom:1px solid var(--line);font-size:16.5px}
section.sec>h2 span{color:var(--soft);font-weight:400;font-size:13px}
.stim{margin:14px 14px 4px;padding:14px 16px;background:#fbfaf5;border:1px solid #ece6d2;border-radius:12px}
.stim .dir{font-size:13px;color:#7a6a33;font-weight:700;margin-bottom:8px}
.stim .body{white-space:pre-wrap;font-size:15px}
.stim .tag{display:inline-block;font-size:11px;background:#efe8cf;color:#6b5c1f;padding:1px 8px;border-radius:999px;margin-bottom:8px}
.q{padding:14px 16px;border-top:1px solid var(--line)}
.q:first-of-type{border-top:0}
.qhead{display:flex;gap:8px;align-items:baseline;flex-wrap:wrap;margin-bottom:6px}
.qnum{font-weight:800;font-size:15.5px}
.src{font-size:11.5px;padding:2px 9px;border-radius:999px;background:var(--brand-soft);color:#26407f;font-weight:600}
.src.y2026{background:#fdeaea;color:#a01d22}.src.y2025{background:#fdf0e4;color:#a75312}
.src.y2024{background:#fbf4dd;color:#8a6100}.src.y2022{background:#e6f5ec;color:#0c6b3c}
.src.y2021{background:#e9efff;color:#1f4fd8}.src.y2020{background:#eef0f3;color:#4c5563}
.dup{font-size:11px;background:#f3e8ff;color:#6b21a8;padding:2px 8px;border-radius:999px;font-weight:700}
.stem{margin:2px 0 10px}
.stem .hi{font-size:16px}
.stem .en{font-size:14px;color:#4c5563;border-left:3px solid #dbe3f5;padding-left:10px;margin-top:6px}
.opts{list-style:none;margin:0;padding:0;display:grid;gap:7px}
.opts li{border:1px solid var(--line);border-radius:10px;padding:8px 11px;cursor:pointer;background:#fff}
.opts li:hover{border-color:#b9c7ee}
.opts li.sel{border-color:var(--brand);background:var(--brand-soft)}
.opts li.right{border-color:var(--ok);background:#e7f7ee}
.opts li.wrong{border-color:var(--bad);background:#fdeaea}
.opts .k{display:inline-block;min-width:22px;font-weight:700;color:#41507a}
.opts .en{display:block;font-size:13px;color:#4c5563;margin-top:2px}
.mark{margin-top:9px;font-size:12.5px;color:var(--soft);cursor:pointer;user-select:none}
.mark.on{color:#b45309;font-weight:700}
.verdict{margin-top:8px;font-size:13.5px;font-weight:700}
.verdict.ok{color:var(--ok)}.verdict.bad{color:var(--bad)}.verdict.skip{color:var(--soft)}
pre.code{background:#f6f8fc;border:1px solid var(--line);border-radius:8px;padding:8px 10px;overflow:auto;font-size:13.5px}
.result{background:var(--card);border:1px solid var(--line);border-radius:14px;padding:18px;margin:18px 0}
.result h2{margin:0 0 4px}
.score{font-size:34px;font-weight:800;color:var(--brand)}
table{border-collapse:collapse;width:100%;font-size:13.5px;margin-top:8px}
th,td{border:1px solid var(--line);padding:6px 8px;text-align:center}
th{background:#f5f8ff}
.keybox{background:var(--card);border:1px solid var(--line);border-radius:14px;padding:16px;margin:18px 0}
.keybox h2{margin:0 0 10px;font-size:17px}
.kgrid{display:grid;grid-template-columns:repeat(auto-fill,minmax(112px,1fr));gap:6px;font-size:13px}
.kgrid div{border:1px solid var(--line);border-radius:8px;padding:4px 8px;display:flex;justify-content:space-between}
.kgrid b{color:var(--ok)}
footer{color:var(--soft);font-size:12.5px;text-align:center;margin-top:26px}
.printonly{display:none}
body.showkey .paper{display:none}
body.showkey .printonly{display:block}
@media print{
  header.top,.side,.notice,.mark,.langbtns,.act,.noprint{display:none!important}
  body{background:#fff;font-size:12pt}
  .grid{display:block}.wrap{max-width:none;padding:0}
  section.sec,.q,.stim{border:0;border-radius:0;break-inside:avoid;page-break-inside:avoid}
  section.sec{margin:10px 0;border-bottom:1px solid #999}
  .opts li{border:0;padding:2px 0}
  .result{display:none}
}
</style>
</head>
<body>
<header class="top">
  <div class="tt">UTET Paper-I · __MOCK_CODE__<small>असली प्रश्न-पत्रों (2020–2026) से बना मॉक · 150 प्रश्न · 150 अंक</small></div>
  <div class="langbtns" id="langbtns">
    <button data-l="both" class="on">दोनों</button>
    <button data-l="hi">हिन्दी</button>
    <button data-l="en">English</button>
  </div>
  <div class="clock" id="clock">150:00</div>
  <button class="act" id="submit">जमा करो</button>
  <button class="act ghost noprint" onclick="window.print()">प्रिंट</button>
</header>

<div class="wrap">
  <div class="notice" id="notice"></div>

  <div class="intro">
    <h1>उत्तराखण्ड शिक्षक पात्रता परीक्षा (UTET) — पेपर-I (कक्षा I–V)</h1>
    <div class="meta">__MOCK_LABEL__ · बनाया गया __GENERATED__ · स्रोत : bank-v2 (verified PYQ)</div>
    <ol>
      <li>कुल <b>150</b> बहुविकल्पीय प्रश्न, हर प्रश्न <b>1 अंक</b> — कुल <b>150 अंक</b>। समय <b>2 घण्टे 30 मिनट</b>। <b>कोई ऋणात्मक अंकन नहीं</b>।</li>
      <li>खण्ड I बाल विकास एवं शिक्षाशास्त्र (1–30) · खण्ड II हिन्दी भाषा-I (31–60) · खण्ड III अंग्रेज़ी भाषा-II (61–90) · खण्ड IV गणित (91–120) · खण्ड V पर्यावरण अध्ययन (121–150)।</li>
      <li>CDP, गणित और EVS के प्रश्न <b>द्विभाषी</b> (हिन्दी + English) हैं — जैसे असली पेपर में होते हैं। भाषा खण्ड अपनी ही भाषा में हैं।</li>
      <li>हर प्रश्न पर लिखा है कि वह <b>किस साल के असली पेपर</b> से आया है — साल, सेट और उस पेपर में उसकी प्रश्न-संख्या।</li>
      <li class="en">Total 150 MCQs, 1 mark each, 150 marks, 2 hours 30 minutes, no negative marking. Every question is a real previous-year UTET question and carries its source year, set and original question number.</li>
    </ol>
  </div>

  <div class="result noprint" id="result" style="display:none"></div>

  <div class="grid">
    <div class="paper" id="paper"></div>
    <aside class="side noprint">
      <h4>प्रश्न पैलेट</h4>
      <div class="pal" id="pal"></div>
      <div class="legend">
        <div><i style="background:#e7f7ee;border:1px solid #a8e0c0"></i> उत्तर दिया</div>
        <div><i style="background:#fff3e0;border:1px solid #f0c48a"></i> बाद में देखूँगा</div>
        <div><i style="background:#fff;border:1px solid #e3e8f2"></i> खाली</div>
      </div>
      <h4 style="margin-top:14px">स्रोत साल</h4>
      <div class="legend" id="yearlegend"></div>
    </aside>
  </div>

  <div class="keybox noprint">
    <h2>उत्तर कुंजी और स्रोत तालिका / Answer key &amp; source map</h2>
    <div id="keytable"></div>
  </div>

  <div class="printonly">
    <h2>उत्तर कुंजी — __MOCK_CODE__</h2>
    <div id="keyprint"></div>
  </div>

  <footer>
    यह पेपर UTET के असली प्रश्न-पत्रों 2020, 2021, 2022, 2024, 2025 और 2026 के सत्यापित प्रश्नों से बना है।
    अभ्यास के लिए — असली पेपर की नकल नहीं।<br>
    <a href="index.html">← सभी मॉक</a> · जनरेटर : <code>tools/v2/build_utet_mock_html.py</code>
  </footer>
</div>

<script>
const D = /*__DATA__*/null;
const STORE = 'utetmock_' + D.meta.id;
let lang = 'both', review = false;
let state = load();

function load(){
  try{ const s = JSON.parse(localStorage.getItem(STORE) || '{}');
       return {ans:s.ans||{}, flag:s.flag||{}, start:s.start||null, submitted:!!s.submitted, submittedAt:s.submittedAt||null};
  }catch(e){ return {ans:{}, flag:{}, start:null, submitted:false}; }
}
function save(){ localStorage.setItem(STORE, JSON.stringify(state)); }

/* ---- छोटा markdown ---- */
function esc(s){ return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;'); }
function md(t){
  if(t==null) return '';
  const parts = String(t).split('```');
  let out = '', i = 0;
  for(const part of parts){
    if(i % 2 === 1){ out += '<pre class="code">' + esc(part.replace(/^\n/,'').replace(/\n$/,'')) + '</pre>'; }
    else{
      const lines = part.split('\n');
      let html = '', list = false;
      for(const line of lines){
        const m = line.match(/^\s*(\d+)\.\s+(.*)$/);
        if(m){ if(!list){ html += '<ol>'; list = true; } html += '<li>' + inline(m[2]) + '</li>'; }
        else{
          if(list){ html += '</ol>'; list = false; }
          if(line.trim()==='') html += '<div style="height:5px"></div>';
          else html += '<div>' + inline(line) + '</div>';
        }
      }
      if(list) html += '</ol>';
      out += html;
    }
    i++;
  }
  return out;
}
function inline(s){
  return esc(s)
    .replace(/\*\*(.+?)\*\*/g,'<b>$1</b>')
    .replace(/(^|[^*])\*([^*\n]+)\*/g,'$1<i>$2</i>');
}
function dual(o, clsHi, clsEn){
  if(!o) return '';
  if(lang === 'hi' || !o.en) return '<div class="' + clsHi + '">' + md(o.hi || o.en) + '</div>';
  if(lang === 'en' || !o.hi) return '<div class="' + clsHi + '">' + md(o.en || o.hi) + '</div>';
  return '<div class="' + clsHi + '">' + md(o.hi) + '</div><div class="' + clsEn + '">' + md(o.en) + '</div>';
}

const SEC = D.meta.sections;
function yearChip(q){
  return '<span class="src y' + q.y + '">UTET ' + q.y + ' · सेट ' + q.set + ' · मूल प्रश्न ' + q.qno + '</span>';
}

function render(){
  const y0 = window.scrollY;
  const paper = document.getElementById('paper');
  let html = '', lastSec = -1, lastStim = null;
  for(const q of D.q){
    if(q.sec !== lastSec){
      if(lastSec >= 0) html += '</section>';
      const s = SEC[q.sec];
      html += '<section class="sec"><h2>खण्ड ' + s.num + ' : ' + s.hi + ' <span>' + s.en +
              ' &nbsp;·&nbsp; प्रश्न ' + s.from + '–' + s.to + '</span></h2>';
      lastSec = q.sec; lastStim = null;
    }
    if(q.st && q.st !== lastStim){
      const st = D.st[q.st];
      const sy = q.st.split('-')[2];
      const grp = D.q.filter(x => x.st === q.st);
      const lo = Math.min.apply(null, grp.map(x => x.qno));
      const hi = Math.max.apply(null, grp.map(x => x.qno));
      html += '<div class="stim"><div style="margin-bottom:8px">' +
              '<span class="tag">' + (st.ty === 'poem' ? 'कविता / Poem' : 'गद्यांश / Passage') +
              ' · ' + grp.length + ' प्रश्न</span> ' +
              '<span class="src y' + sy + '">UTET ' + sy + ' · सेट ' + q.set + ' · मूल प्रश्न ' +
              lo + (hi !== lo ? '–' + hi : '') + '</span> ' +
              '<span class="tag">' + q.st + '</span></div>';
      if(st.d && (st.d.hi || st.d.en)) html += '<div class="dir">' + dual(st.d,'hi','en') + '</div>';
      html += '<div class="body">' + dual(st.t,'hi','en') + '</div></div>';
      lastStim = q.st;
    }
    const chosen = state.ans[q.n];
    let optHtml = '';
    for(const o of q.o){
      let cls = '';
      if(review){
        if(o.k === q.a) cls = 'right';
        else if(o.k === chosen) cls = 'wrong';
      } else if(o.k === chosen) cls = 'sel';
      optHtml += '<li class="' + cls + '" data-q="' + q.n + '" data-k="' + o.k + '">' +
                 '<span class="k">(' + o.k.toUpperCase() + ')</span> ' + dual(o.t,'hi','en') + '</li>';
    }
    let verdict = '';
    if(review){
      if(!chosen) verdict = '<div class="verdict skip">छोड़ा गया · सही उत्तर (' + q.a.toUpperCase() + ')</div>';
      else if(chosen === q.a) verdict = '<div class="verdict ok">✓ सही · उत्तर (' + q.a.toUpperCase() + ')</div>';
      else verdict = '<div class="verdict bad">✗ गलत · तेरा उत्तर (' + chosen.toUpperCase() +
                     '), सही उत्तर (' + q.a.toUpperCase() + ')</div>';
    }
    html += '<div class="q" id="q' + q.n + '">' +
      '<div class="qhead"><span class="qnum">प्रश्न ' + q.n + '.</span>' + yearChip(q) +
      (q.dup ? '<span class="dup">🔁 ' + q.dup.join(', ') + ' में भी आया</span>' : '') + '</div>' +
      '<div class="stem">' + dual(q.p,'hi','en') + '</div>' +
      '<ul class="opts">' + optHtml + '</ul>' +
      '<div class="mark' + (state.flag[q.n] ? ' on' : '') + '" data-f="' + q.n + '">' +
        (state.flag[q.n] ? '★ बाद में देखूँगा' : '☆ बाद में देखने के लिए चिह्नित करो') + '</div>' +
      verdict + '</div>';
  }
  html += '</section>';
  paper.innerHTML = html;
  renderPalette();
  renderKey();
  wire();
  window.scrollTo(0, y0);
}

function renderPalette(){
  const pal = document.getElementById('pal');
  let html = '';
  for(const q of D.q){
    let cls = '';
    if(state.ans[q.n]) cls = 'done';
    if(state.flag[q.n]) cls = 'flag';
    html += '<button class="' + cls + '" data-go="' + q.n + '">' + q.n + '</button>';
  }
  pal.innerHTML = html;
  let yl = '';
  for(const c of D.meta.cycles){
    yl += '<div><span class="src y' + c.year + '" style="margin-right:6px">' + c.year + '</span>' +
          c.count + ' प्रश्न · सेट ' + c.set + ' · ' + c.date + '</div>';
  }
  document.getElementById('yearlegend').innerHTML = yl;
}

function renderKey(){
  let rows = '<table><tr><th>प्रश्न</th><th>उत्तर</th><th>स्रोत पेपर</th><th>सेट</th><th>मूल प्रश्न संख्या</th><th>प्रश्न-ID</th></tr>';
  for(const q of D.q){
    rows += '<tr><td>' + q.n + '</td><td><b>(' + q.a.toUpperCase() + ')</b></td><td>UTET ' + q.y +
            ' (' + q.date + ')</td><td>' + q.set + '</td><td>' + q.qno + '</td><td style="font-size:11px">' +
            q.id + '</td></tr>';
  }
  rows += '</table>';
  document.getElementById('keytable').innerHTML = rows;
  let g = '<div class="kgrid">';
  for(const q of D.q) g += '<div><span>' + q.n + '</span><b>(' + q.a.toUpperCase() + ')</b></div>';
  document.getElementById('keyprint').innerHTML = g + '</div>';
}

function wire(){
  document.querySelectorAll('.opts li').forEach(li => li.addEventListener('click', () => {
    if(review) return;
    const n = +li.dataset.q, k = li.dataset.k;
    if(state.ans[n] === k) delete state.ans[n]; else state.ans[n] = k;
    if(!state.start){ state.start = Date.now(); save(); tick(); }
    save(); render();
  }));
  document.querySelectorAll('.mark').forEach(el => el.addEventListener('click', () => {
    const n = +el.dataset.f;
    if(state.flag[n]) delete state.flag[n]; else state.flag[n] = 1;
    save(); render();
  }));
  document.querySelectorAll('[data-go]').forEach(b => b.addEventListener('click', () => {
    const el = document.getElementById('q' + b.dataset.go);
    if(el) el.scrollIntoView({behavior:'smooth', block:'center'});
  }));
}

function tick(){
  const el = document.getElementById('clock');
  if(!state.start){ el.textContent = fmt(D.meta.duration*60); return; }
  const left = D.meta.duration*60 - Math.floor((Date.now() - state.start)/1000);
  if(left <= 0){ el.textContent = '00:00'; el.classList.add('low');
    if(!state.submitted) submit(true); return; }
  el.textContent = fmt(left);
  el.classList.toggle('low', left < 300);
}
function fmt(s){ const m = Math.floor(s/60), r = s%60; return String(m).padStart(2,'0') + ':' + String(r).padStart(2,'0'); }

function submit(auto){
  if(state.submitted) return;
  const done = Object.keys(state.ans).length;
  if(!auto && done < D.meta.total &&
     !confirm(done + ' प्रश्नों के उत्तर दिए हैं, ' + (D.meta.total - done) + ' खाली हैं। फिर भी जमा करें?')) return;
  state.submitted = true; state.submittedAt = Date.now(); save();
  review = true; render(); showResult();
  document.getElementById('result').scrollIntoView({behavior:'smooth'});
}

function showResult(){
  const mins = state.start ? Math.round((Date.now() - state.start)/60000) : 0;
  let score = 0, secStat = {}, yearStat = {};
  for(const q of D.q){
    const ok = state.ans[q.n] === q.a;
    if(ok) score++;
    const s = SEC[q.sec].hi;
    secStat[s] = secStat[s] || {c:0,t:0}; secStat[s].t++; if(ok) secStat[s].c++;
    yearStat[q.y] = yearStat[q.y] || {c:0,t:0}; yearStat[q.y].t++; if(ok) yearStat[q.y].c++;
  }
  const pct = Math.round(score / D.meta.total * 100);
  const pass = score >= 90 ? '<span style="color:var(--ok)">उत्तीर्ण स्तर (90/150) पार ✓</span>'
                           : '<span style="color:var(--bad)">उत्तीर्ण स्तर 90/150 — अभी ' + (90-score) + ' और चाहिए</span>';
  let st = '<tr><th>खण्ड</th><th>सही</th><th>कुल</th><th>%</th></tr>';
  for(const s in secStat) st += '<tr><td style="text-align:left">' + s + '</td><td>' + secStat[s].c +
    '</td><td>' + secStat[s].t + '</td><td>' + Math.round(secStat[s].c/secStat[s].t*100) + '%</td></tr>';
  let yt = '<tr><th>स्रोत साल</th><th>सही</th><th>कुल</th><th>%</th></tr>';
  for(const y of Object.keys(yearStat).sort().reverse()) yt += '<tr><td>UTET ' + y + '</td><td>' +
    yearStat[y].c + '</td><td>' + yearStat[y].t + '</td><td>' +
    Math.round(yearStat[y].c/yearStat[y].t*100) + '%</td></tr>';
  document.getElementById('result').innerHTML =
    '<h2>नतीजा ' + (state.submittedAt ? '' : '') + '</h2>' +
    '<div class="score">' + score + ' / ' + D.meta.total + '</div>' +
    '<div>' + pct + '% · समय ' + mins + ' मिनट · ' + pass + '</div>' +
    '<div class="grid" style="grid-template-columns:1fr 1fr;margin-top:12px">' +
      '<div><h4 style="margin:0 0 4px">खण्ड-वार / Section-wise</h4><table>' + st + '</table></div>' +
      '<div><h4 style="margin:0 0 4px">साल-वार / Year-wise</h4><table>' + yt + '</table></div>' +
    '</div>' +
    '<div style="margin-top:12px"><button class="act ghost" onclick="document.body.classList.toggle(\'showkey\')">' +
      'सिर्फ़ उत्तर कुंजी देखो / प्रिंट करो</button> ' +
    '<button class="act ghost" onclick="if(confirm(\'इस मॉक के सारे उत्तर मिटा दें?\')){localStorage.removeItem(STORE);location.reload()}">' +
      'मॉक फिर से दो</button></div>';
}

document.getElementById('submit').addEventListener('click', () => submit(false));
document.getElementById('langbtns').addEventListener('click', e => {
  const b = e.target.closest('button'); if(!b) return;
  lang = b.dataset.l;
  document.querySelectorAll('#langbtns button').forEach(x => x.classList.toggle('on', x === b));
  render();
});
document.getElementById('notice').innerHTML =
  '<b>यह मॉक असली प्रश्नों से बना है।</b> इसमें ' + D.meta.total + ' प्रश्न हैं — हर साल (2020, 2021, 2022, 2024, 2025, 2026) से ' +
  'हर खण्ड में 5-5। हर प्रश्न के नीले टैग पर उसका स्रोत लिखा है। ' +
  '<span class="en">Every question below is a verified previous-year UTET Paper-I question; its source year, set and original number are printed with it.</span>';

if(state.submitted) review = true;
document.getElementById('result').style.display = state.submitted ? '' : 'none';
render();
if(state.submitted) showResult();
tick(); setInterval(tick, 1000);
</script>
</body>
</html>
"""

INDEX_TEMPLATE = r"""<!DOCTYPE html>
<html lang="hi">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>UTET Paper-I — असली PYQ मॉक पेपर</title>
<style>
:root{--bg:#f4f6fb;--card:#fff;--ink:#141a2b;--soft:#5b6479;--line:#e3e8f2;--brand:#1f4fd8}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);font-family:"Noto Sans Devanagari","Nirmala UI",system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;line-height:1.65}
.wrap{max-width:1080px;margin:0 auto;padding:22px 16px 60px}
h1{margin:0 0 4px;font-size:24px}
.sub{color:var(--soft);margin:0 0 18px;font-size:14px}
.box{background:var(--card);border:1px solid var(--line);border-radius:14px;padding:16px 18px;margin-bottom:18px}
.box h2{margin:0 0 8px;font-size:17px}
.box ul{margin:8px 0 0;padding-left:20px;font-size:14.5px}
.cards{display:grid;grid-template-columns:repeat(auto-fill,minmax(320px,1fr));gap:14px}
.card{background:var(--card);border:1px solid var(--line);border-radius:14px;padding:14px 16px;text-decoration:none;color:inherit;display:block;transition:.15s}
.card:hover{border-color:#9fb4ee;transform:translateY(-2px);box-shadow:0 6px 18px rgba(31,79,216,.10)}
.card-top{display:flex;justify-content:space-between;align-items:center;font-size:12px;color:var(--soft)}
.code{background:#eaf0ff;color:#26407f;font-weight:700;padding:2px 9px;border-radius:999px}
.card h3{margin:8px 0 2px;font-size:17px}
.card .sub{font-size:12.5px;margin:0 0 8px}
.chips{display:flex;flex-wrap:wrap;gap:5px;margin-bottom:10px}
.chip{font-size:11.5px;padding:2px 8px;border-radius:999px;background:#eef1f7;color:#40495e;font-weight:600}
.go{color:var(--brand);font-weight:700;font-size:13.5px}
table{border-collapse:collapse;width:100%;font-size:14px}
th,td{border:1px solid var(--line);padding:6px 8px;text-align:center}
th{background:#f5f8ff}
footer{color:var(--soft);font-size:12.5px;text-align:center;margin-top:24px}
code{background:#eef1f7;padding:1px 5px;border-radius:5px;font-size:12.5px}
</style>
</head>
<body>
<div class="wrap">
  <h1>UTET Paper-I — असली PYQ से बने मॉक पेपर</h1>
  <p class="sub">6 पूरे मॉक · कुल __TOTAL__ प्रश्न · सबके सब असली UTET प्रश्न · बनाया गया __GENERATED__</p>

  <div class="box">
    <h2>ये मॉक कैसे बने</h2>
    <ul>
      <li>स्रोत : UTET Paper-I के <b>6 असली प्रश्न-पत्र</b> — 2020, 2021, 2022, 2024, 2025, 2026 (हर साल 150 प्रश्न = कुल 900)।</li>
      <li>हर मॉक बिल्कुल असली पेपर जैसा : <b>150 प्रश्न, 150 अंक, 2 घण्टे 30 मिनट, कोई नेगेटिव मार्किंग नहीं</b>।</li>
      <li>खण्ड : CDP 30 · हिन्दी भाषा-I 30 · English भाषा-II 30 · गणित 30 · पर्यावरण अध्ययन 30।</li>
      <li>हर खण्ड में <b>हर साल से 5-5 प्रश्न</b> — यानी हर मॉक छह साल का मिला-जुला पेपर है।</li>
      <li>गद्यांश/कविता कभी नहीं टूटी — पूरा समूह एक साथ, हर मॉक में ठीक 2 गद्यांश (जैसे असली पेपर में)।</li>
      <li>कोई प्रश्न दो मॉक में नहीं दोहराया गया — 900 के 900 प्रश्न बराबर बँट गए हैं।</li>
      <li>हर प्रश्न पर उसका स्रोत लिखा है : <b>साल · सेट · असली पेपर की प्रश्न-संख्या</b>। पूरी तालिका <code>provenance.csv</code> में भी है।</li>
    </ul>
  </div>

  <div class="cards">__CARDS__</div>

  <div class="box" style="margin-top:18px">
    <h2>साल-वार प्रश्न वितरण</h2>
    <table>
      <tr><th>मॉक</th>__YEAR_HEAD__<th>कुल</th></tr>
      __ROWS__
    </table>
  </div>

  <footer>
    जनरेटर : <code>python3 tools/v2/build_utet_mock_html.py</code> · डेटा : <code>bank-v2/exams/utet/paper-1/</code><br>
    यह अभ्यास सामग्री है, UTET का आधिकारिक पेपर नहीं।
  </footer>
</div>
</body>
</html>
"""


if __name__ == "__main__":
    raise SystemExit(main())

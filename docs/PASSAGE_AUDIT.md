# Passage / Poem Audit — CTET + UTET

_Status after full database scan and repair._

## Summary

- Total question rows scanned: **8049**
- Passage/poem/chart groups: **180**
- Passage-linked questions: **1185**
- Orphan `pid`: **0**
- Unused passage: **0**
- Passage/comprehension topic with blank `pid`: **0**
- 1-question passage/poem groups: **0**
- Language policy: Hindi/English/Sanskrit sections are **single-language only**; CDP/Math/EVS are **dual-language**. Validation in `tools/build.py` enforces this.

## Current passage inventory

| Type | Language | Passages | Questions |
|---|---:|---:|---:|
| chart | HI | 2 | 4 |
| poem | EN | 14 | 75 |
| poem | HI | 33 | 185 |
| prose | EN | 53 | 369 |
| prose | HI | 78 | 552 |
| **Total** |  | **180** | **1185** |

## Repairs completed

| File / lines | Set | Text attached | Paper-accurate question count |
|---|---|---|---:|
| `q_ctet.csv` 2794–2799 | CTET Jan 2021 Hindi poem | “दिशाएँ निमंत्रण मुझे दे रही हैं…” | 6 |
| `q_ctet.csv` 2853–2858 | CTET Hindi bank poem | “शाम — एक किसान” / “आकाश का साफा बाँधकर…” | 6 |
| `q_ctet.csv` 3050–3054 | REET 2021 Hindi poem | “हम पंछी उन्मुक्त गगन के” | 5 |
| `q_ctet.csv` 4239–4244 | CTET Dec 2019 Hindi poem | दिनकर की “हिमालय” कविता का अंश | 6 |
| `q_utet2021.csv` 32–34 | UTET 2021 Hindi prose | भाषा/आधुनिकता गद्यांश | 3 |
| `q_utet2021.csv` 57–61 | UTET 2021 Hindi poem | निराला “बादल-राग” / “चल रे चल मेरे पागल बादल” | 5 |
| `q_utet2021.csv` 72–76 | UTET 2021 English prose | Education: general vs specialised knowledge | 5 |
| `q_utet2021.csv` 77–81 | UTET 2021 English poem | Tennyson, “The Charge of the Light Brigade” | 5 |
| `q_utet2021.csv` 97–101 | UTET 2021 Hindi prose | प्रकृति–मनुष्य / पर्यावरण गद्यांश | 5 |
| `q_utet2021.csv` 110–114 | UTET 2021 Hindi prose | राष्ट्रीयता और भाषा-तत्त्व गद्यांश | 5 |
| `q_utet2021.csv` 130–134 | UTET 2021 English prose | Stammering passage | 5 |
| `q_utet2021.csv` 135–139 | UTET 2021 English prose | Great War and Indian literature passage | 5 |

## Converter off-by-one cleanup

The md→csv converter had copied the next passage body onto the previous pedagogy row (usually Q90/Q30). These fake links were removed while keeping the real neighbouring passage groups intact:

`CT35a5fa41`, `CT672b9bc0`, `CTfd4ac714`, `CT6e20505b`, `CT742ed581`, `CT1051ce40`, `CTe8f2658a`, `CT309083b7`, `CTaca68a2a`, `CT11ed4b10`, `CT62927b2b`, `CT76710910`, `CT84d922ae`, `CT90ee4281`, `CT98837974`

## Remaining short groups

| pid | Type | Questions | Note |
|---|---|---:|---|
| CT8b1ce257 | prose | 2 | Hindi bank/environment excerpt has exactly Q125–Q126 here; same passage is also used in UTET 2021 as a separate paper set. |
| CT936a01ad | prose | 2 | Hindi bank excerpt has exactly Q31–Q32. |
| CTdaafd991 | poem | 2 | Two-line verse item has exactly Q33–Q34. |
| P005 | chart | 2 | Practice pie-chart item; 2 questions by design. |
| P010 | chart | 2 | Practice bar-chart item; 2 questions by design. |

## Build validation now enforced

- `hindi`, `english`, `sanskrit`: `q_en/a_en/b_en/c_en/d_en` must be blank.
- `cdp`, `math`, `evs`: English question/options must be filled.
- Any topic marked as `अपठित`, `गद्यांश`, `पद्यांश`, `काव्यांश`, `Comprehension`, `Passage`, or `Poem` must have a `pid`.
- Any one-question passage group is warned for manual review.

Latest build: `python3 tools/build.py` passes cleanly.

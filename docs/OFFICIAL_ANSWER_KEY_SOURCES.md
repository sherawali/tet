# Official CBSE/CTET answer keys — where they live and how to read them

The bank used to carry keys that were invented by the importers: whole 15-question
language sections had a single answer (option `a`) for every question. `audit_answer_keys.py`
reports those. The replacements below are the exam authority's own PDFs.

## Where

`https://ctet.nic.in/previous-year-final-answer-key/`

That page links **straight** to
`https://cdnbbsr.s3waas.gov.in/s3443dec3062d0286986e21dc0631734c9/uploads/<YYYY>/<MM>/<id>.pdf`,
which is fetchable. The *question papers* on the sibling page are Google Drive links and are
not. The `<YYYY>/<MM>/` part is required — without it S3 returns `NoSuchBucket`.

One PDF per exam date covers every set code. Each PDF is roughly 100+ pages: a 1–90 table per
set, then the 91–150 tables in the same set order, one table per language.

A 91–150 table is **60 questions wide, one per language, not per slot**: 91–120 is the
language-I half and 121–150 the language-II half. The tables are headed
`Set :- B PAPER-I-01-English` / `Set :- B PAPER-I-02-Hindi` and so on — `01`/`02` is the
language, not the slot. Splitting one table into the two slots was confirmed on Feb-2026
because the 121–128 English values match an independent Part-V (Language II) table exactly,
and because the 106–120 pedagogy range is identical in the English and Hindi tables, which is
what you would expect if both slots draw their pedagogy items from the same pool.

## Files found so far

| Paper | Date | PDF |
|---|---|---|
| P1 | 21 Jan 2024 | `uploads/2024/02/2024021954.pdf` — **applied** |
| P1 | 08 Feb 2026 | `uploads/2026/04/20260401449979389.pdf` — Set B confirmed, **not yet applied** |

Sibling files on the same index page: P2 Jan-2024 `2024/02/2024021970.pdf`, P1 Jul-2024
`2024/08/2024080797.pdf`, P2 Jul-2024 `2024/08/2024080769.pdf`, P1 Dec-2024
`2025/01/2025012321.pdf`, P2 Dec-2024 `2025/01/2025012315.pdf`, P1 Aug-2023
`2023/09/2023092672.pdf`, P2 Aug-2023 `2023/09/2023092617.pdf`, Dec-2022
`2023/03/2023030346.pdf`, P1 07-Feb-2026 `2026/04/20260401145739613.pdf`, P1 01-Mar-2026
`2026/04/202604011664019376.pdf`, P2 08-Feb-2026 `2026/04/20260401628564007.pdf`.

## How to read a table

`A=1,2 / B=1,3 / C=1,4 / D=2,3 / E=2,4 / F=3,4 / Z=ALL`

A letter means several options were accepted. **Do not store a letter as if it were one
option** — `apply_stimulus_sources.py` skips those questions rather than guessing.

## Which table is ours

The tables are not labelled by language inside the PDF, so a table has to be identified before
it is trusted. Two independent checks were used for 21 Jan 2024:

1. Its language-2 english 121–128 = `d,c,a,d,d,a,b,d` and language-2 hindi 121–128 =
   `d,a,d,a,a,d,a,a`, which match the Oswaal solved paper exactly (15/15).
2. Its hindi-II Q124 answer is option (1), and option (1) is the only one supported by the
   passage (`करीब चालीस करोड़`).

Third-party keys (Oswaal, cbseguidanceweb) disagree with the official PDF on some questions —
for example Oswaal gives Jan-2024 Q91 = 2 where the official key says 1. **The official PDF
wins**; third-party material is only used to *locate* the right table.

Do not read the set letter off the bank. The bank's own set token is unrelated to CBSE's: the
2026 cycle is stored as `ctet-p1-2026-e-…` with `setCode: "e"`, while CBSE calls that same
paper **Set B**. The bank's token only has to match its own question ids, which is what
`apply_stimulus_sources.py` keys the answer tables on.

## Status

| Cycle | Key source | Applied |
|---|---|---|
| ctet-p1-2024 | official, Jan-2024 PDF, table identified by the two checks above | yes — 67 answers corrected across all six language sections |
| ctet-p1-2026 | official, 08-Feb-2026 PDF, Set B; its 1–90 table matched 90/90 and its 121–128 English values matched the independent Part-V table exactly | yes — 38 answers corrected; English Q122 left alone because the key codes it `C` (options 1 and 4) |
| ctet-p1-2018 | official key exists on the same index page but has not been fetched | no — `language-1/english` and `language-2/english` are still uniform |
| everything else | none | no |

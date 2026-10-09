# bank-v2/sources/stimuli — verified passage and poem text

Passage and poem bodies are **not** authored here. They are transcribed from the actual
question paper, and every file records where the text came from. This exists because
`tools/v2/import_all_ctet.py` shipped placeholder bodies for seven cycles (see
`docs/STIMULUS_LINK_AUDIT.md`), which made a passage and its questions disagree.

## Workflow

1. Open the paper for one cycle. `ctet.nic.in` links to Google Drive copies; those are not
   always fetchable, so a full solved-paper PDF on another host works too — record the URL.
2. Create `<cycle>.json` (e.g. `ctet-p1-2024.json`) with one entry per stimulus, naming the
   existing stimulus **id** (find it with `grep -n '"type"' bank-v2/exams/.../stimuli.ndjson`
   or `python3 tools/v2/validate_stimulus_groups.py --verbose`).
3. `python3 tools/v2/apply_stimulus_sources.py --check` — shows the diff, writes nothing.
4. `python3 tools/v2/apply_stimulus_sources.py` — replaces the body, sets
   `review.textVerified`, and stamps `sourceRef` on the stimulus.
5. `python3 tools/v2/audit_stimulus_links.py` — a correct transcription drops the block from
   `wrong-passage` to `ok`. That is the check that the text is the right text.
6. Rebuild: `build_app_db.py`, then `build_cdn_packs.py --prune`.

## File format

```json
{
  "schemaVersion": 1,
  "id": "ctet-p1-2024-stimulus-sources",
  "exam": "ctet", "paper": 1, "cycleLabel": "2024", "examDate": "2024-01-21", "setCode": "I",
  "provenance": {
    "retrieved": "2026-10-09",
    "source": "human-readable description of the document",
    "url": "https://...",
    "officialArchive": "https://ctet.nic.in/question-paper-january-2024/",
    "method": "how the text was obtained",
    "caveat": "known weaknesses of this transcription"
  },
  "stimuli": [
    {
      "stimulusId": "ctet-p1-2024-stimulus-hi-pr-121",
      "section": "language-2/hindi",
      "language": "hi",
      "languageSlot": 2,
      "type": "prose",
      "questionRange": [121, 128],
      "instructions": "निर्देश (121-128): …",
      "text": "the passage exactly as printed",
      "note": "anything the reviewer must know"
    }
  ]
}
```

`apply_stimulus_sources.py` refuses to run if a `stimulusId` does not exist in the bank, so a
typo cannot silently create an orphan.

## Rules

- One cycle per file; fill one cycle completely before starting the next.
- Never paraphrase, fix, or "improve" the paper's text. OCR artefacts are noted in
  `provenance.caveat` rather than silently corrected.
- Devanagari OCR is unreliable. A block only counts as fixed when the audit moves it to `ok`.
- If the real text contradicts the stored answer key, record it in the entry's `note` — do not
  quietly change the answer. See `ctet-p1-2024.json` → `hi-pr-121` (Q124) for an example.

## Status

| cycle | stimuli with verified text | placeholders left |
|---|---|---|
| ctet-p1-2024 | 2 (`hi-pr-121`, `hi-pr-129`) | 107 across all cycles |

`python3 tools/v2/apply_stimulus_sources.py --check` prints the current counts.

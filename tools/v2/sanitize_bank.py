#!/usr/bin/env python3
"""Safely sanitize display text in the TET V2 source bank.

The batch is deterministic and idempotent. It edits only localized display text
in question prompts/options/explanations, stimulus content, and paper-form titles.
IDs, answer keys, option order, appearances, paper forms, audit evidence, and
source provenance are kept intact. Files are staged and atomically replaced only
after every input has parsed and every output has passed the invariants below.
"""
from __future__ import annotations

import argparse
import copy
import json
import os
import stat
import tempfile
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable

from text_sanitizer import (
    sanitize_display_text,
    sanitize_option_text,
    sanitize_question_stem,
    sanitize_stimulus_text,
    strip_redundant_option_prefix,
)

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_BANK = REPO_ROOT / "bank-v2"


@dataclass
class FilePlan:
    path: Path
    original: str
    updated: str
    mode: int
    kind: str
    records: int
    records_changed: int
    staged_path: Path | None = None


def _sanitize_text_map(
    value: Any,
    sanitizer: Callable[[Any], str],
    stats: Counter[str],
    stat_key: str,
) -> None:
    if not isinstance(value, dict):
        return
    for locale, old_text in list(value.items()):
        if not isinstance(old_text, str):
            continue
        new_text = sanitizer(old_text)
        if new_text != old_text:
            value[locale] = new_text
            stats[stat_key] += 1


def sanitize_question_record(question: dict[str, Any], stats: Counter[str]) -> dict[str, Any]:
    result = copy.deepcopy(question)

    for block in result.get("prompt", []) if isinstance(result.get("prompt"), list) else []:
        if isinstance(block, dict):
            _sanitize_text_map(block.get("text"), sanitize_question_stem, stats, "question_stem_texts_changed")

    options = result.get("options", [])
    if isinstance(options, list):
        for index, option in enumerate(options):
            if not isinstance(option, dict):
                continue
            content = option.get("content", [])
            if not isinstance(content, list):
                continue
            for block in content:
                if not isinstance(block, dict):
                    continue
                text_map = block.get("text")
                if not isinstance(text_map, dict):
                    continue
                for locale, old_text in list(text_map.items()):
                    if not isinstance(old_text, str):
                        continue
                    cleaned = sanitize_display_text(old_text)
                    without_prefix = strip_redundant_option_prefix(
                        cleaned, option.get("id"), index
                    )
                    if without_prefix != cleaned:
                        stats["option_prefixes_removed"] += 1
                    new_text = sanitize_option_text(old_text, option.get("id"), index)
                    if new_text != old_text:
                        text_map[locale] = new_text
                        stats["option_texts_changed"] += 1

    explanation = result.get("explanation")
    if isinstance(explanation, list):
        for block in explanation:
            if isinstance(block, dict):
                _sanitize_text_map(
                    block.get("text"), sanitize_display_text, stats, "explanation_texts_changed"
                )

    # Content-bearing structures are immutable apart from their text values.
    assert result.get("id") == question.get("id")
    assert result.get("answer") == question.get("answer")
    before_options = question.get("options", [])
    after_options = result.get("options", [])
    assert len(after_options) == len(before_options)
    assert [o.get("id") for o in after_options] == [o.get("id") for o in before_options]
    return result


def _sanitize_stimulus_table(block: dict[str, Any], stats: Counter[str]) -> None:
    if isinstance(block.get("caption"), dict):
        _sanitize_text_map(block["caption"], sanitize_display_text, stats, "stimulus_texts_changed")

    columns = block.get("columns", [])
    if isinstance(columns, list):
        for column in columns:
            if isinstance(column, dict) and isinstance(column.get("header"), dict):
                _sanitize_text_map(
                    column["header"], sanitize_display_text, stats, "stimulus_texts_changed"
                )

    rows = block.get("rows", [])
    if isinstance(rows, list):
        for row in rows:
            cells = row.get("cells") if isinstance(row, dict) else None
            if isinstance(cells, dict):
                for cell in cells.values():
                    if isinstance(cell, dict):
                        _sanitize_text_map(
                            cell, sanitize_display_text, stats, "stimulus_texts_changed"
                        )


def sanitize_stimulus_record(stimulus: dict[str, Any], stats: Counter[str]) -> dict[str, Any]:
    result = copy.deepcopy(stimulus)
    for field in ("title", "instructions"):
        if isinstance(result.get(field), dict):
            _sanitize_text_map(
                result[field], sanitize_display_text, stats, "stimulus_texts_changed"
            )

    content = result.get("content", [])
    if isinstance(content, list):
        for block in content:
            if not isinstance(block, dict):
                continue
            if block.get("kind") == "table":
                _sanitize_stimulus_table(block, stats)
                continue
            for field in ("text", "alt", "caption"):
                if isinstance(block.get(field), dict):
                    sanitizer = sanitize_stimulus_text if field == "text" else sanitize_display_text
                    _sanitize_text_map(
                        block[field], sanitizer, stats, "stimulus_texts_changed"
                    )

    assert result.get("id") == stimulus.get("id")
    assert result.get("selectionPolicy") == stimulus.get("selectionPolicy")
    assert len(result.get("content", [])) == len(stimulus.get("content", []))
    return result


def sanitize_form_record(form: dict[str, Any], stats: Counter[str]) -> dict[str, Any]:
    result = copy.deepcopy(form)
    if isinstance(result.get("title"), dict):
        _sanitize_text_map(result["title"], sanitize_display_text, stats, "form_titles_changed")
    assert result.get("id") == form.get("id")
    assert result.get("modules") == form.get("modules")
    return result


def _sanitize_record(record: dict[str, Any], kind: str, stats: Counter[str]) -> dict[str, Any]:
    if kind == "questions":
        return sanitize_question_record(record, stats)
    if kind == "stimuli":
        return sanitize_stimulus_record(record, stats)
    if kind == "forms":
        return sanitize_form_record(record, stats)
    return record


def _ndjson_kind(path: Path) -> str | None:
    if path.name == "questions.ndjson":
        return "questions"
    if path.name == "stimuli.ndjson":
        return "stimuli"
    if path.name == "forms.ndjson":
        return "forms"
    return None


def _plan_ndjson(path: Path, kind: str | None, stats: Counter[str]) -> tuple[FilePlan | None, int]:
    original = path.read_text(encoding="utf-8")
    records_out: list[str] = []
    record_count = 0
    input_ids: list[Any] = []
    output_ids: list[Any] = []
    changed_records = 0

    for line_no, raw in enumerate(original.splitlines(), start=1):
        if not raw.strip():
            records_out.append(raw)
            continue
        try:
            value = json.loads(raw)
        except json.JSONDecodeError as exc:
            raise ValueError(f"{path}:{line_no}: invalid NDJSON: {exc}") from exc
        if not isinstance(value, dict):
            raise ValueError(f"{path}:{line_no}: NDJSON row must be a JSON object")

        record_count += 1
        record_id = value.get("id", value.get("questionId", value.get("key")))
        input_ids.append(record_id)
        updated = _sanitize_record(value, kind or "", stats)
        output_ids.append(updated.get("id", updated.get("questionId", updated.get("key"))))
        if updated == value:
            records_out.append(raw)
        else:
            records_out.append(json.dumps(updated, ensure_ascii=False, separators=(",", ":")))
            changed_records += 1

    if input_ids != output_ids:
        raise AssertionError(f"{path}: sanitization changed record identity or order")

    newline = "\r\n" if "\r\n" in original else "\n"
    updated_text = newline.join(records_out)
    if original.endswith(("\n", "\r")) and records_out:
        updated_text += newline

    if updated_text == original:
        return None, record_count

    return (
        FilePlan(
            path=path,
            original=original,
            updated=updated_text,
            mode=stat.S_IMODE(path.stat().st_mode),
            kind=kind or "other",
            records=record_count,
            records_changed=changed_records,
        ),
        record_count,
    )


def _stage_file(path: Path, contents: str, mode: int) -> Path:
    fd, tmp_name = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".sanitize-tmp", dir=path.parent)
    tmp_path = Path(tmp_name)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="") as target:
            target.write(contents)
            target.flush()
            os.fsync(target.fileno())
        os.chmod(tmp_path, mode)
        return tmp_path
    except Exception:
        try:
            tmp_path.unlink()
        except FileNotFoundError:
            pass
        raise


def _commit_plans(plans: list[FilePlan]) -> None:
    staged: list[FilePlan] = []
    replaced: list[FilePlan] = []
    try:
        for plan in plans:
            plan.staged_path = _stage_file(plan.path, plan.updated, plan.mode)
            staged.append(plan)
        for plan in plans:
            assert plan.staged_path is not None
            os.replace(plan.staged_path, plan.path)
            plan.staged_path = None
            replaced.append(plan)
    except Exception:
        # Best-effort rollback from the already-read originals if a later atomic
        # rename fails. Each individual replacement is atomic on the same volume.
        for plan in reversed(replaced):
            restore_path = _stage_file(plan.path, plan.original, plan.mode)
            os.replace(restore_path, plan.path)
        raise
    finally:
        for plan in staged:
            if plan.staged_path is not None:
                try:
                    plan.staged_path.unlink()
                except FileNotFoundError:
                    pass


def _verify_source_json(bank: Path) -> int:
    source_dir = bank / "sources"
    if not source_dir.exists():
        return 0
    count = 0
    for path in sorted(source_dir.glob("*.json")):
        try:
            json.loads(path.read_text(encoding="utf-8"))
        except Exception as exc:
            raise ValueError(f"{path}: invalid source/provenance JSON: {exc}") from exc
        count += 1
    return count


def run(bank: Path, *, dry_run: bool = False) -> tuple[Counter[str], list[FilePlan]]:
    if not bank.is_dir():
        raise FileNotFoundError(f"bank directory not found: {bank}")

    stats: Counter[str] = Counter()
    plans: list[FilePlan] = []
    ndjson_files = sorted(bank.rglob("*.ndjson"))
    for path in ndjson_files:
        plan, rows = _plan_ndjson(path, _ndjson_kind(path), stats)
        kind = _ndjson_kind(path) or "other"
        stats[f"{kind}_files_scanned"] += 1
        stats[f"{kind}_records_scanned"] += rows
        if plan is not None:
            plans.append(plan)
            stats[f"{kind}_files_changed"] += 1
            stats[f"{kind}_records_changed"] += plan.records_changed

    stats["source_json_files_verified"] = _verify_source_json(bank)
    stats["ndjson_files_verified"] = len(ndjson_files)
    stats["files_changed"] = len(plans)

    if not dry_run and plans:
        _commit_plans(plans)
    return stats, plans


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bank", type=Path, default=DEFAULT_BANK, help="bank-v2 directory")
    parser.add_argument(
        "--check",
        action="store_true",
        help="report pending changes without writing files (exit 1 if changes are needed)",
    )
    args = parser.parse_args()

    stats, plans = run(args.bank.resolve(), dry_run=args.check)
    print(json.dumps(dict(sorted(stats.items())), ensure_ascii=False, indent=2))
    if plans:
        print("Changed files:")
        for plan in plans:
            print(f" - {plan.path.relative_to(args.bank.resolve())} ({plan.records} records)")
    if args.check and plans:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

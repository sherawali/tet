#!/usr/bin/env python3
"""Recover text and metadata from public CTET December-2021 PDF mirrors.

This tool is intentionally source-only: it does not write questions, forms,
appearances, stimuli, or answers into the V2 bank. The Arena sandbox cannot
negotiate TLS with several source CDNs, so the branch workflow runs this script
on a GitHub-hosted runner and returns only compact text/metadata derivatives.
Source PDFs stay in the runner's temporary directory and are never committed.
"""

from __future__ import annotations

import hashlib
import json
import re
import tempfile
import time
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

import fitz  # PyMuPDF
import requests

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "bank-v2/sources/ctet-p1-2021-2022-cbt-cycle.json"
OUTPUT = ROOT / "bank-v2/source-recovery/ctet-p1-2021-2022"
USER_AGENT = (
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36"
)


def slug(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")


def download(session: requests.Session, url: str, destination: Path) -> tuple[int, str]:
    last_error: Exception | None = None
    for attempt in range(1, 4):
        try:
            with session.get(url, timeout=(30, 180), stream=True) as response:
                response.raise_for_status()
                digest = hashlib.sha256()
                size = 0
                with destination.open("wb") as handle:
                    for chunk in response.iter_content(chunk_size=1024 * 1024):
                        if not chunk:
                            continue
                        handle.write(chunk)
                        digest.update(chunk)
                        size += len(chunk)
                if destination.read_bytes()[:5] != b"%PDF-":
                    raise ValueError(f"Downloaded body is not a PDF: {url}")
                return size, digest.hexdigest()
        except Exception as exc:  # retry public mirrors transiently
            last_error = exc
            if attempt < 3:
                time.sleep(attempt * 2)
    assert last_error is not None
    raise last_error


def extract_pdf(pdf_path: Path, text_path: Path) -> dict[str, Any]:
    document = fitz.open(pdf_path)
    page_texts: list[str] = []
    image_counts: list[int] = []
    pages_with_text = 0
    for page_index, page in enumerate(document):
        text = page.get_text("text", sort=True).replace("\x00", "")
        pages_with_text += bool(text.strip())
        page_texts.append(f"===== PDF PAGE {page_index + 1} =====\n{text.rstrip()}\n")
        image_counts.append(len(page.get_images(full=True)))
    text_path.parent.mkdir(parents=True, exist_ok=True)
    text_path.write_text("\n".join(page_texts), encoding="utf-8")
    full_text = "\n".join(page_texts)
    question_numbers = [int(value) for value in re.findall(r"Question Number\s*:\s*(\d+)", full_text)]
    question_ids = re.findall(r"Question Id\s*:\s*(\d+)", full_text)
    metadata = {key: value for key, value in document.metadata.items() if value}
    result = {
        "pageCount": document.page_count,
        "metadata": metadata,
        "textCharacters": len(full_text),
        "pagesWithText": pages_with_text,
        "embeddedImageCount": sum(image_counts),
        "pagesWithEmbeddedImages": sum(value > 0 for value in image_counts),
        "questionNumberOccurrences": len(question_numbers),
        "questionNumberMinimum": min(question_numbers) if question_numbers else None,
        "questionNumberMaximum": max(question_numbers) if question_numbers else None,
        "uniqueQuestionIdCount": len(set(question_ids)),
        "frontMatterText": "\n".join(page_texts[:3])[:12_000],
    }
    document.close()
    return result


def source_entries(manifest: dict[str, Any]) -> list[dict[str, str]]:
    entries: list[dict[str, str]] = []
    seen: set[tuple[str, str, str]] = set()
    for form in manifest["forms"]:
        for source_name in ("preppCatalogPdf", "collegeDekhoPdfMirror"):
            url = form.get(source_name)
            if url:
                key = (form["date"], source_name, url)
                if key not in seen:
                    seen.add(key)
                    entries.append({"date": form["date"], "source": source_name, "url": url})
        for number, mirror in enumerate(form.get("additionalPaperMirrors", []), start=1):
            url = mirror["url"]
            source_name = mirror.get("id") or f"additional-{number}"
            key = (form["date"], source_name, url)
            if key not in seen:
                seen.add(key)
                entries.append({"date": form["date"], "source": source_name, "url": url})
    for source_name in ("paper1EnglishMediumFinalKey", "paper1HindiMediumFinalKey"):
        entries.append(
            {
                "date": "cycle",
                "source": source_name,
                "url": manifest["officialDocuments"][source_name],
            }
        )
    return entries


def main() -> int:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    OUTPUT.mkdir(parents=True, exist_ok=True)
    session = requests.Session()
    session.headers.update({"User-Agent": USER_AGENT, "Accept": "application/pdf,*/*;q=0.8"})
    recovered: list[dict[str, Any]] = []
    failures: list[dict[str, str]] = []

    with tempfile.TemporaryDirectory(prefix="ctet-2021-recovery-") as temporary:
        temporary_root = Path(temporary)
        for index, entry in enumerate(source_entries(manifest), start=1):
            date = entry["date"]
            source_name = entry["source"]
            url = entry["url"]
            base_name = f"{date}--{slug(source_name)}"
            pdf_path = temporary_root / f"{base_name}.pdf"
            text_path = OUTPUT / "text" / f"{base_name}.txt"
            print(f"[{index}] recovering {date} {source_name}: {url}", flush=True)
            try:
                size, sha256 = download(session, url, pdf_path)
                details = extract_pdf(pdf_path, text_path)
                recovered.append(
                    {
                        "date": date,
                        "source": source_name,
                        "url": url,
                        "bytes": size,
                        "sha256": sha256,
                        "textPath": str(text_path.relative_to(ROOT)),
                        **details,
                    }
                )
                print(
                    f"    OK {size} bytes, {details['pageCount']} pages, "
                    f"{details['textCharacters']} text chars",
                    flush=True,
                )
            except Exception as exc:
                failures.append(
                    {
                        "date": date,
                        "source": source_name,
                        "url": url,
                        "error": f"{type(exc).__name__}: {exc}",
                    }
                )
                print(f"    FAILED {type(exc).__name__}: {exc}", flush=True)

    index_document = {
        "schemaVersion": 1,
        "cycleSourceManifest": str(MANIFEST.relative_to(ROOT)),
        "purpose": "Source matching and transcription only; no recovered row is imported by this process.",
        "sourcePdfRetention": "not-retained",
        "recoveredCount": len(recovered),
        "failureCount": len(failures),
        "documents": recovered,
        "failures": failures,
    }
    (OUTPUT / "recovery-index.json").write_text(
        json.dumps(index_document, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Recovered {len(recovered)} documents; failures={len(failures)}")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())

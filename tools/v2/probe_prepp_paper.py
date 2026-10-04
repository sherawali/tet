#!/usr/bin/env python3
"""Probe a Prepp paper page from GitHub Actions.

The local Arena sandbox cannot complete TLS handshakes with the Prepp CDN. This
small diagnostic is therefore intended for the workflow-dispatch recovery job in
.github/workflows/build.yml. It records only public request metadata and short
JSON response summaries; it never logs cookies, headers, or browser storage.
"""

from __future__ import annotations

import json
import os
import re
import sys
from collections import OrderedDict
from typing import Any

from playwright.sync_api import Response, sync_playwright

DEFAULT_URL = (
    "https://prepp.in/paper/"
    "ctet-paper-1-question-paper-31-dec-2021-eng-hin-skt-6632ed350368feeaa568fd52"
)


def compact(value: Any, limit: int = 1200) -> str:
    rendered = json.dumps(value, ensure_ascii=False, separators=(",", ":"))
    return rendered if len(rendered) <= limit else rendered[:limit] + "…"


def main() -> int:
    url = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("PROBE_URL", DEFAULT_URL)
    seen: OrderedDict[str, tuple[int, str]] = OrderedDict()
    json_summaries: list[tuple[str, str]] = []

    def on_response(response: Response) -> None:
        request = response.request
        resource_type = request.resource_type
        content_type = (response.headers.get("content-type") or "").lower()
        if resource_type in {"xhr", "fetch"} or "json" in content_type:
            seen[response.url] = (response.status, content_type)
            if "json" in content_type:
                try:
                    value = response.json()
                    if isinstance(value, dict):
                        summary: Any = {
                            "keys": sorted(value.keys()),
                            "sample": value,
                        }
                    elif isinstance(value, list):
                        summary = {
                            "length": len(value),
                            "sample": value[:2],
                        }
                    else:
                        summary = value
                    json_summaries.append((response.url, compact(summary)))
                except Exception as exc:  # diagnostic only
                    json_summaries.append((response.url, f"<JSON read failed: {exc}>"))

    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(headless=True)
        page = browser.new_page(viewport={"width": 1440, "height": 1000})
        page.on("response", on_response)
        print(f"PROBE_URL {url}")
        response = page.goto(url, wait_until="domcontentloaded", timeout=120_000)
        print(f"DOCUMENT_STATUS {response.status if response else 'none'}")

        print("\n=== DIRECT PUBLIC ASSET PROBES ===")
        asset_urls = [
            "https://cdn-images.prepp.in/public/image/5f35b2a7c7b5f3b16df5310073243304.pdf",
            "https://static.collegedekho.com/media/django-summernote/2022-01-29/bc744b3c-3428-4071-b3d6-a018fffcb9de.pdf",
            "https://blogmedia.testbook.com/blog/wp-content/uploads/2022/12/ctet-paper-1-5th-jan-2022-english-hindi-15499e82.pdf",
            "https://cdnbbsr.s3waas.gov.in/s3443dec3062d0286986e21dc0631734c9/uploads/2022/08/2022082370.pdf",
        ]
        for asset_url in asset_urls:
            try:
                asset_response = page.request.get(asset_url, timeout=120_000)
                body = asset_response.body()
                print(
                    f"{asset_response.status}\t{len(body)}\t"
                    f"{asset_response.headers.get('content-type', '')}\t"
                    f"{body[:8]!r}\t{asset_url}"
                )
            except Exception as exc:
                print(f"ERROR\t{type(exc).__name__}: {exc}\t{asset_url}")

        try:
            page.wait_for_load_state("networkidle", timeout=60_000)
        except Exception as exc:
            print(f"NETWORK_IDLE {type(exc).__name__}: {exc}")
        page.wait_for_timeout(5_000)

        print("\n=== XHR/FETCH/JSON RESPONSES ===")
        for response_url, (status, content_type) in seen.items():
            print(f"{status}\t{content_type}\t{response_url}")

        print("\n=== JSON SUMMARIES ===")
        for response_url, summary in json_summaries:
            print(f"URL {response_url}\n{summary}")

        print("\n=== SCRIPT SOURCES ===")
        for src in page.locator("script[src]").evaluate_all("els => els.map(e => e.src)"):
            print(src)

        print("\n=== PERFORMANCE RESOURCES CONTAINING API/QUESTION/PAPER ===")
        resources = page.evaluate(
            "performance.getEntriesByType('resource').map(e => e.name)"
        )
        for resource in resources:
            if re.search(r"api|question|paper|test|quiz", resource, re.I):
                print(resource)

        print("\n=== NEXT DATA KEYS ===")
        next_data = page.evaluate(
            "typeof window.__NEXT_DATA__ === 'undefined' ? null : window.__NEXT_DATA__"
        )
        print(compact(next_data, limit=8_000))

        print("\n=== VISIBLE CONTROLS ===")
        controls = page.locator("button, a, [role=button]").evaluate_all(
            "els => els.map(e => ({tag:e.tagName,text:(e.innerText||e.textContent||'').trim(),"
            "href:e.href||'',aria:e.getAttribute('aria-label')||''}))"
            ".filter(x => x.text || x.aria).slice(0,500)"
        )
        print(compact(controls, limit=20_000))

        print("\n=== BODY TEXT PREFIX ===")
        body_text = page.locator("body").inner_text(timeout=30_000)
        print(body_text[:20_000])
        browser.close()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

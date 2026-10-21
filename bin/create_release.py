"""Creates the GitHub release for the v20 build.

The notes are read as UTF-8 and written to a JSON file, so the Devanagari
text survives the trip to the API.
"""
import json
import os
import subprocess
import sys
from pathlib import Path

REPO = "sherawali/tet"
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "build" / "_release"


def token() -> str:
    request = "protocol=https\nhost=github.com\n\n"
    result = subprocess.run(
        ["git", "credential", "fill"],
        input=request,
        capture_output=True,
        text=True,
    )
    for line in result.stdout.splitlines():
        if line.startswith("password="):
            return line.split("=", 1)[1].strip()
    raise SystemExit("no token found in the git credential helper")


def api(method: str, path: str, payload=None):
    import urllib.error
    import urllib.request

    url = f"https://api.github.com/repos/{REPO}{path}"
    data = None
    headers = {
        "Authorization": f"Bearer {token()}",
        "Accept": "application/vnd.github+json",
        "User-Agent": "tet-app",
        "X-GitHub-Api-Version": "2022-11-28",
    }
    if payload is not None:
        data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        headers["Content-Type"] = "application/json; charset=utf-8"
    request = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        print(f"HTTP {error.code}: {error.read().decode('utf-8', 'replace')}")
        raise SystemExit(1)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    notes = (ROOT / "RELEASE_NOTES_v20.md").read_text(encoding="utf-8")

    existing = api("GET", "/releases")
    release = next((r for r in existing if r["tag_name"] == "v20"), None)

    if release is None:
        release = api(
            "POST",
            "/releases",
            {
                "tag_name": "v20",
                "target_commitish": "main",
                "name": "TET App v20 - offline question bank",
                "body": notes,
                "draft": True,
                "prerelease": False,
            },
        )
        print(f"draft release created: {release['html_url']}")
    else:
        print(f"release already there: {release['html_url']}")

    # Upload the APK when it exists.
    apk = ROOT / "build" / "app" / "outputs" / "flutter-apk" / "app-release.apk"
    if not apk.exists():
        print("no release APK yet - skipping the upload")
        return
    if any(a["name"] == apk.name for a in release["assets"]):
        print("APK already uploaded")
        return

    url = (
        f"https://uploads.github.com/repos/{REPO}/releases/"
        f"{release['id']}/assets?name={apk.name}"
    )
    request = subprocess.run(
        [
            "curl.exe", "-sS", "-X", "POST", url,
            "-H", f"Authorization: Bearer {token()}",
            "-H", "Content-Type: application/vnd.android.package-archive",
            "--data-binary", f"@{apk}",
        ],
        capture_output=True,
        text=True,
    )
    if request.returncode != 0:
        print("upload failed:", request.stderr[:400])
        raise SystemExit(1)
    result = json.loads(request.stdout or "{}")
    if result.get("browser_download_url"):
        print(f"APK uploaded: {result['browser_download_url']}")
    else:
        print("upload response:", request.stdout[:400])


if __name__ == "__main__":
    main()

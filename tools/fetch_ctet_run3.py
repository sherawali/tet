# -*- coding: utf-8 -*-
"""
CTET sources fetcher — RUN 3 (targeted, fast; GitHub Actions runner).

Run-2 seekh: sab kuch OCR karna = 90-min timeout. Isliye ab:
- sirf zaroori cheezein: jan2024 key + 9 official Drive zips + adda247 text PDFs
- OCR sirf un PDFs par jo (a) target-set se match karein AUR (b) text-layer na rakhte hon
- tesseract PARALLEL (4 workers, OMP_THREAD_LIMIT=1) + 150 dpi + page-cap
- careerpower scans = ant me, time-guard ke saath (50 min se zyada ho gaya to skip)

Output: ctetnew/_sources/{keys,qps}/*.txt + manifest.json (overwrite-safe merge)
"""
import json, os, re, subprocess, sys, time, glob, zipfile
from concurrent.futures import ThreadPoolExecutor

T0 = time.time()
OUT = os.path.join("ctetnew", "_sources")
KEYS_DIR = os.path.join(OUT, "keys")
QPS_DIR = os.path.join(OUT, "qps")
DL = "/tmp/dl3"
for d in (KEYS_DIR, QPS_DIR, DL):
    os.makedirs(d, exist_ok=True)

MANIFEST_PATH = os.path.join(OUT, "manifest.json")
manifest = {"run3": {"keys": [], "papers": [], "errors": [], "started": time.strftime("%Y-%m-%d %H:%M:%S")}}
if os.path.exists(MANIFEST_PATH):
    try:
        manifest = json.load(open(MANIFEST_PATH))
    except Exception:
        pass
manifest["run3"] = {"keys": [], "papers": [], "errors": [], "started": time.strftime("%Y-%m-%d %H:%M:%S")}
R = manifest["run3"]

def sh(cmd, timeout=240):
    try:
        return subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return None

def fetch(url, dest, tries=4):
    for i in range(tries):
        sh(f'curl -sL --max-time 200 -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" "{url}" -o "{dest}"')
        if os.path.exists(dest) and os.path.getsize(dest) > 500:
            return True
        time.sleep(8)
    return False

def drive_dl(fid, dest):
    u = f"https://drive.usercontent.google.com/download?id={fid}&export=download&confirm=t"
    if fetch(u, dest, tries=3):
        with open(dest, "rb") as f:
            if f.read(4) == b"%PDF" or zipfile.is_zipfile(dest):
                return "usercontent"
    r = sh(f'gdown --fuzzy "https://drive.google.com/file/d/{fid}/view" -O "{dest}"', timeout=300)
    if r and r.returncode == 0 and os.path.exists(dest) and os.path.getsize(dest) > 500:
        return "gdown"
    return None

# ------------------------------------------------------------------ 1) keys
KEY_URLS = {
    "jan2024_p1_final_key.pdf": "https://cdnbbsr.s3waas.gov.in/s3443dec3062d0286986e21dc0631734c9/uploads/2024/02/2024021954.pdf",
}
print("== keys ==", flush=True)
for name, url in KEY_URLS.items():
    dest = os.path.join(DL, name)
    ok = fetch(url, dest, tries=6)
    ent = {"name": name, "url": url}
    if ok:
        r = sh(f'python3 -c "import pdfplumber,sys; pdf=pdfplumber.open(sys.argv[1]); print(chr(10).join((p.extract_text() or \'\') for p in pdf.pages))" "{dest}"', timeout=180)
        txt = r.stdout if r and r.returncode == 0 else ""
        if len(txt) > 200:
            stem = name.rsplit(".", 1)[0]
            open(os.path.join(KEYS_DIR, stem + ".txt"), "w", encoding="utf-8").write(txt)
            ent["status"] = "ok"; ent["chars"] = len(txt)
        else:
            ent["status"] = "no-text"
    else:
        ent["status"] = "download-fail"
    R["keys"].append(ent)
    print(" ", name, ent["status"], flush=True)

# ------------------------------------------------------------- 2) drive zips
# (label, fid, ocr_allowed, max_ocr_pages)
ZIPS = [
    ("dec2022_13jan2023", "15G4FF1qtpMot8KZS_VZCXoQVUYepdrY9", True,  40),
    ("july2024_setA",     "1i61Br_kq-YiSqL-0u_obVV0j0RC_beeL", True,  40),
    ("dec2024_setH",      "17kvon5hwlXZiJyOaOHaFUO3zY_Gg6kn5", True,  40),
    ("feb2026_p1_07feb_S", "1suavWoDsydGcTk_alVmKhwmyH9GuUJ48", True, 36),
    ("feb2026_p1_08feb_C", "1wbsYGwEMnmQyj5eiZ5ZcdHiCGtIeam60", True, 36),
    ("feb2026_p1_07feb_U", "1jdwb05v_GzPJAuyNKJ6WKzhbG1iwTosy", True, 36),
    ("feb2026_p1_08feb_E", "1NZiXv9hXKqvU1pyCkCxHB7400CYNPfRO", True, 36),
    ("jan2024_setI",      "1zvLZtZEIhvqoooU88uXmgbHTmDHpfQd1", False, 0),
    ("jan2024_setJ",      "1G9dTNyzk3t2w6PW7ybZiE9KyQJaF_mTD", False, 0),
    ("jan2024_setK",      "1gSQxrQGKx5SjUMjcjT-BbCP61sk-rZKN", False, 0),
    ("jan2024_setL",      "1ELHGrhxxFAVfUh4q6KhxRL_NvYYew8i3", False, 0),
]

def pdf_pages(pdf):
    r = sh(f'python3 -c "import pdfplumber,sys; print(len(pdfplumber.open(sys.argv[1]).pages))" "{pdf}"', timeout=120)
    try:
        return int(r.stdout.strip())
    except Exception:
        return 0

def pdf_text(pdf, p1=None, p2=None):
    rng = f"{p1} {p2}" if p1 else ""
    r = sh(f'python3 -c "import pdfplumber,sys; pdf=pdfplumber.open(sys.argv[1]); pages=pdf.pages[{rng}] if len(sys.argv)>2 else pdf.pages; print(chr(10).join((p.extract_text() or \'\') for p in pages))" "{pdf}" {rng}'.strip(), timeout=240)
    return r.stdout if r and r.returncode == 0 else ""

def ocr_pdf(pdf, max_pages):
    """150 dpi PNG → tesseract (eng+hin, psm 6) parallel 4 workers."""
    base = os.path.basename(pdf).rsplit(".", 1)[0] + "_ocr"
    imgdir = os.path.join(DL, "img_" + base)
    os.makedirs(imgdir, exist_ok=True)
    n = pdf_pages(pdf)
    if n <= 0:
        return ""
    last = min(n, max_pages)
    sh(f'pdftoppm -r 150 -png -f 1 -l {last} "{pdf}" "{imgdir}/pg"', timeout=600)
    pages = sorted(glob.glob(os.path.join(imgdir, "pg-*.png")))
    def one(img):
        out = img.rsplit(".", 1)[0]
        env = "OMP_THREAD_LIMIT=1"
        sh(f"{env} tesseract {img} {out} -l eng+hin --psm 6 2>/dev/null", timeout=300)
        try:
            return open(out + ".txt", encoding="utf-8", errors="ignore").read()
        except Exception:
            return ""
    with ThreadPoolExecutor(max_workers=4) as ex:
        texts = list(ex.map(one, pages))
    return "\n\f\n".join(texts)

def handle_pdf(pdf, label, ocr_allowed, max_ocr):
    """ek PDF: text-layer try; scanned ho to (allowed & time) OCR."""
    ent = {"zip": label, "pdf": os.path.basename(pdf)}
    n = pdf_pages(pdf)
    ent["pages"] = n
    if n <= 0:
        ent["status"] = "unreadable"; return ent
    txt = pdf_text(pdf)
    ent["chars"] = len(txt)
    if len(txt) >= 150 * min(n, 5):          # text-layer kaafi hai
        ent["status"] = "text"
    elif ocr_allowed and (time.time() - T0) < 55 * 60:
        txt = ocr_pdf(pdf, max_ocr)
        ent["chars"] = len(txt); ent["status"] = "ocr"
    else:
        ent["status"] = "scanned-skip" if ocr_allowed else "scanned-defer"
        return ent
    stem = re.sub(r"[^A-Za-z0-9_-]+", "_", label + "__" + os.path.basename(pdf).rsplit(".", 1)[0])[:120]
    open(os.path.join(QPS_DIR, stem + ".txt"), "w", encoding="utf-8").write(txt)
    return ent

print("== drive zips ==", flush=True)
for label, fid, ocr_allowed, max_ocr in ZIPS:
    ent = {"label": label, "fid": fid}
    dest = os.path.join(DL, label + ".zip")
    how = drive_dl(fid, dest)
    if not how:
        ent["status"] = "drive-fail"; R["errors"].append(f"drive dl fail: {label}")
        R["papers"].append(ent); print(" ", label, "drive-fail", flush=True); continue
    ent["via"] = how
    # zip? ya seedha PDF?
    if zipfile.is_zipfile(dest):
        zdir = os.path.join(DL, label)
        os.makedirs(zdir, exist_ok=True)
        try:
            with zipfile.ZipFile(dest) as z:
                z.extractall(zdir)
        except Exception as e:
            ent["status"] = "unzip-fail"; R["errors"].append(f"unzip fail {label}: {e}")
            R["papers"].append(ent); continue
        pdfs = sorted(glob.glob(os.path.join(zdir, "**", "*.pdf"), recursive=True))
        p1s = [p for p in pdfs if re.search(r"(paper\s*1|p1|paper[-_ ]?i\b|l1)", os.path.basename(p), re.I)] or pdfs
        p1s = [p for p in p1s if not re.search(r"(paper\s*2|p2|paper[-_ ]?ii\b|l2)", os.path.basename(p), re.I)]
        ent["pdfs_in_zip"] = len(pdfs); ent["p1_pdfs"] = [os.path.basename(p) for p in p1s]
        # OCR budget: har zip me se sirf pehla P1 pdf (baaki text-only)
        results = []
        for i, p in enumerate(p1s[:2]):
            allow = ocr_allowed and i == 0
            results.append(handle_pdf(p, label, allow, max_ocr))
        ent["status"] = "done"; ent["extracted"] = results
    else:
        # direct PDF
        ent["extracted"] = [handle_pdf(dest, label, ocr_allowed, max_ocr)]
        ent["status"] = "done"
    R["papers"].append(ent)
    print(f"  {label}: {ent['status']} ({[(e.get('status'), e.get('chars')) for e in ent.get('extracted', [])]})", flush=True)

# ------------------------------------------------------------- 3) adda247 (text)
ADD = {
    "adda247_7feb_codeU": "https://www.adda247.com/jobs/wp-content/uploads/sites/13/2026/02/07183549/Code-U.pdf",
    "adda247_7feb_codeV": "https://www.adda247.com/jobs/wp-content/uploads/sites/13/2026/02/07183547/Code-V.pdf",
    "adda247_8feb_setC": "https://www.adda247.com/jobs/wp-content/uploads/sites/13/2026/02/08180518/PRT-08-02-26-Set-C.pdf",
}
print("== adda247 ==", flush=True)
for label, url in ADD.items():
    dest = os.path.join(DL, label + ".pdf")
    ent = {"label": label, "url": url}
    if fetch(url, dest):
        ent.update(handle_pdf(dest, label, False, 0))
    else:
        ent["status"] = "download-fail"
    R["papers"].append(ent); print(" ", label, ent.get("status"), ent.get("chars"), flush=True)

# ------------------------------------------------------- 4) careerpower (OCR, guard)
CP = {
    "careerpower_7feb_X": "https://www.careerpower.in/blog/wp-content/uploads/2026/05/12122733/CTET-7-Feb-Code-X-Paper-1.pdf",
    "careerpower_7feb_V": "https://www.careerpower.in/blog/wp-content/uploads/2026/05/12122746/CTET-Question-Paper-1-Shift-2-7-Feb-2026-Code-V.pdf",
    "careerpower_8feb_C": "https://www.careerpower.in/blog/wp-content/uploads/2026/05/12122845/CTET-Question-Paper-1-Shift-2-8-Feb-2026-Code-C.pdf",
    "careerpower_8feb_E": "https://www.careerpower.in/blog/wp-content/uploads/2026/05/12122850/CTET-Question-Paper-1-Shift-2-8-Feb-2026-Code-E.pdf",
}
print("== careerpower (time-guarded) ==", flush=True)
for label, url in CP.items():
    if (time.time() - T0) > 50 * 60:
        R["errors"].append(f"careerpower skipped (time): {label}")
        print(" ", label, "SKIP (time)", flush=True); continue
    dest = os.path.join(DL, label + ".pdf")
    ent = {"label": label, "url": url}
    if fetch(url, dest):
        ent.update(handle_pdf(dest, label, True, 30))
    else:
        ent["status"] = "download-fail"
    R["papers"].append(ent); print(" ", label, ent.get("status"), ent.get("chars"), flush=True)

R["elapsed_min"] = round((time.time() - T0) / 60, 1)
json.dump(manifest, open(MANIFEST_PATH, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print(f"DONE in {R['elapsed_min']} min", flush=True)

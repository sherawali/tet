# -*- coding: utf-8 -*-
"""
CTET sources fetcher — RUN 4 (official Eng+Hin bilingual papers ka OCR).

Run-3 seekh: official zips me har medium ka alag PDF hai (Assamese/Bengali/.../Eng+Hin).
Hum sirf 'Eng+Hin' / 'Main' variant OCR karte hain — wahi bilingual (user requirement) hai.

- 200 dpi, tesseract -l eng+hin (psm 3), parallel 4 workers, page-cap 40
- adda247/careerpower: %PDF-magic validation + Referer + diagnostics
- dec2022 13-Jan zip: retry (Eng+Hin / L1-ENG variant pick karne ke liye regex)
"""
import json, os, re, subprocess, time, glob, zipfile
from concurrent.futures import ThreadPoolExecutor

T0 = time.time()
OUT = os.path.join("ctetnew", "_sources")
QPS_DIR = os.path.join(OUT, "qps")
DL = "/tmp/dl4"
os.makedirs(QPS_DIR, exist_ok=True)
os.makedirs(DL, exist_ok=True)

MANIFEST_PATH = os.path.join(OUT, "manifest.json")
manifest = {}
if os.path.exists(MANIFEST_PATH):
    try:
        manifest = json.load(open(MANIFEST_PATH))
    except Exception:
        pass
manifest["run4"] = {"papers": [], "errors": [], "started": time.strftime("%Y-%m-%d %H:%M:%S")}
R = manifest["run4"]

def sh(cmd, timeout=300):
    try:
        return subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return None

def is_pdf(p):
    try:
        with open(p, "rb") as f:
            return f.read(5) == b"%PDF-"
    except Exception:
        return False

def fetch(url, dest, tries=4, referer=None):
    for i in range(tries):
        ref = f'-e "{referer}"' if referer else ""
        sh(f'curl -sL --max-time 200 -A "Mozilla/5.0 (X11; Linux x86_64; rv:124.0) Gecko/20100101 Firefox/124.0" {ref} "{url}" -o "{dest}"')
        if is_pdf(dest) and os.path.getsize(dest) > 10000:
            return True
        time.sleep(8)
    return False

def drive_dl(fid, dest):
    u = f"https://drive.usercontent.google.com/download?id={fid}&export=download&confirm=t"
    if fetch(u, dest, tries=3):
        if is_pdf(dest) or zipfile.is_zipfile(dest):
            return "usercontent"
    r = sh(f'gdown --fuzzy "https://drive.google.com/file/d/{fid}/view" -O "{dest}"', timeout=300)
    if r and r.returncode == 0 and (is_pdf(dest) or zipfile.is_zipfile(dest)):
        return "gdown"
    return None

def n_pages(pdf):
    r = sh(f'pdfinfo "{pdf}" | grep -i "^Pages" | awk "{{print $2}}"', timeout=120)
    try:
        return int(r.stdout.strip())
    except Exception:
        return 0

def ocr_pdf(pdf, max_pages=40, dpi=200):
    base = re.sub(r"[^A-Za-z0-9]+", "_", os.path.basename(pdf))[:60]
    imgdir = os.path.join(DL, "img_" + base)
    os.makedirs(imgdir, exist_ok=True)
    n = n_pages(pdf)
    if n <= 0:
        return "", 0
    last = min(n, max_pages)
    sh(f'pdftoppm -r {dpi} -gray -png -f 1 -l {last} "{pdf}" "{imgdir}/pg"', timeout=900)
    pages = sorted(glob.glob(os.path.join(imgdir, "pg-*.png")))
    def one(img):
        out = img.rsplit(".", 1)[0]
        sh(f"OMP_THREAD_LIMIT=1 tesseract {img} {out} -l eng+hin --psm 3 2>/dev/null", timeout=400)
        try:
            return open(out + ".txt", encoding="utf-8", errors="ignore").read()
        except Exception:
            return ""
    with ThreadPoolExecutor(max_workers=4) as ex:
        texts = list(ex.map(one, pages))
    return "\n\f\n".join(texts), len(pages)

# (label, fid, pick_regex) — zip me se ye regex wale P1 PDF hi OCR honge
ZIPS = [
    ("feb2026_07feb_S", "1suavWoDsydGcTk_alVmKhwmyH9GuUJ48", r"Main-S"),
    ("feb2026_07feb_U", "1jdwb05v_GzPJAuyNKJ6WKzhbG1iwTosy", r"Main-U"),
    ("feb2026_08feb_C", "1wbsYGwEMnmQyj5eiZ5ZcdHiCGtIeam60", r"Eng\+Hin\s*CCCC"),
    ("feb2026_08feb_E", "1NZiXv9hXKqvU1pyCkCxHB7400CYNPfRO", r"Eng\+Hin\s*EEEE"),
    ("july2024_A",      "1i61Br_kq-YiSqL-0u_obVV0j0RC_beeL", r"Eng\+Hin\s*AAAA"),
    ("dec2024_H",       "17kvon5hwlXZiJyOaOHaFUO3zY_Gg6kn5", r"Eng\+Hin\s*HHHH|Eng\+Hin\s*H\.pdf"),
    ("jan2024_I",       "1zvLZtZEIhvqoooU88uXmgbHTmDHpfQd1", r"Eng\+Hin\s*IIII"),
    ("dec2022_13jan",   "15G4FF1qtpMot8KZS_VZCXoQVUYepdrY9", r"(?i)(eng|hin)"),
]

print("== official Eng+Hin papers ==", flush=True)
for label, fid, pick in ZIPS:
    if (time.time() - T0) > 70 * 60:
        R["errors"].append(f"time-guard stop: {label}")
        print(" ", label, "SKIP (time)", flush=True)
        break
    ent = {"label": label, "fid": fid}
    dest = os.path.join(DL, label + ".bin")
    how = drive_dl(fid, dest)
    if not how:
        ent["status"] = "drive-fail"; R["errors"].append(f"drive fail: {label}")
        R["papers"].append(ent); print(" ", label, "drive-fail", flush=True)
        continue
    ent["via"] = how
    if not zipfile.is_zipfile(dest):
        ent["status"] = "not-a-zip"; R["papers"].append(ent); continue
    zdir = os.path.join(DL, label)
    os.makedirs(zdir, exist_ok=True)
    try:
        with zipfile.ZipFile(dest) as z:
            names = z.namelist()
            ent["zip_files"] = names[:40]
            z.extractall(zdir)
    except Exception as e:
        ent["status"] = "unzip-fail"; R["errors"].append(f"unzip fail {label}: {e}")
        R["papers"].append(ent); continue
    pdfs = sorted(glob.glob(os.path.join(zdir, "**", "*.pdf"), recursive=True))
    picked = [p for p in pdfs if re.search(pick, os.path.basename(p))]
    if label == "dec2022_13jan":
        # paper-1 only, aur P1 me se English/Hindi wale (L1-ENG-L2-HIN style)
        picked = [p for p in pdfs if re.search(r"(?i)(paper\s*1|P1|L1)", os.path.basename(p))
                  and not re.search(r"(?i)(paper\s*2|P2|L2[^E])", os.path.basename(p))
                  and re.search(r"(?i)eng", os.path.basename(p))]
    if not picked:
        ent["status"] = "no-match"; ent["all_pdfs"] = [os.path.basename(p) for p in pdfs]
        R["papers"].append(ent); print(" ", label, "no-match", ent["all_pdfs"][:8], flush=True)
        continue
    ent["picked"] = [os.path.basename(p) for p in picked]
    ex_list = []
    for p in picked[:2]:           # max 2 PDF per zip
        txt, n = ocr_pdf(p)
        stem = re.sub(r"[^A-Za-z0-9_-]+", "_", label + "__" + os.path.basename(p).rsplit(".", 1)[0])[:120]
        open(os.path.join(QPS_DIR, stem + ".txt"), "w", encoding="utf-8").write(txt)
        ex_list.append({"pdf": os.path.basename(p), "pages_ocr": n, "chars": len(txt)})
    ent["status"] = "done"; ent["extracted"] = ex_list
    R["papers"].append(ent)
    print(f"  {label}: {[(e['pages_ocr'], e['chars']) for e in ex_list]}", flush=True)

# ---------------------------------------------- adda247 / careerpower (diagnose+retry)
EXTRA = {
    "adda247_7feb_codeU": ("https://www.adda247.com/jobs/wp-content/uploads/sites/13/2026/02/07183549/Code-U.pdf", "https://www.adda247.com/jobs/"),
    "adda247_7feb_codeV": ("https://www.adda247.com/jobs/wp-content/uploads/sites/13/2026/02/07183547/Code-V.pdf", "https://www.adda247.com/jobs/"),
    "adda247_8feb_setC": ("https://www.adda247.com/jobs/wp-content/uploads/sites/13/2026/02/08180518/PRT-08-02-26-Set-C.pdf", "https://www.adda247.com/jobs/"),
    "careerpower_8feb_C": ("https://www.careerpower.in/blog/wp-content/uploads/2026/05/12122845/CTET-Question-Paper-1-Shift-2-8-Feb-2026-Code-C.pdf", "https://www.careerpower.in/"),
}
print("== extras (adda247/careerpower) ==", flush=True)
for label, (url, ref) in EXTRA.items():
    ent = {"label": label, "url": url}
    dest = os.path.join(DL, label + ".pdf")
    if fetch(url, dest, tries=3, referer=ref):
        txt, n = ocr_pdf(dest, max_pages=40)
        if len(txt) < 5000:      # OCR bhi fail? pdfplumber text try
            r = sh(f'python3 -c "import pdfplumber,sys; print(chr(10).join((p.extract_text() or \'\') for p in pdfplumber.open(sys.argv[1]).pages))" "{dest}"', timeout=240)
            if r and r.returncode == 0 and len(r.stdout) > len(txt):
                txt = r.stdout; n = -1
        stem = re.sub(r"[^A-Za-z0-9_-]+", "_", label)
        open(os.path.join(QPS_DIR, stem + ".txt"), "w", encoding="utf-8").write(txt)
        ent.update({"status": "ok", "pages": n, "chars": len(txt)})
    else:
        sz = os.path.getsize(dest) if os.path.exists(dest) else 0
        head = ""
        try:
            head = open(dest, "rb").read(60).decode("utf-8", "ignore")
        except Exception:
            pass
        ent.update({"status": "dl-fail", "size": sz, "head": head})
    R["papers"].append(ent)
    print(" ", label, ent.get("status"), ent.get("chars"), flush=True)

R["elapsed_min"] = round((time.time() - T0) / 60, 1)
json.dump(manifest, open(MANIFEST_PATH, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print(f"DONE in {R['elapsed_min']} min", flush=True)

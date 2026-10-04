# -*- coding: utf-8 -*-
"""
CTET sources fetcher — RUN 7 (clean rewrite; official Eng+Hin bilingual papers).

- zips: feb2026 S/U (Main), feb2026 C/E + july2024 A + dec2024 H + jan2024 I (Eng+Hin), dec2022 13-Jan
- har PDF: pehle pdfplumber text-layer; scanned ho to OCR (200dpi, eng+hin, psm 3, parallel-4)
- Drive: usercontent → docs.google.com → interstitial-follow → gdown
- crash par bhi traceback manifest me likha jata hai
"""
import json, os, re, subprocess, time, glob, zipfile, traceback
from concurrent.futures import ThreadPoolExecutor

T0 = time.time()
OUT = os.path.join("ctetnew", "_sources")
QPS_DIR = os.path.join(OUT, "qps")
DL = "/tmp/dl7"
os.makedirs(QPS_DIR, exist_ok=True)
os.makedirs(DL, exist_ok=True)

MANIFEST_PATH = os.path.join(OUT, "manifest.json")
manifest = {}
if os.path.exists(MANIFEST_PATH):
    try:
        manifest = json.load(open(MANIFEST_PATH))
    except Exception:
        pass
manifest["run10"] = {"papers": [], "errors": [], "started": time.strftime("%Y-%m-%d %H:%M:%S")}
R = manifest["run10"]

UA = "Mozilla/5.0 (X11; Linux x86_64; rv:124.0) Gecko/20100101 Firefox/124.0"

def sh(cmd, timeout=300):
    try:
        return subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return None

def magic_ok(p):
    try:
        with open(p, "rb") as f:
            h = f.read(5)
        return h == b"%PDF-" or zipfile.is_zipfile(p)
    except Exception:
        return False

def fetch(url, dest, tries=3):
    for i in range(tries):
        sh(f'curl -sL --max-time 240 -A "{UA}" "{url}" -o "{dest}"')
        if os.path.exists(dest) and os.path.getsize(dest) > 10000 and magic_ok(dest):
            return True
        time.sleep(6)
    return False

def drive_dl(fid, dest):
    for u in (f"https://drive.usercontent.google.com/download?id={fid}&export=download&confirm=t",
              f"https://docs.google.com/uc?export=download&id={fid}&confirm=t"):
        if fetch(u, dest, tries=2):
            return "direct"
    # interstitial follow (virus-scan page)
    try:
        html = open(dest, encoding="utf-8", errors="ignore").read()
        m = re.search(r'action="([^"]+)"', html)
        if m:
            params = dict(re.findall(r'name="([^"]+)" value="([^"]*)"', html))
            q = "&".join(f"{k}={v}" for k, v in params.items())
            if fetch(m.group(1) + "?" + q, dest, tries=2):
                return "interstitial"
    except Exception as e:
        R["errors"].append(f"interstitial: {e}")
    r = sh(f'gdown --fuzzy "https://drive.google.com/file/d/{fid}/view" -O "{dest}"', timeout=400)
    if r and r.returncode == 0 and os.path.exists(dest) and magic_ok(dest):
        return "gdown"
    return None

PY_PAGES = 'import pdfplumber,sys; pdf=pdfplumber.open(sys.argv[1]); print(len(pdf.pages))'
PY_TEXT = ('import pdfplumber,sys; pdf=pdfplumber.open(sys.argv[1]); '
           'print(chr(10).join((p.extract_text() or "") for p in pdf.pages))')

def n_pages(pdf):
    r = sh(f'python3 -c \'{PY_PAGES}\' "{pdf}"', timeout=240)
    try:
        return int(r.stdout.strip())
    except Exception:
        return 0

def pdf_text(pdf):
    r = sh(f'python3 -c \'{PY_TEXT}\' "{pdf}"', timeout=400)
    return (r.stdout or "") if r and r.returncode == 0 else ""

def ocr_pdf(pdf, max_pages=40, dpi=200, psm=3, page_from=1, suffix=""):
    tag = re.sub(r"[^A-Za-z0-9]+", "_", os.path.basename(pdf))[:50] + str(int(time.time()))
    imgdir = os.path.join(DL, "img_" + tag)
    os.makedirs(imgdir, exist_ok=True)
    n = n_pages(pdf)
    if n <= 0:
        return "", 0
    last = min(n, page_from - 1 + max_pages)
    sh(f'pdftoppm -r {dpi} -gray -png -f {page_from} -l {last} "{pdf}" "{imgdir}/pg"', timeout=900)
    pages = sorted(glob.glob(os.path.join(imgdir, "pg-*.png")))
    def one(img):
        out = img.rsplit(".", 1)[0]
        sh(f"OMP_THREAD_LIMIT=1 tesseract {img} {out} -l eng+hin --psm {psm} 2>/dev/null", timeout=400)
        try:
            return open(out + ".txt", encoding="utf-8", errors="ignore").read()
        except Exception:
            return ""
    with ThreadPoolExecutor(max_workers=4) as ex:
        texts = list(ex.map(one, pages))
    return "\n\f\n".join(texts), len(pages)

ZIPS = [
    ("feb2026_07feb_S", "1suavWoDsydGcTk_alVmKhwmyH9GuUJ48", r"Main-S"),
    ("feb2026_08feb_C", "1wbsYGwEMnmQyj5eiZ5ZcdHiCGtIeam60", r"Eng\+Hin\s*CCCC"),
    ("july2024_A",      "1i61Br_kq-YiSqL-0u_obVV0j0RC_beeL", r"Eng\+Hin\s*AAAA"),
    ("dec2024_H",       "17kvon5hwlXZiJyOaOHaFUO3zY_Gg6kn5", r"Eng\+Hin\s*HHHH"),
]

def pick_dec2022(pdfs):
    out = []
    for p in pdfs:
        b = os.path.basename(p)
        if re.search(r"(?i)paper\s*2|P2", b):
            continue
        if re.search(r"(?i)eng", b):
            out.append(p)
    return out[:2]

def main():
    for label, fid, pick in ZIPS:
        if (time.time() - T0) > 75 * 60:
            R["errors"].append(f"time-guard: {label} skipped")
            break
        ent = {"label": label, "fid": fid}
        R["papers"].append(ent)
        dest = os.path.join(DL, label + ".bin")
        how = drive_dl(fid, dest)
        if not how:
            ent["status"] = "drive-fail"
            R["errors"].append(f"drive fail: {label}")
            print(" ", label, "drive-fail", flush=True)
            continue
        ent["via"] = how
        if not zipfile.is_zipfile(dest):
            ent["status"] = "not-zip"
            continue
        zdir = os.path.join(DL, label)
        os.makedirs(zdir, exist_ok=True)
        try:
            with zipfile.ZipFile(dest) as z:
                ent["zip_files"] = z.namelist()[:40]
                z.extractall(zdir)
        except Exception as e:
            ent["status"] = "unzip-fail"
            R["errors"].append(f"unzip {label}: {e}")
            continue
        pdfs = sorted(glob.glob(os.path.join(zdir, "**", "*.pdf"), recursive=True))
        picked = pick_dec2022(pdfs) if pick == "__special_dec2022__" else \
                 [p for p in pdfs if re.search(pick, os.path.basename(p))]
        if not picked:
            ent["status"] = "no-match"
            ent["all_pdfs"] = [os.path.basename(p) for p in pdfs]
            print(" ", label, "no-match", flush=True)
            continue
        ent["picked"] = [os.path.basename(p) for p in picked]
        ex_list = []
        for p in picked[:2]:
            try:
                txt, nocr = ocr_pdf(p, max_pages=60, dpi=400, psm=6, page_from=24, suffix="_psm6")
                how2, np_ = f"ocr6({nocr}p)", nocr
                txt11, n11 = ocr_pdf(p, max_pages=60, dpi=400, psm=11, page_from=24, suffix="_psm11")
                stem11 = stem + "_psm11"
                with open(os.path.join(QPS_DIR, stem11 + ".txt"), "w", encoding="utf-8") as f:
                    f.write(txt11)
                stem = re.sub(r"[^A-Za-z0-9_-]+", "_", label + "_ocr24")[:120]
                with open(os.path.join(QPS_DIR, stem + ".txt"), "w", encoding="utf-8") as f:
                    f.write(txt)
                ex_list.append({"pdf": os.path.basename(p), "method": how2, "pages": np_, "chars": len(txt)})
                print(f"  {label}/{os.path.basename(p)}: {how2} pages={np_} chars={len(txt)}", flush=True)
            except Exception:
                ex_list.append({"pdf": os.path.basename(p), "error": traceback.format_exc()[-400:]})
        ent["status"] = "done"
        ent["extracted"] = ex_list

try:
    main()
except Exception:
    R["errors"].append("FATAL: " + traceback.format_exc()[-1500:])
    print(traceback.format_exc(), flush=True)

R["elapsed_min"] = round((time.time() - T0) / 60, 1)
json.dump(manifest, open(MANIFEST_PATH, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print(f"DONE in {R['elapsed_min']} min; errors={len(R['errors'])}", flush=True)

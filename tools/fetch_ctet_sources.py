# -*- coding: utf-8 -*-
"""
CTET official sources fetcher (GitHub Actions runner par chalne ke liye).

- ctet.nic.in ke official answer-key PDFs (S3 CDN) download karta hai
- ctet.nic.in question-paper pages se Google Drive links nikaal kar (gdown)
  Paper-1 question papers download karta hai
- har PDF ka text nikaal kar ctetnew/_sources/ me .txt likhta hai
  (image-scan PDF ke liye tesseract OCR fallback)
- manifest.json me sab kuch record karta hai

Output sirf TEXT hai (PDFs commit nahi hote — repo halka rahe).
"""
import json, os, re, subprocess, sys, hashlib, glob, time

OUT = os.path.join("ctetnew", "_sources")
KEYS_DIR = os.path.join(OUT, "keys")
QPS_DIR = os.path.join(OUT, "qps")
DL = "/tmp/dl"
os.makedirs(KEYS_DIR, exist_ok=True)
os.makedirs(QPS_DIR, exist_ok=True)
os.makedirs(DL, exist_ok=True)

manifest = {"keys": [], "papers": [], "errors": []}

DEV = re.compile(r"[\u0900-\u097F]")

# ---------------------------------------------------------------- answer keys
KEY_URLS = {
    "feb2026_p1_07feb_final_key.pdf": "https://cdnbbsr.s3waas.gov.in/s3443dec3062d0286986e21dc0631734c9/uploads/2026/04/20260401145739613.pdf",
    "feb2026_p1_08feb_final_key.pdf": "https://cdnbbsr.s3waas.gov.in/s3443dec3062d0286986e21dc0631734c9/uploads/2026/04/20260401449979389.pdf",
    "feb2026_p1_01mar_final_key.pdf": "https://cdnbbsr.s3waas.gov.in/s3443dec3062d0286986e21dc0631734c9/uploads/2026/04/202604011664019376.pdf",
    "dec2024_p1_final_key.pdf": "https://cdnbbsr.s3waas.gov.in/s3443dec3062d0286986e21dc0631734c9/uploads/2025/01/2025012321.pdf",
    "july2024_p1_final_key.pdf": "https://cdnbbsr.s3waas.gov.in/s3443dec3062d0286986e21dc0631734c9/uploads/2024/08/2024080797.pdf",
    "jan2024_p1_final_key.pdf": "https://cdnbbsr.s3waas.gov.in/s3443dec3062d0286986e21dc0631734c9/uploads/2024/02/2024021954.pdf",
    "aug2023_p1_final_key.pdf": "https://cdnbbsr.s3waas.gov.in/s3443dec3062d0286986e21dc0631734c9/uploads/2023/09/2023092672.pdf",
    "dec2022_final_key.pdf": "https://cdnbbsr.s3waas.gov.in/s3443dec3062d0286986e21dc0631734c9/uploads/2023/03/2023030346.pdf",
    "dec2021_p1_final_key_hi.pdf": "https://cdnbbsr.s3waas.gov.in/s3443dec3062d0286986e21dc0631734c9/uploads/2022/08/2022082386.pdf",
    "dec2021_p1_final_key_en.pdf": "https://cdnbbsr.s3waas.gov.in/s3443dec3062d0286986e21dc0631734c9/uploads/2022/08/2022082370.pdf",
    "jan2021_p1_final_key.pdf": "https://cdnbbsr.s3waas.gov.in/s3443dec3062d0286986e21dc0631734c9/uploads/2022/03/2022033154.pdf",
}

# ---------------------------------------------------- question paper pages
QP_PAGES = {
    "feb2026": "https://ctet.nic.in/question-paper-feb-2026/",
    "dec2024": "https://ctet.nic.in/question-paper-dec-2024/",
    "july2024": "https://ctet.nic.in/question-paper-july-2024/",
    "jan2024": "https://ctet.nic.in/question-paper-january-2024/",
    "aug2023": "https://ctet.nic.in/question-paper-august-2023/",
    "dec2022": "https://ctet.nic.in/question-paper-december-2022/",
    "dec2021": "https://ctet.nic.in/question-paper-december-2021/",
    "jan2021": "https://ctet.nic.in/question-paper-january-2021/",
}

def sh(cmd, timeout=240):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)

def fetch(url, dest, tries=3):
    for i in range(tries):
        sh(f'curl -sL --max-time 180 -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" "{url}" -o "{dest}"')
        if os.path.exists(dest) and os.path.getsize(dest) > 500:
            return True
        time.sleep(5)
    return False

def drive_download(fid, dest):
    """Drive: pehle usercontent endpoint, phir gdown."""
    u = f"https://drive.usercontent.google.com/download?id={fid}&export=download&confirm=t"
    for i in range(2):
        sh(f'curl -sL --max-time 300 -A "Mozilla/5.0 (X11; Linux x86_64)" "{u}" -o "{dest}"')
        if os.path.exists(dest) and os.path.getsize(dest) > 1000:
            head = open(dest, "rb").read(200)
            if b"<html" not in head.lower() and b"docs.google" not in head.lower():
                return "usercontent"
        time.sleep(3)
    r = sh(f'gdown --fuzzy "https://drive.google.com/file/d/{fid}/view" -O "{dest}"', timeout=300)
    if os.path.exists(dest) and os.path.getsize(dest) > 1000:
        return "gdown"
    manifest["errors"].append(f"drive dl fail {fid}: {r.stderr[-300:] if r else ''}")
    return None

def extract_pdf(pdf_path, txt_path):
    """pdfplumber se text; scan ho to tesseract OCR (hin+eng)."""
    import pdfplumber
    pages, stats = [], []
    try:
        with pdfplumber.open(pdf_path) as pdf:
            for pg in pdf.pages:
                try:
                    t = pg.extract_text() or ""
                except Exception:
                    t = ""
                pages.append(t)
                stats.append(len(t))
    except Exception as e:
        manifest["errors"].append(f"pdfplumber fail {pdf_path}: {e}")
        pages, stats = [], []

    avg = (sum(stats) / len(stats)) if stats else 0
    method = "pdfplumber"
    if avg < 50:  # scanned pdf → OCR
        method = "tesseract-ocr"
        base = pdf_path + ".__p"
        sh(f'pdftoppm -r 200 -png "{pdf_path}" "{base}"', timeout=600)
        imgs = sorted(glob.glob(base + "*.png")) + sorted(glob.glob(base + "-*.png"))
        pages = []
        for im in imgs:
            r = sh(f'tesseract "{im}" - -l hin+eng --psm 6 2>/dev/null', timeout=300)
            pages.append(r.stdout or "")
            os.remove(im)
        sh(f'rm -f "{base}"*')

    out = []
    for i, t in enumerate(pages, 1):
        out.append(f"===== PAGE {i} =====")
        out.append(t)
    text = "\n".join(out)
    n_dev = len(DEV.findall(text))
    with open(txt_path, "w", encoding="utf-8") as f:
        f.write(text)
    return dict(pages=len(pages), avg_chars=round(avg), devanagari=n_dev, method=method,
                chars=len(text))

# ------------------------------------------------------------------ 1. keys
print("== downloading official final answer keys ==", flush=True)
for name, url in KEY_URLS.items():
    dest = os.path.join(DL, name)
    ok = fetch(url, dest)
    if not ok:
        manifest["errors"].append(f"key download fail: {name}")
        continue
    txt = os.path.join(KEYS_DIR, name.replace(".pdf", ".txt"))
    try:
        info = extract_pdf(dest, txt)
        info.update(file=name.replace(".pdf", ".txt"), url=url, kind="key",
                    sha256=hashlib.sha256(open(dest, "rb").read()).hexdigest()[:16])
        manifest["keys"].append(info)
        print(f"  key {name}: {info}", flush=True)
    except Exception as e:
        manifest["errors"].append(f"key extract fail {name}: {e}")

# ------------------------------------------------- 2. question paper pages
print("== fetching question-paper pages for Drive links ==", flush=True)
for exam, page_url in QP_PAGES.items():
    html_path = os.path.join(DL, f"page_{exam}.html")
    if not fetch(page_url, html_path):
        manifest["errors"].append(f"page fetch fail: {exam}")
        continue
    html = open(html_path, encoding="utf-8", errors="ignore").read()
    # drive links: href + anchor text
    links = re.findall(r'href="(https://drive\.google\.com/file/d/([\w-]+)/view[^"]*)"[^>]*>([^<]+)<', html)
    seen = set()
    for url, fid, label in links:
        label = label.strip()
        if fid in seen or not label:
            continue
        seen.add(fid)
        low = label.lower()
        is_p1 = any(k in low for k in ("p1", "paper1", "paper 1", "paper-1")) or \
                (any(k in low for k in ("p2", "paper2", "paper 2", "paper-2")) is False and True)
        # keep all, but tag paper2 so we can filter later
        manifest["papers"].append(dict(exam=exam, label=label, fid=fid, url=url))

print(f"  found {len(manifest['papers'])} drive links", flush=True)

# ------------------------------------------------------------- 3. gdown QPs
# extra direct PDFs (careerpower scans + adda247 text pdfs)
EXTRA_PDFS = {
    "feb2026": [
        ("careerpower_7Feb_CodeX_P1.pdf", "https://www.careerpower.in/blog/wp-content/uploads/2026/05/12122733/CTET-7-Feb-Code-X-Paper-1.pdf"),
        ("careerpower_7Feb_CodeV_P1.pdf", "https://www.careerpower.in/blog/wp-content/uploads/2026/05/12122746/CTET-Question-Paper-1-Shift-2-7-Feb-2026-Code-V.pdf"),
        ("careerpower_8Feb_CodeC_P1.pdf", "https://www.careerpower.in/blog/wp-content/uploads/2026/05/12122845/CTET-Question-Paper-1-Shift-2-8-Feb-2026-Code-C.pdf"),
        ("careerpower_8Feb_CodeE_P1.pdf", "https://www.careerpower.in/blog/wp-content/uploads/2026/05/12122850/CTET-Question-Paper-1-Shift-2-8-Feb-2026-Code-E.pdf"),
        ("adda247_7Feb_CodeU_P1.pdf", "https://www.adda247.com/jobs/wp-content/uploads/sites/13/2026/02/07183549/Code-U.pdf"),
        ("adda247_7Feb_CodeV_P1.pdf", "https://www.adda247.com/jobs/wp-content/uploads/sites/13/2026/02/07183547/Code-V.pdf"),
        ("adda247_8Feb_CodeC_P1.pdf", "https://www.adda247.com/jobs/wp-content/uploads/sites/13/2026/02/08180518/PRT-08-02-26-Set-C.pdf"),
    ],
}

print("== extra direct PDFs ==", flush=True)
for exam, items in EXTRA_PDFS.items():
    for name, url in items:
        dest = os.path.join(DL, "qps", exam, name)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        if not fetch(url, dest):
            manifest["errors"].append(f"extra pdf fail: {name}")
            continue
        txt = os.path.join(QPS_DIR, exam, name.replace(".pdf", ".txt"))
        try:
            info = extract_pdf(dest, txt)
            info.update(file=f"qps/{exam}/{name.replace('.pdf', '.txt')}", label=name.replace(".pdf",""),
                        url=url, kind="extra-pdf")
            manifest["papers"].append(dict(exam=exam, label=name.replace(".pdf", ""), files=[info], url=url))
            print(f"  extra {name}: {info['pages']}p {info['method']} dev={info['devanagari']}", flush=True)
        except Exception as e:
            manifest["errors"].append(f"extra extract fail {name}: {e}")

for item in [p for p in manifest["papers"] if "fid" in p]:
    label = re.sub(r"[^A-Za-z0-9_.-]+", "_", item["label"]).strip("_")
    exam = item["exam"]
    ddir = os.path.join(DL, "qps", exam)
    os.makedirs(ddir, exist_ok=True)
    dest = os.path.join(ddir, label + ".bin")
    how = drive_download(item["fid"], dest)
    if not how:
        item["status"] = "drive-fail"
        continue
    item["via"] = how
    # identify file type
    ft = sh(f'file -b --mime-type "{dest}"').stdout.strip()
    item["mime"] = ft
    files = []
    if "zip" in ft:
        zdir = dest + ".d"
        os.makedirs(zdir, exist_ok=True)
        sh(f'cd "{zdir}" && unzip -o -q "{dest}"')
        files = glob.glob(os.path.join(zdir, "**", "*.pdf"), recursive=True)
    elif "pdf" in ft:
        os.rename(dest, dest + ".pdf")
        files = [dest + ".pdf"]
    else:
        item["status"] = "unknown-type:" + ft
        continue
    item["files"] = item.get("files", [])
    for pdf in files:
        base = os.path.basename(pdf)
        txt = os.path.join(QPS_DIR, exam, re.sub(r"\.pdf$", "", base) + ".txt")
        os.makedirs(os.path.dirname(txt), exist_ok=True)
        try:
            info = extract_pdf(pdf, txt)
            info.update(file=f"qps/{exam}/{os.path.basename(txt)}", label=label,
                        sha256=hashlib.sha256(open(pdf, "rb").read()).hexdigest()[:16])
            item["files"].append(info)
            print(f"  paper {exam}/{base}: {info['pages']}p {info['method']} dev={info['devanagari']}", flush=True)
        except Exception as e:
            manifest["errors"].append(f"extract fail {exam}/{base}: {e}")

# ---------------------------------------------------------------- manifest
with open(os.path.join(OUT, "manifest.json"), "w", encoding="utf-8") as f:
    json.dump(manifest, f, ensure_ascii=False, indent=1)

n_err = len(manifest["errors"])
print(f"DONE. keys={len(manifest['keys'])} papers={len(manifest['papers'])} errors={n_err}")
for e in manifest["errors"][:30]:
    print("ERR:", e)

"""Prepare Play Store phone screenshots.

Sources are live device captures (1080x2460). Play requires an aspect
ratio of at most 2:1, so for a 1080-wide image the height must be <= 2160.
Pipeline per image:
  1. cut the black Android system-nav strip at the very bottom
  2. keep the BOTTOM 2160 rows of what remains (drops the status bar,
     keeps the app header and the bottom tab bar)
  3. save as play/screenshots/<name>.png
"""
from PIL import Image
import os

SRC_DIR = r"D:\T\tet_app\build\_audit"
OUT_DIR = r"D:\T\tet_app\play\screenshots"
W = 1080
MAX_H = 2160  # 1080 * 2

PICKS = [
    ("h2b_booklets_free.png", "01_utet_papers_free.png"),
    ("h12_ctet_booklets.png", "02_ctet_papers_free.png"),
    ("d16_hindi_subject.png", "03_subject_drills_hindi.png"),
    ("h9_history_focus.png", "04_history_weak_focus.png"),
]

os.makedirs(OUT_DIR, exist_ok=True)

def process(img):
    w, h = img.size
    if h < 2000:
        return img
    # 3-button nav = 144px (48dp @3x) at the bottom, status bar = 150px on top
    img = img.crop((0, 150, w, h - 144))
    w, h = img.size
    if h > MAX_H:
        # trim the leftover from the bottom (dark empty margin under the tab bar)
        img = img.crop((0, 0, w, MAX_H))
    return img

for src, out_name in PICKS:
    img = Image.open(os.path.join(SRC_DIR, src)).convert("RGB")
    img = process(img)
    out = os.path.join(OUT_DIR, out_name)
    img.save(out)
    print(f"{src} -> {out_name} {img.size}")

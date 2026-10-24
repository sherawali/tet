"""Play Store feature graphic 1024x500 for TET Rank - navy + gold rosette identity."""
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import math, os

W, H = 1024, 500
OUT = r"D:\T\tet_app\play\feature_graphic_1024x500.png"

EN_BOLD = r"C:\Windows\Fonts\arialbd.ttf"      # Latin
DEV = r"C:\Windows\Fonts\NirmalaB.ttf"          # Devanagari (Nirmala UI Bold)

NAVY_DEEP = (10, 17, 38)
NAVY_TOP = (24, 42, 84)
GOLD = (245, 180, 71)
GOLD_DEEP = (180, 83, 9)
GOLD_SOFT = (253, 230, 138)
CREAM = (246, 238, 216)

def font(size, dev=False):
    p = DEV if dev else EN_BOLD
    if os.path.exists(p):
        return ImageFont.truetype(p, size)
    return ImageFont.load_default()

def star(d, cx, cy, sr, fill, outline=None):
    pts = []
    for i in range(10):
        ang = -math.pi / 2 + i * math.pi / 5
        rad = sr if i % 2 == 0 else sr * 0.42
        pts.append((cx + math.cos(ang) * rad, cy + math.sin(ang) * rad))
    d.polygon(pts, fill=fill, outline=outline, width=2)

def rosette(img, cx, cy, r):
    d = ImageDraw.Draw(img)
    petals = 12
    pr = r * 0.17
    ring_r = r * 0.80
    # soft glow underneath
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=GOLD + (60,))
    glow = glow.filter(ImageFilter.GaussianBlur(r * 0.06))
    img.paste(glow, (0, 0), glow)
    for i in range(petals):
        a = 2 * math.pi * i / petals
        px, py = cx + math.cos(a) * ring_r, cy + math.sin(a) * ring_r
        d.ellipse([px - pr, py - pr, px + pr, py + pr], fill=GOLD_DEEP, outline=GOLD, width=3)
    d.ellipse([cx - ring_r, cy - ring_r, cx + ring_r, cy + ring_r],
              fill=GOLD_DEEP, outline=GOLD, width=max(1, int(r * 0.05)))
    d.ellipse([cx - r * 0.70, cy - r * 0.70, cx + r * 0.70, cy + r * 0.70],
              fill=GOLD_SOFT, outline=GOLD, width=3)
    d.ellipse([cx - r * 0.66, cy - r * 0.66, cx + r * 0.66, cy + r * 0.66],
              fill=NAVY_DEEP, outline=GOLD_DEEP, width=2)
    star(d, cx, cy - r * 0.30, r * 0.15, GOLD)
    f = font(int(r * 0.34), dev=False)
    bb = d.textbbox((0, 0), "TET", font=f)
    d.text((cx - (bb[2] - bb[0]) / 2 - bb[0], cy + r * 0.10 - (bb[3] - bb[1]) / 2 - bb[1]),
           "TET", font=f, fill=GOLD)
    uwr = r * 0.5
    d.line([cx - uwr / 2, cy + r * 0.44, cx + uwr / 2, cy + r * 0.44], fill=GOLD_DEEP, width=3)

# ---- canvas: vertical navy gradient ----
img = Image.new("RGB", (W, H))
d = ImageDraw.Draw(img)
for y in range(H):
    t = y / (H - 1)
    c = tuple(int(NAVY_TOP[i] + (NAVY_DEEP[i] - NAVY_TOP[i]) * t) for i in range(3))
    d.line([(0, y), (W, y)], fill=c)

# faint gold radial glow upper-left behind title
glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
gd = ImageDraw.Draw(glow)
gd.ellipse([-200, -140, 420, 260], fill=GOLD + (26,))
glow = glow.filter(ImageFilter.GaussianBlur(80))
img.paste(glow, (0, 0), glow)

# corner rules (exam-board look)
d = ImageDraw.Draw(img)
for x in (42, W - 42):
    d.line([(x, 54), (x, H - 54)], fill=GOLD_DEEP, width=3)
d.line([(42, 54), (W - 42, 54)], fill=GOLD_DEEP, width=2)
d.line([(42, H - 54), (W - 42, H - 54)], fill=GOLD_DEEP, width=2)

# ---- left: title block ----
f_title = font(72)
bb = d.textbbox((0, 0), "TET RANK", font=f_title)
d.text((88 - bb[0], 108 - bb[1]), "TET RANK", font=f_title, fill=GOLD)

f_sub = font(38)
bb2 = d.textbbox((0, 0), "UTET & CTET 2026", font=f_sub)
d.text((88 - bb2[0], 214 - bb2[1]), "UTET & CTET 2026", font=f_sub, fill=GOLD_SOFT)

f_stat = font(30)
stats = [
    "63 PAPERS  •  9,720 QUESTIONS",
    "MOCKS  •  DRILLS  •  RESULTS",
]
sy = 292
for line in stats:
    bb3 = d.textbbox((0, 0), line, font=f_stat)
    d.text((88 - bb3[0], sy - bb3[1]), line, font=f_stat, fill=CREAM)
    sy += 52

# CTA pill (English: Devanagari needs complex shaping that the local
# rasteriser cannot do, so the free-paper claim goes in Latin script)
f_cta = font(28, dev=False)
cta = "FIRST PAPER FREE"
pbb = d.textbbox((0, 0), cta, font=f_cta)
pw, ph = pbb[2] - pbb[0], pbb[3] - pbb[1]
pad_x, pill_h = 30, 52
py0 = 412
d.rounded_rectangle([88, py0, 88 + pw + 2 * pad_x, py0 + pill_h], pill_h // 2,
                    outline=GOLD, width=2)
d.text((88 + pad_x - pbb[0], py0 + (pill_h - ph) / 2 - pbb[1]), cta, font=f_cta, fill=GOLD)

# ---- right: big rosette ----
rosette(img, 790, 250, 148)

img.save(OUT)
print("saved", OUT, img.size)

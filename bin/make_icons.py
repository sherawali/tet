"""Generates the full launcher icon set for TET Rank (v2 - cleaner rosette).

- Adaptive icon foreground (transparent canvas, medal inside the 66% safe zone)
- Legacy ic_launcher / ic_launcher_round bitmaps (mdpi..xxxhdpi)
- Play Store listing icon (512x512)
Design language of the app: deep navy + brass-gold rosette medal with TET.
"""
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import math, os

ROOT = r"D:\T\tet_app\android\app\src\main\res"
PLAY_OUT = r"D:\T\tet_app\play\play_icon_512.png"

NAVY_DEEP = (10, 17, 38, 255)
NAVY = (15, 27, 58, 255)
NAVY_TOP = (24, 42, 84, 255)
GOLD = (245, 180, 71, 255)
GOLD_DEEP = (180, 83, 9, 255)
GOLD_SOFT = (253, 230, 138, 255)

FONT_PATHS = [
    r"C:\Windows\Fonts\arialbd.ttf",
    r"C:\Windows\Fonts\segoeuib.ttf",
]

def font(size):
    for p in FONT_PATHS:
        if os.path.exists(p):
            try:
                return ImageFont.truetype(p, size)
            except Exception:
                continue
    return ImageFont.load_default()

def glow_grad(size):
    img = Image.new("RGBA", (size, size))
    d = ImageDraw.Draw(img)
    for y in range(size):
        t = y / max(1, size - 1)
        c = tuple(int(NAVY_TOP[i] + (NAVY_DEEP[i] - NAVY_TOP[i]) * t) for i in range(3)) + (255,)
        d.line([(0, y), (size, y)], fill=c)
    return img

def star(d, cx, cy, sr, fill, outline, width):
    pts = []
    for i in range(10):
        ang = -math.pi / 2 + i * math.pi / 5
        rad = sr if i % 2 == 0 else sr * 0.42
        pts.append((cx + math.cos(ang) * rad, cy + math.sin(ang) * rad))
    d.polygon(pts, fill=fill, outline=outline, width=max(1, int(width)))

def rosette(img, cx, cy, r):
    """Scalloped rosette: a ring of petals peeking from behind the main disc."""
    d = ImageDraw.Draw(img)
    petals = 12
    pr = r * 0.17
    ring_r = r * 0.80
    # soft glow underneath
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=GOLD_DEEP[:3] + (70,))
    glow = glow.filter(ImageFilter.GaussianBlur(r * 0.05))
    img.alpha_composite(glow)
    for i in range(petals):
        a = 2 * math.pi * i / petals
        px, py = cx + math.cos(a) * ring_r, cy + math.sin(a) * ring_r
        d.ellipse([px - pr, py - pr, px + pr, py + pr],
                  fill=GOLD_DEEP, outline=GOLD, width=max(1, int(r * 0.025)))
    d.ellipse([cx - ring_r, cy - ring_r, cx + ring_r, cy + ring_r],
              fill=GOLD_DEEP, outline=GOLD, width=max(1, int(r * 0.04)))
    d.ellipse([cx - r * 0.70, cy - r * 0.70, cx + r * 0.70, cy + r * 0.70],
              fill=NAVY_DEEP, outline=GOLD_SOFT, width=max(1, int(r * 0.028)))
    d.ellipse([cx - r * 0.66, cy - r * 0.66, cx + r * 0.66, cy + r * 0.66],
              fill=NAVY, outline=GOLD_DEEP, width=max(1, int(r * 0.010)))

def medal(img, cx, cy, r, with_star=True, with_text=True):
    """Rosette + star + TET lettering, everything inside radius r."""
    rosette(img, cx, cy, r)
    d = ImageDraw.Draw(img)
    if with_star:
        star(d, cx, cy - r * 0.30, r * 0.15, GOLD, GOLD_SOFT, r * 0.012)
    if with_text:
        f = font(int(r * 0.40))
        t = "TET"
        bb = d.textbbox((0, 0), t, font=f)
        tw, th = bb[2] - bb[0], bb[3] - bb[1]
        tx, ty = cx - tw / 2 - bb[0], cy + r * 0.20 - th / 2 - bb[1]
        d.text((tx + r * 0.010, ty + r * 0.010), t, font=f, fill=(0, 0, 0, 190))
        d.text((tx, ty), t, font=f, fill=GOLD)
        uw = r * 0.56
        d.line([cx - uw / 2, cy + r * 0.50, cx + uw / 2, cy + r * 0.50],
               fill=GOLD_DEEP, width=max(1, int(r * 0.03)))

def ribbon(img, cx, top, w, h):
    """V ribbon under the medal with a notched tail."""
    d = ImageDraw.Draw(img)
    spread = w * 0.30
    for side in (-1, 1):
        x0 = cx + side * spread * 0.35
        x1 = cx + side * spread * 1.05
        cut = w * 0.14
        pts = [(x0, top), (x1, top),
               (x1, top + h), ((x0 + x1) / 2 + cut, top + h),
               (x0 + side * cut, top + h - h * 0.22), (x0, top + h - h * 0.30)]
        d.polygon(pts, fill=GOLD_DEEP)
        d.line(pts + [pts[0]], fill=GOLD, width=max(1, int(w * 0.025)))

def legacy_icon(size):
    img = glow_grad(size)
    rad = int(size * 0.22)
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size - 1, size - 1], rad, fill=255)
    rgb = Image.new("RGBA", img.size, (0, 0, 0, 0))
    rgb.paste(img, (0, 0), mask)
    medal(rgb, size / 2, size / 2, size * 0.36)
    return rgb

def round_icon(size):
    img = glow_grad(size)
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).ellipse([0, 0, size - 1, size - 1], fill=255)
    rgb = Image.new("RGBA", img.size, (0, 0, 0, 0))
    rgb.paste(img, (0, 0), mask)
    medal(rgb, size / 2, size / 2, size * 0.32)
    return rgb

def foreground_icon(size):
    """Adaptive foreground: transparent, content inside the 66% safe zone."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    medal(img, size / 2, size / 2, size * 0.30)
    return img

def play_icon(size=512):
    img = glow_grad(size)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([2, 2, size - 3, size - 3], int(size * 0.10),
                        outline=(GOLD_DEEP[0], GOLD_DEEP[1], GOLD_DEEP[2], 160), width=3)
    medal(img, size / 2, size / 2, size * 0.34)
    return img

LEGACY = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
FOREGROUND = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}

for dpi, s in LEGACY.items():
    folder = os.path.join(ROOT, f"mipmap-{dpi}")
    os.makedirs(folder, exist_ok=True)
    legacy_icon(s).save(os.path.join(folder, "ic_launcher.png"))
    round_icon(s).save(os.path.join(folder, "ic_launcher_round.png"))

for dpi, s in FOREGROUND.items():
    folder = os.path.join(ROOT, f"mipmap-{dpi}")
    os.makedirs(folder, exist_ok=True)
    foreground_icon(s).save(os.path.join(folder, "ic_launcher_foreground.png"))

os.makedirs(os.path.dirname(PLAY_OUT), exist_ok=True)
play_icon(512).save(PLAY_OUT)
print("done")

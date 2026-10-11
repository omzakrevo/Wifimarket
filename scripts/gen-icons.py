#!/usr/bin/env python3
"""Génère les icônes PWA (PNG) du logo WiFiMarket avec Pillow. Usage : python3 scripts/gen-icons.py"""
from PIL import Image, ImageDraw
import math, os

BLUE = (37, 99, 235); WHITE = (255, 255, 255); AMBER = (245, 158, 11); NAVY = (16, 42, 86)

def arc(draw, cx, cy, r, w, color, a0=-135, a1=-45):
    draw.arc((cx - r, cy - r, cx + r, cy + r), a0, a1, fill=color, width=int(w))
    for a in (a0, a1):  # extrémités arrondies
        x, y = cx + (r - w / 2) * math.cos(math.radians(a)), cy + (r - w / 2) * math.sin(math.radians(a))
        draw.ellipse((x - w / 2, y - w / 2, x + w / 2, y + w / 2), fill=color)

def icon(size, maskable=False):
    S = size * 4
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if maskable:
        d.rectangle((0, 0, S, S), fill=BLUE)
        scale = 0.62
    else:
        d.rounded_rectangle((0, 0, S - 1, S - 1), radius=int(S * 0.25), fill=BLUE)
        scale = 0.8
    cx, cy = S / 2, S * (0.60 if not maskable else 0.58)
    u = S * scale / 48 * 1.0
    w = int(3.5 * u * 1.6)
    arc(d, cx, cy, 22 * u * 0.95, w, WHITE)
    arc(d, cx, cy, 15 * u * 0.95, w, WHITE)
    arc(d, cx, cy, 8 * u * 0.95, w, AMBER)
    r = 3 * u
    d.ellipse((cx - r, cy - r + 6 * u, cx + r, cy + r + 6 * u), fill=AMBER)
    return img.resize((size, size), Image.LANCZOS)

out = os.path.join(os.path.dirname(__file__), "..", "public", "icons")
os.makedirs(out, exist_ok=True)
for s in (192, 512):
    icon(s).save(os.path.join(out, f"icon-{s}.png"))
icon(512, True).save(os.path.join(out, "maskable-512.png"))
icon(180).save(os.path.join(out, "apple-touch-icon.png"))
icon(64).save(os.path.join(out, "favicon-64.png"))
print("icônes générées")

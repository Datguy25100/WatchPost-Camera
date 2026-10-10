#!/usr/bin/env python3
"""Draws the WatchPost shield logo into assets/icon/*.png (needs: pip install pillow)."""
import os
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "icon")
BLUE = (56, 130, 246, 255)
WHITE = (255, 255, 255, 255)
SS = 4          # supersampling for smooth edges
SIZE = 1024


def bez(p0, p1, p2, p3, n=60):
    pts = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        pts.append((u**3*p0[0] + 3*u*u*t*p1[0] + 3*u*t*t*p2[0] + t**3*p3[0],
                    u**3*p0[1] + 3*u*u*t*p1[1] + 3*u*t*t*p2[1] + t**3*p3[1]))
    return pts


def logo_paths():
    """Same geometry as lib/widgets/logo.dart (64 x 72 box)."""
    shield = [(32, 3), (57, 12), (57, 32)]
    shield += bez((57, 32), (57, 50), (47, 61), (32, 69))[1:]
    shield += bez((32, 69), (17, 61), (7, 50), (7, 32))[1:]
    shield += [(7, 12), (32, 3)]
    import math
    head = [(32 + 9*math.cos(a/60*2*math.pi), 29 + 9*math.sin(a/60*2*math.pi)) for a in range(61)]
    return [shield, head, [(20, 51), (44, 51)], [(32, 38), (32, 51)]]


def draw_logo(img, height_frac, stroke_units=4.6):
    d = ImageDraw.Draw(img)
    W = img.size[0]
    scale = (W * height_frac) / 72.0            # px per logo unit
    ox = (W - 64 * scale) / 2
    oy = (W - 72 * scale) / 2
    w = stroke_units * scale
    for path in logo_paths():
        pts = [(ox + x*scale, oy + y*scale) for x, y in path]
        d.line(pts, fill=WHITE, width=int(w), joint="curve")
        for x, y in pts[:: max(1, len(pts)//40)] + [pts[0], pts[-1]]:   # round caps / joins
            d.ellipse([x - w/2, y - w/2, x + w/2, y + w/2], fill=WHITE)


def make(name, background, height_frac):
    big = Image.new("RGBA", (SIZE*SS, SIZE*SS), background)
    draw_logo(big, height_frac)
    img = big.resize((SIZE, SIZE), Image.LANCZOS)
    if background[3] == 255:
        img = img.convert("RGB")               # iOS wants no alpha
    img.save(os.path.join(OUT, name))
    print("wrote", name)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    make("icon.png", BLUE, 0.62)                       # full icon (iOS + legacy Android)
    make("icon_foreground.png", (0, 0, 0, 0), 0.52)    # Android adaptive foreground (safe zone)

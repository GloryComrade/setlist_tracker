"""Draws the Setlist Tracker app icon (concert-poster ticket) with Pillow.

    python3 tool/app_icon.py            # writes the ios/ and web/ icons
    python3 tool/app_icon.py --preview  # also writes build/icon_preview.png

The art follows DESIGN.md: the headline gradient (Violet Deep -> Magenta Deep
-> Orange Deep, top-left to bottom-right), a black 20% halftone that grows
toward the bottom-right, and a white ticket stub with a cut-out double note.
iOS masks the corners itself, so the 1024 master is a full, opaque square.
"""
import json
import math
import os
import sys

from PIL import Image, ImageChops, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SS = 4  # supersampling
S = 1024 * SS

VIOLET = (0x6D, 0x28, 0xD9)
MAGENTA = (0xE0, 0x15, 0x7A)
ORANGE = (0xC2, 0x41, 0x0C)
WHITE = (0xF5, 0xF3, 0xFA)
STAGE_BLACK = (0x0B, 0x0A, 0x12)


def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def gradient(size):
    """Three-stop diagonal gradient, built small and scaled up (smooth)."""
    n = 256
    g = Image.new("RGB", (n, n))
    px = g.load()
    for y in range(n):
        for x in range(n):
            t = (x + y) / (2 * (n - 1))
            if t < 0.5:
                px[x, y] = lerp(VIOLET, MAGENTA, t / 0.5)
            else:
                px[x, y] = lerp(MAGENTA, ORANGE, (t - 0.5) / 0.5)
    return g.resize((size, size), Image.BICUBIC)


def halftone(size, cell):
    """Black dots on a triangular screen, growing toward the bottom-right."""
    layer = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(layer)
    max_r = cell * 0.36
    row = 0
    y = cell / 2
    while y < size + cell:
        x = cell / 2 if row % 2 else 0.0
        while x < size + cell:
            t = ((x + y) / (2 * size) - 0.32) / 0.68
            if t > 0:
                r = max_r * min(1.0, t) ** 0.9
                if r > cell * 0.05:
                    d.ellipse((x - r, y - r, x + r, y + r), fill=255)
            x += cell
        y += cell * 0.866
        row += 1
    return layer


def ticket_mask(size):
    """White ticket with notches, a tear line, a star stub and a note."""
    m = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(m)
    u = size / 1024 * 0.92  # design units are 1024-space, art at 92%
    w, h = 780 * u, 452 * u
    cx, cy = size / 2, size / 2
    x0, y0, x1, y1 = cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2
    d.rounded_rectangle((x0, y0, x1, y1), radius=44 * u, fill=255)

    # Tear line between stub and ticket: notches top and bottom, then holes.
    tear = x0 + w * 0.30
    nr = 40 * u
    d.ellipse((tear - nr, y0 - nr, tear + nr, y0 + nr), fill=0)
    d.ellipse((tear - nr, y1 - nr, tear + nr, y1 + nr), fill=0)
    hr = 9 * u
    holes = 7
    top, bot = y0 + nr + 26 * u, y1 - nr - 26 * u
    for i in range(holes):
        hy = top + (bot - top) * i / (holes - 1)
        d.ellipse((tear - hr, hy - hr, tear + hr, hy + hr), fill=0)

    # Stub: a bold star, the headline act.
    sx, sy = x0 + (tear - x0) / 2 + 4 * u, cy
    ro, ri = 76 * u, 32 * u
    pts = []
    for k in range(10):
        a = -math.pi / 2 + k * math.pi / 5
        r = ro if k % 2 == 0 else ri
        pts.append((sx + r * math.cos(a), sy + r * math.sin(a)))
    d.polygon(pts, fill=0)

    # Ticket: beamed double note cut out of the white.
    nx = tear + (x1 - tear) / 2 - 6 * u
    stem_w = 30 * u
    head_rx, head_ry = 60 * u, 44 * u
    gap = 176 * u
    left_stem_x = nx - gap / 2 + head_rx - stem_w / 2
    right_stem_x = nx + gap / 2 + head_rx - stem_w / 2
    head_y_l = cy + 108 * u
    head_y_r = cy + 78 * u
    beam_top_l = cy - 150 * u
    beam_top_r = cy - 180 * u
    beam_h = 64 * u

    def head(hx, hy):
        e = Image.new("L", m.size, 0)
        ImageDraw.Draw(e).ellipse(
            (hx - head_rx, hy - head_ry, hx + head_rx, hy + head_ry), fill=255)
        return e.rotate(22, center=(hx, hy), resample=Image.BICUBIC)

    cut = Image.new("L", m.size, 0)
    cd = ImageDraw.Draw(cut)
    for stem_x, top_y, hy in ((left_stem_x, beam_top_l, head_y_l),
                              (right_stem_x, beam_top_r, head_y_r)):
        cd.rectangle((stem_x - stem_w / 2, top_y + 10 * u,
                      stem_x + stem_w / 2, hy - 10 * u), fill=255)
    cd.polygon([
        (left_stem_x - stem_w / 2, beam_top_l),
        (right_stem_x + stem_w / 2, beam_top_r),
        (right_stem_x + stem_w / 2, beam_top_r + beam_h),
        (left_stem_x - stem_w / 2, beam_top_l + beam_h),
    ], fill=255)
    cut = ImageChops.lighter(
        cut, head(left_stem_x - head_rx + stem_w / 2, head_y_l))
    cut = ImageChops.lighter(
        cut, head(right_stem_x - head_rx + stem_w / 2, head_y_r))
    m = ImageChops.subtract(m, cut)
    return m.rotate(12, center=(cx, cy), resample=Image.BICUBIC)


def master():
    bg = gradient(S)
    dots = halftone(S, 40 * SS)
    black = Image.new("RGB", (S, S), (0, 0, 0))
    bg = Image.composite(black, bg, dots.point(lambda v: round(v * 0.22)))
    white = Image.new("RGB", (S, S), WHITE)
    img = Image.composite(white, bg, ticket_mask(S))
    return img.resize((1024, 1024), Image.LANCZOS)


def save(img, path, size):
    full = os.path.join(ROOT, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    out = img
    if img.size != (size, size):
        out = img.resize((size, size), Image.LANCZOS)
    out.convert("RGB").save(full, optimize=True)


def maskable(img, size):
    """Web maskable icon: the art shrunk into the 80% safe zone over the
    full-bleed art, so any mask shape keeps the whole ticket."""
    bg = img.resize((size, size), Image.LANCZOS)
    inner = int(size * 0.80)
    art = img.resize((inner, inner), Image.LANCZOS)
    bg.paste(art, ((size - inner) // 2, (size - inner) // 2))
    return bg


def main():
    img = master()
    appicon = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    with open(os.path.join(ROOT, appicon, "Contents.json")) as f:
        contents = json.load(f)
    for entry in contents["images"]:
        pt = float(entry["size"].split("x")[0])
        px = round(pt * int(entry["scale"].rstrip("x")))
        save(img, f"{appicon}/{entry['filename']}", px)
    save(img, "web/icons/Icon-192.png", 192)
    save(img, "web/icons/Icon-512.png", 512)
    save(maskable(img, 192), "web/icons/Icon-maskable-192.png", 192)
    save(maskable(img, 512), "web/icons/Icon-maskable-512.png", 512)
    save(img, "web/favicon.png", 32)
    # Launch screen: Stage Black, so the app opens without a white flash.
    launch = "ios/Runner/Assets.xcassets/LaunchImage.imageset"
    for name, px in (("LaunchImage.png", 1), ("LaunchImage@2x.png", 2),
                     ("LaunchImage@3x.png", 3)):
        Image.new("RGB", (px, px), STAGE_BLACK).save(
            os.path.join(ROOT, launch, name))
    if "--preview" in sys.argv:
        save(img, "build/icon_preview.png", 1024)


if __name__ == "__main__":
    main()

"""Draws the app's bundled sample art: the venue prints that sit on Show
posters.

Each print is one layer of dark ink, saved as a PNG with an alpha channel.
The app paints the venue's stage-light gradient underneath and the halftone
screen on top, so the poster reads as a screen print in two or three inks:
the two deep shades of the gradient plus this black overprint. Because the
ink is only ever black at low opacity, it can only darken the gradient, so
white type on the poster never loses contrast.

  print_live.png    Live Show: a topographic map with a route and mile ticks
  print_studio.png  Studio Session: a treadmill seen from behind

Everything is drawn here from math, so the images are ours, with no photos,
no stock licenses and no outside source material.

    python3 tool/sample_art.py        # writes assets/images/print_*.png
    python3 tool/sample_art.py --check  # redraws in memory, compares bytes

Needs Pillow and numpy (tested with Pillow 12.3 and numpy 2.5). There is no
randomness: every shape comes from fixed formulas, so running it again gives
the same files.
"""

import io
import math
import os
import sys

import numpy as np
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "images")

# 1080 px square: a 358 pt poster at @3x, cover-fit and centered, so the
# motif sits on the right half and the left 45% (where the type sits) stays
# clear in every crop from 358 x 160 to 358 x 400.
S = 1080

# Ink densities, as alpha of black. The halftone screen in the app prints at
# 20%, so the prints sit on the same scale.
LIGHT = 0.16
MID = 0.24
HEAVY = 0.40


def grid():
    y, x = np.mgrid[0:S, 0:S].astype(np.float64)
    return x / S, y / S


def smoothstep(a, b, t):
    k = np.clip((t - a) / (b - a), 0, 1)
    return k * k * (3 - 2 * k)


def text_side_fade(x):
    """0 over the type on the left, 1 from just past the middle."""
    return smoothstep(0.46, 0.64, x)


def stroke(points, width):
    """Coverage (0..1) of an anti-aliased polyline, drawn 4x and reduced."""
    from PIL import ImageDraw

    k = 4
    big = Image.new("L", (S * k, S * k), 0)
    d = ImageDraw.Draw(big)
    pts = [(px * S * k, py * S * k) for px, py in points]
    w = int(round(width * k))
    d.line(pts, fill=255, width=w, joint="curve")
    r = w / 2
    for px, py in (pts[0], pts[-1]):
        d.ellipse((px - r, py - r, px + r, py + r), fill=255)
    return np.asarray(big.resize((S, S), Image.LANCZOS), np.float64) / 255


def disc(cx, cy, r, ring=0.0):
    """Coverage of a filled disc, or of a ring of the given width."""
    x, y = grid()
    d = np.hypot(x - cx, y - cy) * S
    outer = np.clip(r * S - d + 0.5, 0, 1)
    if ring <= 0:
        return outer
    inner = np.clip(d - (r * S - ring) + 0.5, 0, 1)
    return outer * inner


def over(ink, coverage, alpha):
    """Print one more pass of black ink at `alpha` where `coverage` is 1.
    Overprints build up like real ink: a + b - ab."""
    a = coverage * alpha
    return ink + a - ink * a


def save(ink, name):
    data = encode(ink)
    with open(os.path.join(OUT, name), "wb") as f:
        f.write(data)
    print(name, f"{len(data) // 1024} KB")


def encode(ink):
    a = (np.clip(ink, 0, 1) * 255).round().astype(np.uint8)
    rgba = np.zeros((S, S, 4), np.uint8)
    rgba[..., 3] = a  # black ink: RGB stays 0
    buf = io.BytesIO()
    Image.fromarray(rgba, "RGBA").save(buf, "PNG", optimize=True)
    return buf.getvalue()


# --- Live Show: the route map ------------------------------------------------


def hills(x, y):
    """A smooth landscape: a few round hills and a long ridge."""
    h = np.zeros_like(x)
    for cx, cy, r, amp in (
        (0.78, 0.30, 0.20, 1.0),
        (0.62, 0.78, 0.17, 0.75),
        (0.95, 0.72, 0.22, 0.85),
        (0.50, 0.42, 0.14, 0.45),
    ):
        h += amp * np.exp(-((x - cx) ** 2 + (y - cy) ** 2) / (2 * r * r))
    h += 0.18 * np.sin(x * 7.0 + y * 3.0) * np.cos(y * 5.0 - x * 2.0)
    return h


def contours(h, step, width_px):
    """Anti-aliased isolines of h every `step`, `width_px` wide."""
    v = h / step
    gy, gx = np.gradient(v)
    g = np.hypot(gx, gy) + 1e-9
    f = v - np.floor(v)
    dist = np.minimum(f, 1 - f) / g  # in pixels from the nearest line
    return np.clip(width_px / 2 - dist + 0.5, 0, 1), np.floor(v + 0.5)


def route_points():
    """A loop that climbs the big hill and comes home along the valley."""
    pts = []
    n = 400
    for i in range(n + 1):
        t = i / n
        a = 2 * math.pi * t
        # A lopsided loop, longer than it is wide, with one switchback.
        px = 0.79 + 0.15 * math.sin(a) + 0.03 * math.sin(3 * a + 0.6)
        py = 0.50 - 0.17 * math.cos(a) + 0.035 * math.sin(2 * a)
        pts.append((px, py))
    return pts


def mile_ticks(pts, every, length):
    """Short bars across the route every `every` of its length."""
    seg = [math.dist(pts[i], pts[i + 1]) for i in range(len(pts) - 1)]
    total = sum(seg)
    marks, walked, target = [], 0.0, every
    for i, s in enumerate(seg):
        while walked + s >= target and target < total - every * 0.5:
            k = (target - walked) / s
            (x0, y0), (x1, y1) = pts[i], pts[i + 1]
            mx, my = x0 + (x1 - x0) * k, y0 + (y1 - y0) * k
            dx, dy = (x1 - x0) / s, (y1 - y0) / s
            nx, ny = -dy * length, dx * length
            marks.append([(mx - nx, my - ny), (mx + nx, my + ny)])
            target += every
        walked += s
    return marks


def print_live():
    x, y = grid()
    fade = text_side_fade(x)
    h = hills(x, y)
    lines, level = contours(h, 0.085, 2.2)
    index = (level.astype(int) % 5 == 0).astype(np.float64)
    ink = np.zeros((S, S))
    ink = over(ink, lines * (1 - index) * fade, LIGHT)
    ink = over(ink, lines * index * fade, MID)
    pts = route_points()
    route = stroke(pts, 9)
    ticks = np.zeros((S, S))
    for a, b in mile_ticks(pts, 0.085, 0.016):
        ticks = np.maximum(ticks, stroke([a, b], 4))
    start = disc(*pts[0], 0.022, ring=6)
    ink = over(ink, np.maximum(np.maximum(route, ticks), start) * fade, HEAVY)
    save(ink, "print_live.png")
    return ink


# --- Studio Session: the treadmill deck --------------------------------------


def print_studio():
    """A treadmill seen from behind, whole, like an object on a poster: the
    deck in a light tint, slats that crowd together with distance, two side
    rails, the rear roller, and the console with its handlebar and side
    handrails at the far end. Sized so all of it shows in the shortest Show
    poster crop."""
    from PIL import ImageDraw

    x, _ = grid()
    fade = text_side_fade(x)
    # Simple perspective: depth z runs 1 (near) to FAR; a point at (X, z)
    # lands at x = CX + X / z, y = HORIZON + H / z.
    CX, HORIZON, H, HALF, FAR = 0.79, 0.10, 0.66, 0.19, 1.75

    def at(u, z):
        return CX + (u * 2 - 1) * HALF / z, HORIZON + H / z

    def fill(poly):
        k = 4
        big = Image.new("L", (S * k, S * k), 0)
        ImageDraw.Draw(big).polygon([(px * S * k, py * S * k) for px, py in poly], fill=255)
        return np.asarray(big.resize((S, S), Image.LANCZOS), np.float64) / 255

    ink = np.zeros((S, S))
    ink = over(ink, fill([at(0, 1), at(0, FAR), at(1, FAR), at(1, 1)]) * fade, LIGHT)
    # Slats every equal step of belt, so they crowd with distance.
    slats = np.zeros((S, S))
    z = 1.06
    while z < FAR - 0.03:
        slats = np.maximum(slats, stroke([at(0.05, z), at(0.95, z)], max(1.6, 5.0 / z)))
        z += 0.075 * z  # equal steps on the belt look shorter further off
    ink = over(ink, slats * fade, MID)
    # The console: a panel in the mid tint above the far end of the deck.
    (lx, ly), (rx, ry) = at(-0.06, FAR), at(1.06, FAR)
    up = 0.14
    ink = over(ink, fill([(lx + 0.01, ly - up - 0.05), (rx - 0.01, ry - up - 0.05),
                          (rx - 0.01, ry - up), (lx + 0.01, ly - up)]) * fade, MID)
    def handrail(u, z_end=1.4):
        (ex, ey), (fx, fy) = at(u, z_end), at(u, FAR)
        return stroke([(fx, fy - up), (ex, ey - up * FAR / z_end)], 7)

    heavy = np.maximum.reduce([
        stroke([at(-0.06, 1), at(-0.06, FAR)], 9),  # side rails
        stroke([at(1.06, 1), at(1.06, FAR)], 9),
        stroke([at(-0.06, 1), at(1.06, 1)], 14),  # rear roller
        stroke([(lx, ly), (lx, ly - up)], 6),  # uprights
        stroke([(rx, ry), (rx, ry - up)], 6),
        stroke([(lx - 0.02, ly - up), (rx + 0.02, ry - up)], 7),  # handlebar
        # Side handrails reaching back toward you, at the same height in
        # perspective, so it reads as a treadmill and not a flask.
        handrail(-0.06),
        handrail(1.06),
    ])
    ink = over(ink, heavy * fade, HEAVY)
    save(ink, "print_studio.png")
    return ink


def check():
    """Redraw in memory and compare with the committed files."""
    global save
    drawn = {}
    save = lambda ink, name: drawn.__setitem__(name, encode(ink))  # noqa: E731
    print_live()
    print_studio()
    ok = True
    for name, data in drawn.items():
        with open(os.path.join(OUT, name), "rb") as f:
            same = f.read() == data
        print(name, "matches" if same else "DIFFERS")
        ok &= same
    return ok


if __name__ == "__main__":
    if "--check" in sys.argv:
        sys.exit(0 if check() else 1)
    os.makedirs(OUT, exist_ok=True)
    print_live()
    print_studio()

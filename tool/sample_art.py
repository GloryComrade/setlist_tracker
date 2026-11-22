"""Draws the app's bundled sample art: the venue prints that sit on Show
posters.

Each print is one layer of dark ink, saved as a PNG with an alpha channel.
The app paints the venue's stage-light gradient underneath and the halftone
screen on top, so the poster reads as a screen print in two or three inks:
the two deep shades of the gradient plus this black overprint. Because the
ink is only ever black at low opacity, it can only darken the gradient, so
white type on the poster never loses contrast.

  print_live.png    Live Show: a topographic map with a loop route and ticks
  print_studio.png  Studio Session: a treadmill seen side-on, console first

The app sets each print beside the poster's type, never under it: it is
drawn to the poster's height, starts past the widest line of type, and runs
off the poster's right edge (PrintBeside in lib/ui/widgets/stage_widgets.dart).
So each print is a tall 9:10 sheet whose subject sits in its left 60%, the
part that always shows, with a soft left edge where it meets the type.

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
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "images")

# 810 x 900 px: 9:10, about a 300 pt tall poster at @3x. Keep in step with
# StageArt.printAspect.
W, H = 810, 900

# Ink densities, as alpha of black. The halftone screen in the app prints at
# 20%, so the prints sit on the same scale. Passes combine with max(), the
# way one screen of a single ink works, so no pixel ever passes HEAVY.
LIGHT = 0.16
MID = 0.24
HEAVY = 0.40


def grid():
    """x and y in 0..1 across the width and the height."""
    y, x = np.mgrid[0:H, 0:W].astype(np.float64)
    return x / W, y / H


def smoothstep(a, b, t):
    k = np.clip((t - a) / (b - a), 0, 1)
    return k * k * (3 - 2 * k)


def soft_left(x):
    """0 at the print's left edge, where it meets the type, 1 by 16% in."""
    return smoothstep(0.0, 0.16, x)


def _px(points):
    k = 4
    return [(px * W * k, py * H * k) for px, py in points], k


def _reduce(big):
    return np.asarray(big.resize((W, H), Image.LANCZOS), np.float64) / 255


def stroke(points, width):
    """Coverage (0..1) of an anti-aliased polyline, `width` px wide, drawn
    4x and reduced. Points are in 0..1 of the width and the height."""
    pts, k = _px(points)
    big = Image.new("L", (W * k, H * k), 0)
    d = ImageDraw.Draw(big)
    w = int(round(width * k))
    d.line(pts, fill=255, width=w, joint="curve")
    r = w / 2
    for px, py in (pts[0], pts[-1]):
        d.ellipse((px - r, py - r, px + r, py + r), fill=255)
    return _reduce(big)


def fill(points):
    """Coverage of a filled polygon."""
    pts, k = _px(points)
    big = Image.new("L", (W * k, H * k), 0)
    ImageDraw.Draw(big).polygon(pts, fill=255)
    return _reduce(big)


def ring(cx, cy, r_px, width_px=0.0):
    """Coverage of a disc (or a ring `width_px` wide) of radius `r_px`,
    centered at (cx, cy) in 0..1 coordinates."""
    x, y = grid()
    d = np.hypot((x - cx) * W, (y - cy) * H)
    outer = np.clip(r_px - d + 0.5, 0, 1)
    if width_px <= 0:
        return outer
    return outer * np.clip(d - (r_px - width_px) + 0.5, 0, 1)


def ink_pass(ink, coverage, alpha):
    """Print one more pass at `alpha` where `coverage` is 1. One screen of a
    single ink: overlaps take the darker value, never the sum."""
    return np.maximum(ink, coverage * alpha)


def save(ink, name):
    data = encode(ink)
    with open(os.path.join(OUT, name), "wb") as f:
        f.write(data)
    print(name, f"{len(data) // 1024} KB")


def encode(ink):
    a = (np.clip(ink, 0, HEAVY) * 255).round().astype(np.uint8)
    rgba = np.zeros((H, W, 4), np.uint8)
    rgba[..., 3] = a  # black ink: RGB stays 0
    buf = io.BytesIO()
    Image.fromarray(rgba, "RGBA").save(buf, "PNG", optimize=True)
    return buf.getvalue()


# --- Live Show: the route map ------------------------------------------------


def hills(x, y):
    """A smooth landscape: a few round hills and a long ridge. y is scaled
    by the sheet's aspect so the hills stay round."""
    ys = y * H / W
    h = np.zeros_like(x)
    for cx, cy, r, amp in (
        (0.40, 0.30, 0.22, 1.0),
        (0.78, 0.86, 0.20, 0.8),
        (0.95, 0.30, 0.18, 0.6),
        (0.18, 0.95, 0.16, 0.5),
    ):
        h += amp * np.exp(-((x - cx) ** 2 + (ys - cy) ** 2) / (2 * r * r))
    h += 0.16 * np.sin(x * 6.0 + ys * 3.0) * np.cos(ys * 5.0 - x * 2.0)
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
    """A loop that climbs the big hill and comes home along the valley, in
    the left 60% of the sheet, which always shows."""
    pts = []
    n = 400
    for i in range(n + 1):
        a = 2 * math.pi * i / n
        px = 0.36 + 0.19 * math.sin(a) + 0.035 * math.sin(3 * a + 0.6)
        py = 0.50 - 0.27 * math.cos(a) + 0.04 * math.sin(2 * a)
        pts.append((px, py))
    return pts


def mile_ticks(pts, every, length):
    """Short bars across the route every `every` of its length (in px)."""
    P = [(x * W, y * H) for x, y in pts]
    seg = [math.dist(P[i], P[i + 1]) for i in range(len(P) - 1)]
    total = sum(seg)
    marks, walked, target = [], 0.0, every
    for i, s in enumerate(seg):
        while walked + s >= target and target < total - every * 0.5:
            k = (target - walked) / s
            (x0, y0), (x1, y1) = P[i], P[i + 1]
            mx, my = x0 + (x1 - x0) * k, y0 + (y1 - y0) * k
            dx, dy = (x1 - x0) / s, (y1 - y0) / s
            nx, ny = -dy * length, dx * length
            marks.append([((mx - nx) / W, (my - ny) / H),
                          ((mx + nx) / W, (my + ny) / H)])
            target += every
        walked += s
    return marks


def print_live():
    x, y = grid()
    fade = soft_left(x)
    lines, level = contours(hills(x, y), 0.085, 2.2)
    index = (level.astype(int) % 5 == 0).astype(np.float64)
    ink = np.zeros((H, W))
    ink = ink_pass(ink, lines * (1 - index) * fade, LIGHT)
    ink = ink_pass(ink, lines * index * fade, MID)
    pts = route_points()
    route = stroke(pts, 10)
    ticks = np.zeros((H, W))
    for a, b in mile_ticks(pts, 70, 13):
        ticks = np.maximum(ticks, stroke([a, b], 4))
    sx, sy = pts[0]
    start = ring(sx, sy, 20, 6)
    ink = ink_pass(ink, np.maximum.reduce([route, ticks, start]), HEAVY)
    save(ink, "print_live.png")
    return ink


# --- Studio Session: the treadmill -------------------------------------------


def print_studio():
    """A treadmill side-on, facing left, the way you'd draw one to name it:
    the console with its readout on a raked upright, the handrail, the motor
    hood over the front roller and the belt loop running off the right
    edge. The console end sits in the left 60% of the sheet, which always
    shows; the belt bleeds off the poster like a print that runs to the
    trim."""
    x, _ = grid()
    fade = soft_left(x)
    ink = np.zeros((H, W))

    # The deck rises slightly toward the front (incline).
    fx, fy = 0.30, 0.70  # front roller center
    rx, ry = 1.30, 0.76  # rear roller, past the edge
    rr = 0.055 * W  # roller radius in px

    def deck_y(px, offset):
        t = (px - fx) / (rx - fx)
        return fy + (ry - fy) * t + offset

    top = rr / H
    # The belt loop: top and bottom runs around the two rollers.
    belt = np.maximum.reduce([
        stroke([(fx, deck_y(fx, -top)), (rx, deck_y(rx, -top))], 9),
        stroke([(fx, deck_y(fx, top)), (rx, deck_y(rx, top))], 9),
        ring(fx, fy, rr + 4.5, 9),
    ])
    # The deck between the runs, in a light tint, with belt slats.
    deck = fill([(fx, deck_y(fx, -top)), (rx, deck_y(rx, -top)),
                 (rx, deck_y(rx, top)), (fx, deck_y(fx, top))])
    ink = ink_pass(ink, (deck + ring(fx, fy, rr)).clip(0, 1) * fade, LIGHT)
    slats = np.zeros((H, W))
    sx = fx + 0.06
    while sx < 1.05:
        slats = np.maximum(slats, stroke(
            [(sx, deck_y(sx, -top) + 0.010), (sx - 0.012, deck_y(sx, top) - 0.010)], 3))
        sx += 0.045
    ink = ink_pass(ink, slats * fade, MID)

    # Motor hood: a rounded cowl over the front roller.
    hood = fill([
        (fx - 0.085, fy + 0.02), (fx - 0.08, fy - 0.045), (fx - 0.04, fy - 0.085),
        (fx + 0.10, deck_y(fx + 0.10, -top) - 0.025), (fx + 0.13, deck_y(fx + 0.13, -top)),
        (fx + 0.02, fy + 0.03),
    ])
    ink = ink_pass(ink, hood * fade, MID)

    # Feet under the frame.
    feet = np.maximum(
        stroke([(fx - 0.05, fy + 0.09), (fx + 0.08, fy + 0.09)], 10),
        stroke([(fx + 0.01, fy + 0.05), (fx + 0.01, fy + 0.09)], 9),
    )

    # The upright, raked forward from the hood to the console.
    base = (fx - 0.03, fy - 0.06)
    head = (0.17, 0.27)
    upright = stroke([base, head], 16)

    # The console: a tilted panel facing the runner, with a readout window
    # left clear of heavy ink and three readout bars in it.
    def tilt(cx, cy, w, h, a):
        ca, sa = math.cos(a), math.sin(a)
        pts = []
        for ux, uy in ((-w, -h), (w, -h), (w, h), (-w, h)):
            pts.append((cx + (ux * ca - uy * sa) / W, cy + (ux * sa + uy * ca) / H))
        return pts

    a = math.radians(-16)
    cx, cy = 0.20, 0.215
    panel = fill(tilt(cx, cy, 0.14 * W, 0.055 * H, a))
    window = fill(tilt(cx + 0.012, cy - 0.004, 0.085 * W, 0.027 * H, a))
    ink = ink_pass(ink, panel * (1 - window) * fade, HEAVY)
    ink = ink_pass(ink, window * fade, LIGHT)
    bars = np.zeros((H, W))
    for i, wbar in enumerate((0.05, 0.03, 0.04)):
        bx = cx - 0.045 + i * 0.045
        by = cy - 0.004 + (bx - cx) * math.tan(a) * W / H
        bars = np.maximum(bars, fill(tilt(bx, by, 0.016 * W, 0.012 * H, a)))
    ink = ink_pass(ink, bars * fade, HEAVY)

    # The handrail: level with the runner's waist, from the console back
    # over the front of the belt, ending in a short drop.
    rail = stroke([(0.19, 0.325), (0.56, 0.34), (0.585, 0.375)], 11)

    heavy = np.maximum.reduce([belt, feet, upright, rail])
    ink = ink_pass(ink, heavy * fade, HEAVY)
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

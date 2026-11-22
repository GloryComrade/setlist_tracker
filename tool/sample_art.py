"""Draws the app's bundled sample art: stage backdrops for the poster headers
and sample sleeves for songs with no album art.

Everything is drawn here from noise and shapes, so the images are ours, with
no photos, no stock licenses and no copyrighted album art.

    python3 tool/sample_art.py        # writes assets/images/*.jpg

Seeds are fixed, so running it again gives the same files.
"""

import math
import os

import numpy as np
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "images")

# The stage colors from lib/theme/app_theme.dart.
MAGENTA = (0xE0, 0x15, 0x7A)
ORANGE = (0xC2, 0x41, 0x0C)
VIOLET = (0x6D, 0x28, 0xD9)
TEAL = (0x0E, 0x74, 0x90)
AMBER = (0xFF, 0xB0, 0x20)
CYAN = (0x22, 0xD3, 0xEE)
PINK = (0xFF, 0x4D, 0x9A)
BLACK = (0x0B, 0x0A, 0x12)


def c(rgb):
    return np.array(rgb, dtype=np.float32) / 255.0


def _box(a, k, axis):
    """Running-mean blur of width 2k+1 along one axis, edges clamped."""
    pad = [(0, 0)] * a.ndim
    pad[axis] = (k + 1, k)
    p = np.pad(a, pad, mode="edge")
    cs = np.cumsum(p, axis=axis, dtype=np.float64)
    hi = np.take(cs, range(2 * k + 1, cs.shape[axis]), axis=axis)
    lo = np.take(cs, range(0, cs.shape[axis] - 2 * k - 1), axis=axis)
    return ((hi - lo) / (2 * k + 1)).astype(np.float32)


def blur(a, r):
    """Gaussian-like blur (three box passes) of a float array, in float so
    smooth haze doesn't band the way 8-bit would."""
    k = max(1, int(round(r * 0.9)))
    if r <= 0:
        return a
    for _ in range(3):
        a = _box(_box(a, k, 0), k, 1)
    return a


def grid(w, h):
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    return x / w, y / h


def wash(w, h, stops, angle=0.6):
    """Diagonal multi-stop color wash, top-left to bottom-right."""
    x, y = grid(w, h)
    t = np.clip(x * math.cos(angle) + y * math.sin(angle), 0, None)
    t = t / t.max()
    out = np.zeros((h, w, 3), np.float32)
    n = len(stops) - 1
    for i in range(n):
        a, b = c(stops[i]), c(stops[i + 1])
        lo, hi = i / n, (i + 1) / n
        m = (t >= lo) & (t <= hi)
        k = ((t - lo) / (hi - lo))[..., None]
        out = np.where(m[..., None], a * (1 - k) + b * k, out)
    return out


def beam(w, h, x0, spread, tilt, color, power=1.0):
    """A cone of light from a fixture above the frame."""
    x, y = grid(w, h)
    aspect = w / h
    yy = y + 0.08
    cx = x0 + tilt * yy
    dist = np.abs((x - cx) * aspect) / (spread * yy + 0.01)
    core = np.exp(-(dist**2) * 2.2) * (1.0 - 0.55 * y) * power
    return core[..., None] * c(color)


def bokeh(rng, w, h, n, colors, rmin, rmax, ymax=1.0, alpha=0.7):
    out = np.zeros((h, w, 3), np.float32)
    x, y = np.mgrid[0:h, 0:w]
    for _ in range(n):
        cx, cy = rng.uniform(0, w), rng.uniform(0, h * ymax)
        r = rng.uniform(rmin, rmax)
        col = c(colors[rng.integers(len(colors))])
        x0, x1 = int(max(0, cx - r - 2)), int(min(w, cx + r + 2))
        y0, y1 = int(max(0, cy - r - 2)), int(min(h, cy + r + 2))
        if x1 <= x0 or y1 <= y0:
            continue
        d = np.hypot(x[y0:y1, x0:x1] - cy, y[y0:y1, x0:x1] - cx) / r
        disc = np.clip((1.0 - d) * 6, 0, 1) * (0.55 + 0.45 * d)  # bright rim
        out[y0:y1, x0:x1] += disc[..., None] * col * rng.uniform(0.25, alpha)
    return out


def haze(rng, w, h, scale, strength):
    n = rng.random((h // scale + 2, w // scale + 2)).astype(np.float32)
    im = Image.fromarray(n, mode="F").resize((w, h), Image.BICUBIC)
    a = np.asarray(im)
    a = blur(a, scale * 0.6)
    a = (a - a.min()) / (a.max() - a.min() + 1e-6)
    return a * strength


def crowd(rng, w, h, base, height, count):
    """A black silhouette of heads, shoulders and raised hands along the
    bottom edge. Returns a mask, 1 where the crowd is."""
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    mask = np.zeros((h, w), np.float32)
    floor = h * base
    for i in range(count):
        cx = (i + rng.uniform(-0.4, 0.4)) * w / (count - 1)
        hr = rng.uniform(0.7, 1.15) * height * h
        top = floor - hr * rng.uniform(0.85, 1.25)
        head = np.hypot(x - cx, (y - top) * 1.05) < hr * 0.42
        body = ((x - cx) ** 2 / (hr * 1.05) ** 2 + (y - (top + hr * 1.5)) ** 2 / (hr * 1.2) ** 2) < 1
        mask = np.maximum(mask, head | body)
        if rng.random() < 0.18:  # a hand in the air
            ang = rng.uniform(-0.5, 0.5)
            ax = cx + hr * rng.choice([-0.6, 0.6])
            ln = hr * rng.uniform(1.6, 2.4)
            t = np.clip(((x - ax) * math.sin(ang) + (top - y) * math.cos(ang)) / ln, 0, 1)
            px, py = ax - t * ln * math.sin(-ang), top - t * ln * math.cos(ang)
            arm = np.hypot(x - px, y - py) < hr * 0.16
            fist = np.hypot(x - (ax + ln * math.sin(ang)), y - (top - ln * math.cos(ang))) < hr * 0.24
            mask = np.maximum(mask, arm | fist)
    mask[y > floor + height * h] = 1
    return blur(mask.astype(np.float32), 1.2)


def grain(rng, a, amount=0.035):
    g = rng.normal(0, amount, a.shape[:2]).astype(np.float32)[..., None]
    return a + g


def tone(a):
    """Filmic shoulder so stacked lights glow instead of clipping flat."""
    return 1.0 - np.exp(-a * 1.35)


def save(a, name, q=86):
    os.makedirs(OUT, exist_ok=True)
    img = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))
    img.save(os.path.join(OUT, name), quality=q, optimize=True, progressive=True)
    print(name, img.size, os.path.getsize(os.path.join(OUT, name)) // 1024, "KB")


# Poster backdrops: 1200 x 720. The left 45% stays darker, because the
# titles sit there.
PW, PH = 1200, 720


def text_side_shade(a, keep=0.62):
    x, _ = grid(a.shape[1], a.shape[0])
    k = keep + (1 - keep) * np.clip((x - 0.15) / 0.6, 0, 1)
    return a * k[..., None]


def poster_live():
    rng = np.random.default_rng(11)
    a = wash(PW, PH, [MAGENTA, ORANGE], 0.5) * 0.55 + c(BLACK) * 0.45
    for x0, sp, tl, col, pw in [
        (0.18, 0.10, 0.35, AMBER, 0.9),
        (0.42, 0.08, -0.10, PINK, 1.0),
        (0.66, 0.11, -0.35, AMBER, 1.1),
        (0.86, 0.09, -0.15, ORANGE, 0.9),
        (0.55, 0.06, 0.25, MAGENTA, 0.8),
    ]:
        a += beam(PW, PH, x0, sp, tl, col, pw)
    a += haze(rng, PW, PH, 90, 0.25)[..., None] * c(PINK)
    a += blur(bokeh(rng, PW, PH, 55, [AMBER, PINK, ORANGE], 6, 26, 0.6), 2.5)
    a = tone(a)
    m = crowd(rng, PW, PH, 0.86, 0.075, 26)
    a = a * (1 - m[..., None]) + c(BLACK) * 0.4 * m[..., None]
    a = text_side_shade(a)
    save(grain(rng, a), "stage_live.jpg")


def poster_studio():
    """A dark studio: tall LED panels along the back wall, mirrored in a
    glossy floor, with cool haze."""
    rng = np.random.default_rng(23)
    a = wash(PW, PH, [VIOLET, TEAL], 0.4) * 0.35 + c(BLACK) * 0.65
    x, y = grid(PW, PH)
    horizon = 0.70
    wall = np.zeros((PH, PW, 3), np.float32)
    for i, px in enumerate(np.linspace(0.30, 0.95, 6)):
        col = c(CYAN) if i % 2 == 0 else c(VIOLET) * 1.3
        top = 0.08 + 0.04 * (i % 3)
        panel = (np.abs(x - px) * PW < 9) & (y > top) & (y < horizon)
        wall += panel[..., None] * col
    glow = blur(wall, 22) * 1.6 + blur(wall, 70) * 1.2
    a += wall * 0.9 + glow
    # The floor mirrors the wall, softer and fading toward the camera.
    floor = y >= horizon
    src_rows = np.clip((2 * horizon - y) * PH, 0, PH - 1).astype(int)
    mirror = (wall * 0.9 + glow)[src_rows[:, 0], :, :]
    fade = np.clip(1 - (y - horizon) / (1 - horizon) * 1.4, 0, 1)
    a = np.where(floor[..., None], c(BLACK) * 0.9 + blur(mirror, 6) * 0.45 * fade[..., None], a)
    a += haze(rng, PW, PH, 120, 0.2)[..., None] * c(TEAL)
    a += blur(bokeh(rng, PW, PH, 22, [CYAN, VIOLET], 4, 14, 0.6), 2)
    a = text_side_shade(tone(a))
    save(grain(rng, a), "stage_studio.jpg")


def poster_headline():
    rng = np.random.default_rng(5)
    a = wash(PW, PH, [VIOLET, MAGENTA, ORANGE], 0.55) * 0.55 + c(BLACK) * 0.45
    for x0, sp, tl, col, pw in [
        (0.10, 0.07, 0.45, VIOLET, 1.0),
        (0.30, 0.06, 0.20, PINK, 0.9),
        (0.50, 0.09, 0.0, AMBER, 1.2),
        (0.70, 0.06, -0.20, PINK, 0.9),
        (0.90, 0.07, -0.45, VIOLET, 1.0),
    ]:
        a += beam(PW, PH, x0, sp, tl, col, pw)
    a += haze(rng, PW, PH, 100, 0.28)[..., None] * c(MAGENTA)
    # A row of fixtures along the truss.
    x, y = grid(PW, PH)
    for i in range(9):
        fx = 0.06 + i * 0.11
        spot = np.exp(-(((x - fx) * PW) ** 2 + ((y - 0.02) * PH) ** 2) / 90)
        a += blur(spot, 6)[..., None] * c(AMBER) * 3
    a += blur(bokeh(rng, PW, PH, 45, [AMBER, PINK, VIOLET], 5, 22, 0.7), 2.5)
    a = tone(a)
    m = crowd(rng, PW, PH, 0.9, 0.06, 30)
    a = a * (1 - m[..., None]) + c(BLACK) * 0.4 * m[..., None]
    a = text_side_shade(a)
    save(grain(rng, a), "stage_headline.jpg")


# Sample sleeves: 600 x 600. Title type is drawn by the app on top, so the
# lower-left third stays quiet.
S = 600


def sleeve_shade(a):
    x, y = grid(S, S)
    k = 1 - 0.5 * np.clip((y - 0.45) / 0.55, 0, 1) * np.clip(1.1 - x, 0, 1)
    return a * k[..., None]


def sleeve_bokeh():
    rng = np.random.default_rng(101)
    a = wash(S, S, [VIOLET, BLACK], 0.9) * 0.6
    a += blur(bokeh(rng, S, S, 40, [PINK, AMBER, VIOLET, CYAN], 18, 60), 3)
    a += blur(bokeh(rng, S, S, 60, [AMBER, PINK], 4, 10), 1)
    save(grain(rng, sleeve_shade(tone(a))), "sleeve_city_lights.jpg")


def sleeve_road():
    rng = np.random.default_rng(102)
    x, y = grid(S, S)
    horizon = 0.5
    sky = wash(S, S, [VIOLET, MAGENTA, ORANGE], 1.5708) * (y < horizon)[..., None]
    sun = np.hypot(x - 0.5, (y - horizon) * 1.0) < 0.2
    a = sky + (sun & (y < horizon))[..., None] * c(AMBER) * 0.9
    ground = y >= horizon
    d = np.where(ground, (y - horizon) / (1 - horizon), 0)
    road = np.abs(x - 0.5) < d * 0.45
    a += (ground & ~road)[..., None] * c(BLACK) * 1.0
    a += (ground & road)[..., None] * c((0x1E, 0x1A, 0x2B))
    edge = np.exp(-((np.abs(x - 0.5) - d * 0.45) * S) ** 2 / 6) * ground
    dash = (np.abs(x - 0.5) * S < 1 + d * 5) & (np.sin(np.log(d + 0.02) * 22) > 0) & ground
    a += edge[..., None] * c(PINK) * 0.9 + dash[..., None] * c(AMBER) * 0.9
    a += blur((sun & (y < horizon)).astype(np.float32), 30)[..., None] * c(ORANGE) * 0.6
    save(grain(rng, sleeve_shade(tone(a * 1.2))), "sleeve_night_drive.jpg")


def sleeve_vinyl():
    rng = np.random.default_rng(103)
    x, y = grid(S, S)
    r = np.hypot(x - 0.62, y - 0.42)
    a = wash(S, S, [TEAL, VIOLET], 0.8) * 0.7
    disc = r < 0.42
    grooves = 0.5 + 0.5 * np.sin(r * 900 + rng.random() * 3)
    ang = np.arctan2(y - 0.42, x - 0.62)
    sheen = np.clip(np.cos(2 * ang - 1.0), 0, 1) ** 6
    vinyl = c(BLACK) * (0.8 + 0.2 * grooves[..., None]) + sheen[..., None] * c(CYAN) * 0.35
    a = np.where(disc[..., None], vinyl, a)
    label = r < 0.12
    a = np.where(label[..., None], wash(S, S, [MAGENTA, ORANGE], 0.6), a)
    a = np.where((r < 0.012)[..., None], c(BLACK), a)
    save(grain(rng, sleeve_shade(a), 0.025), "sleeve_spin_cycle.jpg")


def sleeve_beams():
    rng = np.random.default_rng(104)
    a = c(BLACK) + np.zeros((S, S, 3), np.float32)
    for x0, sp, tl, col in [(0.2, 0.05, 0.5, MAGENTA), (0.5, 0.05, 0.0, AMBER), (0.8, 0.05, -0.5, VIOLET)]:
        a += beam(S, S, x0, sp, tl, col, 1.4)
    a += haze(rng, S, S, 60, 0.3)[..., None] * c(MAGENTA)
    a = tone(a)
    m = crowd(rng, S, S, 0.9, 0.08, 12)
    a = a * (1 - m[..., None]) + c(BLACK) * 0.3 * m[..., None]
    save(grain(rng, sleeve_shade(a)), "sleeve_front_row.jpg")


def sleeve_waves():
    rng = np.random.default_rng(105)
    x, y = grid(S, S)
    a = c(BLACK) * 0.9 + np.zeros((S, S, 3), np.float32)
    for i in range(14):
        yy = 0.18 + i * 0.05
        amp = 0.05 * math.sin(i * 0.7) + 0.06
        wave = yy + amp * np.sin(x * 9 + i * 0.6) * np.exp(-((x - 0.6) ** 2) * 4)
        line = np.exp(-((y - wave) * S) ** 2 / 5)
        col = c(CYAN) * (1 - i / 14) + c(PINK) * (i / 14)
        a += line[..., None] * col * 1.1
        a += blur(line, 8)[..., None] * col * 0.5
    save(grain(rng, sleeve_shade(tone(a))), "sleeve_frequency.jpg")


def sleeve_peaks():
    rng = np.random.default_rng(106)
    x, y = grid(S, S)
    a = wash(S, S, [ORANGE, MAGENTA, VIOLET], 1.5708)
    a += blur((np.hypot(x - 0.3, y - 0.3) < 0.09).astype(np.float32), 4)[..., None] * c(AMBER)
    for k, (shade, h0, f) in enumerate([(0.55, 0.55, 5), (0.35, 0.65, 8), (0.12, 0.78, 13)]):
        ridge = h0 + 0.07 * np.sin(x * f + k * 2) + 0.04 * np.sin(x * f * 2.7 + k)
        ridge += 0.03 * haze(rng, S, 1, 20, 1)[0]
        a = np.where((y > ridge)[..., None], a * shade + c(BLACK) * (1 - shade), a)
    save(grain(rng, sleeve_shade(a)), "sleeve_high_country.jpg")


if __name__ == "__main__":
    poster_live()
    poster_studio()
    poster_headline()
    sleeve_bokeh()
    sleeve_road()
    sleeve_vinyl()
    sleeve_beams()
    sleeve_waves()
    sleeve_peaks()

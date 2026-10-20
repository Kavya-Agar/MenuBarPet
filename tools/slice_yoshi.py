"""Slice a Yoshi sprite sheet (pink background, sprites facing right) into the skin's PNG frames.
Every frame is scaled by the same factor and bottom-aligned on one shared canvas so nothing jumps.
Sprite numbers are component order on the sheet (rows top to bottom, left to right).
Usage: slice_yoshi.py <yoshi.png> <out dir>   (e.g. yoshi.png Resources/sprites)
Needs: pillow numpy scipy
"""
import os, sys
import numpy as np
from PIL import Image
from scipy import ndimage

SRC, OUT = sys.argv[1], os.path.join(sys.argv[2], "yoshi")
BG = (255, 174, 201)
SCALE = 0.55
CANVAS_W, CANVAS_H = 34, 23
ANCHOR_X = 11  # canvas column the body's horizontal center lands on

FRAMES = {
    "idle": [25, 26, 27, 28],
    "walk": [20, 21, 22],
    "walk_fast": [111, 112, 113],
    "run": [113, 114, 115, 116, 117, 118],
    "lie": [121, 122, 123],
}
MOUTH_OPEN, TONGUE_SPRITE = 133, 134
# eating: open mouth, tongue flicks out and back, then a swallow (standing frames)
INHALE = [(MOUTH_OPEN, 0), (TONGUE_SPRITE, 4), (TONGUE_SPRITE, 12), (TONGUE_SPRITE, 12),
          (TONGUE_SPRITE, 4), (MOUTH_OPEN, 0), (25, 0), (26, 0)]

sheet = Image.open(SRC).convert("RGBA")
a = np.array(sheet)
bg = (a[..., 0] == BG[0]) & (a[..., 1] == BG[1]) & (a[..., 2] == BG[2])
a[bg, 3] = 0
sheet = Image.fromarray(a)

fg = ~bg
fg[:, 460:] = False          # skip the Expressions panel
fg[690:760, 420:] = False    # skip the credits banner
lab, _ = ndimage.label(ndimage.binary_dilation(fg, iterations=1), structure=np.ones((3, 3)))
boxes = []
for ys, xs in ndimage.find_objects(lab):
    h, w = ys.stop - ys.start, xs.stop - xs.start
    if h * w >= 80 and w >= 8 and h >= 8:
        boxes.append((ys.start, xs.start, ys.stop, xs.stop))
boxes.sort(key=lambda b: (b[0] // 14, b[1]))


def crop(k):
    y0, x0, y1, x1 = boxes[k]
    return sheet.crop((x0, y0, x1, y1))


def with_tongue(n):
    """Sprite 134 carries a very long tongue; keep the head and `n` columns of it plus the tip."""
    sp = crop(TONGUE_SPRITE)
    alpha = np.array(sp)[..., 3] > 0
    counts = alpha.sum(axis=0)
    w = sp.width
    tip = w - 10                                  # the ball on the end of the tongue
    line = int(np.median(counts[w - 30:w - 14]))
    body_end = w - 14
    while counts[body_end] <= line + 1:
        body_end -= 1
    body_end += 1
    parts = [sp.crop((0, 0, body_end, sp.height))]
    mid = sp.crop((body_end + 2, 0, body_end + 3, sp.height))
    for _ in range(n):
        parts.append(mid)
    parts.append(sp.crop((tip, 0, w, sp.height)))
    out = Image.new("RGBA", (sum(p.width for p in parts), sp.height), (0, 0, 0, 0))
    x = 0
    for p in parts:
        out.paste(p, (x, 0)); x += p.width
    return out, body_end


def to_canvas(sp, body_w=None):
    """Scale, hard-edge the alpha, and bottom-align with the body's center on ANCHOR_X."""
    w, h = max(1, round(sp.width * SCALE)), max(1, round(sp.height * SCALE))
    small = sp.convert("RGBa").resize((w, h), Image.LANCZOS).convert("RGBA")
    arr = np.array(small)
    arr[..., 3] = np.where(arr[..., 3] >= 110, 255, 0)
    small = Image.fromarray(arr)
    c = Image.new("RGBA", (CANVAS_W, CANVAS_H), (0, 0, 0, 0))
    bw = (body_w if body_w else sp.width) * SCALE
    c.alpha_composite(small, (round(ANCHOR_X - bw / 2), CANVAS_H - h))
    return c


os.makedirs(OUT, exist_ok=True)
for f in os.listdir(OUT):
    if f.endswith(".png"):
        os.remove(os.path.join(OUT, f))
for name, ids in FRAMES.items():
    for i, k in enumerate(ids):
        to_canvas(crop(k)).save(os.path.join(OUT, f"{name}_{i}.png"))
for i, (k, n) in enumerate(INHALE):
    if k == TONGUE_SPRITE:
        sp, body_end = with_tongue(n)
        img = to_canvas(sp, body_w=body_end)
    else:
        img = to_canvas(crop(k))
    img.save(os.path.join(OUT, f"inhale_{i}.png"))

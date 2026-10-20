"""Slice a Minecraft wolf sprite sheet (blue background, 8 columns, labelled rows) into the tamed wolf's frames
in Resources/sprites/wolf.
Every frame is scaled by the same factor and bottom-aligned on one shared canvas so nothing jumps.
Usage: slice_wolf.py <sheet.jpeg> <out dir>   (e.g. sheet.jpeg Resources/sprites)
Needs: pillow numpy scipy
"""
import os, sys
import numpy as np
from PIL import Image
from scipy import ndimage

SRC, ROOT = sys.argv[1], sys.argv[2]
SCALE = 0.25
CANVAS_W, CANVAS_H = 34, 20
CELL_W = 176
# Row bands (y0, y1) on the 1408x768 sheet.
ROWS = {"idle": (63, 134), "walk": (158, 224), "trot": (227, 290), "tamed": (407, 492),
        "run": (514, 586), "down": (607, 677)}
# (row, column) of each frame; every one faces right.
FRAMES = {
    "idle": [("idle", 0), ("idle", 1), ("idle", 2), ("idle", 4)],
    "walk": [("walk", 0), ("walk", 1), ("walk", 2)],
    "walk_fast": [("trot", 0), ("trot", 1), ("trot", 2)],
    "run": [("run", 0), ("run", 1), ("run", 2), ("run", 3), ("run", 4), ("run", 5)],
    "lie": [("down", 7), ("down", 4), ("down", 7)],
}
TAMED_IDLE = [("tamed", 0), ("tamed", 1), ("tamed", 2), ("tamed", 3)]
RED = (160, 32, 32)   # the tamed wolf's collar

sheet = np.array(Image.open(SRC).convert("RGB")).astype(int)


def cell(row, col):
    """The wolf in one grid cell, background (blue) and the corner label removed."""
    y0, y1 = ROWS[row]
    px = sheet[y0:y1, col * CELL_W:(col + 1) * CELL_W]
    mask = (px[..., 2] - px[..., 0]) < 30            # wolf pixels are grey/white/black/red, never blue
    mask[:16, :30] = False                            # the N1/E2 label
    mask = ndimage.binary_opening(mask, iterations=1)
    lab, n = ndimage.label(mask)
    k = int(np.argmax(ndimage.sum(mask, lab, range(1, n + 1)))) + 1
    mask = ndimage.binary_erosion(lab == k, iterations=1)   # drop the JPEG blue halo
    ys, xs = np.where(mask)
    box = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
    rgba = np.dstack([px.astype(np.uint8), (mask * 255).astype(np.uint8)])
    return Image.fromarray(rgba).crop(box)


def paint_collar(sp, color, frac=0.655, height=0.42):
    """Paint a collar on the neck of a walking/running wolf (standing ones already have it in the sheet)."""
    a = np.array(sp)
    w, h = sp.size
    x = int(w * frac)
    col = a[:, x, 3] > 0
    if not col.any():
        return sp
    top = int(np.argmax(col))
    y1 = top + int(h * height)
    for y in range(top + 2, min(y1, h)):
        for xx in range(x - 4, x + 4):
            if a[y, xx, 3] > 0:
                a[y, xx, :3] = color
    return Image.fromarray(a)


def to_canvas(sp, scale):
    w, h = max(1, round(sp.width * scale)), max(1, round(sp.height * scale))
    small = sp.convert("RGBa").resize((w, h), Image.LANCZOS).convert("RGBA")
    arr = np.array(small)
    arr[..., 3] = np.where(arr[..., 3] >= 110, 255, 0)
    small = Image.fromarray(arr)
    c = Image.new("RGBA", (CANVAS_W, CANVAS_H), (0, 0, 0, 0))
    c.alpha_composite(small, ((CANVAS_W - w) // 2, CANVAS_H - h))
    return c


def write(folder, make, tamed_idle=False):
    out = os.path.join(ROOT, folder)
    os.makedirs(out, exist_ok=True)
    for f in os.listdir(out):
        if f.endswith(".png"):
            os.remove(os.path.join(out, f))
    for anim, ids in FRAMES.items():
        for i, (row, col) in enumerate(ids):
            if tamed_idle and anim == "idle":
                row, col = TAMED_IDLE[i]
            to_canvas(make(cell(row, col), anim, row == "tamed"), SCALE).save(os.path.join(out, f"{anim}_{i}.png"))


def collared(sp, anim, already):
    """The sheet's tamed row already has the collar; walking, running and lying frames get one painted on."""
    if already:
        return sp
    if anim == "lie":
        return paint_collar(sp, RED, frac=0.74, height=0.55)
    return paint_collar(sp, RED, frac=0.655 if anim != "idle" else 0.62, height=0.42 if anim != "idle" else 0.5)


write("wolf", collared, tamed_idle=True)

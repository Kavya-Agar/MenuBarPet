"""Convert vscode-pets dog GIFs into small PNG frames (1 px per art pixel), one folder per skin.
'blue' is the white dog recolored. Sprites: https://github.com/tonybaloney/vscode-pets (CC BY-ND 4.0).
Usage: make_sprites.py <vscode-pets/media/dog> <out dir>
"""
import sys, os
from PIL import Image

SRC, OUT = sys.argv[1], sys.argv[2]
SCALE = 5
ANIMS = ["idle", "walk", "walk_fast", "run", "lie"]
SKINS = {"blue": "white", "black": "black", "akita": "akita"}
RAMP = [(150, 200, 255), (96, 160, 240), (66, 124, 210), (44, 90, 170)]

def recolor(px):
    r, g, b, a = px
    if a == 0:
        return px
    lum = (r + g + b) / 3
    if max(r, g, b) - min(r, g, b) < 30 and lum > 100:
        t = max(0.0, min(1.0, (lum - 100) / 150.0))
        lo, hi = RAMP[3], RAMP[1]
        return tuple(int(lo[i] + (hi[i] - lo[i]) * t) for i in range(3)) + (255,)
    return px

for skin, src in SKINS.items():
    d = os.path.join(OUT, skin)
    os.makedirs(d, exist_ok=True)
    for anim in ANIMS:
        im = Image.open(os.path.join(SRC, f"{src}_{anim}_8fps.gif"))
        for i in range(im.n_frames):
            im.seek(i)
            fr = im.convert("RGBA")
            w, h = fr.size
            small = Image.new("RGBA", (w // SCALE, h // SCALE))
            for y in range(h // SCALE):
                for x in range(w // SCALE):
                    px = fr.getpixel((x * SCALE + 2, y * SCALE + 2))
                    small.putpixel((x, y), recolor(px) if skin == "blue" else px)
            small.save(os.path.join(d, f"{anim}_{i}.png"))

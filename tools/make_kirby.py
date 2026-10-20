"""Draw original Kirby-style pixel sprites (1 px per art pixel, facing right) into Resources/sprites/kirby.
Frame counts match the dog skins so the animation timing in Dog.swift is unchanged.
Usage: make_kirby.py <out dir>   (e.g. Resources/sprites)
"""
import os, sys
from PIL import Image

OUT = os.path.join(sys.argv[1], "kirby")
OUTLINE = (104, 40, 72, 255)
PINK = (255, 177, 206, 255)
SHADE = (240, 138, 180, 255)
FOOT = (226, 52, 84, 255)
FOOT_SHADE = (184, 30, 66, 255)
BLUSH = (255, 106, 150, 255)
EYE = (40, 22, 56, 255)
SHINE = (255, 255, 255, 255)
IRIS = (70, 110, 230, 255)
MOUTH = (200, 30, 60, 255)


class Canvas:
    def __init__(self, w, h):
        self.im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.w, self.h = w, h

    def px(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.im.putpixel((x, y), c)

    def blob(self, cx, cy, rx, ry, fill, outline=OUTLINE, shade=None):
        """Filled ellipse with a 1 px outline; `shade` tints the lower-left rim."""
        for y in range(self.h):
            for x in range(self.w):
                dx, dy = (x + 0.5 - cx), (y + 0.5 - cy)
                if (dx / rx) ** 2 + (dy / ry) ** 2 > 1:
                    continue
                inner = (dx / (rx - 1)) ** 2 + (dy / (ry - 1)) ** 2 <= 1 if rx > 1 and ry > 1 else False
                if not inner:
                    self.px(x, y, outline)
                elif shade and (((dx - 2.0) / (rx - 1)) ** 2 + ((dy + 2.0) / (ry - 1)) ** 2 > 1):
                    self.px(x, y, shade)
                else:
                    self.px(x, y, fill)

    def save(self, name):
        self.im.save(os.path.join(OUT, name))


def eye(c, x, y, blink):
    if blink:
        c.px(x, y + 2, EYE); c.px(x + 1, y + 2, EYE)
        return
    for dy in range(4):
        c.px(x, y + dy, EYE); c.px(x + 1, y + dy, EYE)
    c.px(x, y, SHINE) if False else None
    c.px(x + 1, y, SHINE)
    c.px(x, y + 3, IRIS); c.px(x + 1, y + 3, IRIS)


def kirby(w, h, base, rx, ry, lean=0, back_foot=(0, 0), front_foot=(0, 0), back_arm=(0, 0),
          front_arm=(0, 0), blink=False, mouth=False, bob=0):
    """base = ground row (feet bottom); body sits on top of the feet."""
    c = Canvas(w, h)
    cx = w / 2 - 0.5 + lean
    cy = base - 2 - ry - bob
    # back foot and back arm (behind the body)
    c.blob(cx - 4.5 + back_foot[0], base - 1.6 + back_foot[1], 3.6, 2.3, FOOT, shade=FOOT_SHADE)
    c.blob(cx - rx + 1.2 + back_arm[0], cy + 1 + back_arm[1], 2.2, 2.6, SHADE)
    # body
    c.blob(cx, cy, rx, ry, PINK, shade=SHADE)
    # face (right-leaning)
    fx = int(round(cx + rx * 0.1))
    fy = int(round(cy - ry * 0.45))
    eye(c, fx - 1, fy, blink)
    eye(c, fx + 3, fy, blink)
    c.px(fx - 3, fy + 4, BLUSH); c.px(fx - 2, fy + 4, BLUSH)
    c.px(fx + 5, fy + 4, BLUSH)
    if mouth:
        # mouth 1 = small open, 2-3 = wide open (inhaling) with a tongue on the bottom rows
        size = mouth + 1
        for dx in range(size):
            for dy in range(size):
                tongue = mouth >= 3 and dy >= size - 2 and 0 < dx < size - 1
                c.px(fx + 1 + dx - (size - 2) // 2, fy + 5 + dy, FOOT if tongue else MOUTH)
    else:
        c.px(fx + 1, fy + 5, MOUTH); c.px(fx + 2, fy + 5, MOUTH)
    # front arm and front foot
    c.blob(cx + rx - 1.5 + front_arm[0], cy + 3.5 + front_arm[1], 2.2, 2.6, PINK, shade=SHADE)
    c.blob(cx + 4.5 + front_foot[0], base - 1.6 + front_foot[1], 3.6, 2.3, FOOT, shade=FOOT_SHADE)
    return c


def lying(w, h, ry, blink=True):
    c = Canvas(w, h)
    cx, base = w / 2 - 0.5, h
    cy = base - 2 - ry
    c.blob(cx - 6, base - 1.6, 3.4, 2.2, FOOT, shade=FOOT_SHADE)
    c.blob(cx + 6, base - 1.6, 3.4, 2.2, FOOT, shade=FOOT_SHADE)
    c.blob(cx, cy, 9.5, ry, PINK, shade=SHADE)
    fx, fy = int(cx + 2), int(cy - ry * 0.3)
    for ex in (fx - 1, fx + 3):
        c.px(ex, fy + 1, EYE); c.px(ex + 1, fy + 1, EYE)
    c.px(fx - 3, fy + 3, BLUSH); c.px(fx - 2, fy + 3, BLUSH)
    c.px(fx + 5, fy + 3, BLUSH)
    c.px(fx + 1, fy + 4, MOUTH); c.px(fx + 2, fy + 4, MOUTH)
    c.blob(cx - 8.5, cy + 2, 2.4, 2.2, SHADE)
    return c


os.makedirs(OUT, exist_ok=True)
W, H = 20, 19
BASE = H

# idle: gentle breathing, one blink
for i, (rx, ry, blink) in enumerate([(7.5, 7.5, False), (7.8, 7.2, False), (8.0, 6.9, False), (7.8, 7.2, True)]):
    kirby(W, H, BASE, rx, ry, blink=blink).save(f"idle_{i}.png")

# walk: feet swap, small bob
walk = [
    dict(front_foot=(1, 0), back_foot=(-1, 0), front_arm=(0, 0), back_arm=(0, 0), bob=0),
    dict(front_foot=(-1, -1), back_foot=(1, 0), front_arm=(1, -1), back_arm=(-1, 0), bob=1),
    dict(front_foot=(2, 0), back_foot=(-2, -1), front_arm=(-1, 0), back_arm=(1, -1), bob=1),
]
for i, kw in enumerate(walk):
    kirby(W, H, BASE, 7.5, 7.4, **kw).save(f"walk_{i}.png")

walk_fast = [
    dict(front_foot=(2, 0), back_foot=(-2, -1), front_arm=(1, -1), back_arm=(-1, 1), bob=0, lean=0.5),
    dict(front_foot=(-1, -1), back_foot=(1, 0), front_arm=(0, 1), back_arm=(1, -1), bob=2, lean=0.5),
    dict(front_foot=(1, -1), back_foot=(-2, 0), front_arm=(1, 0), back_arm=(-1, 0), bob=1, lean=0.5),
]
for i, kw in enumerate(walk_fast):
    kirby(W, H, BASE, 7.5, 7.4, **kw).save(f"walk_fast_{i}.png")

# run: stretched, leaning forward, arms thrown back, feet kicking
run = [
    dict(front_foot=(3, -2), back_foot=(-3, 0), bob=0),
    dict(front_foot=(1, -1), back_foot=(-1, -1), bob=2),
    dict(front_foot=(-2, 0), back_foot=(3, -2), bob=1),
    dict(front_foot=(-3, 0), back_foot=(3, -1), bob=0),
    dict(front_foot=(-1, -1), back_foot=(1, -1), bob=2),
    dict(front_foot=(2, -2), back_foot=(-3, 0), bob=1),
]
for i, kw in enumerate(run):
    kirby(22, H, BASE, 7.8, 7.0, lean=1.5, front_arm=(-9, -3), back_arm=(-2, -1), mouth=True, **kw).save(f"run_{i}.png")

# lie: squashed, eyes closed, breathing
for i, ry in enumerate([5.0, 5.5, 6.0]):
    lying(22, 13, ry).save(f"lie_{i}.png")

# inhale (feeding): arms up, mouth opens wide, cheeks puff, gulp, happy hop. Played once, not looped.
inhale = [
    dict(mouth=1, front_arm=(1, -3), back_arm=(-1, -2)),
    dict(mouth=2, front_arm=(2, -5), back_arm=(-1, -4), lean=0.5),
    dict(mouth=3, front_arm=(2, -6), back_arm=(-1, -5), lean=1, rx=7.9, ry=7.1),
    dict(mouth=3, front_arm=(2, -6), back_arm=(-1, -5), lean=1, rx=7.9, ry=7.1, front_foot=(1, 0), back_foot=(-1, 0)),
    dict(mouth=3, front_arm=(2, -5), back_arm=(-1, -4), lean=1.5, rx=7.7, ry=7.3, front_foot=(1, 0), back_foot=(-1, 0)),
    dict(rx=8.4, ry=7.2),
    dict(rx=7.8, ry=7.6),
    dict(blink=True, bob=2, front_arm=(2, -5), back_arm=(-1, -4)),
]
for i, kw in enumerate(inhale):
    kw = dict(kw)
    rx, ry = kw.pop("rx", 7.5), kw.pop("ry", 7.4)
    kirby(W, H, BASE, rx, ry, **kw).save(f"inhale_{i}.png")

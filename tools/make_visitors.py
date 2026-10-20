"""Hand-drawn pixel-art visitors and props (1 px per art pixel, facing right) into Resources/sprites/visitors
and Resources/sprites/props. Each is ASCII art; frame _1 is derived from _0 (feet shuffle, or a drawn variant).
Usage: make_visitors.py <out dir>   (e.g. Resources/sprites)
"""
import os, sys
from PIL import Image

ROOT = sys.argv[1]
PAL = {
    "k": (36, 28, 44), "w": (250, 250, 250), "g": (204, 204, 212), "G": (132, 132, 148), "d": (64, 64, 76),
    "r": (226, 50, 50), "R": (160, 28, 40), "o": (246, 150, 40), "O": (200, 100, 26), "y": (252, 216, 64),
    "Y": (212, 160, 30), "b": (156, 100, 58), "B": (104, 62, 36), "n": (228, 186, 132), "p": (255, 172, 202),
    "P": (230, 112, 162), "l": (150, 204, 255), "u": (60, 110, 222), "c": (80, 210, 230), "e": (112, 202, 72),
    "E": (60, 140, 52), "L": (196, 236, 70), "m": (142, 92, 200), "s": (250, 210, 172),
}

# name: (frame 0, frame 1 or None -> shuffle feet)
ART = {
    "butterfly": ("""
.oo...oo.
ooyo.oyoo
oyyokoyyo
.oyokoyo.
..ookoo..
...k.k...""", """
....o....
...okO...
...okO...
...okO...
...okO...
....k...."""),

    "squirrel": ("""
..bb.......
.bBBb..bb..
bBBb..bbbk.
bBb.bbbbwk.
.bBbbbbbbbk
..bbwwbbbk.
..bbwwbb...
...kb.kb...""", None),

    "cat": ("""
.............k.k
k...........kGkGk
kk..........kGGGGk
.kGGGGGGGGGkGwGwGk
..kGGGGGGGGGGGGGk.
..kGGdGGGGdGGGGk..
...kGkkGGkGkkk....
...kk.kk.kk.kk....""", None),

    "ball": ("""
..LLL..
.LLLLL.
LLwwwLL
LLwLLLL
LLLwwLL
.LLLLL.
..LLL..""", None),

    "mailman": ("""
..uuu.....
.uuuuu....
.sskss....
..sss.....
.uuuuuuu..
uuuuuuuuu.
usuuuuubb.
.uuuuuubb.
..uu.uu...
..kk.kk...""", None),

    "rabbit": ("""
.......wp
.......wp
......kww
..wwwwwwk
.wwwwwwwk
wwwwwwwww
wwwwwwww.
.ww.ww...""", None),

    "koi": ("""
.....oooo...
..ooooooowo.
.oowooooooko
ooOooooooow.
.oOOoooooo..
..oo.oooo...""", """
.....oooo...
..ooooooowo.
oooooooooowk
.oOooooooow.
..oOOoooo...
...o..ooo..."""),

    "crane": ("""
......rk..
.....wwww.
....wwwwwk
.wwwwww...
wwwwwwwwk.
.wwwwww...
..kk.kk...
..k..k....""", None),

    "waddledee": ("""
..bbbbbb..
.bbbbbbbb.
bbbbbbbbbb
bbnnnnnnbb
bnnkwnkwnb
.nnnnnnnn.
.rrrrrrrr.
..rr..rr..""", None),

    "waddledoo": ("""
..oooooo..
.oooooooo.
ooyyyyyyoo
ooyywkwkyo
.oyyyyyyyo.
.oooooooo..
.ooo..ooo.
.kk....kk.""", None),

    "gordo": ("""
...k.k.k...
..kdkdkdk..
.kdGdGdGdk.
kdGwwdwwGdk
kkdGkdkGdkk
kdGdGdGdGdk
.kdGdGdGdk.
..kdkdkdk..
...k.k.k...""", None),

    "warpstar": ("""
....y....
....y....
yyyyyyyyy
.yyyyyyy.
..yoyoy..
.yyyyyyy.
.yy...yy.
yy.....yy""", None),

    "tomato": ("""
...ee...
..eEe...
.rrrrrr.
rrwwrrrr
rwwrrrrR
rrrrrrrR
.rrrrrR.
..RRRR..""", None),

    "scarfy": ("""
.........
..yyyyy..
.yyyyyyy.
yyykyykyy
yyyyyyyyy
.yyyoyyy.
..yyyyy..
..o...o..""", None),

    "bronto": ("""
.rr....rr.
rrrr..rrrr
rrrrrrrrrr
.rrrkrkrr.
..rrrrrr..
...rrrr...
...oo.oo..""", None),

    "apple": ("""
...e.e.
...ee..
..rrrrr
.rrwrrrr
.rwrrrrR
.rrrrrrR
..rrrRR
...RR..""", None),

    "koopa": ("""
..eeee....
.eeeeee.k.
eEeEeEe.kk
eeeeeeeekyk
eEeEeEe.kk
.eeeeeee.k
..ww.ww...
.oo..oo...""", None),

    "goomba": ("""
..bbbbbb..
.bbbbbbbb.
bbwkbbkwbb
bbbkbbkbbb
.bbbbbbbb.
..nnnnnn..
.nnnnnnnn.
.kk....kk.""", None),

    "shyguy": ("""
..rrrrrr..
.rrrrrrrr.
rrwwwwwwrr
rwkkwwkkwr
rwkkwwkkwr
rrwwwwwwrr
.rrrrrrrr.
.rr.rr.rr.
.kk....kk.""", None),

    "bullet": ("""
.kkkkk...
kkkkkkkk.
kdkwwkkkk
kdkwkwkkk
kkkkkkkkk
kkkkkkkk.
.kkkkk...""", """
.kkkkk...
kkkkkkkk.
kdkwwkkkk
kdkwkwkkk
kkkkkkkkk
.kkkkkk..
..kkkk...""" ),

    "boo": ("""
..wwwwww..
.wwwwwwww.
wwkkwwkkww
wwkkwwkkww
wwwwwwwwww
wwwrrrrwww
wwwrrrrwww
.wwwwwwww.
..ww..ww..""", None),

    "coin": ("""
.yyyy.
yyYYyy
yYyyYy
yYyyYy
yyYYyy
.yyyy.""", """
..yy..
..yY..
..yY..
..yY..
..yY..
..yy.."""),

    "star": ("""
....y....
....y....
yyyyyyyyy
.yykyykyy
..yyyyyy.
..yyyyyy.
.yyy..yyy
.yy....yy""", None),

    "egg": ("""
..wwww..
.wwewww.
wwwewwww
wewwwewe
wwwwwwww
weewwwew
.wwwwww.
..wwww..""", """
.e....e.
.eeeeee.
.wkeeke.
.eeeeee.
wwwewwww
weewwwew
.wwwwww.
..wwww.."""),
    "bone": ("""
ww.....ww
wwwwwwwww
wwwwwwwww
ww.....ww""", None),

    "melon": ("""
..eeee..
.eEeEee.
eEeEeEee
eEeEeEee
.eEeEee.
..eeee..""", None),
}

# Props are drawn on the pet (head/neck anchored), not walking around.
PROPS = {
    "sleepcap": ("""
...ww...
..uuuu..
.uuuuuu.
uuuuuuuu
wwwwwwww""", None),

    "umbrella": ("""
.....r.....
..rrrwrrr..
.rrrwwwrrr.
rrwrrrrrwrr""", None),

    "scarf": ("""
rrwrrwrr.
rrwrrwrrr
....rwrr.
....rwr..
.....r...""", None),

    "sweat": ("""
.l
ll
ll""", None),

    "fan": ("""
..oo...
.oooo..
oooooo.
.oooo..
..bb...
..b....""", """
.......
ooooooo
oooooo.
..bb...
..b....
......."""),

    "bolt": ("""
..yy
.yy.
yyyy
..yy
.yy.
.y..""", None),
}

# Frames where the second frame is not drawn: shuffle the bottom two rows one pixel right.
SHUFFLE = {"squirrel", "cat", "mailman", "rabbit", "crane", "waddledee", "waddledoo", "scarfy", "bronto",
           "koopa", "goomba", "shyguy", "boo", "star"}
# One frame is enough for these (bob/spin handled in code).
SINGLE = {"ball", "warpstar", "tomato", "gordo", "apple", "bone", "melon",
          "sleepcap", "umbrella", "scarf", "sweat", "bolt"}


def parse(art):
    rows = art.strip("\n").split("\n")
    w = max(len(r) for r in rows)
    return [r.ljust(w, ".") for r in rows]


def render(rows):
    """Draw the art with a 1 px dark outline all round, so white sprites show on a light menu bar."""
    w, h = len(rows[0]), len(rows)
    im = Image.new("RGBA", (w + 2, h + 2), (0, 0, 0, 0))
    solid = {(x, y) for y, row in enumerate(rows) for x, ch in enumerate(row) if ch != "."}
    for x, y in solid:
        im.putpixel((x + 1, y + 1), PAL[rows[y][x]] + (255,))
    for x, y in solid:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if (nx, ny) not in solid:
                im.putpixel((nx + 1, ny + 1), PAL["k"] + (255,))
    return im


def shuffled(rows):
    w = len(rows[0]) + 1
    out = [r.ljust(w, ".") for r in rows[:-2]]
    for r in rows[-2:]:
        out.append("." + r)
    return out


def emit(art, name_dir):
    out = os.path.join(ROOT, name_dir)
    os.makedirs(out, exist_ok=True)
    for f in os.listdir(out):
        if f.endswith(".png"):
            os.remove(os.path.join(out, f))
    for name, (a, b) in art.items():
        f0 = parse(a)
        if b is not None:
            f1 = parse(b)
        elif name in SINGLE:
            f1 = f0
        else:
            f1 = shuffled(f0)
        w = max(len(f0[0]), len(f1[0]))
        h = max(len(f0), len(f1))
        for i, fr in enumerate((f0, f1)):
            pad = [r.ljust(w, ".") for r in fr]
            pad = ["." * w] * (h - len(pad)) + pad   # bottom-align
            render(pad).save(os.path.join(out, f"{name}_{i}.png"))


emit(ART, "visitors")
emit(PROPS, "props")

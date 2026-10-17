"""Menu portraits (assets/ui/<name>.png, 256x256 transparent) from the hero-shot renders (render_showcase.py) in evidence/fighters/.

Run after render_showcase.py:  python3 source_art/blender/make_portraits.py
Each hero shot is scaled to fill its card, centred, with the feet on the baseline.
"""
import os
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SRC = os.path.join(ROOT, 'evidence', 'fighters')
OUT = os.path.join(ROOT, 'assets', 'ui')
NAMES = ['magnus', 'albert', 'theo', 'iris', 'seren', 'nadia']
SIZE, PAD = 256, 4

shots = {n: Image.open(os.path.join(SRC, n + '_showcase.png')).convert('RGBA') for n in NAMES}
boxes = {n: im.split()[-1].point(lambda a: 255 if a > 8 else 0).getbbox() for n, im in shots.items()}
BODY_FIT = set()  # heroes framed on the body alone, a long blade running off the card edge (none now)


def body_box(im):
    """Bounding box of the armour only. A blade is a thin stroke, so keep the columns and rows with real mass
    (at least 25% of the fullest one) and ignore the thin blade."""
    a = im.split()[-1].point(lambda v: 1 if v > 128 else 0)
    w, h = a.size
    px = a.load()
    cols = [sum(px[x, y] for y in range(h)) for x in range(w)]
    keep = [x for x in range(w) if cols[x] >= .25 * max(cols)]
    l, r = min(keep), max(keep)
    rows = [sum(px[x, y] for x in range(l, r + 1)) for y in range(h)]
    keep = [y for y in range(h) if rows[y] >= .12 * max(rows)]
    return l, min(keep), r, max(keep)


for n, im in shots.items():
    l, t, r, b = boxes[n]
    out = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    if n in BODY_FIT:
        bl, bt, br, bb = body_box(im)
        scale = (SIZE - 2 * PAD) / max(br - bl, bb - bt)
        fig = im.resize((round(im.width * scale), round(im.height * scale)), Image.LANCZOS)
        x0 = SIZE / 2 - (bl + br) / 2 * scale
        # slide sideways (no rescale) so the blade stays on the card too, as far as the body allows
        x0 = min(max(x0, PAD - l * scale), SIZE - PAD - r * scale) if (r - l) * scale <= SIZE - 2 * PAD else x0
        out.alpha_composite(fig, (round(x0), round(SIZE - PAD - bb * scale)))  # feet on the baseline (a low blade may not push them up)
    else:
        scale = (SIZE - 2 * PAD) / max(r - l, b - t)  # each hero shot fills its card
        fig = im.crop((l, t, r, b))
        fig = fig.resize((max(1, round(fig.width * scale)), max(1, round(fig.height * scale))), Image.LANCZOS)
        out.alpha_composite(fig, ((SIZE - fig.width) // 2, SIZE - PAD - fig.height))
    out.save(os.path.join(OUT, n + '.png'))
    print('PORTRAIT', n, fig.size)

"""Turn the owner-supplied icon artwork into shippable launcher assets.

    python tools/build_icon_from_art.py
    dart run flutter_launcher_icons

WHY THIS EXISTS
The source (images/Tick App Icon.png) is a 1254px render with a rounded-
square teal card on a transparent canvas. That is not a launcher icon:

* iOS needs a full-bleed square with NO alpha. The rounded corners have to
  be filled out or they render black, and iOS applies its own squircle
  anyway - baking a second one in gives you a double-rounded edge.
* Android's adaptive foreground must be transparent art on its own, with
  the flat colour supplied by the background layer. Handing it the whole
  card would put a teal square inside a teal circle, and the card's ground
  is not perfectly uniform (sampled R 1-32, G 65-90, B 64-90), so that
  seam would be visible.

So the ground is keyed out for the foreground layer. Keying globally is
safe here even though the book's pages are also teal: the background layer
restores exactly the same teal behind them, so the pages look untouched.
"""
import math
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "images", "Tick App Icon.png")
OUT_FULL = os.path.join(ROOT, "assets", "icon.png")
OUT_FG = os.path.join(ROOT, "assets", "icon_foreground.png")

GROUND = (15, 79, 83)          # sampled card teal -> #0F4F53
SIZE = 1024

# flutter_launcher_icons wraps the foreground in android:inset="16%",
# leaving the art at 68% of the layer. Android guarantees only the central
# 66/108 of the layer (r=312 of 512), so the art's furthest corner must
# land at or inside that after the inset.
INSET_KEEP = 0.68
SAFE_R = 312.0


def is_ground(p):
    """Card ground or empty canvas. Cream (G~241), gold (G~185) and the
    bird's dark eyes (G~20) all fall outside this window."""
    r, g, b, a = p
    if a < 16:
        return True
    return r < 75 and 40 < g < 125 and 40 < b < 125


def art_only(im):
    """Ground keyed to transparent; artwork kept."""
    out = im.copy()
    px = out.load()
    w, h = out.size
    for y in range(h):
        for x in range(w):
            if is_ground(px[x, y]):
                px[x, y] = (0, 0, 0, 0)
    return out


def bbox_and_radius(im):
    b = im.split()[3].getbbox()
    w, h = im.size
    cx, cy = w / 2, h / 2
    r = max(math.hypot(x - cx, y - cy) for x in (b[0], b[2]) for y in (b[1], b[3]))
    return b, r


def true_radius(im, step=2):
    """Furthest OPAQUE pixel from centre. Measuring the bounding box's
    corners instead over-constrains badly here - a book is wide and flat,
    so its bbox corners are empty air, and sizing to them leaves the art
    marooned in the middle of the tile."""
    px = im.load()
    w, h = im.size
    cx, cy = w / 2, h / 2
    best = 0.0
    for y in range(0, h, step):
        for x in range(0, w, step):
            if px[x, y][3] > 16:
                d = math.hypot(x - cx, y - cy)
                if d > best:
                    best = d
    return best


def card_ground(im):
    """Median colour of the card's ground, so the Android background layer
    matches the artwork instead of a single sampled pixel."""
    px = im.load()
    w, h = im.size
    rs, gs, bs = [], [], []
    for y in range(0, h, 7):
        for x in range(0, w, 7):
            p = px[x, y]
            if p[3] > 200 and is_ground(p):
                rs.append(p[0])
                gs.append(p[1])
                bs.append(p[2])
    if not rs:
        return GROUND
    mid = len(rs) // 2
    return (sorted(rs)[mid], sorted(gs)[mid], sorted(bs)[mid])


def main():
    src = Image.open(SRC).convert("RGBA")
    print(f"source {src.size}")

    ground = card_ground(src)
    print("card ground #%02X%02X%02X  <- set adaptive_icon_background to this"
          % ground)

    # ── Full-bleed square for iOS + legacy Android ──────────────────────
    # Composite the original card over a solid ground so the rounded
    # corners fill out to a true square. No alpha survives.
    full = Image.new("RGBA", src.size, ground + (255,))
    full.alpha_composite(src)
    full = full.convert("RGB").resize((SIZE, SIZE), Image.LANCZOS)
    full.save(OUT_FULL)
    print(f"wrote {OUT_FULL} {full.size} RGB")

    # ── Transparent foreground for the Android adaptive icon ────────────
    art = art_only(src)
    b, _ = bbox_and_radius(art)
    art = art.crop(b)                       # trim to the artwork itself
    aw, ah = art.size

    # Scale by the art's furthest OPAQUE pixel, not its bbox corner, so the
    # safe circle is actually filled.
    r0 = true_radius(art)
    target = (SAFE_R / INSET_KEEP) * 0.96   # 4% margin
    scale = target / r0
    nw, nh = max(1, round(aw * scale)), max(1, round(ah * scale))
    art = art.resize((nw, nh), Image.LANCZOS)

    fg = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    fg.alpha_composite(art, ((SIZE - nw) // 2, (SIZE - nh) // 2))
    fg.save(OUT_FG)

    r = true_radius(fg)
    print(f"wrote {OUT_FG} {fg.size} RGBA")
    print(f"art {nw}x{nh}, true r {r:.0f} -> after 16% inset "
          f"{r * INSET_KEEP:.0f} (safe {SAFE_R:.0f})")


if __name__ == "__main__":
    main()

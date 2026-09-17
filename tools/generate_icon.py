"""Yatta! launcher icon — the victory figure.

Regenerate:
    python tools/generate_icon.py            # writes icon_full.html / icon_fg.html
    # screenshot each at 1024x1024 with Edge headless:
    #   msedge --headless=new --disable-gpu --window-size=1024,1024 \
    #     "--screenshot=<abs>/icon.png" --virtual-time-budget=4000 \
    #     "file:///<abs>/icon_full.html"
    #   (add --default-background-color=00000000 for the foreground)
    # then: cp -> assets/icon.png, assets/icon_foreground.png
    dart run flutter_launcher_icons

THE MARK
"Yatta!" is the shout you make with your arms in the air. A figure with
raised arms is the same shape as the letter Y. Name, gesture and letterform
collapse into one mark, which is what makes it ownable instead of being
another checkmark in a category full of checkmarks.

WHY NOT A CHARACTER
Master Ren (the fox sensei) was on the launcher briefly and read as a kids'
app — cartoon eyes and a round muzzle set the wrong register for something
about discipline and an ambitious life. Ren still owns reflection INSIDE the
app; he is the companion, not the brand mark. Before him the Victory Burst
was tried and lost too (see docs/brand_yatta.md for that history).

WHY THIS PALETTE
Deep emerald rather than the bright #58CC02: the brand green stays the app's
interface colour, but at launcher size it reads playful, and a deeper shade
of the same family keeps the lineage while looking adult. One restrained
gold accent, never a second.
"""
import math
import os

OUT = os.path.dirname(os.path.abspath(__file__))

GROUND = "#0F3B2B"      # deep emerald — the launcher ground
MARK = "#F4F7F2"        # near-white; pure #FFF is harsh at this size
GOLD = "#E8B54A"        # restrained gold, not toy yellow

# Geometry, in 1024 space, centred on the canvas.
STROKE = 100.0
FORK = (512.0, 566.0)
ARM_DX, ARM_DY = 202.0, 214.0     # wide spread — this is the triumph
STEM_BOTTOM = 782.0
HEAD_C = (512.0, 284.0)
HEAD_R = 74.0


def _bbox():
    """Extent of the drawn mark including round caps."""
    half = STROKE / 2
    xs = [FORK[0] - ARM_DX - half, FORK[0] + ARM_DX + half]
    ys = [min(HEAD_C[1] - HEAD_R, FORK[1] - ARM_DY - half),
          STEM_BOTTOM + half]
    return min(xs), min(ys), max(xs), max(ys)


def mark(scale: float) -> str:
    """The figure, scaled about the canvas centre with its bbox centred."""
    x0, y0, x1, y1 = _bbox()
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    fx, fy = FORK
    return f'''
  <g transform="translate(512,512) scale({scale}) translate({-cx},{-cy})">
    <path d="M{fx},{STEM_BOTTOM} L{fx},{fy}" stroke="{MARK}"
          stroke-width="{STROKE}" stroke-linecap="round"/>
    <path d="M{fx},{fy} L{fx - ARM_DX},{fy - ARM_DY}" stroke="{MARK}"
          stroke-width="{STROKE}" stroke-linecap="round"/>
    <path d="M{fx},{fy} L{fx + ARM_DX},{fy - ARM_DY}" stroke="{MARK}"
          stroke-width="{STROKE}" stroke-linecap="round"/>
    <circle cx="{HEAD_C[0]}" cy="{HEAD_C[1]}" r="{HEAD_R}" fill="{GOLD}"/>
  </g>'''


def corner_radius(scale: float) -> float:
    x0, y0, x1, y1 = _bbox()
    return math.hypot((x1 - x0) * scale / 2, (y1 - y0) * scale / 2)


def page(body: str, bg: str | None) -> str:
    rect = f'<rect width="1024" height="1024" fill="{bg}"/>' if bg else ""
    return f'''<!doctype html><html><head><meta charset="utf-8"><style>
html,body{{margin:0;padding:0;background:{bg or "transparent"};}}
svg{{display:block;}}
</style></head><body>
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  {rect}
  {body}
</svg>
</body></html>'''


if __name__ == "__main__":
    # Full-bleed square: iOS + legacy Android launchers.
    with open(os.path.join(OUT, "icon_full.html"), "w", encoding="utf-8") as f:
        f.write(page(mark(1.10), GROUND))

    # Adaptive foreground: transparent, and drawn LARGE on purpose.
    # flutter_launcher_icons wraps it in `android:inset="16%"`, leaving the
    # art at 68% of the layer, so pre-shrinking here would shrink it twice.
    # Size by the true opaque-pixel radius rather than the bbox corners —
    # this mark's corners are empty, so the box overstates its reach.
    # 1.42 puts the furthest opaque pixel at r≈302 after the tool's inset,
    # just inside the 66/108dp guaranteed-safe circle (r=312).
    fg = 1.42
    with open(os.path.join(OUT, "icon_fg.html"), "w", encoding="utf-8") as f:
        f.write(page(mark(fg), None))

    print(f"full  bbox-corner radius {corner_radius(1.10):.0f}px (half-canvas 512)")
    print(f"fg    bbox-corner radius {corner_radius(fg):.0f}px "
          f"-> after 16% inset {corner_radius(fg) * 0.68:.0f}px "
          f"(safe 312; verify with the true-pixel check)")

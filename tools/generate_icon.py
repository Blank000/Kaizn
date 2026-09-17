"""Yatta! launcher icon — Master Ren's head on the brand green.

Regenerate:
    python tools/generate_icon.py                     # writes the two HTMLs
    # screenshot each at 1024x1024 with Edge headless:
    #   msedge --headless=new --disable-gpu --window-size=1024,1024 \
    #     "--screenshot=<abs>/icon.png" --virtual-time-budget=4000 \
    #     "file:///<abs>/v2_full.html"
    #   (add --default-background-color=00000000 for the foreground)
    # then: cp -> assets/icon.png, assets/icon_foreground.png
    dart run flutter_launcher_icons


Design decisions, all of them paid for by a critic pass on v1:

* **No burst.** Two rounds of testing put the Victory Burst behind the head;
  every one read as a lion's mane or a sunflower and shrank the face to
  nothing at 48px. The burst already lives in-app as the completion
  animation. The icon is the fox.
* **A dark silhouette outline instead of a darker ground.** Orange fur on
  #58CC02 is about 1.3:1 — a texture, not a figure. Rather than abandon the
  brand green, the whole head+ears silhouette gets a dark brown keyline, so
  the shape projects at any size against any ground.
* **Dark brows, not cream.** Ren's canonical cream brows sit ~1 unit above a
  white sclera; below ~120px they merge into one pale bar that reads as a
  visor. Recoloured to the ear brown they become the upper face's dark
  anchor instead of its worst liability.
* **Bigger eyes, narrower muzzle.** The eyes are the legibility asset and
  were sized like a detail; the muzzle was 62% of head width, which is a
  shiba, not a fox. Now 20% and 38%.
* **Exact mirroring.** Every right-side shape is the left one reflected
  about x=100, so no hand-placed asymmetry can creep in.

Geometry lives in Ren's own 200-unit space so it stays comparable with
lib/shared/widgets/ren_figure.dart.
"""
import math
import os

OUT = os.path.dirname(os.path.abspath(__file__))

GREEN = "#58CC02"          # AppColors.primary — unchanged, deliberately
FOX = "#E8823C"
CREAM = "#F7EFDC"
INK = "#4A2E1C"
INNER_EAR = "#5C3A22"
BROW = "#4A3226"           # was cream; see module docstring
LINE = "#3E2A20"           # silhouette keyline

OUTLINE_W = 3.0            # in head units (~17px at shipping scale)

# Head bbox in the 200-unit space, after the fixes below.
BBOX = (44.0 - OUTLINE_W, 25.0, 156.0 + OUTLINE_W, 134.5)

# The cranium is NOT a circle. A circle gave a shiba: wide cheeks all the way
# down to a round chin. A fox reads as a triangle, so the skull is wide at the
# temples and tapers into a narrow jaw. This single change does more for
# fox-ness than the ears do.
CRANIUM = ("M44,88 "
           "C44,64 68,50 100,50 "
           "C132,50 156,64 156,88 "
           "C156,107 142,121 122,129 "
           "C114,132 107,133 100,133 "
           "C93,133 86,132 78,129 "
           "C58,121 44,107 44,88 Z")


def mirror(d: str) -> str:
    """Reflect a path's x coordinates about x=100."""
    out = []
    for tok in d.replace(",", " ").split():
        if tok.replace(".", "", 1).replace("-", "", 1).isdigit():
            out.append(tok)
        else:
            out.append(tok)
    # Coordinates are always emitted as "x,y" pairs in this file, so do the
    # reflection on the structured builders instead of on strings.
    raise NotImplementedError


def path(points, close=True):
    """points: list of ('M'|'L'|'C'|'Q', (x,y), ...) tuples already ordered."""
    parts = []
    for cmd, *pts in points:
        coords = " ".join(f"{x:.2f},{y:.2f}" for x, y in pts)
        parts.append(f"{cmd}{coords}")
    return " ".join(parts) + (" Z" if close else "")


def flip(pts):
    return [(200.0 - x, y) for x, y in pts]


# ── Ear (left); the right ear is this reflected, so they cannot drift ──────
# Shorter and splayed wider than v1: the tips now sit inside the Android
# 66/108 safe circle even at the larger head size, and a steeper taper reads
# MORE vulpine, not less.
_EAR_OUTER = [("M", (58, 68)), ("C", (52, 52), (50, 38), (52, 28))]
_EAR_TOP = [("C", (70, 34), (86, 44), (96, 58))]
_EAR_BACK = [("C", (84, 64), (70, 66), (58, 68))]
_INNER = [
    ("M", (63, 62)), ("C", (59, 50), (58, 42), (59, 34)),
    ("C", (72, 40), (82, 47), (89, 57)),
    ("C", (80, 60), (71, 61), (63, 62)),
]


def _seg_to_pts(segs):
    pts = []
    for cmd, *p in segs:
        pts.extend(p)
    return pts


def _rebuild(segs, flipped):
    out = []
    for cmd, *p in segs:
        q = flip(p) if flipped else list(p)
        out.append((cmd, *q))
    return out


def ear(flipped: bool) -> str:
    segs = _EAR_OUTER + _EAR_TOP + _EAR_BACK
    return path(_rebuild(segs, flipped))


def inner_ear(flipped: bool) -> str:
    return path(_rebuild(_INNER, flipped))


def silhouette(stroke: bool) -> str:
    """Ears + cranium. Drawn twice: once fat in the keyline colour to build a
    clean union outline, once in fur on top — which also hides the ear/head
    seam that the critic flagged."""
    if stroke:
        style = (f'fill="{LINE}" stroke="{LINE}" stroke-width="{OUTLINE_W * 2}" '
                 f'stroke-linejoin="round"')
    else:
        style = f'fill="{FOX}"'
    return f'''
    <path d="{ear(False)}" {style}/>
    <path d="{ear(True)}" {style}/>
    <path d="{CRANIUM}" {style}/>'''


def eye(cx: float) -> str:
    # Pupil fills ~75% of the sclera and sits low enough to touch the lower
    # lid — visible white under the iris is the universal "startled" cue.
    return (f'<ellipse cx="{cx}" cy="93" rx="11" ry="8.5" fill="#FFFFFF"/>'
            f'<circle cx="{cx}" cy="94.6" r="6.3" fill="{INK}"/>'
            f'<circle cx="{cx + 2.3}" cy="91.9" r="2.0" fill="#FFFFFF"/>')


def head() -> str:
    return f'''
    {silhouette(stroke=True)}
    {silhouette(stroke=False)}
    <path d="{inner_ear(False)}" fill="{INNER_EAR}"/>
    <path d="{inner_ear(True)}" fill="{INNER_EAR}"/>

    <!-- brows: dark, thin, close to the eye — the upper face's anchor -->
    <path d="M65,84 Q76,78 87,83" fill="none" stroke="{BROW}"
          stroke-width="5.2" stroke-linecap="round"/>
    <path d="M135,84 Q124,78 113,83" fill="none" stroke="{BROW}"
          stroke-width="5.2" stroke-linecap="round"/>

    {eye(75)}
    {eye(125)}

    <!-- muzzle: 36% of head width (was 62% — that was a shiba), and tucked
         fully inside the jaw so it never breaks the silhouette -->
    <ellipse cx="100" cy="116" rx="20" ry="15.5" fill="{CREAM}"/>
    <ellipse cx="100" cy="109" rx="7.5" ry="5.5" fill="{INK}"/>
    <path d="M100,113.5 L100,118" stroke="{INK}" stroke-width="3"
          stroke-linecap="round"/>
    <path d="M94,118 Q100,123 106,118" fill="none" stroke="{INK}"
          stroke-width="3" stroke-linecap="round"/>'''


def mark(scale: float) -> str:
    """Centre the head bbox on the 1024 canvas at the given scale."""
    x0, y0, x1, y1 = BBOX
    w, h = x1 - x0, y1 - y0
    hs = (620.0 / w) * scale          # head ≈ 60% of canvas at scale 1
    cx = (x0 + x1) / 2
    cy = (y0 + y1) / 2
    tx = 512.0 - cx * hs
    ty = 512.0 - cy * hs
    return (f'<g transform="translate({tx:.2f},{ty:.2f}) scale({hs:.4f})">'
            f'{head()}</g>')


def content_radius(scale: float) -> float:
    x0, y0, x1, y1 = BBOX
    w, h = x1 - x0, y1 - y0
    hs = (620.0 / w) * scale
    return math.hypot(w * hs / 2, h * hs / 2)


def page(body: str, bg: str | None) -> str:
    rect = f'<rect width="1024" height="1024" fill="{bg}"/>' if bg else ""
    css_bg = bg or "transparent"
    return f'''<!doctype html><html><head><meta charset="utf-8"><style>
html,body{{margin:0;padding:0;background:{css_bg};}}
svg{{display:block;}}
</style></head><body>
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  {rect}
  {body}
</svg>
</body></html>'''


if __name__ == "__main__":
    # Full-bleed square (iOS + legacy Android launchers).
    with open(os.path.join(OUT, "v2_full.html"), "w", encoding="utf-8") as f:
        f.write(page(mark(1.0), GREEN))
    # Adaptive foreground: transparent, but drawn FULL SIZE.
    # flutter_launcher_icons wraps the foreground in `android:inset="16%"`,
    # which leaves the art at 68% of the layer. Pre-shrinking here as well
    # would shrink it twice and leave a tiny fox in a sea of green.
    #
    # Sized by the TRUE opaque-pixel radius, not the bbox corners: a head has
    # empty corners, so measuring the box throws away ~19% of the allowance.
    # At 1.15 the furthest opaque pixel lands at r≈303 after the tool's
    # inset — just inside the 66/108dp guaranteed-safe circle (r=312) that
    # every OEM mask respects.
    fg_scale = 1.15
    with open(os.path.join(OUT, "v2_fg.html"), "w", encoding="utf-8") as f:
        f.write(page(mark(fg_scale), None))
    print(f"full   content radius: {content_radius(1.0):.0f}px (canvas half 512)")
    print(f"fg     content radius: {content_radius(fg_scale):.0f}px "
          f"(safe 312, mask 341)")

"""Zuzu — Lottie animation generator.

    python tools/build_zuzu_lottie.py

Writes the three first-release animations from "A Day With Zuzu" into
assets/lottie/:

    zuzu_invitation.json    loop   4.0s   "One small step?"
    zuzu_first_win.json     once   1.4s   the proud flight
    zuzu_day_complete.json  once   2.0s   the bow and goodbye

WHY GENERATED RATHER THAN DRAWN
Same reason Ren and Pico are CustomPaint built from primitives: hand-plotted
paths drift, and every edit risks a distortion nobody notices until it ships.
Here the character is defined ONCE (`zuzu_parts`) and the three animations
only keyframe transforms on top of it, so the three can never disagree about
what Zuzu looks like.

TECHNIQUE
Lottie layer parenting does the work. Two null layers - ROOT at the feet and
HEAD at the neck - carry the hop, the bow and the head tilt; every body part
is parented to one of them and keeps absolute canvas coordinates. That means
no shape data is ever recomputed per frame, which is what keeps these files
small (~10KB) and safe on Flutter's renderer.

CONSTRAINTS HONOURED (see docs/ANIMATION_BRIEF.md)
- shape layers only, no images, no expressions, no text, no merge paths
- solid strokes, no gradients, no effects
- 30fps, 512x512 square, transparent canvas
- **frame 0 of every file is Zuzu standing neutral and readable**, because
  reduced motion FREEZES the animation rather than hiding it
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "lottie")

FPS = 30
W = H = 512

# Sampled from the owner's storyboard (images/Character/ and the
# "A Day With Zuzu" board).
CREAM = "#FCE4B4"      # feathers
ROBE = "#9C9C78"       # sage robe
TEAL = "#3C9084"       # headband
INK = "#2A2018"        # outline + eyes
BEAK = "#F0A03C"       # beak and feet
BLUSH = "#F0B0A4"
WOOD = "#A8845C"       # staff
WHITE = "#FFFFFF"

SW = 7.0               # outline weight

ROOT_PIVOT = [256.0, 432.0]    # at the feet: hop, bow, squash
HEAD_PIVOT = [256.0, 306.0]    # at the neck: tilt, nod

IND = dict(staff=1, beak=2, blush=3, eyes=4, band=5, head=6, tuft=7,
           wingL=8, wingR=9, robe=10, body=11, feet=12, ROOT=20, HEAD=21)


# ── tiny Lottie helpers ───────────────────────────────────────────────────
def rgba(h):
    h = h.lstrip("#")
    return [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)] + [1]


def sp(v):
    """Static property."""
    return {"a": 0, "k": v}


def kf(pairs, hold=False):
    """Animated property. pairs = [(frame, value), ...]; values are lists.

    Ease is a soft in-out by default, which is what stops the motion looking
    mechanical. `hold` gives stepped keys - used for blinks, where a linear
    interpolation would read as a droopy eyelid instead of a snap."""
    out = []
    for i, (t, v) in enumerate(pairs):
        k = {"t": float(t), "s": list(v)}
        if i < len(pairs) - 1:
            if hold:
                k["h"] = 1
            else:
                k["i"] = {"x": [0.55], "y": [1]}
                k["o"] = {"x": [0.45], "y": [0]}
        out.append(k)
    return {"a": 1, "k": out}


def fill(c):
    return {"ty": "fl", "c": sp(rgba(c)), "o": sp(100), "r": 1, "nm": "f"}


def stroke(c=INK, w=SW):
    return {"ty": "st", "c": sp(rgba(c)), "o": sp(100), "w": sp(w),
            "lc": 2, "lj": 2, "nm": "s"}


def tr(pos=(0, 0), anchor=(0, 0), scale=(100, 100), rot=0, op=100):
    return {"ty": "tr", "p": sp(list(pos)), "a": sp(list(anchor)),
            "s": sp(list(scale)), "r": sp(rot), "o": sp(op),
            "sk": sp(0), "sa": sp(0), "nm": "tr"}


def group(items, name="g", **trkw):
    return {"ty": "gr", "nm": name, "it": items + [tr(**trkw)]}


def ell(cx, cy, w, h, c, outline=True, sw=SW):
    it = [{"ty": "el", "p": sp([cx, cy]), "s": sp([w, h]), "d": 1, "nm": "e"},
          fill(c)]
    if outline:
        it.append(stroke(w=sw))
    return group(it, "ell")


def rect(cx, cy, w, h, c, r=8, outline=True):
    it = [{"ty": "rc", "p": sp([cx, cy]), "s": sp([w, h]), "r": sp(r),
           "d": 1, "nm": "r"}, fill(c)]
    if outline:
        it.append(stroke())
    return group(it, "rect")


def poly(points, c, outline=True, closed=True):
    v = [list(p) for p in points]
    z = [[0, 0]] * len(v)
    it = [{"ty": "sh", "nm": "p",
           "ks": sp({"i": z, "o": z, "v": v, "c": closed})}, fill(c)]
    if outline:
        it.append(stroke())
    return group(it, "poly")


def layer(ind, name, shapes, parent=None, ks=None, op_frames=90):
    base = {"o": sp(100), "r": sp(0), "p": sp([0, 0, 0]),
            "a": sp([0, 0, 0]), "s": sp([100, 100, 100])}
    if ks:
        base.update(ks)
    L = {"ddd": 0, "ind": ind, "ty": 4, "nm": name, "sr": 1, "ks": base,
         "ao": 0, "shapes": shapes, "ip": 0, "op": op_frames, "st": 0,
         "bm": 0}
    if parent is not None:
        L["parent"] = parent
    return L


def null(ind, name, pivot, parent=None, ks=None, op_frames=90):
    base = {"o": sp(0), "r": sp(0), "p": sp(pivot + [0]),
            "a": sp(pivot + [0]), "s": sp([100, 100, 100])}
    if ks:
        base.update(ks)
    L = {"ddd": 0, "ind": ind, "ty": 3, "nm": name, "sr": 1, "ks": base,
         "ao": 0, "ip": 0, "op": op_frames, "st": 0, "bm": 0}
    if parent is not None:
        L["parent"] = parent
    return L


# ── Zuzu, defined once ────────────────────────────────────────────────────
def zuzu_parts(op, eyes_ks=None, wingL_ks=None, wingR_ks=None,
               head_ks=None, root_ks=None, body_ks=None, happy_eyes=False):
    """All of Zuzu. Layers are returned front-to-back (Lottie draws the
    first entry on top)."""
    R, Hd = IND["ROOT"], IND["HEAD"]

    # Staff: held in the left wing, so it hangs off ROOT not the head.
    # Kept clear of the head's left edge (x=170) so it never crosses the
    # face, and pivoted at its foot so a bow swings it naturally.
    staff = layer(IND["staff"], "staff",
                  [rect(148, 356, 15, 202, WOOD, r=8)], parent=R,
                  ks=dict(a=sp([148, 457, 0]), p=sp([148, 457, 0])),
                  op_frames=op)

    beak = layer(IND["beak"], "beak",
                 [poly([(256, 284), (276, 300), (256, 316), (236, 300)],
                       BEAK)], parent=Hd, op_frames=op)

    blush = layer(IND["blush"], "blush",
                  [ell(198, 296, 32, 18, BLUSH, outline=False),
                   ell(314, 296, 32, 18, BLUSH, outline=False)],
                  parent=Hd, op_frames=op)

    if happy_eyes:
        # Closed happy arcs - the "I knew you could" face.
        eshapes = [
            group([{"ty": "sh", "nm": "p", "ks": sp({
                "i": [[0, 0], [-8, 6], [0, 0]], "o": [[8, 6], [0, 0], [0, 0]],
                "v": [[208, 268], [224, 258], [240, 268]], "c": False})},
                stroke(w=8)], "eL"),
            group([{"ty": "sh", "nm": "p", "ks": sp({
                "i": [[0, 0], [-8, 6], [0, 0]], "o": [[8, 6], [0, 0], [0, 0]],
                "v": [[272, 268], [288, 258], [304, 268]], "c": False})},
                stroke(w=8)], "eR"),
        ]
    else:
        eshapes = [ell(224, 264, 27, 31, INK, outline=False),
                   ell(288, 264, 27, 31, INK, outline=False),
                   ell(231, 256, 9, 9, WHITE, outline=False),
                   ell(295, 256, 9, 9, WHITE, outline=False)]
    # Anchor at the midpoint between the eyes. Without this the blink
    # scales toward the canvas origin and the eyes slide off the head.
    eyes = layer(IND["eyes"], "eyes", eshapes, parent=Hd,
                 ks=dict(a=sp([256, 264, 0]), p=sp([256, 264, 0]),
                         **(eyes_ks or {})), op_frames=op)

    band = layer(IND["band"], "band", [
        rect(256, 224, 176, 28, TEAL, r=6),
        poly([(168, 216), (140, 196), (150, 232)], TEAL),
        poly([(168, 232), (142, 250), (156, 256)], TEAL),
    ], parent=Hd, op_frames=op)

    head = layer(IND["head"], "head", [ell(256, 256, 172, 156, CREAM)],
                 parent=Hd, op_frames=op)

    tuft = layer(IND["tuft"], "tuft", [
        ell(238, 180, 26, 38, CREAM), ell(258, 170, 26, 42, CREAM),
        ell(278, 182, 24, 36, CREAM),
    ], parent=Hd, op_frames=op)

    # Anchor sits 35px above the wing's centre, i.e. at the shoulder, so a
    # flap pivots from the joint instead of spinning about its middle.
    wingL = layer(IND["wingL"], "wingL", [ell(0, 0, 46, 76, CREAM)],
                  parent=R,
                  ks=dict(a=sp([0, -35, 0]), p=sp([186, 330, 0]),
                          **(wingL_ks or {})), op_frames=op)
    wingR = layer(IND["wingR"], "wingR", [ell(0, 0, 46, 76, CREAM)],
                  parent=R,
                  ks=dict(a=sp([0, -35, 0]), p=sp([326, 330, 0]),
                          **(wingR_ks or {})), op_frames=op)

    robe = layer(IND["robe"], "robe", [
        ell(256, 388, 158, 122, ROBE),
        ell(256, 378, 26, 26, ROBE),
    ], parent=R, ks=body_ks or {}, op_frames=op)

    body = layer(IND["body"], "body", [ell(256, 352, 152, 148, CREAM)],
                 parent=R, ks=body_ks or {}, op_frames=op)

    feet = layer(IND["feet"], "feet", [
        ell(232, 424, 34, 15, BEAK), ell(282, 424, 34, 15, BEAK),
    ], parent=R, op_frames=op)

    rootL = null(R, "ROOT", list(ROOT_PIVOT), ks=root_ks or {}, op_frames=op)
    headL = null(Hd, "HEAD", list(HEAD_PIVOT), parent=R, ks=head_ks or {},
                 op_frames=op)

    return [staff, beak, blush, eyes, band, head, tuft,
            wingL, wingR, robe, body, feet, headL, rootL]


def comp(name, op, layers):
    return {"v": "5.7.4", "fr": FPS, "ip": 0, "op": op, "w": W, "h": H,
            "nm": name, "ddd": 0, "assets": [], "layers": layers}


# ── 1. The Invitation - loop ──────────────────────────────────────────────
def invitation():
    op = 120                                   # 4.0s
    # Two blinks, stepped so the lid snaps rather than droops.
    eyes = dict(s=kf([(0, [100, 100, 100]), (38, [100, 100, 100]),
                      (41, [100, 12, 100]), (44, [100, 100, 100]),
                      (96, [100, 100, 100]), (99, [100, 12, 100]),
                      (102, [100, 100, 100]), (120, [100, 100, 100])],
                     hold=True))
    # Head: a slow curious tilt toward the journal, then back.
    head = dict(r=kf([(0, [0]), (30, [-5]), (62, [-5]), (92, [0]),
                      (120, [0])]))
    # Right wing lifts to gesture at the journal, holds, lowers.
    wingR = dict(r=kf([(0, [0]), (34, [-38]), (66, [-34]), (92, [0]),
                       (120, [0])]))
    # Breathing, carried on ROOT so the whole bird rises together.
    root = dict(s=kf([(0, [100, 100, 100]), (60, [100.8, 101.6, 100]),
                      (120, [100, 100, 100])]))
    return comp("zuzu_invitation", op,
                zuzu_parts(op, eyes_ks=eyes, head_ks=head, wingR_ks=wingR,
                           root_ks=root))


# ── 2. The First Win - one shot ───────────────────────────────────────────
def first_win():
    op = 42                                    # 1.4s
    # Anticipation dip, leap, hang, land, settle. Squash on ROOT scale,
    # height on ROOT position.
    root = dict(
        p=kf([(0, [256, 432, 0]), (5, [256, 440, 0]), (14, [256, 352, 0]),
              (22, [256, 344, 0]), (31, [256, 436, 0]), (36, [256, 430, 0]),
              (42, [256, 432, 0])]),
        s=kf([(0, [100, 100, 100]), (5, [106, 92, 100]),
              (13, [95, 108, 100]), (22, [100, 100, 100]),
              (31, [108, 90, 100]), (37, [99, 101, 100]),
              (42, [100, 100, 100])]),
    )
    # Wings: two full flaps through the air time.
    wingL = dict(r=kf([(0, [0]), (6, [18]), (13, [-62]), (19, [-14]),
                       (25, [-58]), (32, [6]), (42, [0])]))
    wingR = dict(r=kf([(0, [0]), (6, [-18]), (13, [62]), (19, [14]),
                       (25, [58]), (32, [-6]), (42, [0])]))
    head = dict(r=kf([(0, [0]), (6, [6]), (16, [-8]), (26, [-4]),
                      (34, [3]), (42, [0])]))
    # Eyes squint with delight at the top of the arc.
    eyes = dict(s=kf([(0, [100, 100, 100]), (10, [100, 100, 100]),
                      (14, [100, 42, 100]), (28, [100, 42, 100]),
                      (34, [100, 100, 100]), (42, [100, 100, 100])]))
    return comp("zuzu_first_win", op,
                zuzu_parts(op, root_ks=root, wingL_ks=wingL, wingR_ks=wingR,
                           head_ks=head, eyes_ks=eyes))


# ── 3. Day Complete - one shot ────────────────────────────────────────────
def day_complete():
    op = 60                                    # 2.0s
    # Look down at the finished list, bow from the feet, rise, wave.
    root = dict(r=kf([(0, [0]), (10, [0]), (26, [20]), (38, [20]),
                      (50, [0]), (60, [0])]))
    head = dict(r=kf([(0, [0]), (9, [-9]), (26, [6]), (38, [6]),
                      (50, [-2]), (60, [0])]))
    # Eyes close through the bow - respect, not sleep, because the head is
    # still lifted at the end.
    eyes = dict(s=kf([(0, [100, 100, 100]), (12, [100, 100, 100]),
                      (18, [100, 16, 100]), (44, [100, 16, 100]),
                      (52, [100, 100, 100]), (60, [100, 100, 100])]))
    # Right wing tucks for the bow, then waves twice.
    wingR = dict(r=kf([(0, [0]), (22, [26]), (40, [20]), (48, [-52]),
                       (52, [-34]), (56, [-52]), (60, [-40])]))
    wingL = dict(r=kf([(0, [0]), (24, [-22]), (44, [-16]), (60, [0])]))
    return comp("zuzu_day_complete", op,
                zuzu_parts(op, root_ks=root, head_ks=head, eyes_ks=eyes,
                           wingR_ks=wingR, wingL_ks=wingL))


BUILDS = {
    "zuzu_invitation.json": invitation,
    "zuzu_first_win.json": first_win,
    "zuzu_day_complete.json": day_complete,
}

if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    for fname, fn in BUILDS.items():
        data = fn()
        p = os.path.join(OUT_DIR, fname)
        with open(p, "w", encoding="utf-8") as f:
            json.dump(data, f, separators=(",", ":"))
        kb = os.path.getsize(p) / 1024
        secs = data["op"] / FPS
        print(f"{fname:26s} {kb:5.1f} KB  {secs:.1f}s  "
              f"{data['op']:3d} frames")

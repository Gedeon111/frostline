#!/usr/bin/env python3
"""
Bake a Figma stud sheet into a tileable, backdrop-independent Roblox texture.

WHY THIS EXISTS
---------------
In Figma a studded surface is the stud sheet twice over the button's gradient:
Overlay at 60% fill, then Plus Lighter at 25%. Roblox ScreenGui has no blend modes,
so neither pass can be reproduced live, and stacking the sheet on itself does not
help -- that yields 0.85x the original alpha, fainter than the source.

What makes Overlay read is that it brightens where the source is lighter than
mid-grey and darkens where it is darker. Normal alpha compositing can do exactly that
if the texture carries white pixels for the light half and black for the dark half,
with alpha holding the magnitude. That is a signed emboss. Unlike baking onto a
backdrop colour it stays correct on every colourway, so one asset serves the blue
bar, the red close cell, the gold bundle and the green buttons alike.

    overlay term      |lum - 0.5| * 2 * a * overlay_fill    white if lum > 0.5 else black
    plus lighter term  lum * a * plus_fill                  always white (additive)
    dark term          overlay term * dark_scale            shadow half only
    output             net of the two, as one signed pixel

WHY dark_scale EXISTS
---------------------
Measured against renders of the same swatch, Figma and a plain symmetric Overlay
agree almost exactly on the highlight but not at all on the shadow:

                      SVG / symmetric overlay      Figma
    lighter mean            +12.7                  +13.3
    lighter max             +30.6                  +30.3
    darker mean             -36.0                   -9.0
    darker max              -97.2                  -22.6

Figma's shadow lands around a quarter of the strength, which is what makes its studs
read as smoothly integrated rather than punched into the surface. Hence 0.25.

The sheet is also cropped to a single tile first, detected by autocorrelation on the
alpha channel, so the result tiles seamlessly at any size in Roblox.

USAGE
-----
    python tools/stud_bake.py image.png -o stud_emboss.png --preview

Then upload the output and reference it from Theme. Draw it untinted and fully
opaque: ImageColor3 multiplies, so a tint would erase the black pixels and take the
shadow half of the emboss with them.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image

LUMA = np.array([0.2126, 0.7152, 0.0722], dtype=np.float64)

# Sample colourways for --preview, taken from the SVG export's body gradients.
PREVIEW_BANDS = [
    ("blue", (0x22, 0xE9, 0xFF), (0x00, 0x95, 0xFF)),
    ("red", (0xFF, 0x63, 0x63), (0xFF, 0x2C, 0x2C)),
    ("gold", (0xFF, 0xC4, 0x00), (0xFF, 0xCC, 0x00)),
    ("green", (0x80, 0xF0, 0x57), (0x00, 0xE5, 0x22)),
]


def detect_period(alpha: np.ndarray, axis: int, min_period: int = 8) -> int:
    """Smallest shift along `axis` that the alpha channel repeats under.

    Scores every candidate by mean absolute difference against itself shifted, then
    takes the smallest period within 15% of the best score -- the global minimum is
    usually a multiple of the true period, and we want the fundamental.
    """
    length = alpha.shape[axis]
    limit = length // 2
    if limit <= min_period:
        return length

    scores = {}
    for p in range(min_period, limit + 1):
        if axis == 0:
            diff = np.abs(alpha[p:, :] - alpha[:-p, :])
        else:
            diff = np.abs(alpha[:, p:] - alpha[:, :-p])
        scores[p] = float(diff.mean())

    best = min(scores.values())
    # A perfectly flat channel scores ~0 everywhere; guard the tolerance.
    tolerance = max(best * 1.15, best + 0.35)
    for p in sorted(scores):
        if scores[p] <= tolerance:
            return p
    return min(scores, key=scores.get)


def bake(
    rgba: np.ndarray,
    overlay_fill: float,
    plus_fill: float,
    strength: float,
    dark_scale: float,
) -> np.ndarray:
    """Signed emboss from a stud sheet. See module docstring for the derivation."""
    rgb = rgba[..., :3].astype(np.float64) / 255.0
    a = rgba[..., 3].astype(np.float64) / 255.0

    lum = rgb @ LUMA
    signed = (lum - 0.5) * 2.0

    overlay = np.abs(signed) * a * overlay_fill
    plus = lum * a * plus_fill

    lightens = signed >= 0
    white_term = plus + np.where(lightens, overlay, 0.0)
    # Shadow attenuated on its own: Figma's dark half is far gentler than a symmetric
    # Overlay, and that asymmetry is what makes the studs sit in the surface.
    black_term = np.where(lightens, 0.0, overlay * dark_scale)
    net = white_term - black_term

    out = np.zeros_like(rgba)
    colour = np.where(net >= 0, 255, 0).astype(np.uint8)
    out[..., 0] = colour
    out[..., 1] = colour
    out[..., 2] = colour
    out[..., 3] = np.clip(np.abs(net) * strength * 255.0, 0, 255).round().astype(np.uint8)
    return out


def make_preview(tile: Image.Image, path: Path, cell=(760, 120), tile_px=96) -> None:
    scaled = tile.resize((tile_px, tile_px), Image.LANCZOS)
    w, h = cell
    rows = []
    for _name, top, bottom in PREVIEW_BANDS:
        t = np.linspace(0.0, 1.0, h)[:, None]
        grad = (np.array(top) * (1 - t) + np.array(bottom) * t).round().astype(np.uint8)
        band = Image.fromarray(np.repeat(grad[:, None, :], w, axis=1), "RGB").convert("RGBA")
        for y in range(0, h, tile_px):
            for x in range(0, w, tile_px):
                band.alpha_composite(scaled, (x, y))
        rows.append(band)

    out = Image.new("RGBA", (w, len(rows) * (h + 8) - 8), (24, 24, 28, 255))
    for i, row in enumerate(rows):
        out.paste(row, (0, i * (h + 8)))
    out.save(path)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("source", type=Path, help="stud sheet exported from Figma (PNG with alpha)")
    ap.add_argument("-o", "--out", type=Path, help="output PNG (default: <source>_emboss.png)")
    ap.add_argument("--overlay", type=float, default=0.60, help="Overlay layer fill (default 0.60)")
    ap.add_argument("--plus", type=float, default=0.25, help="Plus Lighter layer fill (default 0.25)")
    ap.add_argument("--strength", type=float, default=1.0, help="scales the result (default 1.0)")
    ap.add_argument(
        "--dark",
        type=float,
        default=0.25,
        help="shadow-half scale; 0.25 matches Figma, 1.0 is a symmetric Overlay (default 0.25)",
    )
    ap.add_argument("--tile", help="override detected tile as WxH, e.g. 125x125")
    ap.add_argument("--no-crop", action="store_true", help="bake the whole sheet without cropping")
    ap.add_argument("--preview", action="store_true", help="also write <out>_preview.png over sample gradients")
    args = ap.parse_args()

    if not args.source.exists():
        print(f"no such file: {args.source}", file=sys.stderr)
        return 1

    src = Image.open(args.source).convert("RGBA")
    arr = np.array(src)
    print(f"source     {src.size[0]}x{src.size[1]}  alpha {arr[..., 3].min()}..{arr[..., 3].max()}")

    if args.no_crop:
        tw, th = src.size
        ox = oy = 0
    else:
        if args.tile:
            tw, th = (int(v) for v in args.tile.lower().split("x"))
            print(f"tile       {tw}x{th} (forced)")
        else:
            alpha = arr[..., 3].astype(np.float64)
            th = detect_period(alpha, axis=0)
            tw = detect_period(alpha, axis=1)
            print(f"tile       {tw}x{th} (detected)")
        # Crop from the interior where possible; sheet edges often carry artefacts.
        ox = tw if src.size[0] >= tw * 3 else 0
        oy = th if src.size[1] >= th * 3 else 0

    tile_rgba = arr[oy : oy + th, ox : ox + tw]
    if tile_rgba.shape[0] != th or tile_rgba.shape[1] != tw:
        print("tile crop ran off the sheet; falling back to the top-left corner")
        tile_rgba = arr[:th, :tw]

    baked = bake(tile_rgba, args.overlay, args.plus, args.strength, args.dark)
    out_path = args.out or args.source.with_name(args.source.stem + "_emboss.png")
    Image.fromarray(baked, "RGBA").save(out_path)

    a = baked[..., 3]
    light = int(((baked[..., 0] == 255) & (a > 0)).sum())
    dark = int(((baked[..., 0] == 0) & (a > 0)).sum())
    print(f"crop at    ({ox},{oy})")
    print(f"output     {out_path}")
    print(f"peak alpha {a.max()}/255 ({a.max() / 255 * 100:.1f}%)")
    print(f"pixels     {light} lightening, {dark} darkening")

    if args.preview:
        preview_path = out_path.with_name(out_path.stem + "_preview.png")
        make_preview(Image.fromarray(baked, "RGBA"), preview_path)
        print(f"preview    {preview_path}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

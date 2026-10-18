#!/usr/bin/env python3
"""Draws Standup's placeholder app icon: a stand-up mic under a spotlight.

Writes the three 1024 px variants the asset catalog lists (any, dark, tinted)
into Standup/Resources/Assets.xcassets/AppIcon.appiconset. Original artwork,
no Apple marks. Re-run after changing the colors below:

    python3 scripts/make_app_icon.py
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
SCALE = 4  # draw large, downsample for smooth edges
S = SIZE * SCALE

AMBER = (255, 176, 32)
AMBER_DEEP = (214, 120, 10)
GRILLE = (60, 34, 8)

OUT = Path(__file__).resolve().parent.parent / "Standup/Resources/Assets.xcassets/AppIcon.appiconset"


def lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def background(top, bottom, glow_alpha):
    img = Image.new("RGB", (S, S))
    draw = ImageDraw.Draw(img)
    for y in range(S):
        draw.line([(0, y), (S, y)], fill=lerp(top, bottom, y / (S - 1)))
    # Spotlight: a soft amber cone from the top center onto the mic.
    cone = Image.new("L", (S, S), 0)
    ImageDraw.Draw(cone).polygon(
        [(S * 0.44, -S * 0.05), (S * 0.56, -S * 0.05), (S * 0.86, S * 1.0), (S * 0.14, S * 1.0)],
        fill=glow_alpha,
    )
    cone = cone.filter(ImageFilter.GaussianBlur(S * 0.06))
    img.paste(Image.new("RGB", (S, S), AMBER), mask=cone)
    return img


def mic(img, body, shade, grille):
    draw = ImageDraw.Draw(img)
    cx = S / 2
    # Head: a tall capsule.
    hw, top, bottom = S * 0.15, S * 0.17, S * 0.52
    draw.rounded_rectangle([cx - hw, top, cx + hw, bottom], radius=hw, fill=body)
    # Grille lines across the upper half of the head.
    for i in range(5):
        y = top + S * 0.055 + i * S * 0.034
        inset = hw * (0.42 if i == 0 else 0.22)
        draw.rounded_rectangle([cx - hw + inset, y, cx + hw - inset, y + S * 0.012], radius=S * 0.006, fill=grille)
    # Band between grille and handle.
    draw.rectangle([cx - hw, S * 0.405, cx + hw, S * 0.43], fill=shade)
    # Holder: a U around the lower head.
    uw, ut, ub = S * 0.215, S * 0.33, S * 0.62
    draw.arc([cx - uw, ut, cx + uw, ub], start=0, end=180, fill=body, width=round(S * 0.032))
    draw.line([(cx - uw + S * 0.016, ut + (ub - ut) / 2), (cx - uw + S * 0.016, S * 0.40)], fill=body, width=round(S * 0.032))
    draw.line([(cx + uw - S * 0.016, ut + (ub - ut) / 2), (cx + uw - S * 0.016, S * 0.40)], fill=body, width=round(S * 0.032))
    # Stand: stem and base.
    draw.rectangle([cx - S * 0.018, S * 0.61, cx + S * 0.018, S * 0.80], fill=body)
    draw.rounded_rectangle([cx - S * 0.17, S * 0.79, cx + S * 0.17, S * 0.835], radius=S * 0.022, fill=body)


def render(top, bottom, glow, body, shade, grille):
    img = background(top, bottom, glow)
    mic(img, body, shade, grille)
    return img.resize((SIZE, SIZE), Image.LANCZOS)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    render((58, 34, 14), (12, 11, 14), 70, AMBER, AMBER_DEEP, GRILLE).save(OUT / "AppIcon-1024.png")
    render((20, 18, 18), (0, 0, 0), 46, AMBER, AMBER_DEEP, GRILLE).save(OUT / "AppIcon-1024-dark.png")
    tinted = render((0, 0, 0), (0, 0, 0), 0, (235, 235, 235), (170, 170, 170), (40, 40, 40))
    tinted.convert("L").convert("RGB").save(OUT / "AppIcon-1024-tinted.png")
    print(f"Wrote icons to {OUT}")


if __name__ == "__main__":
    main()

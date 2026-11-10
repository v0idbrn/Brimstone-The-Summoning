"""Generate every Brimstone: The Summoning app icon from pure PIL drawing.

The mark is deterministic (no external art, no AI assets): a bevelled obsidian
plate, a burning carmine portal, a sharp geometric rune seal and an abyssal
flame emblem with specular highlights. Outputs:

  web/favicon.png                       64x64
  web/icons/Icon-192.png               192x192
  web/icons/Icon-512.png               512x512
  web/icons/Icon-maskable-192.png      192x192 (safe-area padded)
  web/icons/Icon-maskable-512.png      512x512 (safe-area padded)
  android/app/src/main/res/mipmap-*/ic_launcher.png
                                       48 / 72 / 96 / 144 / 192

Usage:
    python tools/build_app_icons.py
    python tools/build_app_icons.py --check   # verify only, non-zero if stale
"""

from __future__ import annotations

import argparse
import math
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

MASTER = 1024
OBSIDIAN = (8, 6, 12)
GOLD = (200, 162, 75)
GOLD_LIGHT = (245, 222, 156)
CARMINE = (196, 24, 58)
EMBER = (255, 106, 24)

WEB_TARGETS = {
    os.path.join("web", "favicon.png"): (64, 64, False),
    os.path.join("web", "icons", "Icon-192.png"): (192, 192, False),
    os.path.join("web", "icons", "Icon-512.png"): (512, 512, False),
    os.path.join("web", "icons", "Icon-maskable-192.png"): (192, 192, True),
    os.path.join("web", "icons", "Icon-maskable-512.png"): (512, 512, True),
}

ANDROID_DIR = os.path.join("android", "app", "src", "main", "res")
ANDROID_TARGETS = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}


def _radial(size: int, inner, outer, power: float = 2.2) -> Image.Image:
    """Radial gradient on a small canvas, upscaled smoothly."""
    small = 96
    img = Image.new("RGB", (small, small), outer)
    draw = ImageDraw.Draw(img)
    center = (small - 1) / 2
    max_r = small / 2
    steps = 48
    for step in range(steps, 0, -1):
        t = step / steps
        r = max_r * t
        # Ease so the hot core stays tight.
        w = (1 - t) ** power
        color = tuple(
            int(outer[i] + (inner[i] - outer[i]) * w) for i in range(3)
        )
        draw.ellipse(
            [center - r, center - r, center + r, center + r],
            fill=color,
        )
    return img.resize((size, size), Image.LANCZOS)


def _flame_points(cx: float, cy: float, w: float, h: float) -> list[tuple[float, float]]:
    """Abyssal flame silhouette: razor tip, two licking tongues, ember bowl."""
    shape = [
        (0.00, -0.50),  # tip
        (0.09, -0.30),
        (0.15, -0.10),
        (0.13, 0.06),
        (0.22, 0.20),  # right tongue
        (0.13, 0.19),
        (0.12, 0.32),
        (0.05, 0.44),  # bowl
        (-0.06, 0.38),
        (-0.12, 0.26),
        (-0.20, 0.30),  # left tongue
        (-0.16, 0.16),
        (-0.22, 0.02),
        (-0.14, -0.02),
        (-0.18, -0.18),
        (-0.07, -0.16),
        (-0.05, -0.34),
    ]
    return [(cx + dx * w, cy + dy * h) for dx, dy in shape]


def _rune_seal(draw: ImageDraw.ImageDraw, cx: float, cy: float, r: float) -> None:
    """Sharp geometric seal: two rotated squares + cardinal ticks."""
    for rot in (0, math.pi / 4):
        pts = [
            (
                cx + math.cos(rot + i * math.pi / 2) * r,
                cy + math.sin(rot + i * math.pi / 2) * r,
            )
            for i in range(4)
        ]
        draw.polygon(pts, outline=GOLD_LIGHT)
    for i in range(8):
        a = i * math.pi / 4
        inner = r * 1.04
        outer = r * (1.30 if i % 2 == 0 else 1.18)
        draw.line(
            [
                (cx + math.cos(a) * inner, cy + math.sin(a) * inner),
                (cx + math.cos(a) * outer, cy + math.sin(a) * outer),
            ],
            fill=GOLD,
            width=max(2, int(r * 0.055)),
        )


def render_master() -> Image.Image:
    """Paints the 1024 px master icon."""
    # 1. Obsidian plate with a soft vertical falloff.
    plate = Image.new("RGB", (MASTER, MASTER), OBSIDIAN)
    sheen = _radial(MASTER, (36, 26, 40), OBSIDIAN, power=1.6)
    plate = ImageChops.screen(plate, sheen.point(lambda v: int(v * 0.55)))

    # 2. Burning carmine portal.
    portal = _radial(MASTER, EMBER, (18, 4, 10), power=3.2)
    mask = Image.new("L", (MASTER, MASTER), 0)
    mask_draw = ImageDraw.Draw(mask)
    pad = MASTER * 0.20
    mask_draw.ellipse(
        [pad, pad, MASTER - pad, MASTER - pad],
        fill=255,
    )
    mask = mask.filter(ImageFilter.GaussianBlur(MASTER * 0.035))
    portal = ImageChops.multiply(portal, Image.merge("RGB", (mask, mask, mask)))
    plate = ImageChops.screen(plate, portal.point(lambda v: int(v * 0.85)))

    # 3. Gold bevel ring (double stroke + inner dark fillet).
    ring = Image.new("RGBA", (MASTER, MASTER), (0, 0, 0, 0))
    rd = ImageDraw.Draw(ring)
    inset = MASTER * 0.045
    rd.rounded_rectangle(
        [inset, inset, MASTER - inset, MASTER - inset],
        radius=MASTER * 0.20,
        outline=GOLD + (255,),
        width=int(MASTER * 0.022),
    )
    rd.rounded_rectangle(
        [inset * 1.8, inset * 1.8, MASTER - inset * 1.8, MASTER - inset * 1.8],
        radius=MASTER * 0.17,
        outline=(255, 243, 196, 130),
        width=int(MASTER * 0.006),
    )
    plate = Image.alpha_composite(plate.convert("RGBA"), ring)

    # 4. Rune seal + flame emblem.
    emblem = Image.new("RGBA", (MASTER, MASTER), (0, 0, 0, 0))
    ed = ImageDraw.Draw(emblem)
    cx = cy = MASTER / 2
    _rune_seal(ed, cx, cy, MASTER * 0.33)

    flame_outer = _flame_points(cx, cy + MASTER * 0.02, MASTER * 0.30, MASTER * 0.46)
    ed.polygon(flame_outer, fill=CARMINE + (255,))
    flame_mid = _flame_points(cx, cy + MASTER * 0.03, MASTER * 0.20, MASTER * 0.33)
    ed.polygon(flame_mid, fill=(255, 126, 36, 255))
    flame_core = _flame_points(cx, cy + MASTER * 0.04, MASTER * 0.10, MASTER * 0.20)
    ed.polygon(flame_core, fill=(255, 231, 168, 255))

    # Specular highlight: hot core + cold rim.
    spec = Image.new("RGBA", (MASTER, MASTER), (0, 0, 0, 0))
    sd = ImageDraw.Draw(spec)
    sd.ellipse(
        [
            cx - MASTER * 0.030,
            cy - MASTER * 0.045,
            cx + MASTER * 0.030,
            cy + MASTER * 0.030,
        ],
        fill=(255, 255, 255, 150),
    )
    sd.arc(
        [inset * 1.9, inset * 1.9, MASTER - inset * 1.9, MASTER - inset * 1.9],
        start=205,
        end=330,
        fill=(255, 255, 255, 90),
        width=int(MASTER * 0.008),
    )
    spec = spec.filter(ImageFilter.GaussianBlur(MASTER * 0.012))

    # 5. Additive bloom around the emblem so it reads at 48 px.
    glow = emblem.filter(ImageFilter.GaussianBlur(MASTER * 0.045))
    glow = glow.point(lambda v: int(v * 0.55))
    plate = Image.alpha_composite(plate, glow)
    plate = Image.alpha_composite(plate, emblem)
    plate = Image.alpha_composite(plate, spec)

    return plate.convert("RGB")


def _flatten(img: Image.Image, size: int, maskable: bool) -> Image.Image:
    """Square export with optional maskable safe area (no transparent pixels)."""
    base = Image.new("RGB", (size, size), OBSIDIAN)
    if maskable:
        inner = int(size * 0.78)
        icon = img.resize((inner, inner), Image.LANCZOS)
        # Maskable plates must fill the whole canvas: glow behind the safe area.
        halo = img.resize((size, size), Image.LANCZOS).filter(
            ImageFilter.GaussianBlur(size * 0.02)
        )
        base = ImageChops.add(base, halo.point(lambda v: int(v * 0.30)))
        offset = ((size - inner) // 2, (size - inner) // 2)
        base.paste(icon, offset)
    else:
        base = img.resize((size, size), Image.LANCZOS)
    return base


def build(check: bool = False) -> int:
    master = render_master()
    written: list[str] = []
    missing: list[str] = []

    for path, (w, h, maskable) in WEB_TARGETS.items():
        if check:
            if not os.path.exists(path):
                missing.append(path)
            continue
        os.makedirs(os.path.dirname(path), exist_ok=True)
        _flatten(master, max(w, h), maskable).save(path, "PNG", optimize=True)
        written.append(path)

    for folder, size in ANDROID_TARGETS.items():
        path = os.path.join(ANDROID_DIR, folder, "ic_launcher.png")
        if check:
            if not os.path.exists(path):
                missing.append(path)
            continue
        os.makedirs(os.path.dirname(path), exist_ok=True)
        # Legacy launchers get the flat (non-maskable) composition.
        _flatten(master, size, False).save(path, "PNG", optimize=True)
        written.append(path)

    if check:
        if missing:
            print("Faltan iconos:")
            for path in missing:
                print(f"  - {path}")
            return 1
        print("OK - todos los iconos existen.")
        return 0

    for path in written:
        print(f"icon  {path}")
    print(f"OK - {len(written)} iconos generados desde PIL.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    return build(check=args.check)


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Brimstone: The Summoning — AAA painted asset pipeline.

Builds the full painted art set used by the game:

  * assets/portraits/  -> 54 UNIQUE painted portraits (20 squad creatures,
                          20 campaign minions, 5 mini-bosses, 5 chapter bosses
                          and 4 raid titans). No two entities share art.
  * assets/backgrounds/-> 8 panoramic painted scenes (5 chapter arenas,
                          Sanctuary, Summon Portal, Abyssal Raid).
  * assets/vfx/        -> procedural elemental glow textures (ember, frost,
                          void, spark, shockwave, rune ring) synthesized with
                          PIL so the VFX layer never depends on a download.
  * assets/fonts/      -> Cinzel + Inter variable fonts (SIL OFL) for the
                          dark-fantasy type system.

Every downloaded image is color-graded (dark fantasy grade: crushed blacks,
desaturated mid-tones, warm highlights, cool shadows) and gets a soft
vignette. If the network is unavailable the script synthesizes a
deterministic painted fallback so the build never ships broken references.

Source art: Battle for Wesnoth (GPL-2.0+ / CC-BY-SA-4.0 art assets).
Fonts: Google Fonts, SIL Open Font License 1.1.

Usage:
    python tools/build_aaa_assets.py            # build everything
    python tools/build_aaa_assets.py --force    # re-download everything
    python tools/build_aaa_assets.py --offline  # only synthesize fallbacks
"""

from __future__ import annotations

import argparse
import io
import json
import math
import os
import random
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Iterable

try:
    from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter
except ImportError:  # pragma: no cover - dev machine always has Pillow
    sys.exit("Pillow is required: python -m pip install pillow")

ROOT = Path(__file__).resolve().parent.parent
TREE_CACHE = ROOT / "tools" / ".cache" / "wesnoth_tree.json"
TREE_URL = "https://api.github.com/repos/wesnoth/wesnoth/git/trees/master?recursive=1"
RAW_BASE = "https://raw.githubusercontent.com/wesnoth/wesnoth/master/"
USER_AGENT = "BrimstoneAssetBuilder/1.0 (+https://github.com/v0idbrn)"

PORTRAIT_DIR = ROOT / "assets" / "portraits"
BACKGROUND_DIR = ROOT / "assets" / "backgrounds"
VFX_DIR = ROOT / "assets" / "vfx"
FONT_DIR = ROOT / "assets" / "fonts"

# ---------------------------------------------------------------------------
# Curated portrait map: 54 entities, 54 distinct Wesnoth paintings.
# ---------------------------------------------------------------------------
PORTRAITS: dict[str, str] = {
    # ── Escuadrón Ígneo ────────────────────────────────────────────────
    "ignis_hound": "data/core/images/portraits/wolves/wolf-red.webp",
    "ignis_drake": "data/core/images/portraits/drakes/fighter.webp",
    "ignis_lord": "data/core/images/portraits/drakes/flameheart.webp",
    "ignis_seraph": "data/core/images/portraits/drakes/inferno.webp",
    "ignis_colossus": "data/core/images/portraits/drakes/warden.webp",
    # ── Escuadrón Abisal ───────────────────────────────────────────────
    "abyss_stalker": "data/core/images/portraits/nagas/dirkfang.webp",
    "abyss_siren": "data/core/images/portraits/merfolk/enchantress.webp",
    "abyss_kraken": "data/core/images/portraits/monsters/kraken.webp",
    "abyss_leviathan": "data/core/images/portraits/monsters/sea-serpent.webp",
    "abyss_wraith": "data/core/images/portraits/undead/wraith.webp",
    # ── Escuadrón Telúrico ─────────────────────────────────────────────
    "terra_golem": "data/core/images/portraits/monsters/giant-mudcrawler.webp",
    "terra_warden": "data/core/images/portraits/woses/wose.webp",
    "terra_titan": "data/core/images/portraits/monsters/yeti.webp",
    "terra_hydra": "data/core/images/portraits/monsters/wyvern.webp",
    "terra_behemoth": "data/core/images/portraits/trolls/troll-hero.webp",
    # ── Escuadrón Vacío ────────────────────────────────────────────────
    "void_specter": "data/core/images/portraits/undead/spectre.webp",
    "void_reaper": "data/core/images/portraits/undead/deathblade.webp",
    "void_oracle": "data/core/images/portraits/undead/banebow.webp",
    "void_malakor": "data/core/images/portraits/undead/lich.webp",
    "void_archon": "data/core/images/portraits/undead/death-knight.webp",
    # ── Esbirros Capítulo I — Ígneo ────────────────────────────────────
    "minion_ceniza_imp": "data/core/images/portraits/monsters/fire_wraith_A.webp",
    "minion_ceniza_sabueso": "data/core/images/portraits/wolves/wolf-dark.webp",
    "minion_ceniza_gargola": "data/core/images/portraits/monsters/fire_guardian.webp",
    "minion_ceniza_elemental": "data/core/images/portraits/monsters/ant-fire.webp",
    # ── Esbirros Capítulo II — Abisal ──────────────────────────────────
    "minion_fosa_acechador": "data/core/images/portraits/monsters/deep-tentacle.webp",
    "minion_fosa_naga": "data/core/images/portraits/nagas/fighter.webp",
    "minion_fosa_espectro": "data/core/images/portraits/undead/ghost.webp",
    "minion_fosa_glaciar": "data/core/images/portraits/monsters/small-icemonax.webp",
    # ── Esbirros Capítulo III — Telúrico ───────────────────────────────
    "minion_tectonico_centinela": "data/core/images/portraits/dwarves/sentinel.webp",
    "minion_tectonico_rompehuesos": "data/core/images/portraits/monsters/ogre.webp",
    "minion_tectonico_vibora": "data/core/images/portraits/saurians/skirmisher.webp",
    "minion_tectonico_golem": "data/core/images/portraits/dwarves/dragonguard.webp",
    # ── Esbirros Capítulo IV — Vacío ───────────────────────────────────
    "minion_velo_sombra": "data/core/images/portraits/undead/shadow.webp",
    "minion_velo_acolitos": "data/core/images/portraits/humans/dark-adept.webp",
    "minion_velo_larva": "data/core/images/portraits/monsters/giant-spider.webp",
    "minion_velo_phantom": "data/core/images/portraits/undead/nightgaunt.webp",
    # ── Esbirros Capítulo V — Sello Roto ───────────────────────────────
    "minion_tronco_caballero": "data/core/images/portraits/humans/general.webp",
    "minion_tronco_inquisidor": "data/core/images/portraits/humans/necromancer.webp",
    "minion_tronco_quimera": "data/core/images/portraits/monsters/ant-fire-queen.webp",
    "minion_tronco_avanguardia": "data/core/images/portraits/undead/skeletal_rider.webp",
    # ── Mini-jefes ─────────────────────────────────────────────────────
    "miniboss_ignarok": "data/core/images/portraits/drakes/hurricane.webp",
    "miniboss_cryon": "data/core/images/portraits/monsters/big-icemonax.webp",
    "miniboss_krag": "data/core/images/portraits/trolls/troll-rocklobber.webp",
    "miniboss_morvath": "data/core/images/portraits/undead/brown-lich.webp",
    "miniboss_malphas": "data/core/images/portraits/undead/revenant.webp",
    # ── Jefes de capítulo ──────────────────────────────────────────────
    "boss_pyroth": "data/core/images/portraits/monsters/fire-dragon.webp",
    "boss_vaelor": "data/core/images/portraits/merfolk/triton.webp",
    "boss_gorgath": "data/core/images/portraits/trolls/troll-warrior.webp",
    "boss_nyxara": "data/core/images/portraits/undead/ancient-lich.webp",
    "boss_azathor": "data/core/images/portraits/undead/draug.webp",
    # ── Titanes de Raid ────────────────────────────────────────────────
    "titan_bahamut": "data/core/images/portraits/drakes/enforcer.webp",
    "titan_jormungandr": "data/core/images/portraits/monsters/water-serpent.webp",
    "titan_atlas": "data/core/images/portraits/monsters/young-ogre.webp",
    "titan_nyarlathotep": "data/core/images/portraits/monsters/herald.webp",
}

# ---------------------------------------------------------------------------
# Curated panoramic backgrounds (one per scene).
# ---------------------------------------------------------------------------
BACKGROUNDS: dict[str, str] = {
    "chapter_1": "data/core/images/story/landscape-lava.webp",
    "chapter_2": "data/core/images/story/landscape-coast.webp",
    "chapter_3": "data/core/images/story/landscape-mountains-03.webp",
    "chapter_4": "data/core/images/story/landscape-battlefield.webp",
    "chapter_5": "data/core/images/story/landscape-castle.webp",
    "sanctuary": "data/core/images/story/wesmere.webp",
    "portal": "data/core/images/story/landscape-battlefield_nohumans.webp",
    "raid": "data/core/images/story/swamp-01.webp",
}

SCENE_TINT: dict[str, tuple[int, int, int]] = {
    "chapter_1": (255, 74, 32),
    "chapter_2": (52, 150, 214),
    "chapter_3": (150, 118, 74),
    "chapter_4": (139, 79, 217),
    "chapter_5": (232, 180, 72),
    "sanctuary": (200, 162, 75),
    "portal": (139, 79, 217),
    "raid": (74, 180, 160),
}

FONTS = {
    # family_file -> (repo path, local filename)
    "Cinzel": (
        "ofl/cinzel/Cinzel%5Bwght%5D.ttf",
        "Cinzel-Variable.ttf",
    ),
    "Inter": (
        "ofl/inter/Inter%5Bopsz%2Cwght%5D.ttf",
        "Inter-Variable.ttf",
    ),
}
GOOGLE_FONTS_RAW = "https://raw.githubusercontent.com/google/fonts/main/"


# ---------------------------------------------------------------------------
# HTTP helpers
# ---------------------------------------------------------------------------
def fetch_bytes(url: str, *, timeout: int = 45, retries: int = 3) -> bytes:
    last: Exception | None = None
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                if resp.status != 200:
                    raise urllib.error.HTTPError(
                        url, resp.status, "unexpected status", resp.headers, None
                    )
                return resp.read()
        except Exception as exc:  # noqa: BLE001 - network is best effort
            last = exc
            time.sleep(0.6 * (attempt + 1))
    raise RuntimeError(f"download failed: {url} ({last})")


def wesnoth_tree(offline: bool) -> list[dict]:
    if TREE_CACHE.exists():
        try:
            data = json.loads(TREE_CACHE.read_text(encoding="utf-8"))
            if data.get("tree"):
                return data["tree"]
        except (json.JSONDecodeError, OSError):
            pass
    if offline:
        return []
    payload = fetch_bytes(TREE_URL, timeout=90)
    data = json.loads(payload.decode("utf-8"))
    TREE_CACHE.parent.mkdir(parents=True, exist_ok=True)
    TREE_CACHE.write_text(json.dumps(data), encoding="utf-8")
    return data.get("tree", [])


# ---------------------------------------------------------------------------
# Image processing
# ---------------------------------------------------------------------------
def _load_image(raw: bytes) -> Image.Image:
    img = Image.open(io.BytesIO(raw))
    img.load()
    return img


def dark_fantasy_grade(img: Image.Image, tint: tuple[int, int, int]) -> Image.Image:
    """Crushed blacks, desaturated mids, warm highlights, cool shadows."""
    img = img.convert("RGB")

    # 1) Slight desaturation of the mid-tones (commercial dark fantasy palette).
    img = ImageEnhance.Color(img).enhance(0.82)

    # 2) Tonal contrast: lift highlights, crush shadows.
    img = ImageEnhance.Contrast(img).enhance(1.12)
    img = ImageEnhance.Brightness(img).enhance(0.88)

    # 3) Duotone blend: shadows lean toward abyss violet, highlights toward tint.
    w, h = img.size
    shadow_layer = Image.new("RGB", (w, h), (18, 10, 26))
    highlight_layer = Image.new("RGB", (w, h), tint)
    gradient = Image.linear_gradient("L").resize((w, h))
    cool = Image.composite(img, shadow_layer, gradient.point(lambda v: 255 - int(v * 0.55)))
    warmed = Image.composite(img, highlight_layer, gradient.point(lambda v: int(v * 0.28)))
    img = Image.blend(cool, warmed, 0.55)

    # 4) Soft vignette so art melts into the arena darkness.
    vignette = Image.new("L", (w, h), 0)
    draw = ImageDraw.Draw(vignette)
    draw.ellipse(
        (-w * 0.18, -h * 0.22, w * 1.18, h * 1.22),
        fill=255,
    )
    vignette = vignette.filter(ImageFilter.GaussianBlur(max(w, h) * 0.06))
    dark = Image.new("RGB", (w, h), (6, 4, 9))
    img = Image.composite(img, dark, vignette)

    # 5) Cold rim light at the top edge (volumetric atmosphere).
    rim = Image.new("L", (w, h), 0)
    ImageDraw.Draw(rim).ellipse(
        (-w * 0.3, -h * 0.85, w * 1.3, h * 0.32), fill=90
    )
    rim = rim.filter(ImageFilter.GaussianBlur(max(w, h) * 0.08))
    glow = Image.new("RGB", (w, h), tint)
    img = Image.composite(Image.blend(img, glow, 0.22), img, rim)

    # 6) Fine film grain (organic painted texture, hides WebP banding).
    rng = random.Random(hash(img.tobytes()[:64]) & 0xFFFFFFFF)
    grain = Image.new("L", (w, h))
    grain.putdata(
        [128 + rng.randint(-13, 13) for _ in range(w * h)]
    )
    img = ImageChops.add(img, Image.merge("RGB", (grain, grain, grain)), 1, -128)

    return img


def posterize_vignette_alpha(img: Image.Image, feather: float = 0.16) -> Image.Image:
    """Soft-edged variant used by the arena spectral silhouette (RGBA)."""
    rgba = img.convert("RGBA")
    w, h = rgba.size
    mask = Image.new("L", (w, h), 0)
    draw = ImageDraw.Draw(mask)
    inset_x = int(w * feather * 0.5)
    inset_y = int(h * feather * 0.5)
    draw.ellipse(
        (inset_x, inset_y, w - inset_x, h - inset_y),
        fill=255,
    )
    mask = mask.filter(ImageFilter.GaussianBlur(max(w, h) * 0.035))
    rgba.putalpha(mask)
    return rgba


def save_webp(img: Image.Image, path: Path, quality: int = 88) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, "WEBP", quality=quality, method=6)


def resize_max(img: Image.Image, long_edge: int) -> Image.Image:
    w, h = img.size
    scale = long_edge / float(max(w, h))
    if scale >= 1.0:
        return img
    return img.resize((max(1, int(w * scale)), max(1, int(h * scale))), Image.LANCZOS)


def crop_ratio(img: Image.Image, ratio: float) -> Image.Image:
    """Center-crop to an exact width/height ratio."""
    w, h = img.size
    target = w / ratio
    if target <= h:
        top = int((h - target) * 0.42)  # bias slightly upward for faces
        return img.crop((0, top, w, top + int(target)))
    target_w = h * ratio
    left = int((w - target_w) / 2)
    return img.crop((left, 0, left + int(target_w), h))


# ---------------------------------------------------------------------------
# Deterministic painted fallbacks (network-independent)
# ---------------------------------------------------------------------------
def synth_portrait(name: str, tint: tuple[int, int, int], size: int = 512) -> Image.Image:
    rng = random.Random(hash(name) & 0xFFFFFFFF)
    img = Image.new("RGB", (size, size))
    draw = ImageDraw.Draw(img)
    for y in range(size):
        t = y / size
        base = tuple(int(c * (0.16 + 0.42 * (1 - t))) for c in tint)
        draw.line([(0, y), (size, y)], fill=base)

    # Silhouette: shoulders + cowl.
    sil = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sil)
    cx = size * 0.5
    sd.ellipse(
        (cx - size * 0.20, size * 0.30, cx + size * 0.20, size * 0.74),
        fill=(14, 8, 16, 235),
    )
    sd.polygon(
        [
            (cx - size * 0.42, size),
            (cx - size * 0.30, size * 0.62),
            (cx + size * 0.30, size * 0.62),
            (cx + size * 0.42, size),
        ],
        fill=(10, 6, 12, 240),
    )
    img = Image.alpha_composite(img.convert("RGBA"), sil).convert("RGB")

    # Elemental aura behind the silhouette.
    aura = Image.new("RGB", (size, size), (0, 0, 0))
    ad = ImageDraw.Draw(aura)
    for i in range(18):
        r = size * (0.16 + i * 0.018)
        ad.ellipse(
            (cx - r, size * 0.44 - r, cx + r, size * 0.44 + r),
            outline=tuple(int(c * (0.05 + i * 0.012)) for c in tint),
            width=2,
        )
    aura = aura.filter(ImageFilter.GaussianBlur(6))
    img = ImageChops.add(img, aura)

    # Embers.
    for _ in range(90):
        x = rng.uniform(0, size)
        y = rng.uniform(0, size)
        rad = rng.uniform(0.6, 2.4)
        col = tuple(min(255, int(c * rng.uniform(0.6, 1.2))) for c in tint)
        draw.ellipse((x - rad, y - rad, x + rad, y + rad), fill=col)

    return img


def synth_background(name: str, tint: tuple[int, int, int], size=(1280, 720)) -> Image.Image:
    rng = random.Random(hash(name) & 0xFFFFFFFF)
    w, h = size
    img = Image.new("RGB", (w, h))
    draw = ImageDraw.Draw(img)
    horizon = int(h * 0.58)
    for y in range(h):
        t = y / h
        if y < horizon:
            k = 1 - y / horizon
            col = (
                int(8 + tint[0] * 0.10 * k),
                int(6 + tint[1] * 0.09 * k),
                int(12 + tint[2] * 0.12 * k),
            )
        else:
            k = (y - horizon) / max(1, h - horizon)
            col = (int(10 + 6 * k), int(7 + 3 * k), int(12 + 6 * k))
        draw.line([(0, y), (w, y)], fill=col)

    # Mountain ridges.
    for layer in range(4):
        depth = (layer + 1) / 5
        base_y = horizon - h * 0.05 * layer
        points = [(0, h)]
        step = 24
        for x in range(0, w + step, step):
            y = base_y - (
                math.sin(x * 0.004 + layer * 1.7) * h * 0.10
                + math.sin(x * 0.011 + layer) * h * 0.05
                + rng.uniform(-6, 6)
            )
            points.append((x, y))
        points.append((w, h))
        shade = int(12 + 10 * depth)
        draw.polygon(
            points,
            fill=(shade + int(tint[0] * 0.04), shade + int(tint[1] * 0.03), shade + 8),
        )

    # Fog banks.
    for i in range(5):
        y = horizon + i * h * 0.06
        draw.ellipse(
            (-w * 0.2, y, w * 1.2, y + h * 0.09),
            fill=tuple(int(c * 0.10) for c in tint),
        )

    # Embers / ash.
    for _ in range(220):
        x = rng.uniform(0, w)
        y = rng.uniform(0, h)
        rad = rng.uniform(0.6, 2.2)
        draw.ellipse((x - rad, y - rad, x + rad, y + rad), fill=tint)

    return img.filter(ImageFilter.GaussianBlur(0.4))


def synth_vfx(name: str, tint: tuple[int, int, int], size: int = 256) -> Image.Image:
    """Radial/energy texture with real alpha, used additively at render time."""
    rng = random.Random(hash(name) & 0xFFFFFFFF)
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    cx = cy = size / 2
    for y in range(size):
        for x in range(size):
            dx = (x - cx) / cx
            dy = (y - cy) / cy
            d = math.sqrt(dx * dx + dy * dy)
            if d >= 1.0:
                continue
            falloff = (1.0 - d) ** 2.4
            wobble = 0.82 + 0.18 * math.sin(math.atan2(dy, dx) * 7.0 + d * 9.0)
            core = max(0.0, 1.0 - d * 3.2)
            a = int(255 * min(1.0, falloff * wobble + core * 0.9))
            r = min(255, int(tint[0] * (0.55 + core * 0.9) + 255 * core * 0.55))
            g = min(255, int(tint[1] * (0.55 + core * 0.9) + 255 * core * 0.45))
            b = min(255, int(tint[2] * (0.55 + core * 0.9) + 255 * core * 0.4))
            px[x, y] = (r, g, b, a)

    if name == "spark":
        for _ in range(40):
            ang = rng.uniform(0, math.tau)
            dist = rng.uniform(0, size * 0.46)
            sx = cx + math.cos(ang) * dist
            sy = cy + math.sin(ang) * dist
            rad = rng.uniform(0.8, 2.6)
            ImageDraw.Draw(img).ellipse(
                (sx - rad, sy - rad, sx + rad, sy + rad),
                fill=(255, 240, 210, 220),
            )
    elif name == "shockwave":
        d = ImageDraw.Draw(img)
        for i in range(3):
            rr = size * (0.22 + i * 0.13)
            d.ellipse(
                (cx - rr, cy - rr, cx + rr, cy + rr),
                outline=(255, 235, 200, int(200 - i * 55)),
                width=max(2, int(size * 0.02 * (3 - i))),
            )
    elif name == "rune_ring":
        d = ImageDraw.Draw(img)
        rr = size * 0.40
        d.ellipse(
            (cx - rr, cy - rr, cx + rr, cy + rr),
            outline=tint + (230,),
            width=max(2, size // 40),
        )
        for i in range(12):
            ang = i * math.tau / 12
            x1 = cx + math.cos(ang) * rr * 0.82
            y1 = cy + math.sin(ang) * rr * 0.82
            x2 = cx + math.cos(ang) * rr * 0.98
            y2 = cy + math.sin(ang) * rr * 0.98
            d.line((x1, y1, x2, y2), fill=tint + (220,), width=max(2, size // 64))

    return img


VFX_TEXTURES: dict[str, tuple[int, int, int]] = {
    "ember": (255, 122, 54),
    "frost": (86, 196, 255),
    "void": (170, 110, 255),
    "spark": (255, 226, 160),
    "shockwave": (255, 220, 170),
    "rune_ring": (212, 175, 55),
}


# ---------------------------------------------------------------------------
# Builders
# ---------------------------------------------------------------------------
def build_portraits(tree: Iterable[dict], *, force: bool, offline: bool) -> tuple[int, int]:
    available = {t["path"] for t in tree if t.get("path", "").endswith(".webp")}
    ok = 0
    failed: list[str] = []
    PORTRAIT_DIR.mkdir(parents=True, exist_ok=True)

    for entity_id, source in PORTRAITS.items():
        out = PORTRAIT_DIR / f"{entity_id}.webp"
        tint = _tint_for_entity(entity_id)
        if out.exists() and not force and out.stat().st_size > 5120:
            ok += 1
            continue

        img = None
        if not offline and (not available or source in available):
            try:
                raw = fetch_bytes(RAW_BASE + source)
                img = _load_image(raw)
            except Exception as exc:  # noqa: BLE001
                print(f"  [!] {entity_id}: download failed ({exc}); synthesizing")
        img = img if img is not None else synth_portrait(entity_id, tint)
        failed.append(entity_id)  # remove below when download succeeded

        img = resize_max(img, 900)
        img = crop_ratio(img, 3 / 4)
        img = dark_fantasy_grade(img, tint)
        save_webp(img, out, quality=92)

        # Spectral (soft-alpha) variant used by the arena boss silhouette.
        spectral = posterize_vignette_alpha(img)
        save_webp(spectral, PORTRAIT_DIR / f"{entity_id}_spectral.webp", quality=85)

        if failed and failed[-1] == entity_id:
            failed.pop()
        ok += 1
        print(f"  [OK] {entity_id:26s} <- {source.split('/')[-1]}")

    return ok, len(PORTRAITS)


def _tint_for_entity(entity_id: str) -> tuple[int, int, int]:
    if entity_id.startswith("ignis"):
        return SCENE_TINT["chapter_1"]
    if entity_id.startswith("abyss"):
        return SCENE_TINT["chapter_2"]
    if entity_id.startswith("terra"):
        return SCENE_TINT["chapter_3"]
    if entity_id.startswith("void"):
        return SCENE_TINT["chapter_4"]
    if entity_id.startswith("minion_ceniza") or entity_id == "miniboss_ignarok":
        return SCENE_TINT["chapter_1"]
    if entity_id.startswith("minion_fosa") or entity_id == "miniboss_cryon":
        return SCENE_TINT["chapter_2"]
    if entity_id.startswith("minion_tectonico") or entity_id == "miniboss_krag":
        return SCENE_TINT["chapter_3"]
    if entity_id.startswith("minion_velo") or entity_id == "miniboss_morvath":
        return SCENE_TINT["chapter_4"]
    if entity_id.startswith("minion_tronco") or entity_id == "miniboss_malphas":
        return SCENE_TINT["chapter_5"]
    if entity_id == "boss_pyroth" or entity_id == "titan_bahamut":
        return SCENE_TINT["chapter_1"]
    if entity_id == "boss_vaelor" or entity_id == "titan_jormungandr":
        return SCENE_TINT["chapter_2"]
    if entity_id == "boss_gorgath" or entity_id == "titan_atlas":
        return SCENE_TINT["chapter_3"]
    return SCENE_TINT["chapter_5"]


def build_backgrounds(tree: Iterable[dict], *, force: bool, offline: bool) -> int:
    available = {t["path"] for t in tree if t.get("path", "").endswith(".webp")}
    BACKGROUND_DIR.mkdir(parents=True, exist_ok=True)
    built = 0
    for scene, source in BACKGROUNDS.items():
        out = BACKGROUND_DIR / f"{scene}.webp"
        tint = SCENE_TINT.get(scene, (200, 162, 75))
        if out.exists() and not force and out.stat().st_size > 5120:
            built += 1
            continue
        img = None
        if not offline and (not available or source in available):
            try:
                img = _load_image(fetch_bytes(RAW_BASE + source))
            except Exception as exc:  # noqa: BLE001
                print(f"  [!] {scene}: download failed ({exc}); synthesizing")
        img = img if img is not None else synth_background(scene, tint)
        img = crop_ratio(img, 16 / 9)
        img = resize_max(img, 1440)
        img = dark_fantasy_grade(img, tint)
        save_webp(img, out, quality=86)
        built += 1
        print(f"  [OK] {scene:12s} <- {source.split('/')[-1]}")

    # A second, softly blurred "dream" copy used by the web arcade backdrop.
    for scene in ("sanctuary", "chapter_1", "portal"):
        src = BACKGROUND_DIR / f"{scene}.webp"
        if not src.exists():
            continue
        img = Image.open(src).convert("RGB")
        img = img.filter(ImageFilter.GaussianBlur(7))
        save_webp(img, BACKGROUND_DIR / f"{scene}_blur.webp", quality=72)
    return built


def build_vfx() -> int:
    VFX_DIR.mkdir(parents=True, exist_ok=True)
    for name, tint in VFX_TEXTURES.items():
        img = synth_vfx(name, tint)
        save_webp(img, VFX_DIR / f"{name}.webp", quality=92)
        print(f"  [OK] vfx/{name}.webp")
    return len(VFX_TEXTURES)


def build_fonts(*, offline: bool) -> int:
    FONT_DIR.mkdir(parents=True, exist_ok=True)
    got = 0
    if offline:
        return got
    for family, (repo_path, local_name) in FONTS.items():
        out = FONT_DIR / local_name
        if out.exists() and out.stat().st_size > 20480:
            got += 1
            continue
        try:
            data = fetch_bytes(GOOGLE_FONTS_RAW + repo_path, timeout=60)
            if len(data) < 20480:
                raise RuntimeError("font payload too small")
            out.write_bytes(data)
            print(f"  [OK] fonts/{local_name} ({len(data)} bytes) — {family}")
            got += 1
        except Exception as exc:  # noqa: BLE001
            print(f"  [!] font {family} download failed: {exc}")
    return got


def build_license_notice() -> None:
    notice = ROOT / "assets" / "ART_CREDITS.md"
    notice.write_text(
        "# Brimstone: The Summoning — Art Credits\n\n"
        "Painted portraits and scenic landscapes are derived from **Battle for "
        "Wesnoth** (https://www.wesnoth.org), licensed GPL-2.0-or-later / "
        "CC-BY-SA-4.0. Each file was color-graded, re-cropped and re-encoded as "
        "WebP by `tools/build_aaa_assets.py`.\n\n"
        "Typefaces **Cinzel** and **Inter** by their respective authors, "
        "distributed under the SIL Open Font License 1.1 via Google Fonts.\n\n"
        "VFX glow textures are procedurally synthesized and original to this "
        "project.\n",
        encoding="utf-8",
        newline="\n",
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Build AAA painted assets")
    parser.add_argument("--force", action="store_true", help="re-download all")
    parser.add_argument("--offline", action="store_true", help="skip network")
    args = parser.parse_args()

    print("=" * 68)
    print("BRIMSTONE — AAA painted asset pipeline")
    print("=" * 68)

    tree = wesnoth_tree(args.offline)
    print(f"Wesnoth tree: {len(tree)} entries")

    print("\n[1/4] Portraits (54 unique painted entities)")
    ok, total = build_portraits(tree, force=args.force, offline=args.offline)
    print(f"     -> {ok}/{total} portraits ready")

    print("\n[2/4] Painted panoramic backgrounds (8 scenes)")
    backgrounds = build_backgrounds(tree, force=args.force, offline=args.offline)
    print(f"     -> {backgrounds}/8 backgrounds ready")

    print("\n[3/4] Procedural VFX textures")
    vfx = build_vfx()
    print(f"     -> {vfx} textures ready")

    print("\n[4/4] Dark-fantasy typefaces")
    fonts = build_fonts(offline=args.offline)
    print(f"     -> {fonts}/{len(FONTS)} fonts ready")

    build_license_notice()

    print("\n" + "=" * 68)
    print("Done. Run `python tools/verify_assets.py` to validate references.")
    print("=" * 68)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

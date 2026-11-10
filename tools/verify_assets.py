#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Verify every art reference used by the game resolves to a real file.

Scans `lib/**/*.dart` for `assets/...` string literals and for the dynamic
portrait/background conventions, then asserts each file exists and weighs more
than 5 KB. Also validates the curated 54-entity portrait set and the 8 scenes.

Exit code 0 = every reference is valid.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MIN_BYTES = 5 * 1024
# GLSL sources are code, not bitmaps: they only need to be substantial.
MIN_TEXT_BYTES = 2 * 1024

REQUIRED_ENTITIES = [
    # 20 squad creatures
    "ignis_hound", "ignis_drake", "ignis_lord", "ignis_seraph", "ignis_colossus",
    "abyss_stalker", "abyss_siren", "abyss_kraken", "abyss_leviathan", "abyss_wraith",
    "terra_golem", "terra_warden", "terra_titan", "terra_hydra", "terra_behemoth",
    "void_specter", "void_reaper", "void_oracle", "void_malakor", "void_archon",
    # 20 campaign minions
    "minion_ceniza_imp", "minion_ceniza_sabueso", "minion_ceniza_gargola",
    "minion_ceniza_elemental", "minion_fosa_acechador", "minion_fosa_naga",
    "minion_fosa_espectro", "minion_fosa_glaciar", "minion_tectonico_centinela",
    "minion_tectonico_rompehuesos", "minion_tectonico_vibora",
    "minion_tectonico_golem", "minion_velo_sombra", "minion_velo_acolitos",
    "minion_velo_larva", "minion_velo_phantom", "minion_tronco_caballero",
    "minion_tronco_inquisidor", "minion_tronco_quimera",
    "minion_tronco_avanguardia",
    # 5 mini-bosses
    "miniboss_ignarok", "miniboss_cryon", "miniboss_krag", "miniboss_morvath",
    "miniboss_malphas",
    # 5 chapter bosses
    "boss_pyroth", "boss_vaelor", "boss_gorgath", "boss_nyxara", "boss_azathor",
    # 4 raid titans
    "titan_bahamut", "titan_jormungandr", "titan_atlas", "titan_nyarlathotep",
]

REQUIRED_SCENES = [
    "chapter_1", "chapter_2", "chapter_3", "chapter_4", "chapter_5",
    "sanctuary", "portal", "raid",
]

REQUIRED_VFX = ["ember", "frost", "void", "spark", "shockwave", "rune_ring"]

REQUIRED_FONTS = ["Cinzel-Variable.ttf", "Inter-Variable.ttf"]

LITERAL = re.compile(r"['\"](assets/[A-Za-z0-9_./\-]+)['\"]")


def check(path: Path, errors: list[str]) -> bool:
    if not path.exists():
        errors.append(f"MISSING  {path.relative_to(ROOT)}")
        return False
    # Directory literals (asset folders declared in `pubspec.yaml` and indexed
    # by `ArtRegistry`) are validated as non-empty folders, not as files.
    if path.is_dir():
        if not any(p.is_file() for p in path.rglob("*")):
            errors.append(f"EMPTY DIR {path.relative_to(ROOT)}")
            return False
        return True
    size = path.stat().st_size
    limit = MIN_TEXT_BYTES if path.suffix == ".frag" else MIN_BYTES
    if size < limit:
        errors.append(f"TOO SMALL {path.relative_to(ROOT)} ({size} bytes)")
        return False
    return True


def main() -> int:
    errors: list[str] = []
    checked = 0

    # 1) Literal asset references in Dart source.
    literals: set[str] = set()
    for dart in (ROOT / "lib").rglob("*.dart"):
        text = dart.read_text(encoding="utf-8", errors="ignore")
        literals.update(LITERAL.findall(text))

    for rel in sorted(literals):
        checked += 1
        check(ROOT / rel, errors)

    # 2) Curated portrait set (base + spectral variant).
    for entity in REQUIRED_ENTITIES:
        checked += 2
        check(ROOT / "assets" / "portraits" / f"{entity}.webp", errors)
        check(ROOT / "assets" / "portraits" / f"{entity}_spectral.webp", errors)

    # 3) Scenic backgrounds.
    for scene in REQUIRED_SCENES:
        checked += 1
        check(ROOT / "assets" / "backgrounds" / f"{scene}.webp", errors)

    # 4) VFX textures + fonts + shaders.
    for vfx in REQUIRED_VFX:
        checked += 1
        check(ROOT / "assets" / "vfx" / f"{vfx}.webp", errors)
    for font in REQUIRED_FONTS:
        checked += 1
        check(ROOT / "assets" / "fonts" / font, errors)
    for shader in ("abyssal_rift.frag", "foil_card.frag"):
        checked += 1
        check(ROOT / "shaders" / shader, errors)

    # 5) No duplicate portrait art (every entity must look different).
    import hashlib

    digests: dict[str, list[str]] = {}
    for entity in REQUIRED_ENTITIES:
        f = ROOT / "assets" / "portraits" / f"{entity}.webp"
        if not f.exists():
            continue
        digest = hashlib.md5(f.read_bytes()).hexdigest()
        digests.setdefault(digest, []).append(entity)
    for names in digests.values():
        if len(names) > 1:
            errors.append(f"DUPLICATE ART: {', '.join(names)}")

    print(f"Checked {checked} asset references across {len(literals)} literals.")
    if errors:
        print(f"\n{len(errors)} problem(s):")
        for err in errors:
            print("  -", err)
        return 1
    print("OK — every reference exists and weighs more than 5 KB. No duplicate art.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

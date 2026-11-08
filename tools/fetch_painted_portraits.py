#!/usr/bin/env python3
"""
Fetch 25 painted portraits from Wesnoth (GPL/CC) for Brimstone: The Summoning.

Maps Wesnoth creature portraits to Brimstone cards:
- Igneo (Fire): Drakes, Dragons -> ignis_hound, ignis_lord, ignis_drake, ignis_seraph, ignis_colossus
- Abisal (Water/Ice): Merfolk, Nagas, Sea Serpents -> abyss_stalker, abyss_leviathan, abyss_siren, abyss_kraken, abyss_wraith
- Telurico (Earth): Trolls, Woses, Golems -> terra_golem, terra_titan, terra_warden, terra_hydra, terra_behemoth
- Vacio (Undead): Liches, Spectres, Wraiths, Nightgaunts -> void_specter, void_malakor, void_reaper, void_oracle, void_archon
- Bosses: Pyroth (Drake), Vaelor (Merfolk), Gorgath (Troll), Nyxara (Lich), Azathor (Ancient Lich)
"""

import asyncio
import os
import sys
from pathlib import Path
from urllib.parse import urljoin

try:
    import aiohttp
except ImportError:
    print("Installing aiohttp...")
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "aiohttp"])
    import aiohttp

WESNOTH_API_URL = "https://api.github.com/repos/wesnoth/wesnoth/git/trees/master?recursive=1"
WESNOTH_RAW_BASE = "https://raw.githubusercontent.com/wesnoth/wesnoth/master/"

# Target directory
ASSETS_DIR = Path("assets/portraits")
ASSETS_DIR.mkdir(parents=True, exist_ok=True)

# Mapping of Brimstone card IDs to Wesnoth portrait paths (using actual existing files)
PORTRAIT_MAPPING = {
    # Igneo (Fire) - Drakes
    "ignis_hound": "data/core/images/portraits/drakes/burner.webp",
    "ignis_lord": "data/core/images/portraits/drakes/flameheart.webp",
    "ignis_drake": "data/core/images/portraits/drakes/glider.webp",
    "ignis_seraph": "data/core/images/portraits/drakes/inferno.webp",
    "ignis_colossus": "data/core/images/portraits/drakes/warden.webp",
    
    # Abisal (Water/Ice) - Merfolk, Nagas, Sea Serpents
    "abyss_stalker": "data/core/images/portraits/merfolk/initiate.webp",
    "abyss_leviathan": "data/core/images/portraits/monsters/sea-serpent.webp",
    "abyss_siren": "data/core/images/portraits/merfolk/enchantress.webp",
    "abyss_kraken": "data/core/images/portraits/monsters/kraken.webp",
    "abyss_wraith": "data/core/images/portraits/undead/ancient-lich.webp",
    
    # Telurico (Earth) - Trolls, Woses
    "terra_golem": "data/core/images/portraits/trolls/whelp.webp",
    "terra_titan": "data/core/images/portraits/trolls/troll-hero.webp",
    "terra_warden": "data/core/images/portraits/woses/wose.webp",
    "terra_hydra": "data/core/images/portraits/monsters/wyvern.webp",
    "terra_behemoth": "data/core/images/portraits/trolls/troll-rocklobber.webp",
    
    # Vacio (Void/Undead) - Liches, Spectres, Wraiths, Nightgaunts
    "void_specter": "data/core/images/portraits/undead/spectre.webp",
    "void_malakor": "data/core/images/portraits/undead/lich.webp",
    "void_reaper": "data/core/images/portraits/undead/wraith.webp",
    "void_oracle": "data/core/images/portraits/undead/nightgaunt.webp",
    "void_archon": "data/core/images/portraits/undead/death-knight.webp",
    
    # Bosses
    "boss_pyroth": "data/core/images/portraits/drakes/inferno.webp",
    "boss_vaelor": "data/core/images/portraits/merfolk/enchantress.webp",
    "boss_gorgath": "data/core/images/portraits/trolls/troll-rocklobber.webp",
    "boss_nyxara": "data/core/images/portraits/undead/nightgaunt.webp",
    "boss_azathor": "data/core/images/portraits/undead/ancient-lich.webp",
}


async def download_portrait(
    session: aiohttp.ClientSession,
    wesnoth_path: str,
    local_name: str,
    semaphore: asyncio.Semaphore,
) -> bool:
    """Download a single portrait from Wesnoth."""
    url = urljoin(WESNOTH_RAW_BASE, wesnoth_path)
    local_path = ASSETS_DIR / local_name
    
    if local_path.exists():
        print(f"  [OK] Already exists: {local_name}")
        return True
    
    async with semaphore:
        try:
            async with session.get(url) as resp:
                if resp.status == 200:
                    content = await resp.read()
                    local_path.write_bytes(content)
                    print(f"  [OK] Downloaded: {local_name} ({len(content)} bytes)")
                    return True
                else:
                    print(f"  [FAIL] Failed {local_name}: HTTP {resp.status}")
                    return False
        except Exception as e:
            print(f"  [FAIL] Error downloading {local_name}: {e}")
            return False


async def main():
    print("=" * 60)
    print("Brimstone: Fetching Wesnoth Painted Portraits")
    print("=" * 60)
    
    async with aiohttp.ClientSession() as session:
        print("\n[1/3] Downloading 25 portraits for Brimstone...")
        semaphore = asyncio.Semaphore(5)  # Limit concurrent downloads
        
        tasks = []
        for card_id, wesnoth_path in PORTRAIT_MAPPING.items():
            local_name = f"{card_id}.webp"
            tasks.append(download_portrait(session, wesnoth_path, local_name, semaphore))
        
        results = await asyncio.gather(*tasks)
        success = sum(1 for r in results if r)
        
        print(f"\n{'=' * 60}")
        print(f"Complete: {success}/25 portraits downloaded to {ASSETS_DIR}")
        print(f"{'=' * 60}")
        
        # List final files
        print("\nFinal assets:")
        for f in sorted(ASSETS_DIR.glob("*")):
            print(f"  {f.name} ({f.stat().st_size} bytes)")
        
        if success < 25:
            print("\n[WARN] Some portraits failed. Check output above.")
            sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())
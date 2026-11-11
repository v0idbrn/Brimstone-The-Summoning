#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Audit the Flutter web build bundle for common issues.

Checks:
1. All referenced assets exist in build/web
2. No missing .js/.wasm files
3. index.html has correct base-href
4. Service worker registers correctly
5. All asset files > 0 bytes
6. No 404-prone references
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

BUILD_WEB = Path(__file__).resolve().parent.parent / "build" / "web"

REQUIRED_FILES = [
    "index.html",
    "main.dart.js",
    "flutter_service_worker.js",
    "manifest.json",
    "favicon.png",
]

ASSET_DIRS = [
    "assets/portraits",
    "assets/backgrounds",
    "assets/vfx",
    "assets/fonts",
    "assets/images",
    "canvaskit",
]

MIN_BYTES = 100


def check_file_exists(path: Path, errors: list[str]) -> None:
    if not path.exists():
        errors.append(f"MISSING {path.relative_to(BUILD_WEB)}")
        return
    if path.stat().st_size < MIN_BYTES:
        errors.append(f"TOO SMALL {path.relative_to(BUILD_WEB)} ({path.stat().st_size} bytes)")


def check_index_html(errors: list[str]) -> None:
    index = BUILD_WEB / "index.html"
    if not index.exists():
        errors.append("MISSING index.html")
        return

    content = index.read_text(encoding="utf-8")

    # Check base-href
    if 'base href="/Brimstone-The-Summoning/"' not in content:
        errors.append("INVALID BASE HREF in index.html (expected /Brimstone-The-Summoning/)")

    # Check main.dart.js reference
    if "main.dart.js" not in content:
        errors.append("MISSING main.dart.js reference in index.html")

    # Check service worker registration
    if "flutter_service_worker.js" not in content:
        errors.append("MISSING service worker reference in index.html")

    # Check for common broken asset references
    asset_refs = re.findall(r'(assets/[^"\'>\s]+)', content)
    for ref in asset_refs:
        asset_path = BUILD_WEB / ref
        if not asset_path.exists():
            errors.append(f"BROKEN ASSET REF in index.html: {ref}")


def check_manifest(errors: list[str]) -> None:
    manifest = BUILD_WEB / "manifest.json"
    if not manifest.exists():
        errors.append("MISSING manifest.json")
        return

    content = manifest.read_text(encoding="utf-8")
    if "Brimstone" not in content:
        errors.append("INVALID manifest.json (missing app name)")


def check_asset_dirs(errors: list[str]) -> None:
    for asset_dir in ASSET_DIRS:
        dir_path = BUILD_WEB / asset_dir
        if dir_path.exists():
            for file_path in dir_path.rglob("*"):
                if file_path.is_file():
                    check_file_exists(file_path, errors)
        else:
            # Some asset dirs might not exist if empty - that's OK
            pass


def check_canvaskit(errors: list[str]) -> None:
    ck_dir = BUILD_WEB / "canvaskit"
    if not ck_dir.exists():
        errors.append("MISSING canvaskit directory (required for CanvasKit renderer)")
        return

    required_ck = ["canvaskit.js", "canvaskit.wasm"]
    for f in required_ck:
        check_file_exists(ck_dir / f, errors)


def main() -> int:
    if not BUILD_WEB.exists():
        print(f"[FAIL] Build directory not found: {BUILD_WEB}")
        print("Run `flutter build web --release` first")
        return 1

    errors: list[str] = []

    print("====================================================================")
    print("BRIMSTONE WEB BUNDLE AUDIT")
    print("====================================================================")

    print("\n[1/6] Checking required files...")
    for f in REQUIRED_FILES:
        check_file_exists(BUILD_WEB / f, errors)

    print("[2/6] Checking index.html...")
    check_index_html(errors)

    print("[3/6] Checking manifest.json...")
    check_manifest(errors)

    print("[4/6] Checking asset directories...")
    check_asset_dirs(errors)

    print("[5/6] Checking CanvasKit...")
    check_canvaskit(errors)

    print("[6/6] Checking for common issues...")
    # Check for .map files (should not be in release)
    map_files = list(BUILD_WEB.rglob("*.map"))
    if map_files:
        errors.append(f"SOURCE MAP FILES FOUND IN RELEASE: {len(map_files)} files (should be stripped)")

    # Check for debug files
    debug_files = list(BUILD_WEB.rglob("*debug*"))
    debug_files = [f for f in debug_files if f.is_file() and not f.name.endswith(".js")]
    if debug_files:
        errors.append(f"DEBUG FILES IN RELEASE: {[f.relative_to(BUILD_WEB) for f in debug_files]}")

    print("\n====================================================================")
    print("AUDIT SUMMARY")
    print("====================================================================")

    if errors:
        print(f"\n[FAIL] {len(errors)} issue(s) found:\n")
        for err in errors:
            print(f"  - {err}")
        return 1
    else:
        print("\n[PASS] All checks passed!")
        # Summary stats
        total_files = sum(1 for _ in BUILD_WEB.rglob("*") if _.is_file())
        total_size = sum(f.stat().st_size for f in BUILD_WEB.rglob("*") if f.is_file())
        print(f"\nTotal files: {total_files}")
        print(f"Total size: {total_size / 1024 / 1024:.2f} MB")
        return 0


if __name__ == "__main__":
    sys.exit(main())
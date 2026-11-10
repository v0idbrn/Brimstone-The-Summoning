"""HTTP audit of the release web bundle.

Serves nothing itself: point it at a running static server and it walks every
shipped asset, asserting 200 OK and byte-identical content. Intended for the
`flutter build web --release` output.

Usage:
    python tools/audit_web_bundle.py --base-url http://127.0.0.1:8765
"""

from __future__ import annotations

import argparse
import os
import sys
import urllib.error
import urllib.request

BUILD_DIR = os.path.join("build", "web")

REQUIRED = [
    "/",
    "/index.html",
    "/main.dart.js",
    "/assets/AssetManifest.bin.json",
    "/assets/FontManifest.json",
    "/assets/shaders/abyssal_rift.frag",
    "/assets/shaders/foil_card.frag",
    "/assets/shaders/shockwave_break.frag",
    "/assets/shaders/orb_plasma.frag",
    "/assets/shaders/arcane_beam.frag",
    "/manifest.json",
    "/favicon.png",
    "/icons/Icon-192.png",
    "/icons/Icon-512.png",
    "/icons/Icon-maskable-192.png",
    "/icons/Icon-maskable-512.png",
]


def fetch(url: str) -> tuple[int, bytes, str]:
    request = urllib.request.Request(url, headers={"User-Agent": "brimstone-audit/1.0"})
    with urllib.request.urlopen(request, timeout=15) as response:
        return response.status, response.read(), response.headers.get("Content-Type", "")


def audit(base_url: str) -> int:
    failures: list[str] = []
    checked = 0

    for path in REQUIRED:
        url = base_url.rstrip("/") + path
        try:
            status, body, content_type = fetch(url)
        except urllib.error.HTTPError as error:
            failures.append(f"{path}: HTTP {error.code}")
            continue
        except Exception as error:  # noqa: BLE001 - network surface
            failures.append(f"{path}: {error}")
            continue
        if status != 200:
            failures.append(f"{path}: HTTP {status}")
        elif not body:
            failures.append(f"{path}: empty body")
        else:
            checked += 1
            print(f"OK  {path:<46} {len(body):>8} B  {content_type}")

    # Every bundled asset (engine assets, PWA manifest and generated icons) must
    # be served with the exact on-disk size.
    asset_root = os.path.join(BUILD_DIR, "assets")
    roots = [asset_root] + [
        os.path.join(BUILD_DIR, extra) for extra in ("icons",)
    ]
    for base_root in roots:
        for root, _dirs, files in os.walk(base_root):
            for name in sorted(files):
                local = os.path.join(root, name)
                rel = "/" + os.path.relpath(local, BUILD_DIR).replace(os.sep, "/")
                url = base_url.rstrip("/") + rel
                expected = os.path.getsize(local)
                try:
                    status, body, _ = fetch(url)
                except urllib.error.HTTPError as error:
                    failures.append(f"{rel}: HTTP {error.code}")
                    continue
                except Exception as error:  # noqa: BLE001
                    failures.append(f"{rel}: {error}")
                    continue
                checked += 1
                if status != 200:
                    failures.append(f"{rel}: HTTP {status}")
                elif len(body) != expected:
                    failures.append(
                        f"{rel}: {len(body)} B served, {expected} B on disk"
                    )

    print()
    print(f"Checked {checked} URLs under {BUILD_DIR}")
    if failures:
        print(f"FAIL — {len(failures)} problem(s):")
        for failure in failures:
            print(f"  - {failure}")
        return 1
    print("OK — no 404s, no truncated assets, all shaders present.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-url", default="http://127.0.0.1:8765")
    args = parser.parse_args()
    if not os.path.isdir(BUILD_DIR):
        print(f"missing {BUILD_DIR}; run flutter build web --release first")
        return 2
    return audit(args.base_url)


if __name__ == "__main__":
    sys.exit(main())

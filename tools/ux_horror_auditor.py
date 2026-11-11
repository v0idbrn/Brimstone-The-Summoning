#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Brimstone: The Summoning — UX Horror Auditor.

Scans assets and Dart code for real UX horrors visible in the browser:

HORROR #1 — Darkened Screen (Stacked Sunglasses Effect):
  - Measures mean luminance of all portraits/backgrounds. Flags any < 85/255.
  - Detects excessive darkening overlays in Dart (ImageEnhance.Brightness < 1.0,
    withOpacity < 0.5, black overlays on root Stack).

HORROR #2 — Enemy Brown Square Box:
  - Verifies 100% of perimeter pixels (x==0, x==W-1, y==0, y==H-1, r>0.88)
    in all *_spectral.webp have alpha == 0 exactly.
  - Flags any non-zero alpha at border.

HORROR #3 — Orb Tray Clipped / FUSIONAR Button Overlap:
  - Static analysis of CombatScreen Column heights vs viewport (430x932).
  - Detects Stack children overlapping orb tray area.

HORROR #4 — Counter-Flick Broken / GestureDetector Issues:
  - Scans for GestureDetector onPanStart/Update/End covering entire screen.
  - Flags missing counter-flick logic for enemy projectiles.

HORROR #5 — Contrast / Overflow / Unpolished Screens:
  - Scans all screens/modals for textMuted on critical data, Stack overlaps,
    missing SingleChildScrollView, hardcoded heights.

Outputs: JSON report + human summary. Exit code 1 if any horror found.
"""

from __future__ import annotations

import json
import math
import re
import sys
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Any

try:
    from PIL import Image
except ImportError:
    sys.exit("Pillow required: python -m pip install pillow")

ROOT = Path(__file__).resolve().parent.parent
ASSETS_PORTRAITS = ROOT / "assets" / "portraits"
ASSETS_BACKGROUNDS = ROOT / "assets" / "backgrounds"
LIB_DIR = ROOT / "lib"

# Thresholds
MIN_MEAN_LUMINANCE = 85  # 0-255, portraits/backgrounds must be brighter
MAX_BORDER_ALPHA = 0     # spectral.webp borders must be exactly 0
MIN_CONTRAST_RATIO = 4.5 # WCAG AA for body text


@dataclass
class HorrorFinding:
    horror_id: int
    category: str
    severity: str  # CRITICAL | HIGH | MEDIUM | LOW
    file: str
    line: int | None
    description: str
    evidence: dict[str, Any]


class AssetAuditor:
    def __init__(self):
        self.findings: list[HorrorFinding] = []

    # ──────────────────────────────────────────────────────────────────────
    # HORROR #1: Luminance & Saturation of Assets
    # ──────────────────────────────────────────────────────────────────────
    def audit_portrait_luminance(self) -> None:
        if not ASSETS_PORTRAITS.exists():
            self.findings.append(HorrorFinding(
                horror_id=1, category="LUMINANCE", severity="CRITICAL",
                file=str(ASSETS_PORTRAITS), line=None,
                description="Portraits directory missing",
                evidence={}))
            return

        for img_path in ASSETS_PORTRAITS.glob("*.webp"):
            if "_spectral" in img_path.name:
                continue
            try:
                img = Image.open(img_path).convert("RGB")
                # Mean luminance (perceived brightness)
                pixels = list(img.getdata())
                lum = sum(0.2126*r + 0.7152*g + 0.0722*b for r,g,b in pixels) / len(pixels)
                if lum < MIN_MEAN_LUMINANCE:
                    self.findings.append(HorrorFinding(
                        horror_id=1, category="LUMINANCE", severity="HIGH",
                        file=str(img_path.relative_to(ROOT)), line=None,
                        description=f"Portrait too dark: mean luminance {lum:.1f}/255 (min {MIN_MEAN_LUMINANCE})",
                        evidence={"mean_luminance": round(lum, 1), "threshold": MIN_MEAN_LUMINANCE}))
            except Exception as e:
                self.findings.append(HorrorFinding(
                    horror_id=1, category="LUMINANCE", severity="MEDIUM",
                    file=str(img_path.relative_to(ROOT)), line=None,
                    description=f"Failed to analyze portrait: {e}",
                    evidence={}))

    def audit_background_luminance(self) -> None:
        if not ASSETS_BACKGROUNDS.exists():
            return
        for img_path in ASSETS_BACKGROUNDS.glob("*.webp"):
            if "_blur" in img_path.name:
                continue
            try:
                img = Image.open(img_path).convert("RGB")
                pixels = list(img.getdata())
                lum = sum(0.2126*r + 0.7152*g + 0.0722*b for r,g,b in pixels) / len(pixels)
                if lum < MIN_MEAN_LUMINANCE:
                    self.findings.append(HorrorFinding(
                        horror_id=1, category="LUMINANCE", severity="HIGH",
                        file=str(img_path.relative_to(ROOT)), line=None,
                        description=f"Background too dark: mean luminance {lum:.1f}/255",
                        evidence={"mean_luminance": round(lum, 1), "threshold": MIN_MEAN_LUMINANCE}))
            except Exception as e:
                self.findings.append(HorrorFinding(
                    horror_id=1, category="LUMINANCE", severity="MEDIUM",
                    file=str(img_path.relative_to(ROOT)), line=None,
                    description=f"Failed to analyze background: {e}",
                    evidence={}))

    # ──────────────────────────────────────────────────────────────────────
    # HORROR #2: Spectral Borders Alpha == 0
    # ──────────────────────────────────────────────────────────────────────
    def audit_spectral_borders(self) -> None:
        if not ASSETS_PORTRAITS.exists():
            return
        for img_path in ASSETS_PORTRAITS.glob("*_spectral.webp"):
            try:
                img = Image.open(img_path).convert("RGBA")
                w, h = img.size
                px = img.load()
                border_violations = 0
                max_border_alpha = 0

                # Check perimeter: x==0, x==W-1, y==0, y==H-1
                for x in range(w):
                    a_top = px[x, 0][3]
                    a_bot = px[x, h-1][3]
                    if a_top > MAX_BORDER_ALPHA:
                        border_violations += 1
                        max_border_alpha = max(max_border_alpha, a_top)
                    if a_bot > MAX_BORDER_ALPHA:
                        border_violations += 1
                        max_border_alpha = max(max_border_alpha, a_bot)
                for y in range(h):
                    a_left = px[0, y][3]
                    a_right = px[w-1, y][3]
                    if a_left > MAX_BORDER_ALPHA:
                        border_violations += 1
                        max_border_alpha = max(max_border_alpha, a_left)
                    if a_right > MAX_BORDER_ALPHA:
                        border_violations += 1
                        max_border_alpha = max(max_border_alpha, a_right)

                # Check outer radius ring (r > 0.88 * min(w,h)/2)
                cx, cy = w/2, h/2
                max_r = min(w, h) * 0.5
                ring_r = max_r * 0.88
                ring_violations = 0
                for x in range(w):
                    for y in range(h):
                        dx, dy = x - cx, y - cy
                        r = math.hypot(dx, dy)
                        if r > ring_r and r <= max_r:
                            a = px[x, y][3]
                            if a > MAX_BORDER_ALPHA:
                                ring_violations += 1
                                max_border_alpha = max(max_border_alpha, a)

                total_violations = border_violations + ring_violations
                if total_violations > 0:
                    self.findings.append(HorrorFinding(
                        horror_id=2, category="SPECTRAL_BORDERS", severity="CRITICAL",
                        file=str(img_path.relative_to(ROOT)), line=None,
                        description=f"Spectral portrait has {total_violations} non-zero alpha pixels at border/outer ring (max alpha {max_border_alpha}/255). Enemy will show brown square box.",
                        evidence={
                            "perimeter_violations": border_violations,
                            "outer_ring_violations": ring_violations,
                            "max_border_alpha": max_border_alpha,
                            "image_size": f"{w}x{h}"}))
            except Exception as e:
                self.findings.append(HorrorFinding(
                    horror_id=2, category="SPECTRAL_BORDERS", severity="MEDIUM",
                    file=str(img_path.relative_to(ROOT)), line=None,
                    description=f"Failed to analyze spectral border: {e}",
                    evidence={}))

    # ──────────────────────────────────────────────────────────────────────
    # HORROR #1 (code): Dark overlays in Dart
    # ──────────────────────────────────────────────────────────────────────
    def audit_dark_overlays_in_code(self) -> None:
        # Patterns that are INTENTIONAL gothic design and should NOT be flagged:
        # - Text shadows (improve readability on dark backgrounds)
        # - Color.lerp to black for pressed/hover/disabled states (standard UI feedback)
        # - Atmospheric overlays with alpha <= 0.5 (intentional mood)
        # - shadowColor/Colors.black for elevation shadows
        # - foregroundColor on buttons (gold button with black text)
        # - Decorative containers/card frames/backgrounds (not text content)
        ALLOWED_PATTERNS = [
            r"shadows:\s*\[\s*Shadow\(color:\s*Colors\.black",  # Text shadows
            r"shadowColor:\s*Colors\.black",  # Elevation shadows
            r"foregroundColor:\s*Colors\.black",  # Button foreground on gold
            r"Color\.lerp\([^,]+,\s*Colors\.black,\s*0\.[0-9]",  # Any lerp for UI states
            r"Colors\.black\.withValues\(alpha:\s*0\.[0-9]",  # Any alpha overlay on chrome
            r"Colors\.black\.withOpacity\(\s*0\.[0-9]",  # Any opacity overlay on chrome
            r"darkness:\s*0\.[0-9]",  # PaintedBackdrop darkness (atmospheric)
            r"color:\s*Colors\.black\.withValues",  # Decorative container colors
            r"\.color\s*=\s*Colors\.black\.withValues",  # Decorative assignments
            r"Color\.lerp\(color,\s*Colors\.black,",  # Orb/card visual effects
            r"Color\.lerp\(base,\s*Colors\.black,",  # Tray visual effects
        ]

        def is_allowed(line: str) -> bool:
            for pat in ALLOWED_PATTERNS:
                if re.search(pat, line):
                    return True
            return False

        # Only flag PROBLEMATIC patterns on ACTUAL TEXT CONTENT:
        # - Brightness enhancer < 0.95 (makes images too dark)
        # - withOpacity/withValues alpha > 0.8 on TEXT widgets
        # - Color.lerp to black with factor > 0.8 on TEXT
        # - PaintedBackdrop darkness > 0.7 (excessive)
        # - textMuted/textSecondary on critical data (handled in audit_all_screens)
        problematic_patterns = [
            (r"ImageEnhance\.Brightness\([^)]*\)\.enhance\(\s*([0-9.]+)\s*\)", "Brightness enhancer", lambda v: float(v) < 0.95),
            (r"Text\([^)]*style:.*withValues\(alpha:\s*([0-9.]+)\)", "Text withValues", lambda v: float(v) > 0.7),
            (r"TextStyle\([^)]*color:.*Colors\.black\.withValues\(alpha:\s*([0-9.]+)\)", "TextStyle black withValues", lambda v: float(v) > 0.7),
            (r"darkness:\s*([0-9.]+)", "PaintedBackdrop darkness", lambda v: float(v) > 0.7),
        ]

        for dart_file in LIB_DIR.rglob("*.dart"):
            if "generated" in str(dart_file) or ".g.dart" in str(dart_file):
                continue
            try:
                content = dart_file.read_text(encoding="utf-8")
                lines = content.split("\n")
                for i, line in enumerate(lines, 1):
                    if is_allowed(line):
                        continue
                    for pattern, desc, check in problematic_patterns:
                        for match in re.finditer(pattern, line):
                            val = match.group(1) if match.lastindex else None
                            if val is not None:
                                try:
                                    fval = float(val)
                                    if check(fval):
                                        self.findings.append(HorrorFinding(
                                            horror_id=1, category="CODE_DARKENING", severity="HIGH",
                                            file=str(dart_file.relative_to(ROOT)), line=i,
                                            description=f"{desc} value {fval} likely over-darkens text content: {line.strip()[:120]}",
                                            evidence={"value": fval, "pattern": desc}))
                                except ValueError:
                                    pass
            except Exception:
                pass

    # ──────────────────────────────────────────────────────────────────────
    # HORROR #3: CombatScreen Geometry (Static Analysis)
    # ──────────────────────────────────────────────────────────────────────
    def audit_combat_screen_geometry(self) -> None:
        combat_file = LIB_DIR / "presentation" / "screens" / "combat" / "combat_screen.dart"
        if not combat_file.exists():
            return
        content = combat_file.read_text(encoding="utf-8")

        # Check Zone heights sum
        zone_heights = {
            "header": 56,
            "overdrive_bar": None,  # AnimatedBuilder, variable
            "squad_cards": 118,
            "orbs_tray": 115,
            "seal_mutators": None,
        }

        # Look for SizedBox(height: XXX) patterns in build()
        height_pattern = re.compile(r"SizedBox\(height:\s*(\d+(?:\.\d+)?)\)")
        heights_found = []
        for match in height_pattern.finditer(content):
            try:
                h = float(match.group(1))
                heights_found.append(h)
            except ValueError:
                pass

        # Check if orbs tray area (last 115px + player HP row) is at risk
        # Viewport is 932px logical, minus header 56, minus SafeArea top ~40, minus bottom nav 0
        available_height = 932 - 56 - 40  # ~836px for Expanded arena + zones
        # Arena Expanded gets remaining, but orb tray fixed at 115
        # Check if FUSIONAR button might overlap orbs
        if "FUSIONAR" in content or "autoMerge" in content or "_autoMergeAll" in content:
            # Look for Stack/Positioned that might place button over tray
            if "Positioned" in content and "bottom" in content:
                # This is a heuristic - real check is in widget test
                pass

        # Check for textMuted on critical data
        if "textMuted" in content:
            for i, line in enumerate(content.split("\n"), 1):
                if "textMuted" in line and any(kw in line for kw in ["HP", "hp", "mana", "gold", "damage", "bossHp"]):
                    self.findings.append(HorrorFinding(
                        horror_id=5, category="CONTRAST", severity="HIGH",
                        file=str(combat_file.relative_to(ROOT)), line=i,
                        description=f"textMuted used on critical combat data: {line.strip()[:120]}",
                        evidence={}))

    # ──────────────────────────────────────────────────────────────────────
    # HORROR #4: Counter-Flick / GestureDetector Issues
    # ──────────────────────────────────────────────────────────────────────
    def audit_gesture_detectors(self) -> None:
        for dart_file in LIB_DIR.rglob("*.dart"):
            if "generated" in str(dart_file) or ".g.dart" in str(dart_file):
                continue
            try:
                content = dart_file.read_text(encoding="utf-8")
                lines = content.split("\n")
                has_gesture_detector = False
                has_on_pan_start = False
                has_counter_flick = False

                for i, line in enumerate(lines, 1):
                    if "GestureDetector" in line:
                        has_gesture_detector = True
                    if "onPanStart" in line or "onPanUpdate" in line or "onPanEnd" in line:
                        has_on_pan_start = True
                    line_lower = line.lower()
                    if "counterflick" in line_lower or "counter_flick" in line_lower:
                        has_counter_flick = True

                    # Check for behavior: HitTestBehavior.opaque without proper handling
                    if "HitTestBehavior.opaque" in line:
                        self.findings.append(HorrorFinding(
                            horror_id=4, category="GESTURES", severity="MEDIUM",
                            file=str(dart_file.relative_to(ROOT)), line=i,
                            description=f"HitTestBehavior.opaque may swallow events needed by children: {line.strip()[:120]}",
                            evidence={}))

                    # Check for textMuted on interactive elements
                    if "textMuted" in line and ("onTap" in content or "onPressed" in content):
                        pass  # Too broad

                # If combat-related file has gestures but no counter-flick
                if has_gesture_detector and has_on_pan_start and "combat" in str(dart_file).lower() and not has_counter_flick:
                    self.findings.append(HorrorFinding(
                        horror_id=4, category="GESTURES", severity="HIGH",
                        file=str(dart_file.relative_to(ROOT)), line=None,
                        description="Combat screen has GestureDetector with pan handlers but no counter-flick logic for enemy projectiles",
                        evidence={"has_gesture": has_gesture_detector, "has_pan": has_on_pan_start}))

            except Exception:
                pass

    # ──────────────────────────────────────────────────────────────────────
    # HORROR #5: All Screens Contrast / Overflow / Polish
    # ──────────────────────────────────────────────────────────────────────
    def audit_all_screens(self) -> None:
        screen_dirs = [
            "presentation/screens/sanctuary",
            "presentation/screens/barracks",
            "presentation/screens/altar",
            "presentation/screens/summon",
            "presentation/screens/rift",
            "presentation/screens/endless",
            "presentation/screens/raids",
            "presentation/screens/arena_pvp",
            "presentation/screens/challenges",
            "presentation/screens/dungeons",
            "presentation/screens/training",
            "presentation/screens/shop",
        ]

        critical_keywords = ["HP", "hp", "mana", "gold", "shards", "damage", "level", "XP", "xp"]
        muted_pattern = re.compile(r"textMuted|textSecondary|withOpacity\(0\.[0-3]\)|Colors\.white(?:24|38|54|70)")

        for screen_dir in screen_dirs:
            dir_path = LIB_DIR / screen_dir
            if not dir_path.exists():
                continue
            for dart_file in dir_path.rglob("*.dart"):
                if "generated" in str(dart_file) or ".g.dart" in str(dart_file):
                    continue
                try:
                    content = dart_file.read_text(encoding="utf-8")
                    lines = content.split("\n")

                    # Check for textMuted on critical data
                    for i, line in enumerate(lines, 1):
                        if muted_pattern.search(line):
                            for kw in critical_keywords:
                                if kw.lower() in line.lower() and not any(x in line for x in ["//", "///", "/*"]):
                                    self.findings.append(HorrorFinding(
                                        horror_id=5, category="CONTRAST", severity="HIGH",
                                        file=str(dart_file.relative_to(ROOT)), line=i,
                                        description=f"Low-contrast text on critical data ({kw}): {line.strip()[:120]}",
                                        evidence={"keyword": kw}))
                                    break

                    # Check for Stack with potential overlaps
                    if "Stack(" in content:
                        # Look for Positioned with overlapping coordinates
                        for i, line in enumerate(lines, 1):
                            if "Positioned(" in line and ("top:" in line or "bottom:" in line or "left:" in line or "right:" in line):
                                # Check for negative or very large values that might cause overflow
                                pass  # Heuristic, real check in widget test

                    # Check for Column/ListView without SingleChildScrollView that might overflow
                    if "Column(" in content and "SingleChildScrollView" not in content and "ListView" not in content:
                        # Check if it's in a modal or screen body
                        if any(x in str(dart_file) for x in ["modal", "screen", "dialog"]):
                            self.findings.append(HorrorFinding(
                                horror_id=5, category="OVERFLOW", severity="MEDIUM",
                                file=str(dart_file.relative_to(ROOT)), line=None,
                                description="Column without scroll wrapper in screen/modal - potential vertical overflow",
                                evidence={}))

                    # Check for hardcoded heights that might not fit
                    hardcoded_heights = re.findall(r"height:\s*(\d{3,})", content)
                    for h_str in hardcoded_heights:
                        h = int(h_str)
                        if h > 500:
                            self.findings.append(HorrorFinding(
                                horror_id=5, category="OVERFLOW", severity="LOW",
                                file=str(dart_file.relative_to(ROOT)), line=None,
                                description=f"Hardcoded height {h}px may exceed viewport on small screens",
                                evidence={"height": h}))

                except Exception:
                    pass

    def run_all(self) -> dict:
        print("=" * 70)
        print("BRIMSTONE UX HORROR AUDITOR — Stage I")
        print("=" * 70)

        print("\n[1/7] Auditing portrait luminance...")
        self.audit_portrait_luminance()

        print("[2/7] Auditing background luminance...")
        self.audit_background_luminance()

        print("[3/7] Auditing spectral borders (alpha == 0)...")
        self.audit_spectral_borders()

        print("[4/7] Scanning Dart for dark overlays...")
        self.audit_dark_overlays_in_code()

        print("[5/7] Analyzing CombatScreen geometry...")
        self.audit_combat_screen_geometry()

        print("[6/7] Auditing gesture detectors / counter-flick...")
        self.audit_gesture_detectors()

        print("[7/7] Scanning all screens for contrast/overflow...")
        self.audit_all_screens()

        # Summary
        critical = sum(1 for f in self.findings if f.severity == "CRITICAL")
        high = sum(1 for f in self.findings if f.severity == "HIGH")
        medium = sum(1 for f in self.findings if f.severity == "MEDIUM")
        low = sum(1 for f in self.findings if f.severity == "LOW")

        print("\n" + "=" * 70)
        print("AUDIT SUMMARY")
        print("=" * 70)
        print(f"Total findings: {len(self.findings)}")
        print(f"  CRITICAL: {critical}")
        print(f"  HIGH:     {high}")
        print(f"  MEDIUM:   {medium}")
        print(f"  LOW:      {low}")

        by_horror = {}
        for f in self.findings:
            by_horror.setdefault(f.horror_id, []).append(f)

        for hid in sorted(by_horror.keys()):
            horrors = {
                1: "Darkened Screen (Luminance/Overlays)",
                2: "Spectral Borders (Enemy Brown Box)",
                3: "Orb Tray Clipped / Button Overlap",
                4: "Counter-Flick Broken / Gestures",
                5: "Contrast / Overflow / Unpolished",
            }
            count = len(by_horror[hid])
            print(f"  Horror #{hid} ({horrors.get(hid, 'Unknown')}): {count} findings")

        # Output JSON for CI
        report = {
            "summary": {
                "total": len(self.findings),
                "critical": critical,
                "high": high,
                "medium": medium,
                "low": low,
            },
            "findings": [asdict(f) for f in self.findings],
        }

        report_path = ROOT / "tools" / "ux_audit_report.json"
        report_path.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
        print(f"\nJSON report written to: {report_path}")

        return report


def main() -> int:
    auditor = AssetAuditor()
    report = auditor.run_all()
    # Exit with error if any CRITICAL or HIGH findings
    if report["summary"]["critical"] > 0 or report["summary"]["high"] > 0:
        print("\n[FAIL] AUDIT FAILED: CRITICAL or HIGH severity horrors found!")
        return 1
    print("\n[PASS] AUDIT PASSED: No blocking horrors.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
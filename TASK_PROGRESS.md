# Task Progress — Brimstone: The Summoning

## Current state (Thu Nov 12 2026)

### Completed — UI/UX regression fixes (GitHub Pages deployment)

All 4 critical regressions fixed:

1. **Combat orb flick damage** — `lib/presentation/screens/combat/combat_screen.dart`
   - `startFlyingShot` now registers damage synchronously/independently of render-object availability (no longer gated on `arenaKey` render box or `Future.delayed`); animation visuals remain a separate overlay concern.
   - Exposed `arenaKey`, `startFlyingShot`, `arenaLocalToEngine` (public) so tests can drive them via `dynamic`.
   - Top-level `elementColor`/`elementAccent` helpers for painter access.
   - Orb level badge changed "Nv." → "Lv.X" with padding (6,2), fontSize 10, height 1.0.
   - Removed unused `_toEngine`/`_tryCounterFlickAt`/`_resolveImpact`/`_slotCenterX`/`_hitRank`.

2. **Orb level badge clipping** — same file; badge now has explicit padding and fixed height.

3. **Sanctuary Mesa del Invocador button text clipping** — `lib/presentation/screens/sanctuary/sanctuary_screen.dart`
   - Grid: 4 columns, `mainAxisExtent: 58`, icon 18, font 10 / height 1.1; `showTitle` only on Historia (first) tab.

4. **Title splash yellow square glow** — `lib/presentation/screens/title/title_splash_screen.dart`
   - `AbyssalRiftView` wrapped in `ClipOval` + `ShaderMask` radial gradient to transparent.

### Tests
- `test/widget_test.dart`: combat damage test updated to read `state.engine` (screen's internal engine), populate `tray[0]` if null, and assert on total effective HP (`bossHp + bossShieldHp`) since `registerDamage` hits shield first.

### Gates (all pass)
- `flutter analyze --no-fatal-infos --no-fatal-warnings` → 0 issues
- `dart format --set-exit-if-changed lib test` → stable
- `flutter test --concurrency=1` → all pass
- `flutter build web --release --base-href "/Brimstone-The-Summoning/"` → `build/web` built successfully

### Git
- Commit `a586faa` `fix(combat-damage-and-ui): apply damage independent of render object; fix orb badge, sanctuary grid clipping, title glow`
- Pushed to `origin main`

### Skipped / not checked
- `flutter build apk` / `./gradlew` (prohibited per AGENTS.md)
- `fix_impact.py` debug helper removed (not committed)
- No APK artifact; web release build is the required shipping artifact per requirements.

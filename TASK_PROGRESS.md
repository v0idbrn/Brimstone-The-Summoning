# Task Progress — Brimstone: The Summoning

## Current state (Thu Nov 12 2026)

### Completed — UI/UX regression fixes (GitHub Pages deployment)

All 4 critical regressions fixed:

1. **HellFire true flick ballistics** — `lib/presentation/screens/combat/combat_screen.dart`
   - `startFlyingShot` now registers damage synchronously/independently of render-object availability; animation visuals remain a separate overlay concern.
   - Pointer sampling: last 5 samples in 80ms window → flick vector (speedPxPerSec / 900.0 clamped 0.55–1.35, plus -totalDy / 180.0 clamped 0.55–1.25).
   - Magnetic aim assist (perp dist < 75px or landing dist < 95px clamps to target center).
   - 180ms parabolic flight, scale 1.0→0.42, damage applies on flick, predictive aim line projected to boss plane during drag.
   - Flick hint: 1-line bubble above tray until first shot, then disappears forever.

2. **Frozen victory screen after "¡SELLO PURIFICADO!"** — `lib/domain/combat/combat_engine.dart` + `combat_screen.dart`
   - `bossHp = math.max(0, bossHp)` clamp in `registerDamage` (never show -44).
   - `_victoryHandled` flag guards victory/defeat triggers so `onVictory`/`onDefeat` fire once.
   - CombatSummaryDialog: "RECLAMAR BOTÍN Y CONTINUAR" pops `true` (victory) / "Volver al Santuario" pops `false` (defeat).
   - BossShatterOverlay 650ms + guaranteed Timer(700ms) opens dialog; not dependent on losable callbacks.

3. **Removed broken onboarding gate** — `lib/main.dart`
   - Removed `OnboardingScreen` import + `_checkOnboarding`/`_showOnboarding` state.
   - `BrimstoneHome` goes directly to `TitleGate(child: HomeShell())`.

4. **Tests** — `test/widget_test.dart`: damage test uses `state.startFlyingShot` with new signature; victory test sets `bossHp=0.0`, calls `state.engine.onVictory?.call()`, pumps 800ms, checks VICTORIA dialog + taps continue; short flick 40px test calls `startFlyingShot` directly; added `dart:math` import.

### Gates (all pass)
- `dart format --set-exit-if-changed lib test` → stable (0 changed)
- `flutter analyze --no-fatal-infos --no-fatal-warnings` → 0 issues
- `flutter test --concurrency=1` → all pass
- `flutter build web --release --base-href "/Brimstone-The-Summoning/"` → `build/web` built successfully

### Git
- Commit `be7e55f` `fix(hellfire-flick-and-victory): true short-stroke vector flick ballistics, fix frozen victory screen after Sello Purificado, clamp bossHp >= 0, remove broken onboarding`
- Pushed to `origin main` (269c6e6..be7e55f)

### Skipped / not checked
- `flutter build apk` / `./gradlew` (prohibited per AGENTS.md)
- No APK artifact; web release build is the required shipping artifact per requirements.

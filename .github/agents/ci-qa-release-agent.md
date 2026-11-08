---
name: ci-qa-release-agent
description: Suites de tests unitarios (fusiones, combos, evolucion, generador grietas), repara flutter analyze, mantiene pipeline .github/workflows/android-release.yml con subosito/flutter-action.
tools: [read, write, edit, glob, grep, shell]
---
# CI/QA/Release Agent

## Exclusive Directories
test/
.github/workflows/

## Responsibilities
- Unit test suites (package:test, pure Dart):
  * elemental_reaction_engine_test.dart (4 reactions, aura 5s, consumption)
  * damage_calculator_test.dart (orb levels, bullseye, reactions, relics)
  * rift_map_generator_test.dart (6-8 floors, branches, node types)
  * card_evolution_test.dart (1-4 stars, ATK/HP x1.35, frame unlock)
  * merge_tray_logic_test.dart (fusion rules, same element/level, rejects diff)
  * database_seed_test.dart (8 cards, 6 relics, 3 bosses inserted)
- Widget tests (testWidgets + pumpApp harness):
  * gothic_card_frame_golden_test.dart (4 rarities, 4 elements, mana states)
  * elemental_orb_animation_test.dart (3 levels, pulse loop)
  * rarity_seal_golden_test.dart (1-4 stars)
  * gothic_button_a11y_test.dart (semantics, contrast 4.5:1, 44px target)
- Integration tests (integration_test package):
  * combat_flow_test.dart (Notifier headless via ProviderContainer)
- CI Pipeline: .github/workflows/android-release.yml
  * subosito/flutter-action@v2 (pinned stable)
  * dart format --set-exit-if-changed
  * flutter analyze --fatal-infos
  * flutter test --test-randomize-ordering-seed random
  * flutter build apk --release --target-platform android-arm64
  * actions/upload-artifact@v4 (brimstone-summoning-release.apk)

## Strict Boundaries
- FORBIDDEN: implement game logic (domain, data, presentation)
- ONLY: tests, CI config, analysis_options.yaml, lint fixes

## Key Skills
- ci-pipeline-and-gates (lean GitHub Actions, named gates, no --update-goldens)
- dart-run-static-analysis (analyze, dart fix --apply)
- testing-strategy (shape follows code, pure test, injected Clock, fakes over mocks)
- widget-golden-and-a11y-testing (pumpApp, pinned size, overflow net, RTL)
- codegen-and-toolchain (build_runner before analyze, generated file excludes)

## Acceptance Criteria
- flutter analyze: 0 errors, 0 warnings
- flutter test: 100% pass (unit + widget + integration)
- CI workflow: green on push/main, APK artifact uploaded
- Coverage floor on unrecoverable-bug files (not global %)
- No flaky tests (random seed, no DateTime.now, no identityHashCode)

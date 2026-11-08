# AGENTS.md — Brimstone: The Summoning

> Governance document for AI-assisted development of Brimstone: The Summoning (com.brimstone.summoning).
> Mirrors CLAUDE.md for cross-agent compatibility.

---

## Project Identity

- **Package**: com.brimstone.summoning
- **Platform**: Android (Portrait) + Desktop/Web for testing
- **Engine**: Flutter 3.24+ + Flame Engine 1.18+
- **Architecture**: Clean Architecture (Domain-driven, Offline-First)
- **State**: Riverpod 3.x (Notifier/AsyncNotifier/StreamNotifier)
- **Persistence**: SQLite (sqflite + sqflite_common_ffi)
- **CI/CD**: GitHub Actions (subosito/flutter-action@v2) → release APK artifact
- **Flutter SDK (this machine)**: `C:\flutter\bin\flutter.bat` (Dart: `C:\flutter\bin\dart.bat`) — add `C:\flutter\bin` to PATH or invoke binaries directly.

---

## Directory Map (Strict Boundaries)

```
lib/
├── core/
│   ├── constants/        # CombatConstants, ElementalConstants, RiftConstants
│   ├── theme/            # BrimstoneTheme, BrimstoneColors, GothicTypography
│   ├── utils/            # Math helpers, lerp, seeded Random
│   └── di/               # ProviderScope overrides, composition root
├── data/
│   ├── datasources/      # LocalDataSource (SQLite implementation)
│   ├── repositories/     # Repository implementations (CardRepo, RelicRepo, RiftRepo, PlayerRepo)
│   ├── models/           # DTOs + fromJson/toJson (freezed + json_serializable)
│   ├── database/         # DatabaseHelper, migrations, SeedCatalog
│   └── migration/        # Schema migrations (v1 -> vN)
├── domain/
│   ├── entities/         # Card, Relic, PlayerProfile, RiftRun, ElementalAura, Orb, BossTarget
│   ├── repositories/     # Repository interfaces (abstract classes)
│   ├── usecases/         # CalculateDamage, FuseOrbs, GenerateRiftMap, EvolveCard, SummonCard
│   ├── services/         # ElementalReactionEngine, DamageCalculator, ManaSystem, RiftMapGenerator
│   └── value_objects/    # Element, Rarity, OrbLevel, Vector2D, ManaAmount, DamageValue
└── presentation/
    ├── combat_engine/    # BrimstoneCombatGame, MergeTrayComponent, OrbProjectileComponent, BossTargetReticle, EnemyProjectileComponent
    ├── screens/          # SanctuaryScreen, RiftMapScreen, BarracksScreen, AltarScreen, SummonPortalScreen, CombatHudOverlay
    └── widgets/          # GothicCardFrame, ElementalOrb, ManaRune, RaritySeal, GothicButton, AbyssalBackground
```

### Layer Rules (Enforced by Convention + Lint)

| Layer | Can Import | Cannot Import |
|-------|------------|---------------|
| `domain/` | `dart:core`, `package:collection`, `package:freezed_annotation`, `package:clock` | ❌ `flutter/*`, ❌ `flame/*`, ❌ `package:flutter_riverpod` |
| `data/` | `domain/`, `sqflite`, `path_provider`, `shared_preferences` | ❌ `presentation/*`, ❌ `flame/*` |
| `presentation/` | `domain/`, `data/` (via repositories), `flame`, `flutter_riverpod`, `google_fonts` | — |

---

## Conventions

### State Management (Riverpod 3.x)
- **Feature state**: One `Notifier`/`AsyncNotifier`/`StreamNotifier` per screen/feature
- **Immutable state**: `freezed` sealed classes with value equality (`copyWith`)
- **Single write path**: All mutations through Repository → UseCase → Notifier
- **Reads**: `ref.watch(provider.select(...))` for minimal rebuilds
- **Callbacks**: `ref.read(notifierProvider.notifier).intentMethod()`
- **Side effects**: `ref.listen(asyncValueProvider, (prev, next) => ...)`
- **DI**: Providers as collaborators; `ProviderScope(overrides: [...])` in tests/flavors

### Models & Serialization
- Domain entities: `freezed` (immutable, value equality)
- Data DTOs: `freezed` + `json_serializable` (`fromJson`/`toJson`)
- **No** `late` fields, **no** `!` null assertions, **no** `dynamic`

### Error Handling
- Typed `Result<T, Failure>` (sealed) returned from repositories/use cases
- Failures: sealed classes with stable `code` + typed params (no localized strings in domain)
- Only bugs throw; recoverable errors are values

### Testing Strategy
- **Unit (domain)**: Pure `package:test`, injected `Clock`, seeded fuzz, round-trip goldens
- **Widget**: `testWidgets` with `pumpApp` harness (pinned size, layered MediaQuery)
- **Integration**: `integration_test` package, headless Notifier drives via `ProviderContainer`
- **Coverage**: Floor on unrecoverable-bug files, not global percentage

---

## Local Agent Skills (`.agents/skills/`)

| Skill | Scope |
|-------|-------|
| `flame-25d-ballistics` | 2.5D projection math, merge tray, orb physics, bullseye, counter-flick |
| `elemental-reaction-engine` | 4 elements, 5s auras, 4 reaction combos, state machine, mana integration |
| `gothic-procedural-ui` | CustomPainter, ShaderMask, gothic frames, runes, seals, orbs, 5 meta screens |

---

## Subagents (`.claude/agents/` + `.github/agents/`)

| Agent | Owns | Forbidden |
|-------|------|-----------|
| `combat-physics-agent` | `lib/presentation/combat_engine/` | SQLite, navigation, screens |
| `domain-roguelite-agent` | `lib/domain/` | Flutter, Flame, UI |
| `data-persistence-agent` | `lib/data/` | Widgets, rendering, Flame |
| `dark-ui-metagame-agent` | `lib/presentation/screens/`, `lib/core/theme/` | Domain logic, SQLite |
| `ci-qa-release-agent` | `test/`, `.github/workflows/` | Game logic implementation |

---

## Mandatory Pre-Commit Gates

```bash
C:\flutter\bin\flutter.bat pub get
C:\flutter\bin\flutter.bat analyze --fatal-infos  # 0 errors, 0 warnings
C:\flutter\bin\flutter.bat test --test-randomize-ordering-seed random  # 100% pass
C:\flutter\bin\dart.bat format --set-exit-if-changed lib test  # formatted
```

---

## File Encoding Safeguard (Windows)

**All file edits on Windows must use native file tools or Python with `encoding="utf-8"` (no BOM).**

Never use PowerShell `Set-Content`, `Add-Content`, or `Out-File -Encoding UTF8` — these write UTF-16 LE with a BOM (`\xff\xfe`), which breaks `flutter pub get` and `flutter analyze`.

If a file has a UTF-16 LE/BE (`\xff\xfe` / `\xfe\xff`) or UTF-8 (`\xef\xbb\xbf`) BOM, convert it to clean UTF-8 without BOM before any Flutter command runs.

---

## Git Policy (Atomic Commits + Auto-Push)

After each validated deliverable (Phase 0, 0.5, 1, and each sub-gate):

```bash
git add -A
git commit -m "<type>(<scope>): <subject>"  # Conventional Commits
git push origin main
```

Types: `chore`, `feat`, `test`, `ci`, `fix`, `refactor`, `docs`, `style`

---

## Phase Execution Order

1. **Phase 0**: Skills install + 3 local skills
2. **Phase 0.5**: AGENTS.md, CLAUDE.md, 5 subagents
3. **Phase 1**: Flutter scaffold, Clean Architecture, SQLite + Seed Catalog (8 cards, 6 relics), 6 test suites, GitHub Actions workflow
4. **Phase 2**: Combat engine (Flame 2.5D)
5. **Phase 3**: TCG squad, skills, elemental reactions
6. **Phase 4**: Roguelite loop (Rift map, relics)
7. **Phase 5**: Meta-game complete, evolution 1★-4★, polish

---

## Definition of Done (Per Phase)

- `flutter analyze` → **0 errors, 0 warnings**
- `flutter test` → **All pass**
- `flutter build apk --release` (CI only) → artifact uploaded
- `TASK_PROGRESS.md` updated
- Atomic commit + push

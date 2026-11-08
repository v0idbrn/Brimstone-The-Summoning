# CLAUDE.md — Brimstone: The Summoning

> **Token Economy (Caveman + Ponytail)**: Respuestas en modo caveman (ultra-concisas, sin prosa de relleno). Lectura de archivos quirúrgica (no releer archivos que no se van a tocar). Reutilizar clases existentes antes de crear archivos nuevos, pero manteniendo máxima riqueza visual en CustomPainter y widgets de UI.

> Mirrors AGENTS.md for cross-agent compatibility.

## Project Identity

- **Package**: com.brimstone.summoning
- **Platform**: Android (Portrait) + Desktop/Web for testing
- **Engine**: Flutter 3.24+ + Flame Engine 1.18+
- **Architecture**: Clean Architecture (Domain-driven, Offline-First)
- **State**: Riverpod 3.x (Notifier/AsyncNotifier/StreamNotifier)
- **Persistence**: SQLite (sqflite + sqflite_common_ffi)
- **CI/CD**: GitHub Actions (subosito/flutter-action@v2) → release APK artifact
- **Flutter SDK (this machine)**: `C:\flutter\bin\flutter.bat` (Dart: `C:\flutter\bin\dart.bat`) — add `C:\flutter\bin` to PATH or invoke binaries directly.

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

## Conventions

### State Management (Riverpod 3.x)
- Feature state: One Notifier/AsyncNotifier/StreamNotifier per screen/feature
- Immutable state: freezed sealed classes with value equality (copyWith)
- Single write path: All mutations through Repository → UseCase → Notifier
- Reads: ref.watch(provider.select(...)) for minimal rebuilds
- Callbacks: ref.read(notifierProvider.notifier).intentMethod()
- Side effects: ref.listen(asyncValueProvider, (prev, next) => ...)
- DI: Providers as collaborators; ProviderScope(overrides: [...]) in tests/flavors

### Models & Serialization
- Domain entities: freezed (immutable, value equality)
- Data DTOs: freezed + json_serializable (fromJson/toJson)
- No late fields, no ! null assertions, no dynamic

### Error Handling
- Typed Result<T, Failure> (sealed) returned from repositories/use cases
- Failures: sealed classes with stable code + typed params (no localized strings in domain)
- Only bugs throw; recoverable errors are values

## Mandatory Pre-Commit Gates

```bash
flutter pub get
flutter analyze --fatal-infos  # 0 errors, 0 warnings
flutter test --test-randomize-ordering-seed random  # 100% pass
dart format --set-exit-if-changed lib test  # formatted
```

## File Encoding Safeguard (Windows)

All file edits on Windows must use native file tools or Python with `encoding="utf-8"` (no BOM).

Never use PowerShell `Set-Content`, `Add-Content`, or `Out-File -Encoding UTF8` — these write UTF-16 LE with a BOM, which breaks `flutter pub get` and `flutter analyze`.

If a file has a UTF-16 LE/BE or UTF-8 BOM, convert it to clean UTF-8 without BOM before any Flutter command runs.

## Git Policy (Atomic Commits + Auto-Push)

After each validated deliverable:

```bash
git add -A
git commit -m "<type>(<scope>): <subject>"  # Conventional Commits
git push origin HEAD:main
```

Types: chore, feat, test, ci, fix, refactor, docs, style

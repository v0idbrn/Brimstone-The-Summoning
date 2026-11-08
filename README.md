# Brimstone: The Summoning

> **Gothic Roguelite Card Battler** — 2.5D Merge-Orb Combat + TCG Evolution + Roguelite Meta-Progression
> **Platform:** Android (Portrait) • Desktop/Web (Testing)
> **Engine:** Flutter 3.24+ + Flame 1.18+
> **Architecture:** Clean Architecture (Domain-Driven, Offline-First)
> **State:** Riverpod 3.x (Notifier / AsyncNotifier / StreamNotifier)
> **Persistence:** SQLite (sqflite + sqflite_common_ffi), schema v6
> **CI/CD:** GitHub Actions → Release APK artifact

[![Flutter](https://img.shields.io/badge/Flutter-3.24+-02569B?logo=flutter&logoColor=white)]()
[![Flame](https://img.shields.io/badge/Flame-1.18+-FF6B6B?logo=flame&logoColor=white)]()
[![Riverpod](https://img.shields.io/badge/Riverpod-3.x-42A5F5?logo=riverpod&logoColor=white)]()
[![SQLite](https://img.shields.io/badge/SQLite-3.45+-003B57?logo=sqlite&logoColor=white)]()
[![Tests](https://img.shields.io/badge/tests-387%20passing-4FFFA3)]()
[![License](https://img.shields.io/badge/License-MIT-green)]()

---

## 🎮 Gameplay Overview

**Brimstone: The Summoning** es un *roguelite deck-builder* con combate en **2.5D isométrico**: fusionas esferas elementales, detonas reacciones químicas y evolucionas un escuadrón de 20 criaturas únicas a través de 5 capítulos de campaña, incursiones de grieta y desafíos tácticos con mutadores.

### Core Loop
1. **Santuario** → Gestiona oro/esquirlas, equipa escuadrón, forja runas, desbloquea talentos
2. **Grieta** → 7 pisos ramificados (Combate / Élite / Altar / Encuentro) → Jefe final
3. **Combate 2.5D** → Arrastra esferas (N1→N2→N3), apunta al *Bullseye* (crítico x1.5), contraataca proyectiles
4. **Evolución** → Fusiona duplicadas (★1→★4), desbloquea *Habilidades de Líder* pasivas
5. **Meta** → 8 Talentos permanentes (0→5), 3 piezas de Armadura, 12 Títulos, Backup V2

---

## ✨ Features Completas (Fases 1-22)

### 🎴 TCG Squad (20 Criaturas / 4 Elementos / 4 Rarezas)
| Elemento | Común | Rara | Épica | Legendaria / Mítica |
|----------|-------|------|-------|---------------------|
| **Ígneo** | Sabueso | Draco | Señor / Serafín | Coloso |
| **Abisal** | Acechador | Sirena / Segador | Kraken | Leviatán / Nigromante |
| **Telúrico** | Gólem | Guardián / Hidra | Titán | Behemoth |
| **Vacío** | Espectro | Oráculo | — | Malakor / Arquiconte |

- **Habilidades activas**: AoE, stun, freeze, lifesteal, escudo, buff/debuff, manipulación de bandeja
- **Habilidades de Líder (slot 0)**: +ATK esferas / +Maná / -Daño recibido / +Crit Bullseye según elemento y ★

### ⚔️ Combate 2.5D (Flame Engine)
- **Bandeja de 5 ranuras** → Arrastra esferas para fusionar (N1+N1=N2, N2+N2=N3)
- **Proyección isométrica 2.5D**: escala `z∈[0,1]` → tamaño 0.38×–1.0×, profundidad visual
- **Dianas orbitales** con amplitud/velocidad variable → golpea en el *Bullseye* (radio interior) para **x1.5 daño**
- **Counter-Flick** → Desliza hacia afuera para destruir proyectiles enemigos (devuelve maná)
- **Auras Elementales (5s)** → Ígnea/Abisal/Telúrica/Vacío → **4 Reacciones**: Magma / Choque Térmico / Petrificación / Colapso del Sello
- **Jefes con Furia (Enrage)**: Pyroth (quema ranuras), Vaelor (escudo hielo), Gorgath (petrifica +20% radio), Nyxara (teleport + drenaje maná), Azathor (inversión rotación + proyectiles dobles)

### 🕳️ Roguelite: Incursiones de Grieta
- **3 Dificultades**: Grieta de Ceniza (Nv.1) / Fosa Abisal (Nv.2) / Trono del Vacío (Nv.3)
- **DAG de 7 pisos** → pisos 2–5 con 3 carriles (Combate / Élite / Altar) **+ un carril opcional de Encuentro del Abismo**; piso 6 Altar de Sangre; piso 7 Jefe
- **10 Encuentros del Abismo** → Espejo de Sangre, Apostador Ciego, Fuente Corrupta, Sello Antiguo, Forja Maldita, Mercader Errante, Cáliz de Obsidiana, Susurros del Vacío, Guardián Caído, Pacto de Ceniza — cada opción altera HP / Oro / Esquirlas / Maná inicial o entrega una reliquia real
- **18 Reliquias Abisales** → Desde Ceniza Volátil / Ojo del Abismo hasta **Prisma del Caos** (esferas prismáticas comodín), Reloj de Ceniza, Colmillo Vampírico, Sello de Sobrecarga, Corazón de Fénix, Llama Eterna…
- **Altar de Sangre**: Cura 40% HP / Sacrifica 12% HP × Reliquia + 150 oro / Inicio 50% maná
- Las reliquias se acumulan entre sí y el motor las traduce a modificadores de daño, maná, radios, auras y economía

### 🏰 Meta-Progression (Persistente en SQLite)
| Sistema | Detalle |
|---------|---------|
| **Árbol de Talentos (8)** | Sangre de Arconte (+6% HP/nv), Furia de Azufre (+5% ATK esferas/nv), Canalización Rúnica (+6% Maná/nv), Ojo Letal (+8% Bullseye/nv), Maestría Elemental (+7% Reacciones/nv), Piel de Basalto (-4% Daño/nv), Avaricia del Vacío (+10% Oro/nv), Eco de Esquirlas (+10% Esquirlas/nv) — **Niveles 0→5**, coste creciente en Oro/Esquirlas |
| **Armadura del Invocador (3)** | Yelmo Abisal (Duración de Aura +15%/nv), Guanteletes de Lanzamiento (Radio Bullseye +10%/nv), Amuleto del Sello (Regeneración 5% HP máx/piso/nv) — **Niveles 0→5** |
| **Desmantelar** | Elimina una copia no equipada (mín. 4 cartas totales, nunca la del escuadrón) → **50★ esquirlas + 150★ oro** |
| **12 Títulos** | Novato / Sellador Menor / Asesino de Gorgath / Vencedor de Nyxara / Destructor de Azathor / Ojo de la Muerte (racha 10) / Verdugo de Ceniza (500 daño) / Alquimista Abisal (50 reacciones) / Rey de las Cartas (20) / Quebrantormentas (5 desafíos) / Viajero del Abismo (oleada 10) / Dios Invocador (todo) — equipables desde el perfil |
| **Historial de Invocador** | Combates ganados, jefes, daño máximo, mejor racha, reacciones, counter-flicks, capítulos, desafíos, cartas y récord del Abismo Sin Fin |
| **Backup V2** | JSON+Base64 portable con perfil, colección, escuadrón, runas, bounties, capítulos, talentos, desafíos, armadura, título activo y estadísticas — **retrocompatible con v1** |

### 🏆 Modos Extra
- **Campaña 5 Capítulos** → Jefes: Pyroth / Vaelor / Gorgath / Nyxara / Azathor — desbloqueo secuencial + recompensas de primera victoria
- **Desafíos del Sello (10 Mutadores)** → *Francotirador Abisal / Crisol Alquímico / Maestro de la Forja / Muralla de Espejos / Pacto de Hemorragia / Tormenta Bipolar / Silencio de Cartas / Lluvia Corrupta / Dianas Fugaces / Juicio del Emperador* — 250 esquirlas + 500 oro la primera victoria
- **Arena de Entrenamiento** → Gólem de pruebas con DPS meter, maná instantáneo y recarga de dianas, sin coste ni récord
- **Abismo Sin Fin** → Oleadas infinitas, récord histórico persistente
- **Códice Abisal** → Grimorio de reacciones, galería de reliquias y anales de jefes

### 🔊 Audio Procedural + Ajustes
- **WAV sintéticos en memoria** → esferas, golpes, reacciones, skills, jefes, evolución, **drone ambiente (4s loop)** y **pulso de jefe**
- **SettingsModal** → Volumen SFX / Volumen Ambiente / Hápticas / Mute global (persistidos en `player_stats`)
- **Racha Crítica** → ≥3 Bullseyes consecutivos → **¡RACHA CRÍTICA!** +10% daño por golpe extra (tope +100%)
- **Viñeta de Peligro** → HP <25% → borde rojo pulsante

---

## 🏗️ Architecture

```
lib/
├── core/
│   ├── constants/          # CombatConstants, ElementalConstants, RiftConstants
│   ├── theme/              # BrimstoneTheme, BrimstoneColors, GothicTypography
│   ├── audio/              # ProceduralSfxEngine (WAV generators, volúmenes, hápticas)
│   ├── utils/              # Math helpers, lerp, seeded Random
│   └── di/                 # ProviderScope overrides, composition root
├── data/
│   ├── datasources/        # LocalDataSource (SQLite)
│   ├── repositories/       # PlayerRepository, CardRepository, RelicRepository, RiftRepository
│   ├── database/           # DatabaseHelper (v6, conexión por instancia, seed 20+18)
│   └── migration/          # Schema migrations (v1→v6)
├── domain/
│   ├── entities/           # Card, Relic, PlayerProfile, RiftRun, ElementalAura, Orb, BossTarget
│   ├── repositories/       # Repository interfaces (abstract)
│   ├── usecases/           # CalculateDamage, FuseOrbs, GenerateRiftMap, EvolveCard, SummonCard
│   ├── services/           # ElementalReactionEngine, DamageCalculator, ManaSystem, RiftMapGenerator
│   ├── roguelite/          # RiftRun, RelicCatalog (18), AbyssalEvents (10)
│   ├── campaign/           # CampaignChapter, unlock logic
│   ├── meta/               # TalentRules, SummonerGearRules, SealChallengeRules, SummonerTitles, LeaderSkill, RuneSystem, SquadSynergyResolver
│   ├── combat/             # CombatEngine, CombatModifiers, CombatModels, CombatMath
│   └── value_objects/      # Element, Rarity, OrbLevel, ManaAmount, DamageValue, Vector2D
├── presentation/
│   ├── combat_engine/      # BrimstoneCombatGame, MergeTray, OrbProjectile, BossTargetReticle
│   ├── screens/
│   │   ├── sanctuary/      # SanctuaryScreen, TalentTreeModal, SummonerProfileModal, SettingsModal, CodexModal
│   │   ├── rift/           # RiftMapScreen, RelicDraftModal, AbyssalEventModal, RiftRunNotifier
│   │   ├── barracks/       # BarracksScreen (desmantelar), CardInspectorModal
│   │   ├── altar/          # AltarEvolutionScreen
│   │   ├── summon/         # SummonPortalScreen
│   │   ├── challenges/     # SealChallengesScreen
│   │   ├── training/       # TrainingArenaScreen
│   │   ├── combat/         # CombatScreen (2.5D Flame, racha, viñeta, training tools)
│   │   ├── endless/        # EndlessAbyssScreen
│   │   └── meta/           # HowToPlayModal, CurrencyBar, widgets
│   └── controllers/        # ProfileController, CollectionController, BountyController
```

### Layer Rules

| Layer | Can Import | Cannot Import |
|-------|------------|---------------|
| `domain/` | `dart:core`, `package:collection`, `package:clock` | ❌ `flutter/*`, ❌ `flame/*`, ❌ `package:flutter_riverpod` |
| `data/` | `domain/`, `sqflite`, `path_provider`, `shared_preferences` | ❌ `presentation/*`, ❌ `flame/*` |
| `presentation/` | `domain/`, `data/` (via repositories), `flame`, `flutter_riverpod`, `google_fonts` | — |

### Persistencia (schema v6)

`cards` · `relics` · `player_profile` · `owned_cards` · `player_squad` · `owned_card_runes` · `bounties` · `codex_reactions` · `chapters_cleared` · `summoner_talents` · `challenges_cleared` · `summoner_gear` · `player_stats`

`DatabaseHelper` mantiene **una conexión por instancia** (nada de `static`), expone `useInMemory()`, `uniqueTestPath()` y `close()`, y cada transacción se abre en el repositorio — sin transacciones anidadas. Eso elimina los `database is locked` en suites paralelas.

---

## 🧪 Testing Strategy (387 Tests)

| Type | Scope | Tools |
|------|-------|-------|
| **Unit (Domain)** | CombatMath, ElementalReactions, DamageCalc, RiftGen, Talent/Gear/Event/Title math | `flutter_test`, seeded fuzz, round-trip |
| **Data (SQLite)** | Seed, migraciones, backup v1/v2, aislamiento por instancia | `sqflite_common_ffi` (in-memory) |
| **Widget** | Sanctuary, Barracks, Codex, Settings, EventModal, RelicDraft | `flutter_test`, `pumpApp` harness |
| **Gates** | `flutter_lints` estricto, format, `analyze --fatal-infos`, `--concurrency=1` | `dart format`, `flutter analyze` |

```bash
# Pre-commit gates (deben pasar)
C:\flutter\bin\flutter.bat pub get
C:\flutter\bin\dart.bat format --set-exit-if-changed lib test
C:\flutter\bin\flutter.bat analyze --fatal-infos
C:\flutter\bin\flutter.bat test --concurrency=1 --test-randomize-ordering-seed random
# → 387 tests, 0 errores, 0 warnings
```

---

## 🚀 Getting Started

```bash
# Prerequisites
- Flutter SDK 3.24+ (stable)
- Android SDK 34 (for APK build)
- Windows/macOS/Linux for desktop testing

# Clone & Run
git clone https://github.com/v0idbrn/Brimstone-The-Summoning.git
cd BrimstoneTheSummoning
C:\flutter\bin\flutter.bat pub get
C:\flutter\bin\flutter.bat run -d <device_id>

# Run tests
C:\flutter\bin\flutter.bat test --concurrency=1
```

Este proyecto **no** usa `build_runner`: las entidades y DTOs son clases inmutables puras (`const`, `copyWith`, `toMap`/`fromMap`).

---

## 📦 CI/CD Pipeline (`.github/workflows/android-release.yml`)

```yaml
jobs:
  build-and-release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { channel: 'stable', cache: true }
      - run: flutter pub get
      - run: flutter analyze --fatal-infos
      - run: flutter test --concurrency=1  # ← aislamiento SQLite
      - run: flutter build apk --release
      - uses: softprops/action-gh-release@v1
        with:
          files: build/app/outputs/flutter-apk/app-release.apk
```

**Artifacts**: APK de release publicado en **GitHub Releases** en cada push a `main`.

---

## 📖 Documentación del repositorio

- [`AGENTS.md`](AGENTS.md) / [`CLAUDE.md`](CLAUDE.md) — gobernanza, límites de capas, gates obligatorios
- [`.agents/skills/`](.agents/skills) — skills locales (`flame-25d-ballistics`, `elemental-reaction-engine`, `gothic-procedural-ui`)
- [`lib/domain`](lib/domain) — reglas puras: daño, reacciones, grieta, talentos, desafíos, títulos
- [`test/domain/phase15_22_master_test.dart`](test/domain/phase15_22_master_test.dart) — suite maestra de las fases 15–22

---

## 🗺️ Roadmap (Post-Release)

- [ ] **Multiplayer Co-op** (WebRTC) — Grietas compartidas
- [ ] **Seasonal Events** — Reliquias/skins limitadas, leaderboards
- [ ] **Modding API** — Cartas/reliquias/jefes custom via JSON
- [ ] **iOS Release** — TestFlight + App Store Connect
- [ ] **Steam Deck** — Proton compatibility, controller mapping

---

## 📄 License

MIT License.

---

## 🙏 Credits

- **Engine**: Flutter Team, Flame Engine contributors
- **Architecture**: Very Good Ventures (`very_good_analysis`), Riverpod (Remi Rousselet)
- **Audio**: Síntesis procedural PCM inspirada en *Bfxr* / *Aseprite*
- **Art Direction**: Estética gótica/abisal con CustomPainter + ShaderMask, sin assets externos

---

> **Brimstone: The Summoning** — *Forja tu destino en el Abismo.*
> **Repositorio**: https://github.com/v0idbrn/Brimstone-The-Summoning
> **Releases**: https://github.com/v0idbrn/Brimstone-The-Summoning/releases/latest

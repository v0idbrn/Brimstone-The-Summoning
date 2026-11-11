# Brimstone: The Summoning

> **Gothic Roguelite Card Battler** — 2.5D Merge-Orb Combat + TCG Evolution + Roguelite Meta-Progression
> **Platform:** Android (Portrait) • Web (Portal jugable) • Desktop (Testing)
> **Engine:** Flutter 3.24+ + Flame 1.18+
> **Architecture:** Clean Architecture (Domain-Driven, Offline-First)
> **State:** Riverpod 3.x (Notifier / AsyncNotifier / StreamNotifier)
> **Persistence:** SQLite (sqflite + sqflite_common_ffi), schema v10
> **CI/CD:** GitHub Actions → Release APK + Web Portal artifacts

[![Flutter](https://img.shields.io/badge/Flutter-3.24+-02569B?logo=flutter&logoColor=white)]()
[![Flame](https://img.shields.io/badge/Flame-1.18+-FF6B6B?logo=flame&logoColor=white)]()
[![Riverpod](https://img.shields.io/badge/Riverpod-3.x-42A5F5?logo=riverpod&logoColor=white)]()
[![SQLite](https://img.shields.io/badge/SQLite-3.45+-003B57?logo=sqlite&logoColor=white)]()
[![Tests](https://img.shields.io/badge/tests-850%2B%20passing-4FFFA3)]()
[![License](https://img.shields.io/badge/License-MIT-green)]()

---

## 🎮 Gameplay Overview

**Brimstone: The Summoning** es un *roguelite deck-builder* con combate en **2.5D isométrico**: fusionas esferas elementales, detonas reacciones químicas y evolucionas un escuadrón de **40 criaturas únicas** a través de **10 capítulos de campaña**, incursiones de grieta, torre de 50 pisos, expediciones abisales, gremios y desafíos tácticos con mutadores.

### Core Loop (Etapa III: Leviatán — Director's Cut)
1. **Santuario (Hub 4 pestañas)** → Historia (Actos I–II) / Torre & Cámaras / Coliseo & Raids / Orden & Expediciones
2. **Grieta + Acto II** → Capítulos VI–X (El Continente Sumergido) + Modo Pesadilla (New Game+)
3. **Combate 2.5D mejorado** → Counter-Flick (radio 58px), Artefactos del Invocador (5º botón), MVP damage breakdown
4. **Torre de los 50 Sellos** → Escalada progresiva con jefes guardianes cada 5 pisos + Barrido Rápido Diario
5. **Expediciones Abisales** → 3 misiones idle (15m/1h/8h) con cartas suplentes → Oro, Esquirlas, XP Maestría
6. **Orden del Pacto (Gremios)** → 4 Órdenes elementales, contribuciones diarias IA, Tienda de Insignias
7. **Evolución 1★→5★** → Ascensión mítica (skins) + 20 criaturas nuevas (5 por elemento)
8. **i18n ES/EN** → Toggle instantáneo persistido en SQLite v10
9. **8 Shaders GLSL** → Mythic Aura, Elemental Weather, Shield Hex + 5 originales
10. **5 Tracks musicales** → Sintetizados algorítmicamente (PCM 16-bit, loop zero-crossing)

---

## ✨ Features Completas (Fases 1-22)

### 🎴 TCG Squad (40 Criaturas / 4 Elementos / 5 por elemento + Roles y Facciones)

| Elemento | Vanguardia | Destructor | Canalizador | Arconte | Mítico |
|----------|------------|------------|-------------|---------|--------|
| **Ígneo** | Sabueso | Draco | Alquimista | Señor / Serafín | Fénix / Berserker / Valkiria / Serpiente |
| **Abisal** | Acechador | Segador | Sirena | Kraken / Oráculo | Leviatán / Verdugo / Glaciar / Medusa / Emperatriz |
| **Telúrico** | Gólem | Guardián | Vibora | Titán / Hidra | Behemoth / Druida / Juggernaut / Escorpión / Centinela / Árbol Mundo |
| **Vacío** | Espectro | Larva | Acolito | Oráculo / Nigromante | Malakor / Arquiconte / Asesino / Titiritero / Heraldo / Liche / Serafín |

- **4 Roles**: Vanguardia (tanque), Destructor (DPS), Canalizador (mana/buffs), Arconte (líder)
- **4 Facciones**: Orden de la Ceniza / Corte del Abismo / Hijos del Basalto / Culto del Eclipse
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

### 🏆 Modos Extra (Etapa III: Leviatán)
- **Campaña Actos I–II (10 Capítulos)** → Jefes: Pyroth / Vaelor / Gorgath / Nyxara / Azathor / Kaelith (Reina Ahogada) / Astreon (Vigía Ciego) / Malakor Renacido / Chronos-Vex / Samael (3 fases: 100%/65%/30% HP) — Selector Normal / Pesadilla (x2.2 stats, x2.5 recompensas)
- **Torre de los 50 Sellos** → 50 pisos con jefes guardianes cada 5 + Barrido Rápido Diario (oro/esquirlas según récord)
- **Expediciones Abisales (Idle)** → 3 slots (15m/1h/8h) para cartas suplentes → Oro, Esquirlas, XP Maestría
- **Artefactos del Invocador (6)** → Reloj de Arena, Crisol, Cáliz, Lente, Bomba, Catalizador — 5º botón en combate (20s CD)
- **Orden del Pacto (Gremios)** → 4 Órdenes elementales, contribuciones diarias IA, buffs globales, Tienda de Insignias
- **MVP Damage Breakdown** → Barras % por carta + insignia ★ MVP en resumen de combate + Historial 15 batallas
- **Desafíos del Sello (10 Mutadores)** → *Francotirador Abisal / Crisol Alquímico / Maestro de la Forja / Muralla de Espejos / Pacto de Hemorragia / Tormenta Bipolar / Silencio de Cartas / Lluvia Corrupta / Dianas Fugaces / Juicio del Emperador*
- **Arena de Entrenamiento** → Gólem de pruebas con DPS meter, maná instantáneo, sin coste ni récord
- **Abismo Sin Fin** → Oleadas infinitas, récord histórico persistente
- **Códice Abisal** → Grimorio de reacciones, galería de reliquias y anales de jefes

### 🔊 Audio Procedural + Ajustes (Etapa III: 5 Tracks Musicales)
- **WAV sintéticos en memoria** → esferas, golpes, reacciones, skills, jefes, evolución, **drone ambiente (4s loop)** y **pulso de jefe**
- **5 Tracks musicales PCM 16-bit** → Sanctuary Requiem / Rift March / Boss Confrontation / Titan & Samael Apocalypse / Portal of Souls (16–24s, loop zero-crossing, lazy caching)
- **SettingsModal** → Volumen SFX / Volumen Ambiente / Volumen Música / Hápticas / Mute global (persistidos en SQLite v10)
- **i18n ES/EN** → Toggle instantáneo en TitleSplashScreen y SettingsModal (persistido en SQLite v10)
- **Racha Crítica** → ≥3 Bullseyes consecutivos → **¡RACHA CRÍTICA!** +10% daño por golpe extra (tope +100%)
- **Viñeta de Peligro** → HP <25% → borde rojo pulsante

### ⚙️ Rendimiento, Web y Seguridad (Fases 23-26)
- **RAM acotada** → `FixedRingBuffer<T>` pre-alojado: 24 ráfagas de partículas (10 en gama baja), 12 textos flotantes, reciclaje O(1) sin realloc ni fugas en sesiones largas
- **Cero allocations por frame** → `Paint` pre-alojados en el fondo 2.5D y los efectos de impacto; caché estático de WAV (`prewarmCache()` / `clearCache()`) que reutiliza el mismo `Uint8List` siempre
- **Modo Gama Baja** → persistido en `player_stats`: 40% de partículas, sin halos secundarios ni niebla animada; mantiene 60 FPS en hardware modesto
- **Web jugable** → SQLite vía WebAssembly + IndexedDB (`sqflite_common_ffi_web`) seleccionado con imports condicionales: `flutter build web --release` compila sin `dart:io` ni `dart:ffi`
- **Marco arcade** → en pantallas >560 px la app se centra en un gabinete 440×920 con título vertical y pistas de ratón; en móvil ocupa el 100%
- **Anti-tamper de backups** → HMAC-SHA256 en Dart puro (`IntegritySigner`) sobre JSON canónico; editar oro, estrellas o talentos invalida `sealSignature` y lanza `FormatException`
- **Anti-cheat en combate** → `CombatSanityGuard` descarta NaN/infinitos/negativos y recorta el daño inyectado al techo legal por golpe; `SecureInt` enmascara enteros sensibles con XOR + checksum
- **Backup V4** → JSON+Base64 portable con **tower_progress, expedition_slots, summoner_artifacts, guild_state, battle_log, app_settings** + retrocompatibilidad v1–v3
- **CI endurecido** → APK ofuscado (`--obfuscate --split-debug-info`) + `Brimstone-Web-Portal.zip` adjuntos al release y a los artifacts

---

## 🏗️ Architecture

```
lib/
├── core/
│   ├── constants/          # CombatConstants, ElementalConstants, RiftConstants
│   ├── theme/              # BrimstoneTheme, BrimstoneColors, GothicTypography
│   ├── audio/              # ProceduralSfxEngine (WAV generators, caché, volúmenes, hápticas)
│   ├── performance/        # FixedRingBuffer, PerformanceSettings (modo gama baja)
│   ├── security/           # IntegritySigner, SealSha256, SecureInt, CombatSanityGuard
│   ├── utils/              # Math helpers, lerp, seeded Random
│   └── di/                 # ProviderScope overrides, composition root
├── data/
│   ├── datasources/        # LocalDataSource (SQLite)
│   ├── repositories/       # PlayerRepository, CardRepository, RelicRepository, RiftRepository
│   ├── database/           # DatabaseHelper (v6, backend FFI nativo / WASM web, seed 20+18)
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

### Persistencia (schema v10)

`cards` · `relics` · `player_profile` · `owned_cards` · `player_squad` · `owned_card_runes` · `bounties` · `codex_reactions` · `chapters_cleared` · `summoner_talents` · `challenges_cleared` · `summoner_gear` · `player_stats` · **`tower_progress` · `expedition_slots` · `summoner_artifacts` · `guild_state` · `battle_log` · `app_settings`**

`DatabaseHelper` mantiene **una conexión por instancia** (nada de `static`), expone `useInMemory()`, `uniqueTestPath()` y `close()`, y cada transacción se abre en el repositorio — sin transacciones anidadas. Eso elimina los `database is locked` en suites paralelas.

---

## 🧪 Testing Strategy (850+ Tests)

| Type | Scope | Tools |
|------|-------|-------|
| **Unit (Domain)** | CombatMath, ElementalReactions, DamageCalc, RiftGen, Talent/Gear/Event/Title math, **Tower/Expedition/Guild/Artifact/Leviathan entities** | `flutter_test`, seeded fuzz, round-trip |
| **Data (SQLite)** | Seed (40 cards), migraciones v1→v10, backup v1–v4, aislamiento por instancia | `sqflite_common_ffi` (in-memory) |
| **Widget** | Sanctuary (4 tabs), Barracks, Codex, Settings, EventModal, RelicDraft, **Tower/Expedition/Guild/Artifact/Logs modals** | `flutter_test`, `pumpApp` harness |
| **Integration** | Combate 2.5D full run, Campaign Act II, Tower sweep, Expeditions claim | `integration_test` |
| **Gates** | `flutter_lints` estricto, format, `analyze --fatal-infos`, `--concurrency=1` | `dart format`, `flutter analyze` |

```bash
# Pre-commit gates (deben pasar)
C:\flutter\bin\flutter.bat pub get
C:\flutter\bin\dart.bat format --set-exit-if-changed lib test
C:\flutter\bin\flutter.bat analyze --fatal-infos
C:\flutter\bin\flutter.bat test --concurrency=1 --test-randomize-ordering-seed random
# → 850+ tests, 0 errores, 0 warnings
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

# Build web portal
C:\flutter\bin\flutter.bat build web --release
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
      - run: flutter build apk --release --obfuscate --split-debug-info=build/symbols
      - run: flutter build web --release   # ← portal jugable (SQLite WASM)
      - uses: softprops/action-gh-release@v1
        with:
          files: build/app/outputs/flutter-apk/app-release.apk
```

**Artifacts**: APK ofuscado + `Brimstone-Web-Portal.zip` publicados en **GitHub Releases** en cada push a `main`.

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

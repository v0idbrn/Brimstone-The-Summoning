import 'dart:async';
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart' hide Element;
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart'
    show KeyDownEvent, LogicalKeyboardKey, KeyEvent;

import '../../../core/audio/procedural_sfx_engine.dart';
import '../../../core/performance/object_pool.dart';
import '../../../core/performance/performance_settings.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../domain/combat/combat_engine.dart';
import '../../../domain/combat/combat_math.dart';
import '../../../domain/combat/combat_models.dart';
import '../../../domain/meta/card_mastery_system.dart';
import '../../../domain/meta/rune_system.dart';
import '../../../domain/meta/summoner_artifact.dart';
import '../../../domain/meta/seal_challenge_rules.dart';
import '../../../domain/meta/squad_synergy_resolver.dart';
import '../../../domain/value_objects/element.dart';
import '../../../domain/value_objects/orb_level.dart';
import '../../combat_engine/brimstone_combat_game.dart';
import '../../controllers/meta_controller.dart';
import '../../../domain/combat/verlet_sparks.dart';
import '../../graphics/combat_sparks.dart';
import '../../graphics/dynamic_camera.dart';
import '../../graphics/elemental_vfx.dart';
import '../../widgets/tcg_card_widget.dart';
import '../../widgets/overdrive_bar.dart';
import '../../widgets/gothic_modal_frame.dart';
import 'hero_skill_cut_in.dart';
import 'combat_artifact_button.dart';
import '../meta/how_to_play_modal.dart';
import '../sanctuary/settings_modal.dart';

/// Full combat screen: restructured into 4 clean touch zones.
///
/// Zone 1 (Top, 56px): Header with back button, boss name, HP bar, ? / ⚙ buttons.
/// Zone 2 (Center, Expanded): 2.5D Arena - full width, painted boss portrait (240x240), targets.
/// Zone 3 (Lower-middle, 118px): 4 Squad Cards (TcgCardWidget) with own GestureDetectors.
/// Zone 4 (Bottom, 115px): Player HP + 5 Orb 3D Tray (UNIFIED flick+drag+merge).
///
/// Drag/Merge/Flick unified (HellFire style):
/// - Single tray of 5 3D elemental orbs
/// - Pan anywhere: drag orb, follows finger freely across entire screen
/// - Flick up (dy < -30 or velocity.dy < -200): parabolic 0.22s flight with magnet to nearest target
/// - Drag lateral in tray: green merge highlights on same element+level (<3), release to merge or swap
/// - 3D orb rendering: radial gradient, specular highlight, elemental icon, "Nv.1/2/3" badge
class CombatScreen extends ConsumerStatefulWidget {
  final CombatEngine? engine;
  final void Function(bool victory, double playerHp)? onCombatResolved;
  final List<SealMutator> mutators;
  final bool showTrainingTools;

  const CombatScreen({
    super.key,
    this.engine,
    this.onCombatResolved,
    this.mutators = const [],
    this.showTrainingTools = false,
  });

  static CombatEngine buildEngine({
    required BossConfig boss,
    required List<ManaCard> cards,
    required double playerMaxHp,
    CombatModifiers modifiers = const CombatModifiers(),
    SquadSynergyBonus? synergy,
    Map<String, RuneInstance> cardRunes = const {},
    double playerDamageMult = 1.0,
    double? startHp,
    bool startManaFull = false,
    Map<String, int> talentLevels = const {},
    Map<String, int> summonerGear = const {},
    List<SealMutator> mutators = const [],
    bool trainingMode = false,
  }) =>
      CombatEngine(
        boss: boss,
        cards: cards,
        playerMaxHp: playerMaxHp,
        modifiers: modifiers,
        synergy: synergy,
        cardRunes: cardRunes,
        playerDamageMult: playerDamageMult,
        startHp: startHp,
        startManaFull: startManaFull,
        talentLevels: talentLevels,
        summonerGear: summonerGear,
        mutators: mutators,
        trainingMode: trainingMode,
      );

  @override
  ConsumerState<CombatScreen> createState() => _CombatScreenState();
}

/// A single pointer sample: position + timestamp for flick vector computation.
class _PointerSample {
  final Offset pos;
  final int timeMs;
  _PointerSample(this.pos, this.timeMs);
}

class _CombatScreenState extends ConsumerState<CombatScreen>
    with TickerProviderStateMixin {
  CombatEngine? _engine;
  late final BrimstoneCombatGame game;
  late final AnimationController _particleCtrl;
  late final AnimationController _mergePulseCtrl;
  int _lastPanMs = 0;
  bool _resolved = false;
  String? _reactionBanner;
  int _session = 0;

  // Raw pointer input state (Listener replaces GestureDetector for web mouse support)
  final GlobalKey _bodyKey = GlobalKey();
  // Arena key for precise coordinate conversion to engine space
  final GlobalKey arenaKey = GlobalKey();
  int? _draggingSlot;
  Offset? _dragStartLocal;
  Offset? _dragCurrentLocal;
  int? _hoveredMergeSlot;

  // Flick ballistics: last 5 pointer samples for computing the true flick vector.
  final List<_PointerSample> _pointerSamples = [];
  static const int _pointerSampleMax = 5;
  static const int _pointerSampleWindowMs = 80;

  // Flick hint: shown until the player launches their first orb.
  bool _showFlickHint = true;

  // Flying shot animation (Flutter overlay - 180ms parabolic flight, HellFire style)
  _FlyingShot? _flyingShot;

  // Game speed multiplier (1.0, 1.5x, 2.0x)
  double _gameSpeed = 1.0;
  // Set to true after Chapter I cleared (future feature gate)
  final bool _speed2xUnlocked = false;

  // Block 3: Auto-Battle state
  bool _autoBattleEnabled = false;

  // Flying projectile for visual 0.22s parabolic flight
  _FlyingOrbProjectile? _flyingProjectile;

  // HellFire visual identity elements
  late final List<_ManaOrbParticle> _manaOrbParticles;
  int _chapterColorIndex = 0;

  // Cinematic hero invocation banner (0.55 s, non-blocking).
  HeroCutInData? _cutIn;

  // Elemental impact barrage that lands with the cut-in (0.70 s).
  int _barrageToken = 0;
  Element _barrageElement = Element.igneous;

  // Break shockwave (Bullseye Lv3 / reaction / seal rupture).
  int _shockToken = 0;

  // Secuencia de muerte del jefe: grietas + brasas + banner dorado.
  int _shatterToken = 0;

  // Artefacto del Invocador equipado (5to botón táctico).
  SummonerArtifact? _equippedArtifact;

  // Studio Edition: cinematic camera + bouncing Verlet sparks.
  final DynamicCombatCamera _camera = DynamicCombatCamera();
  final VerletSparkPool _sparks = VerletSparkPool(capacity: 96);
  late final Ticker _fxTicker;
  Duration _fxElapsed = Duration.zero;
  final ValueNotifier<double> _fxClock = ValueNotifier<double>(0);

  // Keyboard support for PC (Pilar 2)
  late final FocusNode _focusNode;
  bool _showKeyboardHints = false;

  CombatEngine get engine => _engine!;

  late final FixedRingBuffer<_BurstEffect> _bursts;

  void _addBurst(double x, double y, Color color) {
    _bursts.add(_BurstEffect(x: x, y: y, color: color));
    _particleCtrl.forward(from: 0);
  }

  Color _elementColor(Element e) => switch (e) {
        Element.igneous => const Color(0xFFFF5A26),
        Element.abyssal => const Color(0xFF3FD8FF),
        Element.telluric => const Color(0xFFB0703B),
        Element.empty => const Color(0xFFB16EFF),
      };

  Color _elementAccent(Element e) => switch (e) {
        Element.igneous => const Color(0xFFFFD980),
        Element.abyssal => const Color(0xFF80E8FF),
        Element.telluric => const Color(0xFFF0D0A0),
        Element.empty => const Color(0xFFE5D4FF),
      };

  // HellFire: Map element to chapter color index for visual identity
  int _elementToChapterIndex(Element e) => switch (e) {
        Element.igneous => 0, // lava
        Element.abyssal => 1, // ice
        Element.telluric => 2, // emerald
        Element.empty => 3, // purple (void) or 4 for chapter 5 crimson gold
      };

  // HellFire: Get chapter color for visual identity
  Color _chapterColor() {
    const chapterColors = [
      Color(0xFFFF5A26), // Chapter 1 - Igneo (Lava)
      Color(0xFF3FD8FF), // Chapter 2 - Abyssal (Ice)
      Color(0xFF4FFFA3), // Chapter 3 - Telluric (Emerald)
      Color(0xFFB16EFF), // Chapter 4 - Void (Purple)
      Color(0xFFFFC93C), // Chapter 5 - Broken Seal (Crimson Gold)
    ];
    return chapterColors[_chapterColorIndex.clamp(0, chapterColors.length - 1)];
  }

  // HellFire: Spawn 3 mana orb particles from hit target to matching-element squad cards
  void _spawnManaOrbParticles(double startX, double startY, Element element) {
    if (engine.cards.isEmpty) return;

    // Find squad cards matching the element
    final matchingIndices = <int>[];
    for (var i = 0; i < engine.cards.length; i++) {
      if (engine.cards[i].element == element) {
        matchingIndices.add(i);
      }
    }
    if (matchingIndices.isEmpty) return;

    // Spawn 3 particles per hit, distributed among matching cards
    for (var i = 0; i < 3; i++) {
      final targetIndex = matchingIndices[i % matchingIndices.length];

      // Calculate card position on screen
      final cardScreenX = _cardScreenX(targetIndex);
      final cardScreenY = _cardScreenY();

      _manaOrbParticles.add(_ManaOrbParticle(
        startX: startX,
        startY: startY,
        targetX: cardScreenX,
        targetY: cardScreenY,
        element: element,
        progress: 0.0,
        duration: 0.32,
      ));
    }
  }

  // Helper to get card screen X position
  double _cardScreenX(int index) {
    final cardWidth = 112.0;
    final spacing = 8.0;
    final startX =
        (MediaQuery.of(context).size.width - (4 * cardWidth + 3 * spacing)) / 2;
    return startX + index * (cardWidth + spacing) + cardWidth / 2;
  }

  // Helper to get card screen Y position
  double _cardScreenY() {
    // Cards are in the bottom zone (Zone 3), roughly at screen height - 118 + 56 (center of card)
    return MediaQuery.of(context).size.height - 118 + 56;
  }

  @override
  void initState() {
    super.initState();
    _bursts = FixedRingBuffer<_BurstEffect>(
      PerformanceSettings.maxParticleBursts,
    );
    _manaOrbParticles = [];
    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _particleCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _bursts.clear());
      }
    });
    _mergePulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    // Dynamic score: ritual war drums replace the Sanctuary choir.
    _fxTicker = createTicker(_onFxTick)..start();
    ProceduralSfxEngine.startAmbient('boss_pulse');
    _initEngine();
    _loadEquippedArtifact();

    // Keyboard support for PC (Pilar 2)
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
        final width = MediaQuery.of(context).size.width;
        setState(() => _showKeyboardHints = width > 560);
      }
    });
  }

  @override
  void dispose() {
    ProceduralSfxEngine.startAmbient('drone');
    _fxTicker.dispose();
    _fxClock.dispose();
    _particleCtrl.dispose();
    _mergePulseCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Carga (una sola vez) el artefacto fabricado Y equipado por el jugador.
  Future<void> _loadEquippedArtifact() async {
    try {
      final (crafted, equipped) =
          await ref.read(playerRepositoryProvider).loadArtifacts();
      if (!mounted) return;
      final matches = equipped == null
          ? const <SummonerArtifact>[]
          : summonerArtifacts.where((a) => a.id == equipped).toList();
      setState(() {
        _equippedArtifact = crafted.contains(equipped) && matches.isNotEmpty
            ? matches.first
            : null;
      });
    } catch (_) {}
  }

  /// Usa el artefacto equipado si está listo (el motor arma el cooldown).
  void _useEquippedArtifact() {
    final artifact = _equippedArtifact;
    if (artifact == null) return;
    if (!(_engine?.useArtifact(artifact) ?? false)) return;
    ProceduralSfxEngine.playCardSkillInvoke();
    setState(() {});
  }

  // Keyboard shortcuts for PC (Pilar 2)
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    // 1-4: Invoke card skill if mana is full
    if (key == LogicalKeyboardKey.digit1) {
      _tryInvokeCard(0);
    } else if (key == LogicalKeyboardKey.digit2) {
      _tryInvokeCard(1);
    } else if (key == LogicalKeyboardKey.digit3) {
      _tryInvokeCard(2);
    } else if (key == LogicalKeyboardKey.digit4) {
      _tryInvokeCard(3);
    }
    // Q or E: Use equipped artifact
    else if (key == LogicalKeyboardKey.keyQ || key == LogicalKeyboardKey.keyE) {
      _useEquippedArtifact();
    }
    // Space: Auto-merge all
    else if (key == LogicalKeyboardKey.space) {
      _autoMergeAll();
    }
    // A: Toggle auto-battle
    else if (key == LogicalKeyboardKey.keyA) {
      setState(() {
        _autoBattleEnabled = !_autoBattleEnabled;
        _engine?.autoBattleEnabled = _autoBattleEnabled;
      });
    }
    // S or Tab: Cycle game speed 1x -> 1.5x -> 2x (if unlocked)
    else if (key == LogicalKeyboardKey.keyS || key == LogicalKeyboardKey.tab) {
      _cycleGameSpeed();
    }
    // Esc: Pause/settings
    else if (key == LogicalKeyboardKey.escape) {
      _showPauseMenu();
    }
    return KeyEventResult.handled;
  }

  void _tryInvokeCard(int index) {
    if (index >= engine.cards.length) return;
    final card = engine.cards[index];
    if (card.mana >= card.baseManaCost) {
      _onCardTap(index);
    }
  }

  void _cycleGameSpeed() {
    const speeds = [1.0, 1.5, 2.0];
    final currentIndex = speeds.indexOf(_gameSpeed);
    final nextIndex = (currentIndex + 1) % speeds.length;
    final nextSpeed = speeds[nextIndex];
    // Only allow 2x if unlocked (after Chapter I)
    if (nextSpeed == 2.0 && !_speed2xUnlocked) return;
    setState(() => _gameSpeed = nextSpeed);
    // game.speedMultiplier is final (set in constructor); _gameSpeed is used for display
  }

  void _showPauseMenu() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF14090D),
        title: const Text('PAUSA',
            style: TextStyle(
                color: Color(0xFFB16EFF), fontWeight: FontWeight.w900)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CONTINUAR',
                style: TextStyle(color: Color(0xFFB16EFF))),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              showDialog(
                context: context,
                builder: (_) => const SettingsModal(),
              );
            },
            child: const Text('AJUSTES',
                style: TextStyle(color: Color(0xFFB16EFF))),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).maybePop();
            },
            child:
                const Text('SALIR', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  @override
  void didUpdateWidget(CombatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.engine, widget.engine)) {
      _resolved = false;
      _initEngine();
    }
  }

  /// 60 fps driver for the cinematic camera, the bouncing sparks and the
  /// OVERDRIVE rail (they must animate even while the game is slow-mo'd).
  void _onFxTick(Duration elapsed) {
    final dt = ((elapsed - _fxElapsed).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _fxElapsed = elapsed;
    if (dt <= 0 || _engine == null) return;
    _camera.tick(
      dt,
      aiming: _aimingLevelThree,
      bossBroken: engine.bossShieldBroken || engine.overdriveActive,
    );
    _sparks.update(dt, floorY: CombatEngine.trayY - 34);
    _fxClock.value = _fxClock.value + dt;
  }

  /// True while a level-3 orb is dragged above the tray: the aim laser ignites
  /// and the camera leans into the targets.
  bool get _aimingLevelThree {
    final slot = _draggingSlot;
    if (slot == null || _engine == null) return false;
    final orb = engine.tray[slot];
    if (orb == null || orb.level != OrbLevel.three) return false;
    return engine.dragY < CombatEngine.trayY - 120;
  }

  Future<void> _initEngine() async {
    final base = widget.engine ?? defaultEngine();
    final cards = base.cards;
    final synergy = SquadSynergyResolver.resolve(cards);
    final cardRunes = <String, RuneInstance>{};
    cardRunes.addAll(base.cardRunes);
    if (cardRunes.isEmpty) {
      final repo = ref.read(playerRepositoryProvider);
      for (final c in cards) {
        try {
          final rune = await repo.loadCardRune(c.hashCode);
          if (rune != null) cardRunes[c.id] = rune;
        } catch (_) {}
      }
    }
    if (!mounted) return;
    final mutators =
        widget.mutators.isNotEmpty ? widget.mutators : base.mutators;
    _engine = CombatEngine(
      boss: base.boss,
      cards: cards,
      playerMaxHp: base.playerMaxHp,
      modifiers: base.modifiers,
      synergy: synergy.isActive ? synergy : null,
      cardRunes: cardRunes,
      playerDamageMult: base.playerDamageMult,
      talentLevels: base.talents.levels,
      summonerGear: base.gear.levels,
      mutators: mutators,
      trainingMode: base.trainingMode,
      startManaFull: base.trainingMode,
    );
    // HellFire: Set chapter color index based on boss element for visual identity
    _chapterColorIndex = _elementToChapterIndex(_engine!.boss.element);
    _engine!.onHit = (kind, damage, x, y, element) {
      switch (kind) {
        case HitKind.bullseye:
          ProceduralSfxEngine.playHitBullseye();
          ref.read(bountyProvider.notifier).increment('bullseye_hits');
          // Lv3 (streak >= 3) detonates the GPU break shockwave.
          if ((_engine?.bullseyeStreak ?? 0) >= 3 && mounted) {
            setState(() => _shockToken++);
          }
        case HitKind.graze:
          ProceduralSfxEngine.playHitGraze();
        case HitKind.normal:
          ProceduralSfxEngine.playHitNormal();
        case HitKind.miss:
          break;
      }
      _addBurst(x, y, _elementColor(element));
      final crit = kind == HitKind.bullseye;
      if (crit || kind == HitKind.normal || kind == HitKind.graze) {
        _sparks.burst(
          x: x,
          y: y,
          random: engine.random,
          count: crit ? 18 : 8,
          speed: crit ? 340 : 210,
          baseAngle: -math.pi / 2,
          spreadRadians: math.pi * 1.4,
          life: crit ? 0.7 : 0.5,
          size: crit ? 2.8 : 2.0,
        );
        if (crit) _camera.punch();
      }

      // HellFire: Spawn 3 mana orb particles flying from hit target to matching-element squad cards
      _spawnManaOrbParticles(x, y, element);

      if (mounted) setState(() {});
    };
    _engine!.onReaction = (name) {
      ProceduralSfxEngine.playElementalReaction();
      ref.read(bountyProvider.notifier).increment('reactions');
      recordCodexReaction(ref, name);
      setState(() {
        _reactionBanner = name;
        _shockToken++;
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _reactionBanner = null);
      });
    };
    _engine!.onMerge = (level, x, y, element) {
      ProceduralSfxEngine.playOrbMerge(level.index);
      if (level == OrbLevel.three) {
        ref.read(bountyProvider.notifier).increment('merge_to_three');
      }
      _addBurst(x, y, _elementColor(element));
      if (mounted) setState(() {});
    };
    _engine!.onEnrage = () {
      ProceduralSfxEngine.playBossEnrage();
    };
    _engine!.onShieldBreak = () {
      ProceduralSfxEngine.playShieldBreak();
      if (mounted) setState(() => _shockToken++);
    };
    _engine!.onOverdriveStart = () {
      ProceduralSfxEngine.playLevelUp();
      _camera.punch(0.1);
      if (mounted) setState(() => _shockToken++);
    };
    // AAA cut-in: fires for manual taps and AUTO battle alike.
    _engine!.onSkillCast = (card, index) {
      if (!mounted) return;
      setState(() {
        _cutIn = HeroCutInData(
          heroId: card.id,
          heroName: card.name,
          skillName: (CombatEngine.skillDescriptions[card.id] ?? card.name)
              .split(' + ')
              .first,
          element: card.element,
        );
        // Elemental barrage lands while the cut-in band crosses the arena.
        _barrageElement = card.element;
        _barrageToken++;
      });
    };
    _engine!.onTrayChanged = () {
      if (mounted) setState(() {});
    };
    // Block 3: Sync auto-battle state.
    _engine!.autoBattleEnabled = _autoBattleEnabled;
    game = BrimstoneCombatGame(
      engine: _engine!,
      onVictory: () => _resolve(true),
      onDefeat: () => _resolve(false),
      speedMultiplier: _gameSpeed,
    );
    setState(() {});
  }

  Future<void> _resolve(bool victory) async {
    if (_resolved) return;
    _resolved = true;
    if (victory) {
      // Slow-mo is already armed by the engine; fire the shatter spectacle and
      // let the 650 ms sequence breathe before the loot/summary dialog.
      ProceduralSfxEngine.playShieldBreak();
      if (mounted) setState(() => _shatterToken++);
      await Future<void>.delayed(const Duration(milliseconds: 700));
    }
    if (engine.trainingMode) {
      await _showTrainingResult(victory);
      return;
    }
    await ref.read(playerRepositoryProvider).recordCombatResult(
          victory: victory,
          damageTotal: engine.damageTotal,
          maxHit: engine.maxHit.toInt(),
          bullseyes: engine.bullseyes,
          bestBullseyeStreak: engine.bestBullseyeStreak,
          reactions: engine.reactions,
          counterflicks: engine.counterflicks,
          bossKilled: victory,
        );
    // Grant Mastery XP to squad cards on victory (Block 1).
    if (victory) {
      final repo = ref.read(playerRepositoryProvider);
      final collection = await repo.loadCollection();
      final collectionById = {for (final c in collection) c.instanceId: c};
      final squad = await repo.loadSquad();
      // Determine if this was a boss fight by checking boss ID.
      final bossId = engine.boss.id;
      final isBoss = bossId.contains('boss') ||
          bossId.contains('elite') ||
          bossId.contains('chapter') ||
          bossId.contains('titan') ||
          bossId == 'pyroth' ||
          bossId == 'vaelor' ||
          bossId == 'gorgath' ||
          bossId == 'azathor' ||
          bossId == 'nyxara' ||
          engine.boss.maxHp > 1000;
      await grantMasteryXpToSquad(
        squadInstanceIds: squad,
        collectionById: collectionById,
        isBoss: isBoss,
        repo: repo,
      );
    }
    if (!mounted) return;
    await _showCombatSummary(victory);
    widget.onCombatResolved?.call(victory, engine.playerHp);
  }

  Future<void> _showCombatSummary(bool victory) => showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => CombatSummaryDialog(
          victory: victory,
          damageTotal: engine.damageTotal,
          maxHit: engine.maxHit,
          bullseyes: engine.bullseyes,
          reactions: engine.reactions,
          counterflicks: engine.counterflicks,
          mergesToThree: engine.mergesToThree,
          bestStreak: engine.bestBullseyeStreak,
          damageByCard: Map<String, int>.of(engine.damageByCard),
          cardNames: {for (final c in engine.cards) c.id: c.name},
          mvpCardId: engine.mvpCardId,
        ),
      );

  Future<void> _showTrainingResult(bool victory) async {
    final text = victory
        ? '¡Gólem de Pruebas destruido! DPS final: ${engine.dps.toStringAsFixed(1)}'
        : 'El Gólem de Pruebas te superó. DPS final: ${engine.dps.toStringAsFixed(1)}';
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF14090D),
        title: const Text(
          'ARENA DE ENTRENAMIENTO',
          style: TextStyle(
            color: Color(0xFF3FD8FF),
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
        content: Text(text, style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('SEGUIR PRACTICANDO',
                style: TextStyle(color: Color(0xFFB16EFF))),
          ),
        ],
      ),
    );
    if (!mounted) return;
    _restartTraining();
  }

  void _restartTraining() {
    _resolved = false;
    setState(() => _session++);
    _initEngine();
  }

  // Auto-merge all available pairs in tray
  void _autoMergeAll() {
    var merged = false;
    for (var i = 0; i < engine.tray.length; i++) {
      if (engine.tray[i] == null) continue;
      for (var j = i + 1; j < engine.tray.length; j++) {
        if (engine.tray[j] == null) continue;
        final orbA = engine.tray[i]!;
        final orbB = engine.tray[j]!;
        final compatible = (orbA.element == orbB.element ||
                orbA.prismatic ||
                orbB.prismatic) &&
            orbA.level == orbB.level &&
            orbA.level != OrbLevel.three;
        if (compatible) {
          engine.mergeOrbs(i, j);
          merged = true;
          break;
        }
      }
      if (merged) break;
    }
    if (merged) {
      ProceduralSfxEngine.playOrbMerge(2);
      setState(() {});
    }
  }

  // Raw pointer input handlers (Listener-based for web mouse support)
  void _onPointerDown(PointerDownEvent event) {
    if (!mounted || _engine == null) return;
    final arenaBox = arenaKey.currentContext?.findRenderObject() as RenderBox?;
    if (arenaBox == null) return;
    final arenaLocal = arenaBox.globalToLocal(event.position);
    final arenaSize = arenaBox.size;

    // Check if started on orb tray (bottom ~115px of body, but we need body coords for tray)
    final bodyBox = _bodyKey.currentContext?.findRenderObject() as RenderBox?;
    if (bodyBox == null) return;
    final bodyLocal = bodyBox.globalToLocal(event.position);
    final bodyHeight = bodyBox.size.height;

    // Counter-flick priority: any pointer over arena destroys projectiles
    if (arenaLocal.dy < arenaSize.height * 0.7) {
      final (engX, engY) = arenaLocalToEngine(arenaLocal, arenaSize);
      engine.counterFlickAt(engX, engY, engine.time);
      return;
    }

    // Check if started on orb tray (bottom 115px of body)
    if (bodyLocal.dy >= bodyHeight - 115) {
      final bodyWidth = bodyBox.size.width;
      final slot = (bodyLocal.dx / (bodyWidth / 5)).floor().clamp(0, 4);
      if (engine.tray[slot] != null) {
        // Start flick sample tracking
        _pointerSamples.clear();
        _pointerSamples.add(
            _PointerSample(bodyLocal, DateTime.now().millisecondsSinceEpoch));

        setState(() {
          _draggingSlot = slot;
          _dragStartLocal = bodyLocal;
          _dragCurrentLocal = bodyLocal;
        });
        game.draggingOrb = true;
        final (engX, engY) = arenaLocalToEngine(arenaLocal, arenaSize);
        engine.startDrag(slot, engX, engY);
      }
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!mounted || _engine == null) return;
    final arenaBox = arenaKey.currentContext?.findRenderObject() as RenderBox?;
    final bodyBox = _bodyKey.currentContext?.findRenderObject() as RenderBox?;
    if (arenaBox == null || bodyBox == null) return;

    final arenaLocal = arenaBox.globalToLocal(event.position);
    final arenaSize = arenaBox.size;
    final bodyLocal = bodyBox.globalToLocal(event.position);
    final bodyHeight = bodyBox.size.height;

    // Counter-flick over arena (any pointer move in arena zone)
    if (arenaLocal.dy < arenaSize.height * 0.7) {
      final (engX, engY) = arenaLocalToEngine(arenaLocal, arenaSize);
      engine.counterFlickAt(engX, engY, engine.time);
    }

    // Record pointer sample for flick vector computation
    _pointerSamples
        .add(_PointerSample(bodyLocal, DateTime.now().millisecondsSinceEpoch));
    if (_pointerSamples.length > _pointerSampleMax) {
      _pointerSamples.removeAt(0);
    }

    // Update drag preview
    if (_draggingSlot != null) {
      setState(() => _dragCurrentLocal = bodyLocal);

      final (engX, engY) = arenaLocalToEngine(arenaLocal, arenaSize);
      engine.updateDrag(engX, engY,
          (DateTime.now().millisecondsSinceEpoch - _lastPanMs) / 1000.0);
      _lastPanMs = DateTime.now().millisecondsSinceEpoch;

      // Update merge hover target (only when in tray zone)
      if (bodyLocal.dy >= bodyHeight - 115) {
        final bodyWidth = bodyBox.size.width;
        final slot = (bodyLocal.dx / (bodyWidth / 5)).floor().clamp(0, 4);
        if (slot != _draggingSlot && engine.tray[slot] != null) {
          final draggedOrb = engine.tray[_draggingSlot!]!;
          final targetOrb = engine.tray[slot]!;
          final compatible = (draggedOrb.element == targetOrb.element ||
                  draggedOrb.prismatic ||
                  targetOrb.prismatic) &&
              draggedOrb.level == targetOrb.level &&
              draggedOrb.level != OrbLevel.three;
          if (compatible) {
            setState(() => _hoveredMergeSlot = slot);
          }
        }
      } else {
        setState(() => _hoveredMergeSlot = null);
      }
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (!mounted || _engine == null || _draggingSlot == null) return;
    final arenaBox = arenaKey.currentContext?.findRenderObject() as RenderBox?;
    final bodyBox = _bodyKey.currentContext?.findRenderObject() as RenderBox?;
    if (arenaBox == null || bodyBox == null) return;

    final arenaSize = arenaBox.size;
    final bodyWidth = bodyBox.size.width;
    final scaleX = arenaSize.width / CombatEngine.layoutWidth;
    final scaleY = arenaSize.height / CombatEngine.layoutHeight;

    final draggedSlot = _draggingSlot!;
    final dragStart = _dragStartLocal ?? Offset.zero;
    final dragEnd = _dragCurrentLocal ?? Offset.zero;

    final totalDx = dragEnd.dx - dragStart.dx;
    final totalDy = dragEnd.dy - dragStart.dy;
    final isFlickUp = totalDy < -20; // flicked upward from tray

    if (isFlickUp) {
      // --- TRUE FLICK BALLISTICS (HellFire style) ---
      // Compute flick vector from samples in the last 80ms before release.
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final recent = _pointerSamples
          .where((s) => nowMs - s.timeMs <= _pointerSampleWindowMs)
          .toList();

      double flickDx, flickDy, speedPxPerSec;
      if (recent.length >= 2) {
        final first = recent.first;
        final last = recent.last;
        flickDx = last.pos.dx - first.pos.dx;
        flickDy = last.pos.dy - first.pos.dy;
        final dtSec = (last.timeMs - first.timeMs) / 1000.0;
        speedPxPerSec = dtSec > 0
            ? math.sqrt(flickDx * flickDx + flickDy * flickDy) / dtSec
            : 0.0;
      } else {
        flickDx = totalDx;
        flickDy = totalDy;
        speedPxPerSec = 0.0;
      }

      // Potencia del latigazo: velocidad y/o distancia vertical.
      final powerBySpeed = (speedPxPerSec / 900.0).clamp(0.55, 1.35);
      final powerByDist = (-totalDy / 180.0).clamp(0.55, 1.25);
      final power = math.max(powerBySpeed, powerByDist);

      // Dirección normalizada del gesto corto.
      final flickDist = math.sqrt(flickDx * flickDx + flickDy * flickDy);
      final dirX = flickDist > 0 ? flickDx / flickDist : 0.0;
      final dirY = flickDist > 0 ? flickDy / flickDist : -1.0;

      // Punto de inicio del orbe en pantalla (centro del slot de bandeja).
      final orbStartScreenX =
          (CombatEngine.layoutWidth / 5 * (draggedSlot + 0.5)) * scaleX;
      final orbStartScreenY = CombatEngine.trayY * scaleY;

      // Distancia vertical desde la bandeja al plano del jefe.
      final distanciaVerticalAlJefe =
          CombatEngine.bossScreenY * scaleY - orbStartScreenY;

      // Proyección del punto de aterrizaje en la arena.
      final landingX = orbStartScreenX +
          (flickDx / (-flickDy).clamp(15.0, 400.0)) * distanciaVerticalAlJefe;
      final landingY = CombatEngine.bossScreenY * scaleY +
          (power - 1.0) * 50.0; // offset según potencia

      // --- Asistencia magnética inteligente ---
      // Busca dianas cerca del rayo lanzado desde orbStart en dirección (dirX, dirY).
      CombatTarget? magnetTarget;
      var magnetBestDist = double.infinity;
      for (final t in engine.targets) {
        final tx = t.xAt(engine.time, engine.effectiveAngularSpeed(t)) * scaleX;
        final ty = t.yAt(engine.time, engine.effectiveAngularSpeed(t)) * scaleY;

        // Distancia perpendicular del punto al rayo (orbStart + t*dir).
        final rx = tx - orbStartScreenX;
        final ry = ty - orbStartScreenY;
        // Proyector: t_param = (rx*dirX + ry*dirY), punto más cercano = orbStart + t_param*dir
        final tParam = rx * dirX + ry * dirY;
        if (tParam < 0) continue; // diana detrás del punto de partida
        final closestX = orbStartScreenX + tParam * dirX;
        final closestY = orbStartScreenY + tParam * dirY;
        final perpDist = math.sqrt((tx - closestX) * (tx - closestX) +
            (ty - closestY) * (ty - closestY));
        final distToLanding = math.sqrt((tx - landingX) * (tx - landingX) +
            (ty - landingY) * (ty - landingY));

        if ((perpDist < 75.0 || distToLanding < 95.0) &&
            (perpDist + distToLanding * 0.5) < magnetBestDist) {
          magnetBestDist = perpDist + distToLanding * 0.5;
          magnetTarget = t;
        }
      }

      // Si hay magnética, clava el aterrizaje en el centro de la diana.
      double impactEngX, impactEngY;
      HitKind hitKind;
      CombatTarget? impactTarget;
      if (magnetTarget != null) {
        impactEngX = magnetTarget.xAt(
            engine.time, engine.effectiveAngularSpeed(magnetTarget));
        impactEngY = magnetTarget.yAt(
            engine.time, engine.effectiveAngularSpeed(magnetTarget));
        impactTarget = magnetTarget;
        hitKind = CombatMath.classifyHit(
            0.0,
            engine.innerRadiusFor(magnetTarget),
            engine.outerRadiusFor(magnetTarget));
      } else {
        // Sin diana en el camino: convertir landing a engine coords.
        final (leX, leY) = (landingX / scaleX, landingY / scaleY);
        impactEngX = leX;
        impactEngY = leY;
        impactTarget = null;
        hitKind = HitKind.miss;
      }

      // Remover orbe de la bandeja inmediatamente.
      final orb = engine.tray[draggedSlot];
      if (orb == null) {
        game.draggingOrb = false;
        setState(() {
          _draggingSlot = null;
          _dragStartLocal = null;
          _dragCurrentLocal = null;
          _hoveredMergeSlot = null;
          _pointerSamples.clear();
        });
        return;
      }
      engine.tray[draggedSlot] = null;
      ProceduralSfxEngine.playOrbFlick();

      // Ocultar hint del flick tras el primer disparo.
      if (_showFlickHint) {
        setState(() => _showFlickHint = false);
      }

      // Animación de vuelo (180ms) + daño inmediato.
      startFlyingShot(
        draggedSlot,
        impactEngX,
        impactEngY,
        orbStartScreenX,
        orbStartScreenY,
        landingX,
        landingY,
        hitKind,
        impactTarget,
        orb.element,
        orb.level,
      );
    } else {
      // DRAG END: Check for merge or swap in tray
      final targetSlot = (dragEnd.dx / (bodyWidth / 5)).floor().clamp(0, 4);
      if (targetSlot != draggedSlot) {
        final targetOrb = engine.tray[targetSlot];
        final draggedOrb = engine.tray[draggedSlot];
        if (targetOrb != null && draggedOrb != null) {
          final compatible = (draggedOrb.element == targetOrb.element ||
                  draggedOrb.prismatic ||
                  targetOrb.prismatic) &&
              draggedOrb.level == targetOrb.level &&
              draggedOrb.level != OrbLevel.three;
          if (compatible) {
            engine.mergeOrbs(draggedSlot, targetSlot);
            ProceduralSfxEngine.playOrbMerge(targetOrb.level.index);
          } else {
            engine.swapOrbs(draggedSlot, targetSlot);
            ProceduralSfxEngine.playOrbSpawn();
          }
        } else if (targetOrb == null) {
          engine.swapOrbs(draggedSlot, targetSlot);
          ProceduralSfxEngine.playOrbSpawn();
        }
      }
    }

    game.draggingOrb = false;
    setState(() {
      _draggingSlot = null;
      _dragStartLocal = null;
      _dragCurrentLocal = null;
      _hoveredMergeSlot = null;
      _pointerSamples.clear();
    });
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (!mounted || _draggingSlot == null) return;
    game.draggingOrb = false;
    setState(() {
      _draggingSlot = null;
      _dragStartLocal = null;
      _dragCurrentLocal = null;
      _hoveredMergeSlot = null;
    });
  }

  /// Convert arena-local coordinates to engine logical coordinates
  (double, double) arenaLocalToEngine(Offset arenaLocal, Size arenaSize) {
    // Engine uses fixed layout: 430x932
    // Arena widget fills the Expanded area, so we scale
    final scaleX = CombatEngine.layoutWidth / arenaSize.width;
    final scaleY = CombatEngine.layoutHeight / arenaSize.height;
    return (arenaLocal.dx * scaleX, arenaLocal.dy * scaleY);
  }

  // Start flying shot animation in Flutter overlay (180ms parabolic flight, HellFire style)
  void startFlyingShot(
    int slot,
    double impactEngX,
    double impactEngY,
    double startScreenX,
    double startScreenY,
    double targetScreenX,
    double targetScreenY,
    HitKind hitKind,
    CombatTarget? target,
    Element element,
    OrbLevel level,
  ) {
    // Orb ya removido de la bandeja por el llamante; asegurar consistencia.
    engine.tray[slot] = null;

    // Configurar animación de vuelo (screen coords)
    final arenaBox = arenaKey.currentContext?.findRenderObject() as RenderBox?;
    if (arenaBox != null) {
      setState(() {
        _flyingShot = _FlyingShot(
          element: element,
          level: level,
          startX: startScreenX,
          startY: startScreenY,
          targetX: targetScreenX,
          targetY: targetScreenY,
          hitKind: hitKind,
          target: target,
          impactEngX: impactEngX,
          impactEngY: impactEngY,
          startTime: DateTime.now().millisecondsSinceEpoch,
        );
      });
    }

    // Aplicar daño inmediatamente (HellFire: daño al impactar, no ligado al frame de render)
    if (target != null) {
      engine.registerDamage(
        orb: CombatOrb(
          id: 'flying_shot_${DateTime.now().millisecondsSinceEpoch}',
          element: element,
          level: level,
          prismatic: false,
        ),
        target: target,
        multiplier: hitKind == HitKind.bullseye ? 1.5 : 1.0,
        kind: hitKind,
      );
    } else {
      engine.bullseyeStreak = 0;
    }
    if (mounted) setState(() => _flyingShot = null);
  }

  void _onCardTap(int index) {
    if (engine.castSkill(index)) {
      final card = engine.cards[index];
      final skillDesc = CombatEngine.skillDescriptions[card.id] ?? card.id;
      debugPrint('¡${card.name} USA $skillDesc!');
      ProceduralSfxEngine.playCardSkillInvoke();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_engine == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0C0608),
        body:
            Center(child: CircularProgressIndicator(color: Color(0xFFB16EFF))),
      );
    }

    final isDesktop = MediaQuery.of(context).size.width > 560;

    return Scaffold(
      backgroundColor: const Color(0xFF0C0608),
      body: Focus(
        focusNode: _focusNode,
        onKeyEvent: (node, event) => _handleKeyEvent(node, event),
        child: Stack(
          children: [
            Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              onPointerCancel: _onPointerCancel,
              child: Column(
                key: _bodyKey,
                children: [
                  // ZONE 1: HEADER (56px)
                  SizedBox(height: 56, child: _buildHeader()),

                  // ZONE 2: ARENA (Expanded, FULL WIDTH)
                  Expanded(
                    key: arenaKey,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: AnimatedBuilder(
                            animation: _fxClock,
                            builder: (context, _) => Transform.scale(
                              scale: _camera.scale,
                              alignment: Alignment.bottomCenter,
                              child: ClipRect(child: GameWidget(game: game)),
                            ),
                          ),
                        ),
                        // Peripheral vignette that closes in with the tactical zoom.
                        Positioned.fill(
                          child: AnimatedBuilder(
                            animation: _fxClock,
                            builder: (context, _) =>
                                CombatVignette(strength: _camera.vignette),
                          ),
                        ),
                        // Live boss afflictions floating over its portrait.
                        Positioned(
                          top: 6,
                          left: 10,
                          right: 10,
                          child: IgnorePointer(
                            child: _BossStatusBar(engine: engine),
                          ),
                        ),
                        if (engine.scoreTarget != null)
                          Positioned(
                            top: 44,
                            left: 12,
                            right: 12,
                            child: IgnorePointer(
                              child: AnimatedBuilder(
                                animation: _fxClock,
                                builder: (context, _) =>
                                    _DuelScoreboard(engine: engine),
                              ),
                            ),
                          ),
                        // HellFire: Dimensional Rift Archway - stone pillars with elemental energy veins
                        Positioned.fill(
                            child: _RiftArchwayPillars(
                                chapterColor: _chapterColor())),
                        // Particle bursts
                        if (_bursts.isNotEmpty)
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _BurstsPainter(
                                bursts: _bursts,
                                progress: _particleCtrl.value,
                                ringsPerBurst:
                                    PerformanceSettings.ringsPerBurst,
                                scale: PerformanceSettings.particleScale,
                              ),
                            ),
                          ),
                        // HellFire: Mana Orb Particles flying to squad cards
                        if (_manaOrbParticles.isNotEmpty)
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _ManaOrbParticlesPainter(
                                  particles: _manaOrbParticles),
                            ),
                          ),
                        // Flying projectile
                        if (_flyingProjectile != null)
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _FlyingProjectilePainter(
                                projectile: _flyingProjectile!,
                                game: game,
                              ),
                            ),
                          ),
                        // Flying shot animation (Flutter overlay)
                        if (_flyingShot != null)
                          Positioned.fill(
                            child: AnimatedBuilder(
                              animation: _fxClock,
                              builder: (context, _) {
                                return CustomPaint(
                                  painter: _FlyingShotPainter(
                                    shot: _flyingShot!,
                                    arenaSize: arenaKey.currentContext
                                            ?.findRenderObject()
                                            ?.paintBounds
                                            .size ??
                                        Size.zero,
                                    targets: engine.targets,
                                    engineTime: engine.time,
                                    effectiveAngularSpeed:
                                        engine.effectiveAngularSpeed,
                                  ),
                                );
                              },
                            ),
                          ),
                        // Drag preview: orb following pointer + aim line
                        if (_draggingSlot != null && _dragCurrentLocal != null)
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _DragPreviewPainter(
                                dragCurrent: _dragCurrentLocal!,
                                dragStart: _dragStartLocal ?? Offset.zero,
                                slot: _draggingSlot!,
                                orb: engine.tray[_draggingSlot!],
                                arenaKey: arenaKey,
                                engine: engine,
                                hoveredMergeSlot: _hoveredMergeSlot,
                              ),
                            ),
                          ),
                        // Danger overlay
                        Positioned.fill(
                          child: IgnorePointer(
                              child: _CombatDangerOverlay(engine: engine)),
                        ),
                        // Boss shatter: white flash, light cracks, rising embers
                        // and the gilded "¡SELLO PURIFICADO!" banner.
                        Positioned.fill(
                          child: BossShatterOverlay(
                            token: _shatterToken,
                            portraitId: engine.boss.id,
                            element: engine.boss.element,
                          ),
                        ),
                        // Elemental barrage (700 ms) landing with the cut-in.
                        Positioned.fill(
                          child: ElementalBarrage(
                            token: _barrageToken,
                            element: _barrageElement,
                          ),
                        ),
                        // GPU break shockwave (bullseye Lv3, reaction, seal break).
                        Positioned.fill(
                          child: BreakShockwave(
                            token: _shockToken,
                            color: _elementColor(_barrageElement),
                          ),
                        ),
                        // Verlet sparks with gravity + stone-lip bounce.
                        Positioned.fill(
                          child: IgnorePointer(
                            child: AnimatedBuilder(
                              animation: _fxClock,
                              builder: (context, _) => CustomPaint(
                                painter: SparkPoolPainter(
                                  pool: _sparks,
                                  color: _elementColor(_barrageElement),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Arcane beam shader: predictive aim + BREAK chains.
                        Positioned.fill(
                          child: IgnorePointer(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final s = constraints.maxWidth /
                                    CombatEngine.layoutWidth;
                                final dy = (constraints.maxHeight -
                                        CombatEngine.layoutHeight * s) /
                                    2;
                                return Transform.translate(
                                  offset: Offset(0, dy),
                                  child: Transform.scale(
                                    scale: s,
                                    alignment: Alignment.topLeft,
                                    child: _ArcaneField(
                                      engine: engine,
                                      aiming: _aimingLevelThree,
                                      color: _elementColor(_barrageElement),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        // Cinematic hero invocation cut-in (diagonal band + impact)
                        Positioned.fill(
                          child: HeroSkillCutIn(
                            data: _cutIn,
                            onCompleted: () {
                              if (mounted) setState(() => _cutIn = null);
                            },
                          ),
                        ),
                        // Reaction banner
                        if (_reactionBanner != null)
                          Positioned(
                            top: 20,
                            left: 0,
                            right: 0,
                            child: IgnorePointer(
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 18, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.85),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: const Color(0xFFFF5A26)),
                                  ),
                                  child: Text(
                                    '¡$_reactionBanner!',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // Training tools
                        if (widget.showTrainingTools || engine.trainingMode)
                          Positioned(
                            top: 12,
                            left: 10,
                            right: 10,
                            child: _TrainingTools(
                              engine: engine,
                              onFillMana: () {
                                engine.fillAllMana();
                                ProceduralSfxEngine.playOrbSpawn();
                                setState(() {});
                              },
                              onRestart: _restartTraining,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // ZONE 3+4: BOTTOM BAR - fixed height so Column reserves space before Expanded.
                  // OverdriveBar(22) + SquadCards(118) + OrbsTray(104) + mutators(~20) = ~264px
                  SizedBox(
                    height: 330,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // OVERDRIVE rail: frenesi meter under the arena.
                        AnimatedBuilder(
                          animation: _fxClock,
                          builder: (context, _) => OverdriveBar(
                            fraction: engine.overdriveFraction,
                            active: engine.overdriveActive,
                            remaining: engine.overdriveRemaining,
                          ),
                        ),

                        // ZONE 3: SQUAD CARDS (118px)
                        SizedBox(height: 118, child: _buildSquadCards()),

                        // Flick hint: sutil cartelito arriba de la bandeja, solo hasta el primer tiro.
                        if (_showFlickHint)
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: BrimstoneTokens.goldPrimary,
                                  width: 1.2),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.lightbulb,
                                    size: 14, color: Color(0xFFFFC93C)),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    '💡 Deslizá rápido una esfera hacia arriba (Flick) en dirección a una diana • Arrastrá de costado para fusionar',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // ZONE 4: ORBS TRAY (104px) - HP bar + FUSIONAR integrated above, 5 orbs fully visible
                        SizedBox(height: 104, child: _buildOrbsTray()),

                        // Seal mutators label
                        if (widget.mutators.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4, right: 8),
                            child: Align(
                              alignment: Alignment.bottomRight,
                              child: Text(
                                widget.mutators.map((m) => m.label).join(' · '),
                                style: const TextStyle(
                                    color: Colors.white24,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Keyboard hints panel for desktop (Pilar 2)
                  if (isDesktop && _showKeyboardHints)
                    Positioned(
                      right: 12,
                      top: 70,
                      bottom: 280,
                      child: _KeyboardHintsPanel(
                        gameSpeed: _gameSpeed,
                        speed2xUnlocked: _speed2xUnlocked,
                        hasArtifact: _equippedArtifact != null,
                        autoBattleEnabled: _autoBattleEnabled,
                      ),
                    ),
                ],
              ),
            ),
          ], // Stack children
        ), // Stack
      ), // Focus
    ); // Scaffold
  }

  Widget _buildHeader() {
    final hpFraction = engine.bossHp / engine.boss.maxHp;
    final isEnraged = engine.enraged;
    final weakElement = elementalWeakness(engine.boss.element);
    final weakElementName = _elementDisplayName(weakElement);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [BrimstoneTokens.surfaceBase, BrimstoneTokens.bgAbyss],
        ),
        border: Border(
          bottom: BorderSide(
            color: BrimstoneTokens.goldMuted.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BrimstoneSpacing.spaceSM,
            vertical: BrimstoneSpacing.spaceXS,
          ),
          child: Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.arrow_back,
                  color: BrimstoneTokens.textPrimary,
                  size: 22,
                ),
                onPressed: () => Navigator.of(context).maybePop(),
                tooltip: 'Salir del combate',
              ),
              const SizedBox(width: BrimstoneSpacing.spaceXS),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            engine.boss.name,
                            style: BrimstoneTypography.headingSM,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isEnraged) ...[
                          const SizedBox(width: BrimstoneSpacing.spaceXS),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: BrimstoneSpacing.spaceXS,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              gradient: BrimstoneGradients.crimson,
                              borderRadius: BorderRadius.circular(
                                  BrimstoneRadii.radiusSM),
                            ),
                            child: Text(
                              'FURIA',
                              style: BrimstoneTypography.labelXS.copyWith(
                                color: BrimstoneTokens.textOnGold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Stack(
                            children: [
                              Container(
                                height: 6,
                                decoration: BoxDecoration(
                                  color: BrimstoneTokens.surfaceInteractive,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              FractionallySizedBox(
                                widthFactor: hpFraction.clamp(0.0, 1.0),
                                child: Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    gradient: isEnraged
                                        ? BrimstoneGradients.crimson
                                        : LinearGradient(colors: [
                                            BrimstoneElements.igneous,
                                            BrimstoneAccents.crimsonPrimary,
                                          ]),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: BrimstoneSpacing.spaceXS),
                        Text(
                          '${engine.bossHp.toInt()}',
                          style: BrimstoneTypography.numericMonoSM.copyWith(
                            color: BrimstoneTokens.textSecondary,
                          ),
                        ),
                        const SizedBox(width: BrimstoneSpacing.spaceXS),
                        // Elemental weakness chip
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: BrimstoneSpacing.spaceXS,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                BrimstoneElements.forElement(weakElement),
                                BrimstoneElements.forElement(weakElement)
                                    .withValues(alpha: 0.7),
                              ]),
                              borderRadius: BorderRadius.circular(
                                  BrimstoneRadii.radiusSM),
                              border: Border.all(
                                color: BrimstoneTokens.goldMuted,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'Débil a: $weakElementName (+30%)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: BrimstoneTypography.labelXS.copyWith(
                                color: BrimstoneTokens.textOnGold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Block 3: Boss Shield HP Bar
                    if (engine.boss.shieldHp > 0) ...[
                      const SizedBox(height: 3),
                      _BossShieldBar(
                        currentShield: engine.bossShieldHp,
                        maxShield: engine.boss.shieldHp,
                        isBroken: engine.bossShieldBroken,
                        breakTimer: engine.bossBreakTimer,
                      ),
                    ],
                  ],
                ),
              ),
              // Right-side controls: horizontal row, min width to avoid overflow.
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SpeedToggle(
                    initialSpeed: _gameSpeed,
                    onChanged: (speed) => setState(() => _gameSpeed = speed),
                  ),
                  const SizedBox(width: BrimstoneSpacing.spaceXS),
                  // Auto-Battle toggle (Block 3: 🤖 AUTO)
                  _AutoBattleToggle(
                    enabled: _autoBattleEnabled,
                    onChanged: (enabled) {
                      setState(() => _autoBattleEnabled = enabled);
                      _engine?.autoBattleEnabled = enabled;
                    },
                  ),
                  const SizedBox(width: BrimstoneSpacing.spaceXS),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.help_outline,
                      color: BrimstoneTokens.textSecondary,
                      size: 22,
                    ),
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: BrimstoneTokens.surfaceElevated,
                      builder: (_) => const HowToPlayModal(),
                    ),
                    tooltip: 'Ayuda',
                  ),
                  const SizedBox(width: BrimstoneSpacing.spaceXS),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.settings,
                      color: BrimstoneTokens.textSecondary,
                      size: 22,
                    ),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => const SettingsModal(),
                    ),
                    tooltip: 'Ajustes',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _elementDisplayName(Element e) => switch (e) {
        Element.igneous => 'Ígneo',
        Element.abyssal => 'Abisal',
        Element.telluric => 'Telúrico',
        Element.empty => 'Vacío',
      };

  Widget _buildSquadCards() {
    final cards = engine.cards;
    if (cards.isEmpty) {
      return Center(
        child: Text(
          'Sin escuadrón',
          style: BrimstoneTypography.bodySM,
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        gradient: BrimstoneGradients.cardBase,
        border: Border(
          top: BorderSide(
            color: BrimstoneTokens.goldMuted.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: BrimstoneSpacing.spaceXS,
      ),
      child: Row(
        children: List.generate(cards.length, (index) {
          final card = cards[index];
          final isReady = card.mana >= card.baseManaCost;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: TcgCardWidget.fromCombatCard(
                card: card,
                isLeader: index == 0,
                width: double.infinity,
                height: 112,
                onTap: isReady ? () => _onCardTap(index) : null,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildOrbsTray() {
    return Container(
      // HellFire: Runic Stone Base for orb tray - carved stone with metal separators
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFF1A0A0F), const Color(0xFF0C0608)]),
        border: Border(
          top: BorderSide(
              color: _chapterColor().withValues(alpha: 0.5), width: 2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Player HP bar
          Padding(
            padding: const EdgeInsets.fromLTRB(
              BrimstoneSpacing.spaceMD,
              BrimstoneSpacing.spaceSM,
              BrimstoneSpacing.spaceMD,
              BrimstoneSpacing.spaceXS,
            ),
            child: Row(children: [
              Icon(
                Icons.favorite,
                color: BrimstoneAccents.crimsonGlow,
                size: 18,
              ),
              const SizedBox(width: BrimstoneSpacing.spaceXS),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      Text(
                        'HP ',
                        style: BrimstoneTypography.bodyXS.copyWith(
                          color: BrimstoneTokens.textSecondary,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          '${engine.playerHp.toInt()} / ${engine.playerMaxHp.toInt()}',
                          style: BrimstoneTypography.numericMonoSM,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 2),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: Container(
                        height: 5,
                        color: BrimstoneTokens.surfaceInteractive,
                        child: FractionallySizedBox(
                          widthFactor: engine.hpFraction.clamp(0.0, 1.0),
                          alignment: Alignment.centerLeft,
                          child: Container(
                              decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                      colors: engine.isLowHp
                                          ? [
                                              BrimstoneTokens.success,
                                              BrimstoneAccents.info,
                                            ]
                                          : [
                                              BrimstoneTokens.success,
                                              BrimstoneAccents.info,
                                            ]))),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 5to botón táctico: artefacto del Invocador (junto a la barra de HP).
              if (_equippedArtifact != null) ...[
                const SizedBox(width: BrimstoneSpacing.spaceSM),
                AnimatedBuilder(
                  animation: _fxClock,
                  builder: (context, _) => CombatArtifactButton(
                    artifact: _equippedArtifact,
                    cooldownRemaining:
                        _engine?.artifactCooldownRemaining ?? 0.0,
                    onTap: _useEquippedArtifact,
                  ),
                ),
              ],
              // Auto-merge button compact next to HP
              if (_canAutoMerge()) ...[
                const SizedBox(width: BrimstoneSpacing.spaceXS),
                _buildAutoMergeButton(),
              ],
            ]),
          ),
          // Orbs tray - 5 slots in a Row with Expanded
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final trayHeight = constraints.maxHeight;
                  final orbSize = (trayHeight * 0.75).clamp(40.0, 56.0);

                  return Row(
                    children: List.generate(5, (i) {
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: _buildOrbSlot3D(i, orbSize, trayHeight),
                        ),
                      );
                    }),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _canAutoMerge() {
    for (var i = 0; i < engine.tray.length; i++) {
      if (engine.tray[i] == null) continue;
      for (var j = i + 1; j < engine.tray.length; j++) {
        if (engine.tray[j] == null) continue;
        final orbA = engine.tray[i]!;
        final orbB = engine.tray[j]!;
        final compatible = (orbA.element == orbB.element ||
                orbA.prismatic ||
                orbB.prismatic) &&
            orbA.level == orbB.level &&
            orbA.level != OrbLevel.three;
        if (compatible) return true;
      }
    }
    return false;
  }

  Widget _buildOrbSlot3D(int index, double orbSize, double trayHeight) {
    final orb = engine.tray[index];

    if (orb == null) {
      return Center(
        child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1A0A0F),
                border: Border.all(color: const Color(0xFF2A151A), width: 1)),
            child: Center(
                child: Icon(Icons.add,
                    size: 16, color: Colors.white.withValues(alpha: 0.2)))),
      );
    }

    final color = _elementColor(orb.element);
    final accent = _elementAccent(orb.element);
    final level = orb.level.index + 1;
    final isDragging = _draggingSlot == index;

    // HellFire: Orbital aura for Lv.2/3 orbs
    final hasOrbitalAura = level >= 2;

    return AnimatedScale(
      scale: isDragging ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 50),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // HellFire: Orbital aura ring for Lv.2/3
          if (hasOrbitalAura)
            AnimatedBuilder(
              animation: _mergePulseCtrl,
              builder: (context, _) {
                final pulse = _mergePulseCtrl.value;
                final auraRadius =
                    orbSize / 2 + 6 + 4 * math.sin(pulse * 2 * math.pi);
                return Container(
                  width: auraRadius * 2,
                  height: auraRadius * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: level == 2
                          ? const Color(0xFFFFD700).withValues(
                              alpha: 0.4 + 0.2 * math.sin(pulse * 2 * math.pi))
                          : const Color(0xFFFF5A26).withValues(
                              alpha: 0.4 + 0.2 * math.sin(pulse * 2 * math.pi)),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: level == 2
                            ? const Color(0xFFFFD700).withValues(alpha: 0.15)
                            : const Color(0xFFFF5A26).withValues(alpha: 0.15),
                        blurRadius: 8 + 4 * math.sin(pulse * 2 * math.pi),
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                );
              },
            ),
          GestureDetector(
            onTap: () {}, // Prevent tap from bubbling
            child: Container(
              width: orbSize,
              height: orbSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // Custom radial gradient per element (no PlasmaOrb shader)
                gradient: _orbGradient(orb.element, color, accent),
                boxShadow: [
                  BoxShadow(
                      color: color.withValues(alpha: 0.5),
                      blurRadius: 8,
                      spreadRadius: 1),
                  BoxShadow(
                      color: color.withValues(alpha: 0.28),
                      blurRadius: 12,
                      spreadRadius: 2)
                ],
                border: Border.all(
                    color: accent.withValues(alpha: 0.85), width: 1.8),
              ),
              child: Stack(alignment: Alignment.center, children: [
                // Specular highlight
                Positioned(
                    left: orbSize * 0.18,
                    top: orbSize * 0.15,
                    child: Container(
                        width: orbSize * 0.28,
                        height: orbSize * 0.28,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(colors: [
                              Colors.white,
                              Colors.white.withValues(alpha: 0.0)
                            ])))),
                // Element icon
                _buildElementIcon(orb.element, orbSize * 0.42),
                // Level badge
                Positioned(
                    bottom: -6,
                    child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: level == 1
                                    ? const Color(0xFFC0C0C0)
                                    : level == 2
                                        ? const Color(0xFFFFD700)
                                        : const Color(0xFFFF5A26),
                                width: 1.2)),
                        child: Text('Lv.$level',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                height: 1.0,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5)))),
                // Prismatic indicator
                if (orb.prismatic)
                  Positioned(
                      top: 2,
                      right: 2,
                      child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(colors: [
                                Color(0xFFFFD700),
                                Color(0xFFB16EFF)
                              ])))),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // Custom radial gradient per element (replaces PlasmaOrb shader)
  RadialGradient _orbGradient(Element element, Color color, Color accent) {
    switch (element) {
      case Element.igneous:
        return const RadialGradient(
          center: Alignment(-0.35, -0.38),
          radius: 0.95,
          colors: [
            Color(0xFFFF6D00),
            Color(0xFFB71C1C),
            Color(0xFF3E0000),
          ],
          stops: [0.0, 0.55, 1.0],
        );
      case Element.abyssal:
        return const RadialGradient(
          center: Alignment(-0.35, -0.38),
          radius: 0.95,
          colors: [
            Color(0xFF00E5FF),
            Color(0xFF01579B),
            Color(0xFF001933),
          ],
          stops: [0.0, 0.55, 1.0],
        );
      case Element.telluric:
        return const RadialGradient(
          center: Alignment(-0.35, -0.38),
          radius: 0.95,
          colors: [
            Color(0xFF76FF03),
            Color(0xFF2E7D32),
            Color(0xFF0D260F),
          ],
          stops: [0.0, 0.55, 1.0],
        );
      case Element.empty:
        return const RadialGradient(
          center: Alignment(-0.35, -0.38),
          radius: 0.95,
          colors: [
            Color(0xFFE040FB),
            Color(0xFF4A148C),
            Color(0xFF16002E),
          ],
          stops: [0.0, 0.55, 1.0],
        );
    }
  }

  Widget _buildElementIcon(Element element, double size) {
    final iconPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    return CustomPaint(
      size: Size(size, size),
      painter: _ElementIconPainter(
          element: element, size: size, iconPaint: iconPaint),
    );
  }

  Widget _buildAutoMergeButton() {
    var canMerge = false;
    for (var i = 0; i < engine.tray.length; i++) {
      if (engine.tray[i] == null) continue;
      for (var j = i + 1; j < engine.tray.length; j++) {
        if (engine.tray[j] == null) continue;
        final orbA = engine.tray[i]!;
        final orbB = engine.tray[j]!;
        final compatible = (orbA.element == orbB.element ||
                orbA.prismatic ||
                orbB.prismatic) &&
            orbA.level == orbB.level &&
            orbA.level != OrbLevel.three;
        if (compatible) {
          canMerge = true;
          break;
        }
      }
      if (canMerge) break;
    }
    return AnimatedOpacity(
        opacity: canMerge ? 1.0 : 0.4,
        duration: const Duration(milliseconds: 200),
        child: Material(
            color: Colors.transparent,
            child: InkWell(
                onTap: canMerge ? _autoMergeAll : null,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: canMerge
                                ? [
                                    const Color(0xFFFFD700),
                                    const Color(0xFFFF5A26)
                                  ]
                                : [Colors.grey.shade800, Colors.grey.shade900]),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: canMerge
                                ? const Color(0xFFFFD700)
                                : Colors.grey.shade700,
                            width: 1.5),
                        boxShadow: canMerge
                            ? [
                                BoxShadow(
                                    color: const Color(0xFFFFD700)
                                        .withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    spreadRadius: 1)
                              ]
                            : null),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.auto_fix_high,
                          size: 12, color: Colors.black),
                      const SizedBox(width: 3),
                      Text('FUSIONAR IGUALES',
                          style: TextStyle(
                              color: canMerge ? Colors.black : Colors.white38,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3))
                    ])))));
  }
}

/// Speed toggle widget for 1x / 1.5x game speed.

class _SpeedToggle extends StatelessWidget {
  final double initialSpeed;
  final void Function(double) onChanged;

  const _SpeedToggle({required this.initialSpeed, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          const Color(0xFF1A0A0F),
          const Color(0xFF0C0608),
        ]),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: const Color(0xFFB16EFF).withValues(alpha: 0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SpeedButton(
            label: '1x',
            selected: initialSpeed == 1.0,
            onTap: () => onChanged(1.0),
          ),
          Container(
            width: 1,
            height: 20,
            color: Colors.white24,
          ),
          _SpeedButton(
            label: '1.5x',
            selected: initialSpeed == 1.5,
            onTap: () => onChanged(1.5),
          ),
        ],
      ),
    );
  }
}

class _SpeedButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SpeedButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(colors: [
                  const Color(0xFFB16EFF).withValues(alpha: 0.9),
                  const Color(0xFFB16EFF).withValues(alpha: 0.7),
                ])
              : null,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

// Auto-Battle Toggle (Block 3: 🤖 AUTO)
class _AutoBattleToggle extends StatelessWidget {
  final bool enabled;
  final void Function(bool) onChanged;

  const _AutoBattleToggle({required this.enabled, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: enabled
                ? [
                    const Color(0xFF00C853).withValues(alpha: 0.3),
                    const Color(0xFFFFD700).withValues(alpha: 0.2),
                  ]
                : [
                    const Color(0xFF1A0A0F),
                    const Color(0xFF0C0608),
                  ]),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: enabled
                ? const Color(0xFF00C853).withValues(alpha: 0.8)
                : const Color(0xFFB16EFF).withValues(alpha: 0.5),
            width: 1.5),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: const Color(0xFF00C853).withValues(alpha: 0.4),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: GestureDetector(
        onTap: () => onChanged(!enabled),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.smart_toy,
              size: 14,
              color: enabled ? const Color(0xFF00C853) : Colors.white38,
            ),
            const SizedBox(width: 4),
            Text(
              'AUTO',
              style: TextStyle(
                color: enabled ? const Color(0xFF00C853) : Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Keyboard hints panel for desktop (Pilar 2)
class _KeyboardHintsPanel extends StatelessWidget {
  final double gameSpeed;
  final bool speed2xUnlocked;
  final bool hasArtifact;
  final bool autoBattleEnabled;

  const _KeyboardHintsPanel({
    required this.gameSpeed,
    required this.speed2xUnlocked,
    required this.hasArtifact,
    required this.autoBattleEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final hints = <_HintEntry>[
      _HintEntry('[1]', 'Invocar carta 1'),
      _HintEntry('[2]', 'Invocar carta 2'),
      _HintEntry('[3]', 'Invocar carta 3'),
      _HintEntry('[4]', 'Invocar carta 4'),
      _HintEntry('[SPACE]', 'Fusionar iguales'),
      _HintEntry('[Q/E]', hasArtifact ? 'Artefacto' : 'Artefacto (n/a)'),
      _HintEntry('[A]', 'Auto: ${autoBattleEnabled ? 'ON' : 'OFF'}'),
      _HintEntry('[S/Tab]',
          'Velocidad: ${gameSpeed}x${speed2xUnlocked ? '' : ' (2x tras Cap. I)'}'),
      _HintEntry('[Esc]', 'Pausa / Ajustes'),
    ];

    return Container(
      width: 180,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1A0A0F),
            const Color(0xFF0C0608),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFB16EFF).withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB16EFF).withValues(alpha: 0.2),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ATAJOS PC',
            style: TextStyle(
              color: const Color(0xFFB16EFF),
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          ...hints.map((h) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      h.key,
                      style: const TextStyle(
                        color: Color(0xFFFFC93C),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Text(
                      h.label,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _HintEntry {
  final String key;
  final String label;
  const _HintEntry(this.key, this.label);
}

// Boss Shield Break Bar (Block 3: Barrera Arcana + ¡BREAK!)
/// Elegant chips over the boss portrait: burn/aura, petrify, vulnerability and
/// the BREAK stun, each with its remaining seconds.
class _BossStatusBar extends StatelessWidget {
  const _BossStatusBar({required this.engine});

  final CombatEngine engine;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    void add({
      required String label,
      required IconData icon,
      required Color color,
      required double seconds,
    }) {
      if (seconds <= 0) return;
      chips.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(BrimstoneRadii.radiusSM),
            border: Border.all(color: color.withValues(alpha: 0.75), width: 1),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.32),
                blurRadius: 6,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 10, color: color),
              const SizedBox(width: 3),
              Text(
                label,
                style: BrimstoneTypography.labelXS.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 8.5,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 3),
              Text(
                '${seconds.toStringAsFixed(1)}s',
                style: BrimstoneTypography.labelXS.copyWith(
                  color: Colors.white70,
                  fontSize: 8,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (engine.auraRemaining > 0 && engine.aura != null) {
      final aura = engine.aura!;
      add(
        label: 'AURA ${_auraLabel(aura)}',
        icon: Icons.local_fire_department,
        color: _auraColor(aura),
        seconds: engine.auraRemaining,
      );
    }
    add(
      label: 'QUEMADURA',
      icon: Icons.whatshot,
      color: const Color(0xFFFF7A2F),
      seconds: engine.burnRemaining,
    );
    add(
      label: 'PETRIFICADO',
      icon: Icons.landscape,
      color: const Color(0xFF8FB7D9),
      seconds: engine.petrifyRemaining,
    );
    add(
      label: 'VULNERABLE +30%',
      icon: Icons.report_gmailerrorred,
      color: const Color(0xFFFF2A54),
      seconds: engine.vulnerableRemaining,
    );
    add(
      label: 'ATURDIDO · BREAK x1.5',
      icon: Icons.flash_on,
      color: BrimstoneTokens.goldPrimary,
      seconds: engine.bossStunRemaining,
    );

    if (chips.isEmpty) return const SizedBox.shrink();
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 4,
        runSpacing: 3,
        children: chips,
      ),
    );
  }

  static String _auraLabel(Element element) => switch (element) {
        Element.igneous => 'ÍGNEA',
        Element.abyssal => 'ABISAL',
        Element.telluric => 'TELÚRICA',
        Element.empty => 'VACÍO',
      };

  static Color _auraColor(Element element) => switch (element) {
        Element.igneous => const Color(0xFFFF5A26),
        Element.abyssal => const Color(0xFF3FD8FF),
        Element.telluric => const Color(0xFFB0703B),
        Element.empty => const Color(0xFFB16EFF),
      };
}

class _BossShieldBar extends StatelessWidget {
  final double currentShield;
  final double maxShield;
  final bool isBroken;
  final double breakTimer;

  const _BossShieldBar({
    required this.currentShield,
    required this.maxShield,
    required this.isBroken,
    required this.breakTimer,
  });

  @override
  Widget build(BuildContext context) {
    final fraction =
        maxShield > 0 ? (currentShield / maxShield).clamp(0.0, 1.0) : 0.0;
    final showBreak = isBroken && breakTimer > 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      width: 120,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Shield bar
          Container(
            height: 6,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF0A0008),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: Colors.white12),
            ),
            child: Stack(
              children: [
                // Shield fill
                FractionallySizedBox(
                  widthFactor: fraction,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: showBreak
                              ? [
                                  const Color(0xFFFFD700),
                                  const Color(0xFFFF5A26)
                                ]
                              : [
                                  const Color(0xFF00FFFF),
                                  const Color(0xFFB16EFF)
                                ]),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                // Break state indicator
                if (showBreak)
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFFFD700).withValues(alpha: 0.5),
                          const Color(0xFFFF5A26).withValues(alpha: 0.5),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '¡RUPTURA DE SELLO! ${breakTimer.toStringAsFixed(1)}s',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 7,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          // Shield label
          Text(
            showBreak
                ? '¡BREAK! DAÑO CRÍTICO +50%  •  JEFE ATURDIDO'
                : 'Barrera Arcana: ${currentShield.toInt()} / ${maxShield.toInt()}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color:
                  showBreak ? const Color(0xFFFFD700) : const Color(0xFF00FFFF),
              fontSize: 8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// 3D Element Icon Painter
class _ElementIconPainter extends CustomPainter {
  final Element element;
  final double size;
  final Paint iconPaint;

  _ElementIconPainter(
      {required this.element, required this.size, required this.iconPaint});

  @override
  void paint(Canvas canvas, Size s) {
    final cx = size / 2;
    final cy = size / 2;
    final scale = size / 24.0;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(scale);

    switch (element) {
      case Element.igneous:
        final path = Path()
          ..moveTo(0, -24)
          ..cubicTo(16, -7, 19, 15, 0, 19)
          ..cubicTo(-19, 15, -16, -7, 0, -24)
          ..close();
        canvas.drawPath(
            path,
            Paint()
              ..color = const Color(0xFFFFD980).withValues(alpha: 0.5)
              ..style = PaintingStyle.fill);
        canvas.drawPath(path, iconPaint);
        break;
      case Element.abyssal:
        for (var i = 0; i < 3; i++) {
          final a = i * math.pi / 3;
          canvas.drawLine(Offset(math.cos(a) * 24, math.sin(a) * 24),
              Offset(-math.cos(a) * 24, -math.sin(a) * 24), iconPaint);
        }
        canvas.drawCircle(Offset.zero, 2.5, Paint()..color = Colors.white);
        break;
      case Element.telluric:
        final path = Path()
          ..moveTo(0, -24)
          ..lineTo(20, 0)
          ..lineTo(0, 20)
          ..lineTo(-20, 0)
          ..close();
        canvas.drawPath(
            path,
            Paint()
              ..color = const Color(0xFFF0D0A0).withValues(alpha: 0.4)
              ..style = PaintingStyle.fill);
        canvas.drawPath(path, iconPaint);
        break;
      case Element.empty:
        canvas.drawCircle(Offset.zero, 18, iconPaint);
        canvas.drawCircle(
            Offset.zero,
            8,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.fill);
        break;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ElementIconPainter old) =>
      old.element != element || old.size != size;
}

// ----------------------------------------------------------------------
// Flying projectile painter (0.22s parabolic flight)
// ----------------------------------------------------------------------
class _FlyingOrbProjectile {
  final Element element;
  final OrbLevel level;
  final double startX;
  final double startY;
  final double targetX;
  final double targetY;
  final double duration;
  double progress;

  _FlyingOrbProjectile(
      {required this.element,
      required this.level,
      required this.startX,
      required this.startY,
      required this.targetX,
      required this.targetY,
      required this.duration,
      this.progress = 0.0});

  _FlyingOrbProjectile copyWith({double? progress}) => _FlyingOrbProjectile(
      element: element,
      level: level,
      startX: startX,
      startY: startY,
      targetX: targetX,
      targetY: targetY,
      duration: duration,
      progress: progress ?? this.progress);
}

// ----------------------------------------------------------------------
// Flying shot animation (Flutter overlay - 220ms parabolic flight with impact)
// ----------------------------------------------------------------------
class _FlyingShot {
  final Element element;
  final OrbLevel level;
  final double startX;
  final double startY;
  final double targetX;
  final double targetY;
  final HitKind hitKind;
  final CombatTarget? target;
  final double impactEngX;
  final double impactEngY;
  final int startTime;

  _FlyingShot({
    required this.element,
    required this.level,
    required this.startX,
    required this.startY,
    required this.targetX,
    required this.targetY,
    required this.hitKind,
    required this.target,
    required this.impactEngX,
    required this.impactEngY,
    required this.startTime,
  });

  double get progress {
    final elapsed = DateTime.now().millisecondsSinceEpoch - startTime;
    return (elapsed / 180.0).clamp(0.0, 1.0); // HellFire: 180ms flight
  }

  bool get isComplete => progress >= 1.0;
}

class _FlyingProjectilePainter extends CustomPainter {
  final _FlyingOrbProjectile projectile;
  final BrimstoneCombatGame game;

  _FlyingProjectilePainter({required this.projectile, required this.game});

  @override
  void paint(Canvas canvas, Size size) {
    final p = projectile.progress.clamp(0.0, 1.0);
    final z = CombatMath.flightZ(p, 1.0);
    final x = CombatMath.lerp(projectile.startX, projectile.targetX, p);
    final baseY = CombatMath.lerp(projectile.startY, projectile.targetY, p);
    final arc = math.sin(z * math.pi) * 115.0;
    final y = baseY - arc;
    final scale = CombatMath.flightScale(z);
    final screenX = game.offsetX + x * game.viewScale;
    final screenY = game.offsetY + y * game.viewScale;
    final screenScale = game.viewScale * scale;
    if (screenScale <= 0) return;

    canvas.save();
    canvas.translate(screenX, screenY);
    canvas.scale(screenScale);

    final elementColor = _elementColor(projectile.element);
    final elementAccent = _elementAccent(projectile.element);
    final levelNum = projectile.level.index + 1;
    final orbRadius = 24.0 * (0.7 + 0.3 * levelNum / 3);

    // Trail
    if (p >= 0.1) {
      final trailLength = (p * 8).clamp(0.0, 8);
      for (var i = 0; i < trailLength; i++) {
        final t = i / trailLength;
        final trailP = (p - t * 0.15).clamp(0.0, 1.0);
        if (trailP <= 0) continue;
        final trailZ = CombatMath.flightZ(trailP, 1.0);
        final trailScale = CombatMath.flightScale(trailZ);
        final alpha = (1.0 - t) * 0.4 * trailScale;
        canvas.drawCircle(
            Offset.zero,
            orbRadius * trailScale * 0.8,
            Paint()
              ..color = elementColor.withValues(alpha: alpha)
              ..style = PaintingStyle.fill
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      }
    }

    // Orb body
    canvas.drawCircle(
        Offset.zero,
        orbRadius + 4,
        Paint()
          ..color = elementColor.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    canvas.drawCircle(
        Offset.zero,
        orbRadius,
        Paint()
          ..shader = RadialGradient(colors: [
            elementAccent.withValues(alpha: 0.9),
            elementColor,
            Color.lerp(elementColor, const Color(0xFF0A0407), 0.5)!
          ]).createShader(
              Rect.fromCircle(center: Offset.zero, radius: orbRadius))
          ..style = PaintingStyle.fill);
    canvas.drawCircle(
        Offset.zero,
        orbRadius,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    final textPainter = TextPainter(
        text: TextSpan(
            text: '$levelNum',
            style: TextStyle(
                color: Colors.white,
                fontSize: orbRadius * 0.6,
                fontWeight: FontWeight.w900,
                shadows: [Shadow(color: Colors.black, blurRadius: 2)])),
        textDirection: TextDirection.ltr);
    textPainter.layout();
    textPainter.paint(
        canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));

    canvas.restore();
  }

  Color _elementColor(Element e) => switch (e) {
        Element.igneous => const Color(0xFFFF5A26),
        Element.abyssal => const Color(0xFF3FD8FF),
        Element.telluric => const Color(0xFFB0703B),
        Element.empty => const Color(0xFFB16EFF)
      };
  Color _elementAccent(Element e) => switch (e) {
        Element.igneous => const Color(0xFFFFD980),
        Element.abyssal => const Color(0xFF80E8FF),
        Element.telluric => const Color(0xFFF0D0A0),
        Element.empty => const Color(0xFFE5D4FF)
      };

  @override
  bool shouldRepaint(covariant _FlyingProjectilePainter old) =>
      old.projectile.progress != projectile.progress ||
      old.projectile.targetX != projectile.targetX ||
      old.projectile.targetY != projectile.targetY;
}

// ----------------------------------------------------------------------
// Element color utilities (top-level for painter access)
// ----------------------------------------------------------------------
Color elementColor(Element e) => switch (e) {
      Element.igneous => const Color(0xFFFF5A26),
      Element.abyssal => const Color(0xFF3FD8FF),
      Element.telluric => const Color(0xFFB0703B),
      Element.empty => const Color(0xFFB16EFF),
    };

Color elementAccent(Element e) => switch (e) {
      Element.igneous => const Color(0xFFFFD980),
      Element.abyssal => const Color(0xFF80E8FF),
      Element.telluric => const Color(0xFFF0D0A0),
      Element.empty => const Color(0xFFE5D4FF),
    };

// ----------------------------------------------------------------------
// Flying shot painter (Flutter overlay)
// ----------------------------------------------------------------------
class _FlyingShotPainter extends CustomPainter {
  final _FlyingShot shot;
  final Size arenaSize;
  final List<CombatTarget> targets;
  final double engineTime;
  final double Function(CombatTarget) effectiveAngularSpeed;

  _FlyingShotPainter({
    required this.shot,
    required this.arenaSize,
    required this.targets,
    required this.engineTime,
    required this.effectiveAngularSpeed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final p = shot.progress;
    if (p >= 1.0) return;

    // Parabolic flight path
    final z = CombatMath.flightZ(p, 1.0);
    final x = CombatMath.lerp(shot.startX, shot.targetX, p);
    final baseY = CombatMath.lerp(shot.startY, shot.targetY, p);
    final arc = math.sin(z * math.pi) * 115.0;
    final y = baseY - arc;

    final color = elementColor(shot.element);
    final accent = elementAccent(shot.element);
    final orbSize = 32.0 * (1.0 + p * 0.5); // Grows during flight

    // Fire tail
    final tailPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0.0),
          accent.withValues(alpha: 0.6),
          color.withValues(alpha: 0.9),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(x - 20, y - 20, 40, 40));
    canvas.drawLine(
      Offset(x - 15 * (1 - p), y + 10),
      Offset(x, y),
      tailPaint,
    );

    // Orb with glow
    final orbPaint1 = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.9),
          accent,
          color,
        ],
        stops: const [0.0, 0.3, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(x, y), radius: orbSize))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset(x, y), orbSize * 0.7, orbPaint1);

    final orbPaint2 = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white, accent, color],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(
          Rect.fromCircle(center: Offset(x, y), radius: orbSize * 0.6));
    canvas.drawCircle(Offset(x, y), orbSize * 0.45, orbPaint2);

    // Magnetic target indicator (green ring around target)
    if (shot.target != null && p > 0.3) {
      final t = shot.target!;
      final tx = t.xAt(engineTime, effectiveAngularSpeed(t)) *
          (arenaSize.width / CombatEngine.layoutWidth);
      final ty = t.yAt(engineTime, effectiveAngularSpeed(t)) *
          (arenaSize.height / CombatEngine.layoutHeight);
      final dist = math.sqrt((x - tx) * (x - tx) + (y - ty) * (y - ty));
      if (dist < 95) {
        // Within magnet range
        canvas.drawCircle(
          Offset(tx, ty),
          28.0 + 4.0 * math.sin(p * 20),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = Colors.greenAccent.withValues(alpha: 0.8),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FlyingShotPainter old) => true;
}

// ----------------------------------------------------------------------
// Drag preview painter (orb following pointer + aim line + magnetic target ring)
// ----------------------------------------------------------------------
class _DragPreviewPainter extends CustomPainter {
  final Offset dragCurrent;
  final Offset dragStart;
  final int slot;
  final CombatOrb? orb;
  final GlobalKey arenaKey;
  final CombatEngine engine;
  final int? hoveredMergeSlot;

  _DragPreviewPainter({
    required this.dragCurrent,
    required this.dragStart,
    required this.slot,
    required this.orb,
    required this.arenaKey,
    required this.engine,
    required this.hoveredMergeSlot,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (orb == null) return;

    final color = elementColor(orb!.element);
    final accent = elementAccent(orb!.element);

    // Arena bounds for coordinate conversion
    final arenaBox = arenaKey.currentContext?.findRenderObject() as RenderBox?;
    if (arenaBox == null) return;
    final arenaSize = arenaBox.size;
    final scaleX = arenaSize.width / CombatEngine.layoutWidth;
    final scaleY = arenaSize.height / CombatEngine.layoutHeight;

    // Draw aim line from orb slot to current pointer position (if in arena)
    if (dragCurrent.dy <
        arenaBox.localToGlobal(Offset.zero).dy + arenaSize.height * 0.7) {
      final trayScreenX =
          (CombatEngine.layoutWidth / 5 * (slot + 0.5)) * scaleX;
      final trayScreenY = CombatEngine.trayY * scaleY;

      // Golden aim line: from tray through pointer, projected to boss plane (predictive arc)
      final linePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            accent.withValues(alpha: 0.6),
            Colors.amber.withValues(alpha: 0.9),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

      // Dirección del gesto desde la bandeja hacia el puntero.
      final gestureDx = dragCurrent.dx - trayScreenX;
      final gestureDy = dragCurrent.dy - trayScreenY;
      final gestureDist =
          math.sqrt(gestureDx * gestureDx + gestureDy * gestureDy);

      // Punto proyectado en el plano del jefe (bossScreenY).
      double projX = dragCurrent.dx;
      double projY = dragCurrent.dy;
      if (gestureDist > 0 && gestureDy < 0) {
        // Proyectar la dirección hacia la altura del jefe.
        final tProj =
            (CombatEngine.bossScreenY * scaleY - trayScreenY) / gestureDy;
        projX = trayScreenX + gestureDx * tProj.clamp(0.0, 5.0);
        projY = CombatEngine.bossScreenY * scaleY;
      }

      canvas.drawLine(
        Offset(trayScreenX, trayScreenY),
        Offset(projX, projY),
        linePaint,
      );

      // Punto de destino (círculo pequeño en el proyectado).
      canvas.drawCircle(
        Offset(projX, projY),
        6.0,
        Paint()
          ..color = accent.withValues(alpha: 0.9)
          ..style = PaintingStyle.fill,
      );

      // Magnetic target ring
      for (final t in engine.targets) {
        final tx = t.xAt(engine.time, engine.effectiveAngularSpeed(t)) * scaleX;
        final ty = t.yAt(engine.time, engine.effectiveAngularSpeed(t)) * scaleY;
        final dist = math.sqrt((dragCurrent.dx - tx) * (dragCurrent.dx - tx) +
            (dragCurrent.dy - ty) * (dragCurrent.dy - ty));
        if (dist < 95) {
          canvas.drawCircle(
            Offset(tx, ty),
            28.0 + 4.0 * math.sin(engine.time * 10),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5
              ..color = Colors.greenAccent.withValues(alpha: 0.8),
          );
        }
      }
    }

    // Draw orb following pointer (when dragged)
    final dragPaint1 = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.9),
          accent,
          color,
        ],
        stops: const [0.0, 0.3, 1.0],
      ).createShader(Rect.fromCircle(center: dragCurrent, radius: 28))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(dragCurrent, 24.0, dragPaint1);

    final dragPaint2 = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white, accent, color],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(Rect.fromCircle(center: dragCurrent, radius: 20));
    canvas.drawCircle(dragCurrent, 16.0, dragPaint2);
  }

  @override
  bool shouldRepaint(covariant _DragPreviewPainter old) => true;
}

// ----------------------------------------------------------------------
// Supporting classes
// ----------------------------------------------------------------------
class _CombatDangerOverlay extends StatefulWidget {
  final CombatEngine engine;
  const _CombatDangerOverlay({required this.engine});
  @override
  State<_CombatDangerOverlay> createState() => _CombatDangerOverlayState();
}

class _CombatDangerOverlayState extends State<_CombatDangerOverlay> {
  Timer? _ticker;
  double _phase = 0;
  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (!mounted) return;
      if (!widget.engine.isLowHp && widget.engine.bullseyeStreak < 3) return;
      setState(() => _phase = (_phase + 0.12) % (math.pi * 2));
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final engine = widget.engine;
    final low = engine.isLowHp;
    final pulse = 0.45 + 0.35 * (math.sin(_phase) * 0.5 + 0.5);
    final streak = engine.bullseyeStreak;
    return Stack(children: [
      if (low)
        Positioned.fill(
            child: Container(
                decoration: BoxDecoration(
                    border: Border.all(
                        color: Colors.red.withValues(alpha: pulse), width: 10),
                    gradient: RadialGradient(radius: 0.95, colors: [
                      Colors.transparent,
                      Colors.red.withValues(alpha: pulse * 0.35)
                    ])))),
      if (streak >= 3)
        Positioned(
            top: 150,
            right: 12,
            child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFFC93C))),
                child: Text(
                    '¡RACHA CRÍTICA x$streak! +${((engine.bullseyeStreakBonus - 1) * 100).round()}%',
                    style: const TextStyle(
                        color: Color(0xFFFFC93C),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6)))),
    ]);
  }
}

class _TrainingTools extends StatefulWidget {
  final CombatEngine engine;
  final VoidCallback onFillMana;
  final VoidCallback onRestart;
  const _TrainingTools(
      {required this.engine,
      required this.onFillMana,
      required this.onRestart});
  @override
  State<_TrainingTools> createState() => _TrainingToolsState();
}

class _TrainingToolsState extends State<_TrainingTools> {
  Timer? _ticker;
  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dps = widget.engine.dps;
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF3FD8FF))),
        child: Row(children: [
          const Icon(Icons.speed, color: Color(0xFF3FD8FF), size: 16),
          const SizedBox(width: BrimstoneSpacing.spaceXS),
          Text('DPS ${dps.toStringAsFixed(1)}',
              style: const TextStyle(
                  color: Color(0xFF3FD8FF),
                  fontWeight: FontWeight.w900,
                  fontSize: 12)),
          const Spacer(),
          TextButton.icon(
              onPressed: widget.onFillMana,
              icon: const Icon(Icons.bolt, size: 14, color: Color(0xFFB16EFF)),
              label: const Text('MANÁ',
                  style: TextStyle(color: Color(0xFFB16EFF), fontSize: 10))),
          TextButton.icon(
              onPressed: widget.onRestart,
              icon: const Icon(Icons.refresh, size: 14, color: Colors.white54),
              label: const Text('REINICIAR',
                  style: TextStyle(color: Colors.white54, fontSize: 10))),
        ]));
  }
}

// HellFire: Dimensional Rift Archway - stone pillars with elemental energy veins on arena sides
class _RiftArchwayPillars extends StatelessWidget {
  final Color chapterColor;

  const _RiftArchwayPillars({required this.chapterColor});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RiftArchwayPainter(chapterColor: chapterColor),
      size: Size.infinite,
    );
  }
}

class _RiftArchwayPainter extends CustomPainter {
  final Color chapterColor;

  const _RiftArchwayPainter({required this.chapterColor});

  @override
  void paint(Canvas canvas, Size size) {
    final pillarWidth = 48.0;
    final pillarHeight = size.height * 0.85;
    final pillarTopY = size.height * 0.075;
    final leftX = 0.0;
    final rightX = size.width - pillarWidth;

    // Ember particles rising
    final emberPaint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < 12; i++) {
      final progress =
          (DateTime.now().millisecondsSinceEpoch / 1000.0 * 0.5 + i * 0.3) %
              1.0;
      final x = leftX + pillarWidth * (0.2 + 0.6 * math.sin(i * 1.7));
      final y = pillarTopY + pillarHeight * (0.9 - progress * 1.1);
      final alpha = (math.sin(progress * math.pi) * 0.6 + 0.4).clamp(0.0, 1.0);
      emberPaint.color = chapterColor.withValues(alpha: alpha * 0.7);
      canvas.drawCircle(Offset(x, y), 2.0 + progress * 1.5, emberPaint);
    }

    for (var i = 0; i < 12; i++) {
      final progress = (DateTime.now().millisecondsSinceEpoch / 1000.0 * 0.5 +
              i * 0.3 +
              0.5) %
          1.0;
      final x = rightX + pillarWidth * (0.2 + 0.6 * math.cos(i * 1.7));
      final y = pillarTopY + pillarHeight * (0.9 - progress * 1.1);
      final alpha = (math.sin(progress * math.pi) * 0.6 + 0.4).clamp(0.0, 1.0);
      emberPaint.color = chapterColor.withValues(alpha: alpha * 0.7);
      canvas.drawCircle(Offset(x, y), 2.0 + progress * 1.5, emberPaint);
    }

    // Left pillar
    _drawPillar(canvas,
        Rect.fromLTWH(leftX, pillarTopY, pillarWidth, pillarHeight), true);
    // Right pillar
    _drawPillar(canvas,
        Rect.fromLTWH(rightX, pillarTopY, pillarWidth, pillarHeight), false);
  }

  void _drawPillar(Canvas canvas, Rect rect, bool isLeft) {
    final veinColor = chapterColor;

    // Pillar base - dark stone
    final pillarPaint = Paint()..style = PaintingStyle.fill;
    final pillarPath = Path();

    // Tapered stone pillar shape
    final topWidth = rect.width * 0.6;
    final bottomWidth = rect.width;
    final centerX = rect.center.dx;

    pillarPath.moveTo(centerX - topWidth / 2, rect.top);
    pillarPath.lineTo(centerX - bottomWidth / 2, rect.bottom);
    pillarPath.lineTo(centerX + bottomWidth / 2, rect.bottom);
    pillarPath.lineTo(centerX + topWidth / 2, rect.top);
    pillarPath.close();

    // Stone gradient
    final stoneGradient = LinearGradient(
      colors: [
        const Color(0xFF14090D),
        const Color(0xFF0C0608),
        const Color(0xFF0A0407),
      ],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(rect);
    pillarPaint.shader = stoneGradient;
    canvas.drawPath(pillarPath, pillarPaint);

    // Stone texture lines (horizontal strata)
    final strataPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = const Color(0xFF2A151A);
    for (var i = 0; i < 12; i++) {
      final y = rect.top + rect.height * (i / 11.0);
      final widthAtY = bottomWidth - (bottomWidth - topWidth) * (i / 11.0);
      canvas.drawLine(
        Offset(centerX - widthAtY / 2, y),
        Offset(centerX + widthAtY / 2, y),
        strataPaint,
      );
    }

    // Elemental energy veins (glowing cracks)
    final veinPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final pulse =
        (DateTime.now().millisecondsSinceEpoch / 1000.0 * 2.0) % (2 * math.pi);
    final veinAlpha = (math.sin(pulse) * 0.3 + 0.7).clamp(0.0, 1.0);

    // Main vertical vein
    veinPaint.color = veinColor.withValues(alpha: veinAlpha);
    final veinPath = Path();
    veinPath.moveTo(centerX, rect.top + 10);
    for (var i = 0; i < 8; i++) {
      final y = rect.top + 10 + rect.height * 0.8 * (i / 7.0);
      final x = centerX + math.sin(pulse + i * 0.5) * 3.0;
      veinPath.lineTo(x, y);
    }
    canvas.drawPath(veinPath, veinPaint);

    // Branch veins
    for (var branch = 0; branch < 3; branch++) {
      final branchY =
          rect.top + rect.height * 0.25 + branch * rect.height * 0.2;
      final branchPath = Path();
      branchPath.moveTo(centerX, branchY);
      final branchDir = isLeft ? 1.0 : -1.0;
      for (var i = 0; i < 4; i++) {
        final t = i / 3.0;
        final x = centerX + branchDir * rect.width * 0.35 * t;
        final y = branchY +
            rect.height * 0.08 * math.sin(pulse * 2 + branch + i * 0.8);
        branchPath.lineTo(x, y);
      }
      veinPaint.color = veinColor.withValues(alpha: veinAlpha * 0.6);
      veinPaint.strokeWidth = 1.0;
      canvas.drawPath(branchPath, veinPaint);
    }

    // Top cap - metal ring
    final capRect = Rect.fromCenter(
      center: Offset(centerX, rect.top),
      width: topWidth * 1.2,
      height: 8,
    );
    final capPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF4A3A2A),
          const Color(0xFF2A1A0A),
          const Color(0xFF4A3A2A),
        ],
      ).createShader(capRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(capRect, const Radius.circular(4)),
      capPaint,
    );

    // Bottom base - metal ring
    final baseRect = Rect.fromCenter(
      center: Offset(centerX, rect.bottom),
      width: bottomWidth * 1.15,
      height: 10,
    );
    final basePaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF3A2A1A),
          const Color(0xFF1A0A00),
          const Color(0xFF3A2A1A),
        ],
      ).createShader(baseRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(baseRect, const Radius.circular(5)),
      basePaint,
    );

    // Outer glow
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = veinColor.withValues(alpha: veinAlpha * 0.2);
    canvas.drawPath(pillarPath, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _RiftArchwayPainter oldDelegate) =>
      oldDelegate.chapterColor != chapterColor;
}

// HellFire: Mana Orb Particles flying from hit target to matching-element squad cards
class _ManaOrbParticle {
  final double startX;
  final double startY;
  final double targetX;
  final double targetY;
  final Element element;
  final double duration;
  double progress;

  _ManaOrbParticle({
    required this.startX,
    required this.startY,
    required this.targetX,
    required this.targetY,
    required this.element,
    required this.duration,
    this.progress = 0.0,
  });
}

class _ManaOrbParticlesPainter extends CustomPainter {
  final List<_ManaOrbParticle> particles;

  const _ManaOrbParticlesPainter({required this.particles});

  Color _elementColor(Element e) => switch (e) {
        Element.igneous => const Color(0xFFFF5A26),
        Element.abyssal => const Color(0xFF3FD8FF),
        Element.telluric => const Color(0xFFB0703B),
        Element.empty => const Color(0xFFB16EFF),
      };

  Color _elementAccent(Element e) => switch (e) {
        Element.igneous => const Color(0xFFFFD980),
        Element.abyssal => const Color(0xFF80E8FF),
        Element.telluric => const Color(0xFFF0D0A0),
        Element.empty => const Color(0xFFE5D4FF),
      };

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final t = p.progress.clamp(0.0, 1.0);

      // Curved flight path (parabolic with slight curve)
      final midX = (p.startX + p.targetX) / 2 + math.sin(t * math.pi) * 30;
      final midY = (p.startY + p.targetY) / 2 - 50; // Arc upward

      final x = _lerp3(p.startX, midX, p.targetX, t);
      final y = _lerp3(p.startY, midY, p.targetY, t);

      // Particle size grows then shrinks
      final sizeProgress = math.sin(t * math.pi);
      final radius = 4.0 + sizeProgress * 6.0;

      // Fade in/out
      final alpha = (1.0 - (t - 0.5).abs() * 2.0).clamp(0.0, 1.0);

      final color = _elementColor(p.element);
      final accent = _elementAccent(p.element);

      // Outer glow
      canvas.drawCircle(
        Offset(x, y),
        radius * 1.5,
        Paint()
          ..color = color.withValues(alpha: alpha * 0.3)
          ..style = PaintingStyle.fill,
      );

      // Core orb with radial gradient
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: alpha),
              accent.withValues(alpha: alpha),
              color.withValues(alpha: alpha),
            ],
          ).createShader(Rect.fromCircle(center: Offset(x, y), radius: radius))
          ..style = PaintingStyle.fill,
      );

      // Specular highlight
      canvas.drawCircle(
        Offset(x - radius * 0.25, y - radius * 0.25),
        radius * 0.3,
        Paint()
          ..color = Colors.white.withValues(alpha: alpha * 0.8)
          ..style = PaintingStyle.fill,
      );

      // Trail particles
      for (var i = 1; i <= 3; i++) {
        final trailT = (t - i * 0.08).clamp(0.0, 1.0);
        if (trailT > 0) {
          final trailMidX =
              (p.startX + p.targetX) / 2 + math.sin(trailT * math.pi) * 30;
          final trailMidY = (p.startY + p.targetY) / 2 - 50;
          final trailX = _lerp3(p.startX, trailMidX, p.targetX, trailT);
          final trailY = _lerp3(p.startY, trailMidY, p.targetY, trailT);
          final trailAlpha = alpha * (1.0 - i * 0.25);
          final trailRadius = radius * (1.0 - i * 0.2);

          canvas.drawCircle(
            Offset(trailX, trailY),
            trailRadius,
            Paint()
              ..color = color.withValues(alpha: trailAlpha * 0.5)
              ..style = PaintingStyle.fill,
          );
        }
      }
    }
  }

  double _lerp3(double a, double b, double c, double t) {
    final ab = a + (b - a) * t;
    final bc = b + (c - b) * t;
    return ab + (bc - ab) * t;
  }

  @override
  bool shouldRepaint(covariant _ManaOrbParticlesPainter oldDelegate) =>
      oldDelegate.particles != particles;
}

CombatEngine defaultEngine() => CombatEngine(
    boss: BossConfig.pyroth,
    cards: [
      ManaCard(
          id: 'ignis_hound',
          name: 'Sabueso de Azufre',
          element: Element.igneous,
          baseManaCost: 100,
          attack: 10,
          skillLevel: 1,
          masteryRank: 1),
      ManaCard(
          id: 'abyss_stalker',
          name: 'Acechador de Escarcha',
          element: Element.abyssal,
          baseManaCost: 95,
          attack: 12,
          skillLevel: 1,
          masteryRank: 1),
      ManaCard(
          id: 'terra_golem',
          name: 'Gólem de Basalto',
          element: Element.telluric,
          baseManaCost: 100,
          attack: 8,
          skillLevel: 1,
          masteryRank: 1),
      ManaCard(
          id: 'void_specter',
          name: 'Espectro del Sello',
          element: Element.empty,
          baseManaCost: 110,
          attack: 15,
          skillLevel: 1,
          masteryRank: 1),
    ],
    playerMaxHp: 100);

class _BurstEffect {
  final double x, y;
  final Color color;
  _BurstEffect({required this.x, required this.y, required this.color});
}

class _BurstsPainter extends CustomPainter {
  final FixedRingBuffer<_BurstEffect> bursts;
  final double progress;
  final int ringsPerBurst;
  final double scale;
  static final Paint _ringPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5;
  static final Paint _corePaint = Paint();
  _BurstsPainter(
      {required this.bursts,
      required this.progress,
      this.ringsPerBurst = 4,
      this.scale = 1.0});
  @override
  void paint(Canvas canvas, Size size) {
    final ring = _ringPaint;
    final core = _corePaint;
    for (final b in bursts) {
      for (var i = 0; i < ringsPerBurst; i++) {
        final p = (progress - i * 0.18).clamp(0.0, 1.0);
        if (p <= 0.0) continue;
        final radius = p * 120.0 * scale;
        final alpha = ((1.0 - p) * 0.9).clamp(0.0, 1.0);
        ring.color = b.color.withValues(alpha: alpha);
        canvas.drawCircle(Offset(b.x, b.y), radius, ring);
      }
      core.color =
          Colors.white.withValues(alpha: (1.0 - progress).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(b.x, b.y), 6.0 + progress * 10.0, core);
    }
  }

  @override
  bool shouldRepaint(_BurstsPainter old) =>
      old.progress != progress ||
      old.ringsPerBurst != ringsPerBurst ||
      old.scale != scale;
}

class CombatSummaryDialog extends StatelessWidget {
  final bool victory;
  final int damageTotal;
  final double maxHit;
  final int bullseyes;
  final int reactions;
  final int counterflicks;
  final int mergesToThree;
  final int bestStreak;
  final Map<String, int> damageByCard;
  final Map<String, String> cardNames;
  final String mvpCardId;
  const CombatSummaryDialog(
      {super.key,
      required this.victory,
      required this.damageTotal,
      required this.maxHit,
      required this.bullseyes,
      required this.reactions,
      required this.counterflicks,
      required this.mergesToThree,
      this.bestStreak = 0,
      this.damageByCard = const {},
      this.cardNames = const {},
      this.mvpCardId = ''});
  @override
  Widget build(BuildContext context) {
    final loot = victory ? (damageTotal ~/ 5) : 0;
    final entries = damageByCard.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final breakdownTotal = entries.fold<int>(0, (s, e) => s + e.value);
    return AlertDialog(
      backgroundColor: const Color(0xFF14090D),
      title: Text(victory ? 'VICTORIA' : 'DERROTA',
          style: TextStyle(
              color: victory ? const Color(0xFF4FFFA3) : Colors.redAccent,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340, maxHeight: 480),
        child: SingleChildScrollView(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SummaryRow(label: 'Daño total', value: '$damageTotal'),
                _SummaryRow(label: 'Golpe máximo', value: '${maxHit.toInt()}'),
                _SummaryRow(label: 'Bullseyes', value: '$bullseyes'),
                _SummaryRow(label: 'Mejor racha', value: 'x$bestStreak'),
                _SummaryRow(label: 'Reacciones', value: '$reactions'),
                _SummaryRow(label: 'Esferas Nv.3', value: '$mergesToThree'),
                _SummaryRow(label: 'Counter-flicks', value: '$counterflicks'),
                const SizedBox(height: 10),
                _SummaryRow(
                    label: 'Botín',
                    value: '$loot oro',
                    valueColor: const Color(0xFFFFC93C)),
                if (breakdownTotal > 0) ...[
                  const SizedBox(height: 14),
                  const Text('APORTE DE DAÑO',
                      style: TextStyle(
                          color: Color(0xFFFFC93C),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2)),
                  const SizedBox(height: 6),
                  for (final e in entries)
                    _DamageRow(
                      name: cardNames[e.key] ?? e.key,
                      damage: e.value,
                      share: e.value / breakdownTotal,
                      isMvp: e.key == mvpCardId,
                    ),
                ],
              ]),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(victory ? true : false),
            child: Text(
              victory ? 'RECLAMAR BOTÍN Y CONTINUAR' : 'Volver al Santuario',
              style: const TextStyle(
                  color: Color(0xFFB16EFF), fontWeight: FontWeight.w800),
            )),
      ],
    );
  }
}

class _DamageRow extends StatelessWidget {
  final String name;
  final int damage;
  final double share;
  final bool isMvp;
  const _DamageRow(
      {required this.name,
      required this.damage,
      required this.share,
      this.isMvp = false});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(
          width: 96,
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: isMvp ? const Color(0xFFFFC93C) : Colors.white70,
                fontSize: 11,
                fontWeight: isMvp ? FontWeight.w900 : FontWeight.w600),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Container(
              height: 8,
              color: Colors.white12,
              child: FractionallySizedBox(
                widthFactor: share.clamp(0.02, 1.0),
                alignment: Alignment.centerLeft,
                child: const ColoredBox(color: Color(0xFFB16EFF)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 44,
          child: Text('$damage',
              textAlign: TextAlign.right,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800)),
        ),
        if (isMvp) ...[
          const SizedBox(width: 4),
          const Text('★ MVP',
              style: TextStyle(
                  color: Color(0xFFFFC93C),
                  fontSize: 9,
                  fontWeight: FontWeight.w900)),
        ],
      ]),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _SummaryRow(
      {required this.label, required this.value, this.valueColor});
  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
          Text(value,
              style: TextStyle(
                  color: valueColor ?? Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13))
        ]));
  }
}

/// Electric chains + predictive aim laser, drawn in engine coordinates.
class _ArcaneField extends StatelessWidget {
  const _ArcaneField({
    required this.engine,
    required this.aiming,
    required this.color,
  });

  final CombatEngine engine;
  final bool aiming;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final beams = <Widget>[];
    if (aiming) {
      beams.add(
        ArcaneBeam(
          start: Offset(engine.dragX, engine.dragY),
          end: const Offset(
              CombatEngine.bossScreenX, CombatEngine.bossScreenY - 30),
          color: color,
          thickness: 34,
          progress: 0.92,
        ),
      );
    }
    if (engine.bossShieldBroken) {
      for (var i = 0; i < engine.targets.length; i++) {
        final target = engine.targets[i];
        beams.add(
          ArcaneBeam(
            start: const Offset(
                CombatEngine.bossScreenX, CombatEngine.bossScreenY),
            end: Offset(
              target.xAt(engine.time, engine.effectiveAngularSpeed(target)),
              target.yAt(engine.time, engine.effectiveAngularSpeed(target)),
            ),
            color: i.isEven ? color : const Color(0xFFE5D4FF),
            thickness: 13,
            glow: 0.75,
          ),
        );
      }
    }
    if (beams.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      width: CombatEngine.layoutWidth,
      height: CombatEngine.layoutHeight,
      child: Stack(clipBehavior: Clip.none, children: beams),
    );
  }
}

/// Live damage race HUD for an Archon Colosseum duel.
class _DuelScoreboard extends StatelessWidget {
  const _DuelScoreboard({required this.engine});

  final CombatEngine engine;

  @override
  Widget build(BuildContext context) {
    final target = engine.scoreTarget ?? 0;
    final score = engine.damageTotal;
    final ratio = target <= 0 ? 0.0 : (score / target).clamp(0.0, 1.0);
    final remaining =
        (engine.duelDuration - engine.time).clamp(0.0, engine.duelDuration);
    final winning = score >= target;
    final accent = winning ? const Color(0xFF4FFFA3) : const Color(0xFFFFC93C);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                'TU PUNTAJE $score',
                style: BrimstoneFonts.cinzel(
                  size: 9,
                  weight: FontWeight.w900,
                  color: accent,
                ),
              ),
              const Spacer(),
              Text(
                'OBJETIVO $target',
                style: BrimstoneFonts.cinzel(
                  size: 9,
                  weight: FontWeight.w900,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${remaining.toStringAsFixed(0)}s',
                style: BrimstoneFonts.sans(
                  size: 9,
                  color: remaining <= 10
                      ? const Color(0xFFFF5A26)
                      : Colors.white54,
                  weight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          MetallicProgressBar(value: ratio, color: accent, height: 5),
        ],
      ),
    );
  }
}

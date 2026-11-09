import 'dart:async';
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart' hide Element;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/procedural_sfx_engine.dart';
import '../../../core/performance/object_pool.dart';
import '../../../core/performance/performance_settings.dart';
import '../../../domain/combat/combat_engine.dart';
import '../../../domain/combat/combat_math.dart';
import '../../../domain/combat/combat_models.dart';
import '../../../domain/meta/card_mastery_system.dart';
import '../../../domain/meta/rune_system.dart';
import '../../../domain/meta/seal_challenge_rules.dart';
import '../../../domain/meta/squad_synergy_resolver.dart';
import '../../../domain/value_objects/element.dart';
import '../../../domain/value_objects/orb_level.dart';
import '../../combat_engine/brimstone_combat_game.dart';
import '../../controllers/meta_controller.dart';
import '../../widgets/tcg_card_widget.dart';
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

  // Game speed multiplier (1.0 or 1.5x)
  double _gameSpeed = 1.0;

  // Block 3: Auto-Battle state
  bool _autoBattleEnabled = false;

  // Unified drag/flick state
  int? _draggedSlot;
  Offset? _dragStartGlobalPos;
  Offset? _dragCurrentGlobalPos;
  int? _hoveredMergeSlot;

  // Flying projectile for visual 0.22s parabolic flight
  _FlyingOrbProjectile? _flyingProjectile;

  // HellFire visual identity elements
  late final List<_ManaOrbParticle> _manaOrbParticles;
  int _chapterColorIndex = 0;

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
    _initEngine();
  }

  @override
  void dispose() {
    _particleCtrl.dispose();
    _mergePulseCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CombatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.engine, widget.engine)) {
      _resolved = false;
      _initEngine();
    }
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
        case HitKind.graze:
          ProceduralSfxEngine.playHitGraze();
        case HitKind.normal:
          ProceduralSfxEngine.playHitNormal();
        case HitKind.miss:
          break;
      }
      _addBurst(x, y, _elementColor(element));

      // HellFire: Spawn 3 mana orb particles flying from hit target to matching-element squad cards
      _spawnManaOrbParticles(x, y, element);

      if (mounted) setState(() {});
    };
    _engine!.onReaction = (name) {
      ProceduralSfxEngine.playElementalReaction();
      ref.read(bountyProvider.notifier).increment('reactions');
      recordCodexReaction(ref, name);
      setState(() => _reactionBanner = name);
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

  bool _bossDeathFlash = false;

  Future<void> _resolve(bool victory) async {
    if (_resolved) return;
    _resolved = true;
    if (victory) {
      if (mounted) setState(() => _bossDeathFlash = true);
      await Future<void>.delayed(const Duration(milliseconds: 650));
      if (mounted) setState(() => _bossDeathFlash = false);
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

  // Coordinate conversion: screen -> engine (430x932 logical)
  (double, double) _toEngine(Offset p) => game.toEngineCoords(p.dx, p.dy);

  // Convert engine X to tray slot index (0-4)
  int? _slotFromX(double x) {
    final slot = (x / (CombatEngine.layoutWidth / 5)).floor();
    return (slot < 0 || slot > 4) ? null : slot;
  }

  // Get tray slot center X in engine coords
  double _slotCenterX(int slot) => CombatEngine.layoutWidth / 5 * (slot + 0.5);

  // Check if a point is over the tray area (engine coords)
  bool _isOverTray(double y) => y >= CombatEngine.trayY - 60;

  // Find merge target slot near drag position
  int? _findMergeTarget(int draggedSlot, double dragX) {
    final draggedOrb = engine.tray[draggedSlot];
    if (draggedOrb == null) return null;
    final targetSlot = _slotFromX(dragX);
    if (targetSlot == null || targetSlot == draggedSlot) return null;
    final targetOrb = engine.tray[targetSlot];
    if (targetOrb == null) return null;
    final compatible = (draggedOrb.element == targetOrb.element ||
            draggedOrb.prismatic ||
            targetOrb.prismatic) &&
        draggedOrb.level == targetOrb.level &&
        draggedOrb.level != OrbLevel.three;
    return compatible ? targetSlot : null;
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

  // Unified drag/flick handlers
  void _onPanStart(DragStartDetails d) {
    final (x, y) = _toEngine(d.globalPosition);

    // Counter-flick priority
    if (engine.counterFlickAt(
        x, y, DateTime.now().millisecondsSinceEpoch / 1000)) {
      ProceduralSfxEngine.playCounterFlickDestroy();
      ref.read(bountyProvider.notifier).increment('counterflicks');
      return;
    }

    // Check if started on a tray orb
    if (_isOverTray(y)) {
      final slot = _slotFromX(x);
      if (slot != null && engine.tray[slot] != null) {
        _draggedSlot = slot;
        _dragStartGlobalPos = d.globalPosition;
        _dragCurrentGlobalPos = d.globalPosition;
        engine.startDrag(slot, x, y);
        return;
      }
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_draggedSlot == null) return;
    _dragCurrentGlobalPos = d.globalPosition;
    final (x, y) = _toEngine(d.globalPosition);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    engine.updateDrag(x, y, (nowMs - _lastPanMs) / 1000.0);
    _lastPanMs = nowMs;

    // Update merge hover target (only when in tray zone)
    if (_isOverTray(y)) {
      setState(() => _hoveredMergeSlot = _findMergeTarget(_draggedSlot!, x));
    } else {
      setState(() => _hoveredMergeSlot = null);
    }
  }

  void _onPanEnd(DragEndDetails d) {
    if (_draggedSlot == null) return;

    final draggedSlot = _draggedSlot!;
    final startPos = _dragStartGlobalPos ?? Offset.zero;
    final endPos = _dragCurrentGlobalPos ?? Offset.zero;
    final (startX, startY) = _toEngine(startPos);
    final (endX, endY) = _toEngine(endPos);
    final velocity = d.velocity;

    final deltaDy = endPos.dy - startPos.dy;
    final isFlickUp = deltaDy < -30 || velocity.pixelsPerSecond.dy < -200;

    if (isFlickUp) {
      // FLICK: Launch toward boss plane with magnet to nearest target
      _launchFlickProjectile(draggedSlot, startX, startY, endX, endY, velocity);
    } else {
      // DRAG END: Check for merge or swap in tray
      final targetSlot = _slotFromX(endX);
      if (targetSlot != null && targetSlot != draggedSlot) {
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

    setState(() {
      _draggedSlot = null;
      _dragStartGlobalPos = null;
      _dragCurrentGlobalPos = null;
      _hoveredMergeSlot = null;
    });
  }

  // Launch projectile with flick physics (HellFire style)
  void _launchFlickProjectile(int slot, double startX, double startY,
      double endX, double endY, Velocity velocity) {
    final orb = engine.tray[slot];
    if (orb == null) return;

    // Calculate flick direction
    final dx = endX - startX;
    final dy = endY - startY;

    // Target point: extend flick vector to boss plane
    double targetY = CombatEngine.bossScreenY - 90; // target plane
    double targetX = startX + (targetY - startY) / dy * dx;

    // Magnet to nearest target within 75px
    for (final t in engine.targets) {
      final tx = t.xAt(engine.time, engine.effectiveAngularSpeed(t));
      final ty = t.yAt(engine.time, engine.effectiveAngularSpeed(t));
      final dist = math.sqrt(
          (targetX - tx) * (targetX - tx) + (targetY - ty) * (targetY - ty));
      if (dist < 75) {
        targetX = tx;
        targetY = ty;
        break;
      }
    }

    // Clamp target
    targetY = targetY.clamp(
        CombatEngine.bossScreenY - 120, CombatEngine.bossScreenY + 20);

    final trayX = _slotCenterX(slot);
    final trayY = CombatEngine.trayY;

    _flyingProjectile = _FlyingOrbProjectile(
      element: orb.element,
      level: orb.level,
      startX: trayX,
      startY: trayY,
      targetX: targetX,
      targetY: targetY,
      duration: 0.22,
    );

    engine.tray[slot] = null;
    ProceduralSfxEngine.playOrbFlick();
    _animateFlight(targetX, targetY, orb);
  }

  Future<void> _animateFlight(
      double targetX, double targetY, CombatOrb orb) async {
    const flightDuration = 0.22;
    const frames = 60;
    final frameTime = flightDuration / frames;

    for (var i = 0; i <= frames; i++) {
      if (!mounted) return;
      final t = i / frames;
      setState(
          () => _flyingProjectile = _flyingProjectile?.copyWith(progress: t));
      await Future.delayed(Duration(milliseconds: (frameTime * 1000).round()));
    }

    _resolveImpact(targetX, targetY, orb);

    if (mounted) setState(() => _flyingProjectile = null);
  }

  void _resolveImpact(double targetX, double targetY, CombatOrb orb) {
    CombatTarget? best;
    var bestDist = double.infinity;
    var bestKind = HitKind.miss;

    for (final t in engine.targets) {
      final tx = t.xAt(engine.time, engine.effectiveAngularSpeed(t));
      final ty = t.yAt(engine.time, engine.effectiveAngularSpeed(t));
      final d = math.sqrt(
        (targetX - tx) * (targetX - tx) +
            (CombatEngine.bossScreenY - ty) * (CombatEngine.bossScreenY - ty),
      );
      final kind = CombatMath.classifyHit(
          d, engine.innerRadiusFor(t), engine.outerRadiusFor(t));
      if (_hitRank(kind) < _hitRank(bestKind) ||
          (kind == bestKind && d < bestDist)) {
        best = t;
        bestDist = d;
        bestKind = kind;
      }
    }

    if (best == null || bestKind == HitKind.miss) {
      engine.bullseyeStreak = 0;
      if (bestKind == HitKind.graze) {
        engine.registerDamage(
            orb: orb, target: null, multiplier: 0.25, kind: HitKind.graze);
      }
      return;
    }
    final dummyProj = OrbProjectile(
      id: 'visual_${DateTime.now().millisecondsSinceEpoch}',
      element: orb.element,
      level: orb.level,
      startX: _slotCenterX(0),
      startY: CombatEngine.trayY,
      targetX: targetX,
      targetY: targetY,
      flightDuration: 0.001,
    );
    engine.projectiles.add(dummyProj);
    engine.tick(0.001);
    engine.projectiles.removeWhere((p) => p.id == dummyProj.id);
  }

  static int _hitRank(HitKind k) => switch (k) {
        HitKind.bullseye => 0,
        HitKind.normal => 1,
        HitKind.graze => 2,
        HitKind.miss => 3,
      };

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

    return Scaffold(
      backgroundColor: const Color(0xFF0C0608),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: Column(
          key: ValueKey<int>(_session),
          children: [
            // ZONE 1: HEADER (56px)
            SizedBox(height: 56, child: _buildHeader()),

            // ZONE 2: ARENA (Expanded, FULL WIDTH)
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                      child: ClipRect(child: GameWidget(game: game))),
                  // HellFire: Dimensional Rift Archway - stone pillars with elemental energy veins
                  Positioned.fill(
                      child:
                          _RiftArchwayPillars(chapterColor: _chapterColor())),
                  // Particle bursts
                  if (_bursts.isNotEmpty)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _BurstsPainter(
                          bursts: _bursts,
                          progress: _particleCtrl.value,
                          ringsPerBurst: PerformanceSettings.ringsPerBurst,
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
                  // Danger overlay
                  Positioned.fill(
                    child: IgnorePointer(
                        child: _CombatDangerOverlay(engine: engine)),
                  ),
                  // Boss death flash
                  if (_bossDeathFlash)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.95),
                                const Color(0xFFFFD700).withValues(alpha: 0.8),
                                const Color(0xFFFF2A54).withValues(alpha: 0.6),
                                Colors.transparent,
                              ],
                              radius: 1.2,
                            ),
                          ),
                        ),
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
                              border:
                                  Border.all(color: const Color(0xFFFF5A26)),
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

            // ZONE 3: SQUAD CARDS (118px)
            SizedBox(height: 118, child: _buildSquadCards()),

            // ZONE 4: ORBS TRAY + PLAYER HP (115px)
            SizedBox(height: 115, child: _buildOrbsTray()),

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
    );
  }

  Widget _buildHeader() {
    final hpFraction = engine.bossHp / engine.boss.maxHp;
    final isEnraged = engine.enraged;
    final weakElement = elementalWeakness(engine.boss.element);
    final weakElementName = _elementDisplayName(weakElement);
    final weakElementColor = _elementColor(weakElement);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A0A0F), Color(0xFF0C0608)],
        ),
        border: Border(bottom: BorderSide(color: Color(0xFF2A151A), width: 1)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                icon:
                    const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                onPressed: () => Navigator.of(context).maybePop(),
                tooltip: 'Salir del combate',
              ),
              const SizedBox(width: 4),
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
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isEnraged) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [
                                Color(0xFFFF2A54),
                                Color(0xFFFFD700)
                              ]),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('FURIA',
                                style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 7,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5)),
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
                                      color: const Color(0xFF1E0A0E),
                                      borderRadius: BorderRadius.circular(3))),
                              FractionallySizedBox(
                                widthFactor: hpFraction.clamp(0.0, 1.0),
                                child: Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                        colors: isEnraged
                                            ? [
                                                Colors.orangeAccent,
                                                Colors.redAccent
                                              ]
                                            : [
                                                Colors.redAccent,
                                                const Color(0xFFCC0000)
                                              ]),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${engine.bossHp.toInt()}',
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                fontFeatures: [FontFeature.tabularFigures()])),
                        const SizedBox(width: 8),
                        // Elemental weakness chip
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                weakElementColor.withValues(alpha: 0.9),
                                weakElementColor.withValues(alpha: 0.7),
                              ]),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  width: 1),
                            ),
                            child: Text(
                              'Débil a: $weakElementName (+30%)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.3),
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Block 3: Boss Shield HP Bar (ancho acotado por la columna)
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
              // Speed toggle 1x / 1.5x
              _SpeedToggle(
                initialSpeed: _gameSpeed,
                onChanged: (speed) => setState(() => _gameSpeed = speed),
              ),
              // Auto-Battle toggle (Block 3: 🤖 AUTO)
              _AutoBattleToggle(
                enabled: _autoBattleEnabled,
                onChanged: (enabled) {
                  setState(() => _autoBattleEnabled = enabled);
                  _engine?.autoBattleEnabled = enabled;
                },
              ),
              IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.help_outline,
                      color: Colors.white70, size: 22),
                  onPressed: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: const Color(0xFF14090D),
                      builder: (_) => const HowToPlayModal()),
                  tooltip: 'Ayuda'),
              IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.settings,
                      color: Colors.white70, size: 22),
                  onPressed: () => showDialog(
                      context: context, builder: (_) => const SettingsModal()),
                  tooltip: 'Ajustes'),
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
      return const Center(
          child: Text('Sin escuadrón',
              style: TextStyle(color: Colors.white38, fontSize: 12)));
    }
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF14090D), Color(0xFF0C0608)]),
        border: Border(top: BorderSide(color: Color(0xFF2A151A), width: 1)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final card = cards[index];
          final isReady = card.mana >= card.baseManaCost;
          return TcgCardWidget.fromCombatCard(
              card: card,
              isLeader: index == 0,
              width: 112,
              height: 112,
              onTap: isReady ? () => _onCardTap(index) : null);
        },
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
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(children: [
              const Icon(Icons.favorite, color: Color(0xFFFF2A54), size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      Text('HP ',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                      Text(
                          '${engine.playerHp.toInt()} / ${engine.playerMaxHp.toInt()}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              fontFeatures: [FontFeature.tabularFigures()])),
                    ]),
                    const SizedBox(height: 2),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: Container(
                        height: 5,
                        color: const Color(0xFF1E0A0E),
                        child: FractionallySizedBox(
                          widthFactor: engine.hpFraction.clamp(0.0, 1.0),
                          alignment: Alignment.centerLeft,
                          child: Container(
                              decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                      colors: engine.isLowHp
                                          ? [
                                              Colors.redAccent,
                                              const Color(0xFFFF5A26)
                                            ]
                                          : [
                                              const Color(0xFF4FFFA3),
                                              const Color(0xFF00C853)
                                            ]))),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
          // Orbs tray - 5 slots, 3D rendering with Runic Stone Base
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final trayWidth = constraints.maxWidth;
                final slotWidth = trayWidth / 5;
                final trayHeight = constraints.maxHeight;
                final orbSize = (trayHeight * 0.75).clamp(40.0, 56.0);

                return Stack(children: [
                  // HellFire: Runic Stone Base background
                  Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: const Color(0xFF0A0407),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: _chapterColor().withValues(alpha: 0.6),
                            width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: _chapterColor().withValues(alpha: 0.15),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 4,
                            offset: const Offset(0, -2),
                          ),
                        ],
                        // Carved stone texture effect via gradient overlay
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            const Color(0xFF14090D),
                            const Color(0xFF0C0608),
                            const Color(0xFF0A0407),
                          ],
                        )),
                  ),
                  // Metal separators between slots (HellFire style)
                  for (var i = 1; i < 5; i++)
                    Positioned(
                        left: i * slotWidth,
                        top: 8,
                        bottom: 8,
                        child: Container(
                            width: 2,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _chapterColor().withValues(alpha: 0.8),
                                  _chapterColor().withValues(alpha: 0.3),
                                  _chapterColor().withValues(alpha: 0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(1),
                              boxShadow: [
                                BoxShadow(
                                  color: _chapterColor().withValues(alpha: 0.4),
                                  blurRadius: 2,
                                  spreadRadius: 0.5,
                                ),
                              ],
                            ))),
                  // Orbs in slots (3D with orbital auras for Lv.2/3)
                  for (var i = 0; i < 5; i++)
                    _buildOrbSlot3D(i, slotWidth, orbSize, trayHeight),
                  // Dragged orb preview (follows finger globally)
                  if (_draggedSlot != null && _dragCurrentGlobalPos != null)
                    _buildDraggedOrbPreview3D(slotWidth, orbSize),
                  // Green merge rings on compatible targets
                  if (_hoveredMergeSlot != null)
                    _buildMergeRing(
                        _hoveredMergeSlot!, slotWidth, orbSize, trayHeight),
                  // Auto-merge button
                  Positioned(top: 4, right: 12, child: _buildAutoMergeButton()),
                ]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrbSlot3D(
      int index, double slotWidth, double orbSize, double trayHeight) {
    final orb = engine.tray[index];
    final cx = index * slotWidth + slotWidth / 2;
    final cy = trayHeight / 2;

    if (orb == null) {
      return Positioned(
        left: cx - 14,
        top: cy - 14,
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
    final isDragging = _draggedSlot == index;

    // HellFire: Orbital aura for Lv.2/3 orbs
    final hasOrbitalAura = level >= 2;

    return Positioned(
      left: cx - orbSize / 2,
      top: cy - orbSize / 2,
      child: AnimatedScale(
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
                                alpha:
                                    0.4 + 0.2 * math.sin(pulse * 2 * math.pi))
                            : const Color(0xFFFF5A26).withValues(
                                alpha:
                                    0.4 + 0.2 * math.sin(pulse * 2 * math.pi)),
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
                  gradient: RadialGradient(
                      center: Alignment(-0.35, -0.38),
                      radius: 0.95,
                      colors: [
                        Colors.white.withValues(alpha: 0.95),
                        accent,
                        color,
                        Color.lerp(color, Colors.black, 0.75)!
                      ],
                      stops: const [
                        0.0,
                        0.22,
                        0.62,
                        1.0
                      ]),
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
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.78),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(
                                  color: level == 1
                                      ? const Color(0xFFC0C0C0)
                                      : level == 2
                                          ? const Color(0xFFFFD700)
                                          : const Color(0xFFFF5A26),
                                  width: 0.9)),
                          child: Text('Nv.$level',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8.5,
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
      ),
    );
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

  Widget _buildDraggedOrbPreview3D(double slotWidth, double orbSize) {
    if (_dragCurrentGlobalPos == null) return const SizedBox.shrink();
    final orb = engine.tray[_draggedSlot!];
    if (orb == null) return const SizedBox.shrink();

    final color = _elementColor(orb.element);
    final accent = _elementAccent(orb.element);
    final level = orb.level.index + 1;
    final previewSize = orbSize * 1.3;

    return Positioned(
      left: _dragCurrentGlobalPos!.dx - previewSize / 2,
      top: _dragCurrentGlobalPos!.dy - previewSize / 2,
      child: IgnorePointer(
        child: Container(
          width: previewSize,
          height: previewSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
                center: Alignment(-0.35, -0.38),
                radius: 0.95,
                colors: [
                  Colors.white.withValues(alpha: 0.95),
                  accent,
                  color,
                  Color.lerp(color, Colors.black, 0.7)!
                ]),
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: 0.8),
                  blurRadius: 20,
                  spreadRadius: 4)
            ],
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.9), width: 3),
          ),
          child: Stack(alignment: Alignment.center, children: [
            _buildElementIcon(orb.element, previewSize * 0.45),
            Text('$level',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: previewSize * 0.35,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(
                          color: Colors.black.withValues(alpha: 0.9),
                          blurRadius: 3)
                    ])),
          ]),
        ),
      ),
    );
  }

  Widget _buildMergeRing(
      int slot, double slotWidth, double orbSize, double trayHeight) {
    final color = const Color(0xFF4FFFA3);
    final pulse = _mergePulseCtrl.value;
    final cx = slot * slotWidth + slotWidth / 2;
    final cy = trayHeight / 2;

    return Positioned(
      left: cx - orbSize / 2 - 6 - pulse * 4,
      top: cy - orbSize / 2 - 6 - pulse * 4,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _mergePulseCtrl,
          builder: (context, _) => Container(
            width: orbSize + 12 + pulse * 8,
            height: orbSize + 12 + pulse * 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: color.withValues(alpha: 0.7 - pulse * 0.3),
                  width: 3 + pulse * 2),
              boxShadow: [
                BoxShadow(
                    color: color.withValues(alpha: 0.4 - pulse * 0.2),
                    blurRadius: 12 + pulse * 8,
                    spreadRadius: 2 + pulse * 2)
              ],
            ),
            child: Center(
                child: Text('¡FUSIONAR!',
                    style: TextStyle(
                        color: color.withValues(alpha: 0.9),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(
                              color: Colors.black.withValues(alpha: 0.8),
                              blurRadius: 2)
                        ]))),
          ),
        ),
      ),
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

// Boss Shield Break Bar (Block 3: Barrera Arcana + ¡BREAK!)
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
          const SizedBox(width: 6),
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
  const CombatSummaryDialog(
      {super.key,
      required this.victory,
      required this.damageTotal,
      required this.maxHit,
      required this.bullseyes,
      required this.reactions,
      required this.counterflicks,
      required this.mergesToThree,
      this.bestStreak = 0});
  @override
  Widget build(BuildContext context) {
    final loot = victory ? (damageTotal ~/ 5) : 0;
    return AlertDialog(
      backgroundColor: const Color(0xFF14090D),
      title: Text(victory ? 'VICTORIA' : 'DERROTA',
          style: TextStyle(
              color: victory ? const Color(0xFF4FFFA3) : Colors.redAccent,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2)),
      content: Column(
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
          ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CONTINUAR',
                style: TextStyle(
                    color: Color(0xFFB16EFF), fontWeight: FontWeight.w800))),
      ],
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

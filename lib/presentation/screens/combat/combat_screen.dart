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
import '../../../domain/meta/rune_system.dart';
import '../../../domain/meta/seal_challenge_rules.dart';
import '../../../domain/meta/squad_synergy_resolver.dart';
import '../../../domain/value_objects/element.dart';
import '../../../domain/value_objects/orb_level.dart';
import '../../controllers/meta_controller.dart';
import '../../combat_engine/brimstone_combat_game.dart';
import '../../widgets/tcg_card_widget.dart';
import '../meta/how_to_play_modal.dart';
import '../sanctuary/settings_modal.dart';

/// Full combat screen: restructured into 4 clean touch zones.
///
/// Zone 1 (Top, 68px): Header with back button, boss name, HP bar, ? / ⚙ buttons.
/// Zone 2 (Center, Expanded): 2.5D Arena with painted boss portrait, targets, projectiles.
/// Zone 3 (Lower-middle, 126px): 4 Squad Cards (TcgCardWidget) with own GestureDetectors.
/// Zone 4 (Bottom, 130px): Player HP + 5 Orb Merge Tray + ⚡ AUTO-MERGE button.
///
/// Drag/Merge/Throw rewritten for 60fps:
/// - Live drag preview follows finger at 1.25x scale
/// - Green/gold rings on compatible merge targets
/// - Auto-merge button fuses all available pairs
/// - Position-based aim (not velocity): parabolic 0.26s flight to target point
/// - Click-to-throw mode: tap orb to select, tap target to launch
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
    with SingleTickerProviderStateMixin {
  CombatEngine? _engine;
  late final BrimstoneCombatGame game;
  late final AnimationController _particleCtrl;
  late final AnimationController _mergePulseCtrl;
  int _lastPanMs = 0;
  bool _resolved = false;
  String? _reactionBanner;
  int _session = 0;

  // Drag state
  int? _draggedSlot;
  Offset? _dragPosition;
  int? _hoveredMergeSlot;
  int? _selectedOrbSlot; // For click-to-throw mode

  // Flying projectile for visual 0.26s parabolic flight
  _FlyingOrbProjectile? _flyingProjectile;

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

  @override
  void initState() {
    super.initState();
    _bursts = FixedRingBuffer<_BurstEffect>(
      PerformanceSettings.maxParticleBursts,
    );
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
        } catch (_) {
        }
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
      if (mounted) setState(() {});
    };
    _engine!.onReaction = (name) {
      ProceduralSfxEngine.playElementalReaction();
      ref.read(bountyProvider.notifier).increment('reactions');
      recordCodexReaction(ref, name);
      setState(() {
        _reactionBanner = name;
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
    game = BrimstoneCombatGame(
      engine: _engine!,
      onVictory: () => _resolve(true),
      onDefeat: () => _resolve(false),
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
        ? '¡Gólem de Pruebas destruido! DPS final: '
            '${engine.dps.toStringAsFixed(1)}'
        : 'El Gólem de Pruebas te superó. DPS final: '
            '${engine.dps.toStringAsFixed(1)}';
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
            child: const Text(
              'SEGUIR PRACTICANDO',
              style: TextStyle(color: Color(0xFFB16EFF)),
            ),
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
  double _slotCenterX(int slot) {
    return CombatEngine.layoutWidth / 5 * (slot + 0.5);
  }

  // Check if a point is over the tray area
  bool _isOverTray(double y) => y >= CombatEngine.trayY - 60;

  // Check if a point is over the arena area (above tray)
  bool _isOverArena(double y) => y < CombatEngine.trayY - 60;

  // Find merge target slot near drag position
  int? _findMergeTarget(int draggedSlot, double dragX) {
    final draggedOrb = engine.tray[draggedSlot];
    if (draggedOrb == null) return null;
    final targetSlot = _slotFromX(dragX);
    if (targetSlot == null || targetSlot == draggedSlot) return null;
    final targetOrb = engine.tray[targetSlot];
    if (targetOrb == null) return null;
    // Compatible: same element and same level (< 3)
    final compatible =
        (draggedOrb.element == targetOrb.element ||
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
        final compatible =
            (orbA.element == orbB.element ||
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

  // Drag handlers
  void _onPanStart(DragStartDetails d) {
    final (x, y) = _toEngine(d.localPosition);

    // Counter-flick priority
    if (engine.counterFlickAt(x, y, DateTime.now().millisecondsSinceEpoch / 1000)) {
      ProceduralSfxEngine.playCounterFlickDestroy();
      ref.read(bountyProvider.notifier).increment('counterflicks');
      return;
    }

    // Click-to-throw: tap orb in tray to select
    if (_isOverTray(y)) {
      final slot = _slotFromX(x);
      if (slot != null && engine.tray[slot] != null) {
        // If already selected, deselect
        if (_selectedOrbSlot == slot) {
          setState(() => _selectedOrbSlot = null);
        } else {
          setState(() => _selectedOrbSlot = slot);
        }
        return;
      }
    }

    // Drag from tray
    if (_isOverTray(y)) {
      final slot = _slotFromX(x);
      if (slot != null && engine.tray[slot] != null) {
        _draggedSlot = slot;
        _dragPosition = d.localPosition;
        _lastPanMs = DateTime.now().millisecondsSinceEpoch;
        engine.startDrag(slot, x, y);
      }
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_draggedSlot == null) return;
    _dragPosition = d.localPosition;
    final (x, y) = _toEngine(d.localPosition);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    engine.updateDrag(x, y, (nowMs - _lastPanMs) / 1000.0);
    _lastPanMs = nowMs;

    // Update merge hover target
    setState(() {
      _hoveredMergeSlot = _findMergeTarget(_draggedSlot!, x);
    });
  }

  void _onPanEnd(DragEndDetails d) {
    if (_draggedSlot == null) return;

    final draggedSlot = _draggedSlot!;
    final dragPos = _dragPosition ?? Offset.zero;
    final (dragX, dragY) = _toEngine(dragPos);

    // Determine if released over arena (throw) or tray (merge/swap)
    if (_isOverArena(dragY)) {
      // THROW: Launch projectile to target point
      _launchProjectileTo(dragX, dragY, draggedSlot);
    } else {
      // MERGE or SWAP in tray
      final targetSlot = _slotFromX(dragX);
      if (targetSlot != null && targetSlot != draggedSlot) {
        final targetOrb = engine.tray[targetSlot];
        final draggedOrb = engine.tray[draggedSlot];
        if (targetOrb != null && draggedOrb != null) {
          final compatible =
              (draggedOrb.element == targetOrb.element ||
                  draggedOrb.prismatic ||
                  targetOrb.prismatic) &&
              draggedOrb.level == targetOrb.level &&
              draggedOrb.level != OrbLevel.three;
          if (compatible) {
            // MERGE
            engine.mergeOrbs(draggedSlot, targetSlot);
            ProceduralSfxEngine.playOrbMerge(targetOrb.level.index);
          } else {
            // SWAP
            engine.swapOrbs(draggedSlot, targetSlot);
            ProceduralSfxEngine.playOrbSpawn();
          }
        } else if (targetOrb == null) {
          // Move to empty slot
          engine.swapOrbs(draggedSlot, targetSlot);
          ProceduralSfxEngine.playOrbSpawn();
        }
      }
    }

    setState(() {
      _draggedSlot = null;
      _dragPosition = null;
      _hoveredMergeSlot = null;
    });
  }

  void _onTapUp(TapUpDetails d) {
    final (x, y) = _toEngine(d.localPosition);

    // Counter-flick
    if (engine.counterFlickAt(x, y, 0)) {
      ProceduralSfxEngine.playCounterFlickDestroy();
      ref.read(bountyProvider.notifier).increment('counterflicks');
      return;
    }

    // Click-to-throw: if orb selected and tap in arena, launch to target
    if (_selectedOrbSlot != null && _isOverArena(y)) {
      _launchProjectileTo(x, y, _selectedOrbSlot!);
      setState(() => _selectedOrbSlot = null);
      return;
    }

    // Tap on empty area deselects
    if (_selectedOrbSlot != null) {
      setState(() => _selectedOrbSlot = null);
    }
  }

  // Launch visual projectile with 0.26s parabolic flight
  void _launchProjectileTo(double targetX, double targetY, int slot) {
    final orb = engine.tray[slot];
    if (orb == null) return;

    // Find nearest target for magnetism
    double finalTargetX = targetX;
    double finalTargetY = targetY;
    for (final t in engine.targets) {
      final tx = t.xAt(engine.time, engine.effectiveAngularSpeed(t));
      final ty = t.yAt(engine.time, engine.effectiveAngularSpeed(t));
      final dist = math.sqrt((targetX - tx) * (targetX - tx) + (targetY - ty) * (targetY - ty));
      if (dist < 45) {
        finalTargetX = tx;
        finalTargetY = ty;
        break;
      }
    }

    // Clamp targetY to boss plane
    finalTargetY = finalTargetY.clamp(
      CombatEngine.bossScreenY - 100,
      CombatEngine.bossScreenY + 50,
    );

    final startX = _slotCenterX(slot);
    final startY = CombatEngine.trayY;

    // Create visual flying projectile
    _flyingProjectile = _FlyingOrbProjectile(
      element: orb.element,
      level: orb.level,
      startX: startX,
      startY: startY,
      targetX: finalTargetX,
      targetY: finalTargetY,
      duration: 0.26,
    );

    // Remove orb from tray immediately
    engine.tray[slot] = null;

    ProceduralSfxEngine.playOrbFlick();

    // Animate flight
    _animateFlight(finalTargetX, finalTargetY, orb);
  }

  Future<void> _animateFlight(
    double targetX,
    double targetY,
    CombatOrb orb,
  ) async {
    const flightDuration = 0.26;
    const frames = 60;
    final frameTime = flightDuration / frames;

    for (var i = 0; i <= frames; i++) {
      if (!mounted) return;
      final t = i / frames;
      setState(() {
        _flyingProjectile = _flyingProjectile?.copyWith(progress: t);
      });
      await Future.delayed(Duration(milliseconds: (frameTime * 1000).round()));
    }

    // Resolve impact using public engine API
    _resolveImpact(targetX, targetY, orb);

    if (mounted) {
      setState(() => _flyingProjectile = null);
    }
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
        d,
        engine.innerRadiusFor(t),
        engine.outerRadiusFor(t),
      );
      // Use public rank comparison via CombatEngine._rank (private) - replicate logic
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
          orb: orb,
          target: null,
          multiplier: 0.25,
          kind: HitKind.graze,
        );
      }
      return;
    }
    // Call engine's internal resolution by simulating arrival
    // We use a dummy projectile to trigger the engine's _resolveArrival
    final dummyProj = OrbProjectile(
      id: 'visual_${DateTime.now().millisecondsSinceEpoch}',
      element: orb.element,
      level: orb.level,
      startX: _slotCenterX(0), // not used
      startY: CombatEngine.trayY,
      targetX: targetX,
      targetY: targetY,
      flightDuration: 0.001, // instant
    );
    engine.projectiles.add(dummyProj);
    // Tick once to process
    engine.tick(0.001);
    engine.projectiles.removeWhere((p) => p.id == dummyProj.id);
  }

  static int _hitRank(HitKind k) => switch (k) {
        HitKind.bullseye => 0,
        HitKind.normal => 1,
        HitKind.graze => 2,
        HitKind.miss => 3,
      };

  // Card invocation handler
  void _onCardTap(int index) {
    if (engine.castSkill(index)) {
      final card = engine.cards[index];
      // Get skill description from static map
      final skillDesc = CombatEngine.skillDescriptions[card.id] ?? card.id;
      _showSkillBanner(card.name, skillDesc);
      ProceduralSfxEngine.playCardSkillInvoke();
      setState(() {});
    }
  }

  void _showSkillBanner(String cardName, String skillName) {
    // Could show a banner overlay, for now just log
    debugPrint('¡$cardName USA $skillName!');
  }

  @override
  Widget build(BuildContext context) {
    if (_engine == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0C0608),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFB16EFF)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0C0608),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        onTapUp: _onTapUp,
        child: Column(
          key: ValueKey<int>(_session),
          children: [
            // ============================================================
            // ZONE 1: HEADER (68px)
            // ============================================================
            SizedBox(
              height: 68,
              child: _buildHeader(),
            ),

            // ============================================================
            // ZONE 2: ARENA (Expanded) - 2.5D Combat
            // ============================================================
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(child: GameWidget(game: game)),
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
                  // Danger overlay (vignette + crit streak)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: _CombatDangerOverlay(engine: engine),
                    ),
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
                              horizontal: 18,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFFF5A26)),
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

            // ============================================================
            // ZONE 3: SQUAD CARDS (126px)
            // ============================================================
            SizedBox(
              height: 126,
              child: _buildSquadCards(),
            ),

            // ============================================================
            // ZONE 4: ORBS TRAY + PLAYER HP (130px)
            // ============================================================
            SizedBox(
              height: 130,
              child: _buildOrbsTray(),
            ),

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
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // ZONE 1: HEADER
  // ------------------------------------------------------------------
  Widget _buildHeader() {
    final hpFraction = engine.bossHp / engine.boss.maxHp;
    final isEnraged = engine.enraged;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A0A0F), Color(0xFF0C0608)],
        ),
        border: Border(
          bottom: BorderSide(color: Color(0xFF2A151A), width: 1),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              // Back button
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                onPressed: () => Navigator.of(context).maybePop(),
                tooltip: 'Salir del combate',
              ),
              const SizedBox(width: 4),

              // Boss name + enrage indicator
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          engine.boss.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (isEnraged) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF2A54), Color(0xFFFFD700)],
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'FURIA',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 7,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    // Boss HP bar
                    Stack(
                      children: [
                        Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E0A0E),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: hpFraction.clamp(0.0, 1.0),
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isEnraged
                                    ? [Colors.orangeAccent, Colors.redAccent]
                                    : [Colors.redAccent, const Color(0xFFCC0000)],
                              ),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // HP text
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '${engine.bossHp.toInt()} / ${engine.boss.maxHp.toInt()}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),

              // Help button
              IconButton(
                icon: const Icon(Icons.help_outline, color: Colors.white70, size: 22),
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: const Color(0xFF14090D),
                  builder: (_) => const HowToPlayModal(),
                ),
                tooltip: 'Ayuda',
              ),

              // Settings button
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white70, size: 22),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const SettingsModal(),
                ),
                tooltip: 'Ajustes',
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // ZONE 3: SQUAD CARDS
  // ------------------------------------------------------------------
  Widget _buildSquadCards() {
    final cards = engine.cards;
    if (cards.isEmpty) {
      return const Center(
        child: Text(
          'Sin escuadrón',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF14090D), Color(0xFF0C0608)],
        ),
        border: Border(
          top: BorderSide(color: Color(0xFF2A151A), width: 1),
        ),
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
            onTap: isReady ? () => _onCardTap(index) : null,
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------------
  // ZONE 4: ORBS TRAY + PLAYER HP
  // ------------------------------------------------------------------
  Widget _buildOrbsTray() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF14090D), Color(0xFF0C0608)],
        ),
        border: Border(
          top: BorderSide(color: Color(0xFF2A151A), width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Player HP bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                const Icon(Icons.favorite, color: Color(0xFFFF2A54), size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            'HP ',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${engine.playerHp.toInt()} / ${engine.playerMaxHp.toInt()}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: Container(
                          height: 5,
                          color: const Color(0xFF1E0A0E),
                          child: FractionallySizedBox(
                            widthFactor: (engine.hpFraction).clamp(0.0, 1.0),
                            alignment: Alignment.centerLeft,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: engine.isLowHp
                                      ? [Colors.redAccent, const Color(0xFFFF5A26)]
                                      : [const Color(0xFF4FFFA3), const Color(0xFF00C853)],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Orbs tray
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final trayWidth = constraints.maxWidth;
                final slotWidth = trayWidth / 5;
                final trayHeight = constraints.maxHeight;
                final orbSize = (trayHeight * 0.7).clamp(36.0, 56.0);

                return Stack(
                  children: [
                    // Background
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A0407),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF2A151A), width: 1),
                      ),
                    ),

                    // Slot dividers
                    for (var i = 1; i < 5; i++)
                      Positioned(
                        left: i * slotWidth,
                        top: 2,
                        bottom: 2,
                        child: Container(
                          width: 1,
                          color: const Color(0xFF2A151A),
                        ),
                      ),

                    // Orbs in slots
                    for (var i = 0; i < 5; i++)
                      _buildOrbSlot(i, slotWidth, orbSize, trayHeight),

                    // Dragged orb preview (follows finger)
                    if (_draggedSlot != null && _dragPosition != null)
                      _buildDraggedOrbPreview(slotWidth, orbSize),

                    // Green merge rings on compatible targets
                    if (_hoveredMergeSlot != null)
                      _buildMergeRing(_hoveredMergeSlot!, slotWidth, orbSize, trayHeight),

                    // Selected orb halo (click-to-throw mode)
                    if (_selectedOrbSlot != null)
                      _buildSelectionHalo(_selectedOrbSlot!, slotWidth, orbSize, trayHeight),

                    // Auto-merge button
                    Positioned(
                      top: 4,
                      right: 12,
                      child: _buildAutoMergeButton(),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrbSlot(int index, double slotWidth, double orbSize, double trayHeight) {
    final orb = engine.tray[index];
    if (orb == null) {
      return Positioned(
        left: index * slotWidth + slotWidth / 2 - 14,
        top: trayHeight / 2 - 14,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1A0A0F),
            border: Border.all(
              color: const Color(0xFF2A151A),
              width: 1,
              style: BorderStyle.solid,
            ),
          ),
          child: Center(
            child: Icon(
              Icons.add,
              size: 16,
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ),
        ),
      );
    }

    final color = _elementColor(orb.element);
    final accent = _elementAccent(orb.element);
    final level = orb.level.index + 1;

    return Positioned(
      left: index * slotWidth + slotWidth / 2 - orbSize / 2,
      top: trayHeight / 2 - orbSize / 2,
      child: Container(
        width: orbSize,
        height: orbSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.9),
              color,
              Color.lerp(color, const Color(0xFF0A0407), 0.4)!,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.5),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
          border: Border.all(
            color: accent.withValues(alpha: 0.8),
            width: 2,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Level number
            Text(
              '$level',
              style: TextStyle(
                color: Colors.white,
                fontSize: orbSize * 0.35,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.8),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
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
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFB16EFF)],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDraggedOrbPreview(double slotWidth, double orbSize) {
    if (_dragPosition == null) return const SizedBox.shrink();

    final orb = engine.tray[_draggedSlot!];
    if (orb == null) return const SizedBox.shrink();

    final color = _elementColor(orb.element);
    final level = orb.level.index + 1;
    final previewSize = orbSize * 1.25;

    return Positioned(
      left: _dragPosition!.dx - previewSize / 2,
      top: _dragPosition!.dy - previewSize / 2,
      child: IgnorePointer(
        child: AnimatedScale(
          scale: 1.0,
          duration: const Duration(milliseconds: 50),
          child: Container(
            width: previewSize,
            height: previewSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withValues(alpha: 0.95),
                  color,
                  Color.lerp(color, const Color(0xFF0A0407), 0.3)!,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.8),
                  blurRadius: 16,
                  spreadRadius: 3,
                ),
              ],
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.9),
                width: 3,
              ),
            ),
            child: Center(
              child: Text(
                '$level',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: previewSize * 0.4,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.9),
                      blurRadius: 3,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMergeRing(int slot, double slotWidth, double orbSize, double trayHeight) {
    final color = const Color(0xFF4FFFA3); // Green merge ring
    final pulse = _mergePulseCtrl.value;

    return Positioned(
      left: slot * slotWidth + slotWidth / 2 - orbSize / 2 - 6 - pulse * 4,
      top: trayHeight / 2 - orbSize / 2 - 6 - pulse * 4,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _mergePulseCtrl,
          builder: (context, _) {
            return Container(
              width: orbSize + 12 + pulse * 8,
              height: orbSize + 12 + pulse * 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: color.withValues(alpha: 0.7 - pulse * 0.3),
                  width: 3 + pulse * 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4 - pulse * 0.2),
                    blurRadius: 12 + pulse * 8,
                    spreadRadius: 2 + pulse * 2,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '¡FUSIONAR!',
                  style: TextStyle(
                    color: color.withValues(alpha: 0.9),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.8),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSelectionHalo(int slot, double slotWidth, double orbSize, double trayHeight) {
    final color = const Color(0xFFFFD700); // Gold selection halo

    return Positioned(
      left: slot * slotWidth + slotWidth / 2 - orbSize / 2 - 4,
      top: trayHeight / 2 - orbSize / 2 - 4,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _mergePulseCtrl,
          builder: (context, _) {
            final pulse = (math.sin(_mergePulseCtrl.value * 2 * math.pi) + 1) / 2;
            return Container(
              width: orbSize + 8 + pulse * 6,
              height: orbSize + 8 + pulse * 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: color.withValues(alpha: 0.6 + pulse * 0.4),
                  width: 2 + pulse * 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3 + pulse * 0.2),
                    blurRadius: 10 + pulse * 6,
                    spreadRadius: 1 + pulse,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAutoMergeButton() {
    // Check if any merge is possible
    var canMerge = false;
    for (var i = 0; i < engine.tray.length; i++) {
      if (engine.tray[i] == null) continue;
      for (var j = i + 1; j < engine.tray.length; j++) {
        if (engine.tray[j] == null) continue;
        final orbA = engine.tray[i]!;
        final orbB = engine.tray[j]!;
        final compatible =
            (orbA.element == orbB.element || orbA.prismatic || orbB.prismatic) &&
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: canMerge
                    ? [const Color(0xFFFFD700), const Color(0xFFFF5A26)]
                    : [Colors.grey.shade800, Colors.grey.shade900],
              ),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: canMerge ? const Color(0xFFFFD700) : Colors.grey.shade700,
                width: 1.5,
              ),
              boxShadow: canMerge
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_fix_high, size: 12, color: Colors.black),
                const SizedBox(width: 3),
                Text(
                  'FUSIONAR IGUALES',
                  style: TextStyle(
                    color: canMerge ? Colors.black : Colors.white38,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// Flying projectile painter (0.26s parabolic flight)
// ----------------------------------------------------------------------
class _FlyingOrbProjectile {
  final Element element;
  final OrbLevel level;
  final double startX;
  final double startY;
  final double targetX;
  final double targetY;
  final double duration;
  double progress; // 0..1

  _FlyingOrbProjectile({
    required this.element,
    required this.level,
    required this.startX,
    required this.startY,
    required this.targetX,
    required this.targetY,
    required this.duration,
    this.progress = 0.0,
  });

  _FlyingOrbProjectile copyWith({double? progress}) => _FlyingOrbProjectile(
        element: element,
        level: level,
        startX: startX,
        startY: startY,
        targetX: targetX,
        targetY: targetY,
        duration: duration,
        progress: progress ?? this.progress,
      );
}

class _FlyingProjectilePainter extends CustomPainter {
  final _FlyingOrbProjectile projectile;
  final BrimstoneCombatGame game;

  _FlyingProjectilePainter({required this.projectile, required this.game});

  @override
  void paint(Canvas canvas, Size size) {
    final p = projectile.progress.clamp(0.0, 1.0);
    final z = CombatMath.flightZ(p, 1.0); // parabolic Z

    // Position with parabolic arc
    final x = CombatMath.lerp(projectile.startX, projectile.targetX, p);
    final baseY = CombatMath.lerp(projectile.startY, projectile.targetY, p);
    final arcHeight = 115.0; // max height at z=0.5
    final arc = math.sin(z * math.pi) * arcHeight;
    final y = baseY - arc;

    // Scale with perspective (1.0 -> 0.42)
    final scale = CombatMath.flightScale(z);

    // Convert to screen coords
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

    // Trail (drawn behind)
    _drawTrail(canvas, elementColor, elementAccent, orbRadius, p);

    // Orb body
    _drawOrb(canvas, elementColor, elementAccent, orbRadius, levelNum);

    canvas.restore();
  }

  void _drawTrail(Canvas canvas, Color color, Color accent, double radius, double p) {
    if (p < 0.1) return;
    final trailLength = (p * 8).clamp(0.0, 8);
    for (var i = 0; i < trailLength; i++) {
      final t = i / trailLength;
      final trailP = (p - t * 0.15).clamp(0.0, 1.0);
      if (trailP <= 0) continue;
      final trailZ = CombatMath.flightZ(trailP, 1.0);
      final trailScale = CombatMath.flightScale(trailZ);
      final alpha = (1.0 - t) * 0.4 * trailScale;
      canvas.drawCircle(
        Offset(0, 0),
        radius * trailScale * 0.8,
        Paint()
          ..color = color.withValues(alpha: alpha)
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
  }

  void _drawOrb(Canvas canvas, Color color, Color accent, double radius, int level) {
    // Outer glow
    canvas.drawCircle(
      Offset.zero,
      radius + 4,
      Paint()
        ..color = color.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Main orb
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withValues(alpha: 0.9),
            color,
            Color.lerp(color, const Color(0xFF0A0407), 0.5)!,
          ],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius))
        ..style = PaintingStyle.fill,
    );

    // Border
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Level number
    final textPainter = TextPainter(
      text: TextSpan(
        text: '$level',
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.6,
          fontWeight: FontWeight.w900,
          shadows: [
            Shadow(color: Colors.black, blurRadius: 2),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2, -textPainter.height / 2),
    );
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

  @override
  bool shouldRepaint(covariant _FlyingProjectilePainter old) =>
      old.projectile.progress != projectile.progress ||
      old.projectile.targetX != projectile.targetX ||
      old.projectile.targetY != projectile.targetY;
}

// ----------------------------------------------------------------------
// Existing supporting classes (unchanged)
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
    return Stack(
      children: [
        if (low)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.red.withValues(alpha: pulse),
                  width: 10,
                ),
                gradient: RadialGradient(
                  radius: 0.95,
                  colors: [
                    Colors.transparent,
                    Colors.red.withValues(alpha: pulse * 0.35),
                  ],
                ),
              ),
            ),
          ),
        if (streak >= 3)
          Positioned(
            top: 150,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFC93C)),
              ),
              child: Text(
                '¡RACHA CRÍTICA x$streak! +${((engine.bullseyeStreakBonus - 1) * 100).round()}%',
                style: const TextStyle(
                  color: Color(0xFFFFC93C),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TrainingTools extends StatefulWidget {
  final CombatEngine engine;
  final VoidCallback onFillMana;
  final VoidCallback onRestart;

  const _TrainingTools({
    required this.engine,
    required this.onFillMana,
    required this.onRestart,
  });

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
        border: Border.all(color: const Color(0xFF3FD8FF)),
      ),
      child: Row(
        children: [
          const Icon(Icons.speed, color: Color(0xFF3FD8FF), size: 16),
          const SizedBox(width: 6),
          Text(
            'DPS ${dps.toStringAsFixed(1)}',
            style: const TextStyle(
              color: Color(0xFF3FD8FF),
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: widget.onFillMana,
            icon: const Icon(Icons.bolt, size: 14, color: Color(0xFFB16EFF)),
            label: const Text(
              'MANÁ',
              style: TextStyle(color: Color(0xFFB16EFF), fontSize: 10),
            ),
          ),
          TextButton.icon(
            onPressed: widget.onRestart,
            icon: const Icon(Icons.refresh, size: 14, color: Colors.white54),
            label: const Text(
              'REINICIAR',
              style: TextStyle(color: Colors.white54, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
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
        ),
        ManaCard(
          id: 'abyss_stalker',
          name: 'Acechador de Escarcha',
          element: Element.abyssal,
          baseManaCost: 95,
          attack: 12,
        ),
        ManaCard(
          id: 'terra_golem',
          name: 'Gólem de Basalto',
          element: Element.telluric,
          baseManaCost: 100,
          attack: 8,
        ),
        ManaCard(
          id: 'void_specter',
          name: 'Espectro del Sello',
          element: Element.empty,
          baseManaCost: 110,
          attack: 15,
        ),
      ],
      playerMaxHp: 100,
    );

class _BurstEffect {
  final double x;
  final double y;
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

  _BurstsPainter({
    required this.bursts,
    required this.progress,
    this.ringsPerBurst = 4,
    this.scale = 1.0,
  });

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

  const CombatSummaryDialog({
    super.key,
    required this.victory,
    required this.damageTotal,
    required this.maxHit,
    required this.bullseyes,
    required this.reactions,
    required this.counterflicks,
    required this.mergesToThree,
    this.bestStreak = 0,
  });

  @override
  Widget build(BuildContext context) {
    final loot = victory ? (damageTotal ~/ 5) : 0;
    return AlertDialog(
      backgroundColor: const Color(0xFF14090D),
      title: Text(
        victory ? 'VICTORIA' : 'DERROTA',
        style: TextStyle(
          color: victory ? const Color(0xFF4FFFA3) : Colors.redAccent,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SummaryRow(label: 'Daño total', value: '$damageTotal'),
          _SummaryRow(label: 'Golpe máximo', value: '${maxHit.toInt()}'),
          _SummaryRow(label: 'Bullseyes conectados', value: '$bullseyes'),
          _SummaryRow(label: 'Mejor racha crítica', value: 'x$bestStreak'),
          _SummaryRow(label: 'Reacciones detonadas', value: '$reactions'),
          _SummaryRow(
            label: 'Esferas Nv.3 fusionadas',
            value: '$mergesToThree',
          ),
          _SummaryRow(label: 'Counter-flicks', value: '$counterflicks'),
          const SizedBox(height: 10),
          _SummaryRow(
            label: 'Botín',
            value: '$loot oro',
            valueColor: const Color(0xFFFFC93C),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'CONTINUAR',
            style: TextStyle(
              color: Color(0xFFB16EFF),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
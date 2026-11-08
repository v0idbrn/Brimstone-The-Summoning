import 'package:flame/game.dart';
import 'package:flutter/material.dart' hide Element;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/procedural_sfx_engine.dart';
import '../../../domain/combat/combat_engine.dart';
import '../../../domain/combat/combat_math.dart';
import '../../../domain/combat/combat_models.dart';
import '../../../domain/value_objects/element.dart';
import '../../../domain/value_objects/orb_level.dart';
import '../../controllers/meta_controller.dart';
import '../../combat_engine/brimstone_combat_game.dart';
import '../../combat_engine/combat_hud_overlay.dart';

/// Full combat screen: Flame game + fullscreen gesture bridge + HUD overlay.
///
/// Pan gestures are routed to the pure [CombatEngine]: dragging an orb in the
/// merge tray, flicking it upward to launch, or tapping a corrupted orb to
/// counter-flick it.
class CombatScreen extends ConsumerStatefulWidget {
  final CombatEngine? engine;
  final void Function(bool victory, double playerHp)? onCombatResolved;

  const CombatScreen({super.key, this.engine, this.onCombatResolved});

  /// Builds the engine from the squad, relics and rift difficulty.
  static CombatEngine buildEngine({
    required BossConfig boss,
    required List<ManaCard> cards,
    required double playerMaxHp,
    CombatModifiers modifiers = const CombatModifiers(),
  }) => CombatEngine(
    boss: boss,
    cards: cards,
    playerMaxHp: playerMaxHp,
    modifiers: modifiers,
  );

  @override
  ConsumerState<CombatScreen> createState() => _CombatScreenState();
}

class _CombatScreenState extends ConsumerState<CombatScreen> {
  late final CombatEngine engine;
  late final BrimstoneCombatGame game;
  int _lastPanMs = 0;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    engine = widget.engine ?? defaultEngine();
    // Wire combat audio events to the procedural SFX engine.
    engine.onHit = (kind) {
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
    };
    engine.onReaction = (name) {
      ProceduralSfxEngine.playElementalReaction();
      ref.read(bountyProvider.notifier).increment('reactions');
    };
    engine.onMerge = (level) {
      ProceduralSfxEngine.playOrbMerge(level.index);
      if (level == OrbLevel.three) {
        ref.read(bountyProvider.notifier).increment('merge_to_three');
      }
    };
    engine.onEnrage = () {
      ProceduralSfxEngine.playBossEnrage();
    };
    game = BrimstoneCombatGame(
      engine: engine,
      onVictory: () => _resolve(true),
      onDefeat: () => _resolve(false),
    );
  }

  void _resolve(bool victory) {
    if (_resolved) return;
    _resolved = true;
    widget.onCombatResolved?.call(victory, engine.playerHp);
  }

  (double, double) _toEngine(Offset p) => game.toEngineCoords(p.dx, p.dy);

  void _onPanStart(DragStartDetails d) {
    final (x, y) = _toEngine(d.localPosition);
    // Counter-flick takes priority: touch a corrupted orb to destroy it.
    if (engine.counterFlickAt(
      x,
      y,
      DateTime.now().millisecondsSinceEpoch / 1000,
    )) {
      ProceduralSfxEngine.playCounterFlickDestroy();
      ref.read(bountyProvider.notifier).increment('counterflicks');
      return;
    }
    if (y >= CombatEngine.trayY - 60) {
      final slot = _slotFromX(x);
      if (slot != null) engine.startDrag(slot, x, y);
    }
  }

  int? _slotFromX(double x) {
    final slot = (x / (CombatEngine.layoutWidth / 5)).floor();
    return slot < 0 || slot > 4 ? null : slot;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final (x, y) = _toEngine(d.localPosition);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    engine.updateDrag(x, y, (nowMs - _lastPanMs) / 1000.0);
    _lastPanMs = nowMs;
  }

  void _onPanEnd(DragEndDetails d) {
    final vy = d.velocity.pixelsPerSecond.dy / game.viewScale;
    if (vy < CombatMath.flickSpeedThreshold) {
      ProceduralSfxEngine.playOrbFlick();
    }
    engine.releaseDrag(vy);
  }

  void _onTapUp(TapUpDetails d) {
    final (x, y) = _toEngine(d.localPosition);
    if (engine.counterFlickAt(x, y, 0)) {
      ProceduralSfxEngine.playCounterFlickDestroy();
      ref.read(bountyProvider.notifier).increment('counterflicks');
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0608),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        onTapUp: _onTapUp,
        child: Stack(
          children: [
            Positioned.fill(child: GameWidget(game: game)),
            Positioned.fill(
              child: CombatHudOverlay(
                engine: engine,
                onVictory: () => _resolve(true),
                onDefeat: () => _resolve(false),
              ),
            ),
          ],
        ),
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

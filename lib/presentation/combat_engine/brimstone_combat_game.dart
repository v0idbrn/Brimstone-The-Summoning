import 'package:flame/game.dart';

import '../../domain/combat/combat_engine.dart';
import '../../domain/combat/combat_math.dart';
import 'arena_background_25d.dart';
import 'boss_actor_component.dart';
import 'boss_target_reticle.dart';
import 'enemy_corrupted_orb.dart';
import 'floating_combat_text.dart';
import 'orb_projectile_25d.dart';

/// First-person 2.5D combat game (logical resolution 430 x 932 portrait).
/// All simulation lives in the pure [CombatEngine]; this class only owns the
/// render tree, screen shake and gesture plumbing.
/// NO merge tray here - the tray is a Flutter widget overlay for unified gestures.
class BrimstoneCombatGame extends FlameGame {
  final CombatEngine engine;
  final void Function()? onVictory;
  final void Function()? onDefeat;

  double viewScale = 1;
  double baseOffsetX = 0;
  double baseOffsetY = 0;
  double shakeX = 0;
  double shakeY = 0;

  BrimstoneCombatGame({required this.engine, this.onVictory, this.onDefeat});

  /// Absolute offsets including screen shake.
  double get offsetX => baseOffsetX + shakeX;
  double get offsetY => baseOffsetY + shakeY;

  @override
  Future<void> onLoad() async {
    _recalculateView();
    engine.onVictory = onVictory;
    engine.onDefeat = onDefeat;
    await addAll([
      ArenaBackground25D(this),
      BossActorComponent(this),
      BossTargetReticle(this),
      OrbProjectile25D(this),
      EnemyCorruptedOrb(this),
      FloatingCombatText(this),
      // MergeTrayComponent REMOVED - tray is now a Flutter widget overlay
    ]);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _recalculateView();
  }

  void _recalculateView() {
    final w = canvasSize.x;
    final h = canvasSize.y;
    // Full width, no letterboxing - let Flutter widget handle responsive sizing
    viewScale = w / CombatEngine.layoutWidth;
    baseOffsetX = 0;
    baseOffsetY = (h - CombatEngine.layoutHeight * viewScale) / 2;
  }

  /// Converts a widget-space point to engine logical coordinates.
  (double, double) toEngineCoords(double wx, double wy) =>
      ((wx - baseOffsetX) / viewScale, (wy - baseOffsetY) / viewScale);

  @override
  void update(double dt) {
    super.update(dt);
    engine.tick(dt);
    final t = engine.time;
    shakeX = CombatMath.shakeOffset(engine.trauma, t, 14);
    shakeY = -CombatMath.shakeOffset(engine.trauma, t + 0.31, 10);
  }
}

import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Element;

import 'brimstone_combat_game.dart';
import 'arena_background_25d.dart';

/// Corrupted boss projectiles: fly z=1 (scale .38) -> z=0 (scale 1.15) in
/// ~1.65s toward the tray. Destroyable by touch or own-orb intercept
/// (Counter-Flick) for +20 mana to the whole deck.
class EnemyCorruptedOrb extends PositionComponent {
  final BrimstoneCombatGame combatGame;

  EnemyCorruptedOrb(this.combatGame) {
    position = Vector2.zero();
    priority = 2;
  }

  @override
  void render(Canvas canvas) {
    final e = combatGame.engine;
    canvas.save();
    canvas.translate(combatGame.offsetX, combatGame.offsetY);
    canvas.scale(combatGame.viewScale);

    for (final p in e.enemyProjectiles) {
      final ez = math.min(1.0, p.elapsed / p.duration);
      final z = 1.0 - ez; // boss-plane depth: 1 at spawn, 0 on arrival.
      final scale = 1.15 - (1.15 - 0.38) * ez;
      final x = CombatMathLerp.lerp(p.startX, p.endX, ez);
      final y = CombatMathLerp.lerp(p.startY, p.endY, ez);
      final r = 24.0 * scale;
      final pulse = 0.6 + 0.4 * math.sin(e.time * 14);

      canvas.drawCircle(
        Offset(x, y),
        r + 5 * pulse,
        Paint()..color = const Color(0xFF8B1E1E).withValues(alpha: 0.35),
      );
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()..color = const Color(0xFFB32B23),
      );
      canvas.drawCircle(
        Offset(x, y),
        r * 0.45,
        Paint()
          ..color = const Color(0xFFFFD9A0).withValues(alpha: 0.85 * pulse),
      );
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white.withValues(alpha: 0.0 + 0.6 * z),
      );
    }
    canvas.restore();
  }
}

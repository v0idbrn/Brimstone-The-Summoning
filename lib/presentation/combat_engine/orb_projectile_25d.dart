import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Element;

import '../../domain/value_objects/element.dart';
import 'brimstone_combat_game.dart';
import 'arena_background_25d.dart';

/// Player orb projectile: travels z 0 (tray) -> 1 (boss plane) in 0.32-0.55s
/// with scale = 1 - 0.62z, a 115px vertical arc and the flick's target_x.
class OrbProjectile25D extends PositionComponent {
  final BrimstoneCombatGame combatGame;

  OrbProjectile25D(this.combatGame) {
    position = Vector2.zero();
    priority = 2;
  }

  Color colorFor(Element e) => switch (e) {
        Element.igneous => const Color(0xFFFF5A26),
        Element.abyssal => const Color(0xFF3FD8FF),
        Element.telluric => const Color(0xFFB0703B),
        Element.empty => const Color(0xFFB16EFF),
      };

  @override
  void render(Canvas canvas) {
    final e = combatGame.engine;
    canvas.save();
    canvas.translate(combatGame.offsetX, combatGame.offsetY);
    canvas.scale(combatGame.viewScale);

    for (final p in e.projectiles) {
      final z = math.min(1.0, p.elapsed / p.flightDuration);
      final scale = 1.0 - 0.62 * z;
      final x = CombatMathLerp.lerp(p.startX, p.targetX, z);
      final y = CombatMathLerp.lerp(p.startY, p.targetY, z) -
          math.sin(z * math.pi) * 115.0;
      final r = 22.0 * scale;

      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()..color = colorFor(p.element).withValues(alpha: 0.95),
      );
      // Motion trail.
      for (var i = 1; i <= 3; i++) {
        final zz = math.max(0.0, z - i * 0.05);
        final tx = CombatMathLerp.lerp(p.startX, p.targetX, zz);
        final ty = CombatMathLerp.lerp(p.startY, p.targetY, zz) -
            math.sin(zz * math.pi) * 115.0;
        canvas.drawCircle(
          Offset(tx, ty),
          r * (1 - i * 0.2),
          Paint()..color = colorFor(p.element).withValues(alpha: 0.28 / i),
        );
      }
      canvas.drawCircle(
        Offset(x, y),
        r * (0.35 + 0.22 * p.level.index),
        Paint()..color = Colors.white.withValues(alpha: 0.6),
      );
    }
    canvas.restore();
  }
}

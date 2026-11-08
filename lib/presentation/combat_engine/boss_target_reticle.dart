import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Element;

import '../../domain/value_objects/element.dart';
import 'brimstone_combat_game.dart';

/// Moving dimensional target reticles over the boss: outer ring radius 46,
/// critical inner center radius 20 (+40% with Ojo del Abismo), petrify-slowed.
class BossTargetReticle extends PositionComponent {
  final BrimstoneCombatGame combatGame;

  BossTargetReticle(this.combatGame) {
    position = Vector2.zero();
    priority = 1;
  }

  Color get auraColor => switch (combatGame.engine.aura) {
        Element.igneous => const Color(0xFFFF5A26),
        Element.abyssal => const Color(0xFF3FD8FF),
        Element.telluric => const Color(0xFFB0703B),
        Element.empty => const Color(0xFFB16EFF),
        null => Colors.grey.shade700,
      };

  @override
  void render(Canvas canvas) {
    final e = combatGame.engine;
    canvas.save();
    canvas.translate(combatGame.offsetX, combatGame.offsetY);
    canvas.scale(combatGame.viewScale);

    for (final t in e.targets) {
      final x = t.xAt(e.time, e.effectiveAngularSpeed(t));
      final y = t.yAt(e.time, e.effectiveAngularSpeed(t));
      final outer = e.outerRadiusFor(t);
      final inner = e.innerRadiusFor(t);

      canvas.drawCircle(
        Offset(x, y),
        outer,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = auraColor,
      );
      // Rotating tick marks on the outer ring.
      for (var i = 0; i < 4; i++) {
        final a = e.time * 1.5 + i * math.pi / 2;
        canvas.drawCircle(
          Offset(x + math.cos(a) * outer, y + math.sin(a) * outer),
          3.5,
          Paint()..color = auraColor.withValues(alpha: 0.8),
        );
      }
      final centerFill = Paint()
        ..color = auraColor.withValues(alpha: 0.35)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), inner, centerFill);
      canvas.drawCircle(
        Offset(x, y),
        inner,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white,
      );
      if (t.frozen) {
        canvas.drawCircle(
          Offset(x, y),
          outer,
          Paint()..color = Colors.lightBlueAccent.withValues(alpha: 0.25),
        );
      }
    }
    canvas.restore();
  }
}

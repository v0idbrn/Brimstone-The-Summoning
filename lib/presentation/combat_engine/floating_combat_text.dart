import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';

import '../../domain/combat/combat_models.dart';
import 'brimstone_combat_game.dart';

/// Floating combat text: normal damage, golden bullseye crits and reaction
/// / skill banners, each rising and fading over ~1 second.
class FloatingCombatText extends PositionComponent {
  final BrimstoneCombatGame combatGame;

  FloatingCombatText(this.combatGame) {
    position = Vector2.zero();
    priority = 4;
  }

  @override
  void render(Canvas canvas) {
    final e = combatGame.engine;
    canvas.save();
    canvas.translate(combatGame.offsetX, combatGame.offsetY);
    canvas.scale(combatGame.viewScale);

    for (final t in e.texts) {
      final rise = 42.0 * t.age;
      final opacity = (1.0 - t.age / 1.1).clamp(0.0, 1.0);
      final fontSize = switch (t.kind) {
        FloatingTextKind.crit => 26.0,
        FloatingTextKind.reaction => 22.0,
        FloatingTextKind.skill => 20.0,
        FloatingTextKind.normal => 16.0,
      };
      final color = switch (t.kind) {
        FloatingTextKind.crit => Colors.amberAccent,
        FloatingTextKind.reaction => const Color(0xFFB16EFF),
        FloatingTextKind.skill => const Color(0xFF3FD8FF),
        FloatingTextKind.normal => Colors.white,
      };
      TextPaint(
        style: TextStyle(
          color: color.withValues(alpha: opacity),
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          shadows: [Shadow(color: Colors.black, blurRadius: 4)],
        ),
      ).render(
        canvas,
        t.text,
        Vector2(t.x - widthGuess(t.text, fontSize) / 2, t.y - 20 - rise),
      );
    }
    canvas.restore();
  }

  double widthGuess(String text, double fontSize) =>
      fontSize * 0.58 * math.max(4, text.length * 0.75);
}

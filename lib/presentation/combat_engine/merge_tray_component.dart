import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Element;

import '../../domain/combat/combat_engine.dart';
import '../../domain/combat/combat_math.dart';
import '../../domain/combat/combat_models.dart';
import '../../domain/value_objects/element.dart';
import 'brimstone_combat_game.dart';

/// Bottom merge tray at y = size.y * 0.84 with 5 slots; orbs spawn here,
/// merge/swap by drag, and are flick-launched with a predictive dotted arc.
class MergeTrayComponent extends PositionComponent {
  final BrimstoneCombatGame combatGame;

  MergeTrayComponent(this.combatGame) {
    position = Vector2.zero();
    priority = 3;
  }

  double get slotW => CombatEngine.layoutWidth / 5;

  Color orbColor(Element e) => switch (e) {
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

    final trayY = CombatEngine.trayY;
    final w = CombatEngine.layoutWidth;
    final h = CombatEngine.layoutHeight;

    // Tray backing.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, trayY - 66, w, h - trayY + 66),
        const Radius.circular(18),
      ),
      Paint()..color = const Color(0xFF1A0E14).withValues(alpha: 0.92),
    );

    for (var i = 0; i < 5; i++) {
      final cx = slotW * (i + 0.5);
      final cy = (trayY + h) / 2;
      canvas.drawCircle(
        Offset(cx, cy),
        slotW * 0.38,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.06)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        Offset(cx, cy),
        slotW * 0.38,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = Colors.white24,
      );
      final orb = e.tray[i];
      if (orb != null && e.dragSlot != i) {
        _drawOrb(canvas, orb, cx, cy, slotW * 0.34);
      }
    }

    // Dragged orb + predictive dotted trajectory toward the boss plane.
    final slot = e.dragSlot;
    if (slot != null) {
      final orb = e.tray[slot];
      if (orb != null) {
        _drawOrb(canvas, orb, e.dragX, e.dragY, slotW * 0.34);
        if (e.dragY < CombatEngine.trayY) {
          final dash = Paint()
            ..color = orbColor(orb.element).withValues(alpha: 0.8)
            ..strokeWidth = 2.5;
          for (var i = 1; i <= 14; i++) {
            final z = i / 14;
            final px = CombatMath.lerp(e.dragX, e.dragX, z);
            final py =
                CombatMath.lerp(e.dragY, CombatEngine.bossScreenY, z) -
                math.sin(z * math.pi) * 90;
            if (i % 2 == 0) {
              canvas.drawCircle(Offset(px, py), 2.6, dash);
            }
          }
        }
      }
    }

    canvas.restore();
  }

  void _drawOrb(Canvas canvas, CombatOrb orb, double cx, double cy, double r) {
    final color = orbColor(orb.element);
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..color = color.withValues(alpha: 0.9)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(cx, cy),
      r * (0.4 + 0.22 * orb.level.index),
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white70,
    );
  }
}

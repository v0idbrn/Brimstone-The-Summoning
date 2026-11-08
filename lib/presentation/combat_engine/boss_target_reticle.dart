import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Element;

import '../../domain/value_objects/element.dart';
import 'brimstone_combat_game.dart';

/// Moving dimensional arcane target reticles over the boss:
/// segmented outer ring with rotating runes, crosshair targeting lines,
/// elemental color halo glow, and a bright pulsing Bullseye core at the center.
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
        null => const Color(0xFFFFD700),
      };

  @override
  void render(Canvas canvas) {
    final e = combatGame.engine;
    canvas.save();
    canvas.translate(combatGame.offsetX, combatGame.offsetY);
    canvas.scale(combatGame.viewScale);

    final color = auraColor;
    final time = e.time;

    for (final t in e.targets) {
      final x = t.xAt(time, e.effectiveAngularSpeed(t));
      final y = t.yAt(time, e.effectiveAngularSpeed(t));
      final outer = e.outerRadiusFor(t);
      final inner = e.innerRadiusFor(t);

      // ── HALO ELEMENTAL EXTERIOR (Glow ambiental) ────────────────
      final haloPaint = Paint()
        ..color = color.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawCircle(Offset(x, y), outer * 1.05, haloPaint);

      // ── ANILLO EXTERIOR SEGMENTADO (Portal Arcano) ──────────────
      const segments = 6;
      final arcAngle = (math.pi * 2 / segments) * 0.72;
      final gapAngle = (math.pi * 2 / segments) * 0.28;
      final rotOffset = time * 1.4;

      final segPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..color = color.withValues(alpha: 0.95);

      for (var i = 0; i < segments; i++) {
        final startA = rotOffset + i * (arcAngle + gapAngle);
        canvas.drawArc(
          Rect.fromCircle(center: Offset(x, y), radius: outer),
          startA,
          arcAngle,
          false,
          segPaint,
        );
      }

      // Nodos/marcas rúnicas en los vértices del portal
      for (var i = 0; i < 4; i++) {
        final a = -time * 0.9 + i * (math.pi / 2);
        final nx = x + math.cos(a) * (outer + 3);
        final ny = y + math.sin(a) * (outer + 3);
        canvas.drawCircle(
          Offset(nx, ny),
          2.6,
          Paint()..color = Colors.white,
        );
      }

      // ── LÍNEAS DE MIRA EN CRUZ (Crosshairs arcanos) ──────────────
      final crosshairPaint = Paint()
        ..color = color.withValues(alpha: 0.75)
        ..strokeWidth = 1.6;

      final crossGlow = Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..strokeWidth = 1.0;

      const crossGap = 7.0;
      final crossExt = outer + 6.0;

      // 4 brazos de la mira: izquierda, derecha, arriba, abajo
      final arms = [
        [Offset(x - crossExt, y), Offset(x - inner - crossGap, y)],
        [Offset(x + inner + crossGap, y), Offset(x + crossExt, y)],
        [Offset(x, y - crossExt), Offset(x, y - inner - crossGap)],
        [Offset(x, y + inner + crossGap), Offset(x, y + crossExt)],
      ];

      for (final arm in arms) {
        canvas.drawLine(arm[0], arm[1], crosshairPaint);
        canvas.drawLine(arm[0], arm[1], crossGlow);
      }

      // ── CÍRCULO INTERMEDIO DE CALIBRACIÓN ─────────────────────────
      canvas.drawCircle(
        Offset(x, y),
        inner * 1.55,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = color.withValues(alpha: 0.4),
      );

      // ── NÚCLEO BULLSEYE BRILLANTE PULSANTE ─────────────────────────
      final pulse = 0.85 + 0.15 * math.sin(time * 6.0);
      final pulseR = inner * pulse;

      // Relleno de energía del Bullseye
      final coreRadial = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white,
            color.withValues(alpha: 0.85),
            color.withValues(alpha: 0.15),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(x, y), radius: inner))
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), pulseR, coreRadial);

      // Anillo blanco nítido del Bullseye
      canvas.drawCircle(
        Offset(x, y),
        pulseR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..color = Colors.white,
      );

      // Punto central puro de impacto crítico
      canvas.drawCircle(
        Offset(x, y),
        3.0,
        Paint()..color = Colors.white,
      );

      // Efecto de congelación si el objetivo está petrificado/ralentizado
      if (t.frozen) {
        canvas.drawCircle(
          Offset(x, y),
          outer * 1.15,
          Paint()
            ..color = const Color(0xFF3FD8FF).withValues(alpha: 0.35)
            ..style = PaintingStyle.fill,
        );
      }
    }
    canvas.restore();
  }
}

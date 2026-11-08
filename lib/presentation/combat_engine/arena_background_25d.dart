import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Element;

import '../../core/performance/performance_settings.dart';
import '../../domain/combat/combat_engine.dart';
import '../../domain/value_objects/element.dart';
import 'brimstone_combat_game.dart';

/// Dark-fantasy 2.5D arena: horizon, obsidian floor, gothic pillars,
/// animated abyssal fog and a rotating dimensional portal behind the boss.
class ArenaBackground25D extends PositionComponent {
  final BrimstoneCombatGame combatGame;

  ArenaBackground25D(this.combatGame) {
    position = Vector2.zero();
    priority = -10;
  }

  // Paint pre-alojados: el fondo se repinta cada frame y no debe instanciar
  // objetos nuevos (0 allocations por frame en el camino caliente).
  final Paint _skyPaint = Paint();
  final Paint _floorBasePaint = Paint()..color = const Color(0xFF14090D);
  final Paint _vanishPaint = Paint()
    ..color = const Color(0xFF2A1116).withValues(alpha: 0.65)
    ..strokeWidth = 2
    ..style = PaintingStyle.stroke;
  final Paint _gridPaint = Paint()
    ..color = const Color(0xFF3A1A1F)
    ..strokeWidth = 1.2;
  final Paint _ringPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 5;
  final Paint _glowPaint = Paint()..style = PaintingStyle.fill;
  final Paint _orbitPaint = Paint();
  final Paint _fogPaint = Paint()
    ..color = const Color(0xFF8B5CF6).withValues(alpha: 0.06);
  final Paint _pillarBodyPaint = Paint();
  final Paint _pillarTrimPaint = Paint();

  Element get bossElement => combatGame.engine.boss.element;

  Color get portalColor => switch (bossElement) {
        Element.igneous => const Color(0xFFFF5A26),
        Element.abyssal => const Color(0xFF3FD8FF),
        Element.telluric => const Color(0xFFB0703B),
        Element.empty => const Color(0xFFB16EFF),
      };

  @override
  void render(Canvas canvas) {
    final s = combatGame.viewScale;
    final w = CombatEngine.layoutWidth;
    final h = CombatEngine.layoutHeight;
    final horizonY = h * 0.28;

    canvas.save();
    canvas.translate(combatGame.offsetX, combatGame.offsetY);
    canvas.scale(s);

    // Sky gradient
    final sky = Rect.fromLTWH(0, 0, w, horizonY);
    _skyPaint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF1A0E14),
        portalColor.withValues(alpha: 0.18),
        const Color(0xFF2B1016),
      ],
    ).createShader(sky);
    canvas.drawRect(sky, _skyPaint);

    // Obsidian floor with vanishing lines converging to the horizon center.
    canvas.drawRect(
      Rect.fromLTWH(0, horizonY, w, h - horizonY),
      _floorBasePaint,
    );
    final vanish = Offset(w * 0.5, horizonY);
    for (var i = -7; i <= 7; i++) {
      final baseX = w * 0.5 + i * (w / 8);
      canvas.drawLine(vanish, Offset(baseX, h), _vanishPaint);
    }
    for (var i = 1; i <= 6; i++) {
      final t = i / 6;
      final y = CombatMathLerp.lerp(horizonY, h, t * t);
      canvas.drawLine(Offset(0, y), Offset(w, y), _gridPaint);
    }

    // Depth-scaled gothic side pillars.
    for (var i = 0; i < 3; i++) {
      final depth = (i + 1) / 4;
      final py = CombatMathLerp.lerp(horizonY, h * 0.9, depth);
      final scale = 1.0 - depth * 0.45;
      for (final side in <int>[0, 1]) {
        final cx = side == 0 ? w * 0.06 : w * 0.94;
        final pw = 46 * scale;
        final ph = (h - horizonY) * 0.75 * scale;
        final top = py - ph * 0.35;
        _drawPillar(canvas, cx - pw / 2, top, pw, ph, depth);
      }
    }

    // Rotating dimensional portal behind the boss.
    final portalCx = CombatEngine.bossScreenX;
    final portalCy = CombatEngine.bossScreenY - 60;
    final portalR = 110.0;
    _ringPaint.color = portalColor.withValues(alpha: 0.75);
    _glowPaint.color = portalColor.withValues(alpha: 0.14);
    // En gama baja se omite el halo (fill costoso) y se reducen los satélites.
    if (PerformanceSettings.enableSecondaryGlow) {
      canvas.drawCircle(Offset(portalCx, portalCy), portalR, _glowPaint);
    }
    canvas.drawCircle(Offset(portalCx, portalCy), portalR, _ringPaint);
    _orbitPaint.color = portalColor;
    final orbitCount = PerformanceSettings.lowSpecMode ? 5 : 10;
    for (var i = 0; i < orbitCount; i++) {
      final a = time * 1.2 + i * math.pi * 2 / orbitCount;
      final x = portalCx + math.cos(a) * portalR;
      final y = portalCy + math.sin(a) * portalR;
      canvas.drawCircle(Offset(x, y), 5, _orbitPaint);
    }

    // Animated abyssal fog drifting by sine waves (omitida en gama baja).
    final fogLayers = PerformanceSettings.enableDecorativeBackground ? 3 : 0;
    for (var layer = 0; layer < fogLayers; layer++) {
      final baseY = horizonY + 40 + layer * 90;
      final path = Path()..moveTo(0, baseY);
      for (var x = 0; x <= w; x += 20) {
        final y = baseY +
            math.sin(x / 90 + time * (0.6 + layer * 0.25)) * 14 +
            layer * 6;
        path.lineTo(x.toDouble(), y);
      }
      path.lineTo(w, h);
      path.lineTo(0, h);
      path.close();
      canvas.drawPath(path, _fogPaint);
    }

    canvas.restore();
  }

  void _drawPillar(
    Canvas c,
    double x,
    double y,
    double w,
    double h,
    double depth,
  ) {
    final opacity = 0.35 + 0.4 * (1 - depth);
    _pillarBodyPaint.color = Color.fromRGBO(26, 14, 20, opacity);
    _pillarTrimPaint.color = Color.fromRGBO(58, 26, 31, opacity);
    c.drawRect(Rect.fromLTWH(x, y, w, h), _pillarBodyPaint);
    c.drawRect(
      Rect.fromLTWH(x - w * 0.15, y, w * 1.3, 18),
      _pillarTrimPaint,
    );
    c.drawRect(
      Rect.fromLTWH(x - w * 0.15, y + h, w * 1.3, 16),
      _pillarTrimPaint,
    );
  }

  double get time => combatGame.engine.time;
}

/// Trigonometric lerp helpers shared by combat painters.
class CombatMathLerp {
  static double lerp(double a, double b, double t) => a + (b - a) * t;
}

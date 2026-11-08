import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Element;

import '../../domain/combat/combat_engine.dart';
import '../../domain/value_objects/element.dart';
import 'brimstone_combat_game.dart';

/// Procedurally-painted boss: breathing, hit flash, attack timer bar and the
/// rune ring that shows the active elemental aura with its 5s countdown.
/// Renders enrage phase 2 (palette shift, +15% scale, boss-specific aura).
class BossActorComponent extends PositionComponent {
  final BrimstoneCombatGame combatGame;
  double _flash = 0;
  double _lastHp = -1;
  double _enragePulse = 0;

  BossActorComponent(this.combatGame) {
    position = Vector2.zero();
    priority = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    final hp = combatGame.engine.bossHp;
    if (_lastHp >= 0 && hp < _lastHp) _flash = 0.12;
    _lastHp = hp;
    _flash = math.max(0, _flash - dt);
    if (combatGame.engine.enraged) {
      _enragePulse += dt * 4;
    } else {
      _enragePulse = 0;
    }
  }

  Color get elementColor => switch (combatGame.engine.boss.element) {
        Element.igneous => const Color(0xFFFF5A26),
        Element.abyssal => const Color(0xFF3FD8FF),
        Element.telluric => const Color(0xFFB0703B),
        Element.empty => const Color(0xFFB16EFF),
      };

  /// Whether the boss is in enrage phase 2 (<45% HP).
  bool get _enraged => combatGame.engine.enraged;

  /// Enrage color shift: incandescent glow over the base element color.
  Color get _enrageColor {
    final base = elementColor;
    final pulse = (math.sin(_enragePulse) + 1) / 2;
    return Color.lerp(base, const Color(0xFFFF5A26), 0.5 + 0.5 * pulse)!;
  }

  @override
  void render(Canvas canvas) {
    final e = combatGame.engine;
    final s = combatGame.viewScale;
    canvas.save();
    canvas.translate(combatGame.offsetX, combatGame.offsetY);
    canvas.scale(s);

    final cx = CombatEngine.bossScreenX;
    final cy = CombatEngine.bossScreenY;
    final breathe = 1 + 0.02 * math.sin(e.time * 2 * math.pi / 3);

    // Enrage: +15% scale and incandescent palette shift.
    final enrageScale = _enraged ? 1.15 : 1.0;
    final bodyColor = _enraged ? _enrageColor : elementColor;

    final paint = Paint()..style = PaintingStyle.fill;
    switch (e.boss.id) {
      case 'pyroth':
        _paintPyroth(canvas, cx, cy, breathe * enrageScale, bodyColor, paint);
      case 'vaelor':
        _paintVaelor(canvas, cx, cy, breathe * enrageScale, bodyColor, paint);
      default:
        _paintAzathor(canvas, cx, cy, breathe * enrageScale, bodyColor, paint);
    }

    if (_flash > 0) {
      final flashPaint = Paint()
        ..color = Colors.white.withValues(
          alpha: (0.55 * _flash / 0.12).clamp(0.0, 1.0),
        );
      _paintSilhouette(canvas, cx, cy, breathe * enrageScale, flashPaint);
    }

    // Attack timer bar.
    final frac = (1 - (e.bossAttackTimer / e.boss.attackInterval)).clamp(
      0.0,
      1.0,
    );
    final barY = cy - 118;
    canvas.drawRect(
      Rect.fromLTWH(cx - 60, barY, 120, 7),
      Paint()..color = const Color(0xFF3A1A1F),
    );
    canvas.drawRect(
      Rect.fromLTWH(cx - 60, barY, 120 * frac, 7),
      Paint()..color = _enraged ? Colors.orangeAccent : Colors.redAccent,
    );

    // Aura rune ring + countdown.
    if (e.aura != null) {
      final a = cx;
      final by = barY - 34;
      canvas.drawCircle(
        Offset(a, by),
        26,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = elementColor,
      );
      canvas.drawArc(
        Rect.fromCircle(center: Offset(a, by), radius: 26),
        -math.pi / 2,
        2 * math.pi * (e.auraRemaining / 5.0),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..color = Colors.white,
      );
      TextPaint(style: TextStyle(color: elementColor, fontSize: 14)).render(
        canvas,
        '${e.auraRemaining.toStringAsFixed(1)}s',
        Vector2(a - 16, by - 8),
      );
    }

    canvas.restore();
  }

  void _paintBody(
    Canvas canvas,
    double cx,
    double cy,
    double breathe,
    Color color,
    Paint paint,
  ) {
    final r = 64 * breathe;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: r * 2, height: r * 2.5),
      paint..color = color,
    );
  }

  void _paintSilhouette(
    Canvas canvas,
    double cx,
    double cy,
    double breathe,
    Paint p,
  ) {
    final r = 64 * breathe;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: r * 2, height: r * 2.5),
      p,
    );
  }

  void _paintPyroth(
    Canvas canvas,
    double cx,
    double cy,
    double breathe,
    Color color,
    Paint paint,
  ) {
    _paintBody(canvas, cx, cy, breathe, color, paint);
    // Molten cracks.
    final crack = Paint()
      ..color = const Color(0xFFFF5A26)
      ..strokeWidth = 3;
    for (var i = 0; i < 5; i++) {
      final a = i * 1.25;
      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx + math.cos(a) * 52, cy + math.sin(a) * 62),
        crack,
      );
    }
    canvas.drawCircle(
      Offset(cx - 18, cy - 20),
      7,
      Paint()..color = Colors.amber,
    );
    canvas.drawCircle(
      Offset(cx + 18, cy - 20),
      7,
      Paint()..color = Colors.amber,
    );
    if (_enraged) {
      // Incandescent corona during enrage.
      final corona = Paint()
        ..color = const Color(0xFFFF5A26).withValues(alpha: 0.6)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, cy),
          width: 130 * breathe,
          height: 150 * breathe,
        ),
        corona,
      );
    }
  }

  void _paintVaelor(
    Canvas canvas,
    double cx,
    double cy,
    double breathe,
    Color color,
    Paint paint,
  ) {
    _paintBody(canvas, cx, cy, breathe, color, paint);
    final spike = Paint()
      ..color = const Color(0xFF3FD8FF)
      ..strokeWidth = 4;
    for (var i = 0; i < 7; i++) {
      final a = -math.pi * 0.9 + i * math.pi * 0.3;
      canvas.drawLine(
        Offset(cx + math.cos(a) * 48, cy + math.sin(a) * 52),
        Offset(cx + math.cos(a) * 84, cy + math.sin(a) * 88),
        spike,
      );
    }
    canvas.drawCircle(
      Offset(cx - 16, cy - 18),
      6,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(cx + 16, cy - 18),
      6,
      Paint()..color = Colors.white,
    );
    if (_enraged) {
      // Ice shield glow on enraged Vaelor.
      final shield = Paint()
        ..color = const Color(0xFF3FD8FF).withValues(alpha: 0.35)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, cy),
          width: 110 * breathe,
          height: 130 * breathe,
        ),
        shield,
      );
    }
  }

  void _paintAzathor(
    Canvas canvas,
    double cx,
    double cy,
    double breathe,
    Color color,
    Paint paint,
  ) {
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(cx, cy),
        width: 96 * breathe,
        height: 230 * breathe,
      ),
      paint..color = color,
    );
    final runes = Paint()
      ..color = const Color(0xFFB16EFF)
      ..strokeWidth = 3;
    for (var i = 0; i < 4; i++) {
      final y = cy - 80 + i * 46;
      canvas.drawLine(Offset(cx - 26, y), Offset(cx + 26, y), runes);
    }
    canvas.drawCircle(
      Offset(cx, cy - 40),
      12,
      Paint()..color = const Color(0xFFE5D4FF),
    );
    canvas.drawCircle(
      Offset(cx, cy - 40),
      24,
      Paint()..color = const Color(0xFFB16EFF).withValues(alpha: 0.35),
    );
    if (_enraged) {
      // Void corona: rotating seal pulses.
      final seal = Paint()
        ..color = const Color(0xFFB16EFF).withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      final r = 40 + 10 * math.sin(_enragePulse * 2);
      canvas.drawCircle(Offset(cx, cy), r, seal);
      canvas.drawCircle(Offset(cx, cy), r * 0.6, seal);
    }
  }
}

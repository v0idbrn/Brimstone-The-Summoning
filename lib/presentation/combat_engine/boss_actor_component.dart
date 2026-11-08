import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Element;

import '../../domain/combat/combat_engine.dart';
import '../../domain/value_objects/element.dart';
import 'brimstone_combat_game.dart';

/// Procedurally-painted boss: breathing, hit flash, attack timer bar and the
/// rune ring that shows the active elemental aura with its 5s countdown.
class BossActorComponent extends PositionComponent {
  final BrimstoneCombatGame combatGame;
  double _flash = 0;
  double _lastHp = -1;

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
  }

  Color get elementColor => switch (combatGame.engine.boss.element) {
    Element.igneous => const Color(0xFFFF5A26),
    Element.abyssal => const Color(0xFF3FD8FF),
    Element.telluric => const Color(0xFFB0703B),
    Element.empty => const Color(0xFFB16EFF),
  };

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

    final paint = Paint()..style = PaintingStyle.fill;
    switch (e.boss.id) {
      case 'pyroth':
        _paintPyroth(canvas, cx, cy, breathe, paint);
      case 'vaelor':
        _paintVaelor(canvas, cx, cy, breathe, paint);
      default:
        _paintAzathor(canvas, cx, cy, breathe, paint);
    }

    if (_flash > 0) {
      final flashPaint = Paint()
        ..color = Colors.white.withValues(
          alpha: (0.55 * _flash / 0.12).clamp(0.0, 1.0),
        );
      _paintSilhouette(canvas, cx, cy, breathe, flashPaint);
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
      Paint()..color = Colors.redAccent,
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
  ) {
    final r = 64 * breathe;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: r * 2, height: r * 2.5),
      Paint()..color = color,
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
    Paint paint,
  ) {
    _paintBody(canvas, cx, cy, breathe, const Color(0xFF8C1D0F));
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
  }

  void _paintVaelor(
    Canvas canvas,
    double cx,
    double cy,
    double breathe,
    Paint paint,
  ) {
    _paintBody(canvas, cx, cy, breathe, const Color(0xFF0E3A55));
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
  }

  void _paintAzathor(
    Canvas canvas,
    double cx,
    double cy,
    double breathe,
    Paint paint,
  ) {
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(cx, cy),
        width: 96 * breathe,
        height: 230 * breathe,
      ),
      Paint()..color = const Color(0xFF1B0A22),
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
  }
}

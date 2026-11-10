import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Element;

import '../../domain/value_objects/element.dart';
import 'arena_background_25d.dart';
import 'brimstone_combat_game.dart';

/// Player orb projectile travelling z 0 (tray) → 1 (boss plane) in 0.32-0.55 s
/// with `scale = 1 - 0.62z`, a 115 px vertical arc and the flick's target_x.
///
/// It is rendered as a living comet: a tapered conical tail with an opacity
/// gradient behind the sphere, detached sparks shedding along the path, a
/// liquid-glass core and — at level 3 — a burning solar corona.
class OrbProjectile25D extends PositionComponent {
  OrbProjectile25D(this.combatGame) {
    position = Vector2.zero();
    priority = 2;
  }

  final BrimstoneCombatGame combatGame;

  final Paint _fill = Paint()..style = PaintingStyle.fill;
  final Paint _stroke = Paint()..style = PaintingStyle.stroke;
  final Paint _glow = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

  Color colorFor(Element e) => switch (e) {
        Element.igneous => const Color(0xFFFF5A26),
        Element.abyssal => const Color(0xFF3FD8FF),
        Element.telluric => const Color(0xFFB0703B),
        Element.empty => const Color(0xFFB16EFF),
      };

  Color accentFor(Element e) => switch (e) {
        Element.igneous => const Color(0xFFFFD980),
        Element.abyssal => const Color(0xFFB8F0FF),
        Element.telluric => const Color(0xFFF0D0A0),
        Element.empty => const Color(0xFFE5D4FF),
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
      final color = colorFor(p.element);
      final accent = accentFor(p.element);
      final level = p.level.index + 1;

      final x = CombatMathLerp.lerp(p.startX, p.targetX, z);
      final y = CombatMathLerp.lerp(p.startY, p.targetY, z) -
          math.sin(z * math.pi) * 115.0;
      final r = 22.0 * scale;

      // ── Conical comet tail (widest at the old position) ─────────────
      final tailSpan = 0.26; // fraction of the flight kept as tail
      final zBack = math.max(0.0, z - tailSpan);
      final tx = CombatMathLerp.lerp(p.startX, p.targetX, zBack);
      final ty = CombatMathLerp.lerp(p.startY, p.targetY, zBack) -
          math.sin(zBack * math.pi) * 115.0;
      final tailR = 22.0 * (1.0 - 0.62 * zBack);

      final dir = Offset(x - tx, y - ty);
      final len = dir.distance;
      if (len > 0.5) {
        final n = Offset(-dir.dy / len, dir.dx / len);
        final tail = Path()
          ..moveTo(x + n.dx * r * 0.85, y + n.dy * r * 0.85)
          ..quadraticBezierTo(
            (x + tx) / 2 + n.dx * tailR * 0.55,
            (y + ty) / 2 + n.dy * tailR * 0.55,
            tx,
            ty,
          )
          ..quadraticBezierTo(
            (x + tx) / 2 - n.dx * tailR * 0.55,
            (y + ty) / 2 - n.dy * tailR * 0.55,
            x - n.dx * r * 0.85,
            y - n.dy * r * 0.85,
          )
          ..close();

        _fill.shader = LinearGradient(
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
          colors: [
            accent.withValues(alpha: 0.85),
            color.withValues(alpha: 0.55),
            color.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(
          Rect.fromPoints(Offset(x, y), Offset(tx, ty)).inflate(tailR + 4),
        );
        canvas.drawPath(tail, _fill);
        _fill.shader = null;
      }

      // ── Shed sparks with pseudo-gravity ─────────────────────────────
      for (var i = 0; i < 4 + level; i++) {
        final t = (z - 0.05 * (i + 1)).clamp(0.0, 1.0);
        final sx = CombatMathLerp.lerp(p.startX, p.targetX, t);
        final sy = CombatMathLerp.lerp(p.startY, p.targetY, t) -
            math.sin(t * math.pi) * 115.0;
        final spread = 6.0 + i * 2.2;
        final drift = math.sin(e.time * 9 + i) * spread;
        _fill.color = Color.lerp(color, Colors.white, 0.5)!
            .withValues(alpha: (1 - i / (5 + level)) * 0.7);
        canvas.drawCircle(
          Offset(sx + drift * 0.5, sy + drift.abs() * 0.35),
          1.2 + (i % 3) * 0.6,
          _fill,
        );
      }

      // ── Outer elemental glow ────────────────────────────────────────
      _glow.color = color.withValues(alpha: 0.55);
      canvas.drawCircle(Offset(x, y), r * 1.35, _glow);

      // ── Liquid-glass sphere core ────────────────────────────────────
      _fill.shader = RadialGradient(
        center: const Alignment(-0.35, -0.4),
        radius: 0.95,
        colors: [
          Colors.white,
          accent,
          color,
          Color.lerp(color, Colors.black, 0.7)!,
        ],
        stops: const [0.0, 0.25, 0.62, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(x, y), radius: r));
      canvas.drawCircle(Offset(x, y), r, _fill);
      _fill.shader = null;

      // ── Specular glass highlight ────────────────────────────────────
      _fill.color = Colors.white.withValues(alpha: 0.85);
      canvas.drawCircle(
        Offset(x - r * 0.28, y - r * 0.3),
        r * 0.22,
        _fill,
      );

      // ── Level decorations ──────────────────────────────────────────
      if (level >= 2) {
        _stroke
          ..strokeWidth = 1.6
          ..color = Colors.white.withValues(alpha: 0.55);
        for (var i = 0; i < 2; i++) {
          final a = e.time * 6 + i * math.pi;
          canvas.drawArc(
            Rect.fromCircle(center: Offset(x, y), radius: r * 1.28),
            a,
            math.pi * 0.7,
            false,
            _stroke,
          );
        }
      }
      if (level >= 3) {
        // Solar corona spikes.
        _fill.color = accent.withValues(alpha: 0.75);
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4 + e.time * 2.4;
          final r1 = r * 1.05;
          final r2 = r * (1.45 + 0.12 * math.sin(e.time * 7 + i));
          final spike = Path()
            ..moveTo(x + math.cos(a - 0.16) * r1, y + math.sin(a - 0.16) * r1)
            ..lineTo(x + math.cos(a) * r2, y + math.sin(a) * r2)
            ..lineTo(x + math.cos(a + 0.16) * r1, y + math.sin(a + 0.16) * r1)
            ..close();
          canvas.drawPath(spike, _fill);
        }
      }
    }
    canvas.restore();
  }
}

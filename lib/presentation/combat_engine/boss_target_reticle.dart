import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Element;

import '../../core/performance/performance_settings.dart';
import '../../domain/value_objects/element.dart';
import 'brimstone_combat_game.dart';

/// HellFire-style precision target seals.
///
/// Each moving target is rendered as an arcane aiming seal:
///   * toothed outer ring rotating clockwise,
///   * etched second ring counter-rotating with cardinal rune nodes,
///   * arcane crosshair arms with a calibration circle,
///   * incandescent bullseye core that pulses and blooms expanding shockwave
///     rings while the player drags an orb upward,
///   * frost crust when the target is frozen/petrified.
class BossTargetReticle extends PositionComponent {
  BossTargetReticle(this.combatGame) {
    position = Vector2.zero();
    priority = 1;
  }

  final BrimstoneCombatGame combatGame;

  final Paint _stroke = Paint()..style = PaintingStyle.stroke;
  final Paint _fill = Paint()..style = PaintingStyle.fill;
  final Paint _glow = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

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
    final dragging = combatGame.draggingOrb;

    for (final t in e.targets) {
      final x = t.xAt(time, e.effectiveAngularSpeed(t));
      final y = t.yAt(time, e.effectiveAngularSpeed(t));
      final outer = e.outerRadiusFor(t);
      final inner = e.innerRadiusFor(t);
      final center = Offset(x, y);

      // ── Elemental halo ──────────────────────────────────────────────
      _glow.color = color.withValues(alpha: dragging ? 0.34 : 0.22);
      canvas.drawCircle(center, outer * 1.08, _glow);

      // ── Toothed outer ring (clockwise) ──────────────────────────────
      _stroke
        ..strokeWidth = 3.4
        ..color = color.withValues(alpha: 0.95);
      const teeth = 18;
      final toothArc = (math.pi * 2 / teeth) * 0.58;
      for (var i = 0; i < teeth; i++) {
        final start = time * 1.35 + i * (math.pi * 2 / teeth);
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: outer),
          start,
          toothArc,
          false,
          _stroke,
        );
      }

      // ── Etched counter-rotating ring ────────────────────────────────
      _stroke
        ..strokeWidth = 1.2
        ..color = color.withValues(alpha: 0.5);
      canvas.drawCircle(center, outer * 0.84, _stroke);

      for (var i = 0; i < 4; i++) {
        final a = -time * 0.95 + i * (math.pi / 2);
        final nx = x + math.cos(a) * (outer * 0.84);
        final ny = y + math.sin(a) * (outer * 0.84);
        canvas.drawCircle(Offset(nx, ny), 2.6, _fill..color = Colors.white);
        // Cardinal rune tick pointing inward.
        _stroke
          ..strokeWidth = 1.4
          ..color = color.withValues(alpha: 0.7);
        canvas.drawLine(
          Offset(nx, ny),
          Offset(
            x + math.cos(a) * (outer * 0.70),
            y + math.sin(a) * (outer * 0.70),
          ),
          _stroke,
        );
      }

      // ── Arcane crosshair arms ───────────────────────────────────────
      const gap = 7.0;
      final ext = outer + 7.0;
      _stroke
        ..strokeWidth = 1.6
        ..color = color.withValues(alpha: 0.8);
      _fill.color = Colors.white.withValues(alpha: 0.95);

      void arm(Offset a, Offset b) {
        canvas.drawLine(a, b, _stroke);
      }

      arm(Offset(x - ext, y), Offset(x - inner - gap, y));
      arm(Offset(x + inner + gap, y), Offset(x + ext, y));
      arm(Offset(x, y - ext), Offset(x, y - inner - gap));
      arm(Offset(x, y + inner + gap), Offset(x, y + ext));

      // Calibration circle.
      _stroke
        ..strokeWidth = 1.0
        ..color = color.withValues(alpha: 0.4);
      canvas.drawCircle(center, inner * 1.55, _stroke);

      // ── Drag bloom: expanding lock-on shockwaves ───────────────────
      if (dragging && PerformanceSettings.enableSecondaryGlow) {
        for (var wave = 0; wave < 3; wave++) {
          final phase = (time * 0.9 + wave / 3.0) % 1.0;
          _stroke
            ..strokeWidth = 2.0 * (1 - phase) + 0.4
            ..color = color.withValues(alpha: (1 - phase) * 0.55);
          canvas.drawCircle(center, inner * (1.0 + phase * 1.9), _stroke);
        }
      }

      // ── Incandescent bullseye core ─────────────────────────────────
      final pulse = 0.85 + 0.15 * math.sin(time * 6.0);
      final coreR = inner * pulse;

      _fill.shader = RadialGradient(
        colors: [
          Colors.white,
          Color.lerp(Colors.white, color, 0.35)!,
          color.withValues(alpha: 0.85),
          color.withValues(alpha: 0.05),
        ],
        stops: const [0.0, 0.32, 0.66, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: inner));
      canvas.drawCircle(center, coreR, _fill);
      _fill.shader = null;

      _stroke
        ..strokeWidth = 2.0
        ..color = Colors.white;
      canvas.drawCircle(center, coreR, _stroke);

      _fill.color = Colors.white;
      canvas.drawCircle(center, 3.0, _fill);

      // Inner cross glint.
      _stroke
        ..strokeWidth = 1.0
        ..color = Colors.white.withValues(alpha: 0.65);
      canvas.drawLine(
        Offset(x - coreR * 0.55, y),
        Offset(x + coreR * 0.55, y),
        _stroke,
      );
      canvas.drawLine(
        Offset(x, y - coreR * 0.55),
        Offset(x, y + coreR * 0.55),
        _stroke,
      );

      // ── Frozen / petrified crust ───────────────────────────────────
      if (t.frozen) {
        _fill
          ..color = const Color(0xFF3FD8FF).withValues(alpha: 0.32)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawCircle(center, outer * 1.12, _fill);
        _fill.maskFilter = null;
        _stroke
          ..strokeWidth = 2.0
          ..color = const Color(0xFFB8F0FF).withValues(alpha: 0.8);
        for (var i = 0; i < 6; i++) {
          final a = i * math.pi / 3 + time * 0.2;
          canvas.drawLine(
            Offset(x + math.cos(a) * inner, y + math.sin(a) * inner),
            Offset(x + math.cos(a) * outer, y + math.sin(a) * outer),
            _stroke,
          );
        }
      }
    }
    canvas.restore();
  }
}

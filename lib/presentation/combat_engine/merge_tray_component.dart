import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Element;

import '../../../core/audio/procedural_sfx_engine.dart';
import '../../domain/combat/combat_engine.dart';
import '../../domain/combat/combat_math.dart';
import '../../domain/combat/combat_models.dart';
import '../../domain/value_objects/element.dart';
import '../../domain/value_objects/orb_level.dart';
import 'brimstone_combat_game.dart';

/// Bottom merge tray at y = size.y * 0.84 with 5 slots; orbs spawn here,
/// merge/swap by drag, and are flick-launched with a predictive dotted arc
/// plus a luminous parabola showing the z = 1.0 impact point.
/// Orbs are rendered with rich 3D sphere gradient lighting, specular highlight,
/// glowing rims, elemental rune icons, and clear "Nv.1", "Nv.2", "Nv.3" badges.
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

  Color orbAccent(Element e) => switch (e) {
        Element.igneous => const Color(0xFFFFD980),
        Element.abyssal => const Color(0xFF80E8FF),
        Element.telluric => const Color(0xFFF0D0A0),
        Element.empty => const Color(0xFFE5D4FF),
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

    // Tray backing metálico oscuro.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, trayY - 66, w, h - trayY + 66),
        const Radius.circular(18),
      ),
      Paint()..color = const Color(0xFF14080D).withValues(alpha: 0.94),
    );

    for (var i = 0; i < 5; i++) {
      final cx = slotW * (i + 0.5);
      final cy = (trayY + h) / 2;
      canvas.drawCircle(
        Offset(cx, cy),
        slotW * 0.38,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.05)
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
        _drawOrb3D(canvas, orb, cx, cy, slotW * 0.34);
        // Pyroth enrage burn marker.
        if (e.isSlotBurned(i)) {
          canvas.drawCircle(
            Offset(cx, cy),
            slotW * 0.46,
            Paint()
              ..color = Colors.orangeAccent.withValues(alpha: 0.55)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5,
          );
        }
      }
    }

    // Dragged orb + luminous parabola + predictive reticle toward the boss plane.
    final slot = e.dragSlot;
    if (slot != null) {
      final orb = e.tray[slot];
      if (orb != null) {
        _drawOrb3D(canvas, orb, e.dragX, e.dragY, slotW * 0.34);
        if (e.dragY < CombatEngine.trayY) {
          final dash = Paint()
            ..color = orbColor(orb.element).withValues(alpha: 0.8)
            ..strokeWidth = 2.5;
          final arcPaint = Paint()
            ..color = orbColor(orb.element).withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6;
          final reticlePaint = Paint()
            ..color = orbColor(orb.element).withValues(alpha: 0.9)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2;

          for (var i = 1; i <= 14; i++) {
            final z = i / 14;
            final px = CombatMath.lerp(e.dragX, e.dragX, z);
            final py = CombatMath.lerp(e.dragY, CombatEngine.bossScreenY, z) -
                math.sin(z * math.pi) * 90;
            if (i % 2 == 0) {
              canvas.drawCircle(Offset(px, py), 2.6, dash);
            }
            final pxPrev = CombatMath.lerp(e.dragX, e.dragX, (i - 1) / 14);
            final pyPrev = CombatMath.lerp(
                  e.dragY,
                  CombatEngine.bossScreenY,
                  (i - 1) / 14,
                ) -
                math.sin(((i - 1) / 14) * math.pi) * 90;
            canvas.drawLine(Offset(pxPrev, pyPrev), Offset(px, py), arcPaint);
          }

          final impactX = e.dragX;
          final impactY = CombatEngine.bossScreenY - 90;
          canvas.drawCircle(
            Offset(impactX, impactY),
            7,
            reticlePaint..style = PaintingStyle.stroke,
          );
          canvas.drawLine(
            Offset(impactX - 9, impactY),
            Offset(impactX + 9, impactY),
            reticlePaint,
          );
          canvas.drawLine(
            Offset(impactX, impactY - 9),
            Offset(impactX, impactY + 9),
            reticlePaint,
          );
          canvas.drawCircle(
            Offset(impactX, impactY),
            2.5,
            reticlePaint..style = PaintingStyle.fill,
          );
        }
      }
    }

    canvas.restore();
  }

  void playMergeSound(int newLevel) =>
      ProceduralSfxEngine.playOrbMerge(newLevel);

  void playFlickSound() => ProceduralSfxEngine.playOrbFlick();

  void playCounterFlickSound() => ProceduralSfxEngine.playCounterFlickDestroy();

  void playSpawnSound() => ProceduralSfxEngine.playOrbSpawn();

  /// Renderizado de esfera 3D:
  /// - Gradiente radial volumétrico (luz cenital izquierda a sombra oscura)
  /// - Punto de luz especular blanco arriba a la izquierda
  /// - Borde brillante translúcido del color del elemento
  /// - Ícono elemental procedural en el centro
  /// - Etiqueta clara de nivel: "Nv.1", "Nv.2", "Nv.3"
  void _drawOrb3D(
    Canvas canvas,
    CombatOrb orb,
    double cx,
    double cy,
    double r,
  ) {
    final base = orbColor(orb.element);
    final accent = orbAccent(orb.element);

    // 1. Halo exterior sutil
    final glow = Paint()
      ..color = base.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset(cx, cy), r * 1.08, glow);

    // 2. Esfera 3D con RadialGradient desplazado arriba a la izquierda
    final spherePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.38),
        radius: 0.95,
        colors: [
          Colors.white.withValues(alpha: 0.95),
          accent,
          base,
          Color.lerp(base, Colors.black, 0.75)!,
        ],
        stops: const [0.0, 0.22, 0.62, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), r, spherePaint);

    // 3. Brillo de borde interno (rim lighting)
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = accent.withValues(alpha: 0.85);
    canvas.drawCircle(Offset(cx, cy), r, rimPaint);

    // 4. Punto de luz especular arriba a la izquierda
    final specCenter = Offset(cx - r * 0.32, cy - r * 0.35);
    final specPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white,
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: specCenter, radius: r * 0.28))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(specCenter, r * 0.28, specPaint);

    // 5. Ícono elemental procedural en el centro
    _drawElementIcon(canvas, orb.element, cx, cy - 2, r * 0.42);

    // 6. Placa de nivel: Nv.1 / Nv.2 / Nv.3
    _drawLevelBadge(canvas, orb.level, cx, cy + r * 0.46, r);
  }

  void _drawElementIcon(
    Canvas canvas,
    Element element,
    double cx,
    double cy,
    double size,
  ) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    switch (element) {
      case Element.igneous:
        // Llama ígnea estilizada
        final path = Path()
          ..moveTo(cx, cy - size)
          ..cubicTo(
            cx + size * 0.7,
            cy - size * 0.3,
            cx + size * 0.8,
            cy + size * 0.6,
            cx,
            cy + size * 0.8,
          )
          ..cubicTo(
            cx - size * 0.8,
            cy + size * 0.6,
            cx - size * 0.7,
            cy - size * 0.3,
            cx,
            cy - size,
          )
          ..close();
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xFFFFD980).withValues(alpha: 0.5)
            ..style = PaintingStyle.fill,
        );
        canvas.drawPath(path, paint);

      case Element.abyssal:
        // Cristal de hielo / copo abisal
        for (var i = 0; i < 3; i++) {
          final a = i * math.pi / 3;
          canvas.drawLine(
            Offset(cx + math.cos(a) * size, cy + math.sin(a) * size),
            Offset(cx - math.cos(a) * size, cy - math.sin(a) * size),
            paint,
          );
        }
        canvas.drawCircle(
          Offset(cx, cy),
          2.5,
          Paint()..color = Colors.white,
        );

      case Element.telluric:
        // Runa de montaña / rombo telúrico
        final path = Path()
          ..moveTo(cx, cy - size)
          ..lineTo(cx + size * 0.85, cy)
          ..lineTo(cx, cy + size * 0.85)
          ..lineTo(cx - size * 0.85, cy)
          ..close();
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xFFF0D0A0).withValues(alpha: 0.4)
            ..style = PaintingStyle.fill,
        );
        canvas.drawPath(path, paint);

      case Element.empty:
        // Vórtice del Vacío (círculo místico y cruz)
        canvas.drawCircle(Offset(cx, cy), size * 0.75, paint);
        canvas.drawCircle(
          Offset(cx, cy),
          size * 0.35,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.fill,
        );
    }
  }

  void _drawLevelBadge(
    Canvas canvas,
    OrbLevel level,
    double cx,
    double cy,
    double r,
  ) {
    final label = switch (level) {
      OrbLevel.one => 'Nv.1',
      OrbLevel.two => 'Nv.2',
      OrbLevel.three => 'Nv.3',
    };

    final bgBadge = Paint()
      ..color = Colors.black.withValues(alpha: 0.78)
      ..style = PaintingStyle.fill;

    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: r * 0.88, height: 11),
      const Radius.circular(3),
    );
    canvas.drawRRect(badgeRect, bgBadge);

    final border = Paint()
      ..color = switch (level) {
        OrbLevel.one => const Color(0xFFC0C0C0),
        OrbLevel.two => const Color(0xFFFFD700),
        OrbLevel.three => const Color(0xFFFF5A26),
      }
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    canvas.drawRRect(badgeRect, border);

    TextPaint(
      style: const TextStyle(
        color: Colors.white,
        fontSize: 8.5,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.5,
      ),
    ).render(
      canvas,
      label,
      Vector2(cx - 10.5, cy - 5.5),
    );
  }
}

import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Element;

import '../../domain/combat/combat_engine.dart';
import '../../domain/value_objects/element.dart';
import 'brimstone_combat_game.dart';

/// Procedurally-painted boss with imposing Dark Fantasy anatomical silhouette:
/// rotating runic portal behind, deployed dark/igneous wings, spiked armored pauldrons,
/// demonic horned head, glowing slit eyes, torso with elemental energy fissures,
/// breathing animation, hit flash, and attack timer / aura countdown bar.
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

  Color get elementAccent => switch (combatGame.engine.boss.element) {
        Element.igneous => const Color(0xFFFFD980),
        Element.abyssal => const Color(0xFF80E8FF),
        Element.telluric => const Color(0xFFF0D0A0),
        Element.empty => const Color(0xFFE5D4FF),
      };

  bool get _enraged => combatGame.engine.enraged;

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
    final breathe = 1 + 0.03 * math.sin(e.time * 2 * math.pi / 2.8);

    final enrageScale = _enraged ? 1.15 : 1.0;
    final bodyColor = _enraged ? _enrageColor : elementColor;
    final accent = elementAccent;

    // 1. Portal rúnico giratorio detrás
    _drawRunicPortal(canvas, cx, cy, e.time, bodyColor);

    // 2. Silueta anatómica Dark Fantasy
    _drawDarkFantasyBoss(
      canvas,
      cx,
      cy,
      breathe * enrageScale,
      bodyColor,
      accent,
      e.time,
    );

    // 3. Hit flash
    if (_flash > 0) {
      final flashPaint = Paint()
        ..color = Colors.white.withValues(
          alpha: (0.6 * _flash / 0.12).clamp(0.0, 1.0),
        );
      _drawFlashSilhouette(canvas, cx, cy, breathe * enrageScale, flashPaint);
    }

    // 4. Attack timer bar
    final frac = (1 - (e.bossAttackTimer / e.boss.attackInterval)).clamp(
      0.0,
      1.0,
    );
    final barY = cy - 130;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 62, barY, 124, 7),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF1E0A0E),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 60, barY + 1, 120 * frac, 5),
        const Radius.circular(2),
      ),
      Paint()..color = _enraged ? Colors.orangeAccent : Colors.redAccent,
    );

    // 5. Aura rune ring + countdown
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

  /// Portal rúnico místico giratorio detrás del cuerpo del jefe
  void _drawRunicPortal(
    Canvas canvas,
    double cx,
    double cy,
    double time,
    Color color,
  ) {
    const portalR = 95.0;
    final portalCenter = Offset(cx, cy - 10);

    // Glow ambiental exterior
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22);
    canvas.drawCircle(portalCenter, portalR * 1.1, glowPaint);

    // Anillo exterior con gradiente
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..shader = SweepGradient(
        colors: [
          color.withValues(alpha: 0.1),
          color.withValues(alpha: 0.8),
          Colors.white.withValues(alpha: 0.9),
          color.withValues(alpha: 0.8),
          color.withValues(alpha: 0.1),
        ],
        transform: GradientRotation(time * 0.8),
      ).createShader(Rect.fromCircle(center: portalCenter, radius: portalR));
    canvas.drawCircle(portalCenter, portalR, ringPaint);

    // Anillo interior secundario girando en sentido inverso
    final innerRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = color.withValues(alpha: 0.45);
    canvas.drawCircle(portalCenter, portalR * 0.72, innerRingPaint);

    // Runas segmentadas en órbita
    final runePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = Colors.white.withValues(alpha: 0.65);

    const runeCount = 8;
    for (var i = 0; i < runeCount; i++) {
      final angle = time * 0.6 + i * (math.pi * 2 / runeCount);
      final rx = cx + math.cos(angle) * portalR;
      final ry = (cy - 10) + math.sin(angle) * portalR;
      canvas.save();
      canvas.translate(rx, ry);
      canvas.rotate(angle + math.pi / 2);
      canvas.drawLine(const Offset(-4, 0), const Offset(4, 0), runePaint);
      canvas.drawLine(const Offset(0, -4), const Offset(0, 4), runePaint);
      canvas.drawCircle(Offset.zero, 1.8, Paint()..color = color);
      canvas.restore();
    }
  }

  /// Silueta Dark Fantasy: alas desplegadas, hombreras con púas, cuernos curvos,
  /// ojos luminosos rasgados y torso con fisuras incandescentes.
  void _drawDarkFantasyBoss(
    Canvas canvas,
    double cx,
    double cy,
    double scale,
    Color color,
    Color accent,
    double time,
  ) {
    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(scale);

    // ── ALAS DESPLEGADAS (Izquierda y Derecha) ─────────────────────
    _drawWings(canvas, color, accent, time);

    // ── TORSO Y CORAZA ACORAZADA ──────────────────────────────────
    _drawTorso(canvas, color, accent);

    // ── HOMBRERAS CON PÚAS ─────────────────────────────────────────
    _drawSpikedPauldrons(canvas, color, accent);

    // ── CABEZA DEMONÍACA Y CUERNOS CURVOS ─────────────────────────
    _drawDemonHead(canvas, color, accent);

    // ── OJOS RASGADOS LUMINOSOS ────────────────────────────────────
    _drawLuminousEyes(canvas, accent, time);

    canvas.restore();
  }

  void _drawWings(Canvas canvas, Color color, Color accent, double time) {
    final wingFlap = math.sin(time * 2.2) * 5.0;

    for (final side in [-1.0, 1.0]) {
      final wingPath = Path();
      // Origen en la espalda superior
      wingPath.moveTo(side * 22, -18);

      // Codo superior del ala
      final tipX = side * (108 + wingFlap * side);
      const tipY = -78.0;
      wingPath.cubicTo(
        side * 45,
        -55,
        side * 78,
        -88,
        tipX,
        tipY,
      );

      // Garras / membranas del ala desplegada
      wingPath.cubicTo(
        side * 85,
        -35,
        side * 92,
        -15,
        side * 98,
        5,
      );
      wingPath.cubicTo(
        side * 70,
        -5,
        side * 60,
        20,
        side * 64,
        42,
      );
      wingPath.cubicTo(
        side * 42,
        22,
        side * 28,
        15,
        side * 18,
        10,
      );
      wingPath.close();

      // Gradiente oscuro a elemento ígneo/abyssal
      final wingPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.85),
            const Color(0xFF15080E),
          ],
        ).createShader(Rect.fromLTWH(side < 0 ? -115 : 0, -85, 120, 130))
        ..style = PaintingStyle.fill;
      canvas.drawPath(wingPath, wingPaint);

      // Huesos/costillas del ala (borde afilado)
      final bonePaint = Paint()
        ..color = accent.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawPath(wingPath, bonePaint);

      // Costillas internas luminosas
      final ribPaint = Paint()
        ..color = color.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4;
      canvas.drawLine(
        Offset(side * 30, -25),
        Offset(side * 85, -30),
        ribPaint,
      );
      canvas.drawLine(
        Offset(side * 25, -10),
        Offset(side * 75, 10),
        ribPaint,
      );
    }
  }

  void _drawTorso(Canvas canvas, Color color, Color accent) {
    // Silueta del torso musculoso/acorazado en V
    final torsoPath = Path()
      ..moveTo(-34, -20)
      ..cubicTo(-38, 10, -28, 48, -16, 75)
      ..lineTo(16, 75)
      ..cubicTo(28, 48, 38, 10, 34, -20)
      ..close();

    final torsoPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.2),
        radius: 0.9,
        colors: [
          const Color(0xFF261017),
          const Color(0xFF0D0508),
        ],
      ).createShader(const Rect.fromLTWH(-40, -25, 80, 105))
      ..style = PaintingStyle.fill;
    canvas.drawPath(torsoPath, torsoPaint);

    final torsoBorder = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(torsoPath, torsoBorder);

    // ── GRIETAS DE ENERGÍA INCANDESCENTE EN EL TORSO ─────────────
    final crackPaint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 1.5);

    final coreGlow = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;

    // Núcleo rúnico central en el pecho
    canvas.drawCircle(
      const Offset(0, 5),
      8,
      Paint()
        ..color = color.withValues(alpha: 0.85)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(
      const Offset(0, 5),
      3.5,
      Paint()..color = Colors.white,
    );

    // Fisuras radiantes desde el pecho
    final cracks = [
      [const Offset(0, 5), const Offset(-18, 22), const Offset(-25, 45)],
      [const Offset(0, 5), const Offset(18, 22), const Offset(25, 45)],
      [const Offset(0, 5), const Offset(-8, -12), const Offset(-16, -18)],
      [const Offset(0, 5), const Offset(8, -12), const Offset(16, -18)],
      [const Offset(0, 12), const Offset(0, 38), const Offset(5, 62)],
    ];

    for (final seg in cracks) {
      final path = Path()..moveTo(seg[0].dx, seg[0].dy);
      for (var i = 1; i < seg.length; i++) {
        path.lineTo(seg[i].dx, seg[i].dy);
      }
      canvas.drawPath(path, crackPaint);
      canvas.drawPath(path, coreGlow);
    }
  }

  void _drawSpikedPauldrons(Canvas canvas, Color color, Color accent) {
    for (final side in [-1.0, 1.0]) {
      final pPath = Path()
        ..moveTo(side * 22, -26)
        ..lineTo(side * 52, -38) // Púa principal exterior
        ..lineTo(side * 42, -18)
        ..lineTo(side * 56, -12) // Púa secundaria
        ..lineTo(side * 36, 0)
        ..lineTo(side * 22, -10)
        ..close();

      final pPaint = Paint()
        ..color = const Color(0xFF2A151E)
        ..style = PaintingStyle.fill;
      canvas.drawPath(pPath, pPaint);

      final pStroke = Paint()
        ..color = accent.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawPath(pPath, pStroke);
    }
  }

  void _drawDemonHead(Canvas canvas, Color color, Color accent) {
    // ── CUERNOS CURVOS GRANDES ────────────────────────────────────
    for (final side in [-1.0, 1.0]) {
      final hornPath = Path()
        ..moveTo(side * 14, -46)
        ..cubicTo(
          side * 28,
          -64,
          side * 48,
          -86,
          side * 36,
          -106, // Punta curvada hacia adentro
        )
        ..cubicTo(
          side * 26,
          -82,
          side * 18,
          -66,
          side * 8,
          -48,
        )
        ..close();

      final hornPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            const Color(0xFF1E0E15),
            color.withValues(alpha: 0.95),
            accent,
          ],
        ).createShader(Rect.fromLTWH(side < 0 ? -48 : 0, -110, 50, 70))
        ..style = PaintingStyle.fill;
      canvas.drawPath(hornPath, hornPaint);

      final hornEdge = Paint()
        ..color = Colors.white.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4;
      canvas.drawPath(hornPath, hornEdge);
    }

    // ── CABEZA / MÁSCARA ANGULAR ──────────────────────────────────
    final headPath = Path()
      ..moveTo(0, -22) // Mentón afilado
      ..lineTo(-18, -38) // Mandíbula izquierda
      ..lineTo(-16, -56) // Sien izquierda
      ..lineTo(0, -62) // Frente superior
      ..lineTo(16, -56) // Sien derecha
      ..lineTo(18, -38) // Mandíbula derecha
      ..close();

    final headPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.8,
        colors: [
          const Color(0xFF351722),
          const Color(0xFF12060A),
        ],
      ).createShader(const Rect.fromLTWH(-20, -65, 40, 45))
      ..style = PaintingStyle.fill;
    canvas.drawPath(headPath, headPaint);

    final headStroke = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(headPath, headStroke);
  }

  void _drawLuminousEyes(Canvas canvas, Color accent, double time) {
    final eyeGlow = 0.7 + 0.3 * math.sin(time * 5.0);

    final glowPaint = Paint()
      ..color = accent.withValues(alpha: eyeGlow)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    final eyeCore = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (final side in [-1.0, 1.0]) {
      // Ojo rasgado amenazante
      final eyePath = Path()
        ..moveTo(side * 5, -45)
        ..lineTo(side * 12, -49)
        ..lineTo(side * 6, -47)
        ..close();

      canvas.drawPath(eyePath, glowPaint);
      canvas.drawPath(eyePath, eyeCore);
    }
  }

  void _drawFlashSilhouette(
    Canvas canvas,
    double cx,
    double cy,
    double scale,
    Paint p,
  ) {
    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(scale);

    final torsoPath = Path()
      ..moveTo(-34, -20)
      ..cubicTo(-38, 10, -28, 48, -16, 75)
      ..lineTo(16, 75)
      ..cubicTo(28, 48, 38, 10, 34, -20)
      ..close();
    canvas.drawPath(torsoPath, p);

    final headPath = Path()
      ..moveTo(0, -22)
      ..lineTo(-18, -38)
      ..lineTo(-16, -56)
      ..lineTo(0, -62)
      ..lineTo(16, -56)
      ..lineTo(18, -38)
      ..close();
    canvas.drawPath(headPath, p);

    canvas.restore();
  }
}

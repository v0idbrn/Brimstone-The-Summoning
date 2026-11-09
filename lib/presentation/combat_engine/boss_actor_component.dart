import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Element;
import 'package:flutter/services.dart';

import '../../domain/campaign/campaign_enemies.dart';
import '../../domain/combat/combat_engine.dart';
import '../../domain/value_objects/element.dart';
import 'brimstone_combat_game.dart';

/// Ruta real del retrato de un jefe (assets/portraits/), o null si se usa
/// el fallback pintado. Los Titanes de Raid se mapean por elemento.
String? _portraitAssetForBoss(String bossId) {
  for (final e in campaignEnemies) {
    if (e.id == bossId) return 'assets/${e.portraitAsset}';
  }
  const titans = {
    'titan_igneous': 'assets/portraits/boss_pyroth.webp',
    'titan_abyssal': 'assets/portraits/boss_vaelor.webp',
    'titan_telluric': 'assets/portraits/boss_gorgath.webp',
    'titan_void': 'assets/portraits/boss_nyxara.webp',
  };
  final titan = titans[bossId];
  if (titan != null) return titan;
  const namedBosses = ['pyroth', 'vaelor', 'azathor', 'gorgath', 'nyxara'];
  if (namedBosses.contains(bossId)) return 'assets/portraits/boss_$bossId.webp';
  return null;
}

/// Boss actor that renders a full-color Wesnoth painted portrait (240x240) with:
/// - Rotating abyssal portal behind
/// - Breathing animation (vertical scale 1.0 <-> 1.04)
/// - Hit flash (white flash)
/// - Red shake on hit
/// - Fire/lightning halo when enraged (<45% HP)
/// - Attack timer bar + aura rune ring
/// NO black circle - the painted portrait IS the boss visual.
class BossActorComponent extends PositionComponent {
  final BrimstoneCombatGame combatGame;
  double _flash = 0;
  double _lastHp = -1;
  double _enragePulse = 0;
  double _hitShake = 0;
  ui.Image? _portraitImage;

  BossActorComponent(this.combatGame) {
    position = Vector2.zero();
    priority = 0;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Retratos reales en assets/portraits/<id>.webp cargados por bytes
    // (Flame.images añade el prefijo assets/images/ que no existe aquí).
    final asset = _portraitAssetForBoss(combatGame.engine.boss.id);
    if (asset == null) return;
    try {
      final data = await rootBundle.load(asset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      _portraitImage = (await codec.getNextFrame()).image;
    } catch (_) {
      // Imagen no disponible: se usa el fallback pintado.
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    final hp = combatGame.engine.bossHp;
    if (_lastHp >= 0 && hp < _lastHp) {
      _flash = 0.15;
      _hitShake = 0.1;
    }
    _lastHp = hp;
    _flash = math.max(0, _flash - dt * 8);
    _hitShake = math.max(0, _hitShake - dt * 10);
    if (combatGame.engine.enraged) {
      _enragePulse += dt * 3;
    } else {
      _enragePulse = math.max(0, _enragePulse - dt * 2);
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
    return Color.lerp(base, const Color(0xFFFF5A26), 0.4 + 0.4 * pulse)!;
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

    // Breathing animation: vertical scale 1.0 <-> 1.04
    final breathe = 1 + 0.04 * math.sin(e.time * 2 * math.pi / 2.8);

    // Enrage scale: 1.15x when enraged
    final enrageScale = _enraged ? 1.15 : 1.0;

    // Hit shake offset
    final shakeX = _hitShake > 0 ? (math.sin(e.time * 90) * _hitShake * 8) : 0;
    final shakeY = _hitShake > 0 ? (math.cos(e.time * 73) * _hitShake * 4) : 0;

    final totalScale = breathe * enrageScale;
    final bodyColor = _enraged ? _enrageColor : elementColor;
    final accent = elementAccent;

    // 1. Portal rúnico giratorio detrás (scaled to 240px portrait)
    _drawRunicPortal(canvas, cx + shakeX, cy + shakeY, e.time, bodyColor);

    // 2. Painted boss portrait - 240x240, no black circle, no frame
    _drawPaintedPortrait(
      canvas,
      cx + shakeX,
      cy + shakeY,
      totalScale,
      bodyColor,
      accent,
      e.time,
    );

    // 3. Hit flash
    if (_flash > 0) {
      final flashPaint = Paint()
        ..color = Colors.white.withValues(
          alpha: (_flash / 0.15).clamp(0.0, 1.0),
        )
        ..blendMode = BlendMode.srcATop;
      _drawPortraitSilhouette(
          canvas, cx + shakeX, cy + shakeY, totalScale, flashPaint);
    }

    // 4. Enrage halo (fire/lightning aura)
    if (_enraged) {
      _drawEnrageHalo(canvas, cx + shakeX, cy + shakeY, totalScale, bodyColor,
          accent, e.time);
    }

    // 5. Attack timer bar (above portrait)
    final frac =
        (1 - (e.bossAttackTimer / e.boss.attackInterval)).clamp(0.0, 1.0);
    final barY = cy - 170; // moved up for 240px portrait
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

    // 6. Aura rune ring + countdown
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

  /// Portal rúnico místico giratorio detrás del retrato del jefe (scaled for 240px portrait)
  void _drawRunicPortal(
    Canvas canvas,
    double cx,
    double cy,
    double time,
    Color color,
  ) {
    const portalR = 130.0; // larger for 240px portrait
    final portalCenter = Offset(cx, cy - 20);

    // Glow ambiental exterior
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);
    canvas.drawCircle(portalCenter, portalR * 1.15, glowPaint);

    // Anillo exterior con gradiente giratorio
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..shader = SweepGradient(
        colors: [
          color.withValues(alpha: 0.05),
          color.withValues(alpha: 0.6),
          Colors.white.withValues(alpha: 0.8),
          color.withValues(alpha: 0.6),
          color.withValues(alpha: 0.05),
        ],
        transform: GradientRotation(time * 0.6),
      ).createShader(Rect.fromCircle(center: portalCenter, radius: portalR));
    canvas.drawCircle(portalCenter, portalR, ringPaint);

    // Anillo interior secundario girando en sentido inverso
    final innerRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color.withValues(alpha: 0.4);
    canvas.drawCircle(portalCenter, portalR * 0.68, innerRingPaint);

    // Runas segmentadas en órbita
    final runePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.7);

    const runeCount = 10;
    for (var i = 0; i < runeCount; i++) {
      final angle = time * 0.5 + i * (math.pi * 2 / runeCount);
      final rx = cx + math.cos(angle) * portalR;
      final ry = (cy - 20) + math.sin(angle) * portalR;
      canvas.save();
      canvas.translate(rx, ry);
      canvas.rotate(angle + math.pi / 2);
      canvas.drawLine(const Offset(-6, 0), const Offset(6, 0), runePaint);
      canvas.drawLine(const Offset(0, -6), const Offset(0, 6), runePaint);
      canvas.drawCircle(Offset.zero, 2.5, Paint()..color = color);
      canvas.restore();
    }
  }

  /// Draw the painted Wesnoth portrait at 240x240 - NO black circle, NO frame
  void _drawPaintedPortrait(
    Canvas canvas,
    double cx,
    double cy,
    double scale,
    Color color,
    Color accent,
    double time,
  ) {
    // Fixed 240x240 portrait size (not scaled by breathe/enrage - that's for portal)
    const portraitSize = 240.0;
    final rect = Rect.fromLTWH(
      cx - portraitSize / 2,
      cy - portraitSize / 2,
      portraitSize,
      portraitSize,
    );

    canvas.save();
    canvas.clipRect(rect);

    if (_portraitImage != null) {
      // Draw the painted portrait maintaining aspect ratio (cover, center)
      final imageRect = Rect.fromLTWH(0, 0, _portraitImage!.width.toDouble(),
          _portraitImage!.height.toDouble());
      final scaleX = rect.width / imageRect.width;
      final scaleY = rect.height / imageRect.height;
      final scaleFactor = math.max(scaleX, scaleY);
      final drawWidth = imageRect.width * scaleFactor;
      final drawHeight = imageRect.height * scaleFactor;
      final drawRect = Rect.fromLTWH(
        rect.center.dx - drawWidth / 2,
        rect.center.dy - drawHeight / 2,
        drawWidth,
        drawHeight,
      );
      canvas.drawImageRect(
        _portraitImage!,
        imageRect,
        drawRect,
        Paint()..filterQuality = FilterQuality.high,
      );
    } else {
      // Fallback: draw procedural silhouette
      _drawFallbackSilhouette(canvas, rect, color, accent);
    }

    canvas.restore();
    // NO elemental frame - the painted art IS the boss
  }

  void _drawFallbackSilhouette(
      Canvas canvas, Rect rect, Color color, Color accent) {
    // Draw a dark silhouette as fallback
    final silhouettePaint = Paint()..color = const Color(0xFF0A0407);
    final center = rect.center;
    final radius = math.min(rect.width, rect.height) * 0.45;
    canvas.drawCircle(center, radius, silhouettePaint);
  }

  void _drawPortraitSilhouette(
    Canvas canvas,
    double cx,
    double cy,
    double scale,
    Paint paint,
  ) {
    const portraitSize = 240.0;
    final rect = Rect.fromLTWH(
      cx - portraitSize / 2,
      cy - portraitSize / 2,
      portraitSize,
      portraitSize,
    );
    canvas.drawRect(rect, paint);
  }

  /// Enrage halo: fire particles for Igneo, lightning for Abyssal, rock debris for Telurico, void wisps for Vacío
  void _drawEnrageHalo(
    Canvas canvas,
    double cx,
    double cy,
    double scale,
    Color color,
    Color accent,
    double time,
  ) {
    final haloRadius = 150 * scale; // larger for 240px portrait
    final particleCount = 24;

    for (var i = 0; i < particleCount; i++) {
      final baseAngle = i * (math.pi * 2 / particleCount);
      final angle = baseAngle + time * 0.8;
      final radius = haloRadius * (0.85 + 0.15 * math.sin(time * 2 + i));
      final px = cx + math.cos(angle) * radius;
      final py = cy + math.sin(angle) * radius;
      final particleScale = 0.5 + 0.5 * math.sin(time * 3 + i);

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(angle);
      canvas.scale(particleScale);

      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = color.withValues(alpha: 0.7);

      // Different particle shapes per element
      switch (combatGame.engine.boss.element) {
        case Element.igneous:
          // Fire ember
          canvas.drawCircle(Offset.zero, 4,
              paint..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
          break;
        case Element.abyssal:
          // Ice shard
          final shardPath = Path()
            ..moveTo(0, -5)
            ..lineTo(-3, 5)
            ..lineTo(3, 5)
            ..close();
          canvas.drawPath(shardPath, paint);
          break;
        case Element.telluric:
          // Rock debris
          canvas.drawRect(
              Rect.fromCenter(center: Offset.zero, width: 6, height: 6), paint);
          break;
        case Element.empty:
          // Void wisp
          canvas.drawCircle(Offset.zero, 5,
              paint..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
          break;
      }
      canvas.restore();
    }
  }
}

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Element;
import 'package:flutter/services.dart';

import '../../core/performance/performance_settings.dart';
import '../../domain/campaign/campaign_enemies.dart';
import '../../domain/combat/combat_engine.dart';
import '../../domain/value_objects/element.dart';
import '../graphics/art_registry.dart';
import 'brimstone_combat_game.dart';

/// Resolves the painted portrait path for a boss id.
///
/// Campaign enemies carry their own curated art; raid titans map to the four
/// dedicated titan paintings. Unknown ids fall back to the chapter I boss so no
/// reference is ever broken.
String _portraitAssetForBoss(String bossId) {
  for (final e in campaignEnemies) {
    if (e.id == bossId) {
      return ArtRegistry.resolvePortraitAsset(e.portraitAsset);
    }
  }
  const titans = {
    'titan_igneous': 'titan_bahamut',
    'titan_abyssal': 'titan_jormungandr',
    'titan_telluric': 'titan_atlas',
    'titan_void': 'titan_nyarlathotep',
    'titan_bahamut': 'titan_bahamut',
    'titan_jormungandr': 'titan_jormungandr',
    'titan_atlas': 'titan_atlas',
    'titan_nyarlathotep': 'titan_nyarlathotep',
  };
  final titan = titans[bossId];
  if (titan != null) return ArtRegistry.portrait(titan);
  const namedBosses = ['pyroth', 'vaelor', 'azathor', 'gorgath', 'nyxara'];
  if (namedBosses.contains(bossId)) {
    return ArtRegistry.portrait('boss_$bossId');
  }
  return ArtRegistry.fallbackPortrait;
}

/// Boss actor: a painted high-resolution portrait emerging from the abyssal
/// rift, never a rectangular photo.
///
/// The silhouette is dissolved with a radial `BlendMode.dstIn` mask so the art
/// melts organically into the magma/void atmosphere. On top of that:
///   * projected ground shadow + breathing float,
///   * twin counter-rotating runic portal rings with orbiting sigils,
///   * white hit flash + lateral crimson shake,
///   * golden vibrating chains while the seal is BROKEN,
///   * overflowing elemental fury halo below 45% HP.
class BossActorComponent extends PositionComponent {
  BossActorComponent(this.combatGame) {
    position = Vector2.zero();
    priority = 0;
  }

  final BrimstoneCombatGame combatGame;

  double _flash = 0;
  double _lastHp = -1;
  double _enragePulse = 0;
  double _hitShake = 0;
  ui.Image? _portraitImage;

  // Preallocated paints: the arena repaints every frame.
  final Paint _imagePaint = Paint()..filterQuality = FilterQuality.high;
  final Paint _maskPaint = Paint()..blendMode = BlendMode.dstIn;
  final Paint _shadowPaint = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22);
  final Paint _glowPaint = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
  final Paint _strokePaint = Paint()..style = PaintingStyle.stroke;
  final Paint _fillPaint = Paint()..style = PaintingStyle.fill;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final asset = _portraitAssetForBoss(combatGame.engine.boss.id);
    try {
      final data = await rootBundle.load(asset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      _portraitImage = (await codec.getNextFrame()).image;
    } catch (_) {
      // Asset unavailable: the procedural silhouette is used instead.
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    final hp = combatGame.engine.bossHp;
    if (_lastHp >= 0 && hp < _lastHp) {
      _flash = 0.15;
      _hitShake = 0.12;
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

  Element get _element => combatGame.engine.boss.element;

  Color get elementColor => switch (_element) {
        Element.igneous => const Color(0xFFFF5A26),
        Element.abyssal => const Color(0xFF3FD8FF),
        Element.telluric => const Color(0xFFB0703B),
        Element.empty => const Color(0xFFB16EFF),
      };

  Color get elementAccent => switch (_element) {
        Element.igneous => const Color(0xFFFFD980),
        Element.abyssal => const Color(0xFF80E8FF),
        Element.telluric => const Color(0xFFF0D0A0),
        Element.empty => const Color(0xFFE5D4FF),
      };

  bool get _enraged => combatGame.engine.enraged;
  bool get _broken => combatGame.engine.bossShieldBroken;

  Color get _enrageColor {
    final pulse = (math.sin(_enragePulse) + 1) / 2;
    return Color.lerp(
        elementColor, const Color(0xFFFF5A26), 0.4 + 0.4 * pulse)!;
  }

  @override
  void render(Canvas canvas) {
    final e = combatGame.engine;
    canvas.save();
    canvas.translate(combatGame.offsetX, combatGame.offsetY);
    canvas.scale(combatGame.viewScale);

    final cx = CombatEngine.bossScreenX;
    final cy = CombatEngine.bossScreenY;

    final float = math.sin(e.time * 2 * math.pi / 3.1) * 5.0;
    final breathe = 1 + 0.04 * math.sin(e.time * 2 * math.pi / 2.8);
    final enrageScale = _enraged ? 1.12 : 1.0;
    final scale = breathe * enrageScale;

    final shakeX = _hitShake > 0 ? math.sin(e.time * 90) * _hitShake * 9 : 0.0;
    final shakeY = _hitShake > 0 ? math.cos(e.time * 73) * _hitShake * 4 : 0.0;

    final px = cx + shakeX;
    final py = cy + shakeY + float;
    final bodyColor = _enraged ? _enrageColor : elementColor;

    // Plane 1 — rift portal burning behind the boss.
    _drawGroundShadow(canvas, px, cy, scale);
    _drawRunicPortal(canvas, cx + shakeX * 0.4, cy - 18, e.time, bodyColor);

    // Plane 2 — the painted boss fused into the rift (no hard edges).
    _drawOrganicPortrait(canvas, px, py, scale, bodyColor, e.time);

    if (_flash > 0) {
      _drawFlash(canvas, px, py, scale);
    }
    if (_broken) {
      _drawSealChains(canvas, px, py, scale, e.time);
    }
    if (_enraged) {
      _drawEnrageHalo(canvas, px, py, scale, bodyColor, elementAccent, e.time);
    }

    _drawAttackTimer(canvas, cx, cy);
    _drawAuraTimer(canvas, cx, cy);

    canvas.restore();
  }

  // ── Plane 1: portal ──────────────────────────────────────────────────
  void _drawRunicPortal(
    Canvas canvas,
    double cx,
    double cy,
    double time,
    Color color,
  ) {
    const radius = 132.0;
    final center = Offset(cx, cy);

    _glowPaint.color = color.withValues(alpha: 0.20);
    canvas.drawCircle(center, radius * 1.18, _glowPaint);

    // Inner void disc: layered radial lava.
    _fillPaint.shader = RadialGradient(
      colors: [
        color.withValues(alpha: 0.30),
        const Color(0xFF120610).withValues(alpha: 0.62),
        Colors.transparent,
      ],
      stops: const [0.0, 0.55, 1.0],
    ).createShader(Rect.fromCircle(center: center, radius: radius * 0.92));
    canvas.drawCircle(center, radius * 0.92, _fillPaint);
    _fillPaint.shader = null;

    // Outer ring: segmented, clockwise.
    const segments = 14;
    for (var i = 0; i < segments; i++) {
      final start = time * 0.55 + i * (math.pi * 2 / segments);
      _strokePaint
        ..strokeWidth = 3.0
        ..shader = SweepGradient(
          colors: [
            color.withValues(alpha: 0.05),
            color.withValues(alpha: 0.75),
            Colors.white.withValues(alpha: 0.9),
            color.withValues(alpha: 0.75),
            color.withValues(alpha: 0.05),
          ],
          transform: GradientRotation(time * 0.6),
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        (math.pi * 2 / segments) * 0.62,
        false,
        _strokePaint,
      );
    }
    _strokePaint.shader = null;

    // Middle ring: counter-rotating runes.
    const midR = 108.0;
    _strokePaint
      ..strokeWidth = 2.2
      ..color = color.withValues(alpha: 0.55);
    canvas.drawCircle(center, midR, _strokePaint);

    const runeCount = 12;
    for (var i = 0; i < runeCount; i++) {
      final angle = -time * 0.7 + i * (math.pi * 2 / runeCount);
      final rx = center.dx + math.cos(angle) * midR;
      final ry = center.dy + math.sin(angle) * midR;
      canvas.save();
      canvas.translate(rx, ry);
      canvas.rotate(angle + math.pi / 2);
      _strokePaint
        ..strokeWidth = 2.0
        ..color = Colors.white.withValues(alpha: 0.72);
      canvas.drawLine(const Offset(-6, 0), const Offset(6, 0), _strokePaint);
      canvas.drawLine(const Offset(0, -6), const Offset(0, 6), _strokePaint);
      _fillPaint.color = color;
      canvas.drawCircle(Offset.zero, 2.4, _fillPaint);
      canvas.restore();
    }

    // Inner ring: fast dervish.
    _strokePaint
      ..strokeWidth = 1.4
      ..color = color.withValues(alpha: 0.4);
    canvas.drawCircle(center, 74, _strokePaint);
    for (var i = 0; i < 5; i++) {
      final a = time * 1.6 + i * math.pi * 2 / 5;
      _fillPaint.color = elementAccent.withValues(alpha: 0.55);
      canvas.drawCircle(
        Offset(center.dx + math.cos(a) * 74, center.dy + math.sin(a) * 74),
        3.2,
        _fillPaint,
      );
    }

    // Rising embers escaping the rift.
    if (PerformanceSettings.enableSecondaryGlow) {
      final count = PerformanceSettings.lowSpecMode ? 8 : 18;
      for (var i = 0; i < count; i++) {
        final t = ((time * 0.35 + i * 0.137) % 1.0);
        final a = i * 2.399963;
        final rr = radius * (0.35 + 0.55 * (1 - t));
        final x = center.dx + math.cos(a) * rr;
        final y = center.dy + math.sin(a) * rr - t * 120;
        _fillPaint.color = color.withValues(alpha: (1 - t) * 0.5);
        canvas.drawCircle(Offset(x, y), 1.4 + 1.8 * (1 - t), _fillPaint);
      }
    }
  }

  void _drawGroundShadow(Canvas canvas, double cx, double groundY, double s) {
    _shadowPaint.color = Colors.black.withValues(alpha: 0.55);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, groundY + 148),
        width: 210 * s,
        height: 44 * s,
      ),
      _shadowPaint,
    );
    _fillPaint.color = elementColor.withValues(alpha: 0.10);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, groundY + 148),
        width: 150 * s,
        height: 30 * s,
      ),
      _fillPaint,
    );
  }

  // ── Plane 2: organic portrait ────────────────────────────────────────
  void _drawOrganicPortrait(
    Canvas canvas,
    double cx,
    double cy,
    double scale,
    Color color,
    double time,
  ) {
    const size = 260.0;
    final rect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: size * scale,
      height: size * scale,
    );

    // Layer isolates the art so `dstIn` only dissolves this silhouette.
    canvas.saveLayer(rect.inflate(2), Paint());

    if (_portraitImage != null) {
      final image = _portraitImage!;
      final src = Rect.fromLTWH(
        0,
        0,
        image.width.toDouble(),
        image.height.toDouble(),
      );
      final scaleFactor = math.max(
        rect.width / src.width,
        rect.height / src.height,
      );
      final drawW = src.width * scaleFactor;
      final drawH = src.height * scaleFactor;
      final dst = Rect.fromCenter(
        center: rect.center,
        width: drawW,
        height: drawH,
      );
      canvas.drawImageRect(image, src, dst, _imagePaint);
    } else {
      _fillPaint.shader = RadialGradient(
        colors: [color.withValues(alpha: 0.9), const Color(0xFF0A0407)],
      ).createShader(rect);
      canvas.drawOval(rect, _fillPaint);
      _fillPaint.shader = null;
    }

    // Organic dissolve: elliptical gradient fades every edge to alpha 0.
    _maskPaint.shader = RadialGradient(
      colors: [
        Colors.white,
        Colors.white,
        Colors.white.withValues(alpha: 0.72),
        Colors.transparent,
      ],
      stops: const [0.0, 0.58, 0.82, 1.0],
    ).createShader(rect);
    canvas.drawOval(rect, _maskPaint);
    _maskPaint.shader = null;
    canvas.restore();

    // Elemental rim light hugging the dissolved silhouette.
    _strokePaint
      ..strokeWidth = 2.2
      ..shader = SweepGradient(
        colors: [
          color.withValues(alpha: 0.0),
          color.withValues(alpha: 0.55),
          Colors.white.withValues(alpha: 0.7),
          color.withValues(alpha: 0.55),
          color.withValues(alpha: 0.0),
        ],
        transform: GradientRotation(time * 0.8),
      ).createShader(rect);
    canvas.drawOval(rect.deflate(6), _strokePaint);
    _strokePaint.shader = null;
  }

  void _drawFlash(Canvas canvas, double cx, double cy, double scale) {
    const size = 260.0;
    final rect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: size * scale,
      height: size * scale,
    );
    final alpha = (_flash / 0.15).clamp(0.0, 1.0);

    canvas.saveLayer(rect.inflate(2), Paint());
    _fillPaint
      ..blendMode = BlendMode.srcATop
      ..color = Colors.white.withValues(alpha: alpha * 0.9);
    canvas.drawRect(rect, _fillPaint);
    _fillPaint.blendMode = BlendMode.srcOver;

    _maskPaint.shader = RadialGradient(
      colors: [Colors.white, Colors.transparent],
      stops: const [0.55, 1.0],
    ).createShader(rect);
    canvas.drawOval(rect, _maskPaint);
    _maskPaint.shader = null;
    canvas.restore();

    // Crimson slash across the silhouette.
    _strokePaint
      ..strokeWidth = 4.0
      ..color = const Color(0xFFFF2A54).withValues(alpha: alpha);
    canvas.drawLine(
      Offset(rect.left + 18, rect.top + 40),
      Offset(rect.right - 18, rect.bottom - 40),
      _strokePaint,
    );
  }

  // ── Seal chains while the boss is BROKEN ─────────────────────────────
  void _drawSealChains(
    Canvas canvas,
    double cx,
    double cy,
    double scale,
    double time,
  ) {
    const links = 9;
    _strokePaint
      ..strokeWidth = 2.4
      ..color = const Color(0xFFF2D078).withValues(alpha: 0.85);
    for (var side = 0; side < 2; side++) {
      final dir = side == 0 ? -1.0 : 1.0;
      for (var i = 0; i < links; i++) {
        final t = i / (links - 1);
        final x = cx + dir * (40 + t * 118) * scale;
        final y = cy -
            40 +
            t * 150 * scale +
            math.sin(time * 6 + i * 0.8 + side) * 3.5;
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(dir * (0.5 + math.sin(time * 3 + i) * 0.18));
        canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: 16, height: 9),
          _strokePaint,
        );
        canvas.restore();
      }
    }
    // Broken seal sparks.
    for (var i = 0; i < 8; i++) {
      final a = time * 2 + i * math.pi / 4;
      _fillPaint.color = const Color(0xFFFFE28A)
          .withValues(alpha: 0.4 + 0.4 * math.sin(time * 5 + i));
      canvas.drawCircle(
        Offset(cx + math.cos(a) * 96 * scale, cy + math.sin(a) * 96 * scale),
        2.6,
        _fillPaint,
      );
    }
  }

  // ── Enrage fury halo ─────────────────────────────────────────────────
  void _drawEnrageHalo(
    Canvas canvas,
    double cx,
    double cy,
    double scale,
    Color color,
    Color accent,
    double time,
  ) {
    final haloRadius = 152 * scale;
    final count = PerformanceSettings.lowSpecMode ? 10 : 24;

    _glowPaint.color =
        color.withValues(alpha: 0.16 + 0.06 * math.sin(time * 4));
    canvas.drawCircle(Offset(cx, cy), haloRadius * 1.08, _glowPaint);

    for (var i = 0; i < count; i++) {
      final angle = i * (math.pi * 2 / count) + time * 0.8;
      final radius = haloRadius * (0.85 + 0.15 * math.sin(time * 2 + i));
      final px = cx + math.cos(angle) * radius;
      final py = cy + math.sin(angle) * radius;
      final particleScale = 0.5 + 0.5 * math.sin(time * 3 + i);

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(angle);
      canvas.scale(particleScale);

      _fillPaint.color =
          Color.lerp(color, accent, 0.35)!.withValues(alpha: 0.78);
      _fillPaint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);

      switch (_element) {
        case Element.igneous:
          canvas.drawCircle(Offset.zero, 4.2, _fillPaint);
        case Element.abyssal:
          final shard = Path()
            ..moveTo(0, -6)
            ..lineTo(-3.2, 5)
            ..lineTo(3.2, 5)
            ..close();
          canvas.drawPath(shard, _fillPaint);
        case Element.telluric:
          canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: 6, height: 6),
            _fillPaint,
          );
        case Element.empty:
          canvas.drawCircle(Offset.zero, 5.2, _fillPaint);
      }
      _fillPaint.maskFilter = null;
      canvas.restore();
    }
  }

  // ── HUD-ish overlays anchored to the boss ────────────────────────────
  void _drawAttackTimer(Canvas canvas, double cx, double cy) {
    final e = combatGame.engine;
    final frac =
        (1 - (e.bossAttackTimer / e.boss.attackInterval)).clamp(0.0, 1.0);
    final barY = cy - 176;
    _fillPaint.color = const Color(0xFF1E0A0E);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 62, barY, 124, 7),
        const Radius.circular(3),
      ),
      _fillPaint,
    );
    _fillPaint.color = _enraged ? Colors.orangeAccent : Colors.redAccent;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 60, barY + 1, 120 * frac, 5),
        const Radius.circular(2),
      ),
      _fillPaint,
    );
  }

  void _drawAuraTimer(Canvas canvas, double cx, double cy) {
    final e = combatGame.engine;
    final aura = e.aura;
    if (aura == null) return;
    final by = cy - 210;
    _strokePaint
      ..strokeWidth = 3
      ..color = elementColor;
    canvas.drawCircle(Offset(cx, by), 24, _strokePaint);
    _strokePaint
      ..strokeWidth = 3.5
      ..color = Colors.white;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, by), radius: 24),
      -math.pi / 2,
      2 * math.pi * (e.auraRemaining / 5.0),
      false,
      _strokePaint,
    );
    TextPaint(style: TextStyle(color: elementColor, fontSize: 13)).render(
      canvas,
      '${e.auraRemaining.toStringAsFixed(1)}s',
      Vector2(cx - 15, by - 8),
    );
  }
}

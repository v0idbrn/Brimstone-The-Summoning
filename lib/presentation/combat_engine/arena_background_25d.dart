import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Element;
import 'package:flutter/services.dart';

import '../../core/performance/performance_settings.dart';
import '../../domain/campaign/campaign_chapters.dart';
import '../../domain/combat/combat_engine.dart';
import '../../domain/value_objects/element.dart';
import '../graphics/art_registry.dart';
import '../graphics/rift_effect.dart';
import 'brimstone_combat_game.dart';

/// Five-plane cinematic arena (HellFire-style depth staging).
///
///   Plane 0 — painted panoramic chapter illustration with volumetric haze and
///             a slow breathing camera sway.
///   Plane 1 — the living abyssal rift (GPU fragment shader, canvas fallback).
///   Plane 2 — the boss portrait (owned by [BossActorComponent]).
///   Plane 3 — gothic foreground columns, low fog and rising embers
///             ([ArenaForeground25D]).
///   Plane 4 — the arcane bullseye seals (owned by [BossTargetReticle]).
class ArenaBackground25D extends PositionComponent {
  ArenaBackground25D(this.combatGame) {
    position = Vector2.zero();
    priority = -10;
  }

  final BrimstoneCombatGame combatGame;

  ui.Image? _scene;
  ui.FragmentShader? _riftShader;
  bool _shaderReady = false;

  // Preallocated paints: the arena repaints every frame.
  final Paint _paint = Paint();
  final Paint _linePaint = Paint()..style = PaintingStyle.stroke;
  final Paint _fillPaint = Paint()..style = PaintingStyle.fill;
  final Paint _fogPaint = Paint()..style = PaintingStyle.fill;
  final Paint _shaderPaint = Paint()..blendMode = BlendMode.plus;

  Element get bossElement => combatGame.engine.boss.element;

  Color get portalColor => switch (bossElement) {
        Element.igneous => const Color(0xFFFF5A26),
        Element.abyssal => const Color(0xFF3FD8FF),
        Element.telluric => const Color(0xFFB0703B),
        Element.empty => const Color(0xFFB16EFF),
      };

  String get _sceneAsset {
    final id = combatGame.engine.boss.id;
    for (final chapter in campaignChapters) {
      if (chapter.boss.id == id) {
        return ArtRegistry.chapterBackground(chapter.number);
      }
    }
    if (id.startsWith('titan_')) return ArtRegistry.raid;
    return ArtRegistry.chapter1;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    try {
      final data = await rootBundle.load(_sceneAsset);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: 1280,
      );
      _scene = (await codec.getNextFrame()).image;
    } catch (_) {
      _scene = null;
    }
    _riftShader = BrimstoneShaders.newRiftShader();
    _shaderReady = _riftShader != null;
  }

  @override
  void render(Canvas canvas) {
    final e = combatGame.engine;
    final s = combatGame.viewScale;
    final w = CombatEngine.layoutWidth;
    final h = CombatEngine.layoutHeight;
    final horizonY = h * 0.30;
    final time = e.time;

    canvas.save();
    canvas.translate(combatGame.offsetX, combatGame.offsetY);
    canvas.scale(s);

    // ── Plane 0: painted scene (breathing parallax) ────────────────────
    _drawScene(canvas, w, h, horizonY, time);

    // ── Volumetric grade + distant arcane atmosphere ───────────────────
    _paint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF08040B).withValues(alpha: 0.86),
        const Color(0xFF1A0A12).withValues(alpha: 0.35),
        const Color(0xFF09040A).withValues(alpha: 0.92),
      ],
      stops: const [0.0, 0.46, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), _paint);
    _paint.shader = null;

    // ── Plane 1: the dimensional rift heart ────────────────────────────
    _drawRift(canvas, time);

    // ── Obsidian floor with vanishing perspective grid ─────────────────
    _paint.color = const Color(0xFF0B0509).withValues(alpha: 0.72);
    canvas.drawRect(Rect.fromLTWH(0, horizonY, w, h - horizonY), _paint);
    _linePaint
      ..strokeWidth = 1.6
      ..color = portalColor.withValues(alpha: 0.20);
    final vanish = Offset(w * 0.5, horizonY);
    for (var i = -7; i <= 7; i++) {
      canvas.drawLine(
        vanish,
        Offset(w * 0.5 + i * (w / 7.0), h),
        _linePaint,
      );
    }
    _linePaint.color = const Color(0xFF3A1A1F).withValues(alpha: 0.55);
    for (var i = 1; i <= 7; i++) {
      final t = i / 7.0;
      final y = CombatMathLerp.lerp(horizonY, h, t * t);
      canvas.drawLine(Offset(0, y), Offset(w, y), _linePaint);
    }

    // ── Low-lying fog bank sweeping across the floor ───────────────────
    if (PerformanceSettings.enableDecorativeBackground) {
      _drawFogBands(canvas, w, h, horizonY, time);
    }

    // ── Rising embers / ash (Plane 3 partial) ──────────────────────────
    _drawEmbers(canvas, w, h, time);

    // ── Cinematic vignette ─────────────────────────────────────────────
    _paint.shader = RadialGradient(
      radius: 0.95,
      colors: [
        Colors.transparent,
        const Color(0xFF040207).withValues(alpha: 0.88)
      ],
      stops: const [0.52, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), _paint);
    _paint.shader = null;

    canvas.restore();
  }

  void _drawScene(
      Canvas canvas, double w, double h, double horizonY, double t) {
    final scene = _scene;
    if (scene == null) {
      // Painted fallback sky: elemental wash over abyss.
      _paint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF120812),
          portalColor.withValues(alpha: 0.22),
          const Color(0xFF1E0C14),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h), _paint);
      _paint.shader = null;
      return;
    }

    final sway = math.sin(t * 0.18) * 5.0;
    final breathe = 1.0 + 0.012 * math.sin(t * 0.42);
    final imageW = scene.width.toDouble();
    final imageH = scene.height.toDouble();
    final scale = math.max(w / imageW, h / imageH) * breathe;
    final drawW = imageW * scale;
    final drawH = imageH * scale;
    final dst = Rect.fromLTWH(
      (w - drawW) / 2 + sway,
      (h - drawH) / 2 - 20 + math.sin(t * 0.3) * 3,
      drawW,
      drawH,
    );
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, w, h));
    canvas.drawImageRect(
      scene,
      Rect.fromLTWH(0, 0, imageW, imageH),
      dst,
      _paint..filterQuality = FilterQuality.medium,
    );
    canvas.restore();
  }

  void _drawRift(Canvas canvas, double time) {
    final cx = CombatEngine.bossScreenX;
    final cy = CombatEngine.bossScreenY - 12;
    const size = 300.0;
    final rect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: size,
      height: size,
    );

    final shader = _riftShader;
    if (_shaderReady && shader != null) {
      try {
        shader
          ..setFloat(0, size)
          ..setFloat(1, size)
          ..setFloat(2, time)
          ..setFloat(3, portalColor.r)
          ..setFloat(4, portalColor.g)
          ..setFloat(5, portalColor.b)
          ..setFloat(6, 1.0);
        _shaderPaint.shader = shader;
        canvas.save();
        canvas.clipRect(rect);
        canvas.translate(rect.left, rect.top);
        canvas.drawRect(
          Rect.fromLTWH(0, 0, size, size),
          _shaderPaint,
        );
        canvas.restore();
        _shaderPaint.shader = null;
        return;
      } catch (_) {
        _shaderReady = false;
      }
    }

    // Canvas fallback: layered swirl so the arena never looks flat.
    _fillPaint.shader = RadialGradient(
      colors: [
        Colors.white.withValues(alpha: 0.22),
        portalColor.withValues(alpha: 0.30),
        portalColor.withValues(alpha: 0.08),
        Colors.transparent,
      ],
      stops: const [0.0, 0.25, 0.6, 1.0],
    ).createShader(rect);
    canvas.drawCircle(Offset(cx, cy), size * 0.48, _fillPaint);
    _fillPaint.shader = null;

    for (var arm = 0; arm < 3; arm++) {
      final dir = arm.isEven ? 1.0 : -1.0;
      _linePaint
        ..strokeWidth = 2.0
        ..color = portalColor.withValues(alpha: 0.30);
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: 60 + arm * 30),
        time * dir * 0.5 + arm,
        math.pi * 1.1,
        false,
        _linePaint,
      );
    }
  }

  void _drawFogBands(
      Canvas canvas, double w, double h, double horizonY, double t) {
    for (var layer = 0; layer < 3; layer++) {
      final baseY = horizonY + 30 + layer * 82;
      final path = Path()..moveTo(0, baseY);
      for (var x = 0; x <= w; x += 24) {
        path.lineTo(
          x.toDouble(),
          baseY + math.sin(x / 92 + t * (0.55 + layer * 0.22)) * 13 + layer * 5,
        );
      }
      path
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      _fogPaint.color =
          const Color(0xFF8B5CF6).withValues(alpha: 0.045 + layer * 0.012);
      canvas.drawPath(path, _fogPaint);
    }
  }

  void _drawEmbers(Canvas canvas, double w, double h, double t) {
    final count = PerformanceSettings.lowSpecMode ? 8 : 26;
    for (var i = 0; i < count; i++) {
      final seed = i * 0.6180339887;
      final phase = (t * (0.06 + (i % 5) * 0.012) + seed) % 1.0;
      final x = ((i * 97) % 100) / 100 * w + math.sin(t + i) * 12;
      final y = h * (0.92 - phase * 0.85);
      final alpha = math.sin(phase * math.pi) * 0.5;
      _fillPaint.color = Color.lerp(
        portalColor,
        Colors.white,
        (i % 4) / 5,
      )!
          .withValues(alpha: alpha.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), 0.9 + (i % 3) * 0.55, _fillPaint);
    }
  }
}

/// Plane 3 — gothic foreground: carved columns with elemental veins, low mist
/// and a bottom scrim that frames the combat HUD.
class ArenaForeground25D extends PositionComponent {
  ArenaForeground25D(this.combatGame) {
    position = Vector2.zero();
    priority = 3;
  }

  final BrimstoneCombatGame combatGame;

  final Paint _paint = Paint();
  final Paint _linePaint = Paint()..style = PaintingStyle.stroke;
  final Paint _fillPaint = Paint()..style = PaintingStyle.fill;

  Color get _color => switch (combatGame.engine.boss.element) {
        Element.igneous => const Color(0xFFFF5A26),
        Element.abyssal => const Color(0xFF3FD8FF),
        Element.telluric => const Color(0xFFB0703B),
        Element.empty => const Color(0xFFB16EFF),
      };

  @override
  void render(Canvas canvas) {
    final e = combatGame.engine;
    final s = combatGame.viewScale;
    final w = CombatEngine.layoutWidth;
    final h = CombatEngine.layoutHeight;

    canvas.save();
    canvas.translate(combatGame.offsetX, combatGame.offsetY);
    canvas.scale(s);

    // Carved columns framing the arena, with glowing elemental veins.
    _drawColumn(canvas, -6, h, w * 0.16, true, e.time);
    _drawColumn(canvas, w - w * 0.16 + 6, h, w * 0.16, false, e.time);

    // Rising mist over the tray boundary.
    _paint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.transparent,
        _color.withValues(alpha: 0.06),
        const Color(0xFF06030A).withValues(alpha: 0.72),
      ],
      stops: const [0.0, 0.55, 1.0],
    ).createShader(Rect.fromLTWH(0, h * 0.72, w, h * 0.28));
    canvas.drawRect(Rect.fromLTWH(0, h * 0.72, w, h * 0.28), _paint);
    _paint.shader = null;

    canvas.restore();
  }

  void _drawColumn(
    Canvas canvas,
    double x,
    double bottom,
    double width,
    bool left,
    double time,
  ) {
    const top = 46.0;
    final height = bottom - top;

    // Body.
    _paint.shader = LinearGradient(
      begin: left ? Alignment.centerLeft : Alignment.centerRight,
      end: left ? Alignment.centerRight : Alignment.centerLeft,
      colors: [
        const Color(0xFF0A0509),
        const Color(0xFF1A0E18),
        const Color(0xFF0A0509),
      ],
      stops: const [0.0, 0.55, 1.0],
    ).createShader(Rect.fromLTWH(x, top, width, height));
    canvas.drawRect(Rect.fromLTWH(x, top, width, height), _paint);
    _paint.shader = null;

    // Engraved elemental vein.
    final veinX = x + width * (left ? 0.72 : 0.28);
    final pulse = 0.45 + 0.25 * math.sin(time * 1.6 + (left ? 0 : 1.8));
    _linePaint
      ..strokeWidth = 2.4
      ..color = _color.withValues(alpha: pulse);
    final vein = Path()..moveTo(veinX, top + 30);
    for (var y = top + 30.0; y < bottom; y += 34) {
      vein.lineTo(veinX + math.sin(y * 0.11) * 6, y + 34);
    }
    canvas.drawPath(vein, _linePaint);

    // Gothic capital + base mouldings.
    _fillPaint.color = const Color(0xFF241222);
    canvas.drawRect(
        Rect.fromLTWH(x - width * 0.10, top, width * 1.2, 26), _fillPaint);
    canvas.drawRect(
      Rect.fromLTWH(x - width * 0.10, bottom - 34, width * 1.2, 34),
      _fillPaint,
    );
    _linePaint
      ..strokeWidth = 1.2
      ..color = _color.withValues(alpha: 0.28);
    canvas.drawRect(Rect.fromLTWH(x, top + 26, width, height - 60), _linePaint);

    // Skull/rune boss relief at the capital.
    _fillPaint.color = _color.withValues(alpha: 0.35);
    canvas.drawCircle(
      Offset(x + width * 0.5, top + 13),
      width * 0.12,
      _fillPaint,
    );
    for (var i = 0; i < 3; i++) {
      canvas.drawRect(
        Rect.fromLTWH(
          x + width * 0.22 + i * width * 0.22,
          top + 30,
          3,
          14,
        ),
        _fillPaint,
      );
    }
  }
}

/// Trigonometric lerp helpers shared by combat painters.
class CombatMathLerp {
  static double lerp(double a, double b, double t) => a + (b - a) * t;
}

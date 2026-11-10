import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Element;

import '../../core/performance/render_environment.dart';
import '../../domain/value_objects/element.dart';

/// Loads and caches the two GPU fragment programs shipped with the game.
///
/// Every call path is defensive: a missing shader, a platform without runtime
/// effects (widget tests, some low-spec devices) or a compile failure simply
/// leaves the program `null` and the painters fall back to hand-drawn canvas
/// gradients, so gameplay never crashes and the RAM profile stays flat.
class BrimstoneShaders {
  const BrimstoneShaders._();

  static const String riftAsset = 'shaders/abyssal_rift.frag';
  static const String foilAsset = 'shaders/foil_card.frag';
  static const String shockwaveAsset = 'shaders/shockwave_break.frag';
  static const String plasmaAsset = 'shaders/orb_plasma.frag';

  static ui.FragmentProgram? _rift;
  static ui.FragmentProgram? _foil;
  static ui.FragmentProgram? _shockwave;
  static ui.FragmentProgram? _plasma;
  static bool _warming = false;
  static bool _warmed = false;

  static bool get riftAvailable => _rift != null;
  static bool get foilAvailable => _foil != null;
  static bool get shockwaveAvailable => _shockwave != null;
  static bool get plasmaAvailable => _plasma != null;

  /// Preloads every program once (called from `main()` after the first frame).
  static Future<void> warmUp() async {
    if (_warmed || _warming || isWidgetTestEnvironment) return;
    _warming = true;
    try {
      final loaded = await Future.wait<ui.FragmentProgram?>([
        _load(riftAsset),
        _load(foilAsset),
        _load(shockwaveAsset),
        _load(plasmaAsset),
      ]);
      _rift = loaded[0];
      _foil = loaded[1];
      _shockwave = loaded[2];
      _plasma = loaded[3];
    } finally {
      _warming = false;
      _warmed = true;
    }
  }

  static Future<ui.FragmentProgram?> _load(String asset) async {
    try {
      return await ui.FragmentProgram.fromAsset(asset)
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      return null;
    }
  }

  /// Fresh shader instance bound to the rift program, or `null`.
  static ui.FragmentShader? newRiftShader() {
    try {
      return _rift?.fragmentShader();
    } catch (_) {
      return null;
    }
  }

  /// Fresh shader instance bound to the foil program, or `null`.
  static ui.FragmentShader? newFoilShader() {
    try {
      return _foil?.fragmentShader();
    } catch (_) {
      return null;
    }
  }

  /// Fresh shader instance bound to the break shockwave program, or `null`.
  static ui.FragmentShader? newShockwaveShader() {
    try {
      return _shockwave?.fragmentShader();
    } catch (_) {
      return null;
    }
  }

  /// Fresh shader instance bound to the orb plasma program, or `null`.
  static ui.FragmentShader? newPlasmaShader() {
    try {
      return _plasma?.fragmentShader();
    } catch (_) {
      return null;
    }
  }
}

/// Elemental hue used by the rift and foil effects.
Color riftColorFor(Element element) => switch (element) {
      Element.igneous => const Color(0xFFFF5A26),
      Element.abyssal => const Color(0xFF3FD8FF),
      Element.telluric => const Color(0xFFB0703B),
      Element.empty => const Color(0xFFB16EFF),
    };

/// A living dimensional rift rendered on the GPU, with a hand-drawn fallback.
///
/// The widget owns a single repeating controller (20 s loop) and repaints a
/// single `CustomPaint`; the shader instance is created once and only its
/// uniforms are rewritten, so steady-state allocation is zero.
class AbyssalRiftView extends StatefulWidget {
  const AbyssalRiftView({
    super.key,
    required this.color,
    this.intensity = 1.0,
    this.animate = true,
    this.fallbackBlur = 0.0,
  });

  final Color color;
  final double intensity;

  /// When false (tests / reduced motion) the effect renders a static frame.
  final bool animate;
  final double fallbackBlur;

  @override
  State<AbyssalRiftView> createState() => _AbyssalRiftViewState();
}

class _AbyssalRiftViewState extends State<AbyssalRiftView>
    with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;
  ui.FragmentShader? _shader;
  Size _lastSize = Size.zero;

  bool get _canAnimate => widget.animate && !isWidgetTestEnvironment;

  @override
  void initState() {
    super.initState();
    _shader = BrimstoneShaders.newRiftShader();
    if (_canAnimate) {
      _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 20),
      )..repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Program may have finished loading after mount (first frame warm-up).
    _shader ??= BrimstoneShaders.newRiftShader();
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _ctrl;
    if (controller == null) {
      return CustomPaint(
        painter: _RiftPainter(
          color: widget.color,
          intensity: widget.intensity,
          seconds: 3.4,
          shader: _shader,
          size: _lastSize,
        ),
        child: const SizedBox.expand(),
      );
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) {
          _lastSize = constraints.biggest;
          return CustomPaint(
            painter: _RiftPainter(
              color: widget.color,
              intensity: widget.intensity,
              seconds: controller.value * 20.0,
              shader: _shader,
              size: _lastSize,
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class _RiftPainter extends CustomPainter {
  _RiftPainter({
    required this.color,
    required this.intensity,
    required this.seconds,
    required this.shader,
    required this.size,
  });

  final Color color;
  final double intensity;
  final double seconds;
  final ui.FragmentShader? shader;
  final Size size;

  final Paint _paint = Paint();

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final rect = Offset.zero & canvasSize;
    final shader = this.shader;
    if (shader != null) {
      try {
        shader
          ..setFloat(0, canvasSize.width)
          ..setFloat(1, canvasSize.height)
          ..setFloat(2, seconds)
          ..setFloat(3, color.r)
          ..setFloat(4, color.g)
          ..setFloat(5, color.b)
          ..setFloat(6, intensity.clamp(0.0, 1.5));
        _paint
          ..shader = shader
          ..blendMode = BlendMode.plus;
        canvas.drawRect(rect, _paint);
        _paint.blendMode = BlendMode.srcOver;
        return;
      } catch (_) {
        _paint.shader = null;
      }
    }
    _paintFallback(canvas, canvasSize);
  }

  void _paintFallback(Canvas canvas, Size canvasSize) {
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final radius = math.min(canvasSize.width, canvasSize.height) / 2;

    _paint
      ..blendMode = BlendMode.plus
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.55 * intensity),
          color.withValues(alpha: 0.55 * intensity),
          color.withValues(alpha: 0.16 * intensity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.22, 0.62, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, _paint);

    // Twin counter-rotating spiral ribbons.
    for (var arm = 0; arm < 2; arm++) {
      final dir = arm == 0 ? 1.0 : -1.0;
      final ribbon = Path();
      for (var i = 0; i <= 44; i++) {
        final t = i / 44.0;
        final r = radius * (0.10 + t * 0.92);
        final a = dir * (t * math.pi * 3.4) + seconds * (0.55 * dir);
        final p = Offset(
          center.dx + math.cos(a) * r,
          center.dy + math.sin(a) * r,
        );
        if (i == 0) {
          ribbon.moveTo(p.dx, p.dy);
        } else {
          ribbon.lineTo(p.dx, p.dy);
        }
      }
      _paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..shader = SweepGradient(
          colors: [
            color.withValues(alpha: 0.0),
            color.withValues(alpha: 0.55 * intensity),
            Colors.white.withValues(alpha: 0.7 * intensity),
            color.withValues(alpha: 0.0),
          ],
          transform: GradientRotation(seconds * 0.5),
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawPath(ribbon, _paint);
    }

    // Runic shockwave rings.
    _paint.shader = null;
    for (var i = 0; i < 3; i++) {
      final phase = (seconds * 0.28 + i / 3.0) % 1.0;
      final rr = radius * (0.14 + phase * 0.82);
      _paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 + (1.0 - phase) * 2.0
        ..color = color.withValues(alpha: (1.0 - phase) * 0.45 * intensity);
      canvas.drawCircle(center, rr, _paint);
    }

    // Hot core.
    _paint
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.85 * intensity),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(center: center, radius: radius * 0.30),
      );
    canvas.drawCircle(center, radius * 0.30, _paint);
    _paint
      ..shader = null
      ..blendMode = BlendMode.srcOver
      ..style = PaintingStyle.fill;
  }

  @override
  bool shouldRepaint(covariant _RiftPainter oldDelegate) =>
      oldDelegate.seconds != seconds ||
      oldDelegate.color != color ||
      oldDelegate.intensity != intensity;
}

/// Holographic collectible foiling for 3★/4★ cards.
///
/// Uses `shaders/foil_card.frag` when the GPU program is available and an
/// animated diagonal sheen (pure canvas gradient) otherwise. Never animates in
/// tests so `pumpAndSettle` stays stable.
class FoilSheen extends StatefulWidget {
  const FoilSheen({
    super.key,
    required this.tint,
    this.intensity = 0.4,
    this.animate = true,
    this.borderRadius = 10,
  });

  final Color tint;
  final double intensity;
  final bool animate;
  final double borderRadius;

  @override
  State<FoilSheen> createState() => _FoilSheenState();
}

class _FoilSheenState extends State<FoilSheen>
    with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;
  ui.FragmentShader? _shader;

  bool get _canAnimate => widget.animate && !isWidgetTestEnvironment;

  @override
  void initState() {
    super.initState();
    _shader = BrimstoneShaders.newFoilShader();
    if (_canAnimate) {
      _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 8),
      )..repeat();
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _ctrl;
    final painter = _FoilPainter(
      tint: widget.tint,
      intensity: widget.intensity,
      seconds: controller == null ? 1.7 : controller.value * 8.0,
      shader: _shader,
    );
    return IgnorePointer(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: controller == null
            ? CustomPaint(painter: painter, child: const SizedBox.expand())
            : AnimatedBuilder(
                animation: controller,
                builder: (context, _) => CustomPaint(
                  painter: _FoilPainter(
                    tint: widget.tint,
                    intensity: widget.intensity,
                    seconds: controller.value * 8.0,
                    shader: _shader,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
      ),
    );
  }
}

class _FoilPainter extends CustomPainter {
  _FoilPainter({
    required this.tint,
    required this.intensity,
    required this.seconds,
    required this.shader,
  });

  final Color tint;
  final double intensity;
  final double seconds;
  final ui.FragmentShader? shader;

  final Paint _paint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shader = this.shader;
    if (shader != null) {
      try {
        shader
          ..setFloat(0, size.width)
          ..setFloat(1, size.height)
          ..setFloat(2, seconds)
          ..setFloat(3, tint.r)
          ..setFloat(4, tint.g)
          ..setFloat(5, tint.b)
          ..setFloat(6, intensity.clamp(0.0, 1.0));
        _paint
          ..shader = shader
          ..blendMode = BlendMode.plus;
        canvas.drawRect(rect, _paint);
        _paint.blendMode = BlendMode.srcOver;
        return;
      } catch (_) {
        _paint.shader = null;
      }
    }

    // Canvas fallback: travelling diagonal specular band + prismatic edge.
    final phase = (seconds * 0.22) % 1.0;
    _paint
      ..blendMode = BlendMode.plus
      ..shader = LinearGradient(
        begin: Alignment(-1.6 + phase * 3.2, -1.0),
        end: Alignment(-0.6 + phase * 3.2, 1.0),
        colors: [
          Colors.transparent,
          tint.withValues(alpha: 0.10 * intensity),
          Colors.white.withValues(alpha: 0.30 * intensity),
          const Color(0xFFB16EFF).withValues(alpha: 0.16 * intensity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.38, 0.52, 0.66, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, _paint);

    // Prismatic rim shimmer along the bezel.
    _paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = tint.withValues(alpha: 0.55 * intensity);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(0.8), const Radius.circular(10)),
      _paint,
    );
    _paint
      ..blendMode = BlendMode.srcOver
      ..style = PaintingStyle.fill
      ..shader = null;
  }

  @override
  bool shouldRepaint(covariant _FoilPainter oldDelegate) =>
      oldDelegate.seconds != seconds ||
      oldDelegate.tint != tint ||
      oldDelegate.intensity != intensity;
}

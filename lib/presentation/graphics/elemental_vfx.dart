import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Element;

import '../../core/performance/render_environment.dart';
import '../../core/theme/design_tokens.dart';
import '../../domain/value_objects/element.dart';
import 'art_registry.dart';
import 'rift_effect.dart';

/// Palette helpers shared by every elemental effect.
Color elementColor(Element element) => switch (element) {
      Element.igneous => const Color(0xFFFF5A26),
      Element.abyssal => const Color(0xFF3FD8FF),
      Element.telluric => const Color(0xFFB0703B),
      Element.empty => const Color(0xFFB16EFF),
    };

Color elementGlow(Element element) => switch (element) {
      Element.igneous => const Color(0xFFFFD980),
      Element.abyssal => const Color(0xFFB8F0FF),
      Element.telluric => const Color(0xFFF0D0A0),
      Element.empty => const Color(0xFFE5D4FF),
    };

// ───────────────────────────────────────────────────────────── plasma orb

/// Living elemental plasma sphere rendered on the GPU (`orb_plasma.frag`) with
/// a hand-painted canvas fallback for tests, low-spec mode and devices without
/// runtime effects. Purely decorative: it never swallows pointer events.
class PlasmaOrb extends StatefulWidget {
  const PlasmaOrb({
    super.key,
    required this.color,
    this.glow,
    this.intensity = 1.0,
    this.animate = true,
    this.secondsPerTurn = 6.0,
  });

  final Color color;
  final Color? glow;
  final double intensity;
  final bool animate;
  final double secondsPerTurn;

  @override
  State<PlasmaOrb> createState() => _PlasmaOrbState();
}

class _PlasmaOrbState extends State<PlasmaOrb>
    with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;
  ui.FragmentShader? _shader;

  bool get _canAnimate => widget.animate && !isWidgetTestEnvironment;

  @override
  void initState() {
    super.initState();
    _shader = BrimstoneShaders.newPlasmaShader();
    if (_canAnimate) {
      _ctrl = AnimationController(
        vsync: this,
        duration: Duration(
          milliseconds: (widget.secondsPerTurn * 1000).round(),
        ),
      )..repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _shader ??= BrimstoneShaders.newPlasmaShader();
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
      return IgnorePointer(
        child: CustomPaint(
          painter: _PlasmaPainter(
            color: widget.color,
            glow: widget.glow ?? Colors.white,
            intensity: widget.intensity,
            seconds: 1.3,
            shader: _shader,
          ),
          child: const SizedBox.expand(),
        ),
      );
    }
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => CustomPaint(
          painter: _PlasmaPainter(
            color: widget.color,
            glow: widget.glow ?? Colors.white,
            intensity: widget.intensity,
            seconds: controller.value * widget.secondsPerTurn,
            shader: _shader,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _PlasmaPainter extends CustomPainter {
  _PlasmaPainter({
    required this.color,
    required this.glow,
    required this.intensity,
    required this.seconds,
    required this.shader,
  });

  final Color color;
  final Color glow;
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
          ..setFloat(3, color.r)
          ..setFloat(4, color.g)
          ..setFloat(5, color.b)
          ..setFloat(6, intensity.clamp(0.0, 1.6));
        _paint
          ..shader = shader
          ..blendMode = BlendMode.plus;
        canvas.drawRect(rect, _paint);
        _paint
          ..blendMode = BlendMode.srcOver
          ..shader = null;
        return;
      } catch (_) {
        _paint.shader = null;
      }
    }
    _fallback(canvas, size);
  }

  void _fallback(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2;
    _paint
      ..blendMode = BlendMode.plus
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.85),
          glow.withValues(alpha: 0.55),
          color.withValues(alpha: 0.55 * intensity),
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.28, 0.68, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, _paint);

    // Rotating plasma filaments.
    for (var arm = 0; arm < 5; arm++) {
      final phase = seconds * 0.9 + arm * (math.pi * 2 / 5);
      final path = Path();
      for (var i = 0; i <= 26; i++) {
        final f = i / 26.0;
        final rr = radius * (0.16 + f * 0.78);
        final a = phase + f * math.pi * 1.5;
        final p = Offset(
          center.dx + math.cos(a) * rr,
          center.dy + math.sin(a) * rr * 0.92,
        );
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      _paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..shader = null
        ..color = glow.withValues(alpha: 0.30 * intensity);
      canvas.drawPath(path, _paint);
    }
    _paint
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.srcOver;
  }

  @override
  bool shouldRepaint(covariant _PlasmaPainter old) =>
      old.seconds != seconds ||
      old.color != color ||
      old.intensity != intensity ||
      old.shader != shader;
}

// ─────────────────────────────────────────────────────── break shockwave

/// A 0.6 s expanding shockwave with chromatic aberration and electric arcs.
///
/// Bump [token] to fire it again. Falls back to canvas arcs when the GPU
/// program is missing; in tests it renders a single static frame.
class BreakShockwave extends StatefulWidget {
  const BreakShockwave({
    super.key,
    required this.token,
    this.color = const Color(0xFFFFD700),
    this.intensity = 1.2,
    this.onCompleted,
  });

  final int token;
  final Color color;
  final double intensity;
  final VoidCallback? onCompleted;

  static const Duration duration = Duration(milliseconds: 600);

  @override
  State<BreakShockwave> createState() => _BreakShockwaveState();
}

class _BreakShockwaveState extends State<BreakShockwave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: BreakShockwave.duration,
  );
  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _shader = BrimstoneShaders.newShockwaveShader();
    if (widget.token > 0) _ctrl.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant BreakShockwave oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.token != oldWidget.token && widget.token > 0) {
      _ctrl.forward(from: 0).then((_) {
        if (mounted) widget.onCompleted?.call();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          if (_ctrl.value == 0) return const SizedBox.shrink();
          return CustomPaint(
            painter: _ShockwavePainter(
              progress: Curves.easeOutCubic.transform(_ctrl.value),
              color: widget.color,
              intensity: widget.intensity,
              shader: _shader,
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class _ShockwavePainter extends CustomPainter {
  _ShockwavePainter({
    required this.progress,
    required this.color,
    required this.intensity,
    required this.shader,
  });

  final double progress;
  final Color color;
  final double intensity;
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
          ..setFloat(2, progress)
          ..setFloat(3, color.r)
          ..setFloat(4, color.g)
          ..setFloat(5, color.b)
          ..setFloat(6, intensity);
        _paint
          ..shader = shader
          ..blendMode = BlendMode.plus;
        canvas.drawRect(rect, _paint);
        _paint
          ..blendMode = BlendMode.srcOver
          ..shader = null;
        return;
      } catch (_) {
        _paint.shader = null;
      }
    }
    _fallback(canvas, size);
  }

  void _fallback(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxR = math.min(size.width, size.height) * 0.55;
    final r = maxR * (0.05 + progress * 0.95);
    final fade = (1 - progress).clamp(0.0, 1.0);
    _paint
      ..blendMode = BlendMode.plus
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 + 8.0 * fade;
    final random = math.Random(19);
    for (var i = 0; i < 3; i++) {
      _paint.color = [
        color,
        const Color(0xFFFF3B6B),
        const Color(0xFF3FD8FF),
      ][i]
          .withValues(alpha: 0.55 * fade * intensity);
      canvas.drawCircle(center, r + i * 4.0, _paint);
    }
    // Electric filaments.
    for (var i = 0; i < 14; i++) {
      final a = random.nextDouble() * math.pi * 2;
      final p0 = Offset(
        center.dx + math.cos(a) * (r - 6),
        center.dy + math.sin(a) * (r - 6),
      );
      final p1 = Offset(
        center.dx + math.cos(a) * (r + 14),
        center.dy + math.sin(a) * (r + 14),
      );
      _paint
        ..strokeWidth = 1.1
        ..color = Colors.white.withValues(alpha: 0.5 * fade);
      canvas.drawLine(p0, p1, _paint);
    }
    _paint
      ..blendMode = BlendMode.srcOver
      ..style = PaintingStyle.fill;
  }

  @override
  bool shouldRepaint(covariant _ShockwavePainter old) =>
      old.progress != progress || old.color != color;
}

// ──────────────────────────────────────────────────── elemental barrage

/// 0.7 s elemental impact that lands on the boss while the hero cut-in runs.
///
/// * Igneous — five burning meteors on a diagonal, leaving ember craters.
/// * Abyssal — cyan crystal lances erupting and shattering on the targets.
/// * Telluric — monolith pillars with golden seismic rings.
/// * Empty   — an X-shaped dimensional slash followed by a gravity implosion.
class ElementalBarrage extends StatefulWidget {
  const ElementalBarrage({
    super.key,
    required this.token,
    required this.element,
    this.onCompleted,
  });

  final int token;
  final Element element;
  final VoidCallback? onCompleted;

  static const Duration duration = Duration(milliseconds: 700);

  @override
  State<ElementalBarrage> createState() => _ElementalBarrageState();
}

class _ElementalBarrageState extends State<ElementalBarrage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: ElementalBarrage.duration,
  );

  @override
  void initState() {
    super.initState();
    if (widget.token > 0) _ctrl.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant ElementalBarrage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.token != oldWidget.token && widget.token > 0) {
      _ctrl.forward(from: 0).then((_) {
        if (mounted) widget.onCompleted?.call();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          if (_ctrl.value == 0) return const SizedBox.shrink();
          return CustomPaint(
            painter: ElementalBarragePainter(
              element: widget.element,
              progress: _ctrl.value,
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

/// Public painter (reused by tests and by the cut-in).
class ElementalBarragePainter extends CustomPainter {
  ElementalBarragePainter({required this.element, required this.progress});

  final Element element;
  final double progress;

  final Paint _paint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final t = progress.clamp(0.0, 1.0);
    switch (element) {
      case Element.igneous:
        _igneous(canvas, size, t);
      case Element.abyssal:
        _abyssal(canvas, size, t);
      case Element.telluric:
        _telluric(canvas, size, t);
      case Element.empty:
        _void(canvas, size, t);
    }
  }

  void _igneous(Canvas canvas, Size size, double t) {
    final color = elementColor(Element.igneous);
    final glow = elementGlow(Element.igneous);
    for (var i = 0; i < 5; i++) {
      final delay = i * 0.09;
      final local = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final start = Offset(
        size.width * (0.18 + i * 0.16),
        -size.height * 0.10,
      );
      final end = Offset(
        size.width * (0.30 + i * 0.11),
        size.height * (0.55 + (i.isEven ? 0.0 : 0.12)),
      );
      final p = Offset.lerp(start, end, Curves.easeInCubic.transform(local))!;
      final trail = Offset.lerp(start, p, 0.72)!;
      _paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7 * (1 - local * 0.4)
        ..strokeCap = StrokeCap.round
        ..shader = ui.Gradient.linear(
          trail,
          p,
          [
            color.withValues(alpha: 0.0),
            color.withValues(alpha: 0.7),
            Colors.white.withValues(alpha: 0.9),
          ],
          const [0.0, 0.55, 1.0],
        );
      canvas.drawLine(trail, p, _paint);
      _paint
        ..style = PaintingStyle.fill
        ..shader = RadialGradient(
          colors: [Colors.white, glow, color.withValues(alpha: 0.0)],
        ).createShader(Rect.fromCircle(center: p, radius: 18));
      canvas.drawCircle(p, 18, _paint);
      // Ember crater.
      if (local > 0.75) {
        final crater = ((local - 0.75) / 0.25).clamp(0.0, 1.0);
        _paint
          ..shader = null
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withValues(alpha: 0.55 * (1 - crater));
        canvas.drawOval(
          Rect.fromCenter(
            center: end,
            width: 70 + crater * 50,
            height: 22 + crater * 16,
          ),
          _paint,
        );
      }
    }
    _paint
      ..shader = null
      ..style = PaintingStyle.fill;
  }

  void _abyssal(Canvas canvas, Size size, double t) {
    final color = elementColor(Element.abyssal);
    final glow = elementGlow(Element.abyssal);
    for (var i = 0; i < 6; i++) {
      final x = size.width * (0.16 + i * 0.136);
      final delay = i * 0.06;
      final local = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final rise = Curves.easeOutCubic.transform(local);
      final baseY = size.height * 0.92;
      final height = size.height * (0.32 + (i % 3) * 0.11) * rise;
      final width = 9.0 + (i % 2) * 4;
      final path = Path()
        ..moveTo(x - width, baseY)
        ..lineTo(x - width * 0.35, baseY - height * 0.72)
        ..lineTo(x, baseY - height)
        ..lineTo(x + width * 0.35, baseY - height * 0.72)
        ..lineTo(x + width, baseY);
      _paint
        ..style = PaintingStyle.fill
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.9),
            glow.withValues(alpha: 0.85),
            color.withValues(alpha: 0.55),
          ],
        ).createShader(
            Rect.fromLTRB(x - width, baseY - height, x + width, baseY));
      canvas.drawPath(path, _paint);
      // Shatter sparks at the apex.
      if (local > 0.55) {
        final burst = ((local - 0.55) / 0.45).clamp(0.0, 1.0);
        final random = math.Random(i * 31 + 7);
        for (var s = 0; s < 7; s++) {
          final a = random.nextDouble() * math.pi * 2;
          final d = 6 + burst * (18 + random.nextDouble() * 26);
          final sp = Offset(
            x + math.cos(a) * d,
            baseY - height + math.sin(a) * d,
          );
          _paint
            ..shader = null
            ..color = glow.withValues(alpha: 0.8 * (1 - burst));
          canvas.drawCircle(sp, 1.8, _paint);
        }
      }
    }
    _paint
      ..shader = null
      ..style = PaintingStyle.fill;
  }

  void _telluric(Canvas canvas, Size size, double t) {
    final color = elementColor(Element.telluric);
    final glow = elementGlow(Element.telluric);
    // Seismic rings from the ground.
    final ring = Curves.easeOut.transform(t);
    _paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0 * (1 - ring * 0.6)
      ..color = glow.withValues(alpha: 0.55 * (1 - ring));
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.9),
        width: size.width * (0.25 + ring * 1.15),
        height: size.height * (0.06 + ring * 0.26),
      ),
      _paint,
    );
    for (var i = 0; i < 4; i++) {
      final x = size.width * (0.26 + i * 0.16);
      final delay = i * 0.07;
      final local = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final rise = Curves.easeOutCubic.transform(local);
      final height = size.height * (0.34 + (i % 2) * 0.16) * rise;
      final width = 26.0 + (i % 2) * 10;
      final rect = Rect.fromLTRB(
        x - width / 2,
        size.height * 0.9 - height,
        x + width / 2,
        size.height * 0.9,
      );
      _paint
        ..style = PaintingStyle.fill
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.95),
            const Color(0xFF3A2418),
            const Color(0xFF120A08),
          ],
        ).createShader(rect);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        _paint,
      );
      // Molten cracks.
      _paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = glow.withValues(alpha: 0.85 * local);
      final crack = Path()
        ..moveTo(x - width * 0.2, rect.bottom - 6)
        ..lineTo(x + width * 0.1, rect.bottom - height * 0.45)
        ..lineTo(x - width * 0.05, rect.top + 6);
      canvas.drawPath(crack, _paint);
    }
    _paint
      ..shader = null
      ..style = PaintingStyle.fill;
  }

  void _void(Canvas canvas, Size size, double t) {
    final color = elementColor(Element.empty);
    final glow = elementGlow(Element.empty);
    final slash = Curves.easeInOutCubic.transform(t.clamp(0.0, 0.62) / 0.62);
    final center = size.center(Offset.zero);
    final len = size.longestSide * 0.62 * slash;

    for (final dir in [1.0, -1.0]) {
      final p0 = Offset(center.dx - len * dir, center.dy - len);
      final p1 = Offset(center.dx + len * dir, center.dy + len);
      _paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14 * (1 - slash * 0.55)
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [
            color.withValues(alpha: 0.0),
            color.withValues(alpha: 0.85),
            Colors.white,
            color.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.35, 0.6, 1.0],
        ).createShader(Rect.fromPoints(p0, p1));
      canvas.drawLine(p0, p1, _paint);
      _paint
        ..strokeWidth = 2.4
        ..color = glow.withValues(alpha: 0.9);
      canvas.drawLine(p0, p1, _paint);
    }

    // Gravitational implosion after the slash.
    if (t > 0.62) {
      final implosion = ((t - 0.62) / 0.38).clamp(0.0, 1.0);
      final radius = size.shortestSide * 0.30 * (1 - implosion);
      _paint
        ..style = PaintingStyle.fill
        ..shader = RadialGradient(
          colors: [
            Colors.black,
            color.withValues(alpha: 0.75 * implosion),
            color.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(
          Rect.fromCircle(center: center, radius: radius + 4),
        );
      canvas.drawCircle(center, radius + 4, _paint);
      _paint
        ..shader = null
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = glow.withValues(alpha: 0.8 * (1 - implosion));
      canvas.drawCircle(center, radius + 18 * implosion, _paint);
    }
    _paint
      ..shader = null
      ..style = PaintingStyle.fill;
  }

  @override
  bool shouldRepaint(covariant ElementalBarragePainter old) =>
      old.progress != progress || old.element != element;
}

// ────────────────────────────────────────────────────── boss shatter

/// 0.65 s boss death: white flash, light cracks bursting from the portrait,
/// the silhouette dissolving into rising embers and the gilded
/// "¡SELLO PURIFICADO!" banner.
class BossShatterOverlay extends StatefulWidget {
  const BossShatterOverlay({
    super.key,
    required this.token,
    required this.portraitId,
    required this.element,
    this.onCompleted,
  });

  final int token;
  final String portraitId;
  final Element element;
  final VoidCallback? onCompleted;

  static const Duration duration = Duration(milliseconds: 650);

  @override
  State<BossShatterOverlay> createState() => _BossShatterOverlayState();
}

class _BossShatterOverlayState extends State<BossShatterOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: BossShatterOverlay.duration,
  );

  @override
  void initState() {
    super.initState();
    if (widget.token > 0) _ctrl.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant BossShatterOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.token != oldWidget.token && widget.token > 0) {
      _ctrl.forward(from: 0).then((_) {
        if (mounted) widget.onCompleted?.call();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final t = _ctrl.value;
          if (t == 0) return const SizedBox.shrink();
          final flash = (1 - (t / 0.18).clamp(0.0, 1.0)).clamp(0.0, 1.0);
          final banner = ((t - 0.22) / 0.30).clamp(0.0, 1.0);
          return Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _ShatterPainter(
                  progress: t,
                  element: widget.element,
                  portraitAsset: ArtRegistry.portrait(widget.portraitId),
                ),
              ),
              if (flash > 0)
                ColoredBox(
                  color: Colors.white.withValues(alpha: 0.85 * flash),
                ),
              if (banner > 0)
                Align(
                  alignment: const Alignment(0, -0.05),
                  child: Opacity(
                    opacity: Curves.easeOut.transform(banner),
                    child: Transform.scale(
                      scale: 0.86 + 0.14 * Curves.easeOutBack.transform(banner),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 26,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF3A2408), Color(0xFF120A04)],
                          ),
                          border: Border.all(
                            color: BrimstoneTokens.goldPrimary,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: BrimstoneTokens.goldPrimary
                                  .withValues(alpha: 0.45),
                              blurRadius: 22,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: Text(
                          '¡SELLO PURIFICADO!',
                          style: BrimstoneFonts.cinzel(
                            size: 20,
                            weight: FontWeight.w900,
                            color: BrimstoneTokens.goldPrimary,
                            letterSpacing: 2.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ShatterPainter extends CustomPainter {
  _ShatterPainter({
    required this.progress,
    required this.element,
    required this.portraitAsset,
  });

  final double progress;
  final Element element;
  final String portraitAsset;

  final Paint _paint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final color = elementGlow(element);
    final flash = (1 - (progress / 0.20).clamp(0.0, 1.0));

    // Cracks bursting out of the boss portrait.
    final crackProgress = Curves.easeOut.transform(
      (progress / 0.55).clamp(0.0, 1.0),
    );
    final random = math.Random(5);
    for (var i = 0; i < 12; i++) {
      final angle = random.nextDouble() * math.pi * 2;
      final length = size.shortestSide * (0.14 + random.nextDouble() * 0.34);
      final tip = Offset(
        center.dx + math.cos(angle) * length * crackProgress,
        center.dy + math.sin(angle) * length * crackProgress,
      );
      final mid = Offset(
        center.dx + math.cos(angle + 0.18) * length * 0.55 * crackProgress,
        center.dy + math.sin(angle + 0.18) * length * 0.55 * crackProgress,
      );
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(mid.dx, mid.dy)
        ..lineTo(tip.dx, tip.dy);
      _paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6 * (0.4 + flash)
        ..shader = ui.Gradient.linear(
          center,
          tip,
          [
            Colors.white.withValues(alpha: 0.95),
            color.withValues(alpha: 0.0),
          ],
        );
      canvas.drawPath(path, _paint);
    }

    // Rising embers: the silhouette dissolving into particles.
    final rise = Curves.easeOutCubic.transform(progress);
    for (var i = 0; i < 26; i++) {
      final spread = random.nextDouble() - 0.5;
      final startY = center.dy + random.nextDouble() * size.height * 0.16;
      final x = center.dx + spread * size.width * 0.5;
      final y =
          startY - rise * size.height * (0.22 + random.nextDouble() * 0.4);
      final fade = (1 - progress * 1.05).clamp(0.0, 1.0);
      _paint
        ..style = PaintingStyle.fill
        ..color = color.withValues(alpha: 0.75 * fade)
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.9 * fade),
            Colors.transparent
          ],
        ).createShader(Rect.fromCircle(center: Offset(x, y), radius: 5));
      canvas.drawCircle(Offset(x, y), 5 * (0.4 + fade * 0.8), _paint);
    }
    _paint
      ..shader = null
      ..style = PaintingStyle.fill;

    // Portrait burns away.
    if (progress < 0.6) {
      final burn = (1 - progress / 0.6).clamp(0.0, 1.0);
      _paint
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.5 * burn),
            color.withValues(alpha: 0.35 * burn),
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromCircle(
            center: center,
            radius: size.shortestSide * (0.18 + progress * 0.25),
          ),
        );
      canvas.drawCircle(
        center,
        size.shortestSide * (0.18 + progress * 0.25),
        _paint,
      );
      _paint
        ..blendMode = BlendMode.srcOver
        ..shader = null;
    }
  }

  @override
  bool shouldRepaint(covariant _ShatterPainter old) =>
      old.progress != progress ||
      old.element != element ||
      old.portraitAsset != portraitAsset;
}

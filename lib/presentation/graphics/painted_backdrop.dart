import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/performance/render_environment.dart';

/// Cinematic painted backdrop shared by every meta screen.
///
/// Layering (back to front):
///   1. Painted panoramic illustration (`assets/backgrounds/*.webp`) cover-fit.
///   2. Volumetric grade: elemental wash + crushing dark gradient.
///   3. Optional low fog band and rising embers/ash (elemental flavour).
///   4. Vignette that melts the art into the UI chrome.
///
/// Embers animate only outside widget tests, so `pumpAndSettle` never hangs.
class PaintedBackdrop extends StatelessWidget {
  const PaintedBackdrop({
    super.key,
    required this.asset,
    required this.tint,
    this.darkness = 0.72,
    this.embers = true,
    this.fog = true,
    this.alignment = Alignment.center,
    this.child,
  });

  final String asset;
  final Color tint;

  /// 0 = untouched art, 1 = almost black.
  final double darkness;
  final bool embers;
  final bool fog;
  final Alignment alignment;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          asset,
          fit: BoxFit.cover,
          alignment: alignment,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => ColoredBox(
            color: Color.lerp(const Color(0xFF0C0608), tint, 0.12)!,
          ),
        ),
        // Elemental wash: ties the photograph to the chapter palette.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(const Color(0xFF0A0407), tint, 0.18)!
                    .withValues(alpha: 0.55),
                Colors.transparent,
                Color.lerp(const Color(0xFF0A0407), tint, 0.10)!
                    .withValues(alpha: 0.35),
              ],
            ),
          ),
        ),
        // Crushing darkness so the glass panels always stay legible.
        ColoredBox(color: Colors.black.withValues(alpha: darkness)),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF0A0407).withValues(alpha: 0.55),
                Colors.transparent,
                const Color(0xFF07030A).withValues(alpha: 0.86),
              ],
              stops: const [0.0, 0.42, 1.0],
            ),
          ),
        ),
        if (fog) const Positioned.fill(child: _FogVeil()),
        if (embers)
          Positioned.fill(child: _Embers(tint: tint, seed: asset.hashCode)),
        const Positioned.fill(child: _Vignette()),
        if (child != null) child!,
      ],
    );
  }
}

class _Vignette extends StatelessWidget {
  const _Vignette();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          radius: 1.05,
          colors: [Colors.transparent, Color(0xCC05030A)],
          stops: [0.45, 1.0],
        ),
      ),
    );
  }
}

class _FogVeil extends StatelessWidget {
  const _FogVeil();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: FractionallySizedBox(
        heightFactor: 0.42,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF8B5CF6).withValues(alpha: 0.0),
                const Color(0xFF8B5CF6).withValues(alpha: 0.07),
                const Color(0xFF06030A).withValues(alpha: 0.45),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Embers extends StatefulWidget {
  const _Embers({required this.tint, required this.seed});

  final Color tint;
  final int seed;

  @override
  State<_Embers> createState() => _EmbersState();
}

class _EmbersState extends State<_Embers> with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;

  @override
  void initState() {
    super.initState();
    if (!isWidgetTestEnvironment) {
      _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 14),
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
    final painter = _EmberPainter(
      tint: widget.tint,
      seed: widget.seed,
      progress: _ctrl == null ? 0.35 : _ctrl!.value,
    );
    final controller = _ctrl;
    if (controller == null) {
      return CustomPaint(painter: painter, child: const SizedBox.expand());
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => CustomPaint(
        painter: _EmberPainter(
          tint: widget.tint,
          seed: widget.seed,
          progress: controller.value,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _EmberPainter extends CustomPainter {
  _EmberPainter({
    required this.tint,
    required this.seed,
    required this.progress,
  });

  final Color tint;
  final int seed;
  final double progress;

  final Paint _paint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed);
    final count = 34;
    for (var i = 0; i < count; i++) {
      final baseX = rng.nextDouble() * size.width;
      final phase = rng.nextDouble();
      final speed = 0.35 + rng.nextDouble() * 0.65;
      final drift = math.sin((progress + phase) * math.pi * 2) * 14;
      final t = (progress * speed + phase) % 1.0;
      final y = size.height * (1.05 - t * 1.15);
      final x = baseX + drift;
      final radius = 0.8 + rng.nextDouble() * 2.0;
      final alpha = (math.sin(t * math.pi) * 0.55).clamp(0.0, 1.0);
      _paint
        ..color = Color.lerp(tint, Colors.white, rng.nextDouble() * 0.4)!
            .withValues(alpha: alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 1.4);
      canvas.drawCircle(Offset(x, y), radius, _paint);
    }
    _paint.maskFilter = null;
  }

  @override
  bool shouldRepaint(covariant _EmberPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.tint != tint;
}

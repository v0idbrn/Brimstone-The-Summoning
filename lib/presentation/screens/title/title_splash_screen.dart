import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/audio/procedural_sfx_engine.dart';
import '../../../core/performance/render_environment.dart';
import '../../../core/theme/design_tokens.dart';
import '../../graphics/art_registry.dart';
import '../../graphics/painted_backdrop.dart';
import '../../graphics/rift_effect.dart';

/// Cinematic entry gate: the painted abyss burns behind the chiselled
/// BRIMSTONE emblem until the player unseals the rift.
///
/// The gate owns the first user gesture, which is exactly when browsers allow
/// audio: tapping the seal unlocks the audio context, plays the opening chord
/// and hands control to [child] with a zoom + fade camera move.
class TitleGate extends StatefulWidget {
  const TitleGate({
    super.key,
    required this.child,
    this.skipSplash = false,
  });

  final Widget child;

  /// Tests (and deep links) can jump straight to [child].
  final bool skipSplash;

  @override
  State<TitleGate> createState() => _TitleGateState();
}

class _TitleGateState extends State<TitleGate> {
  late bool _revealed = widget.skipSplash;

  void _unseal() {
    if (_revealed) return;
    ProceduralSfxEngine.playTitleOpen();
    ProceduralSfxEngine.startAmbient('drone');
    setState(() => _revealed = true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 850),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final zoom = Tween<double>(begin: 1.16, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: zoom, child: child),
        );
      },
      child: _revealed
          ? KeyedSubtree(key: const ValueKey('home'), child: widget.child)
          : TitleSplashScreen(
              key: const ValueKey('splash'),
              onUnseal: _unseal,
            ),
    );
  }
}

/// The splash itself. Split from [TitleGate] so it can be previewed or tested
/// in isolation.
class TitleSplashScreen extends StatefulWidget {
  const TitleSplashScreen({super.key, required this.onUnseal});

  final VoidCallback onUnseal;

  @override
  State<TitleSplashScreen> createState() => _TitleSplashScreenState();
}

class _TitleSplashScreenState extends State<TitleSplashScreen>
    with TickerProviderStateMixin {
  AnimationController? _emberCtrl;
  AnimationController? _pulseCtrl;

  bool get _animate => !isWidgetTestEnvironment;

  @override
  void initState() {
    super.initState();
    if (_animate) {
      _emberCtrl = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 9),
      )..repeat();
      _pulseCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1700),
      )..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _emberCtrl?.dispose();
    _pulseCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Translucent: el sello tap no se traga los gestos de la pila decorativa.
      behavior: HitTestBehavior.translucent,
      onTap: widget.onUnseal,
      child: Scaffold(
        backgroundColor: BrimstoneTokens.bgAbyss,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const PaintedBackdrop(
              asset: ArtRegistry.sanctuary,
              tint: Color(0xFFC8A24B),
              darkness: 0.4,
              embers: true,
              fog: true,
              alignment: Alignment.center,
            ),
            Center(
              child: FractionallySizedBox(
                widthFactor: 0.62,
                heightFactor: 0.42,
                child: ClipOval(
                  child: ShaderMask(
                    shaderCallback: (rect) => RadialGradient(
                      center: Alignment.center,
                      radius: 1.0,
                      colors: [
                        Colors.white,
                        Colors.white.withValues(alpha: 0.8),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.65, 1.0],
                    ).createShader(rect),
                    blendMode: BlendMode.dstIn,
                    child: AbyssalRiftView(
                      color: BrimstoneTokens.goldPrimary,
                      intensity: 0.35,
                      animate: _animate,
                    ),
                  ),
                ),
              ),
            ),
            if (_emberCtrl != null)
              AnimatedBuilder(
                animation: _emberCtrl!,
                builder: (context, _) => CustomPaint(
                  painter: _EmberRainPainter(seconds: _emberCtrl!.value * 9),
                ),
              )
            else
              const RepaintBoundary(child: SizedBox.shrink()),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxHeight < 700;
                  return Column(
                    children: [
                      const Spacer(),
                      _Emblem(compact: compact),
                      const Spacer(),
                      _SealButton(
                        pulse: _pulseCtrl,
                        onTap: widget.onUnseal,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'BRIMSTONE · v1.0',
                        style: BrimstoneFonts.sans(
                          size: 9,
                          weight: FontWeight.w700,
                          color: BrimstoneTokens.textMuted,
                          letterSpacing: 3.0,
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Emblem extends StatelessWidget {
  const _Emblem({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Chiselled crest: layered diamonds + rune seal.
          SizedBox(
            width: compact ? 92 : 116,
            height: compact ? 92 : 116,
            child: const CustomPaint(painter: _CrestPainter()),
          ),
          SizedBox(height: compact ? 10 : 16),
          // Gilded engraved title with a metallic gradient.
          ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFF3C4),
                Color(0xFFE8C271),
                Color(0xFF9A6F1E),
                Color(0xFFE8C271),
              ],
              stops: [0.0, 0.36, 0.62, 1.0],
            ).createShader(rect),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'BRIMSTONE',
                style: BrimstoneFonts.cinzel(
                  size: compact ? 34 : 44,
                  weight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 7,
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'THE SUMMONING',
              style: BrimstoneFonts.cinzel(
                size: compact ? 12 : 14,
                weight: FontWeight.w700,
                color: BrimstoneTokens.goldPrimary,
                letterSpacing: 9,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Ornamental rule.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: compact ? 48 : 66,
                height: 1,
                color: BrimstoneTokens.goldMuted.withValues(alpha: 0.7),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Transform.rotate(
                  angle: math.pi / 4,
                  child: Container(
                    width: 6,
                    height: 6,
                    color: BrimstoneTokens.goldPrimary.withValues(alpha: 0.85),
                  ),
                ),
              ),
              Container(
                width: compact ? 48 : 66,
                height: 1,
                color: BrimstoneTokens.goldMuted.withValues(alpha: 0.7),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'CRÓNICAS DEL SELLO ROTO',
            textAlign: TextAlign.center,
            style: BrimstoneFonts.sans(
              size: compact ? 9.5 : 10.5,
              weight: FontWeight.w600,
              color: BrimstoneTokens.textSecondary,
              letterSpacing: 4.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SealButton extends StatelessWidget {
  const _SealButton({required this.pulse, required this.onTap});

  final AnimationController? pulse;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A1A08), Color(0xFF100804)],
        ),
        border: Border.all(color: BrimstoneTokens.goldPrimary, width: 1.6),
        boxShadow: [
          BoxShadow(
            color: BrimstoneTokens.goldPrimary.withValues(alpha: 0.35),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_fire_department,
            size: 16,
            color: BrimstoneTokens.goldPrimary,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'TOCAR PARA DESELLAR LA GRIETA',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BrimstoneFonts.cinzel(
                size: 11.5,
                weight: FontWeight.w800,
                color: BrimstoneTokens.goldBright,
                letterSpacing: 1.6,
              ),
            ),
          ),
        ],
      ),
    );

    final controller = pulse;
    return Semantics(
      button: true,
      label: 'Desellar la grieta',
      child: GestureDetector(
        onTap: onTap,
        child: controller == null
            ? content
            : AnimatedBuilder(
                animation: controller,
                builder: (context, child) {
                  final scale =
                      1.0 + 0.018 * math.sin(controller.value * math.pi);
                  return Transform.scale(scale: scale, child: child);
                },
                child: content,
              ),
      ),
    );
  }
}

/// Drifting golden embers and grey ash in front of the abyss.
class _EmberRainPainter extends CustomPainter {
  _EmberRainPainter({required this.seconds});

  final double seconds;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(23);
    final paint = Paint();
    for (var i = 0; i < 46; i++) {
      final x = random.nextDouble() * size.width;
      final speed = 0.02 + random.nextDouble() * 0.05;
      final phase = random.nextDouble();
      final drift = math.sin(seconds * (0.4 + phase) + i) * 14;
      final progress = (phase + seconds * speed) % 1.0;
      final y = size.height * (1.08 - progress * 1.16);
      final isAsh = i.isEven;
      final radius = (isAsh ? 1.1 : 1.8) + random.nextDouble() * 1.4;
      final fade = progress < 0.12
          ? progress / 0.12
          : progress > 0.85
              ? (1 - progress) / 0.15
              : 1.0;
      paint
        ..shader = null
        ..color = (isAsh ? const Color(0xFF9A8F86) : const Color(0xFFFFC93C))
            .withValues(alpha: 0.32 * fade.clamp(0.0, 1.0));
      canvas.drawCircle(
        Offset(x + drift, y),
        radius,
        paint,
      );
      if (!isAsh) {
        paint.color = const Color(0xFFFFE8A0)
            .withValues(alpha: 0.35 * fade.clamp(0.0, 1.0));
        canvas.drawCircle(Offset(x + drift, y), radius * 0.45, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EmberRainPainter old) => old.seconds != seconds;
}

/// Layered chiselled crest: diamond bezel, gilded ring and rune seal.
class _CrestPainter extends CustomPainter {
  const _CrestPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final gold = BrimstoneTokens.goldPrimary;
    final paint = Paint()..style = PaintingStyle.stroke;

    // Outer diamond bezel.
    final diamond = Path()
      ..moveTo(center.dx, center.dy - r)
      ..lineTo(center.dx + r, center.dy)
      ..lineTo(center.dx, center.dy + r)
      ..lineTo(center.dx - r, center.dy)
      ..close();
    paint
      ..strokeWidth = 2.0
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFF0BC), Color(0xFF8A5F16), Color(0xFFE8C271)],
      ).createShader(Offset.zero & size);
    canvas.drawPath(diamond, paint);

    // Gilded ring + dark core.
    paint
      ..style = PaintingStyle.fill
      ..shader = const RadialGradient(
        colors: [Color(0xFF2A1206), Color(0xFF0A0407)],
      ).createShader(Rect.fromCircle(center: center, radius: r * 0.62));
    canvas.drawCircle(center, r * 0.62, paint);

    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..shader = null
      ..color = gold.withValues(alpha: 0.85);
    canvas.drawCircle(center, r * 0.62, paint);
    canvas.drawCircle(center, r * 0.52, paint);

    // Rune seal: three flame tongues over a cross.
    paint
      ..strokeWidth = 2.0
      ..color = gold.withValues(alpha: 0.9);
    canvas.drawLine(
      Offset(center.dx, center.dy - r * 0.34),
      Offset(center.dx, center.dy + r * 0.34),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx - r * 0.26, center.dy + r * 0.12),
      Offset(center.dx + r * 0.26, center.dy + r * 0.12),
      paint,
    );
    final flame = Path()
      ..moveTo(center.dx, center.dy - r * 0.36)
      ..quadraticBezierTo(
        center.dx + r * 0.20,
        center.dy - r * 0.12,
        center.dx,
        center.dy + r * 0.06,
      )
      ..quadraticBezierTo(
        center.dx - r * 0.20,
        center.dy - r * 0.12,
        center.dx,
        center.dy - r * 0.36,
      );
    paint
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFF3C4),
          gold.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(center.dx, center.dy - r * 0.14),
          radius: r * 0.36,
        ),
      );
    canvas.drawPath(flame, paint);
  }

  @override
  bool shouldRepaint(covariant _CrestPainter oldDelegate) => false;
}

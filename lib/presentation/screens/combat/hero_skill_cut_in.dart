import 'dart:math' as math;

import 'package:flutter/material.dart' hide Element;

import '../../../core/theme/design_tokens.dart';
import '../../../domain/value_objects/element.dart';
import '../../graphics/art_registry.dart';

/// Payload for a hero invocation cut-in.
class HeroCutInData {
  const HeroCutInData({
    required this.heroId,
    required this.heroName,
    required this.skillName,
    required this.element,
  });

  final String heroId;
  final String heroName;
  final String skillName;
  final Element element;

  Color get color => switch (element) {
        Element.igneous => const Color(0xFFFF5A26),
        Element.abyssal => const Color(0xFF3FD8FF),
        Element.telluric => const Color(0xFFB0703B),
        Element.empty => const Color(0xFFB16EFF),
      };

  Color get glow => switch (element) {
        Element.igneous => const Color(0xFFFFD980),
        Element.abyssal => const Color(0xFFB8F0FF),
        Element.telluric => const Color(0xFFF0D0A0),
        Element.empty => const Color(0xFFE5D4FF),
      };
}

/// 0.55 s cinematic diagonal cut-in, JRPG/AAA style.
///
/// A diagonal obsidian band whips across the arena carrying the painted hero
/// portrait, the skill name in gilded Cinzel capitals and the hero name; behind
/// it the boss is struck by an elemental barrage (meteors, glacial lances,
/// tectonic pillars or a dimensional void slash). It never blocks input
/// (IgnorePointer) and never interrupts the combat rhythm.
class HeroSkillCutIn extends StatefulWidget {
  const HeroSkillCutIn({super.key, required this.data, this.onCompleted});

  final HeroCutInData? data;
  final VoidCallback? onCompleted;

  static const Duration duration = Duration(milliseconds: 550);

  @override
  State<HeroSkillCutIn> createState() => _HeroSkillCutInState();
}

class _HeroSkillCutInState extends State<HeroSkillCutIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: HeroSkillCutIn.duration,
  );

  @override
  void didUpdateWidget(covariant HeroSkillCutIn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data != null && widget.data != oldWidget.data) {
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
          final data = widget.data;
          if (data == null || _ctrl.value == 0) {
            return const SizedBox.shrink();
          }
          final t = Curves.easeOutCubic.transform(_ctrl.value.clamp(0.0, 1.0));
          return Stack(
            fit: StackFit.expand,
            children: [
              // Elemental barrage on the boss.
              CustomPaint(
                painter: _ImpactPainter(
                  element: data.element,
                  color: data.color,
                  glow: data.glow,
                  progress: _ctrl.value,
                ),
              ),
              // Diagonal cinematic band.
              _CutInBand(data: data, progress: t),
            ],
          );
        },
      ),
    );
  }
}

class _CutInBand extends StatelessWidget {
  const _CutInBand({required this.data, required this.progress});

  final HeroCutInData data;
  final double progress;

  @override
  Widget build(BuildContext context) {
    // Sweeps left→right, holds, then exits upward.
    final enter = (progress / 0.30).clamp(0.0, 1.0);
    final exit = ((progress - 0.72) / 0.28).clamp(0.0, 1.0);
    final offsetX = (1 - enter) * -1.4 + exit * 1.5;
    final fade = (1 - exit).clamp(0.0, 1.0);

    return Opacity(
      opacity: fade,
      child: FractionalTranslation(
        translation: Offset(offsetX, 0),
        child: Center(
          child: Transform.rotate(
            angle: -0.20,
            child: SizedBox(
              width: double.infinity,
              height: 132,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // Obsidian glass band with gilded seams.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.transparent,
                          const Color(0xFF07030A).withValues(alpha: 0.96),
                          Color.lerp(
                              const Color(0xFF140910), data.color, 0.18)!,
                          const Color(0xFF07030A).withValues(alpha: 0.96),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.12, 0.55, 0.88, 1.0],
                      ),
                      border: Border.symmetric(
                        horizontal: BorderSide(
                          color: BrimstoneAccents.goldPrimary
                              .withValues(alpha: 0.55),
                          width: 1.0,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: data.color.withValues(alpha: 0.35),
                          blurRadius: 28,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  // Hero portrait medallion.
                  Padding(
                    padding: const EdgeInsets.only(left: 26),
                    child: Row(
                      children: [
                        Container(
                          width: 104,
                          height: 104,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: BrimstoneAccents.goldBright,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: data.glow.withValues(alpha: 0.55),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              ArtRegistry.portrait(data.heroId),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => ColoredBox(
                                color: Color.lerp(
                                  const Color(0xFF140910),
                                  data.color,
                                  0.35,
                                )!,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Flexible(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data.heroName.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: BrimstoneTypography.headingSM.copyWith(
                                  color: BrimstoneAccents.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                data.skillName.toUpperCase(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    BrimstoneTypography.chapterTitle.copyWith(
                                  fontSize: 20,
                                  color: data.glow,
                                  letterSpacing: 2.2,
                                  shadows: [
                                    const Shadow(
                                      color: Colors.black,
                                      blurRadius: 8,
                                    ),
                                    Shadow(
                                      color: data.color.withValues(alpha: 0.85),
                                      blurRadius: 18,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Container(
                                    width: 26,
                                    height: 2,
                                    color: data.color,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '¡INVOCACIÓN!',
                                    style: BrimstoneTypography.labelSM.copyWith(
                                      color: BrimstoneAccents.goldPrimary,
                                      letterSpacing: 2.0,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Elemental barrage striking the boss plane during the cut-in.
class _ImpactPainter extends CustomPainter {
  _ImpactPainter({
    required this.element,
    required this.color,
    required this.glow,
    required this.progress,
  });

  final Element element;
  final Color color;
  final Color glow;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final fade = progress < 0.35
        ? progress / 0.35
        : (1 - (progress - 0.35) / 0.65).clamp(0.0, 1.0);
    if (fade <= 0) return;

    final center = Offset(size.width / 2, size.height * 0.34);
    final fill = Paint()..style = PaintingStyle.fill;
    final stroke = Paint()..style = PaintingStyle.stroke;
    final rng = math.Random(7);

    // Screen-wide elemental flash.
    fill.shader = RadialGradient(
      colors: [
        glow.withValues(alpha: 0.22 * fade),
        color.withValues(alpha: 0.10 * fade),
        Colors.transparent,
      ],
    ).createShader(
      Rect.fromCircle(center: center, radius: size.longestSide * 0.7),
    );
    canvas.drawRect(Offset.zero & size, fill);
    fill.shader = null;

    switch (element) {
      case Element.igneous:
        // Meteor rain.
        for (var i = 0; i < 14; i++) {
          final t = (progress * 1.6 + i * 0.07) % 1.0;
          final x = center.dx + (rng.nextDouble() - 0.5) * size.width * 0.9;
          final y = center.dy - 220 + t * 300;
          final r = 8.0 * (1 - t * 0.5);
          fill.color = Color.lerp(glow, color, t)!.withValues(alpha: fade);
          canvas.drawCircle(Offset(x, y), r, fill);
          stroke
            ..strokeWidth = 3
            ..color = color.withValues(alpha: 0.55 * fade);
          canvas.drawLine(
            Offset(x + 18, y - 46),
            Offset(x, y),
            stroke,
          );
        }
      case Element.abyssal:
        // Piercing glacial lances.
        for (var i = 0; i < 9; i++) {
          final t = (progress * 1.4 + i * 0.11) % 1.0;
          final x = center.dx + (i - 4) * 34.0;
          final y = center.dy - 200 + t * 280;
          final lance = Path()
            ..moveTo(x, y - 34)
            ..lineTo(x + 7, y)
            ..lineTo(x, y + 12)
            ..lineTo(x - 7, y)
            ..close();
          fill.color =
              Color.lerp(Colors.white, color, 0.45)!.withValues(alpha: fade);
          canvas.drawPath(lance, fill);
        }
      case Element.telluric:
        // Tectonic pillars erupting.
        for (var i = 0; i < 7; i++) {
          final t = (progress * 1.5 + i * 0.1) % 1.0;
          final x = center.dx + (i - 3) * 52.0;
          final h = 40 + t * 120;
          final rect = Rect.fromLTWH(x - 15, center.dy + 40 - h, 30, h);
          fill.shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              glow.withValues(alpha: fade),
              const Color(0xFF3A2414).withValues(alpha: fade),
            ],
          ).createShader(rect);
          canvas.drawRect(rect, fill);
          fill.shader = null;
        }
      case Element.empty:
        // Dimensional void slash.
        final slash = Path()
          ..moveTo(center.dx - size.width * 0.6, center.dy + 120)
          ..lineTo(center.dx + size.width * 0.6, center.dy - 140);
        stroke
          ..strokeWidth = 26 * fade
          ..color = color.withValues(alpha: 0.35 * fade)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
        canvas.drawPath(slash, stroke);
        stroke
          ..strokeWidth = 5 * fade
          ..color = Colors.white.withValues(alpha: 0.9 * fade)
          ..maskFilter = null;
        canvas.drawPath(slash, stroke);
    }

    // Shared shockwave ring at the boss core.
    stroke
      ..strokeWidth = 3
      ..color = glow.withValues(alpha: 0.55 * fade);
    canvas.drawCircle(center, 40 + progress * 200, stroke);
    stroke
      ..strokeWidth = 1.2
      ..color = color.withValues(alpha: 0.35 * fade);
    canvas.drawCircle(center, 70 + progress * 260, stroke);
  }

  @override
  bool shouldRepaint(covariant _ImpactPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.element != element;
}

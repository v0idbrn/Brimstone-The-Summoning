import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';

/// OVERDRIVE meter drawn under the arena.
///
/// Idle: an ember-filled gauge labelled FRENESÍ. Armed: the rail turns gold and
/// the label becomes ¡FRENESÍ ABISAL! with the remaining seconds.
class OverdriveBar extends StatelessWidget {
  const OverdriveBar({
    super.key,
    required this.fraction,
    required this.active,
    this.remaining = 0,
    this.height = 22,
  });

  final double fraction;
  final bool active;
  final double remaining;
  final double height;

  @override
  Widget build(BuildContext context) {
    final value = fraction.clamp(0.0, 1.0);
    final accent = active ? const Color(0xFFFFD24A) : const Color(0xFFFF5A26);
    final hot = active ? const Color(0xFFFFF3B0) : const Color(0xFFFFB05A);

    return Semantics(
      label: active ? '¡FRENESÍ ABISAL!' : 'FRENESÍ',
      value: '${(value * 100).round()}%',
      child: Container(
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: const Color(0xFF10070B),
          border: Border.all(
            color: active
                ? const Color(0xFFFFD24A)
                : BrimstoneTokens.goldPrimary.withValues(alpha: 0.35),
            width: active ? 1.6 : 0.8,
          ),
          boxShadow: [
            if (active)
              BoxShadow(
                color: const Color(0xFFFFD24A).withValues(alpha: 0.45),
                blurRadius: 14,
                spreadRadius: 1,
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: active ? 1.0 : value,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: active
                            ? const [Color(0xFFFFD24A), Color(0xFFFF7A18)]
                            : [const Color(0xFF7A1E0E), accent, hot],
                      ),
                    ),
                    child: CustomPaint(
                      painter: _EmberTicksPainter(active: active),
                    ),
                  ),
                ),
              ),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      active ? Icons.local_fire_department : Icons.bolt,
                      size: 11,
                      color: active ? const Color(0xFF2A0608) : Colors.white70,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      active
                          ? '¡FRENESÍ ABISAL!  ${remaining.toStringAsFixed(1)}s'
                          : value >= 1.0
                              ? '¡FRENESÍ LISTO!'
                              : 'FRENESÍ  ${(value * 100).round()}%',
                      style: BrimstoneFonts.cinzel(
                        size: 8.5,
                        weight: FontWeight.w800,
                        color: active ? const Color(0xFF2A0608) : Colors.white,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmberTicksPainter extends CustomPainter {
  const _EmberTicksPainter({required this.active});

  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: active ? 0.18 : 0.30)
      ..strokeWidth = 1;
    const ticks = 20;
    for (var i = 1; i < ticks; i++) {
      final x = size.width * i / ticks;
      final tall = i.isEven ? 0.55 : 0.32;
      canvas.drawLine(
        Offset(x, size.height * (1 - tall)),
        Offset(x, size.height),
        paint,
      );
    }
    // Moving specular band while the frenzy burns.
    if (active) {
      final band = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.55),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(
            Rect.fromLTWH(size.width * 0.35, 0, size.width * 0.3, size.height));
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), band);
    } else {
      final glow = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.25),
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromCircle(
            center: Offset(size.width, size.height * 0.5),
            radius: math.max(6, size.width * 0.2),
          ),
        );
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), glow);
    }
  }

  @override
  bool shouldRepaint(covariant _EmberTicksPainter old) => old.active != active;
}

import 'package:flutter/material.dart';

import '../../domain/combat/combat_engine.dart';
import '../../domain/combat/verlet_sparks.dart';

/// Draws the [VerletSparkPool] in engine-logical coordinates.
///
/// The painter reproduces the Flame view transform (`scale = width / 430`,
/// vertical centring of the 932 px layout) so sparks line up with the boss
/// reticle and the stone tray lip they bounce on.
class SparkPoolPainter extends CustomPainter {
  SparkPoolPainter({
    required this.pool,
    required this.color,
    this.time = 0,
    this.floorY = CombatEngine.trayY - 42,
  });

  final VerletSparkPool pool;
  final Color color;
  final double time;
  final double floorY;

  @override
  void paint(Canvas canvas, Size size) {
    if (pool.isEmpty) return;
    final scale = size.width / CombatEngine.layoutWidth;
    final offsetY = (size.height - CombatEngine.layoutHeight * scale) / 2;

    canvas
      ..save()
      ..translate(0, offsetY)
      ..scale(scale, scale);

    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final p in pool.particles) {
      if (!p.alive) continue;
      final energy = p.energy;
      final wear = (1.0 - energy).clamp(0.0, 1.0);
      paint
        ..strokeWidth = (p.size * (0.55 + energy)).clamp(0.6, 4.0)
        ..color = Color.lerp(
          Colors.white,
          color,
          (wear * 1.35).clamp(0.0, 1.0),
        )!
            .withValues(alpha: (0.15 + energy * 0.85).clamp(0.0, 1.0));
      canvas.drawLine(
        Offset(p.prevX, p.prevY),
        Offset(p.x, p.y),
        paint,
      );
      // Hot micro-core at the spark head.
      paint
        ..strokeWidth = (p.size * 0.9).clamp(0.8, 3.0)
        ..color = Colors.white.withValues(alpha: energy * 0.75);
      canvas.drawLine(
        Offset(p.x, p.y),
        Offset(p.x + p.velocityX * 0.35, p.y + p.velocityY * 0.35),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SparkPoolPainter oldDelegate) => true;
}

/// Peripheral darkness that closes in with the tactical zoom / punch.
class CombatVignette extends StatelessWidget {
  const CombatVignette({
    super.key,
    required this.strength,
    this.color = const Color(0xFF07030A),
  });

  final double strength;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (strength <= 0.001) return const SizedBox.shrink();
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            radius: 0.92,
            colors: [
              Colors.transparent,
              Colors.transparent,
              color.withValues(alpha: strength.clamp(0.0, 0.7)),
              color.withValues(alpha: (strength * 1.5).clamp(0.0, 0.9)),
            ],
            stops: const [0.0, 0.55, 0.82, 1.0],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

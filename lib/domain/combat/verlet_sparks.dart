import 'dart:math' as math;

/// One bouncing spark, integrated with Verlet positions.
///
/// The pool keeps these pre-allocated: a hit never allocates, it only overwrites
/// the oldest slot, so thousands of impacts produce zero GC pressure.
class SparkParticle {
  SparkParticle();

  double x = 0;
  double y = 0;
  double prevX = 0;
  double prevY = 0;
  double life = 0;
  double maxLife = 1;
  double size = 1;
  double hueShift = 0;

  /// Trail segment drawn from the previous frame position to the current one.
  double get velocityX => x - prevX;

  /// Vertical velocity in px/frame (positive = falling).
  double get velocityY => y - prevY;

  bool get alive => life > 0;

  /// Normalised remaining lifetime (1 at birth, 0 at death).
  double get energy => maxLife <= 0 ? 0 : (life / maxLife).clamp(0.0, 1.0);
}

/// Fixed-budget ballistics for impact sparks.
///
/// Verlet integration with a fixed 1/60 s sub-step keeps the arcs deterministic
/// (and therefore testable): gravity [gravity] px/s², air drag [drag] and a
/// stone-lip bounce with restitution [restitution] at [floorY].
class VerletSparkPool {
  VerletSparkPool({
    this.capacity = 96,
    this.gravity = 520,
    this.restitution = 0.45,
    this.drag = 0.985,
  })  : assert(capacity > 0),
        _particles = List<SparkParticle>.generate(
          capacity,
          (_) => SparkParticle(),
          growable: false,
        );

  static const double fixedStep = 1 / 60;

  final int capacity;
  final double gravity;
  final double restitution;
  final double drag;

  final List<SparkParticle> _particles;
  int _cursor = 0;
  int _live = 0;

  /// Live sparks in draw order (bounded by [capacity]).
  List<SparkParticle> get particles => _particles;

  int get liveCount => _live;

  bool get isEmpty => _live == 0;

  /// Emits a spark at ([x], [y]) with the given velocities in px/second.
  SparkParticle spawn({
    required double x,
    required double y,
    required double velocityX,
    required double velocityY,
    double life = 0.55,
    double size = 2.2,
    double hueShift = 0,
  }) {
    final p = _particles[_cursor];
    _cursor = (_cursor + 1) % capacity;
    p
      ..x = x
      ..y = y
      ..prevX = x - velocityX * fixedStep
      ..prevY = y - velocityY * fixedStep
      ..life = life
      ..maxLife = life
      ..size = size
      ..hueShift = hueShift;
    _live = math.min(capacity, _live + 1);
    return p;
  }

  /// Convenience: a radial burst of [count] sparks (deterministic in [random]).
  void burst({
    required double x,
    required double y,
    required math.Random random,
    int count = 10,
    double speed = 220,
    double spreadRadians = math.pi * 2,
    double baseAngle = -math.pi / 2,
    double life = 0.55,
    double size = 2.2,
  }) {
    for (var i = 0; i < count; i++) {
      final angle = baseAngle + (random.nextDouble() - 0.5) * spreadRadians;
      final magnitude = speed * (0.45 + random.nextDouble() * 0.75);
      spawn(
        x: x,
        y: y,
        velocityX: math.cos(angle) * magnitude,
        velocityY: math.sin(angle) * magnitude,
        life: life * (0.7 + random.nextDouble() * 0.6),
        size: size * (0.7 + random.nextDouble() * 0.8),
        hueShift: random.nextDouble(),
      );
    }
  }

  /// Advances every live spark. [floorY] is the stone lip of the tray: sparks
  /// reflect there with [restitution] and lose horizontal speed to friction.
  void update(double dt, {required double floorY}) {
    if (dt <= 0 || _live == 0) return;
    final steps = math.min(4, math.max(1, (dt / fixedStep).ceil()));
    final step = math.min(dt, fixedStep * steps) / steps;
    final stepSquared = step * step;

    for (final p in _particles) {
      if (!p.alive) continue;
      p.life -= dt;
      if (p.life <= 0) {
        p.life = 0;
        _live = math.max(0, _live - 1);
        continue;
      }
      for (var s = 0; s < steps; s++) {
        final vx = (p.x - p.prevX) * drag;
        final vy = (p.y - p.prevY) * drag + gravity * stepSquared;
        p.prevX = p.x;
        p.prevY = p.y;
        p.x += vx;
        p.y += vy;
        if (p.y >= floorY && p.y - p.prevY > 0) {
          p.y = floorY;
          // Reflect: next frame's implicit velocity points upward.
          p.prevY = p.y + (p.y - p.prevY) * restitution;
          p.prevX = p.x - (p.x - p.prevX) * 0.72;
        }
      }
    }
  }

  void clear() {
    for (final p in _particles) {
      p.life = 0;
    }
    _live = 0;
    _cursor = 0;
  }
}

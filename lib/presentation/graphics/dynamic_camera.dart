import 'dart:math' as math;

/// Cinematic 2.5D camera for the combat arena.
///
/// Pure maths (no widgets) so the feel is unit-testable:
///
/// * tactical micro-zoom 1.00→[aimZoom] while aiming a level-3 orb or while the
///   boss is in BREAK;
/// * impact punch: a damped spring kicks the zoom to ≈1.08 for ~60 ms and
///   settles elastically;
/// * [vignette] rises with the zoom so the frame closes in on the targets.
class DynamicCombatCamera {
  DynamicCombatCamera({
    this.baseZoom = 1.0,
    this.aimZoom = 1.06,
    this.maxZoom = 1.16,
    this.stiffness = 190,
    this.damping = 24,
    this.zoomSharpness = 9,
  });

  final double baseZoom;
  final double aimZoom;
  final double maxZoom;
  final double stiffness;
  final double damping;
  final double zoomSharpness;

  double zoom = 1.0;
  double _punch = 0;
  double _punchVelocity = 0;

  /// Present zoom applied to the arena canvas.
  double get scale => (zoom + _punch).clamp(baseZoom, maxZoom);

  /// 0→~0.6 vignette strength for the peripheral darkness.
  double get vignette {
    final tactical = (zoom - baseZoom) / math.max(1e-6, aimZoom - baseZoom);
    return (tactical * 0.45 + _punch * 3.2).clamp(0.0, 0.65);
  }

  bool get isPunching => _punch > 0.002;

  /// Kicks the camera. [strength] is added to the current punch.
  void punch([double strength = 0.08]) {
    _punch = math.min(0.12, _punch + strength);
    _punchVelocity = 0;
  }

  /// Advances the spring. [aiming] and [bossBroken] request the tactical zoom.
  void tick(
    double dt, {
    required bool aiming,
    required bool bossBroken,
  }) {
    if (dt <= 0) return;
    final step = math.min(dt, 0.05);
    final target = (aiming || bossBroken) ? aimZoom : baseZoom;
    final smoothing = 1 - math.exp(-zoomSharpness * step);
    zoom += (target - zoom) * smoothing;

    // Damped spring back to rest: 60 ms kick, elastic settle.
    final acceleration = -stiffness * _punch - damping * _punchVelocity;
    _punchVelocity += acceleration * step;
    _punch += _punchVelocity * step;
    if (_punch.abs() < 1e-4 && _punchVelocity.abs() < 1e-3) {
      _punch = 0;
      _punchVelocity = 0;
    }
  }

  void reset() {
    zoom = baseZoom;
    _punch = 0;
    _punchVelocity = 0;
  }
}

import 'dart:math' as math;

import '../value_objects/orb_level.dart';
import 'combat_models.dart';

/// Pure 2.5D ballistics math for the combat engine (unit-testable, no Flame).
class CombatMath {
  static const double flightMin = 0.32;
  static const double flightMax = 0.55;
  static const double flickSpeedThreshold = -280.0; // px/s upward
  static const double grazeRadius = 70.0;
  static const double projectileInterceptDistance = 44.0;
  static const double interceptZWindow = 0.16;

  /// Normalized flight progress z in [0, 1].
  static double flightZ(double elapsed, double duration) =>
      (elapsed / duration).clamp(0.0, 1.0);

  /// Player orb scale from z = 0 (tray) to z = 1 (boss plane).
  static double flightScale(double z) => 1.0 - 0.62 * z;

  /// Enemy corrupted orb scale from z = 1 (0.38) to z = 0 (1.15).
  static double enemyFlightScale(double z) => 1.15 - (1.15 - 0.38) * z;

  /// Screen Y with vertical parabolic arc lifting of 115 px.
  static double flightY(double startY, double targetY, double z) =>
      lerp(startY, targetY, z) - math.sin(z * math.pi) * 115.0;

  static double lerp(double a, double b, double t) => a + (b - a) * t;

  static double clamp01(double v) => v.clamp(0.0, 1.0);

  /// Adjusted flight duration from flick velocity (faster flick -> shorter).
  static double durationForFlickSpeed(double vy) {
    final speed = (-vy).abs().clamp(280.0, 2000.0).toDouble();
    final t = (speed - 280.0) / (2000.0 - 280.0);
    return flightMax - t * (flightMax - flightMin);
  }

  /// Classify a landing against target radii (inner/outer already scaled).
  static HitKind classifyHit(double distance, double innerR, double outerR) {
    if (distance <= innerR) return HitKind.bullseye;
    if (distance <= outerR) return HitKind.normal;
    if (distance <= grazeRadius) return HitKind.graze;
    return HitKind.miss;
  }

  /// Damage multiplier for a hit kind against an orb level.
  static double hitMultiplier(HitKind kind, OrbLevel level) {
    final base = switch (level) {
      OrbLevel.one => 1.0,
      OrbLevel.two => 2.2,
      OrbLevel.three => 4.8,
    };
    final hit = switch (kind) {
      HitKind.bullseye => 1.5,
      HitKind.normal => 1.0,
      HitKind.graze => 0.25,
      HitKind.miss => 0.0,
    };
    return base * hit;
  }

  /// Mana on hit for a hit kind and orb level.
  static double hitMana(HitKind kind, OrbLevel level) {
    final base = switch (level) {
      OrbLevel.one => 15.0,
      OrbLevel.two => 35.0,
      OrbLevel.three => 75.0,
    };
    final hit = switch (kind) {
      HitKind.bullseye => 1.5,
      HitKind.normal => 1.0,
      HitKind.graze => 0.25,
      HitKind.miss => 0.0,
    };
    return base * hit;
  }

  /// Aura applies on any level; crit applies aura at any level per spec.
  static bool appliesAura(HitKind kind, OrbLevel level) {
    if (kind == HitKind.bullseye) return true;
    return level != OrbLevel.one;
  }

  /// Camera shake offset (trauma model): maxShake * trauma^2 * sin(time*45).
  static double shakeOffset(double trauma, double time, double maxShake) =>
      maxShake * trauma * trauma * math.sin(time * 45.0);
}

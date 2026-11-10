/// OVERDRIVE (Frenesí Abisal) tuning.
///
/// Every landed hit, merge and elemental reaction feeds a 0→100 % meter. At
/// 100 % the arena ignites for [duration] seconds: the tray refills itself every
/// [refillInterval] with level 2/3 orbs, shots fly at maximum speed and every
/// point of damage is multiplied by [damageMult].
class OverdriveRules {
  const OverdriveRules._();

  static const double gainPerHit = 0.045;
  static const double gainPerBullseye = 0.09;
  static const double gainPerMerge = 0.12;
  static const double gainPerReaction = 0.18;

  static const double duration = 6.0;
  static const double damageMult = 1.4;
  static const double refillInterval = 0.15;

  /// Fastest projectile flight while the frenzy burns (seconds).
  static const double projectileFlight = 0.35;

  static const double normalFlight = 0.85;

  /// Tray pattern produced by the frenzy refill: alternating 3★ / 2★ orbs.
  static int refillLevelFor(int index) => index.isEven ? 3 : 2;

  /// Full-meter trigger, clamped so float drift can never leak past 100 %.
  static bool shouldActivate(double charge) => charge >= 1.0;

  static double clampCharge(double charge) => charge.clamp(0.0, 1.0);
}

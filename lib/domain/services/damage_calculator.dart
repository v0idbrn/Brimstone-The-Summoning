import '../value_objects/orb_level.dart';

class DamageCalculator {
  static double calculate(
    OrbLevel level, {
    bool isBullseye = false,
    double reactionMultiplier = 1.0,
  }) {
    double base;
    switch (level) {
      case OrbLevel.one:
        base = 1.0;
        break;
      case OrbLevel.two:
        base = 2.2;
        break;
      case OrbLevel.three:
        base = 4.8;
        break;
    }
    if (isBullseye) base *= 1.5;
    return base * reactionMultiplier;
  }
}

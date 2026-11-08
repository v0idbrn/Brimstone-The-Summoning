import '../services/damage_calculator.dart';
import '../value_objects/orb_level.dart';

class CalculateDamage {
  double call(
    OrbLevel level, {
    bool bullseye = false,
    double reactionMult = 1.0,
  }) =>
      DamageCalculator.calculate(
        level,
        isBullseye: bullseye,
        reactionMultiplier: reactionMult,
      );
}

import 'dart:math' as math;

import '../value_objects/rarity.dart';

/// Rarity weights for the summoning portal (Pacto Menor / Gran Ritual).
class SummonService {
  static const double epicFloor = 1.0; // at least 1 epic in a grand ritual

  Rarity rollRarity(math.Random random) {
    final roll = random.nextInt(100) + 1; // 1..100
    if (roll <= 8) return Rarity.mythic; // 8%
    if (roll <= 25) return Rarity.legendary; // 17%
    if (roll <= 42) return Rarity.epic; // 17%
    if (roll <= 67) return Rarity.rare; // 25%
    return Rarity.common; // 33%
  }

  /// Grand Ritual guarantee: at least one epic or legendary in a 5-pull.
  List<Rarity> rollGrandRitual(math.Random random, int count) {
    final results = [for (var i = 0; i < count; i++) rollRarity(random)];
    final hasHigh = results.any(
      (r) => r == Rarity.epic || r == Rarity.legendary || r == Rarity.mythic,
    );
    if (!hasHigh) results[results.length - 1] = Rarity.epic;
    return results;
  }
}

/// evolution rules: 1★ -> 4★ sacrificing a duplicate catalogId & stars.
class EvolutionRules {
  static const int maxStars = 4;

  /// Gold cost ascending stars: 250*stars.
  static int costFor(int stars) => 250 * stars;

  static bool canEvolve({
    required int stars,
    required String catalogId,
    required List<CardIdentifier> duplicates,
  }) {
    if (stars >= maxStars) return false;
    return duplicates.any((d) => d.catalogId == catalogId && d.stars == stars);
  }
}

/// Lightweight identity projection consumed by the rules above.
class CardIdentifier {
  final String catalogId;
  final int stars;
  const CardIdentifier(this.catalogId, this.stars);
}

/// Level-up rules: +10% ATK/HP per level, gold cost 100*level.
class LevelUpRules {
  static int costFor(int level) => 100 * level;

  static int statAfter(int baseStat, int level) =>
      (baseStat * math.pow(1.10, level - 1)).round();
}

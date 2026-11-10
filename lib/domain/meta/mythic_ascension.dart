import 'dart:math' as math;

/// 5★ Primordial Ascension: the ceiling above the classic 4★ evolution.
///
/// Unlike 1★→4★ (which sacrifices a duplicate), ascending to 5★ is paid with
/// [shardCost] Esquirlas de Esencia Primordial plus [goldCost] oro. The result
/// keeps a mythic squad passive even when the card is not the leader.
class MythicAscension {
  const MythicAscension._();

  static const int maxStars = 5;
  static const int ascensionStars = 4;

  static const int shardCost = 1200;
  static const int goldCost = 2500;

  /// +45 % ATK / HP on top of the 4★ values.
  static const double statMultiplier = 1.45;

  /// -8 mana cost.
  static const int manaReduction = 8;

  /// +8 % elemental damage for the whole deck while the card is owned.
  static const double squadElementalBonus = 0.08;

  static bool canAscend(int stars) => stars == ascensionStars;

  static int attackAfter(int attack) => (attack * statMultiplier).round();

  static int healthAfter(int health) => (health * statMultiplier).round();

  static int manaAfter(int baseMana) => math.max(0, baseMana - manaReduction);

  static int totalCost() => shardCost + goldCost;

  /// Human-readable passive line used by the card frame and the Altar.
  static String get passiveLabel =>
      '+${(squadElementalBonus * 100).round()}% DAÑO ELEMENTAL AL MAZO';
}

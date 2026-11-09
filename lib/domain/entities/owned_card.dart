import '../value_objects/element.dart';
import '../value_objects/rarity.dart';

/// A card instance owned by the player (catalog copy + progression).
class OwnedCard {
  final int instanceId;
  final String catalogId;
  final String name;
  final Element element;
  final Rarity rarity;
  final int baseManaCost;
  final int baseAttack;
  final int baseHealth;
  final int level;
  final int stars;
  final int skillLevel; // 1-5
  final int masteryXp; // 0-999 (each 100 XP = 1 Mastery Rank, max 10)

  const OwnedCard({
    required this.instanceId,
    required this.catalogId,
    required this.name,
    required this.element,
    required this.rarity,
    required this.baseManaCost,
    required this.baseAttack,
    required this.baseHealth,
    required this.level,
    required this.stars,
    required this.skillLevel,
    required this.masteryXp,
  });

  /// Mastery Rank 1-10 (each 100 XP = 1 rank).
  int get masteryRank => ((masteryXp ~/ 100) + 1).clamp(1, 10);

  /// Whether the skill is awakened (Skill Level 5 or Mastery Rank 5+).
  bool get isAwakened => skillLevel >= 5 || masteryRank >= 5;

  /// Skill effect multiplier: +15% per skill level above 1.
  double get skillEffectMult => 1.0 + (skillLevel - 1) * 0.15;

  /// Skill mana cost reduction: -4 per skill level above 1.
  int get skillManaCostReduction => (skillLevel - 1) * 4;

  OwnedCard copyWith({
    int? level,
    int? stars,
    int? attack,
    int? health,
    int? skillLevel,
    int? masteryXp,
  }) =>
      OwnedCard(
        instanceId: instanceId,
        catalogId: catalogId,
        name: name,
        element: element,
        rarity: rarity,
        baseManaCost: baseManaCost,
        baseAttack: attack ?? baseAttack,
        baseHealth: health ?? baseHealth,
        level: level ?? this.level,
        stars: stars ?? this.stars,
        skillLevel: skillLevel ?? this.skillLevel,
        masteryXp: masteryXp ?? this.masteryXp,
      );
}

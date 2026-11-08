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
  });

  OwnedCard copyWith({int? level, int? stars, int? attack, int? health}) =>
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
      );
}

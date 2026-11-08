import '../value_objects/element.dart';
import '../value_objects/rarity.dart';

class Card {
  final String id;
  final String name;
  final Element element;
  final Rarity rarity;
  final int baseManaCost;
  final int currentMana;
  final int attack;
  final int health;
  final int stars;
  final String activeSkill;

  const Card({
    required this.id,
    required this.name,
    required this.element,
    required this.rarity,
    required this.baseManaCost,
    this.currentMana = 0,
    required this.attack,
    required this.health,
    this.stars = 1,
    required this.activeSkill,
  });

  int get effectiveAttack => (attack * 1.35 * stars).toInt();
  int get effectiveHealth => (health * 1.35 * stars).toInt();

  bool get isManaFull => currentMana >= baseManaCost;
}

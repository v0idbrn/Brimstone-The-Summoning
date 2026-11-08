class CardDto {
  final String id;
  final String name;
  final String element;
  final String rarity;
  final int baseManaCost;
  final int attack;
  final int health;
  final int stars;
  final String activeSkill;

  const CardDto({
    required this.id,
    required this.name,
    required this.element,
    required this.rarity,
    required this.baseManaCost,
    required this.attack,
    required this.health,
    required this.stars,
    required this.activeSkill,
  });

  factory CardDto.fromJson(Map<String, dynamic> json) => CardDto(
    id: json['id'] as String,
    name: json['name'] as String,
    element: json['element'] as String,
    rarity: json['rarity'] as String,
    baseManaCost: json['base_mana_cost'] as int,
    attack: json['attack'] as int,
    health: json['health'] as int,
    stars: json['stars'] as int,
    activeSkill: json['active_skill'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'element': element,
    'rarity': rarity,
    'base_mana_cost': baseManaCost,
    'attack': attack,
    'health': health,
    'stars': stars,
    'active_skill': activeSkill,
  };
}

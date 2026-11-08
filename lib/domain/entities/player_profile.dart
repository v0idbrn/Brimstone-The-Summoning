// PlayerProfile entity
class PlayerProfile {
  final String id;
  final int gold;
  final int shards;
  final int maxHp;
  final int currentHp;
  const PlayerProfile({
    required this.id,
    required this.gold,
    required this.shards,
    required this.maxHp,
    required this.currentHp,
  });
}

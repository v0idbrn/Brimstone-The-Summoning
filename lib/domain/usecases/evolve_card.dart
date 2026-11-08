import '../repositories/card_repository.dart';
import '../entities/card.dart';
import '../value_objects/rarity.dart';

class EvolveCard {
  final CardRepository repository;

  EvolveCard(this.repository);

  Future<Card> call(Card card) async {
    if (card.stars >= 4) throw Exception('Already max stars');
    final evolved = Card(
      id: card.id,
      name: card.name,
      element: card.element,
      rarity: _nextRarity(card.rarity),
      baseManaCost: card.baseManaCost,
      currentMana: 0,
      attack: card.attack,
      health: card.health,
      stars: card.stars + 1,
      activeSkill: card.activeSkill,
    );
    await repository.saveCard(evolved);
    return evolved;
  }

  Rarity _nextRarity(Rarity r) => Rarity.values[r.index + 1];
}

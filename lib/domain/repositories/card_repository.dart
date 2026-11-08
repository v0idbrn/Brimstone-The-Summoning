import '../entities/card.dart';

abstract class CardRepository {
  Future<List<Card>> getAllCards();
  Future<Card?> getCardById(String id);
  Future<void> saveCard(Card card);
}

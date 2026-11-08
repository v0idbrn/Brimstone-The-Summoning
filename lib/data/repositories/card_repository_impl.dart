import '../../domain/repositories/card_repository.dart';
import '../../domain/entities/card.dart';
import '../../domain/value_objects/element.dart';
import '../../domain/value_objects/rarity.dart';
import '../database/database_helper.dart';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class CardRepositoryImpl implements CardRepository {
  final DatabaseHelper _db;

  CardRepositoryImpl(this._db);

  @override
  Future<List<Card>> getAllCards() async {
    final db = await _db.db;
    final maps = await db.query('cards');
    return maps
        .map(
          (m) => Card(
            id: m['id'] as String,
            name: m['name'] as String,
            element: Element.values.firstWhere(
              (e) => e.name == m['element'] as String,
            ),
            rarity: Rarity.values.firstWhere(
              (r) => r.name == m['rarity'] as String,
            ),
            baseManaCost: m['base_mana_cost'] as int,
            currentMana: 0,
            attack: m['attack'] as int,
            health: m['health'] as int,
            stars: m['stars'] as int,
            activeSkill: m['active_skill'] as String,
          ),
        )
        .toList();
  }

  @override
  Future<Card?> getCardById(String id) async {
    final db = await _db.db;
    final maps = await db.query('cards', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    final m = maps.first;
    return Card(
      id: m['id'] as String,
      name: m['name'] as String,
      element: Element.values.firstWhere(
        (e) => e.name == m['element'] as String,
      ),
      rarity: Rarity.values.firstWhere((r) => r.name == m['rarity'] as String),
      baseManaCost: m['base_mana_cost'] as int,
      currentMana: 0,
      attack: m['attack'] as int,
      health: m['health'] as int,
      stars: m['stars'] as int,
      activeSkill: m['active_skill'] as String,
    );
  }

  @override
  Future<void> saveCard(Card card) async {
    final db = await _db.db;
    await db.insert(
        'cards',
        {
          'id': card.id,
          'name': card.name,
          'element': card.element.name,
          'rarity': card.rarity.name,
          'base_mana_cost': card.baseManaCost,
          'attack': card.attack,
          'health': card.health,
          'stars': card.stars,
          'active_skill': card.activeSkill,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
}

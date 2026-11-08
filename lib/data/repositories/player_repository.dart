import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:brimstone_summoning/domain/entities/owned_card.dart';
import 'package:brimstone_summoning/domain/meta/rune_system.dart';
import 'package:brimstone_summoning/domain/value_objects/element.dart';
import 'package:brimstone_summoning/domain/value_objects/rarity.dart';

import '../database/database_helper.dart';

/// SQLite persistence for the summoner profile, the owned card collection
/// and the active 4-card squad.
class PlayerRepository {
  final DatabaseHelper _db;
  PlayerRepository(this._db);

  // ------------------------------------------------------- player profile

  Future<List<int>> loadProfile() async {
    final db = await _db.db;
    final rows = await db.query('player_profile', limit: 1);
    if (rows.isEmpty) {
      return const [500, 100, 20, 1]; // gold, shards, energy, level
    }
    final r = rows.first;
    return [
      (r['gold'] as int?) ?? 500,
      (r['shards'] as int?) ?? 100,
      (r['energy'] as int?) ?? 20,
      (r['summoner_level'] as int?) ?? 1,
    ];
  }

  Future<void> saveProfile({
    required int gold,
    required int shards,
    required int energy,
    required int summonerLevel,
  }) async {
    final db = await _db.db;
    final existing = await db.query('player_profile', limit: 1);
    final values = {
      'gold': gold,
      'shards': shards,
      'energy': energy,
      'summoner_level': summonerLevel,
    };
    if (existing.isEmpty) {
      await db.insert('player_profile', {'id': 'player_1', ...values});
    } else {
      final id = existing.first['id'];
      await db.update(
        'player_profile',
        values,
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  // ---------------------------------------------------------- collection

  Future<List<OwnedCard>> loadCollection() async {
    final db = await _db.db;
    final rows = await db.rawQuery('''
      SELECT o.id AS instance_id, c.card_id AS catalog_id, c.name, c.element,
             c.rarity, c.base_mana_cost, c.attack, c.health, o.level, o.stars
      FROM owned_cards o
      LEFT JOIN cards c ON c.id = o.card_id
      ORDER BY o.id DESC
    ''');
    return [
      for (final row in rows)
        OwnedCard(
          instanceId: row['instance_id'] as int,
          catalogId: (row['catalog_id'] as String?) ?? 'fighterX',
          name: (row['name'] as String?) ?? 'Corrupto sin nombre',
          element: Element.values.firstWhere(
            (e) => e.name == row['element'],
            orElse: () => Element.igneous,
          ),
          rarity: Rarity.values.firstWhere(
            (r) => r.name == row['rarity'],
            orElse: () => Rarity.common,
          ),
          baseManaCost: (row['base_mana_cost'] as int?) ?? 100,
          baseAttack: (row['attack'] as int?) ?? 10,
          baseHealth: (row['health'] as int?) ?? 15,
          level: (row['level'] as int?) ?? 1,
          stars: (row['stars'] as int?) ?? 1,
        ),
    ];
  }

  Future<OwnedCard> insertSummonedCard(String catalogId) async {
    final db = await _db.db;
    final raw = await db.query(
      'cards',
      where: 'id = ?',
      whereArgs: [catalogId],
      limit: 1,
    );
    Map<String, Object?> metaRow;
    if (raw.isEmpty) {
      // Fallback stat line for unknown catalog ids.
      metaRow = const {
        'name': 'Luchador Corrupto',
        'element': 'void',
        'rarity': 'common',
        'base_mana_cost': 100,
        'attack': 10,
        'health': 15,
      };
    } else {
      final seed = raw.first;
      metaRow = {
        'name': seed['name'],
        'element': seed['element'],
        'rarity': seed['rarity'],
        'base_mana_cost': seed['base_mana_cost'],
        'attack': seed['attack'],
        'health': seed['health'],
      };
    }
    final id = await db.insert('owned_cards', {
      'card_id': catalogId,
      'level': 1,
      'stars': 1,
    });
    return OwnedCard(
      instanceId: id,
      catalogId: catalogId,
      name: metaRow['name'] as String,
      element: Element.values.firstWhere(
        (e) => e.name == metaRow['element'],
        orElse: () => Element.igneous,
      ),
      rarity: Rarity.values.firstWhere(
        (r) => r.name == metaRow['rarity'],
        orElse: () => Rarity.common,
      ),
      baseManaCost: metaRow['base_mana_cost'] as int,
      baseAttack: metaRow['attack'] as int,
      baseHealth: metaRow['health'] as int,
      level: 1,
      stars: 1,
    );
  }

  Future<void> deleteOwnedCard(int instanceId) async {
    final db = await _db.db;
    await db.delete('owned_cards', where: 'id = ?', whereArgs: [instanceId]);
    // If the deleted card was in the squad, remove the slot too.
    await db.delete(
      'player_squad',
      where: 'owned_card_id = ?',
      whereArgs: [instanceId],
    );
  }

  Future<void> updateOwnedCard(OwnedCard card) async {
    final db = await _db.db;
    await db.update(
      'owned_cards',
      {'level': card.level, 'stars': card.stars},
      where: 'id = ?',
      whereArgs: [card.instanceId],
    );
  }

  // ---------------------------------------------------------------- squad

  Future<List<int>> loadSquad() async {
    final db = await _db.db;
    final rows = await db.query('player_squad', orderBy: 'slot');
    return [for (final r in rows) r['owned_card_id'] as int];
  }

  Future<void> saveSquad(List<int> instanceIds) async {
    final db = await _db.db;
    await db.delete('player_squad');
    for (var i = 0; i < instanceIds.length && i < 4; i++) {
      await db.insert('player_squad', {
        'slot': i,
        'owned_card_id': instanceIds[i],
      });
    }
  }

  // ----------------------------------------------------------------- runes

  /// Carga la runa equipada en la carta [instanceId], o null si no tiene.
  Future<RuneInstance?> loadCardRune(int instanceId) async {
    final db = await _db.db;
    final rows = await db.query(
      'owned_card_runes',
      where: 'owned_card_id = ?',
      whereArgs: [instanceId],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return RuneInstance(
      type: RuneType.values.firstWhere(
        (t) => t.name == row['rune_type'],
        orElse: () => RuneType.crimsonFury,
      ),
      level: (row['level'] as int?) ?? 1,
    );
  }

  /// Guarda (inserta o actualiza) la runa equipada en [instanceId].
  Future<void> saveCardRune(int instanceId, RuneInstance rune) async {
    final db = await _db.db;
    await db.insert(
        'owned_card_runes',
        {
          'owned_card_id': instanceId,
          'rune_type': rune.type.name,
          'level': rune.level,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Quita la runa de la carta [instanceId].
  Future<void> removeCardRune(int instanceId) async {
    final db = await _db.db;
    await db.delete(
      'owned_card_runes',
      where: 'owned_card_id = ?',
      whereArgs: [instanceId],
    );
  }

  // ---------------------------------------------------------------- endless

  /// Carga el récord histórico de oleada máxima del Abismo Sin Fin.
  Future<int> loadHighestEndlessWave() async {
    final db = await _db.db;
    final rows = await db.query('player_profile', limit: 1);
    if (rows.isEmpty) return 0;
    return (rows.first['highest_endless_wave'] as int?) ?? 0;
  }

  /// Guarda el récord histórico de oleada máxima si supera el previo.
  Future<void> saveHighestEndlessWave(int wave) async {
    final db = await _db.db;
    final current = await loadHighestEndlessWave();
    if (wave <= current) return;
    final existing = await db.query('player_profile', limit: 1);
    if (existing.isEmpty) {
      await db.insert('player_profile', {
        'id': 'player_1',
        'gold': 500,
        'shards': 100,
        'max_hp': 100,
        'current_hp': 100,
        'energy': 20,
        'summoner_level': 1,
        'highest_endless_wave': wave,
      });
    } else {
      await db.update(
        'player_profile',
        {'highest_endless_wave': wave},
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    }
  }

  // ----------------------------------------------------------------- bounty

  Future<List<Map<String, Object?>>> loadBounties() async {
    final db = await _db.db;
    return await db.query('bounties');
  }

  Future<void> saveBounties(List<Map<String, Object?>> rows) async {
    final db = await _db.db;
    for (final row in rows) {
      await db.update(
        'bounties',
        {'progress': row['progress'], 'claimed': row['claimed']},
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
  }

  // ---------------------------------------------------------------- codex

  Future<void> incrementCodexReaction(String name) async {
    final db = await _db.db;
    final rows = await db.query(
      'codex_reactions',
      where: 'id = ?',
      whereArgs: [name],
    );
    if (rows.isEmpty) return;
    final current = (rows.first['detonations'] as int?) ?? 0;
    await db.update(
      'codex_reactions',
      {'detonations': current + 1},
      where: 'id = ?',
      whereArgs: [name],
    );
  }
}

import 'dart:math' as math;

import 'package:sqflite_common/sqlite_api.dart';

import 'package:brimstone_summoning/core/security/integrity_signer.dart';

import 'package:brimstone_summoning/domain/entities/owned_card.dart';
import 'package:brimstone_summoning/domain/meta/rune_system.dart';
import 'package:brimstone_summoning/domain/meta/summoner_titles.dart';
import 'package:brimstone_summoning/domain/meta/talent_rules.dart';
import 'package:brimstone_summoning/domain/value_objects/element.dart';
import 'package:brimstone_summoning/domain/value_objects/rarity.dart';

import '../database/database_helper.dart';

/// SQLite persistence for the summoner profile, the owned card collection,
/// the active 4-card squad and every long-term meta progression track.
class PlayerRepository {
  final DatabaseHelper _db;

  /// Firma HMAC-SHA256 de los respaldos (anti-tamper).
  final IntegritySigner signer;

  PlayerRepository(this._db, {IntegritySigner? signer})
      : signer = signer ?? IntegritySigner();

  DatabaseHelper get databaseHelper => _db;

  // ------------------------------------------------------- player profile

  /// Exporta todo el progreso como un mapa serializable a JSON (Backup V2).
  Future<Map<String, dynamic>> exportBackup() async {
    final profile = await loadProfile();
    final collection = await loadCollection();
    final squad = await loadSquad();
    final runes = <String, dynamic>{};
    for (final c in collection) {
      final rune = await loadCardRune(c.instanceId);
      if (rune != null) {
        runes[c.instanceId.toString()] = {
          'runeType': rune.type.name,
          'level': rune.level,
        };
      }
    }
    final bounties = await loadBounties();
    final highestWave = await loadHighestEndlessWave();
    final clearedChapters = await loadClearedChapters();
    final lastTribute = await loadLastTributeDate();
    final talents = await loadTalentLevels();
    final challenges = await loadClearedChallenges();
    final gear = await loadGearLevels();
    final activeTitle = await loadActiveTitle();
    final stats = await loadStats();

    final payload = <String, dynamic>{
      'formatVersion': 2,
      'profile': {
        'gold': profile[0],
        'shards': profile[1],
        'energy': profile[2],
        'summonerLevel': profile[3],
        'highestEndlessWave': highestWave,
      },
      'collection': [
        for (final c in collection)
          {
            'instanceId': c.instanceId,
            'catalogId': c.catalogId,
            'name': c.name,
            'element': c.element.name,
            'rarity': c.rarity.name,
            'baseManaCost': c.baseManaCost,
            'baseAttack': c.baseAttack,
            'baseHealth': c.baseHealth,
            'level': c.level,
            'stars': c.stars,
            'skillLevel': c.skillLevel,
            'masteryXp': c.masteryXp,
          },
      ],
      'squad': squad,
      'runes': runes,
      'bounties': [
        for (final b in bounties)
          {
            'id': b['id'],
            'progress': b['progress'],
            'claimed': b['claimed'],
          },
      ],
      'chapters': clearedChapters,
      'merchant': {'lastTributeDate': lastTribute},
      'talents': talents,
      'challengesCleared': challenges,
      'gear': gear,
      'activeTitle': activeTitle,
      'stats': stats.toMap(),
    };
    // Sello de integridad: cualquier edición posterior del JSON deja de cuadrar.
    payload[IntegritySigner.signatureKey] = signer.sign(payload);
    return payload;
  }

  /// Importa y reemplaza todo el progreso desde un mapa JSON previo.
  /// Lanza [FormatException] si el payload es inválido; nunca deja la BD a
  /// medio camino (usa una única transacción).
  Future<void> importBackup(
    Map<String, dynamic> data, {
    bool allowUnsignedLegacy = false,
  }) async {
    final version = _asInt(data['formatVersion'], 1);
    if (version != 1 && version != 2) {
      throw FormatException('Formato de backup no reconocido.');
    }
    // v2 exige sello válido: un JSON editado a mano (oro, estrellas, niveles)
    // no puede entrar al perfil. v1 (legado) no tiene sello por diseño.
    if (version >= 2) {
      final signature = data[IntegritySigner.signatureKey];
      final hasSignature = signature is String && signature.isNotEmpty;
      if (!allowUnsignedLegacy || hasSignature) {
        if (!signer.verify(data)) {
          throw const FormatException(IntegritySigner.tamperMessage);
        }
      }
    }

    final profile = _asMap(data['profile']);
    final collection = _asList(data['collection']);
    final squad = _asList(data['squad']);
    final runes = _asMap(data['runes']);
    final bounties = _asList(data['bounties']);
    final chapters = _asList(data['chapters']);
    final merchant = _asMap(data['merchant']);
    final talents = _asMap(data['talents']);
    final challenges = _asList(data['challengesCleared']);
    final gear = _asMap(data['gear']);
    final stats = _asMap(data['stats']);
    final activeTitle =
        version == 2 ? _asNullableStr(data['activeTitle']) : null;

    final db = await _db.db;
    await db.transaction((txn) async {
      await txn.update(
        'player_profile',
        {
          'gold': _asInt(profile['gold'], 500),
          'shards': _asInt(profile['shards'], 100),
          'energy': _asInt(profile['energy'], 20),
          'summoner_level': _asInt(profile['summonerLevel'], 1),
          'highest_endless_wave': _asInt(profile['highestEndlessWave'], 0),
          'active_title': activeTitle,
        },
        where: "id = 'player_1'",
      );

      // Limpiar tablas progresivas.
      await txn.delete('owned_card_runes');
      await txn.delete('player_squad');
      await txn.delete('owned_cards');
      await txn.delete('summoner_talents');
      await txn.delete('challenges_cleared');
      await txn.delete('summoner_gear');
      await txn.delete('player_stats');
      await txn.delete('chapters_cleared');

      final validIds = <int>{};
      for (final raw in collection) {
        if (raw is! Map) continue;
        final iid = _asInt(raw['instanceId'], 0);
        if (iid <= 0) continue;
        validIds.add(iid);
        await txn.insert(
          'owned_cards',
          {
            'id': iid,
            'card_id': _asStr(raw['catalogId'], 'fighterX'),
            'level': _asInt(raw['level'], 1),
            'stars': _asInt(raw['stars'], 1),
            'skill_level': _asInt(raw['skillLevel'], 1),
            'mastery_xp': _asInt(raw['masteryXp'], 0),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      var slot = 0;
      for (final id in squad) {
        if (slot >= 4) break;
        final iid = _asInt(id, 0);
        if (iid > 0 && validIds.contains(iid)) {
          await txn
              .insert('player_squad', {'slot': slot, 'owned_card_id': iid});
          slot++;
        }
      }

      for (final entry in runes.entries) {
        final rune = entry.value;
        if (rune is! Map) continue;
        final iid = int.tryParse(entry.key);
        if (iid == null || !validIds.contains(iid)) continue;
        await txn.insert(
          'owned_card_runes',
          {
            'owned_card_id': iid,
            'rune_type': _asStr(rune['runeType'], 'crimsonFury'),
            'level': _asInt(rune['level'], 1),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final raw in bounties) {
        if (raw is! Map) continue;
        final bid = _asStr(raw['id'], '');
        if (bid.isEmpty) continue;
        await txn.update(
          'bounties',
          {
            'progress': _asInt(raw['progress'], 0),
            'claimed':
                (_asInt(raw['claimed'], 0) == 1 || raw['claimed'] == true)
                    ? 1
                    : 0,
          },
          where: 'id = ?',
          whereArgs: [bid],
        );
      }

      for (final entry in talents.entries) {
        final level = _asInt(entry.value, 0);
        if (level <= 0) continue;
        await txn.insert(
          'summoner_talents',
          {
            'talent_id': entry.key,
            'level':
                level > TalentRules.maxLevel ? TalentRules.maxLevel : level,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final raw in challenges) {
        if (raw is! String) continue;
        await txn.insert(
          'challenges_cleared',
          {
            'challenge_id': raw,
            'cleared_at': DateTime.now().millisecondsSinceEpoch,
            'first_win': 1,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final entry in gear.entries) {
        final level = _asInt(entry.value, 0);
        if (level <= 0) continue;
        await txn.insert(
          'summoner_gear',
          {
            'gear_id': entry.key,
            'level': level,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final raw in chapters) {
        if (raw is! String) continue;
        await txn.insert(
          'chapters_cleared',
          {
            'chapter_id': raw,
            'cleared_at': DateTime.now().millisecondsSinceEpoch,
            'first_win': 1,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final entry in stats.entries) {
        await txn.insert(
          'player_stats',
          {'stat_key': entry.key, 'stat_value': _asInt(entry.value, 0)},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      final lastTribute = merchant['lastTributeDate'];
      if (lastTribute is String && lastTribute.isNotEmpty) {
        await txn.update(
          'player_profile',
          {'last_tribute_date': lastTribute},
          where: 'id = ?',
          whereArgs: ['player_1'],
        );
      }
    });
  }

  static int _asInt(dynamic v, int fallback) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return fallback;
  }

  static String _asStr(dynamic v, String fallback) {
    if (v is String && v.isNotEmpty) return v;
    return fallback;
  }

  static String? _asNullableStr(dynamic v) {
    if (v is String && v.isNotEmpty) return v;
    return null;
  }

  static Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map) return v.map((k, value) => MapEntry('$k', value));
    return <String, dynamic>{};
  }

  static List<dynamic> _asList(dynamic v) => v is List ? v : <dynamic>[];

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
      await db.update(
        'player_profile',
        values,
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    }
  }

  /// Gasta oro/esquirlas si alcanza. Devuelve false si no hay fondos.
  Future<bool> spend({int gold = 0, int shards = 0}) async {
    final profile = await loadProfile();
    if (profile[0] < gold || profile[1] < shards) return false;
    await saveProfile(
      gold: profile[0] - gold,
      shards: profile[1] - shards,
      energy: profile[2],
      summonerLevel: profile[3],
    );
    return true;
  }

  /// Otorga oro/esquirlas.
  Future<void> grant({int gold = 0, int shards = 0}) async {
    final profile = await loadProfile();
    await saveProfile(
      gold: profile[0] + gold,
      shards: profile[1] + shards,
      energy: profile[2],
      summonerLevel: profile[3],
    );
  }

  /// Aplica los multiplicadores de oro/esquirlas del Árbol de Talentos.
  Future<Map<String, int>> grantWithTalentBonus({
    int gold = 0,
    int shards = 0,
  }) async {
    final tree = TalentTree(await loadTalentLevels());
    final boostedGold = tree.applyGoldGain(gold);
    final boostedShards = tree.applyShardsGain(shards);
    await grant(gold: boostedGold, shards: boostedShards);
    return {'gold': boostedGold, 'shards': boostedShards};
  }

  /// Añade energía al perfil.
  Future<void> addEnergy(int amount) async {
    final profile = await loadProfile();
    await saveProfile(
      gold: profile[0],
      shards: profile[1],
      energy: (profile[2] + amount).clamp(0, 9999),
      summonerLevel: profile[3],
    );
  }

  /// Añade esquirlas al perfil.
  Future<void> addShards(int amount) async {
    final profile = await loadProfile();
    await saveProfile(
      gold: profile[0],
      shards: profile[1] + amount,
      energy: profile[2],
      summonerLevel: profile[3],
    );
  }

  /// Añade oro al perfil.
  Future<void> addGold(int amount) async {
    final profile = await loadProfile();
    await saveProfile(
      gold: profile[0] + amount,
      shards: profile[1],
      energy: profile[2],
      summonerLevel: profile[3],
    );
  }

  // ---------------------------------------------------------- collection

  Future<List<OwnedCard>> loadCollection() async {
    final db = await _db.db;
    final rows = await db.rawQuery('''
      SELECT o.id AS instance_id, c.id AS catalog_id, c.name, c.element,
             c.rarity, c.base_mana_cost, c.attack, c.health, o.level, o.stars,
             o.skill_level, o.mastery_xp
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
          skillLevel: (row['skill_level'] as int?) ?? 1,
          masteryXp: (row['mastery_xp'] as int?) ?? 0,
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
      'skill_level': 1,
      'mastery_xp': 0,
    });
    return OwnedCard(
      instanceId: id,
      catalogId: catalogId,
      name: (metaRow['name'] as String?) ?? 'Luchador Corrupto',
      element: Element.values.firstWhere(
        (e) => e.name == metaRow['element'],
        orElse: () => Element.igneous,
      ),
      rarity: Rarity.values.firstWhere(
        (r) => r.name == metaRow['rarity'],
        orElse: () => Rarity.common,
      ),
      baseManaCost: (metaRow['base_mana_cost'] as int?) ?? 100,
      baseAttack: (metaRow['attack'] as int?) ?? 10,
      baseHealth: (metaRow['health'] as int?) ?? 15,
      level: 1,
      stars: 1,
      skillLevel: 1,
      masteryXp: 0,
    );
  }

  Future<void> deleteOwnedCard(int instanceId) async {
    final db = await _db.db;
    await db.delete('owned_cards', where: 'id = ?', whereArgs: [instanceId]);
    await db.delete(
      'player_squad',
      where: 'owned_card_id = ?',
      whereArgs: [instanceId],
    );
    await db.delete(
      'owned_card_runes',
      where: 'owned_card_id = ?',
      whereArgs: [instanceId],
    );
  }

  Future<void> updateOwnedCard(OwnedCard card) async {
    final db = await _db.db;
    await db.update(
      'owned_cards',
      {
        'level': card.level,
        'stars': card.stars,
        'skill_level': card.skillLevel,
        'mastery_xp': card.masteryXp,
      },
      where: 'id = ?',
      whereArgs: [card.instanceId],
    );
  }

  // -------------------------------------------------- desmantelamiento

  /// Recompensas por desmantelar: 50 esquirlas y 150 oro por estrella.
  static const int disenchantShardsPerStar = 50;
  static const int disenchantGoldPerStar = 150;

  /// Desmantela una copia duplicada: elimina la carta y entrega
  /// `50 * stars` esquirlas + `150 * stars` oro.
  ///
  /// Reglas de seguridad: la carta no puede estar en el escuadrón y el jugador
  /// debe conservar al menos [minimumRemaining] cartas después de la operación.
  /// Devuelve null si la operación no es válida.
  Future<Map<String, int>?> disenchantCopy(
    int instanceId, {
    int minimumRemaining = 4,
  }) async {
    final collection = await loadCollection();
    if (collection.length <= minimumRemaining) return null;
    final target = collection.where((c) => c.instanceId == instanceId);
    if (target.isEmpty) return null;
    final card = target.first;
    final squad = await loadSquad();
    if (squad.contains(instanceId)) return null;

    final shards = disenchantShardsPerStar * card.stars;
    final gold = disenchantGoldPerStar * card.stars;
    await deleteOwnedCard(instanceId);
    await grantWithTalentBonus(gold: gold, shards: shards);
    return {'shards': shards, 'gold': gold};
  }

  /// Devuelve true si [instanceId] se puede desmantelar con las reglas dadas.
  Future<bool> canDisenchantCopy(
    int instanceId, {
    int minimumRemaining = 4,
  }) async {
    final collection = await loadCollection();
    if (collection.length <= minimumRemaining) return false;
    if (!collection.any((c) => c.instanceId == instanceId)) return false;
    final squad = await loadSquad();
    return !squad.contains(instanceId);
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
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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

  /// Añade una runa al perfil del jugador (para el inventario de runas forjadas).
  Future<void> addRuneToProfile(RuneType runeType) async {
    final db = await _db.db;
    // Store in player_stats with key 'rune_<type>'
    await db.insert(
      'player_stats',
      {'stat_key': 'rune_${runeType.name}', 'stat_value': 1},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Mejora la runa equipada en la carta al siguiente nivel.
  Future<void> upgradeCardRune(int instanceId) async {
    final db = await _db.db;
    final rune = await loadCardRune(instanceId);
    if (rune == null) return;
    if (rune.level >= 5) return;
    await saveCardRune(
        instanceId, RuneInstance(type: rune.type, level: rune.level + 1));
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

  // --------------------------------------------------------- campaign chapters

  /// Carga los ids de los capítulos de campaña ya limpiados.
  Future<List<String>> loadClearedChapters() async {
    final db = await _db.db;
    final rows = await db.query('chapters_cleared', orderBy: 'cleared_at');
    return [for (final r in rows) r['chapter_id'] as String];
  }

  /// Carga la última fecha de tributo diario reclamada (YYYY-MM-DD) o null.
  Future<String?> loadLastTributeDate() async {
    final db = await _db.db;
    final rows = await db.query('player_profile', limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['last_tribute_date'] as String?;
  }

  /// Marca [chapterId] como limpiado y otorga las recompensas de primera
  /// victoria (con los bonos del árbol de talentos) si aún no lo estaba.
  Future<bool> markChapterCleared(
    String chapterId, {
    required int rewardGold,
    required int rewardShards,
  }) async {
    final db = await _db.db;
    final existing = await db.query(
      'chapters_cleared',
      where: 'chapter_id = ?',
      whereArgs: [chapterId],
    );
    final isFirstWin = existing.isEmpty;
    await db.insert(
      'chapters_cleared',
      {
        'chapter_id': chapterId,
        'cleared_at': DateTime.now().millisecondsSinceEpoch,
        'first_win': isFirstWin ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    if (isFirstWin) {
      await grantWithTalentBonus(gold: rewardGold, shards: rewardShards);
    }
    return isFirstWin;
  }

  /// Registra un capítulo como limpiado sin otorgar recompensas.
  Future<void> recordChapterCleared(
    String chapterId, {
    bool firstWin = false,
  }) async {
    final db = await _db.db;
    await db.insert(
      'chapters_cleared',
      {
        'chapter_id': chapterId,
        'cleared_at': DateTime.now().millisecondsSinceEpoch,
        'first_win': firstWin ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ------------------------------------------------------ talentos (v6)

  /// Niveles actuales de los 8 talentos (vacío = 0).
  Future<Map<String, int>> loadTalentLevels() async {
    final db = await _db.db;
    final rows = await db.query('summoner_talents');
    final levels = <String, int>{};
    for (final r in rows) {
      final id = r['talent_id'] as String?;
      if (id == null) continue;
      levels[id] = (r['level'] as int?) ?? 0;
    }
    return levels;
  }

  Future<void> saveTalentLevel(String talentId, int level) async {
    final db = await _db.db;
    final capped = level.clamp(0, TalentRules.maxLevel);
    await db.insert(
      'summoner_talents',
      {'talent_id': talentId, 'level': capped},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Mejora [talentId] un nivel pagando oro + esquirlas.
  /// Devuelve false si no existe, está al máximo o faltan fondos.
  Future<bool> upgradeTalent(String talentId) async {
    final levels = await loadTalentLevels();
    final current = levels[talentId] ?? 0;
    final cost = TalentRules.costFor(talentId, current);
    if (cost == null) return false;
    final paid = await spend(gold: cost.gold, shards: cost.shards);
    if (!paid) return false;
    await saveTalentLevel(talentId, current + 1);
    return true;
  }

  // ------------------------------------------------ equipamiento (v6)

  /// Niveles actuales de las 3 piezas del invocador (0 = no forjada).
  Future<Map<String, int>> loadGearLevels() async {
    final db = await _db.db;
    final rows = await db.query('summoner_gear');
    final levels = <String, int>{};
    for (final r in rows) {
      final id = r['gear_id'] as String?;
      if (id == null) continue;
      levels[id] = (r['level'] as int?) ?? 0;
    }
    return levels;
  }

  Future<void> saveGearLevel(String gearId, int level) async {
    final db = await _db.db;
    await db.insert(
      'summoner_gear',
      {'gear_id': gearId, 'level': level.clamp(0, 5)},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Forja (nivel 0→1) o mejora una pieza pagando oro + esquirlas.
  Future<bool> forgeGear(String gearId) async {
    final levels = await loadGearLevels();
    final current = levels[gearId] ?? 0;
    final cost = _gearCost(gearId, current);
    if (cost == null) return false;
    final paid = await spend(gold: cost[0], shards: cost[1]);
    if (!paid) return false;
    await saveGearLevel(gearId, current + 1);
    return true;
  }

  static List<int>? _gearCost(String gearId, int currentLevel) {
    if (currentLevel >= 5) return null;
    const pieces = {'yelmo_abisal', 'guanteletes_lanzamiento', 'amuleto_sello'};
    if (!pieces.contains(gearId)) return null;
    final next = currentLevel <= 0 ? 1 : currentLevel + 1;
    return [300 * next, 90 * next];
  }

  // ------------------------------------------------------ desafíos (v6)

  Future<List<String>> loadClearedChallenges() async {
    final db = await _db.db;
    final rows = await db.query('challenges_cleared', orderBy: 'cleared_at');
    return [for (final r in rows) r['challenge_id'] as String];
  }

  /// Marca un Desafío del Sello como superado. Devuelve true si fue la
  /// primera victoria (y por tanto se otorgó la recompensa).
  Future<bool> markChallengeCleared(
    String challengeId, {
    int rewardGold = 500,
    int rewardShards = 250,
  }) async {
    final db = await _db.db;
    final existing = await db.query(
      'challenges_cleared',
      where: 'challenge_id = ?',
      whereArgs: [challengeId],
    );
    final isFirstWin = existing.isEmpty;
    await db.insert(
      'challenges_cleared',
      {
        'challenge_id': challengeId,
        'cleared_at': DateTime.now().millisecondsSinceEpoch,
        'first_win': isFirstWin ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    if (isFirstWin) {
      await grantWithTalentBonus(gold: rewardGold, shards: rewardShards);
    }
    return isFirstWin;
  }

  // --------------------------------------------------------- título activo

  Future<String?> loadActiveTitle() async {
    final db = await _db.db;
    final rows = await db.query('player_profile', limit: 1);
    if (rows.isEmpty) return null;
    final value = rows.first['active_title'];
    return value is String && value.isNotEmpty ? value : null;
  }

  Future<void> saveActiveTitle(String? titleId) async {
    final db = await _db.db;
    await db.update(
      'player_profile',
      {'active_title': titleId},
      where: 'id = ?',
      whereArgs: ['player_1'],
    );
  }

  // ------------------------------------------------------ métricas (v6)

  /// Incrementa contadores del historial global.
  Future<void> bumpStats(Map<String, int> deltas) async {
    if (deltas.isEmpty) return;
    final db = await _db.db;
    await db.transaction((txn) async {
      for (final entry in deltas.entries) {
        if (entry.value == 0) continue;
        final rows = await txn.query(
          'player_stats',
          where: 'stat_key = ?',
          whereArgs: [entry.key],
        );
        final current =
            rows.isEmpty ? 0 : (rows.first['stat_value'] as int?) ?? 0;
        await txn.insert(
          'player_stats',
          {'stat_key': entry.key, 'stat_value': current + entry.value},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Todos los contadores crudos del historial (clave → valor).
  Future<Map<String, int>> loadRawStats() async {
    final db = await _db.db;
    final rows = await db.query('player_stats');
    return {
      for (final r in rows)
        (r['stat_key'] as String): (r['stat_value'] as int?) ?? 0,
    };
  }

  /// Lee un contador del historial (0 si no existe).
  Future<int> readStat(String key) async {
    final db = await _db.db;
    final rows = await db.query(
      'player_stats',
      where: 'stat_key = ?',
      whereArgs: [key],
    );
    if (rows.isEmpty) return 0;
    return (rows.first['stat_value'] as int?) ?? 0;
  }

  /// Escribe un valor absoluto en el historial (ajustes, preferencias).
  Future<void> writeStat(String key, int value) async {
    final db = await _db.db;
    await db.insert(
      'player_stats',
      {'stat_key': key, 'stat_value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Guarda un máximo histórico (sólo escribe si [value] supera lo actual).
  Future<void> bumpMaxStat(String key, int value) async {
    final db = await _db.db;
    final rows = await db.query(
      'player_stats',
      where: 'stat_key = ?',
      whereArgs: [key],
    );
    final current = rows.isEmpty ? 0 : (rows.first['stat_value'] as int?) ?? 0;
    if (value <= current) return;
    await db.insert(
      'player_stats',
      {'stat_key': key, 'stat_value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Historial global consolidado (contadores + tablas de progreso).
  Future<SummonerStats> loadStats() async {
    final db = await _db.db;
    final rows = await db.query('player_stats');
    final raw = <String, int>{
      for (final r in rows)
        (r['stat_key'] as String): (r['stat_value'] as int?) ?? 0,
    };
    final chapters = (await db.query('chapters_cleared')).length;
    final challenges = (await db.query('challenges_cleared')).length;
    final cards = (await db.query('owned_cards')).length;
    final endless = await loadHighestEndlessWave();

    return SummonerStats(
      combatsWon: raw['combatsWon'] ?? 0,
      bossesSlain: raw['bossesSlain'] ?? 0,
      maxHit: raw['maxHit'] ?? 0,
      bestBullseyeStreak: raw['bestBullseyeStreak'] ?? 0,
      reactions: raw['reactions'] ?? 0,
      chaptersCleared: chapters,
      challengesCleared: challenges,
      cardsOwned: cards,
      endlessRecord: endless,
      counterflicks: raw['counterflicks'] ?? 0,
    );
  }

  /// Registra el resultado de un combate en el historial global.
  Future<void> recordCombatResult({
    required bool victory,
    int damageTotal = 0,
    int maxHit = 0,
    int bullseyes = 0,
    int bestBullseyeStreak = 0,
    int reactions = 0,
    int counterflicks = 0,
    bool bossKilled = false,
  }) async {
    await bumpStats({
      if (victory) 'combatsWon': 1,
      if (victory && bossKilled) 'bossesSlain': 1,
      'reactions': reactions,
      'counterflicks': counterflicks,
      'bullseyes': bullseyes,
      'damageTotal': damageTotal,
    });
    await bumpMaxStat('maxHit', maxHit);
    await bumpMaxStat('bestBullseyeStreak', bestBullseyeStreak);
  }

  // ------------------------------------------------------------------- merchant

  /// Reclama el tributo diario del Mercader del Vacío (150 esquirlas + 400 oro)
  /// una vez por fecha de calendario. Retorna las recompensas otorgadas o null
  /// si ya se reclamó hoy. [now] es inyectable para pruebas.
  Future<Map<String, int>?> claimDailyTribute({DateTime? now}) async {
    final today = (now ?? DateTime.now()).toIso8601String().substring(0, 10);
    final db = await _db.db;
    final rows = await db.query('player_profile', limit: 1);
    if (rows.isEmpty) return null;
    final last = rows.first['last_tribute_date'] as String?;
    if (last == today) return null;
    final profile = await loadProfile();
    await saveProfile(
      gold: profile[0] + 400,
      shards: profile[1] + 150,
      energy: profile[2],
      summonerLevel: profile[3],
    );
    await db.update(
      'player_profile',
      {'last_tribute_date': today},
      where: 'id = ?',
      whereArgs: [rows.first['id']],
    );
    return {'gold': 400, 'shards': 150};
  }

  /// Transmuta 400 oro en 100 esquirlas. Retorna false si hay fondos insuficientes.
  Future<bool> transmuteGoldToShards() async {
    final profile = await loadProfile();
    if (profile[0] < 400) return false;
    await saveProfile(
      gold: profile[0] - 400,
      shards: profile[1] + 100,
      energy: profile[2],
      summonerLevel: profile[3],
    );
    return true;
  }

  /// Transmuta 100 esquirlas en 400 oro. Retorna false si hay fondos insuficientes.
  Future<bool> transmuteShardsToGold() async {
    final profile = await loadProfile();
    if (profile[1] < 100) return false;
    await saveProfile(
      gold: profile[0] + 400,
      shards: profile[1] - 100,
      energy: profile[2],
      summonerLevel: profile[3],
    );
    return true;
  }

  /// Compra un contrato de élite: 300 esquirlas por 1 copia 1★ de [catalogId].
  Future<bool> purchaseEliteContract(String catalogId) async {
    final profile = await loadProfile();
    if (profile[1] < 300) return false;
    await saveProfile(
      gold: profile[0],
      shards: profile[1] - 300,
      energy: profile[2],
      summonerLevel: profile[3],
    );
    await insertSummonedCard(catalogId);
    return true;
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

  /// Carga los 3 presets de mazos guardados.
  Future<List<Map<String, Object?>>> loadDeckPresets() async {
    final db = await _db.db;
    return await db.query('deck_presets', orderBy: 'preset_index');
  }

  /// Guarda los 3 presets de mazos.
  Future<void> saveDeckPresets(List<Map<String, Object?>> rows) async {
    final db = await _db.db;
    await db.delete('deck_presets');
    for (final row in rows) {
      await db.insert('deck_presets', row);
    }
  }

  /// Carga el progreso del Pase de Batalla.
  Future<Map<String, Object?>> loadBattlePass() async {
    final db = await _db.db;
    final rows = await db.query('battle_pass', limit: 1);
    if (rows.isEmpty) {
      return {
        'xp': 0,
        'claimedFree': [],
        'claimedPremium': [],
        'premiumUnlocked': 0
      };
    }
    final row = rows.first;
    return {
      'xp': row['xp'] ?? 0,
      'claimedFree': row['claimed_free'],
      'claimedPremium': row['claimed_premium'],
      'premiumUnlocked': row['premium_unlocked'] ?? 0,
    };
  }

  /// Guarda el progreso del Pase de Batalla.
  Future<void> saveBattlePass(Map<String, Object?> data) async {
    final db = await _db.db;
    await db.insert(
      'battle_pass',
      {
        'id': 'season_1',
        'xp': data['xp'] ?? 0,
        'claimed_free': data['claimedFree'] is List
            ? (data['claimedFree'] as List).join(',')
            : '',
        'claimed_premium': data['claimedPremium'] is List
            ? (data['claimedPremium'] as List).join(',')
            : '',
        'premium_unlocked': data['premiumUnlocked'] == true ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ---------------------------------------------------------------- codex

  /// Incrementa el contador de detonaciones de una reacción. Acepta tanto el
  /// id (`erupcion_magmatica`) como el nombre visible.
  Future<void> incrementCodexReaction(String nameOrId) async {
    final db = await _db.db;
    var rows = await db.query(
      'codex_reactions',
      where: 'id = ?',
      whereArgs: [nameOrId],
    );
    if (rows.isEmpty) {
      rows = await db.query(
        'codex_reactions',
        where: 'name = ?',
        whereArgs: [nameOrId],
      );
    }
    if (rows.isEmpty) return;
    final row = rows.first;
    final current = (row['detonations'] as int?) ?? 0;
    await db.update(
      'codex_reactions',
      {'detonations': current + 1},
      where: 'id = ?',
      whereArgs: [row['id']],
    );
  }

  /// Contadores de reacciones por id (para el Códice).
  Future<Map<String, int>> loadCodexDetonations() async {
    final db = await _db.db;
    final rows = await db.query('codex_reactions');
    return {
      for (final r in rows)
        (r['id'] as String): (r['detonations'] as int?) ?? 0,
    };
  }

  // ============================================================ RAID BOSSES (v8)

  /// Carga todos los Titanes de Raid con su HP actual.
  Future<List<Map<String, Object?>>> loadRaidBosses() async {
    final db = await _db.db;
    return await db.query('raid_bosses', orderBy: 'id');
  }

  /// Carga un Titán específico por ID.
  Future<Map<String, Object?>?> loadRaidBoss(String id) async {
    final db = await _db.db;
    final rows = await db.query(
      'raid_bosses',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  /// Aplica daño al Titán y actualiza su HP actual en SQLite.
  /// Retorna true si el Titán fue abatido (current_hp <= 0).
  Future<bool> dealDamageToRaidBoss(String id, int damage) async {
    final db = await _db.db;
    final boss = await loadRaidBoss(id);
    if (boss == null) return false;
    final currentHp = (boss['current_hp'] as int?) ?? 0;
    final newHp = math.max(0, currentHp - damage);
    final isDefeated = newHp <= 0;
    await db.update(
      'raid_bosses',
      {
        'current_hp': newHp,
        'last_updated': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    return isDefeated;
  }

  /// Resetea el Titán a HP completo y sube su nivel de Ascensión (+1).
  Future<void> ascendRaidBoss(String id) async {
    final db = await _db.db;
    final boss = await loadRaidBoss(id);
    if (boss == null) return;
    final baseHp = (boss['base_hp'] as int?) ?? 0;
    final ascension = ((boss['ascension_level'] as int?) ?? 0) + 1;
    // Escala x1.8 por nivel de Ascensión.
    final newHp = (baseHp * math.pow(1.8, ascension)).round();
    await db.update(
      'raid_bosses',
      {
        'current_hp': newHp,
        'ascension_level': ascension,
        'last_updated': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============================================================ GACHA STATE (v8)

  /// Carga el estado del Gacha (pity counter, banner activo, invocación gratuita diaria).
  Future<Map<String, Object?>> loadGachaState() async {
    final db = await _db.db;
    final rows = await db.query('gacha_state',
        where: 'id = ?', whereArgs: ['gacha_state'], limit: 1);
    if (rows.isEmpty) {
      return {
        'pityCounter': 0,
        'activeBanner': 'general',
        'lastFreeSummonDate': null,
        'dailySummonsToday': 0,
      };
    }
    return rows.first;
  }

  /// Guarda el estado del Gacha.
  Future<void> saveGachaState(Map<String, Object?> data) async {
    final db = await _db.db;
    await db.update(
      'gacha_state',
      {
        'pity_counter': data['pityCounter'] ?? 0,
        'active_banner': data['activeBanner'] ?? 'general',
        'last_free_summon_date': data['lastFreeSummonDate'],
        'daily_summons_today': data['dailySummonsToday'] ?? 0,
      },
      where: 'id = ?',
      whereArgs: ['gacha_state'],
    );
  }

  /// Verifica si la invocación gratuita diaria está disponible.
  Future<bool> isFreeSummonAvailable() async {
    final state = await loadGachaState();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final lastFree = state['lastFreeSummonDate'] as String?;
    return lastFree != today;
  }

  /// Marca la invocación gratuita diaria como usada.
  Future<void> markFreeSummonUsed() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await saveGachaState({
      'pityCounter': 0,
      'activeBanner': 'general',
      'lastFreeSummonDate': today,
      'dailySummonsToday': 0,
    });
  }

  /// Incrementa el pity counter y verifica si se garantiza una Legendaria.
  /// Retorna true si la siguiente invocación es garantizada Legendaria (pity >= 20).
  Future<bool> incrementPityAndCheckGuaranteed() async {
    final state = await loadGachaState();
    final pity = (state['pityCounter'] as int?) ?? 0;
    final newPity = pity + 1;
    final guaranteed = newPity >= 20;
    await saveGachaState({
      'pityCounter': guaranteed ? 0 : newPity,
      'activeBanner': state['activeBanner'],
      'lastFreeSummonDate': state['lastFreeSummonDate'],
      'dailySummonsToday': state['dailySummonsToday'],
    });
    return guaranteed;
  }

  /// Cambia el banner activo y resetea el pity counter.
  Future<void> setActiveBanner(String bannerId) async {
    await saveGachaState({
      'pityCounter': 0,
      'activeBanner': bannerId,
      'lastFreeSummonDate': null,
      'dailySummonsToday': 0,
    });
  }

  // ============================================================ REDEEMED CODES (v8)

  /// Verifica si un código promocional ya fue canjeado.
  Future<bool> isCodeRedeemed(String code) async {
    final db = await _db.db;
    final rows = await db.query(
      'redeemed_codes',
      where: 'code = ?',
      whereArgs: [code],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Canjea un código promocional. Retorna el mapa de recompensas o null si ya fue canjeado.
  Future<Map<String, int>?> redeemCode(String code) async {
    final db = await _db.db;
    final already = await isCodeRedeemed(code);
    if (already) return null;
    final upper = code.toUpperCase();
    Map<String, int> rewards;
    switch (upper) {
      case 'HELLFIRE2026':
        rewards = {'shards': 1000, 'gold': 2500};
        break;
      case 'BRIMSTONEVIP':
        rewards = {
          'shards': 500,
          'gold': 0,
          'card': 1
        }; // card handled separately
        break;
      case 'VOIDLORD':
        rewards = {
          'shards': 500,
          'gold': 0,
          'card': 2
        }; // card handled separately
        break;
      case 'AUTOBATTLE':
        rewards = {'gold': 3000, 'shards': 300};
        break;
      default:
        return null;
    }
    await db.insert('redeemed_codes', {
      'code': upper,
      'redeemed_at': DateTime.now().millisecondsSinceEpoch,
    });
    return rewards;
  }

  /// Otorga la carta de recompensa por código canjeado.
  Future<void> grantPromoCard(String cardId) async {
    await insertSummonedCard(cardId);
  }
}

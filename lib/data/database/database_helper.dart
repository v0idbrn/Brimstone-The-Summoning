import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static Database? _db;
  static const int version = 2;

  Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    sqfliteFfiInit();
    final docs = await getApplicationDocumentsDirectory();
    final path = '${docs.path}/brimstone.db';
    return await openDatabase(
      path,
      version: version,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Fresh v2 schema: drop and reseed (pre-release data is disposable).
    await db.execute('DROP TABLE IF EXISTS cards');
    await db.execute('DROP TABLE IF EXISTS relics');
    await db.execute('DROP TABLE IF EXISTS player_profile');
    await db.execute('DROP TABLE IF EXISTS owned_cards');
    await db.execute('DROP TABLE IF EXISTS player_squad');
    await _onCreate(db, newVersion);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute(
      'CREATE TABLE cards(id TEXT PRIMARY KEY, name TEXT, element TEXT, rarity TEXT, base_mana_cost INTEGER, attack INTEGER, health INTEGER, stars INTEGER, active_skill TEXT)',
    );
    await db.execute(
      'CREATE TABLE relics(id TEXT PRIMARY KEY, name TEXT, description TEXT, effect_value REAL)',
    );
    await db.execute(
      'CREATE TABLE player_profile(id TEXT PRIMARY KEY, gold INTEGER, shards INTEGER, max_hp INTEGER, current_hp INTEGER, energy INTEGER DEFAULT 20, summoner_level INTEGER DEFAULT 1)',
    );
    await db.execute(
      'CREATE TABLE owned_cards(id INTEGER PRIMARY KEY AUTOINCREMENT, card_id TEXT, level INTEGER DEFAULT 1, stars INTEGER DEFAULT 1)',
    );
    await db.execute(
      'CREATE TABLE player_squad(slot INTEGER PRIMARY KEY, owned_card_id INTEGER)',
    );
    await _seedCatalog(db);
  }

  Future<void> _seedCatalog(Database db) async {
    final cards = <Map<String, dynamic>>[
      {
        'id': 'ignis_hound',
        'name': 'Sabueso de Azufre',
        'element': 'igneous',
        'rarity': 'common',
        'base_mana_cost': 100,
        'attack': 10,
        'health': 15,
        'stars': 1,
        'active_skill':
            'Lanza 3 mordiscos ígneos a dianas aleatorias y aplica aura Ígnea.',
      },
      {
        'id': 'ignis_lord',
        'name': 'Ignis, Señor de la Forja',
        'element': 'igneous',
        'rarity': 'epic',
        'base_mana_cost': 140,
        'attack': 20,
        'health': 30,
        'stars': 2,
        'active_skill': 'Invoca un meteoro colosal que golpea todas las dianas con daño 3.5x y aura Ígnea.',
      },
      {
        'id': 'abyss_stalker',
        'name': 'Acechador de Escarcha',
        'element': 'abyssal',
        'rarity': 'common',
        'base_mana_cost': 95,
        'attack': 12,
        'health': 14,
        'stars': 1,
        'active_skill':
            'Estaca glacial que inflige daño 2.4x y aplica aura Abisal.',
      },
      {
        'id': 'abyss_leviathan',
        'name': 'Leviatán del Foso',
        'element': 'abyssal',
        'rarity': 'legendary',
        'base_mana_cost': 150,
        'attack': 25,
        'health': 45,
        'stars': 3,
        'active_skill': 'Congela el movimiento de todas las dianas por 4.5s, limpia proyectiles enemigos y aplica aura Abisal.',
      },
      {
        'id': 'terra_golem',
        'name': 'Gólem de Basalto',
        'element': 'telluric',
        'rarity': 'common',
        'base_mana_cost': 100,
        'attack': 8,
        'health': 25,
        'stars': 1,
        'active_skill': 'Otorga un escudo de piedra que absorbe el próximo golpe del jefe y aplica aura Telúrica.',
      },
      {
        'id': 'terra_titan',
        'name': 'Titán Quiebramundos',
        'element': 'telluric',
        'rarity': 'epic',
        'base_mana_cost': 135,
        'attack': 18,
        'health': 40,
        'stars': 2,
        'active_skill': 'Terremoto que aturde al jefe por 3.0s, agranda el tamaño de las dianas un 35% y aplica aura Telúrica.',
      },
      {
        'id': 'void_specter',
        'name': 'Espectro del Sello',
        'element': 'void',
        'rarity': 'rare',
        'base_mana_cost': 110,
        'attack': 15,
        'health': 20,
        'stars': 1,
        'active_skill': 'Golpe sombrío que roba vida al jefe y sube en +1 nivel dos esferas aleatorias de tu bandeja.',
      },
      {
        'id': 'void_malakor',
        'name': 'Malakor, Heraldo Abisal',
        'element': 'void',
        'rarity': 'legendary',
        'base_mana_cost': 160,
        'attack': 30,
        'health': 50,
        'stars': 3,
        'active_skill': 'Abre una grieta que transforma toda tu bandeja a esferas Nivel 3 y aplica aura de Vacío.',
      },
    ];
    for (final c in cards) {
      await db.insert('cards', c);
    }
    final relics = <Map<String, dynamic>>[
      {
        'id': 'ceniza_volatil',
        'name': 'Ceniza Volátil',
        'description': 'Las esferas Ígneas spawnean directamente en Nivel 2 con un 35% de probabilidad.',
        'effect_value': 0.35,
      },
      {
        'id': 'ojo_abismo',
        'name': 'Ojo del Abismo',
        'description':
            'El radio del Bullseye crítico en todas las dianas aumenta un 40%.',
        'effect_value': 0.40,
      },
      {
        'id': 'sello_resonancia',
        'name': 'Sello de Resonancia',
        'description': 'Detonar cualquier Reacción Elemental devuelve 20 de maná a todas tus cartas.',
        'effect_value': 20.0,
      },
      {
        'id': 'pacto_sangre',
        'name': 'Pacto de Sangre',
        'description': 'Tus cartas cargan maná un 50% más rápido, pero empezás cada nodo perdiendo un 8% de vida máxima.',
        'effect_value': 0.50,
      },
      {
        'id': 'forja_perpetua',
        'name': 'Forja Perpetua',
        'description': 'Al fusionar dos esferas de Nivel 1, tenés un 25% de probabilidad de que salten directamente a Nivel 3.',
        'effect_value': 0.25,
      },
      {
        'id': 'coraza_obsidiana',
        'name': 'Coraza de Obsidiana',
        'description': 'Destruir un proyectil enemigo con Counter-Flick te cura un 4% de vida y genera una esfera de Nivel 2.5.',
        'effect_value': 0.04,
      },
    ];
    for (final r in relics) {
      await db.insert('relics', r);
    }
    await db.insert('player_profile', {
      'id': 'player_1',
      'gold': 500,
      'shards': 100,
      'max_hp': 100,
      'current_hp': 100,
      'energy': 20,
      'summoner_level': 1,
    });
  }
}

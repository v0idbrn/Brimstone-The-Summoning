import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// SQLite schema owner for Brimstone: The Summoning.
///
/// Cada instancia mantiene su propia conexión ([_db] ya no es estático), de
/// modo que dos tests pueden abrir bases distintas en paralelo sin
/// contención del archivo. Para tests se puede usar [useInMemory] o un
/// archivo único por suite con [setOverridePath].
class DatabaseHelper {
  /// Schema actual: v6 añade talentos, desafíos, equipamiento del invocador
  /// y el historial global de métricas.
  static const int version = 6;

  /// Ruta por defecto para las instancias creadas después de esta llamada.
  static String? _overridePath;

  /// Contador para generar nombres de archivo únicos en tests.
  static int _testPathCounter = 0;

  final String? _path;
  Database? _db;

  DatabaseHelper({String? path}) : _path = path ?? _overridePath;

  /// Fija la ruta para las nuevas instancias (null = ruta real de la app).
  ///
  /// Acepta [inMemoryDatabasePath] (':memory:') o una ruta de archivo. No
  /// afecta a instancias ya construidas.
  static void setOverridePath(String? path) {
    _overridePath = path;
  }

  /// Configura las nuevas instancias para usar una base en memoria.
  static void useInMemory() {
    _overridePath = inMemoryDatabasePath;
  }

  /// Genera una ruta de archivo única (bajo el directorio temporal) pensada
  /// para aislar suites de tests entre sí.
  static String uniqueTestPath([String prefix = 'brimstone_test']) {
    _testPathCounter++;
    final stamp = DateTime.now().microsecondsSinceEpoch;
    return p.join(
      Directory.systemTemp.path,
      '${prefix}_${stamp}_$_testPathCounter.db',
    );
  }

  bool get _isMemory => _path == inMemoryDatabasePath;

  Future<Database> get db async => _db ??= await _initDb();

  Future<Database> _initDb() async {
    sqfliteFfiInit();
    final String path;
    if (_path != null) {
      path = _path;
    } else {
      final docs = await getApplicationDocumentsDirectory();
      path = p.join(docs.path, 'brimstone.db');
    }
    return openDatabase(
      path,
      version: version,
      singleInstance: !_isMemory,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Cierra la conexión de esta instancia (necesario en tests para liberar el
  /// archivo antes de borrarlo).
  Future<void> close() async {
    final database = _db;
    _db = null;
    if (database == null) return;
    if (!database.isOpen) return;
    await database.close();
  }

  /// Borra el archivo de la base si esta instancia usa uno y no es memoria.
  Future<void> deleteDatabaseFile() async {
    await close();
    if (_path == null || _isMemory) return;
    final file = File(_path);
    if (await file.exists()) {
      try {
        await file.delete();
      } on FileSystemException {
        // El archivo puede estar en uso por otra conexión; los tests usan
        // rutas únicas, así que ignorar es seguro.
      }
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Pre-release: el progreso local es desechable, se recrea el esquema.
    const tables = [
      'cards',
      'relics',
      'player_profile',
      'owned_cards',
      'player_squad',
      'owned_card_runes',
      'bounties',
      'codex_reactions',
      'chapters_cleared',
      'summoner_talents',
      'challenges_cleared',
      'summoner_gear',
      'player_stats',
    ];
    for (final table in tables) {
      await db.execute('DROP TABLE IF EXISTS $table');
    }
    await _onCreate(db, newVersion);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute(
      'CREATE TABLE cards(id TEXT PRIMARY KEY, name TEXT, element TEXT, '
      'rarity TEXT, base_mana_cost INTEGER, attack INTEGER, health INTEGER, '
      'stars INTEGER, active_skill TEXT)',
    );
    await db.execute(
      'CREATE TABLE relics(id TEXT PRIMARY KEY, name TEXT, description TEXT, '
      'effect_value REAL)',
    );
    await db.execute(
      'CREATE TABLE player_profile(id TEXT PRIMARY KEY, gold INTEGER, '
      'shards INTEGER, max_hp INTEGER, current_hp INTEGER, '
      'energy INTEGER DEFAULT 20, summoner_level INTEGER DEFAULT 1, '
      'highest_endless_wave INTEGER DEFAULT 0, last_tribute_date TEXT, '
      'active_title TEXT)',
    );
    await db.execute(
      'CREATE TABLE owned_cards(id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'card_id TEXT, level INTEGER DEFAULT 1, stars INTEGER DEFAULT 1)',
    );
    await db.execute(
      'CREATE TABLE player_squad(slot INTEGER PRIMARY KEY, '
      'owned_card_id INTEGER)',
    );
    await db.execute(
      'CREATE TABLE owned_card_runes(owned_card_id INTEGER PRIMARY KEY, '
      'rune_type TEXT NOT NULL, level INTEGER DEFAULT 1)',
    );
    await db.execute(
      'CREATE TABLE bounties(id TEXT PRIMARY KEY, title TEXT, description TEXT, '
      'kind TEXT, target INTEGER, reward_shards INTEGER, reward_gold INTEGER, '
      'progress INTEGER DEFAULT 0, claimed INTEGER DEFAULT 0)',
    );
    await db.execute(
      'CREATE TABLE codex_reactions(id TEXT PRIMARY KEY, name TEXT, '
      'description TEXT, trigger TEXT, detonations INTEGER DEFAULT 0)',
    );
    await db.execute(
      'CREATE TABLE chapters_cleared(chapter_id TEXT PRIMARY KEY, '
      'cleared_at INTEGER NOT NULL, first_win INTEGER DEFAULT 0)',
    );
    // v6: Árbol de Talentos del Invocador.
    await db.execute(
      'CREATE TABLE summoner_talents(talent_id TEXT PRIMARY KEY, '
      'level INTEGER NOT NULL DEFAULT 0)',
    );
    // v6: Desafíos del Sello superados.
    await db.execute(
      'CREATE TABLE challenges_cleared(challenge_id TEXT PRIMARY KEY, '
      'cleared_at INTEGER NOT NULL, first_win INTEGER DEFAULT 0)',
    );
    // v6: Equipamiento permanente del Invocador (nivel 0 = no forjado).
    await db.execute(
      'CREATE TABLE summoner_gear(gear_id TEXT PRIMARY KEY, '
      'level INTEGER NOT NULL DEFAULT 0)',
    );
    // v6: Historial global de métricas (contadores clave/valor).
    await db.execute(
      'CREATE TABLE player_stats(stat_key TEXT PRIMARY KEY, '
      'stat_value INTEGER NOT NULL DEFAULT 0)',
    );

    await _seedCatalog(db);
    await _seedRelics(db);
    await _seedBounties(db);
    await _seedCodexReactions(db);
  }

  Future<void> _seedCatalog(Database db) async {
    final cards = <Map<String, Object?>>[
      // ------------------------------------------------------------- Ígneas
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
        'active_skill':
            'Invoca un meteoro colosal que golpea todas las dianas con daño 3.5x y aura Ígnea.',
      },
      {
        'id': 'ignis_drake',
        'name': 'Draco de Escoria',
        'element': 'igneous',
        'rarity': 'rare',
        'base_mana_cost': 110,
        'attack': 14,
        'health': 18,
        'stars': 1,
        'active_skill':
            'Ráfaga de escoria ígnea: daño 1.8x a una diana y aplica aura Ígnea.',
      },
      {
        'id': 'ignis_seraph',
        'name': 'Serafín Carbonizado',
        'element': 'igneous',
        'rarity': 'epic',
        'base_mana_cost': 150,
        'attack': 22,
        'health': 32,
        'stars': 2,
        'active_skill':
            'Descendencia de ceniza: daño 3.0x a todas las dianas y aura Ígnea intensa.',
      },
      {
        'id': 'ignis_colossus',
        'name': 'Vulcanor, Rey del Cráter',
        'element': 'igneous',
        'rarity': 'legendary',
        'base_mana_cost': 180,
        'attack': 32,
        'health': 55,
        'stars': 3,
        'active_skill':
            'Erupción del cráter: daño 4.5x, aura Ígnea y aturde al jefe 2.0s.',
      },
      // ----------------------------------------------------------- Abisales
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
        'active_skill':
            'Congela todas las dianas 4.5s, limpia proyectiles y aplica aura Abisal.',
      },
      {
        'id': 'abyss_siren',
        'name': 'Sirena de Escarcha',
        'element': 'abyssal',
        'rarity': 'rare',
        'base_mana_cost': 105,
        'attack': 13,
        'health': 17,
        'stars': 1,
        'active_skill':
            'Canto glacial: daño 1.8x, congela 2.0s y aplica aura Abisal.',
      },
      {
        'id': 'abyss_kraken',
        'name': 'Kraken de la Fosa',
        'element': 'abyssal',
        'rarity': 'epic',
        'base_mana_cost': 145,
        'attack': 21,
        'health': 35,
        'stars': 2,
        'active_skill':
            'Tentáculos abisales: daño 2.8x a todas las dianas y aura Abisal.',
      },
      {
        'id': 'abyss_wraith',
        'name': 'Espectro Glacial',
        'element': 'abyssal',
        'rarity': 'legendary',
        'base_mana_cost': 170,
        'attack': 30,
        'health': 48,
        'stars': 3,
        'active_skill':
            'Lamento glacial: daño 3.6x, congela 4.0s y aplica aura Abisal.',
      },
      // ---------------------------------------------------------- Telúricas
      {
        'id': 'terra_golem',
        'name': 'Gólem de Basalto',
        'element': 'telluric',
        'rarity': 'common',
        'base_mana_cost': 100,
        'attack': 8,
        'health': 25,
        'stars': 1,
        'active_skill':
            'Escudo de piedra que absorbe el próximo golpe y aura Telúrica.',
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
        'active_skill':
            'Terremoto que aturde 3.0s, agranda dianas un 35% y aura Telúrica.',
      },
      {
        'id': 'terra_warden',
        'name': 'Guardián de Obsidiana',
        'element': 'telluric',
        'rarity': 'rare',
        'base_mana_cost': 105,
        'attack': 11,
        'health': 24,
        'stars': 1,
        'active_skill':
            'Piel de obsidiana: escudo que absorbe el próximo golpe y aura Telúrica.',
      },
      {
        'id': 'terra_hydra',
        'name': 'Hidra de Raíz Pétrea',
        'element': 'telluric',
        'rarity': 'epic',
        'base_mana_cost': 140,
        'attack': 19,
        'health': 38,
        'stars': 2,
        'active_skill':
            'Múltiples cabezas: daño 2.6x a todas las dianas y aura Telúrica.',
      },
      {
        'id': 'terra_behemoth',
        'name': 'Behemot Rompecumbres',
        'element': 'telluric',
        'rarity': 'legendary',
        'base_mana_cost': 175,
        'attack': 28,
        'health': 52,
        'stars': 3,
        'active_skill':
            'Temblor de la tierra: daño 4.0x, aturde 2.5s y aura Telúrica.',
      },
      // ------------------------------------------------------------- Vacío
      {
        'id': 'void_specter',
        'name': 'Espectro del Sello',
        'element': 'void',
        'rarity': 'rare',
        'base_mana_cost': 110,
        'attack': 15,
        'health': 20,
        'stars': 1,
        'active_skill':
            'Golpe sombrío que roba vida y sube +1 nivel dos esferas de tu bandeja.',
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
        'active_skill':
            'Abre una grieta que transforma la bandeja a Nivel 3 y aura de Vacío.',
      },
      {
        'id': 'void_reaper',
        'name': 'Segador Astral',
        'element': 'void',
        'rarity': 'rare',
        'base_mana_cost': 115,
        'attack': 16,
        'health': 19,
        'stars': 1,
        'active_skill':
            'Hoja del vacío: daño 2.0x, drena vida y aplica aura de Vacío.',
      },
      {
        'id': 'void_oracle',
        'name': 'Oráculo del Eclipse',
        'element': 'void',
        'rarity': 'epic',
        'base_mana_cost': 155,
        'attack': 24,
        'health': 34,
        'stars': 2,
        'active_skill':
            'Eclipse lunar: daño 3.2x a todas las dianas y aura de Vacío.',
      },
      {
        'id': 'void_archon',
        'name': "Xal'atoh, Arconte del Vacío",
        'element': 'void',
        'rarity': 'legendary',
        'base_mana_cost': 185,
        'attack': 34,
        'health': 58,
        'stars': 3,
        'active_skill':
            'Juicio del Arconte: daño 4.8x, vulnera al jefe y aura de Vacío.',
      },
    ];
    for (final c in cards) {
      await db.insert('cards', c);
    }

    await db.insert('player_profile', {
      'id': 'player_1',
      'gold': 500,
      'shards': 100,
      'max_hp': 100,
      'current_hp': 100,
      'energy': 20,
      'summoner_level': 1,
      'highest_endless_wave': 0,
    });
  }

  Future<void> _seedRelics(Database db) async {
    // 18 Reliquias Abisales (ids espejo de RelicCatalog).
    final relics = <Map<String, Object?>>[
      {
        'id': 'ceniza_volatil',
        'name': 'Ceniza Volátil',
        'description': 'Esferas Ígneas aparecen en Nivel 2 con 35%.',
        'effect_value': 0.35,
      },
      {
        'id': 'ojo_abismo',
        'name': 'Ojo del Abismo',
        'description': 'Radio del Bullseye +40%.',
        'effect_value': 0.40,
      },
      {
        'id': 'sello_resonancia',
        'name': 'Sello de Resonancia',
        'description': 'Detonar una reacción devuelve 20 de maná.',
        'effect_value': 20.0,
      },
      {
        'id': 'pacto_sangre',
        'name': 'Pacto de Sangre',
        'description': 'Maná +50% rápido, -8% HP al iniciar nodo.',
        'effect_value': 0.50,
      },
      {
        'id': 'forja_perpetua',
        'name': 'Forja Perpetua',
        'description': 'Fusionar N1 tiene 25% de saltar a N3.',
        'effect_value': 0.25,
      },
      {
        'id': 'coraza_obsidiana',
        'name': 'Coraza de Obsidiana',
        'description': 'Counter-Flick cura 4% de vida.',
        'effect_value': 0.04,
      },
      {
        'id': 'prisma_caos',
        'name': 'Prisma del Caos',
        'description':
            'Esferas Prismáticas comodín que fusionan con cualquier elemento.',
        'effect_value': 0.15,
      },
      {
        'id': 'reloj_ceniza',
        'name': 'Reloj de Ceniza',
        'description': '+2s de duración de aura.',
        'effect_value': 2.0,
      },
      {
        'id': 'colmillo_vampirico',
        'name': 'Colmillo Vampírico',
        'description': 'Bullseye cura +2% de vida máxima.',
        'effect_value': 0.02,
      },
      {
        'id': 'sello_sobrecarga',
        'name': 'Sello de Sobrecarga',
        'description': 'La carta Líder arranca con 100% de maná.',
        'effect_value': 1.0,
      },
      {
        'id': 'esencia_abismo',
        'name': 'Esencia del Abismo',
        'description': 'Todas las esferas ganan +1 nivel base.',
        'effect_value': 1.0,
      },
      {
        'id': 'corazon_phoenix',
        'name': 'Corazón de Fénix',
        'description': 'Revives una vez con 30% de vida.',
        'effect_value': 0.30,
      },
      {
        'id': 'grimorio_antiguo',
        'name': 'Grimorio Antiguo',
        'description': 'Habilidades -20% maná y +15% efecto.',
        'effect_value': 0.20,
      },
      {
        'id': 'tunica_vacio',
        'name': 'Túnica del Vacío',
        'description': 'Recibes -15% daño.',
        'effect_value': 0.15,
      },
      {
        'id': 'martillo_titan',
        'name': 'Martillo del Titán',
        'description': 'Fusiones mínimo N2; N3 con 50%.',
        'effect_value': 0.50,
      },
      {
        'id': 'cadenas_sello',
        'name': 'Cadenas del Sello',
        'description': 'Jefes aturdidos 2s y ataques 25% más lentos.',
        'effect_value': 0.25,
      },
      {
        'id': 'llama_eterna',
        'name': 'Llama Eterna',
        'description': 'Esferas Ígneas sobreviven al impacto un 20%.',
        'effect_value': 0.20,
      },
      {
        'id': 'sombra_perdida',
        'name': 'Sombra Perdida',
        'description': '+1 esquirlas y +25% crítico Abisal.',
        'effect_value': 0.25,
      },
    ];
    for (final r in relics) {
      await db.insert('relics', r);
    }
  }

  Future<void> _seedBounties(Database db) async {
    final bounties = <Map<String, Object?>>[
      {
        'id': 'forge_master',
        'title': 'Maestro de la Forja',
        'description': 'Fusiona 25 esferas a Nivel 3.',
        'kind': 'merge_to_three',
        'target': 25,
        'reward_shards': 150,
        'reward_gold': 0,
        'progress': 0,
        'claimed': 0,
      },
      {
        'id': 'hawk_eye',
        'title': 'Ojo de Halcón',
        'description': 'Conecta 15 impactos críticos Bullseye.',
        'kind': 'bullseye_hits',
        'target': 15,
        'reward_shards': 150,
        'reward_gold': 0,
        'progress': 0,
        'claimed': 0,
      },
      {
        'id': 'elemental_alchemist',
        'title': 'Alquimista Elemental',
        'description': 'Detona 10 Reacciones Elementales.',
        'kind': 'reactions',
        'target': 10,
        'reward_shards': 200,
        'reward_gold': 0,
        'progress': 0,
        'claimed': 0,
      },
      {
        'id': 'spell_breaker',
        'title': 'Rompe-Hechizos',
        'description': 'Destruye 10 orbes enemigos con Counter-Flick.',
        'kind': 'counterflicks',
        'target': 10,
        'reward_shards': 0,
        'reward_gold': 300,
        'progress': 0,
        'claimed': 0,
      },
      {
        'id': 'dark_ascension',
        'title': 'Ascensión Oscura',
        'description': 'Evoluciona cualquier carta en el Altar.',
        'kind': 'evolution',
        'target': 1,
        'reward_shards': 250,
        'reward_gold': 0,
        'progress': 0,
        'claimed': 0,
      },
      {
        'id': 'rift_conqueror',
        'title': 'Conquistador de la Grieta',
        'description':
            'Completa una Incursión de Grieta venciendo al Jefe del Piso 7.',
        'kind': 'rift_clear',
        'target': 1,
        'reward_shards': 500,
        'reward_gold': 1000,
        'progress': 0,
        'claimed': 0,
      },
    ];
    for (final b in bounties) {
      await db.insert('bounties', b);
    }
  }

  Future<void> _seedCodexReactions(Database db) async {
    final reactions = <Map<String, Object?>>[
      {
        'id': 'erupcion_magmatica',
        'name': 'Erupción Magmática',
        'description':
            'Ígnea + Abisal: daño en área a todas las dianas y explosión de fuego.',
        'trigger': 'Aura Ígnea + impacto Abisal',
        'detonations': 0,
      },
      {
        'id': 'choque_termico',
        'name': 'Choque Térmico',
        'description': 'Abisal + Telúrica: restaura maná a todas las cartas.',
        'trigger': 'Aura Abisal + impacto Telúrico',
        'detonations': 0,
      },
      {
        'id': 'petrificacion_abisal',
        'name': 'Petrificación Abisal',
        'description':
            'Telúrica + Vacío: congela las dianas y retrasa el ataque del jefe.',
        'trigger': 'Aura Telúrica + impacto Vacío',
        'detonations': 0,
      },
      {
        'id': 'colapso_del_sello',
        'name': 'Colapso del Sello',
        'description':
            'Vacío + Ígnea: cura al jugador y deja al jefe vulnerable.',
        'trigger': 'Aura Vacío + impacto Ígneo',
        'detonations': 0,
      },
    ];
    for (final r in reactions) {
      await db.insert('codex_reactions', r);
    }
  }
}

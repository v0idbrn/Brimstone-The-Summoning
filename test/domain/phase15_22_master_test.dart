import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:brimstone_summoning/core/audio/procedural_sfx_engine.dart';
import 'package:brimstone_summoning/data/database/database_helper.dart';
import 'package:brimstone_summoning/data/repositories/player_repository.dart';
import 'package:brimstone_summoning/domain/combat/combat_engine.dart';
import 'package:brimstone_summoning/domain/combat/combat_models.dart';
import 'package:brimstone_summoning/domain/meta/seal_challenge_rules.dart';
import 'package:brimstone_summoning/domain/meta/summoner_gear.dart';
import 'package:brimstone_summoning/domain/meta/summoner_titles.dart';
import 'package:brimstone_summoning/domain/meta/talent_rules.dart';
import 'package:brimstone_summoning/domain/roguelite/abyssal_events.dart';
import 'package:brimstone_summoning/domain/roguelite/relic_catalog.dart';
import 'package:brimstone_summoning/domain/value_objects/element.dart';
import 'package:brimstone_summoning/domain/value_objects/orb_level.dart';

/// REPOSITORIO Y BASE AISLADA ------------------------------------------------

DatabaseHelper freshHelper() {
  DatabaseHelper.useInMemory();
  return DatabaseHelper();
}

PlayerRepository freshRepo() => PlayerRepository(freshHelper());

ManaCard manaCard({
  String id = 'ignis_hound',
  Element element = Element.igneous,
  int stars = 1,
  int manaCost = 100,
  double attack = 10,
}) =>
    ManaCard(
      id: id,
      name: id,
      element: element,
      baseManaCost: manaCost,
      attack: attack,
      stars: stars,
    );

CombatEngine buildEngine({
  BossConfig boss = BossConfig.pyroth,
  List<ManaCard>? cards,
  CombatModifiers modifiers = const CombatModifiers(),
  List<SealMutator> mutators = const [],
  Map<String, int> talents = const {},
  Map<String, int> gear = const {},
  int seed = 42,
  bool trainingMode = false,
}) =>
    CombatEngine(
      boss: boss,
      cards: cards ?? [manaCard()],
      playerMaxHp: 100,
      modifiers: modifiers,
      random: math.Random(seed),
      talentLevels: talents,
      summonerGear: gear,
      mutators: mutators,
      trainingMode: trainingMode,
    );

CombatTarget buildTarget({double angularSpeed = 1.0}) => CombatTarget(
      id: 't1',
      trajectory: TargetTrajectory.orbital,
      cx: 500.0,
      cy: 200.0,
      amplitude: 0.0,
      baseAngularSpeed: angularSpeed,
    );

double hitDamage(CombatEngine engine, HitKind kind, OrbLevel level) {
  final beforeTotal = engine.damageTotal;
  engine.registerDamage(
    orb: CombatOrb(id: 'o', element: Element.igneous, level: level),
    target: buildTarget(),
    multiplier: 1.0,
    kind: kind,
  );
  return (engine.damageTotal - beforeTotal).toDouble();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // =========================================================== MÓDULO 0
  group('Módulo 0 — SQLite sin bloqueos', () {
    test('el esquema actual es v11', () {
      expect(DatabaseHelper.version, 11);
    });

    test('crea las 15 tablas del esquema v7', () async {
      final db = await freshHelper().db;
      final rows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      final names = {for (final r in rows) r['name'] as String};
      for (final table in [
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
        'deck_presets',
        'battle_pass',
      ]) {
        expect(names, contains(table), reason: 'falta la tabla $table');
      }
    });

    test('dos bases en memoria son independientes', () async {
      final a = PlayerRepository(freshHelper());
      final b = PlayerRepository(freshHelper());
      await a.saveProfile(gold: 9999, shards: 1, energy: 20, summonerLevel: 1);
      expect((await a.loadProfile())[0], 9999);
      expect((await b.loadProfile())[0], 500);
    });

    test('uniqueTestPath devuelve rutas distintas para tests paralelos', () {
      final first = DatabaseHelper.uniqueTestPath();
      final second = DatabaseHelper.uniqueTestPath();
      expect(first, isNot(equals(second)));
      expect(first.contains('brimstone_test'), isTrue);
    });

    test('la base semilla tiene las 40 criaturas del catálogo', () async {
      final db = await freshHelper().db;
      final rows = await db.query('cards');
      expect(rows.length, 40);
    });

    test('la base semilla tiene las 18 reliquias', () async {
      final db = await freshHelper().db;
      final rows = await db.query('relics');
      expect(rows.length, 18);
    });

    test('las 6 tablas progresivas arrancan vacías', () async {
      final repo = freshRepo();
      expect(await repo.loadTalentLevels(), isEmpty);
      expect(await repo.loadGearLevels(), isEmpty);
      expect(await repo.loadClearedChallenges(), isEmpty);
      expect(await repo.loadClearedChapters(), isEmpty);
      expect(await repo.loadActiveTitle(), isNull);
      expect(await repo.loadCollection(), isEmpty);
    });
  });

  // =========================================================== MÓDULO 1
  group('Módulo 1 — 10 Encuentros del Abismo', () {
    test('el catálogo tiene exactamente 10 eventos', () {
      expect(AbyssalEvents.all.length, 10);
    });

    test('los ids de evento son únicos', () {
      final ids = AbyssalEvents.all.map((e) => e.id).toSet();
      expect(ids.length, 10);
    });

    test('cada evento ofrece exactamente 3 opciones', () {
      for (final event in AbyssalEvents.all) {
        expect(event.options.length, 3, reason: event.id);
      }
    });

    test('los títulos son únicos y no vacíos', () {
      final titles = AbyssalEvents.all.map((e) => e.title).toSet();
      expect(titles.length, 10);
      expect(titles.every((t) => t.isNotEmpty), isTrue);
    });

    test('ningún evento tiene opciones sin efecto real', () {
      for (final event in AbyssalEvents.all) {
        for (final option in event.options) {
          final hasEffect = option.hpDelta != 0 ||
              option.goldDelta != 0 ||
              option.shardsDelta != 0 ||
              option.manaDelta != 0 ||
              option.relicId != null;
          expect(hasEffect, isTrue, reason: '${event.id} / ${option.label}');
        }
      }
    });

    test('todas las reliquias otorgadas existen en el catálogo', () {
      final validIds = RelicCatalog.all.map((r) => r.id).toSet();
      for (final event in AbyssalEvents.all) {
        for (final option in event.options) {
          final relic = option.relicId;
          if (relic == null) continue;
          expect(validIds, contains(relic), reason: '${event.id} → $relic');
        }
      }
    });

    test('los eventos reparten al menos 8 reliquias distintas', () {
      final relics = <String>{};
      for (final event in AbyssalEvents.all) {
        for (final option in event.options) {
          if (option.relicId != null) relics.add(option.relicId!);
        }
      }
      expect(relics.length, greaterThanOrEqualTo(8));
    });

    test('cada evento tiene al menos una opción que daña la vida', () {
      for (final event in AbyssalEvents.all) {
        expect(
          event.options.any((o) => o.hpDelta < 0),
          isTrue,
          reason: event.id,
        );
      }
    });

    test('effectSummary resume los efectos de la opción', () {
      const option = AbyssalEventOption(
        label: 'x',
        hpDelta: -10,
        goldDelta: 40,
        shardsDelta: 5,
        manaDelta: 0.2,
      );
      expect(option.effectSummary, contains('-10% HP'));
      expect(option.effectSummary, contains('+40 oro'));
      expect(option.effectSummary, contains('+5 esquirlas'));
      expect(option.effectSummary, contains('+20% maná'));
    });

    test('applyAbyssalOption convierte el HP en porcentaje del máximo', () {
      final outcome = applyAbyssalOption(
        option: const AbyssalEventOption(label: 'x', hpDelta: -10),
        playerHp: 100,
        playerMaxHp: 100,
        gold: 0,
        shards: 0,
        startManaFraction: 0,
        relicIds: const [],
      );
      expect(outcome.playerHp, 90);
      expect(outcome.hpLost, 10);
    });

    test('applyAbyssalOption no baja la vida de 0 ni sube del máximo', () {
      final lethal = applyAbyssalOption(
        option: const AbyssalEventOption(label: 'x', hpDelta: -90),
        playerHp: 20,
        playerMaxHp: 100,
        gold: 0,
        shards: 0,
        startManaFraction: 0,
        relicIds: const [],
      );
      expect(lethal.playerHp, 0);

      final heal = applyAbyssalOption(
        option: const AbyssalEventOption(label: 'x', hpDelta: 50),
        playerHp: 80,
        playerMaxHp: 100,
        gold: 0,
        shards: 0,
        startManaFraction: 0,
        relicIds: const [],
      );
      expect(heal.playerHp, 100);
    });

    test('applyAbyssalOption acumula oro y esquirlas sin negativos', () {
      final rich = applyAbyssalOption(
        option: const AbyssalEventOption(
          label: 'x',
          goldDelta: 40,
          shardsDelta: 7,
        ),
        playerHp: 100,
        playerMaxHp: 100,
        gold: 100,
        shards: 10,
        startManaFraction: 0,
        relicIds: const [],
      );
      expect(rich.gold, 140);
      expect(rich.shards, 17);

      final broke = applyAbyssalOption(
        option: const AbyssalEventOption(label: 'x', goldDelta: -50),
        playerHp: 100,
        playerMaxHp: 100,
        gold: 10,
        shards: 0,
        startManaFraction: 0,
        relicIds: const [],
      );
      expect(broke.gold, 0);
    });

    test('applyAbyssalOption limita la fracción de maná a 0..1', () {
      final outcome = applyAbyssalOption(
        option: const AbyssalEventOption(label: 'x', manaDelta: 0.8),
        playerHp: 100,
        playerMaxHp: 100,
        gold: 0,
        shards: 0,
        startManaFraction: 0.6,
        relicIds: const [],
      );
      expect(outcome.startManaFraction, 1.0);
    });

    test('applyAbyssalOption otorga la reliquia una sola vez', () {
      final first = applyAbyssalOption(
        option: const AbyssalEventOption(label: 'x', relicId: 'prisma_caos'),
        playerHp: 100,
        playerMaxHp: 100,
        gold: 0,
        shards: 0,
        startManaFraction: 0,
        relicIds: const ['prisma_caos'],
      );
      expect(first.relicIds.length, 1);
      expect(first.relicId, 'prisma_caos');
    });

    test('byId resuelve un evento y falla con uno desconocido', () {
      expect(
          AbyssalEvents.byId('mirror_of_blood').title, 'El Espejo de Sangre');
      expect(() => AbyssalEvents.byId('nope'), throwsArgumentError);
    });
  });

  group('Módulo 1 — 18 Reliquias Abisales', () {
    test('el catálogo tiene 18 reliquias', () {
      expect(RelicCatalog.all.length, 18);
    });

    test('los ids de reliquia son únicos', () {
      expect(RelicCatalog.all.map((r) => r.id).toSet().length, 18);
    });

    test('la base de datos espeja los 18 ids del catálogo', () async {
      final db = await freshHelper().db;
      final rows = await db.query('relics');
      final dbIds = {for (final r in rows) r['id'] as String};
      final catalogIds = RelicCatalog.all.map((r) => r.id).toSet();
      expect(dbIds, catalogIds);
    });

    test('byId devuelve la primera reliquia si el id no existe', () {
      expect(RelicCatalog.byId('inexistente').id, RelicCatalog.all.first.id);
    });

    test('Ceniza Volátil mejora el spawn ígneo a Nivel 2', () {
      final mods = CombatModifiers.fromRelics(['ceniza_volatil']);
      expect(mods.igneousLevel2Chance, 0.35);
    });

    test('Ojo del Abismo agranda el radio crítico un 40%', () {
      expect(CombatModifiers.fromRelics(['ojo_abismo']).critRadiusMult, 1.4);
    });

    test('Sello de Resonancia devuelve 20 de maná', () {
      expect(CombatModifiers.fromRelics(['sello_resonancia']).reactionMana, 20);
    });

    test('Pacto de Sangre acelera el maná y cuesta vida', () {
      final mods = CombatModifiers.fromRelics(['pacto_sangre']);
      expect(mods.manaSpeedMult, 1.5);
      expect(mods.startHpLossFraction, 0.08);
    });

    test('Forja Perpetua permite saltar a Nivel 3', () {
      expect(
        CombatModifiers.fromRelics(['forja_perpetua']).jumpToThreeChance,
        0.25,
      );
    });

    test('Coraza de Obsidiana cura al hacer Counter-Flick', () {
      expect(
        CombatModifiers.fromRelics(['coraza_obsidiana'])
            .counterflickHealFraction,
        0.04,
      );
    });

    test('Prisma del Caos activa las esferas prismáticas', () {
      expect(CombatModifiers.fromRelics(['prisma_caos']).prismaticOrb, isTrue);
    });

    test('Reloj de Ceniza añade 2 segundos de aura', () {
      expect(
        CombatModifiers.fromRelics(['reloj_ceniza']).auraDurationBonus,
        2.0,
      );
    });

    test('Colmillo Vampírico cura 2% por Bullseye', () {
      expect(
        CombatModifiers.fromRelics(['colmillo_vampirico']).bullseyeHealFraction,
        0.02,
      );
    });

    test('Sello de Sobrecarga llena el maná del Líder', () {
      expect(
        CombatModifiers.fromRelics(['sello_sobrecarga']).leaderStartManaFull,
        isTrue,
      );
    });

    test('Esencia del Abismo sube un nivel base las esferas', () {
      expect(
        CombatModifiers.fromRelics(['esencia_abismo']).baseOrbLevelBonus,
        1,
      );
    });

    test('Corazón de Fénix permite revivir una vez', () {
      expect(
        CombatModifiers.fromRelics(['corazon_phoenix']).phoenixRevive,
        isTrue,
      );
    });

    test('Grimorio Antiguo abarata y potencia las habilidades', () {
      final mods = CombatModifiers.fromRelics(['grimorio_antiguo']);
      expect(mods.skillManaCostMult, 0.8);
      expect(mods.skillEffectMult, 1.15);
    });

    test('Túnica del Vacío reduce el daño recibido un 15%', () {
      expect(
        CombatModifiers.fromRelics(['tunica_vacio']).damageTakenMult,
        0.85,
      );
    });

    test('Martillo del Titán garantiza Nivel 2 y 50% de Nivel 3', () {
      final mods = CombatModifiers.fromRelics(['martillo_titan']);
      expect(mods.minMergeLevel, 2);
      expect(mods.threeMergeChance, 0.5);
    });

    test('Cadenas del Sello aturden y frenan al jefe', () {
      final mods = CombatModifiers.fromRelics(['cadenas_sello']);
      expect(mods.bossStartStun, 2.0);
      expect(mods.bossAttackIntervalMult, 0.75);
    });

    test('Llama Eterna conserva esferas Ígneas un 20%', () {
      expect(
        CombatModifiers.fromRelics(['llama_eterna']).igneousOrbSaveChance,
        0.20,
      );
    });

    test('Sombra Perdida da esquirlas y crítico Abisal', () {
      final mods = CombatModifiers.fromRelics(['sombra_perdida']);
      expect(mods.abyssalCritMult, 1.25);
      expect(mods.shardsPerEnemyBonus, 1.0);
    });

    test('acumular las 18 reliquias no rompe los modificadores', () {
      final mods = CombatModifiers.fromRelics(
        RelicCatalog.all.map((r) => r.id),
      );
      expect(mods.prismaticOrb, isTrue);
      expect(mods.auraDurationBonus, 2.0);
      expect(mods.leaderStartManaFull, isTrue);
    });
  });

  group('Módulo 1 — Esferas Prismáticas', () {
    CombatEngine prismaticEngine() => buildEngine(
          modifiers: CombatModifiers.fromRelics(['prisma_caos']),
          seed: 3,
        );

    test('una esfera prismática fusiona con otro elemento del mismo nivel', () {
      final engine = prismaticEngine();
      engine.tray[0] = const CombatOrb(
        id: 'p',
        element: Element.igneous,
        level: OrbLevel.one,
        prismatic: true,
      );
      engine.tray[1] = const CombatOrb(
        id: 'b',
        element: Element.abyssal,
        level: OrbLevel.one,
      );
      final level = engine.mergeOrbs(0, 1);
      expect(level, OrbLevel.two);
      expect(engine.tray[1]!.element, Element.abyssal);
    });

    test('sin prisma, dos elementos distintos no fusionan', () {
      final engine = buildEngine();
      engine.tray[0] = const CombatOrb(
        id: 'a',
        element: Element.igneous,
        level: OrbLevel.one,
      );
      engine.tray[1] = const CombatOrb(
        id: 'b',
        element: Element.abyssal,
        level: OrbLevel.one,
      );
      expect(engine.mergeOrbs(0, 1), isNull);
    });

    test('una esfera prismática detona un aura sin reacción definida', () {
      final engine = prismaticEngine();
      engine.applyAura(Element.empty);
      final reaction = engine.applyAura(
        Element.igneous,
        orbLevel: 1,
        prismatic: true,
      );
      expect(reaction, 'Detonación Prismática');
    });

    test('sin prisma, la misma combinación no detona', () {
      final engine = prismaticEngine();
      engine.applyAura(Element.empty);
      expect(engine.applyAura(Element.igneous, orbLevel: 1), isNull);
    });

    test('Prisma del Caos hace aparecer esferas prismáticas', () {
      final engine = prismaticEngine();
      var found = false;
      for (var i = 0; i < 400 && !found; i++) {
        final orb = engine.spawnOrbInSlot(0);
        if (orb?.prismatic ?? false) found = true;
        engine.tray[0] = null;
      }
      expect(found, isTrue);
    });

    test('sin la reliquia nunca aparecen esferas prismáticas', () {
      final engine = buildEngine(seed: 5);
      // Clear prefilled tray
      for (var i = 0; i < engine.tray.length; i++) {
        engine.tray[i] = null;
      }
      for (var i = 0; i < 200; i++) {
        expect(engine.spawnOrbInSlot(0)!.prismatic, isFalse);
        engine.tray[0] = null;
      }
    });

    test('Esencia del Abismo spawnea siempre Nivel 2 o mayor', () {
      final engine = buildEngine(
        modifiers: CombatModifiers.fromRelics(['esencia_abismo']),
      );
      // Clear prefilled tray
      for (var i = 0; i < engine.tray.length; i++) {
        engine.tray[i] = null;
      }
      for (var i = 0; i < 60; i++) {
        final orb = engine.spawnOrbInSlot(0)!;
        expect(orb.level.index, greaterThanOrEqualTo(1));
        engine.tray[0] = null;
      }
    });
  });

  // =========================================================== MÓDULO 2
  group('Módulo 2 — Árbol de Talentos', () {
    test('hay 8 talentos permanentes', () {
      expect(TalentRules.allTalents.length, 8);
    });

    test('los ids de talento son únicos', () {
      expect(TalentRules.allTalents.map((t) => t.id).toSet().length, 8);
    });

    test('los nombres coinciden con el diseño', () {
      expect(
        TalentRules.allTalents.map((t) => t.name).toList(),
        [
          'Sangre de Arconte',
          'Furia de Azufre',
          'Canalización Rúnica',
          'Ojo Letal',
          'Maestría Elemental',
          'Piel de Basalto',
          'Avaricia del Vacío',
          'Eco de Esquirlas',
        ],
      );
    });

    test('cada talento escala de Nivel 0 a Nivel 5', () {
      for (final talent in TalentRules.allTalents) {
        expect(talent.valueAt(0), 0.0);
        expect(talent.valueAt(5), closeTo(talent.perLevel * 5, 1e-9));
      }
    });

    test('Sangre de Arconte da +6% HP por nivel', () {
      final talent = TalentRules.allTalents[0];
      expect(talent.valueAt(1), closeTo(0.06, 1e-9));
      expect(talent.valueAt(5), closeTo(0.30, 1e-9));
    });

    test('Furia de Azufre da +5% ATK por nivel', () {
      final talent = TalentRules.allTalents[1];
      expect(talent.valueAt(5), closeTo(0.25, 1e-9));
    });

    test('Maestría Elemental da +7% de reacción por nivel', () {
      final talent = TalentRules.allTalents[4];
      expect(talent.valueAt(5), closeTo(0.35, 1e-9));
    });

    test('el coste escala con el nivel (oro 250·nv, esquirlas 75·nv)', () {
      expect(
        TalentRules.costFor('archon_blood', 0),
        const TalentCost(gold: 250, shards: 75),
      );
      expect(
        TalentRules.costFor('archon_blood', 4),
        const TalentCost(gold: 1250, shards: 375),
      );
    });

    test('no hay coste al máximo ni para talentos inexistentes', () {
      expect(TalentRules.costFor('archon_blood', 5), isNull);
      expect(TalentRules.costFor('nope', 0), isNull);
    });

    test('un árbol vacío no otorga bonos', () {
      const tree = TalentTree();
      expect(tree.maxHpMult, 1.0);
      expect(tree.orbDamageMult, 1.0);
      expect(tree.manaMult, 1.0);
      expect(tree.bullseyeDamageMult, 1.0);
      expect(tree.reactionDamageMult, 1.0);
      expect(tree.damageTakenMult, 1.0);
      expect(tree.goldGainMult, 1.0);
      expect(tree.shardsGainMult, 1.0);
      expect(tree.totalLevels, 0);
    });

    test('Sangre de Arconte a 5 da +30% HP', () {
      final tree = TalentTree({'archon_blood': 5});
      expect(tree.maxHpMult, closeTo(1.30, 1e-9));
    });

    test('Ojo Letal a 5 da +40% de Bullseye', () {
      final tree = TalentTree({'deadly_eye': 5});
      expect(tree.bullseyeDamageMult, closeTo(1.40, 1e-9));
    });

    test('Piel de Basalto a 5 reduce el daño recibido un 20%', () {
      final tree = TalentTree({'basalt_skin': 5});
      expect(tree.damageTakenMult, closeTo(0.80, 1e-9));
    });

    test('Avaricia del Vacío multiplica el oro', () {
      final tree = TalentTree({'void_greed': 5});
      expect(tree.goldGainMult, closeTo(1.5, 1e-9));
      expect(tree.applyGoldGain(200), 300);
    });

    test('Eco de Esquirlas multiplica las esquirlas', () {
      final tree = TalentTree({'shard_echo': 5});
      expect(tree.applyShardsGain(100), 150);
    });

    test('totalLevels suma todos los niveles invertidos', () {
      final tree = TalentTree({'archon_blood': 5, 'sulfur_fury': 2});
      expect(tree.totalLevels, 7);
    });

    test('withLevel limita el nivel al máximo', () {
      final tree = const TalentTree().withLevel('archon_blood', 99);
      expect(tree.levelOf('archon_blood'), TalentRules.maxLevel);
    });

    test('el repositorio mejora un talento pagando oro y esquirlas', () async {
      final repo = freshRepo();
      final ok = await repo.upgradeTalent('archon_blood');
      expect(ok, isTrue);
      final profile = await repo.loadProfile();
      expect(profile[0], 250);
      expect(profile[1], 25);
      expect((await repo.loadTalentLevels())['archon_blood'], 1);
    });

    test('el repositorio rechaza la mejora sin fondos', () async {
      final repo = freshRepo();
      await repo.saveProfile(gold: 0, shards: 0, energy: 20, summonerLevel: 1);
      expect(await repo.upgradeTalent('archon_blood'), isFalse);
      expect(await repo.loadTalentLevels(), isEmpty);
    });

    test('el repositorio rechaza talentos desconocidos o al máximo', () async {
      final repo = freshRepo();
      expect(await repo.upgradeTalent('nope'), isFalse);
      await repo.saveTalentLevel('archon_blood', 5);
      expect(await repo.upgradeTalent('archon_blood'), isFalse);
    });
  });

  group('Módulo 2 — Armadura del Invocador', () {
    test('hay 3 piezas de armadura', () {
      expect(SummonerGearRules.allGear.length, 3);
    });

    test('los nombres coinciden con el diseño', () {
      expect(
        SummonerGearRules.allGear.map((g) => g.name).toList(),
        ['Yelmo Abisal', 'Guanteletes de Lanzamiento', 'Amuleto del Sello'],
      );
    });

    test('el Yelmo multiplica la duración del aura', () {
      expect(const GearLoadout({'yelmo_abisal': 1}).auraDurationMult, 1.0);
      expect(
        const GearLoadout({'yelmo_abisal': 5}).auraDurationMult,
        closeTo(1.6, 1e-9),
      );
    });

    test('los Guanteletes amplían el radio de Bullseye', () {
      expect(
        const GearLoadout({'guanteletes_lanzamiento': 5}).bullseyeRadiusMult,
        closeTo(1.4, 1e-9),
      );
    });

    test('el Amuleto regenera vida entre pisos', () {
      expect(
        const GearLoadout({'amuleto_sello': 5}).lifeRegenFraction,
        closeTo(0.20, 1e-9),
      );
      expect(const GearLoadout().lifeRegenFraction, 0.0);
    });

    test('el coste de forja escala por nivel', () {
      expect(
        SummonerGearRules.costFor('yelmo_abisal', 0),
        const GearCost(gold: 300, shards: 90),
      );
      expect(
        SummonerGearRules.costFor('yelmo_abisal', 4),
        const GearCost(gold: 1500, shards: 450),
      );
      expect(SummonerGearRules.costFor('yelmo_abisal', 5), isNull);
      expect(SummonerGearRules.costFor('nope', 0), isNull);
    });

    test('el repositorio forja una pieza y la persiste', () async {
      final repo = freshRepo();
      expect(await repo.forgeGear('yelmo_abisal'), isTrue);
      expect((await repo.loadGearLevels())['yelmo_abisal'], 1);
      final profile = await repo.loadProfile();
      expect(profile[0], 200);
      expect(profile[1], 10);
    });

    test('el repositorio rechaza piezas desconocidas o sin fondos', () async {
      final repo = freshRepo();
      expect(await repo.forgeGear('nope'), isFalse);
      await repo.saveProfile(gold: 0, shards: 0, energy: 20, summonerLevel: 1);
      expect(await repo.forgeGear('yelmo_abisal'), isFalse);
    });

    test('hasAny detecta equipamiento forjado', () {
      expect(const GearLoadout().hasAny, isFalse);
      expect(const GearLoadout({'amuleto_sello': 2}).hasAny, isTrue);
    });
  });

  group('Módulo 2 — Desmantelar copias (Disenchant)', () {
    Future<PlayerRepository> repoWithCards(int count,
        {int squadSlot = -1}) async {
      final repo = freshRepo();
      final ids = <int>[];
      for (var i = 0; i < count; i++) {
        final card = await repo.insertSummonedCard(
          i.isEven ? 'ignis_hound' : 'abyss_stalker',
        );
        ids.add(card.instanceId);
      }
      if (squadSlot >= 0 && squadSlot < ids.length) {
        await repo.saveSquad([ids[squadSlot]]);
      }
      return repo;
    }

    test('entrega 50·estrellas esquirlas y 150·estrellas oro', () async {
      final repo = await repoWithCards(5);
      final card = (await repo.loadCollection()).first;
      final rewards = await repo.disenchantCopy(card.instanceId);
      expect(rewards, isNotNull);
      expect(rewards!['shards'], 50 * card.stars);
      expect(rewards['gold'], 150 * card.stars);
    });

    test('elimina la copia de la colección', () async {
      final repo = await repoWithCards(5);
      final before = await repo.loadCollection();
      await repo.disenchantCopy(before.first.instanceId);
      final after = await repo.loadCollection();
      expect(after.length, before.length - 1);
    });

    test('bloquea el desmantelamiento si quedan menos de 4 cartas', () async {
      final repo = await repoWithCards(4);
      final card = (await repo.loadCollection()).first;
      expect(await repo.disenchantCopy(card.instanceId), isNull);
      expect(await repo.canDisenchantCopy(card.instanceId), isFalse);
    });

    test('bloquea el desmantelamiento de una carta del escuadrón', () async {
      final repo = await repoWithCards(5, squadSlot: 0);
      final squad = await repo.loadSquad();
      expect(await repo.disenchantCopy(squad.first), isNull);
      expect(await repo.canDisenchantCopy(squad.first), isFalse);
    });

    test('permite desmantelar copias fuera del escuadrón', () async {
      final repo = await repoWithCards(5, squadSlot: 0);
      final squad = await repo.loadSquad();
      final card = (await repo.loadCollection())
          .firstWhere((c) => c.instanceId != squad.first);
      expect(await repo.canDisenchantCopy(card.instanceId), isTrue);
    });

    test('devuelve null para cartas inexistentes', () async {
      final repo = await repoWithCards(5);
      expect(await repo.disenchantCopy(99999), isNull);
    });
  });

  // =========================================================== MÓDULO 3
  group('Módulo 3 — Desafíos del Sello', () {
    test('hay 10 desafíos tácticos', () {
      expect(SealChallengeRules.allChallenges.length, 10);
    });

    test('los ids de desafío son únicos', () {
      expect(
        SealChallengeRules.allChallenges.map((c) => c.id).toSet().length,
        10,
      );
    });

    test('los títulos son únicos y no vacíos', () {
      final titles = SealChallengeRules.allChallenges.map((c) => c.title);
      expect(titles.toSet().length, 10);
      expect(titles.every((t) => t.isNotEmpty), isTrue);
    });

    test('cada desafío tiene al menos un mutador', () {
      for (final c in SealChallengeRules.allChallenges) {
        expect(c.mutators, isNotEmpty, reason: c.id);
      }
    });

    test('los 10 mutadores se usan exactamente una vez', () {
      final used = <SealMutator>[];
      for (final c in SealChallengeRules.allChallenges) {
        used.addAll(c.mutators);
      }
      expect(used.toSet().length, SealMutator.values.length);
      expect(used.length, SealMutator.values.length);
    });

    test('cada desafío otorga 250 esquirlas + 500 oro', () {
      for (final c in SealChallengeRules.allChallenges) {
        expect(c.rewardShards, 250, reason: c.id);
        expect(c.rewardGold, 500, reason: c.id);
      }
    });

    test('Juicio del Emperador se pelea contra Azathor', () {
      final c = SealChallengeRules.byId('emperors_judgment');
      expect(c?.boss.id, 'azathor');
      expect(c?.has(SealMutator.azathorFuryStart), isTrue);
    });

    test('byId resuelve y falla con desconocidos', () {
      expect(SealChallengeRules.byId('abyssal_sniper')?.title,
          'Francotirador Abisal');
      expect(SealChallengeRules.byId('nope'), isNull);
    });

    test('Francotirador Abisal anula el daño que no es Bullseye', () {
      final engine = buildEngine(mutators: [SealMutator.bullseyeOnly]);
      expect(hitDamage(engine, HitKind.normal, OrbLevel.one), 0.0);
      expect(hitDamage(engine, HitKind.graze, OrbLevel.two), 0.0);
      expect(
        hitDamage(engine, HitKind.bullseye, OrbLevel.one),
        greaterThan(0),
      );
    });

    test('Maestro de la Forja sólo admite esferas de Nivel 3', () {
      final engine = buildEngine(mutators: [SealMutator.lvl3Only]);
      expect(hitDamage(engine, HitKind.normal, OrbLevel.one), 0.0);
      expect(hitDamage(engine, HitKind.normal, OrbLevel.two), 0.0);
      expect(
        hitDamage(engine, HitKind.normal, OrbLevel.three),
        greaterThan(0),
      );
    });

    test('Crisol Alquímico reduce el daño directo al 20%', () {
      final base = hitDamage(
        buildEngine(),
        HitKind.normal,
        OrbLevel.one,
      );
      final crucible = hitDamage(
        buildEngine(mutators: [SealMutator.reactionBoost]),
        HitKind.normal,
        OrbLevel.one,
      );
      expect(crucible / base, closeTo(0.2, 1e-9));
    });

    test('Crisol Alquímico cuadruplica el daño de reacción', () {
      final engine = buildEngine(mutators: [SealMutator.reactionBoost]);
      final before = engine.bossHp;
      engine.applyAura(Element.igneous);
      engine.applyAura(Element.abyssal);
      final reactionDamage = before - engine.bossHp;
      expect(reactionDamage, greaterThan(CombatEngine.baseDamage * 4));
    });

    test('Muralla de Espejos refleja el 12% del HP máximo del jefe', () async {
      final engine = buildEngine(mutators: [SealMutator.counterflickReflect]);
      engine.enemyProjectiles.add(
        EnemyProjectile(
          id: 'e1',
          startX: 100,
          startY: 200,
          endX: 100,
          endY: 200,
          duration: 1.6,
        ),
      );
      final before = engine.bossHp;
      expect(engine.counterFlickAt(100, 200, 0), isTrue);
      expect(before - engine.bossHp, closeTo(engine.boss.maxHp * 0.12, 1e-6));
    });

    test('Pacto de Hemorragia drena 2% de vida por segundo', () {
      final engine = buildEngine(mutators: [SealMutator.bleedHeal]);
      final before = engine.playerHp;
      engine.tick(1.0);
      expect(before - engine.playerHp, closeTo(2.0, 0.05));
    });

    test('Pacto de Hemorragia cura 5% por Bullseye', () {
      final engine = buildEngine(mutators: [SealMutator.bleedHeal]);
      engine.playerHp = 50;
      engine.registerDamage(
        orb: const CombatOrb(
          id: 'o',
          element: Element.igneous,
          level: OrbLevel.one,
        ),
        target: buildTarget(),
        multiplier: 1.0,
        kind: HitKind.bullseye,
      );
      expect(engine.playerHp, greaterThan(50));
      expect(engine.playerHp, closeTo(55, 1e-6));
    });

    test('Tormenta Bipolar sólo spawnea Ígneo y Abisal', () {
      final engine = buildEngine(
        mutators: [SealMutator.igneousAbyssalFast],
      );
      // Clear prefilled tray
      for (var i = 0; i < engine.tray.length; i++) {
        engine.tray[i] = null;
      }
      for (var i = 0; i < 80; i++) {
        final orb = engine.spawnOrbInSlot(0)!;
        expect(
          orb.element == Element.igneous || orb.element == Element.abyssal,
          isTrue,
        );
        engine.tray[0] = null;
      }
    });

    test('Silencio de Cartas bloquea habilidades y sube el daño de esferas',
        () {
      final card = manaCard();
      card.mana = card.baseManaCost.toDouble();
      final engine = buildEngine(
        cards: [card],
        mutators: [SealMutator.skillDisabledOrbBoost],
      );
      expect(engine.castSkill(0), isFalse);
      final base = hitDamage(buildEngine(), HitKind.normal, OrbLevel.one);
      final silenced = hitDamage(
        buildEngine(mutators: [SealMutator.skillDisabledOrbBoost]),
        HitKind.normal,
        OrbLevel.one,
      );
      expect(silenced / base, closeTo(2.2, 1e-9));
    });

    test('Lluvia Corrupta duplica los proyectiles del jefe', () {
      int maxProjectiles(List<SealMutator> mutators) {
        final engine = buildEngine(
          boss: BossConfig.azathor,
          mutators: mutators,
          seed: 8,
        );
        var max = 0;
        for (var i = 0; i < 300; i++) {
          if (engine.bossProjectileCount > max) {
            max = engine.bossProjectileCount;
          }
        }
        return max;
      }

      expect(
        maxProjectiles([SealMutator.bossDoubleProjectiles]),
        greaterThan(maxProjectiles(const [])),
      );
    });

    test('Dianas Fugaces encoge y acelera las dianas', () {
      final normal = buildEngine();
      final fleeting = buildEngine(mutators: [SealMutator.fastSmallManaBoost]);
      final radiusRatio = fleeting.outerRadiusFor(buildTarget()) /
          normal.outerRadiusFor(buildTarget());
      expect(radiusRatio, closeTo(0.75, 1e-9));
      expect(
        fleeting.effectiveAngularSpeed(buildTarget()),
        greaterThan(normal.effectiveAngularSpeed(buildTarget())),
      );
    });

    test('Dianas Fugaces duplica la ganancia de maná', () {
      List<ManaCard> cards() => [manaCard()];
      final normal = buildEngine(cards: cards());
      final fleeting = buildEngine(
        cards: cards(),
        mutators: [SealMutator.fastSmallManaBoost],
      );
      normal.addManaToCards(Element.igneous, 10);
      fleeting.addManaToCards(Element.igneous, 10);
      expect(fleeting.cards.first.mana,
          closeTo(normal.cards.first.mana * 2, 1e-6));
    });

    test('Juicio del Emperador arranca con Azathor enfurecido', () {
      final engine = buildEngine(
        boss: BossConfig.azathor,
        mutators: [SealMutator.azathorFuryStart],
      );
      expect(engine.enraged, isTrue);
    });

    test('la primera victoria de un desafío se paga una sola vez', () async {
      final repo = freshRepo();
      final first = await repo.markChallengeCleared('abyssal_sniper');
      expect(first, isTrue);
      final profile = await repo.loadProfile();
      expect(profile[0], 1000);
      expect(profile[1], 350);

      final second = await repo.markChallengeCleared('abyssal_sniper');
      expect(second, isFalse);
      final after = await repo.loadProfile();
      expect(after[0], 1000);
      expect(after[1], 350);
    });

    test('los desafíos superados se persisten', () async {
      final repo = freshRepo();
      await repo.markChallengeCleared('forge_master');
      await repo.markChallengeCleared('corrupt_rain');
      expect(
        await repo.loadClearedChallenges(),
        containsAll(['forge_master', 'corrupt_rain']),
      );
    });

    test('la arena usa un gólem de pruebas indestructible y sin coste', () {
      final engine = buildEngine(
        boss: BossConfig.trainingGolem,
        trainingMode: true,
      );
      expect(engine.boss.id, 'training_golem');
      expect(engine.boss.maxHp, greaterThanOrEqualTo(50000));
      expect(engine.cards.first.isReady, isTrue);
    });

    test('la arena rellena el maná al instante', () {
      final engine = buildEngine(
        boss: BossConfig.trainingGolem,
        trainingMode: true,
      );
      engine.cards.first.mana = 0;
      engine.fillAllMana();
      expect(engine.cards.first.mana, engine.cards.first.baseManaCost);
    });

    test('la arena expone un medidor de DPS en vivo', () {
      final engine = buildEngine(boss: BossConfig.trainingGolem);
      engine.tick(1.0);
      hitDamage(engine, HitKind.normal, OrbLevel.one);
      expect(engine.dps, greaterThan(0));
    });
  });

  // =========================================================== MÓDULO 4
  group('Módulo 4 — Ambiente procedural', () {
    test('el drone del Santuario es un WAV válido', () {
      final wav = ProceduralSfxEngine.generateSanctuaryDroneWav();
      expect(wav.length, greaterThan(44));
      expect(wav[0], 0x52); // R
      expect(wav[1], 0x49); // I
      expect(wav[2], 0x46); // F
      expect(wav[3], 0x46); // F
    });

    test('el pulso del jefe es un WAV válido', () {
      final wav = ProceduralSfxEngine.generateBossPulseWav();
      expect(wav.length, greaterThan(44));
      expect(wav[0], 0x52);
    });

    test('el drone dura más que el pulso del jefe', () {
      final drone = ProceduralSfxEngine.generateSanctuaryDroneWav();
      final pulse = ProceduralSfxEngine.generateBossPulseWav();
      expect(drone.length, greaterThan(pulse.length));
    });

    test('el drone del Santuario dura unos 4 segundos', () {
      final drone = ProceduralSfxEngine.generateSanctuaryDroneWav();
      // 44100 Hz · 4 s · 2 bytes + cabecera de 44 bytes.
      expect(drone.length, closeTo(44100 * 4 * 2 + 44, 4096));
    });

    test('bufferFor expone drone y boss_pulse', () {
      expect(ProceduralSfxEngine.bufferFor('drone').length, greaterThan(44));
      expect(
          ProceduralSfxEngine.bufferFor('boss_pulse').length, greaterThan(44));
    });

    test('bufferFor falla con un sonido desconocido', () {
      expect(
        () => ProceduralSfxEngine.bufferFor('nope'),
        throwsArgumentError,
      );
    });

    test('sanctuaryDroneBuffer coincide con el generador', () {
      expect(
        ProceduralSfxEngine.sanctuaryDroneBuffer().length,
        ProceduralSfxEngine.generateSanctuaryDroneWav().length,
      );
    });

    test('el volumen de efectos se limita a 0..1', () {
      ProceduralSfxEngine.setSfxVolume(1.7);
      expect(ProceduralSfxEngine.sfxVolume, 1.0);
      ProceduralSfxEngine.setSfxVolume(-2);
      expect(ProceduralSfxEngine.sfxVolume, 0.0);
      ProceduralSfxEngine.setSfxVolume(0.65);
      expect(ProceduralSfxEngine.sfxVolume, closeTo(0.65, 1e-9));
    });

    test('el volumen de ambiente se limita a 0..1', () {
      ProceduralSfxEngine.setAmbientVolume(3);
      expect(ProceduralSfxEngine.ambientVolume, 1.0);
      ProceduralSfxEngine.setAmbientVolume(0.25);
      expect(ProceduralSfxEngine.ambientVolume, closeTo(0.25, 1e-9));
    });

    test('las hápticas se pueden desactivar', () {
      ProceduralSfxEngine.setHapticsEnabled(false);
      expect(ProceduralSfxEngine.hapticsEnabled, isFalse);
      ProceduralSfxEngine.setHapticsEnabled(true);
      expect(ProceduralSfxEngine.hapticsEnabled, isTrue);
    });

    test('restoreSettings aplica los valores persistidos', () {
      ProceduralSfxEngine.restoreSettings(
        sfxVolume: 30,
        ambientVolume: 70,
        hapticsEnabled: false,
      );
      expect(ProceduralSfxEngine.sfxVolume, closeTo(0.30, 1e-9));
      expect(ProceduralSfxEngine.ambientVolume, closeTo(0.70, 1e-9));
      expect(ProceduralSfxEngine.hapticsEnabled, isFalse);
    });

    test('el silencio anula los volúmenes efectivos', () {
      ProceduralSfxEngine.setMuted(true);
      expect(ProceduralSfxEngine.effectiveSfxVolume, 0.0);
      expect(ProceduralSfxEngine.effectiveAmbientVolume, 0.0);
      ProceduralSfxEngine.setMuted(false);
      expect(ProceduralSfxEngine.effectiveSfxVolume, greaterThan(0));
    });
  });

  group('Módulo 4 — Racha crítica y viñeta de peligro', () {
    test('el primer Bullseye no da bonus', () {
      final engine = buildEngine();
      engine.registerDamage(
        orb: const CombatOrb(
          id: 'o',
          element: Element.igneous,
          level: OrbLevel.one,
        ),
        target: buildTarget(),
        multiplier: 1.0,
        kind: HitKind.bullseye,
      );
      expect(engine.bullseyeStreak, 1);
      expect(engine.bullseyeStreakBonus, 1.0);
    });

    test('con 3 Bullseyes seguidos el bonus es +10%', () {
      final engine = buildEngine();
      for (var i = 0; i < 3; i++) {
        hitDamage(engine, HitKind.bullseye, OrbLevel.one);
      }
      expect(engine.bullseyeStreak, 3);
      expect(engine.bullseyeStreakBonus, closeTo(1.10, 1e-9));
    });

    test('el bonus escala +10% por golpe y se topa en +100%', () {
      final engine = buildEngine();
      for (var i = 0; i < 5; i++) {
        hitDamage(engine, HitKind.bullseye, OrbLevel.one);
      }
      expect(engine.bullseyeStreakBonus, closeTo(1.30, 1e-9));
      for (var i = 0; i < 30; i++) {
        hitDamage(engine, HitKind.bullseye, OrbLevel.one);
      }
      expect(engine.bullseyeStreakBonus, closeTo(2.0, 1e-9));
    });

    test('un golpe normal corta la racha', () {
      final engine = buildEngine();
      hitDamage(engine, HitKind.bullseye, OrbLevel.one);
      hitDamage(engine, HitKind.bullseye, OrbLevel.one);
      hitDamage(engine, HitKind.normal, OrbLevel.one);
      expect(engine.bullseyeStreak, 0);
      expect(engine.bullseyeStreakBonus, 1.0);
    });

    test('un roce también corta la racha', () {
      final engine = buildEngine();
      hitDamage(engine, HitKind.bullseye, OrbLevel.one);
      hitDamage(engine, HitKind.bullseye, OrbLevel.one);
      hitDamage(engine, HitKind.graze, OrbLevel.one);
      expect(engine.bullseyeStreak, 0);
    });

    test('se recuerda la mejor racha del combate', () {
      final engine = buildEngine();
      for (var i = 0; i < 4; i++) {
        hitDamage(engine, HitKind.bullseye, OrbLevel.one);
      }
      hitDamage(engine, HitKind.normal, OrbLevel.one);
      hitDamage(engine, HitKind.bullseye, OrbLevel.one);
      expect(engine.bestBullseyeStreak, 4);
    });

    test('la racha aumenta el daño real del Bullseye', () {
      final first = buildEngine();
      final firstDamage = hitDamage(first, HitKind.bullseye, OrbLevel.one);
      final streak = buildEngine();
      hitDamage(streak, HitKind.bullseye, OrbLevel.one);
      hitDamage(streak, HitKind.bullseye, OrbLevel.one);
      final thirdDamage = hitDamage(streak, HitKind.bullseye, OrbLevel.one);
      expect(thirdDamage, greaterThan(firstDamage));
    });

    test('la viñeta se activa bajo el 25% de vida', () {
      final engine = buildEngine();
      expect(engine.isLowHp, isFalse);
      engine.playerHp = engine.playerMaxHp * 0.24;
      expect(engine.isLowHp, isTrue);
      expect(engine.hpFraction, closeTo(0.24, 1e-9));
    });
  });

  // =========================================================== MÓDULO 5
  group('Módulo 5 — 12 Títulos del Invocador', () {
    test('hay exactamente 12 títulos', () {
      expect(SummonerTitles.titles.length, 12);
    });

    test('los ids de título son únicos', () {
      expect(SummonerTitles.titles.map((t) => t.id).toSet().length, 12);
    });

    test('todos los títulos declaran requisito', () {
      for (final title in SummonerTitles.titles) {
        expect(title.requirement, isNotEmpty, reason: title.id);
      }
    });

    test('Novato se desbloquea con el primer combate ganado', () {
      final title = SummonerTitles.byId('novato')!;
      expect(title.isUnlocked(const SummonerStats()), isFalse);
      expect(title.isUnlocked(const SummonerStats(combatsWon: 1)), isTrue);
    });

    test('Sellador Menor exige 2 capítulos', () {
      final title = SummonerTitles.byId('sellador')!;
      expect(
          title.isUnlocked(const SummonerStats(chaptersCleared: 1)), isFalse);
      expect(title.isUnlocked(const SummonerStats(chaptersCleared: 2)), isTrue);
    });

    test('Asesino de Gorgath exige el Capítulo III', () {
      final title = SummonerTitles.byId('gorgath_slayer')!;
      expect(
          title.isUnlocked(const SummonerStats(chaptersCleared: 2)), isFalse);
      expect(title.isUnlocked(const SummonerStats(chaptersCleared: 3)), isTrue);
    });

    test('Vencedor de Nyxara exige el Capítulo IV', () {
      final title = SummonerTitles.byId('nyxara_slayer')!;
      expect(
          title.isUnlocked(const SummonerStats(chaptersCleared: 3)), isFalse);
      expect(title.isUnlocked(const SummonerStats(chaptersCleared: 4)), isTrue);
    });

    test('Destructor de Azathor exige el Capítulo V', () {
      final title = SummonerTitles.byId('azathor_slayer')!;
      expect(
          title.isUnlocked(const SummonerStats(chaptersCleared: 4)), isFalse);
      expect(title.isUnlocked(const SummonerStats(chaptersCleared: 5)), isTrue);
    });

    test('Ojo de la Muerte exige 10 Bullseyes seguidos', () {
      final title = SummonerTitles.byId('deadly_eye')!;
      expect(
        title.isUnlocked(const SummonerStats(bestBullseyeStreak: 9)),
        isFalse,
      );
      expect(
        title.isUnlocked(const SummonerStats(bestBullseyeStreak: 10)),
        isTrue,
      );
    });

    test('Verdugo de Ceniza exige 500 de daño en un golpe', () {
      final title = SummonerTitles.byId('executioner')!;
      expect(title.isUnlocked(const SummonerStats(maxHit: 499)), isFalse);
      expect(title.isUnlocked(const SummonerStats(maxHit: 500)), isTrue);
    });

    test('Alquimista Abisal exige 50 reacciones', () {
      final title = SummonerTitles.byId('alchemist')!;
      expect(title.isUnlocked(const SummonerStats(reactions: 49)), isFalse);
      expect(title.isUnlocked(const SummonerStats(reactions: 50)), isTrue);
    });

    test('Rey de las Cartas exige 20 cartas', () {
      final title = SummonerTitles.byId('card_king')!;
      expect(title.isUnlocked(const SummonerStats(cardsOwned: 19)), isFalse);
      expect(title.isUnlocked(const SummonerStats(cardsOwned: 20)), isTrue);
    });

    test('Quebrantormentas exige 5 desafíos', () {
      final title = SummonerTitles.byId('seal_breaker')!;
      expect(
        title.isUnlocked(const SummonerStats(challengesCleared: 4)),
        isFalse,
      );
      expect(
        title.isUnlocked(const SummonerStats(challengesCleared: 5)),
        isTrue,
      );
    });

    test('Viajero del Abismo exige la oleada 10', () {
      final title = SummonerTitles.byId('abyss_wanderer')!;
      expect(title.isUnlocked(const SummonerStats(endlessRecord: 9)), isFalse);
      expect(title.isUnlocked(const SummonerStats(endlessRecord: 10)), isTrue);
    });

    test('Dios Invocador exige todo el contenido dominado', () {
      final title = SummonerTitles.byId('summoner_god')!;
      expect(
        title.isUnlocked(const SummonerStats(
          chaptersCleared: 5,
          challengesCleared: 10,
          cardsOwned: 20,
          endlessRecord: 20,
        )),
        isTrue,
      );
      expect(
        title.isUnlocked(const SummonerStats(
          chaptersCleared: 5,
          challengesCleared: 10,
          cardsOwned: 20,
        )),
        isFalse,
      );
    });

    test('resolve cae al título por defecto si no hay nada equipado', () {
      expect(
        SummonerTitles.resolve(null, const SummonerStats()).id,
        SummonerTitles.defaultTitle.id,
      );
    });

    test('resolve ignora un título bloqueado o inexistente', () {
      expect(
        SummonerTitles.resolve('card_king', const SummonerStats()).id,
        SummonerTitles.defaultTitle.id,
      );
      expect(
        SummonerTitles.resolve('nope', const SummonerStats()).id,
        SummonerTitles.defaultTitle.id,
      );
    });

    test('resolve respeta un título desbloqueado', () {
      expect(
        SummonerTitles.resolve(
          'card_king',
          const SummonerStats(cardsOwned: 20),
        ).id,
        'card_king',
      );
    });

    test('unlockedFor filtra por progreso', () {
      final unlocked = SummonerTitles.unlockedFor(
        const SummonerStats(combatsWon: 1, chaptersCleared: 2),
      );
      expect(unlocked.map((t) => t.id), containsAll(['novato', 'sellador']));
      expect(unlocked.map((t) => t.id), isNot(contains('azathor_slayer')));
    });

    test('progressLabel describe el avance del requisito', () {
      final label = SummonerTitles.byId('card_king')!.progressLabel(
        const SummonerStats(cardsOwned: 7),
      );
      expect(label, contains('7/20'));
    });

    test('el título equipado se persiste en SQLite', () async {
      final repo = freshRepo();
      await repo.saveActiveTitle('novato');
      expect(await repo.loadActiveTitle(), 'novato');
      await repo.saveActiveTitle(null);
      expect(await repo.loadActiveTitle(), isNull);
    });
  });

  group('Módulo 5 — Historial de Invocador', () {
    test('registrar un combate suma victorias y jefes', () async {
      final repo = freshRepo();
      await repo.recordCombatResult(
        victory: true,
        bossKilled: true,
        damageTotal: 1000,
        maxHit: 250,
      );
      final stats = await repo.loadStats();
      expect(stats.combatsWon, 1);
      expect(stats.bossesSlain, 1);
    });

    test('una derrota no suma victorias', () async {
      final repo = freshRepo();
      await repo.recordCombatResult(victory: false, damageTotal: 500);
      final stats = await repo.loadStats();
      expect(stats.combatsWon, 0);
      expect(stats.bossesSlain, 0);
    });

    test('el golpe máximo sólo sube, nunca baja', () async {
      final repo = freshRepo();
      await repo.recordCombatResult(victory: true, maxHit: 500);
      await repo.recordCombatResult(victory: true, maxHit: 120);
      expect((await repo.loadStats()).maxHit, 500);
    });

    test('la mejor racha sólo sube, nunca baja', () async {
      final repo = freshRepo();
      await repo.recordCombatResult(victory: true, bestBullseyeStreak: 9);
      await repo.recordCombatResult(victory: true, bestBullseyeStreak: 3);
      expect((await repo.loadStats()).bestBullseyeStreak, 9);
    });

    test('las reacciones y counter-flicks se acumulan', () async {
      final repo = freshRepo();
      await repo.recordCombatResult(
          victory: true, reactions: 3, counterflicks: 2);
      await repo.recordCombatResult(
          victory: true, reactions: 4, counterflicks: 1);
      final stats = await repo.loadStats();
      expect(stats.reactions, 7);
      expect(stats.counterflicks, 3);
    });

    test('loadStats agrega capítulos, desafíos, cartas y récord', () async {
      final repo = freshRepo();
      await repo.markChapterCleared(
        'chapter_ceniza',
        rewardGold: 0,
        rewardShards: 0,
      );
      await repo.markChallengeCleared('forge_master');
      await repo.insertSummonedCard('ignis_hound');
      await repo.insertSummonedCard('abyss_stalker');
      await repo.saveHighestEndlessWave(12);
      final stats = await repo.loadStats();
      expect(stats.chaptersCleared, 1);
      expect(stats.challengesCleared, 1);
      expect(stats.cardsOwned, 2);
      expect(stats.endlessRecord, 12);
    });

    test('un máximo histórico de oleada nunca retrocede', () async {
      final repo = freshRepo();
      await repo.saveHighestEndlessWave(15);
      await repo.saveHighestEndlessWave(9);
      expect(await repo.loadHighestEndlessWave(), 15);
    });

    test('stats serializa y deserializa sin pérdida', () {
      const stats = SummonerStats(
        combatsWon: 4,
        bossesSlain: 2,
        maxHit: 777,
        bestBullseyeStreak: 11,
        reactions: 40,
        chaptersCleared: 3,
        challengesCleared: 5,
        cardsOwned: 18,
        endlessRecord: 9,
        counterflicks: 6,
      );
      final roundTrip = SummonerStats.fromMap(stats.toMap());
      expect(roundTrip.toMap(), stats.toMap());
    });
  });

  group('Módulo 5 — Backup V2', () {
    test('exportBackup usa formatVersion 4', () async {
      final data = await freshRepo().exportBackup();
      expect(data['formatVersion'], 4);
    });

    test('el backup incluye talentos, desafíos, gear, título y stats',
        () async {
      final data = await freshRepo().exportBackup();
      expect(data.containsKey('talents'), isTrue);
      expect(data.containsKey('challengesCleared'), isTrue);
      expect(data.containsKey('gear'), isTrue);
      expect(data.containsKey('activeTitle'), isTrue);
      expect(data.containsKey('stats'), isTrue);
    });

    test('el backup conserva talentos tras importar', () async {
      final repo = freshRepo();
      await repo.saveTalentLevel('archon_blood', 3);
      final backup = await repo.exportBackup();

      final restored = freshRepo();
      await restored.importBackup(backup);
      expect((await restored.loadTalentLevels())['archon_blood'], 3);
    });

    test('el backup conserva desafíos superados', () async {
      final repo = freshRepo();
      await repo.markChallengeCleared('abyssal_sniper');
      await repo.markChallengeCleared('blood_pact');
      final backup = await repo.exportBackup();

      final restored = freshRepo();
      await restored.importBackup(backup);
      expect(
        await restored.loadClearedChallenges(),
        containsAll(['abyssal_sniper', 'blood_pact']),
      );
    });

    test('el backup conserva la armadura forjada', () async {
      final repo = freshRepo();
      await repo.saveGearLevel('yelmo_abisal', 4);
      final backup = await repo.exportBackup();

      final restored = freshRepo();
      await restored.importBackup(backup);
      expect((await restored.loadGearLevels())['yelmo_abisal'], 4);
    });

    test('el backup conserva el título activo', () async {
      final repo = freshRepo();
      await repo.saveActiveTitle('novato');
      final backup = await repo.exportBackup();

      final restored = freshRepo();
      await restored.importBackup(backup);
      expect(await restored.loadActiveTitle(), 'novato');
    });

    test('el backup conserva el historial de métricas', () async {
      final repo = freshRepo();
      await repo.recordCombatResult(
        victory: true,
        bossKilled: true,
        maxHit: 640,
        bestBullseyeStreak: 12,
        reactions: 8,
      );
      final backup = await repo.exportBackup();

      final restored = freshRepo();
      await restored.importBackup(backup);
      final stats = await restored.loadStats();
      expect(stats.combatsWon, 1);
      expect(stats.maxHit, 640);
      expect(stats.bestBullseyeStreak, 12);
      expect(stats.reactions, 8);
    });

    test('un backup v1 sigue siendo importable', () async {
      final repo = freshRepo();
      final backup = {
        'formatVersion': 1,
        'profile': {'gold': 777, 'shards': 33, 'summonerLevel': 4},
        'collection': <dynamic>[],
        'squad': <dynamic>[],
        'runes': <String, dynamic>{},
        'bounties': <dynamic>[],
        'chapters': <String>['chapter_ceniza'],
        'merchant': {'lastTributeDate': '2026-01-01'},
      };
      await repo.importBackup(backup);
      final profile = await repo.loadProfile();
      expect(profile[0], 777);
      expect(profile[1], 33);
      expect(profile[3], 4);
      expect(await repo.loadClearedChapters(), contains('chapter_ceniza'));
    });

    test('importar un backup desconocido lanza FormatException', () async {
      expect(
        () => freshRepo().importBackup({'formatVersion': 42}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  // ======================================================== INTEGRACIÓN
  group('Integración — talentos, gear y reliquias en combate', () {
    test('Sangre de Arconte sube el HP máximo del motor', () {
      final engine = buildEngine(talents: {'archon_blood': 5});
      expect(engine.playerMaxHp, closeTo(130, 1e-9));
      expect(engine.playerHp, closeTo(130, 1e-9));
    });

    test('Furia de Azufre sube el daño de las esferas', () {
      final base = hitDamage(buildEngine(), HitKind.normal, OrbLevel.one);
      final buffed = hitDamage(
        buildEngine(talents: {'sulfur_fury': 5}),
        HitKind.normal,
        OrbLevel.one,
      );
      expect(buffed / base, closeTo(1.25, 1e-9));
    });

    test('Ojo Letal sólo potencia el Bullseye', () {
      final baseCrit = hitDamage(buildEngine(), HitKind.bullseye, OrbLevel.one);
      final talentCrit = hitDamage(
        buildEngine(talents: {'deadly_eye': 5}),
        HitKind.bullseye,
        OrbLevel.one,
      );
      expect(talentCrit / baseCrit, closeTo(1.40, 1e-9));

      final baseNormal = hitDamage(buildEngine(), HitKind.normal, OrbLevel.one);
      final talentNormal = hitDamage(
        buildEngine(talents: {'deadly_eye': 5}),
        HitKind.normal,
        OrbLevel.one,
      );
      expect(talentNormal, closeTo(baseNormal, 1e-9));
    });

    test('Maestría Elemental sube el daño de reacción', () {
      double reactionDamage(Map<String, int> talents) {
        final engine = buildEngine(talents: talents);
        final before = engine.bossHp;
        engine.applyAura(Element.igneous);
        engine.applyAura(Element.abyssal);
        return before - engine.bossHp;
      }

      final base = reactionDamage(const {});
      final mastered = reactionDamage({'elemental_mastery': 5});
      expect(mastered / base, closeTo(1.35, 1e-9));
    });

    test('Piel de Basalto reduce el daño recibido', () {
      final engine = buildEngine(talents: {'basalt_skin': 5});
      final before = engine.playerHp;
      engine.hitPlayer();
      expect(before - engine.playerHp, closeTo(8.0, 1e-9));
    });

    test('Canalización Rúnica acelera la carga de maná', () {
      final base = buildEngine();
      final runic = buildEngine(talents: {'runic_channeling': 5});
      base.addManaToCards(Element.igneous, 10);
      runic.addManaToCards(Element.igneous, 10);
      expect(runic.cards.first.mana, greaterThan(base.cards.first.mana));
    });

    test('El Yelmo Abisal alarga el aura en combate', () {
      final base = buildEngine();
      base.applyAura(Element.igneous);
      final yelmo = buildEngine(gear: {'yelmo_abisal': 5});
      yelmo.applyAura(Element.igneous);
      expect(yelmo.auraRemaining, greaterThan(base.auraRemaining));
      expect(yelmo.auraRemaining, closeTo(base.auraRemaining * 1.6, 1e-9));
    });

    test('Reloj de Ceniza y Yelmo Abisal se acumulan', () {
      final engine = buildEngine(
        modifiers: CombatModifiers.fromRelics(['reloj_ceniza']),
        gear: {'yelmo_abisal': 5},
      );
      engine.applyAura(Element.igneous);
      expect(engine.auraRemaining, closeTo((5 + 2) * 1.6, 1e-9));
    });

    test('Los Guanteletes agrandan el Bullseye en combate', () {
      final base = buildEngine();
      final gauntlets = buildEngine(gear: {'guanteletes_lanzamiento': 5});
      expect(
        gauntlets.innerRadiusFor(buildTarget()) /
            base.innerRadiusFor(buildTarget()),
        closeTo(1.4, 1e-9),
      );
    });

    test('Sello de Sobrecarga llena el maná de la carta Líder', () {
      final cards = [
        manaCard(id: 'ignis_lord', manaCost: 140),
        manaCard(id: 'abyss_stalker', element: Element.abyssal),
      ];
      final engine = buildEngine(
        cards: cards,
        modifiers: CombatModifiers.fromRelics(['sello_sobrecarga']),
      );
      expect(engine.cards.first.mana, 140);
      expect(engine.cards.last.mana, 0);
    });

    test('Cadenas del Sello aturden al jefe al empezar', () {
      final engine = buildEngine(
        modifiers: CombatModifiers.fromRelics(['cadenas_sello']),
      );
      expect(engine.bossStunRemaining, closeTo(2.0, 1e-9));
      expect(
        engine.bossAttackTimer,
        closeTo(BossConfig.pyroth.attackInterval * 0.75, 1e-9),
      );
    });

    test('Corazón de Fénix revive una sola vez', () {
      final engine = buildEngine(
        modifiers: CombatModifiers.fromRelics(['corazon_phoenix']),
      );
      engine.playerHp = 0;
      engine.tick(0.016);
      expect(engine.finished, isFalse);
      expect(engine.playerHp, closeTo(engine.playerMaxHp * 0.30, 1e-9));

      engine.playerHp = 0;
      engine.tick(0.016);
      expect(engine.finished, isTrue);
      expect(engine.victory, isFalse);
    });

    test('Colmillo Vampírico cura al conectar un Bullseye', () {
      final engine = buildEngine(
        modifiers: CombatModifiers.fromRelics(['colmillo_vampirico']),
      );
      engine.playerHp = 50;
      hitDamage(engine, HitKind.bullseye, OrbLevel.one);
      expect(engine.playerHp, closeTo(52, 1e-6));
    });

    test('Martillo del Titán garantiza al menos Nivel 2 al fusionar', () {
      final engine = buildEngine(
        modifiers: CombatModifiers.fromRelics(['martillo_titan']),
        seed: 11,
      );
      for (var i = 0; i < 20; i++) {
        engine.tray[0] = const CombatOrb(
          id: 'a',
          element: Element.telluric,
          level: OrbLevel.one,
        );
        engine.tray[1] = const CombatOrb(
          id: 'b',
          element: Element.telluric,
          level: OrbLevel.one,
        );
        final level = engine.mergeOrbs(0, 1);
        expect(level, isNotNull);
        expect(level!.index, greaterThanOrEqualTo(1));
      }
    });

    test('la fusión avisa con coordenadas exactas y elemento', () {
      final engine = buildEngine();
      OrbLevel? mergedLevel;
      double? mergeX;
      double? mergeY;
      Element? mergedElement;
      engine.onMerge = (level, x, y, element) {
        mergedLevel = level;
        mergeX = x;
        mergeY = y;
        mergedElement = element;
      };
      engine.tray[0] = const CombatOrb(
        id: 'a',
        element: Element.empty,
        level: OrbLevel.one,
      );
      engine.tray[2] = const CombatOrb(
        id: 'b',
        element: Element.empty,
        level: OrbLevel.one,
      );
      engine.mergeOrbs(0, 2);
      expect(mergedLevel, OrbLevel.two);
      expect(mergedElement, Element.empty);
      expect(mergeX, isNotNull);
      expect(mergeY, isNotNull);
    });

    test('las skills de carta consumen maná y hacen daño', () {
      final card = manaCard(id: 'ignis_lord', manaCost: 140, attack: 20);
      card.mana = 140;
      final engine = buildEngine(cards: [card]);
      final before = engine.bossHp;
      expect(engine.castSkill(0), isTrue);
      expect(engine.bossHp, lessThan(before));
      expect(engine.cards.first.mana, lessThan(140));
    });

    test('Grimorio Antiguo abarata las skills', () {
      ManaCard card() {
        final c = manaCard(id: 'ignis_lord', manaCost: 100, attack: 20);
        c.mana = 80;
        return c;
      }

      final plain = buildEngine(cards: [card()]);
      expect(plain.castSkill(0), isFalse);

      final grimoire = buildEngine(
        cards: [card()],
        modifiers: CombatModifiers.fromRelics(['grimorio_antiguo']),
      );
      expect(grimoire.castSkill(0), isTrue);
    });

    test('un combate completo puede terminar en victoria', () {
      final engine = buildEngine(
        boss: BossConfig(
          id: 'dummy',
          name: 'Dummy',
          element: Element.igneous,
          maxHp: 1,
        ),
      );
      hitDamage(engine, HitKind.bullseye, OrbLevel.three);
      engine.tick(0.016);
      expect(engine.finished, isTrue);
      expect(engine.victory, isTrue);
    });

    test('el motor respeta el HP inicial recibido', () {
      final engine = CombatEngine(
        boss: BossConfig.pyroth,
        cards: [manaCard()],
        playerMaxHp: 100,
        startHp: 40,
        random: math.Random(1),
      );
      expect(engine.playerHp, 40);
      expect(engine.playerMaxHp, 100);
    });
  });
}

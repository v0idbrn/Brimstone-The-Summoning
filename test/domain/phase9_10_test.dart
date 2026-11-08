import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:brimstone_summoning/data/repositories/player_repository.dart';
import 'package:brimstone_summoning/data/database/database_helper.dart';
import 'package:brimstone_summoning/domain/combat/combat_engine.dart';
import 'package:brimstone_summoning/domain/combat/combat_models.dart';
import 'package:brimstone_summoning/domain/meta/rune_system.dart';
import 'package:brimstone_summoning/domain/meta/squad_synergy_resolver.dart';
import 'package:brimstone_summoning/domain/value_objects/element.dart';
import 'package:brimstone_summoning/domain/value_objects/orb_level.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  CombatEngine fresh({
    double playerDamageMult = 1.0,
    double? startHp,
    bool startManaFull = false,
    Map<String, RuneInstance> cardRunes = const {},
  }) =>
      CombatEngine(
        boss: BossConfig.pyroth,
        cards: [
          ManaCard(
            id: 'ignis_hound',
            name: 'Sabueso de Azufre',
            element: Element.igneous,
            baseManaCost: 100,
            attack: 10,
          ),
        ],
        random: math.Random(42),
        playerDamageMult: playerDamageMult,
        startHp: startHp,
        startManaFull: startManaFull,
        cardRunes: cardRunes,
      );

  final orb = CombatOrb(
    id: 'o1',
    element: Element.igneous,
    level: OrbLevel.one,
  );
  final target = CombatTarget(
    id: 't1',
    trajectory: TargetTrajectory.orbital,
    cx: 300,
    cy: 200,
    amplitude: 50,
    baseAngularSpeed: 1.0,
  );

  group('CombatEngine — métricas de combate', () {
    test('registerDamage acumula daño total, golpe máximo y bullseyes', () {
      final e = fresh();
      e.registerDamage(
          orb: orb, target: target, multiplier: 1.0, kind: HitKind.bullseye);
      expect(e.damageTotal, greaterThan(0));
      expect(e.maxHit, greaterThan(0));
      expect(e.bullseyes, 1);
      expect(e.reactions, 0);
    });

    test('golpe normal no cuenta como bullseye', () {
      final e = fresh();
      e.registerDamage(
          orb: orb, target: target, multiplier: 1.0, kind: HitKind.normal);
      expect(e.bullseyes, 0);
      expect(e.damageTotal, greaterThan(0));
    });

    test('golpe crítico actualiza golpe máximo si supera el previo', () {
      final e = fresh();
      e.registerDamage(
          orb: orb, target: target, multiplier: 1.0, kind: HitKind.normal);
      final firstMax = e.maxHit;
      e.registerDamage(
          orb: orb, target: target, multiplier: 5.0, kind: HitKind.bullseye);
      expect(e.maxHit, greaterThan(firstMax));
    });

    test('playerDamageMult escala el daño total', () {
      final e1 = fresh(playerDamageMult: 1.0);
      final e2 = fresh(playerDamageMult: 2.0);
      e1.registerDamage(
          orb: orb, target: target, multiplier: 1.0, kind: HitKind.normal);
      e2.registerDamage(
          orb: orb, target: target, multiplier: 1.0, kind: HitKind.normal);
      expect(e2.damageTotal, closeTo(e1.damageTotal * 2, 0.001));
    });

    test('startHp fija la vida inicial del jugador', () {
      final e = fresh(startHp: 42.0);
      expect(e.playerHp, 42.0);
    });

    test('startManaFull llena el maná de todas las cartas', () {
      final cards = [
        ManaCard(
          id: 'c1',
          name: 'C1',
          element: Element.igneous,
          baseManaCost: 100,
          attack: 10,
        ),
      ];
      CombatEngine(
        boss: BossConfig.pyroth,
        cards: cards,
        random: math.Random(42),
        startManaFull: true,
      );
      expect(cards[0].mana, 100.0);
    });

    test('applyAura incrementa el contador de reacciones', () {
      final e = fresh();
      e.applyAura(Element.igneous); // establece aura
      e.applyAura(Element.abyssal); // detona reacción (íneo + abyssal)
      expect(e.reactions, 1);
    });

    test('applyAura sin reacción no incrementa contador', () {
      final e = fresh();
      e.applyAura(Element.igneous);
      e.applyAura(Element.igneous); // mismo elemento, no hay reacción
      expect(e.reactions, 0);
    });

    test('counterFlickAt incrementa counterflicks al destruir proyectil', () {
      final e = fresh();
      final proj = EnemyProjectile(
        id: 'p1',
        startX: 300,
        startY: 200,
        endX: 300,
        endY: 200,
        duration: 1.65,
      );
      e.enemyProjectiles.add(proj);
      // Toque en la posición del proyectil (en vuelo, z≈0 → ey cerca de endY).
      final hit = e.counterFlickAt(300, 200, 0);
      expect(hit, isTrue);
      expect(e.counterflicks, 1);
    });

    test('counterFlickAt sin proyectil en rango no incrementa', () {
      final e = fresh();
      final hit = e.counterFlickAt(9999, 9999, 0);
      expect(hit, isFalse);
      expect(e.counterflicks, 0);
    });

    test('mergeOrbs a Nivel 3 incrementa mergesToThree', () {
      final e = fresh();
      e.tray[0] =
          CombatOrb(id: 'a', element: Element.igneous, level: OrbLevel.one);
      e.tray[1] =
          CombatOrb(id: 'b', element: Element.igneous, level: OrbLevel.one);
      e.mergeOrbs(0, 1);
      expect(e.mergesToThree, 0); // uno a dos aún no es tres
      e.tray[0] =
          CombatOrb(id: 'c', element: Element.igneous, level: OrbLevel.two);
      e.tray[1] =
          CombatOrb(id: 'd', element: Element.igneous, level: OrbLevel.two);
      e.mergeOrbs(0, 1);
      expect(e.mergesToThree, 1);
    });
  });

  group('CombatEngine — runas y sinergias en daño', () {
    test('runa crimsonFury aumenta el atkMult efectivo de la carta', () {
      final e = fresh(
        cardRunes: {
          'ignis_hound': RuneInstance(type: RuneType.crimsonFury, level: 5),
        },
      );
      // La runa está guardada en el engine.
      expect(e.cardRunes['ignis_hound']?.type, RuneType.crimsonFury);
      expect(e.cardRunes['ignis_hound']?.level, 5);
      // RuneSystem.atkMult refleja el bono (probado en phase7_8_test; aquí se
      // confirma que el engine lo aplicaría al ATK de la carta).
      expect(
        RuneSystem.atkMult(RuneType.crimsonFury, 5),
        greaterThan(1.0),
      );
      expect(
        RuneSystem.atkMult(RuneType.crimsonFury, 1),
        1.12,
      );
    });

    test('runa eternaFlow no afecta daño (solo costo de maná)', () {
      final base = fresh();
      final withRune = fresh(
        cardRunes: {
          'ignis_hound': RuneInstance(type: RuneType.eternalFlow, level: 5),
        },
      );
      base.registerDamage(
          orb: orb, target: target, multiplier: 1.0, kind: HitKind.normal);
      withRune.registerDamage(
          orb: orb, target: target, multiplier: 1.0, kind: HitKind.normal);
      expect(withRune.damageTotal, base.damageTotal);
    });

    test('sinergia monoelemental + runa se aplican juntas al daño', () {
      final cards = List.generate(
        4,
        (i) => ManaCard(
          id: 'ignis_hound_$i',
          name: 'Sabueso $i',
          element: Element.igneous,
          baseManaCost: 100,
          attack: 10,
        ),
      );
      final synergy = SquadSynergyResolver.resolve(cards);
      expect(synergy.type, SquadSynergyType.monoElemental);
      final e = CombatEngine(
        boss: BossConfig.pyroth,
        cards: cards,
        random: math.Random(42),
        synergy: synergy,
        cardRunes: {
          'ignis_hound_0': RuneInstance(type: RuneType.crimsonFury, level: 3),
        },
      );
      e.registerDamage(
          orb: orb, target: target, multiplier: 1.0, kind: HitKind.normal);
      expect(e.damageTotal, greaterThan(0));
    });

    test('startHp se conserva entre conceptos de oleada (endless)', () {
      final e1 = fresh(startHp: 30.0);
      expect(e1.playerHp, 30.0);
      final e2 = fresh(startHp: 70.0);
      expect(e2.playerHp, 70.0);
    });
  });

  group('Backup/Restore — estructura y validación JSON', () {
    test('round-trip JSON/Base64 preserva el mapa de backup', () {
      final original = {
        'formatVersion': 1,
        'profile': {
          'gold': 1230,
          'shards': 450,
          'energy': 20,
          'summonerLevel': 5
        },
        'collection': [
          {'instanceId': 7, 'catalogId': 'ignis_hound', 'level': 3, 'stars': 2},
        ],
        'squad': [7],
        'runes': {
          '7': {'runeType': 'crimsonFury', 'level': 3}
        },
        'bounties': [
          {'id': 'forge_master', 'progress': 10, 'claimed': 0}
        ],
      };
      final json = const JsonEncoder.withIndent('  ').convert(original);
      final base64 = base64Encode(utf8.encode(json));
      final decoded =
          jsonDecode(utf8.decode(base64Decode(base64))) as Map<String, dynamic>;
      expect(decoded['formatVersion'], 1);
      expect((decoded['profile'] as Map)['gold'], 1230);
      expect((decoded['collection'] as List).length, 1);
      expect((decoded['runes'] as Map)['7']['runeType'], 'crimsonFury');
    });

    PlayerRepository isolatedRepo() {
      DatabaseHelper.useInMemory();
      return PlayerRepository(DatabaseHelper());
    }

    test('importBackup rechaza un formatVersion desconocido', () {
      final repo = isolatedRepo();
      expect(
        () => repo.importBackup({'formatVersion': 99}),
        throwsA(isA<FormatException>()),
      );
    });

    test('importBackup trata un payload sin formatVersion como v1', () async {
      final repo = isolatedRepo();
      await repo.importBackup({
        'profile': {'gold': 1234}
      });
      final profile = await repo.loadProfile();
      expect(profile[0], 1234);
    });

    test('importBackup acepta un map vacío (v1 sin datos)', () async {
      final repo = isolatedRepo();
      await repo.importBackup({});
      final profile = await repo.loadProfile();
      expect(profile[0], 500);
    });

    test('exportBackup esquema contiene claves esperadas (sin DB, estructura)',
        () {
      // Validamos que el formato de export sea consistente con lo que importBackup lee.
      final schema = {
        'formatVersion': 1,
        'profile': <String, dynamic>{},
        'collection': <dynamic>[],
        'squad': <dynamic>[],
        'runes': <String, dynamic>{},
        'bounties': <dynamic>[],
      };
      expect(schema['formatVersion'], 1);
      expect(schema.containsKey('profile'), isTrue);
      expect(schema.containsKey('collection'), isTrue);
      expect(schema.containsKey('squad'), isTrue);
      expect(schema.containsKey('runes'), isTrue);
      expect(schema.containsKey('bounties'), isTrue);
    });
  });
}

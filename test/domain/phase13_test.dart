import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:brimstone_summoning/data/database/database_helper.dart';
import 'package:brimstone_summoning/domain/combat/combat_engine.dart';
import 'package:brimstone_summoning/domain/combat/combat_models.dart';
import 'package:brimstone_summoning/domain/meta/leader_skill.dart';
import 'package:brimstone_summoning/domain/value_objects/element.dart';
import 'package:brimstone_summoning/domain/value_objects/orb_level.dart';

/// Las 20 ids de catálogo esperadas tras la expansión Fase 13.
const _catalog20 = [
  'ignis_hound',
  'ignis_lord',
  'ignis_drake',
  'ignis_seraph',
  'ignis_colossus',
  'abyss_stalker',
  'abyss_leviathan',
  'abyss_siren',
  'abyss_kraken',
  'abyss_wraith',
  'terra_golem',
  'terra_titan',
  'terra_warden',
  'terra_hydra',
  'terra_behemoth',
  'void_specter',
  'void_malakor',
  'void_reaper',
  'void_oracle',
  'void_archon',
];

/// Helper para crear un DatabaseHelper aislado por test (evita locks SQLite en paralelo).
DatabaseHelper _freshDb() {
  // Base en memoria por instancia: dos suites nunca comparten archivo ni
  // conexion, asi que no puede aparecer 'database is locked'.
  DatabaseHelper.useInMemory();
  return DatabaseHelper();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        final dir = Directory(Directory.current.path);
        return dir.path;
      }
      return null;
    },
  );

  CombatEngine fresh({required List<ManaCard> cards}) => CombatEngine(
        boss: BossConfig.pyroth,
        cards: cards,
        random: math.Random(42),
      );

  ManaCard card({
    required String id,
    required Element element,
    int stars = 1,
    double mana = 0,
  }) =>
      ManaCard(
        id: id,
        name: '$id test',
        element: element,
        baseManaCost: 100,
        attack: 10,
        stars: stars,
        mana: mana,
      );

  group('Phase 13 — catálogo TCG de 20 criaturas', () {
    test('seed de base de datos contiene exactamente 20 cartas de catálogo',
        () async {
      final db = await _freshDb().db;
      final rows = await db.query('cards');
      final ids = rows.map((r) => r['id'] as String).toSet();
      expect(ids.length, 20);
      for (final id in _catalog20) {
        expect(ids, contains(id), reason: 'falta $id en el catálogo');
      }
    });

    test('todas las 20 criaturas tienen skill de catálogo asignada', () {
      // CombatEngine expone las descripciones de skill por id del catálogo.
      // Validamos que cada id del catálogo resuelva a una habilidad conocida.
      for (final id in _catalog20) {
        final engine = fresh(cards: [card(id: id, element: Element.igneous)]);
        // castSkill con maná lleno ejecuta la skill sin lanzar excepción.
        engine.cards[0].mana = engine.cards[0].baseManaCost.toDouble();
        engine.targets.add(CombatTarget(
          id: 't1',
          trajectory: TargetTrajectory.orbital,
          cx: 500.0,
          cy: 200.0,
          amplitude: 0.0,
          baseAngularSpeed: 0.0,
        ));
        final hpBefore = engine.bossHp;
        engine.castSkill(0);
        expect(engine.bossHp, lessThanOrEqualTo(hpBefore),
            reason: '$id no aplicó daño de skill');
      }
    });
  });

  group('Phase 13 — LeaderSkill (pasiva del Líder, slot 0)', () {
    test('líder Ígneo otorga +15% / +22.5% / +30% daño de esferas por estrella',
        () {
      expect(
        LeaderSkill(element: Element.igneous, stars: 1).orbDamageMult,
        closeTo(1.15, 1e-9),
      );
      expect(
        LeaderSkill(element: Element.igneous, stars: 2).orbDamageMult,
        closeTo(1.225, 1e-9),
      );
      expect(
        LeaderSkill(element: Element.igneous, stars: 3).orbDamageMult,
        closeTo(1.30, 1e-9),
      );
      // Líder de otro elemento no bono las esferas.
      expect(
        LeaderSkill(element: Element.abyssal, stars: 3).orbDamageMult,
        1.0,
      );
    });

    test('líder Abisal otorga +20% / +27.5% / +35% ganancia de maná', () {
      expect(
        LeaderSkill(element: Element.abyssal, stars: 1).manaGainMult,
        closeTo(1.20, 1e-9),
      );
      expect(
        LeaderSkill(element: Element.abyssal, stars: 2).manaGainMult,
        closeTo(1.275, 1e-9),
      );
      expect(
        LeaderSkill(element: Element.abyssal, stars: 3).manaGainMult,
        closeTo(1.35, 1e-9),
      );
      expect(
        LeaderSkill(element: Element.telluric, stars: 3).manaGainMult,
        1.0,
      );
    });

    test('líder Telúrico reduce daño recibido -15% / -20% / -25%', () {
      expect(
        LeaderSkill(element: Element.telluric, stars: 1).damageTakenMult,
        closeTo(0.85, 1e-9),
      );
      expect(
        LeaderSkill(element: Element.telluric, stars: 2).damageTakenMult,
        closeTo(0.80, 1e-9),
      );
      expect(
        LeaderSkill(element: Element.telluric, stars: 3).damageTakenMult,
        closeTo(0.75, 1e-9),
      );
      expect(
        LeaderSkill(element: Element.igneous, stars: 3).damageTakenMult,
        1.0,
      );
    });

    test('líder Vacío otorga +20% / +30% / +40% crítico Bullseye', () {
      expect(
        LeaderSkill(element: Element.empty, stars: 1).critBullseyeMult,
        closeTo(1.20, 1e-9),
      );
      expect(
        LeaderSkill(element: Element.empty, stars: 2).critBullseyeMult,
        closeTo(1.30, 1e-9),
      );
      expect(
        LeaderSkill(element: Element.empty, stars: 3).critBullseyeMult,
        closeTo(1.40, 1e-9),
      );
      expect(
        LeaderSkill(element: Element.telluric, stars: 3).critBullseyeMult,
        1.0,
      );
    });

    test('escuadrón sin cartas no produce LeaderSkill', () {
      expect(leaderSkillOf(<ManaCard>[]), isNull);
    });

    test('leaderSkillOf deriva elemento y estrellas de la carta slot 0', () {
      final ls = leaderSkillOf([
        card(id: 'ignis_colossus', element: Element.igneous, stars: 3),
        card(id: 'abyss_siren', element: Element.abyssal, stars: 1),
      ]);
      expect(ls?.element, Element.igneous);
      expect(ls?.stars, 3);
      expect(ls?.orbDamageMult, closeTo(1.30, 1e-9));
    });
  });

  group('Phase 13 — skills activas de las 12 criaturas nuevas', () {
    test('ignis_drake: daño single 1.8x + aura Ígnea', () {
      final e = fresh(
        cards: [card(id: 'ignis_drake', element: Element.igneous)],
      );
      e.cards[0].mana = e.cards[0].baseManaCost.toDouble();
      e.targets.add(CombatTarget(
        id: 't1',
        trajectory: TargetTrajectory.orbital,
        cx: 500.0,
        cy: 200.0,
        amplitude: 0.0,
        baseAngularSpeed: 0.0,
      ));
      final hpBefore = e.bossHp;
      e.castSkill(0);
      expect(e.bossHp, lessThan(hpBefore));
      expect(e.aura, Element.igneous);
    });

    test('ignis_seraph: daño AoE 3.0x + aura Ígnea', () {
      final e = fresh(
        cards: [card(id: 'ignis_seraph', element: Element.igneous)],
      );
      e.cards[0].mana = e.cards[0].baseManaCost.toDouble();
      e.targets.add(CombatTarget(
        id: 't1',
        trajectory: TargetTrajectory.orbital,
        cx: 500.0,
        cy: 200.0,
        amplitude: 0.0,
        baseAngularSpeed: 0.0,
      ));
      final hpBefore = e.bossHp;
      e.castSkill(0);
      expect(e.bossHp, lessThan(hpBefore));
      expect(e.aura, Element.igneous);
    });

    test('ignis_colossus: daño AoE 4.5x + aturde jefe 2.0s', () {
      final e = fresh(
        cards: [card(id: 'ignis_colossus', element: Element.igneous)],
      );
      e.cards[0].mana = e.cards[0].baseManaCost.toDouble();
      e.castSkill(0);
      expect(e.bossStunRemaining, closeTo(2.0, 1e-9));
      expect(e.aura, Element.igneous);
    });

    test('abyss_siren: daño single 1.8x + congela 2s + aura Abisal', () {
      final e = fresh(
        cards: [card(id: 'abyss_siren', element: Element.abyssal)],
      );
      e.cards[0].mana = e.cards[0].baseManaCost.toDouble();
      e.targets.add(CombatTarget(
        id: 't1',
        trajectory: TargetTrajectory.orbital,
        cx: 500.0,
        cy: 200.0,
        amplitude: 0.0,
        baseAngularSpeed: 0.0,
      ));
      e.castSkill(0);
      expect(e.targets.first.frozen, isTrue);
      expect(e.targets.first.frozenRemaining, closeTo(2.0, 1e-9));
      expect(e.aura, Element.abyssal);
    });

    test('abyss_kraken: daño AoE 2.8x + aura Abisal', () {
      final e = fresh(
        cards: [card(id: 'abyss_kraken', element: Element.abyssal)],
      );
      e.cards[0].mana = e.cards[0].baseManaCost.toDouble();
      e.castSkill(0);
      expect(e.aura, Element.abyssal);
    });

    test('abyss_wraith: daño AoE 3.6x + congela 4s + aura Abisal', () {
      final e = fresh(
        cards: [card(id: 'abyss_wraith', element: Element.abyssal)],
      );
      e.cards[0].mana = e.cards[0].baseManaCost.toDouble();
      e.targets.add(CombatTarget(
        id: 't1',
        trajectory: TargetTrajectory.orbital,
        cx: 500.0,
        cy: 200.0,
        amplitude: 0.0,
        baseAngularSpeed: 0.0,
      ));
      e.castSkill(0);
      expect(e.targets.first.frozenRemaining, closeTo(4.0, 1e-9));
      expect(e.aura, Element.abyssal);
    });

    test('terra_warden: escudo 25% HP max + aura Telúrica', () {
      final e = fresh(
        cards: [card(id: 'terra_warden', element: Element.telluric)],
      );
      e.cards[0].mana = e.cards[0].baseManaCost.toDouble();
      final shieldBefore = e.shield;
      e.castSkill(0);
      expect(e.shield, greaterThan(shieldBefore));
      expect(e.aura, Element.telluric);
    });

    test('terra_hydra: daño AoE 2.6x + aura Telúrica', () {
      final e = fresh(
        cards: [card(id: 'terra_hydra', element: Element.telluric)],
      );
      e.cards[0].mana = e.cards[0].baseManaCost.toDouble();
      e.castSkill(0);
      expect(e.aura, Element.telluric);
    });

    test('terra_behemoth: daño AoE 4.0x + aturde 2.5s + aura Telúrica', () {
      final e = fresh(
        cards: [card(id: 'terra_behemoth', element: Element.telluric)],
      );
      e.cards[0].mana = e.cards[0].baseManaCost.toDouble();
      e.castSkill(0);
      expect(e.bossStunRemaining, closeTo(2.5, 1e-9));
      expect(e.aura, Element.telluric);
    });

    test('void_reaper: daño single 2.0x + drena vida + aura Vacío', () {
      final e = fresh(
        cards: [card(id: 'void_reaper', element: Element.empty)],
      );
      e.cards[0].mana = e.cards[0].baseManaCost.toDouble();
      e.targets.add(CombatTarget(
        id: 't1',
        trajectory: TargetTrajectory.orbital,
        cx: 500.0,
        cy: 200.0,
        amplitude: 0.0,
        baseAngularSpeed: 0.0,
      ));
      final hpBefore = e.playerHp;
      e.castSkill(0);
      expect(e.playerHp, greaterThanOrEqualTo(hpBefore));
      expect(e.aura, Element.empty);
    });

    test('void_oracle: daño AoE 3.2x + aura Vacío', () {
      final e = fresh(
        cards: [card(id: 'void_oracle', element: Element.empty)],
      );
      e.cards[0].mana = e.cards[0].baseManaCost.toDouble();
      e.castSkill(0);
      expect(e.aura, Element.empty);
    });

    test('void_archon: daño AoE 4.8x + vulnera jefe 4s + aura Vacío', () {
      final e = fresh(
        cards: [card(id: 'void_archon', element: Element.empty)],
      );
      e.cards[0].mana = e.cards[0].baseManaCost.toDouble();
      e.castSkill(0);
      expect(e.vulnerableRemaining, closeTo(4.0, 1e-9));
      expect(e.aura, Element.empty);
    });
  });

  group('Phase 13 — LeaderSkill aplicado en combate', () {
    test('líder Telúrico reduce el daño recibido del jugador', () {
      final leader =
          card(id: 'terra_golem', element: Element.telluric, stars: 3);
      final e = fresh(cards: [leader]);
      final hpBefore = e.playerHp;
      e.hitPlayer();
      final taken = hpBefore - e.playerHp;
      // Telúrico 3★: -25% daño recibido.
      expect(taken, closeTo(BossConfig.pyroth.attackDamage * 0.75, 1e-6));
    });

    test('líder no Telúrico recibe daño íntegro del jefe', () {
      final leader =
          card(id: 'ignis_hound', element: Element.igneous, stars: 3);
      final e = fresh(cards: [leader]);
      final hpBefore = e.playerHp;
      e.hitPlayer();
      expect(
          hpBefore - e.playerHp, closeTo(BossConfig.pyroth.attackDamage, 1e-6));
    });

    test('líder Vacío multiplica daño crítico Bullseye de esferas', () {
      final leader = card(id: 'void_specter', element: Element.empty, stars: 3);
      final e = fresh(cards: [leader]);
      final target = CombatTarget(
        id: 't1',
        trajectory: TargetTrajectory.orbital,
        cx: 500.0,
        cy: 200.0,
        amplitude: 0.0,
        baseAngularSpeed: 0.0,
      );
      const base = 50.0;
      // Daño con líder vacío vs sin líder en bullseye: ratio 1.4.
      final withLeader = _singleHitDamage(e, target, base, HitKind.bullseye);
      // Control: líder Telúrico (sin bono de orbes ni crítico) para aislar
      // únicamente el multiplicador crítico del Vacío.
      final withoutLeader = _singleHitDamage(
        fresh(cards: [card(id: 'terra_golem', element: Element.telluric)]),
        target,
        base,
        HitKind.bullseye,
      );
      expect(withLeader / withoutLeader, closeTo(1.40, 1e-6));
    });
  });
}

/// Lanza un solo registro de daño y devuelve el daño infligido al jefe.
double _singleHitDamage(
  CombatEngine e,
  CombatTarget target,
  double base,
  HitKind kind,
) {
  final hpBefore = e.bossHp;
  e.registerDamage(
    orb: CombatOrb(id: 'o', element: Element.igneous, level: OrbLevel.one),
    target: target,
    multiplier: 1.0,
    kind: kind,
  );
  return hpBefore - e.bossHp;
}

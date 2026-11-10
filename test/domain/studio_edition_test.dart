import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';

import 'package:brimstone_summoning/data/database/database_helper.dart';
import 'package:brimstone_summoning/data/repositories/player_repository.dart';
import 'package:brimstone_summoning/domain/arena/archon_league.dart';
import 'package:brimstone_summoning/domain/combat/combat_engine.dart';
import 'package:brimstone_summoning/domain/combat/combat_models.dart';
import 'package:brimstone_summoning/domain/combat/overdrive.dart';
import 'package:brimstone_summoning/domain/combat/verlet_sparks.dart';
import 'package:brimstone_summoning/domain/entities/owned_card.dart';
import 'package:brimstone_summoning/domain/meta/elemental_chambers.dart';
import 'package:brimstone_summoning/domain/meta/mythic_ascension.dart';
import 'package:brimstone_summoning/domain/value_objects/card_skin.dart';
import 'package:brimstone_summoning/domain/value_objects/element.dart';
import 'package:brimstone_summoning/domain/value_objects/orb_level.dart';
import 'package:brimstone_summoning/domain/value_objects/rarity.dart';
import 'package:brimstone_summoning/presentation/graphics/combat_sparks.dart';
import 'package:brimstone_summoning/presentation/graphics/dynamic_camera.dart';
import 'package:brimstone_summoning/presentation/widgets/overdrive_bar.dart';

// ───────────────────────────────────────────────────────────── harness

DatabaseHelper freshHelper() {
  DatabaseHelper.useInMemory();
  return DatabaseHelper();
}

PlayerRepository freshRepo() => PlayerRepository(freshHelper());

OwnedCard ownedCard({
  int instanceId = 1,
  String catalogId = 'ignis_hound',
  Element element = Element.igneous,
  int stars = 4,
  int attack = 10,
  int health = 15,
  int manaCost = 100,
  int level = 1,
  CardSkin skin = CardSkin.classic,
}) =>
    OwnedCard(
      instanceId: instanceId,
      catalogId: catalogId,
      name: 'Sabueso de Azufre',
      element: element,
      rarity: Rarity.common,
      baseManaCost: manaCost,
      baseAttack: attack,
      baseHealth: health,
      level: level,
      stars: stars,
      skillLevel: 1,
      masteryXp: 0,
      skin: skin,
    );

CombatEngine engineWith({
  int? scoreTarget,
  double duelDuration = 45,
  double bossHp = 5000,
  double attackDamage = 0,
  int seed = 7,
  List<ManaCard>? cards,
}) =>
    CombatEngine(
      boss: BossConfig(
        id: 'test_guardian',
        name: 'Guardián de Prueba',
        element: Element.igneous,
        maxHp: bossHp,
        attackInterval: 99,
        attackDamage: attackDamage,
        shieldHp: 0.0001,
      ),
      cards: cards ??
          [
            ManaCard(
              id: 'ignis_hound',
              name: 'Sabueso',
              element: Element.igneous,
              baseManaCost: 100,
              attack: 10,
            ),
          ],
      playerMaxHp: 500,
      random: math.Random(seed),
      scoreTarget: scoreTarget,
      duelDuration: duelDuration,
    );

CombatOrb orb() =>
    const CombatOrb(id: 'o1', element: Element.igneous, level: OrbLevel.one);

void main() {
  // ══════════════════════════════════════════════════ 5★ ASCENSIÓN MÍTICA

  group('Studio — Ascensión mítica 5★', () {
    test('el techo clásico sigue en 4★ y la ascensión exige 4★', () {
      expect(MythicAscension.canAscend(4), isTrue);
      expect(MythicAscension.canAscend(3), isFalse);
      expect(MythicAscension.canAscend(5), isFalse);
      expect(MythicAscension.ascensionStars, 4);
      expect(MythicAscension.maxStars, 5);
    });

    test('coste total = 1 200 esquirlas + 2 500 oro', () {
      expect(MythicAscension.shardCost, 1200);
      expect(MythicAscension.goldCost, 2500);
      expect(MythicAscension.totalCost(), 3700);
    });

    test('estadísticas +45% y maná -8', () {
      expect(MythicAscension.attackAfter(100), 145);
      expect(MythicAscension.healthAfter(40), 58);
      expect(MythicAscension.manaAfter(100), 92);
      expect(MythicAscension.manaAfter(4), 0);
      expect(MythicAscension.statMultiplier, closeTo(1.45, 1e-9));
      expect(MythicAscension.squadElementalBonus, closeTo(0.08, 1e-9));
    });

    test('la pasiva mítica se rotula en español', () {
      expect(MythicAscension.passiveLabel, contains('8%'));
      expect(MythicAscension.passiveLabel, contains('DAÑO ELEMENTAL'));
    });

    test('OwnedCard.isMythic distingue 4★ de 5★', () {
      expect(ownedCard(stars: 4).isMythic, isFalse);
      expect(ownedCard(stars: 5).isMythic, isTrue);
    });

    test('copyWith conserva skin y permite cambiar maná base', () {
      final card = ownedCard(stars: 5, skin: CardSkin.abyssal);
      final next = card.copyWith(
        skin: CardSkin.celestial,
        baseManaCost: 92,
        stars: 5,
      );
      expect(next.skin, CardSkin.celestial);
      expect(next.baseManaCost, 92);
      expect(card.skin, CardSkin.abyssal, reason: 'inmutable');
    });

    test('la ascensión aplica las tres reglas a la vez', () {
      final base = ownedCard(stars: 4, attack: 20, health: 30, manaCost: 110);
      final ascended = base.copyWith(
        stars: 5,
        attack: MythicAscension.attackAfter(base.baseAttack),
        health: MythicAscension.healthAfter(base.baseHealth),
        baseManaCost: MythicAscension.manaAfter(base.baseManaCost),
      );
      expect(ascended.stars, 5);
      expect(ascended.baseAttack, 29);
      expect(ascended.baseHealth, 44);
      expect(ascended.baseManaCost, 102);
      expect(ascended.isMythic, isTrue);
    });

    test('los tres skins tienen etiqueta propia', () {
      final labels = CardSkin.values.map((s) => s.label).toSet();
      expect(labels.length, 3);
      expect(CardSkin.classic.isClassic, isTrue);
      expect(CardSkin.abyssal.isClassic, isFalse);
      expect(CardSkin.celestial.label, contains('CELESTIAL'));
    });

    test('el skin 5★ sobrevive al round-trip en SQLite', () async {
      final repo = freshRepo();
      final summoned = await repo.insertSummonedCard('ignis_hound');
      final ascended = summoned.copyWith(
        stars: 5,
        attack: MythicAscension.attackAfter(summoned.baseAttack),
        health: MythicAscension.healthAfter(summoned.baseHealth),
        baseManaCost: MythicAscension.manaAfter(summoned.baseManaCost),
        skin: CardSkin.abyssal,
      );
      await repo.updateOwnedCard(ascended);
      final loaded = await repo.loadCollection();
      expect(loaded, hasLength(1));
      expect(loaded.first.stars, 5);
      expect(loaded.first.skin, CardSkin.abyssal);
      expect(loaded.first.baseManaCost, ascended.baseManaCost);
    });

    test('sin skin elegida la colección carga CLÁSICA', () async {
      final repo = freshRepo();
      await repo.insertSummonedCard('abyss_stalker');
      final loaded = await repo.loadCollection();
      expect(loaded.single.skin, CardSkin.classic);
    });
  });

  // ══════════════════════════════════════════════════ COLISEO

  group('Studio — Coliseo de los Arcontes', () {
    const thresholds = {
      ArchonLeague.ceniza: 0,
      ArchonLeague.hierro: 300,
      ArchonLeague.bronce: 700,
      ArchonLeague.plata: 1200,
      ArchonLeague.oroImperial: 1800,
      ArchonLeague.granArconte: 2600,
    };

    for (final entry in thresholds.entries) {
      test('${entry.key.label} arranca en ${entry.value} trofeos', () {
        expect(entry.key.minTrophies, entry.value);
        expect(ArchonRanking.leagueFor(entry.value), entry.key);
        expect(
          ArchonRanking.leagueFor(entry.value + 120),
          entry.key,
          reason: 'no debe saltar antes del umbral siguiente',
        );
      });
    }

    test('leagueFor reparte las seis divisiones', () {
      expect(ArchonRanking.leagueFor(299), ArchonLeague.ceniza);
      expect(ArchonRanking.leagueFor(700), ArchonLeague.bronce);
      expect(ArchonRanking.leagueFor(99999), ArchonLeague.granArconte);
    });

    test('nextThreshold apunta al siguiente escalón y null en la cima', () {
      expect(ArchonRanking.nextThreshold(0), 300);
      expect(ArchonRanking.nextThreshold(300), 700);
      expect(ArchonRanking.nextThreshold(2599), 2600);
      expect(ArchonRanking.nextThreshold(2600), isNull);
    });

    test('progressToNext es 0 al entrar y 1 en la cima', () {
      expect(ArchonRanking.progressToNext(300), closeTo(0.0, 1e-9));
      expect(ArchonRanking.progressToNext(500), closeTo(0.5, 1e-9));
      expect(ArchonRanking.progressToNext(3000), 1.0);
    });

    test('perder resta 12 trofeos sin bajar del piso de liga', () {
      expect(ArchonRanking.trophiesAfterLoss(400), 388);
      expect(ArchonRanking.trophiesAfterLoss(305), 300);
      expect(ArchonRanking.trophiesAfterLoss(0), 0);
      expect(ArchonRanking.trophiesAfterLoss(2600), 2600);
    });

    test('el generador es determinista con la misma semilla', () {
      final a = ArchonDuelGenerator.generate(
        random: math.Random(99),
        trophies: 850,
      );
      final b = ArchonDuelGenerator.generate(
        random: math.Random(99),
        trophies: 850,
      );
      expect(a.length, 3);
      for (var i = 0; i < a.length; i++) {
        expect(a[i].name, b[i].name);
        expect(a[i].title, b[i].title);
        expect(a[i].targetScore, b[i].targetScore);
        expect(
          a[i].cards.map((c) => c.catalogId).toList(),
          b[i].cards.map((c) => c.catalogId).toList(),
        );
      }
    });

    test('los tres rivales usan los tres niveles de desafío', () {
      final rivals = ArchonDuelGenerator.generate(
        random: math.Random(5),
        trophies: 0,
      );
      expect(rivals.map((r) => r.tier).toList(), ArchonDuelTier.values);
      expect(rivals[0].pointsAtStake, 45);
      expect(rivals[1].pointsAtStake, 85);
      expect(rivals[2].pointsAtStake, 140);
    });

    test('cada rival presenta 4 cartas distintas', () {
      final rivals = ArchonDuelGenerator.generate(
        random: math.Random(11),
        trophies: 1200,
      );
      for (final rival in rivals) {
        expect(rival.cards, hasLength(4));
        expect(rival.cards.map((c) => c.catalogId).toSet(), hasLength(4));
        expect(rival.power, greaterThan(0));
      }
    });

    test('el puntaje objetivo escala con los trofeos', () {
      final low = ArchonDuelGenerator.generate(
        random: math.Random(3),
        trophies: 0,
      );
      final high = ArchonDuelGenerator.generate(
        random: math.Random(3),
        trophies: 2500,
      );
      expect(high.last.targetScore, greaterThan(low.last.targetScore));
      expect(low.last.targetScore, greaterThanOrEqualTo(120));
    });

    test('victoria suma puntos, racha y récord', () {
      const start = ArchonProgress(trophies: 300, streak: 2, bestStreak: 2);
      final next = start.recordWin(tier: ArchonDuelTier.parejo, bonus: 0);
      expect(next.trophies, 300 + 85 + 10);
      expect(next.wins, 1);
      expect(next.streak, 3);
      expect(next.bestStreak, 3);
    });

    test('la racha aporta como máximo +25 trofeos', () {
      const start = ArchonProgress(trophies: 0, streak: 40, bestStreak: 40);
      final next = start.recordWin(tier: ArchonDuelTier.facil, bonus: 0);
      expect(next.trophies, 45 + 25);
    });

    test('caer reinicia la racha y conserva el récord', () {
      const start = ArchonProgress(
        trophies: 1250,
        wins: 4,
        losses: 1,
        streak: 3,
        bestStreak: 7,
      );
      final next = start.recordLoss();
      expect(next.trophies, 1238);
      expect(next.losses, 2);
      expect(next.streak, 0);
      expect(next.bestStreak, 7);
      expect(next.wins, 4);
    });

    test('los cofres crecen con la liga y la dificultad', () {
      const bronze = ArchonProgress(trophies: 700);
      const apex = ArchonProgress(trophies: 2600);
      final easy = bronze.rewardsFor(ArchonDuelTier.facil);
      final hard = bronze.rewardsFor(ArchonDuelTier.desafio);
      final apexChest = apex.rewardsFor(ArchonDuelTier.facil);
      expect(hard.shards, greaterThan(easy.shards));
      expect(apexChest.shards, greaterThan(easy.shards));
      expect(hard.gold, greaterThan(easy.gold));
      expect(apexChest.goldenCardChance, greaterThan(easy.goldenCardChance));
    });

    test('el progreso de liga persiste en SQLite', () async {
      final repo = freshRepo();
      expect((await repo.loadArchonProgress()).trophies, 0);
      await repo.saveArchonProgress(
        const ArchonProgress(
          trophies: 1830,
          wins: 9,
          losses: 3,
          streak: 4,
          bestStreak: 6,
        ),
      );
      final loaded = await repo.loadArchonProgress();
      expect(loaded.trophies, 1830);
      expect(loaded.wins, 9);
      expect(loaded.losses, 3);
      expect(loaded.streak, 4);
      expect(loaded.bestStreak, 6);
      expect(loaded.league, ArchonLeague.oroImperial);
    });

    test('guardar dos veces actualiza la misma fila', () async {
      final repo = freshRepo();
      await repo.saveArchonProgress(const ArchonProgress(trophies: 100));
      await repo.saveArchonProgress(const ArchonProgress(trophies: 2600));
      expect((await repo.loadArchonProgress()).trophies, 2600);
    });
  });

  // ══════════════════════════════════════════════════ CÁMARAS

  group('Studio — Cámaras Elementales', () {
    test('existen las cuatro cámaras, una por elemento', () {
      expect(ElementalChambers.all, hasLength(4));
      expect(
        ElementalChambers.all.map((c) => c.element).toSet(),
        Element.values.toSet(),
      );
      expect(ElementalChambers.byId('fosa_abismal'), ElementalChambers.fosa);
      expect(ElementalChambers.byId('nope').id, ElementalChambers.crater.id);
    });

    test('el elemento favorecido es el opuesto del guardián', () {
      expect(ElementalChambers.crater.favoured, Element.abyssal);
      expect(ElementalChambers.fosa.favoured, Element.empty);
      expect(ElementalChambers.monolito.favoured, Element.igneous);
      expect(ElementalChambers.eclipse.favoured, Element.telluric);
    });

    test('el bono es ×2 solo con el elemento opuesto', () {
      expect(
        ChamberRules.elementBonus(
          squadElement: Element.abyssal,
          chamberElement: Element.igneous,
        ),
        2.0,
      );
      expect(
        ChamberRules.elementBonus(
          squadElement: Element.igneous,
          chamberElement: Element.igneous,
        ),
        1.0,
      );
    });

    test('el HP del guardián escala por dificultad', () {
      final normal = ChamberRules.bossHpFor(
        difficulty: ChamberDifficulty.normal,
        chapterHp: 600,
      );
      final hell = ChamberRules.bossHpFor(
        difficulty: ChamberDifficulty.infierno,
        chapterHp: 600,
      );
      expect(normal, 600);
      expect(hell, 1350);
      expect(hell, greaterThan(normal));
    });

    test('las tres dificultades declaran su etiqueta', () {
      expect(ChamberDifficulty.normal.label, 'NORMAL');
      expect(ChamberDifficulty.pesadilla.label, 'PESADILLA');
      expect(ChamberDifficulty.infierno.label, 'INFIERNO');
      expect(ChamberDifficulty.normal.isNightmarePlus, isFalse);
      expect(ChamberDifficulty.infierno.isNightmarePlus, isTrue);
    });

    test('las recompensas crecen con la dificultad', () {
      final normal = ChamberRules.rewardsFor(
        chamber: ElementalChambers.crater,
        difficulty: ChamberDifficulty.normal,
        oppositeBonus: false,
      );
      final hell = ChamberRules.rewardsFor(
        chamber: ElementalChambers.crater,
        difficulty: ChamberDifficulty.infierno,
        oppositeBonus: false,
      );
      expect(hell.essences, greaterThan(normal.essences));
      expect(hell.gold, greaterThan(normal.gold));
      expect(hell.masteryXp, greaterThan(normal.masteryXp));
      expect(hell.grantsRune, isTrue);
      expect(normal.grantsRune, isFalse);
    });

    test('el bono de elemento opuesto duplica el botín', () {
      final plain = ChamberRules.rewardsFor(
        chamber: ElementalChambers.monolito,
        difficulty: ChamberDifficulty.pesadilla,
        oppositeBonus: false,
      );
      final doubled = ChamberRules.rewardsFor(
        chamber: ElementalChambers.monolito,
        difficulty: ChamberDifficulty.pesadilla,
        oppositeBonus: true,
      );
      expect(doubled.essences, greaterThan(plain.essences + 40));
      expect(doubled.gold, plain.gold * 2);
      expect(doubled.masteryXp, plain.masteryXp * 2);
      expect(doubled.runeChance, lessThanOrEqualTo(1.0));
    });

    test('la clave de clear incluye cámara y dificultad', () {
      expect(
        ChamberRules.clearKey(
          ElementalChambers.eclipse,
          ChamberDifficulty.infierno,
        ),
        'eclipse_vacio:infierno',
      );
    });

    test('un clear se registra la primera vez y se repite después', () async {
      final repo = freshRepo();
      final first = await repo.recordChamberClear(
        ElementalChambers.crater,
        ChamberDifficulty.pesadilla,
      );
      final second = await repo.recordChamberClear(
        ElementalChambers.crater,
        ChamberDifficulty.pesadilla,
      );
      expect(first, isTrue);
      expect(second, isFalse);
      final clears = await repo.loadChamberClears();
      expect(
        clears.containsKey('crater_igneo:pesadilla'),
        isTrue,
      );
      expect(clears['crater_igneo:pesadilla']!.firstClear, isFalse);
      expect(clears['crater_igneo:pesadilla']!.clearedAt, greaterThan(0));
    });

    test('las esencias se acumulan y se gastan', () async {
      final repo = freshRepo();
      await repo.addEssence(Element.igneous, 40);
      await repo.addEssence(Element.igneous, 15);
      expect(await repo.loadEssence(Element.igneous), 55);
      expect(await repo.spendEssence(Element.igneous, 60), isFalse);
      expect(await repo.spendEssence(Element.igneous, 55), isTrue);
      expect(await repo.loadEssence(Element.igneous), 0);
      expect((await repo.loadEssences())[Element.igneous.name], 0);
    });

    test('la maestría de las cartas equipadas sube y topea en 999', () async {
      final repo = freshRepo();
      final card = await repo.insertSummonedCard('ignis_hound');
      expect(await repo.addMasteryXp(card.instanceId, 90), 90);
      expect(await repo.addMasteryXp(card.instanceId, 950), 999);
    });
  });

  // ══════════════════════════════════════════════════ OVERDRIVE

  group('Studio — OVERDRIVE', () {
    test('las constantes del frenesí son las pactadas', () {
      expect(OverdriveRules.duration, 6.0);
      expect(OverdriveRules.damageMult, 1.4);
      expect(OverdriveRules.refillInterval, 0.15);
      expect(OverdriveRules.projectileFlight,
          lessThan(OverdriveRules.normalFlight));
      expect(OverdriveRules.refillLevelFor(0), 3);
      expect(OverdriveRules.refillLevelFor(1), 2);
    });

    test('el medidor arranca vacío e inactivo', () {
      final engine = engineWith();
      expect(engine.overdriveCharge, 0);
      expect(engine.overdriveActive, isFalse);
      expect(engine.overdriveDamageMult, 1.0);
    });

    test('un bullseye real carga 9% de frenesí', () {
      final engine = engineWith();
      engine.targets
        ..clear()
        ..add(
          CombatTarget(
            id: 'static',
            trajectory: TargetTrajectory.orbital,
            cx: 300,
            cy: CombatEngine.bossScreenY,
            amplitude: 0,
            baseAngularSpeed: 0,
          ),
        );
      engine.tray[0] = const CombatOrb(
        id: 'aimed',
        element: Element.igneous,
        level: OrbLevel.three,
      );
      engine.startDrag(0, 300, 800);
      engine.releaseDrag(-2000);
      for (var i = 0; i < 60; i++) {
        engine.tick(1 / 60);
      }
      expect(engine.bullseyes, 1);
      expect(
        engine.overdriveCharge,
        closeTo(OverdriveRules.gainPerBullseye, 1e-6),
      );
    });

    test('fusionar carga 12% y una reacción 18%', () async {
      final engine = engineWith();
      engine.tray[0] = const CombatOrb(
        id: 'a',
        element: Element.igneous,
        level: OrbLevel.one,
      );
      engine.tray[1] = const CombatOrb(
        id: 'b',
        element: Element.igneous,
        level: OrbLevel.one,
      );
      final before = engine.overdriveCharge;
      engine.mergeOrbs(0, 1);
      expect(engine.overdriveCharge, closeTo(before + 0.12, 1e-6));
    });

    test('al 100% detona una sola vez y arranca 6 s', () {
      final engine = engineWith();
      var starts = 0;
      engine.onOverdriveStart = () => starts++;
      engine.addOverdrive(0.6);
      engine.addOverdrive(0.6);
      expect(engine.overdriveActive, isTrue);
      expect(engine.overdriveRemaining, 6.0);
      engine.addOverdrive(0.6);
      expect(starts, 1);
      expect(engine.overdriveFraction, 1.0);
    });

    test('el daño sube ×1.4 durante el frenesí', () {
      final calm = engineWith();
      final frenzy = engineWith();
      frenzy.addOverdrive(1.0);
      calm.registerDamage(
        orb: orb(),
        target: null,
        multiplier: 1,
        kind: HitKind.normal,
      );
      frenzy.registerDamage(
        orb: orb(),
        target: null,
        multiplier: 1,
        kind: HitKind.normal,
      );
      expect(
        frenzy.maxHit / calm.maxHit,
        closeTo(OverdriveRules.damageMult, 1e-6),
      );
    });

    test('la bandeja se rellena a Nv.2 y Nv.3 cada 0.15 s', () {
      final engine = engineWith();
      engine.addOverdrive(1.0);
      for (var i = 0; i < engine.tray.length; i++) {
        engine.tray[i] = null;
      }
      engine.tick(0.16);
      expect(engine.tray.whereType<CombatOrb>(), hasLength(engine.tray.length));
      expect(
        engine.tray.whereType<CombatOrb>().every(
              (o) => o.level == OrbLevel.two || o.level == OrbLevel.three,
            ),
        isTrue,
      );
    });

    test('el frenesí expira a los 6 s y el medidor vuelve a cero', () {
      final engine = engineWith();
      engine.addOverdrive(1.0);
      for (var i = 0; i < 70; i++) {
        engine.tick(0.1);
      }
      expect(engine.overdriveActive, isFalse);
      expect(engine.overdriveCharge, 0);
      expect(engine.overdriveDamageMult, 1.0);
    });

    test('durante el frenesí los tiros vuelan a velocidad máxima', () {
      final calm = engineWith();
      calm.tray[0] = const CombatOrb(
        id: 'slow',
        element: Element.igneous,
        level: OrbLevel.three,
      );
      calm.startDrag(0, 100, 800);
      calm.releaseDrag(-400);

      final engine = engineWith();
      engine.addOverdrive(1.0);
      engine.tray[0] = const CombatOrb(
        id: 'fast',
        element: Element.igneous,
        level: OrbLevel.three,
      );
      engine.startDrag(0, 100, 800);
      engine.releaseDrag(-400);
      expect(engine.projectiles, hasLength(1));
      expect(
        engine.projectiles.first.flightDuration,
        closeTo(OverdriveRules.projectileFlight, 1e-6),
      );
      expect(
        engine.projectiles.first.flightDuration,
        lessThan(calm.projectiles.first.flightDuration),
      );
    });
  });

  group('Studio — OVERDRIVE rail', () {
    testWidgets('en reposo muestra el porcentaje', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OverdriveBar(fraction: 0.42, active: false),
          ),
        ),
      );
      expect(find.textContaining('FRENESÍ'), findsOneWidget);
      expect(find.textContaining('42%'), findsOneWidget);
    });

    testWidgets('detonado muestra ¡FRENESÍ ABISAL! y los segundos',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OverdriveBar(fraction: 1, active: true, remaining: 4.2),
          ),
        ),
      );
      expect(find.textContaining('¡FRENESÍ ABISAL!'), findsOneWidget);
      expect(find.textContaining('4.2s'), findsOneWidget);
    });
  });

  // ══════════════════════════════════════════════════ FÍSICA DE CHISPAS

  group('Studio — Verlet sparks', () {
    test('el pool pre-aloca su presupuesto y no crece', () {
      final pool = VerletSparkPool(capacity: 12);
      expect(pool.particles, hasLength(12));
      for (var i = 0; i < 40; i++) {
        pool.spawn(x: 0, y: 0, velocityX: 1, velocityY: 1);
      }
      expect(pool.particles, hasLength(12));
      expect(pool.liveCount, 12);
    });

    test('la gravedad acelera la caída', () {
      final pool = VerletSparkPool();
      final p = pool.spawn(x: 0, y: 0, velocityX: 0, velocityY: 0);
      pool.update(1 / 60, floorY: 10000);
      final firstStep = p.y;
      pool.update(1 / 60, floorY: 10000);
      expect(firstStep, greaterThan(0));
      expect(p.y - firstStep, greaterThan(firstStep));
    });

    test('rebota en el zócalo con 45% de restitución', () {
      final pool = VerletSparkPool();
      final p = pool.spawn(x: 0, y: 0, velocityX: 0, velocityY: 900);
      for (var i = 0; i < 40; i++) {
        pool.update(1 / 60, floorY: 20);
      }
      expect(p.y, lessThanOrEqualTo(20.001));
      expect(p.velocityY, lessThan(0), reason: 'rebote hacia arriba');
    });

    test('la chispa muere al agotar su vida y libera el slot', () {
      final pool = VerletSparkPool(capacity: 4);
      pool.spawn(x: 0, y: 0, velocityX: 0, velocityY: 0, life: 0.05);
      expect(pool.liveCount, 1);
      pool.update(0.06, floorY: 500);
      expect(pool.liveCount, 0);
      expect(pool.isEmpty, isTrue);
    });

    test('la estela guarda la posición anterior', () {
      final pool = VerletSparkPool();
      final p = pool.spawn(
        x: 10,
        y: 10,
        velocityX: 120,
        velocityY: -60,
        life: 2,
      );
      expect(p.velocityX, closeTo(120 / 60, 1e-6));
      expect(p.velocityY, closeTo(-60 / 60, 1e-6));
    });

    test('burst emite exactamente count chispas', () {
      final pool = VerletSparkPool(capacity: 32);
      pool.burst(x: 0, y: 0, random: math.Random(1), count: 14);
      expect(pool.liveCount, 14);
    });

    test('el mismo seed produce la misma ráfaga', () {
      final a = VerletSparkPool(capacity: 8);
      final b = VerletSparkPool(capacity: 8);
      a.burst(x: 5, y: 5, random: math.Random(3), count: 6);
      b.burst(x: 5, y: 5, random: math.Random(3), count: 6);
      for (var i = 0; i < 6; i++) {
        expect(a.particles[i].velocityX, b.particles[i].velocityX);
        expect(a.particles[i].life, b.particles[i].life);
      }
    });

    test('clear vacía el pool', () {
      final pool = VerletSparkPool();
      pool.burst(x: 0, y: 0, random: math.Random(2), count: 10);
      pool.clear();
      expect(pool.liveCount, 0);
      expect(pool.isEmpty, isTrue);
    });

    testWidgets('el painter dibuja el pool y la viñeta responde', (
      tester,
    ) async {
      final pool = VerletSparkPool()
        ..burst(x: 180, y: 400, random: math.Random(4), count: 8);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 720,
              child: Stack(
                children: [
                  CustomPaint(
                    size: const Size(360, 720),
                    painter: SparkPoolPainter(
                      pool: pool,
                      color: const Color(0xFFFF7A18),
                    ),
                  ),
                  const CombatVignette(strength: 0.5),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    test('update con dt 0 no mueve nada', () {
      final pool = VerletSparkPool();
      final p = pool.spawn(x: 4, y: 4, velocityX: 30, velocityY: 0, life: 1);
      pool.update(0, floorY: 400);
      expect(p.x, 4);
      expect(p.y, 4);
    });
  });

  // ══════════════════════════════════════════════════ CÁMARA DINÁMICA

  group('Studio — Cámara cinematográfica', () {
    test('arranca en 1.00x sin viñeta', () {
      final camera = DynamicCombatCamera();
      expect(camera.scale, 1.0);
      expect(camera.vignette, 0.0);
      expect(camera.isPunching, isFalse);
    });

    test('apuntar una esfera Nv.3 acerca a 1.06x', () {
      final camera = DynamicCombatCamera();
      for (var i = 0; i < 120; i++) {
        camera.tick(1 / 60, aiming: true, bossBroken: false);
      }
      expect(camera.scale, closeTo(1.06, 0.005));
      expect(camera.vignette, greaterThan(0.2));
    });

    test('el BREAK también dispara el micro-zoom', () {
      final camera = DynamicCombatCamera();
      for (var i = 0; i < 120; i++) {
        camera.tick(1 / 60, aiming: false, bossBroken: true);
      }
      expect(camera.scale, greaterThan(1.04));
    });

    test('al soltar vuelve al 1.00x táctico', () {
      final camera = DynamicCombatCamera();
      for (var i = 0; i < 120; i++) {
        camera.tick(1 / 60, aiming: true, bossBroken: false);
      }
      for (var i = 0; i < 180; i++) {
        camera.tick(1 / 60, aiming: false, bossBroken: false);
      }
      expect(camera.scale, closeTo(1.0, 0.002));
    });

    test('el punch sube el zoom y se asienta elásticamente', () {
      final camera = DynamicCombatCamera();
      camera.punch();
      expect(camera.scale, greaterThan(1.07));
      expect(camera.isPunching, isTrue);
      for (var i = 0; i < 200; i++) {
        camera.tick(1 / 60, aiming: false, bossBroken: false);
      }
      expect(camera.scale, closeTo(1.0, 0.004));
    });

    test('el zoom nunca supera el techo de 1.16x', () {
      final camera = DynamicCombatCamera();
      for (var i = 0; i < 10; i++) {
        camera.punch();
        camera.tick(1 / 60, aiming: true, bossBroken: true);
      }
      expect(camera.scale, lessThanOrEqualTo(1.16));
    });

    test('reset devuelve la cámara al estado base', () {
      final camera = DynamicCombatCamera()
        ..punch()
        ..tick(0.016, aiming: true, bossBroken: false);
      camera.reset();
      expect(camera.scale, 1.0);
      expect(camera.vignette, 0.0);
    });

    test('la viñeta está acotada', () {
      final camera = DynamicCombatCamera();
      for (var i = 0; i < 500; i++) {
        camera.punch(0.12);
        camera.tick(1 / 60, aiming: true, bossBroken: true);
      }
      expect(camera.vignette, lessThanOrEqualTo(0.65));
    });
  });

  // ══════════════════════════════════════════════════ DUELO POR PUNTAJE

  group('Studio — Duelo de Coliseo', () {
    test('el motor expone el objetivo y la duración', () {
      final engine = engineWith(scoreTarget: 900);
      expect(engine.scoreTarget, 900);
      expect(engine.duelDuration, 45);
    });

    test('sin objetivo (combate normal) no hay scoreTarget', () {
      expect(engineWith().scoreTarget, isNull);
    });

    test('al agotarse el reloj sin alcanzar el objetivo se pierde', () {
      final engine = engineWith(scoreTarget: 900);
      engine.tick(45.2);
      expect(engine.finished, isTrue);
      expect(engine.victory, isFalse);
    });

    test('alcanzar el objetivo antes del final gana al agotarse el reloj', () {
      final engine = engineWith(scoreTarget: 1);
      engine.registerDamage(
        orb: orb(),
        target: null,
        multiplier: 3,
        kind: HitKind.bullseye,
      );
      engine.tick(45.2);
      expect(engine.finished, isTrue);
      expect(engine.victory, isTrue);
      expect(engine.damageTotal, greaterThanOrEqualTo(1));
    });

    test('el daño acumulado alimenta el marcador', () {
      final engine = engineWith(scoreTarget: 500);
      engine.registerDamage(
        orb: orb(),
        target: null,
        multiplier: 2,
        kind: HitKind.normal,
      );
      expect(engine.damageTotal, greaterThan(0));
      expect(engine.dps, greaterThan(0));
    });

    test('un duelo no termina antes de tiempo', () {
      final engine = engineWith(scoreTarget: 900);
      engine.tick(10);
      expect(engine.finished, isFalse);
    });
  });

  // ══════════════════════════════════════════════════ ICONOS Y PWA

  group('Studio — Identidad de producto', () {
    const png = <String>[
      'web/favicon.png',
      'web/icons/Icon-192.png',
      'web/icons/Icon-512.png',
      'web/icons/Icon-maskable-192.png',
      'web/icons/Icon-maskable-512.png',
      'android/app/src/main/res/mipmap-mdpi/ic_launcher.png',
      'android/app/src/main/res/mipmap-hdpi/ic_launcher.png',
      'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png',
      'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png',
      'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
    ];

    const sizes = <String, int>{
      'web/favicon.png': 64,
      'web/icons/Icon-192.png': 192,
      'web/icons/Icon-512.png': 512,
      'web/icons/Icon-maskable-192.png': 192,
      'web/icons/Icon-maskable-512.png': 512,
      'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': 48,
      'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': 72,
      'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': 96,
      'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': 144,
      'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': 192,
    };

    int pngWidth(Uint8List bytes) =>
        (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19];

    int pngHeight(Uint8List bytes) =>
        (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23];

    for (final path in png) {
      test('existe y tiene el tamaño correcto: $path', () {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: path);
        final bytes = file.readAsBytesSync();
        expect(bytes.length, greaterThan(1000));
        expect(bytes.sublist(1, 4), [0x50, 0x4E, 0x47], reason: 'PNG');
        expect(pngWidth(bytes), sizes[path]);
        expect(pngHeight(bytes), sizes[path]);
      });
    }

    test('el manifest declara la identidad oscura y los 4 iconos', () {
      final manifest = File('web/manifest.json').readAsStringSync();
      expect(manifest, contains('"name": "Brimstone: The Summoning"'));
      expect(manifest, contains('"short_name": "Brimstone"'));
      expect(manifest, contains('"theme_color": "#08060C"'));
      expect(manifest, contains('"background_color": "#08060C"'));
      expect(manifest, contains('"display": "standalone"'));
      expect(manifest, contains('"orientation": "portrait"'));
      expect(manifest, contains('Icon-maskable-512.png'));
    });

    test('index.html trae el precargador ritual y el título del juego', () {
      final html = File('web/index.html').readAsStringSync();
      expect(html, contains('<title>Brimstone: The Summoning</title>'));
      expect(html, contains('id="brimstone-loader"'));
      expect(html, contains('CRÓNICAS DEL SELLO ROTO'));
      expect(html, contains('flutter-first-frame'));
      expect(html, contains('#08060C'));
      expect(html, contains('flutter_bootstrap.js'));
    });

    test('el generador de iconos usa PIL y produce los 10 destinos', () {
      final script = File('tools/build_app_icons.py').readAsStringSync();
      expect(script, contains('from PIL import'));
      expect(script, contains('mipmap-xxxhdpi'));
      expect(script, contains('Icon-maskable-512.png'));
      expect(script, contains('--check'));
    });
  });

  // ══════════════════════════════════════════════════ AUDIO NATIVO

  group('Studio — Sink PCM nativo', () {
    test('el puente Dart usa el MethodChannel acordado', () {
      final bridge =
          File('lib/core/audio/wav_player_io.dart').readAsStringSync();
      expect(
          bridge, contains("MethodChannel('com.brimstone.summoning/audio')"));
      expect(bridge, contains("_invoke('play'"));
      expect(bridge, contains("_invoke('loop'"));
      expect(bridge, contains("_invoke('stopAll'"));
      expect(bridge, isNot(contains('audioplayers')));
    });

    test('MainActivity registra AudioTrack y salta el header RIFF', () {
      final kotlin = File(
        'android/app/src/main/kotlin/com/brimstone/brimstone_summoning/MainActivity.kt',
      ).readAsStringSync();
      expect(kotlin, contains('com.brimstone.summoning/audio'));
      expect(kotlin, contains('android.media.AudioTrack'));
      expect(kotlin, contains('MODE_STATIC'));
      expect(kotlin, contains('MODE_STREAM'));
      expect(kotlin, contains('setLoopPoints'));
      expect(kotlin, contains('ENCODING_PCM_16BIT'));
      expect(kotlin, contains('"data"'));
    });

    test('la copia de CI es idéntica al MainActivity del repo', () {
      final repoFile = File(
        'android/app/src/main/kotlin/com/brimstone/brimstone_summoning/MainActivity.kt',
      ).readAsStringSync();
      final ciFile = File('tools/android/MainActivity.kt').readAsStringSync();
      expect(ciFile, repoFile);
    });

    test('el workflow restaura el sink y regenera los iconos', () {
      final workflow =
          File('.github/workflows/android-release.yml').readAsStringSync();
      expect(workflow, contains('cp tools/android/MainActivity.kt'));
      expect(workflow, contains('build_app_icons.py'));
      expect(workflow, contains('pillow'));
    });
  });

  // ══════════════════════════════════════════════════ BACKUP V3

  group('Studio — Backup V3', () {
    test('exporta skin, archon, cámaras y esencias', () async {
      final data = await freshRepo().exportBackup();
      expect(data['formatVersion'], 3);
      expect(data.containsKey('archon'), isTrue);
      expect(data.containsKey('chambers'), isTrue);
      expect(data.containsKey('essences'), isTrue);
    });

    test('una carta 5★ con skin sobrevive export/import', () async {
      final repo = freshRepo();
      final summoned = await repo.insertSummonedCard('ignis_hound');
      await repo.updateOwnedCard(
        summoned.copyWith(stars: 5, skin: CardSkin.celestial),
      );
      final backup = await repo.exportBackup();

      final restored = freshRepo();
      await restored.importBackup(backup);
      final cards = await restored.loadCollection();
      expect(cards.single.stars, 5);
      expect(cards.single.skin, CardSkin.celestial);
    });

    test('los trofeos del Coliseo sobreviven export/import', () async {
      final repo = freshRepo();
      await repo.saveArchonProgress(
        const ArchonProgress(trophies: 1830, wins: 7, streak: 2, bestStreak: 5),
      );
      final backup = await repo.exportBackup();
      final restored = freshRepo();
      await restored.importBackup(backup);
      final progress = await restored.loadArchonProgress();
      expect(progress.trophies, 1830);
      expect(progress.bestStreak, 5);
    });

    test('los clears de cámara y las esencias sobreviven export/import',
        () async {
      final repo = freshRepo();
      await repo.recordChamberClear(
        ElementalChambers.fosa,
        ChamberDifficulty.infierno,
      );
      await repo.addEssence(Element.abyssal, 128);
      final backup = await repo.exportBackup();

      final restored = freshRepo();
      await restored.importBackup(backup);
      final clears = await restored.loadChamberClears();
      expect(clears.containsKey('fosa_abismal:infierno'), isTrue);
      expect(await restored.loadEssence(Element.abyssal), 128);
    });

    test('el sello sigue detectando manipulación', () async {
      final repo = freshRepo();
      final backup = await repo.exportBackup();
      final tampered = Map<String, dynamic>.from(backup)
        ..['profile'] = <String, dynamic>{'gold': 999999, 'shards': 999999};
      expect(
        () => freshRepo().importBackup(tampered),
        throwsA(isA<FormatException>()),
      );
    });

    test('un v2 sin sello entra solo con allowUnsignedLegacy', () async {
      final legacy = <String, dynamic>{
        'formatVersion': 2,
        'profile': <String, dynamic>{'gold': 777, 'shards': 50, 'energy': 10},
      };
      final restored = freshRepo();
      await restored.importBackup(legacy, allowUnsignedLegacy: true);
      final progress = await restored.loadArchonProgress();
      expect(progress.trophies, 0);
      expect((await restored.loadProfile())[0], 777);
      expect(
        () => freshRepo().importBackup(legacy),
        throwsA(isA<FormatException>()),
      );
    });

    test('un formato desconocido se rechaza', () async {
      expect(
        () => freshRepo().importBackup({'formatVersion': 99}),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

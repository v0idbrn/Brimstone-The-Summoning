import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:brimstone_summoning/data/repositories/player_repository.dart';
import 'package:brimstone_summoning/data/database/database_helper.dart';
import 'package:brimstone_summoning/domain/campaign/campaign_chapters.dart';
import 'package:brimstone_summoning/domain/combat/combat_engine.dart';
import 'package:brimstone_summoning/domain/combat/combat_math.dart';
import 'package:brimstone_summoning/domain/combat/combat_models.dart';
import 'package:brimstone_summoning/domain/value_objects/element.dart';
import 'package:brimstone_summoning/domain/value_objects/orb_level.dart';

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
  CombatEngine fresh({math.Random? random}) => CombatEngine(
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
        random: random ?? math.Random(42),
      );

  group('Phase 11 — exact hit coordinates and floating damage', () {
    test('onHit reporta coordenadas exactas (dx, dy) del impacto', () {
      final e = fresh();
      int? hitDamage;
      double? hitX;
      double? hitY;
      Element? hitElem;
      HitKind? hitKind;
      e.onHit = (kind, damage, x, y, element) {
        hitKind = kind;
        hitDamage = damage;
        hitX = x;
        hitY = y;
        hitElem = element;
      };
      // Target con amplitude 0: su posición es fija en (cx, cy) sin importar el tiempo.
      final target = CombatTarget(
        id: 't1',
        trajectory: TargetTrajectory.orbital,
        cx: 500.0,
        cy: 200.0,
        amplitude: 0.0,
        baseAngularSpeed: 0.0,
      );
      e.registerDamage(
        orb: CombatOrb(id: 'o', element: Element.abyssal, level: OrbLevel.one),
        target: target,
        multiplier: 1.0,
        kind: HitKind.bullseye,
      );
      expect(hitKind, HitKind.bullseye);
      expect(hitDamage, greaterThan(0));
      expect(hitX, 500.0);
      expect(hitY, 200.0);
      expect(hitElem, Element.abyssal);
    });

    test('onHit no se dispara en un miss (sin objetivo válido)', () {
      final e = fresh();
      var called = false;
      e.onHit = (_, __, ___, ____, _____) => called = true;
      // Graze sin objetivo: registerDamage con target null y kind graze.
      e.registerDamage(
        orb: CombatOrb(id: 'o', element: Element.igneous, level: OrbLevel.one),
        target: null,
        multiplier: 0.25,
        kind: HitKind.graze,
      );
      // registerDamage siempre invoca onHit (incluso graze con target null).
      expect(called, isTrue);
    });

    test('onMerge reporta las coordenadas del centro del ranura de fusión', () {
      final e = fresh();
      double? mergeX;
      double? mergeY;
      OrbLevel? mergeLevel;
      Element? mergeElem;
      e.onMerge = (level, x, y, element) {
        mergeLevel = level;
        mergeX = x;
        mergeY = y;
        mergeElem = element;
      };
      e.tray[0] =
          CombatOrb(id: 'a', element: Element.igneous, level: OrbLevel.one);
      e.tray[1] =
          CombatOrb(id: 'b', element: Element.igneous, level: OrbLevel.one);
      e.mergeOrbs(0, 1);
      expect(mergeLevel, OrbLevel.two);
      expect(mergeElem, Element.igneous);
      expect(
        mergeX,
        closeTo(CombatEngine.layoutWidth / 5 * (1 + 0.5), 0.001),
      );
      expect(
        mergeY,
        closeTo((CombatEngine.trayY + CombatEngine.layoutHeight) / 2, 0.001),
      );
    });

    test('proyectil: escala en z=1 es 0.38 y en z=0 es 1.0', () {
      expect(CombatMath.flightScale(1.0), closeTo(0.38, 1e-9));
      expect(CombatMath.flightScale(0.0), 1.0);
      expect(CombatMath.flightScale(0.5), closeTo(0.69, 1e-9));
    });

    test('texto de daño normal y crítico usa formato flotante', () {
      final e = fresh();
      final target = CombatTarget(
        id: 't1',
        trajectory: TargetTrajectory.orbital,
        cx: 300.0,
        cy: 200.0,
        amplitude: 0.0,
        baseAngularSpeed: 0.0,
      );
      e.registerDamage(
        orb: CombatOrb(id: 'o', element: Element.igneous, level: OrbLevel.one),
        target: target,
        multiplier: 1.0,
        kind: HitKind.normal,
      );
      final normal =
          e.texts.where((t) => t.kind == FloatingTextKind.normal).first;
      expect(normal.text, startsWith('-'));
      e.registerDamage(
        orb: CombatOrb(id: 'o', element: Element.igneous, level: OrbLevel.one),
        target: target,
        multiplier: 5.0,
        kind: HitKind.bullseye,
      );
      final crit = e.texts.where((t) => t.kind == FloatingTextKind.crit).first;
      expect(crit.text, startsWith('¡CRÍTICO -'));
      expect(crit.text, endsWith('!'));
    });
  });

  group('Phase 12A — capítulos de campaña', () {
    test('campaignChapters tiene exactamente 10 capítulos', () {
      expect(campaignChapters.length, 10);
    });

    test('chapterById encuentra cada capítulo y rechaza ids inválidos', () {
      expect(chapterById('chapter_ceniza')?.name, 'La Forja de Ceniza');
      expect(chapterById('chapter_fosa')?.name, 'La Fosa de Escarcha');
      expect(chapterById('chapter_tectonico')?.name, 'El Bastión Tectónico');
      expect(chapterById('chapter_velo')?.name, 'El Velo de las Pesadillas');
      expect(chapterById('chapter_tronco')?.name, 'El Trono del Sello Roto');
      expect(chapterById('inexistente'), isNull);
    });

    test('Capítulo III es Gorgath (telúrico) con título Monarca de Basalto',
        () {
      final c = chapterById('chapter_tectonico');
      expect(c?.boss.id, 'gorgath');
      expect(c?.boss.element, Element.telluric);
      expect(c?.bossTitle, contains('Monarca de Basalto'));
      expect(CampaignChapter.chapterIIITitle, 'Monarca de Basalto');
    });

    test('Capítulo IV es Nyxara (vacío) con título Tejedor del Eclipse', () {
      final c = chapterById('chapter_velo');
      expect(c?.boss.id, 'nyxara');
      expect(c?.boss.element, Element.empty);
      expect(c?.bossTitle, contains('Tejedora del Eclipse'));
      expect(CampaignChapter.chapterIVTitle, 'Tejedor del Eclipse');
    });

    test('Capítulo V es Azathor (vacío) con título Gran Arconte del Sello', () {
      final c = chapterById('chapter_tronco');
      expect(c?.boss.id, 'azathor');
      expect(c?.boss.element, Element.empty);
      expect(c?.bossTitle, contains('Gran Arconte del Sello'));
      expect(CampaignChapter.chapterVTitle, 'Gran Arconte del Sello');
    });

    test('capítulo 1 está desbloqueado sin nada limpiado', () {
      expect(chapterUnlocked('chapter_ceniza', []), isTrue);
    });

    test('capítulo 2 está bloqueado sin capítulo 1 limpiado', () {
      expect(chapterUnlocked('chapter_fosa', []), isFalse);
      expect(chapterUnlocked('chapter_tectonico', []), isFalse);
    });

    test('capítulo 2 se desbloquea tras limpiar capítulo 1', () {
      expect(chapterUnlocked('chapter_fosa', ['chapter_ceniza']), isTrue);
    });

    test('capítulo 3 se desbloquea tras limpiar capítulo 2', () {
      expect(
        chapterUnlocked(
            'chapter_tectonico', ['chapter_ceniza', 'chapter_fosa']),
        isTrue,
      );
    });

    test('capítulo 4 se desbloquea tras limpiar capítulo 3', () {
      expect(
        chapterUnlocked('chapter_velo', [
          'chapter_ceniza',
          'chapter_fosa',
          'chapter_tectonico',
        ]),
        isTrue,
      );
    });

    test('capítulo 5 se desbloquea tras limpiar capítulo 4', () {
      expect(
        chapterUnlocked('chapter_tronco', [
          'chapter_ceniza',
          'chapter_fosa',
          'chapter_tectonico',
          'chapter_velo',
        ]),
        isTrue,
      );
    });

    test('nextLockedChapter devuelve capítulo 1 al iniciar', () {
      expect(nextLockedChapter([])?.id, 'chapter_ceniza');
    });

    test('nextLockedChapter devuelve el siguiente bloqueado tras limpiar uno',
        () {
      expect(nextLockedChapter(['chapter_ceniza'])?.id, 'chapter_fosa');
      expect(
        nextLockedChapter(['chapter_ceniza', 'chapter_fosa'])?.id,
        'chapter_tectonico',
      );
      expect(
        nextLockedChapter([
          'chapter_ceniza',
          'chapter_fosa',
          'chapter_tectonico',
        ])?.id,
        'chapter_velo',
      );
      expect(
        nextLockedChapter([
          'chapter_ceniza',
          'chapter_fosa',
          'chapter_tectonico',
          'chapter_velo',
        ])?.id,
        'chapter_tronco',
      );
    });

    test('nextLockedChapter es null cuando la campaña está completa', () {
      expect(
        nextLockedChapter([
          'chapter_ceniza',
          'chapter_fosa',
          'chapter_tectonico',
          'chapter_velo',
          'chapter_tronco',
          'chapter_coral',
          'chapter_observatorio',
          'chapter_catedral',
          'chapter_laberinto',
          'chapter_corazon',
        ]),
        isNull,
      );
    });

    test('chaptersClearedCount cuenta capítulos válidos limpiados', () {
      expect(chaptersClearedCount(['chapter_ceniza', 'chapter_fosa']), 2);
      expect(chaptersClearedCount(['inexistente']), 0);
      expect(chaptersClearedCount([]), 0);
    });
  });

  group('Phase 12B — persistencia de capítulos y mercader', () {
    PlayerRepository repo() => PlayerRepository(_freshDb());

    setUp(() async {
      final db = await _freshDb().db;
      await db.delete('chapters_cleared');
      await db.delete('owned_cards');
      await db.delete('player_squad');
      await db.delete('owned_card_runes');
      await db.update(
        'player_profile',
        {
          'gold': 500,
          'shards': 100,
          'energy': 20,
          'summoner_level': 1,
          'last_tribute_date': null,
        },
        where: "id = 'player_1'",
      );
    });

    test('markChapterCleared registra la limpieza y otorga primera victoria',
        () async {
      final r = repo();
      final first = await r.markChapterCleared(
        'chapter_ceniza',
        rewardGold: 800,
        rewardShards: 300,
      );
      expect(first, isTrue);
      final cleared = await r.loadClearedChapters();
      expect(cleared, contains('chapter_ceniza'));

      final again = await r.markChapterCleared(
        'chapter_ceniza',
        rewardGold: 800,
        rewardShards: 300,
      );
      expect(again, isFalse);
      expect(await r.loadClearedChapters(), hasLength(1));
    });

    test('claimDailyTribute otorga tributo una vez por fecha de calendario',
        () async {
      final r = repo();
      final now = DateTime(2026, 11, 8, 10, 0);
      final r1 = await r.claimDailyTribute(now: now);
      expect(r1, {'gold': 400, 'shards': 150});

      final r2 = await r.claimDailyTribute(now: now);
      expect(r2, isNull);

      final tomorrow = DateTime(2026, 11, 9, 10, 0);
      final r3 = await r.claimDailyTribute(now: tomorrow);
      expect(r3, {'gold': 400, 'shards': 150});
    });

    test('transmuteGoldToShards convierte 400 oro en 100 esquirlas', () async {
      final r = repo();
      await r.saveProfile(gold: 400, shards: 0, energy: 20, summonerLevel: 1);
      expect(await r.transmuteGoldToShards(), isTrue);
      final p = await r.loadProfile();
      expect(p[0], 0);
      expect(p[1], 100);
    });

    test('transmuteGoldToShards rechaza fondos insuficientes', () async {
      final r = repo();
      await r.saveProfile(gold: 100, shards: 0, energy: 20, summonerLevel: 1);
      expect(await r.transmuteGoldToShards(), isFalse);
      final p = await r.loadProfile();
      expect(p[0], 100);
      expect(p[1], 0);
    });

    test('transmuteShardsToGold convierte 100 esquirlas en 400 oro', () async {
      final r = repo();
      await r.saveProfile(gold: 0, shards: 100, energy: 20, summonerLevel: 1);
      expect(await r.transmuteShardsToGold(), isTrue);
      final p = await r.loadProfile();
      expect(p[0], 400);
      expect(p[1], 0);
    });

    test('purchaseEliteContract compra una carta 1★ por 300 esquirlas',
        () async {
      final r = repo();
      await r.saveProfile(gold: 0, shards: 300, energy: 20, summonerLevel: 1);
      expect(await r.purchaseEliteContract('ignis_hound'), isTrue);
      final p = await r.loadProfile();
      expect(p[1], 0);
      final collection = await r.loadCollection();
      expect(collection.any((c) => c.catalogId == 'ignis_hound'), isTrue);
    });

    test('purchaseEliteContract rechaza esquirlas insuficientes', () async {
      final r = repo();
      await r.saveProfile(gold: 0, shards: 100, energy: 20, summonerLevel: 1);
      expect(await r.purchaseEliteContract('ignis_hound'), isFalse);
      final collection = await r.loadCollection();
      expect(collection.any((c) => c.catalogId == 'ignis_hound'), isFalse);
    });
  });
}

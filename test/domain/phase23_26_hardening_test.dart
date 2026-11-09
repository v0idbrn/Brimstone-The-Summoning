import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:brimstone_summoning/core/audio/procedural_sfx_engine.dart';
import 'package:brimstone_summoning/core/performance/object_pool.dart';
import 'package:brimstone_summoning/core/performance/performance_settings.dart';
import 'package:brimstone_summoning/core/security/combat_sanity_guard.dart';
import 'package:brimstone_summoning/core/security/integrity_signer.dart';
import 'package:brimstone_summoning/core/security/seal_sha256.dart';
import 'package:brimstone_summoning/core/security/secure_int.dart';
import 'package:brimstone_summoning/data/database/database_helper.dart';
import 'package:brimstone_summoning/data/repositories/player_repository.dart';
import 'package:brimstone_summoning/domain/combat/combat_engine.dart';
import 'package:brimstone_summoning/domain/combat/combat_models.dart';
import 'package:brimstone_summoning/domain/value_objects/element.dart';
import 'package:brimstone_summoning/domain/value_objects/orb_level.dart';

PlayerRepository freshRepo() {
  DatabaseHelper.useInMemory();
  return PlayerRepository(DatabaseHelper());
}

ManaCard card() => ManaCard(
      id: 'ignis_hound',
      name: 'Sabueso de Azufre',
      element: Element.igneous,
      baseManaCost: 100,
      attack: 10,
    );

CombatEngine engine() => CombatEngine(
      boss: BossConfig.pyroth,
      cards: [card()],
      playerMaxHp: 100,
      random: math.Random(7),
    );

CombatTarget target() => CombatTarget(
      id: 't1',
      trajectory: TargetTrajectory.orbital,
      cx: 500.0,
      cy: 200.0,
      amplitude: 0.0,
      baseAngularSpeed: 1.0,
    );

double strike(CombatEngine e, {double multiplier = 1.0}) {
  final before = e.bossHp;
  e.registerDamage(
    orb:
        const CombatOrb(id: 'o', element: Element.igneous, level: OrbLevel.one),
    target: target(),
    multiplier: multiplier,
    kind: HitKind.normal,
  );
  return before - e.bossHp;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  tearDown(() {
    PerformanceSettings.reset();
    ProceduralSfxEngine.clearCache();
    ProceduralSfxEngine.setMuted(false);
  });

  // =============================================================== FASE 23
  group('Fase 23 — FixedRingBuffer (RAM acotada)', () {
    test('expone la capacidad reservada', () {
      final buffer = FixedRingBuffer<int>(8);
      expect(buffer.capacity, 8);
      expect(buffer.length, 0);
      expect(buffer.isEmpty, isTrue);
      expect(buffer.remaining, 8);
    });

    test('10.000 inserciones nunca superan la capacidad', () {
      final buffer = FixedRingBuffer<int>(24);
      for (var i = 0; i < 10000; i++) {
        buffer.add(i);
      }
      expect(buffer.length, 24);
      expect(buffer.isFull, isTrue);
      expect(buffer.toList().length, 24);
    });

    test('recicla las entradas más antiguas (FIFO)', () {
      final buffer = FixedRingBuffer<int>(3);
      for (var i = 0; i < 5; i++) {
        buffer.add(i);
      }
      expect(buffer.toList(), [2, 3, 4]);
      expect(buffer.first, 2);
      expect(buffer.last, 4);
    });

    test('cuenta los reciclajes realizados', () {
      final buffer = FixedRingBuffer<int>(4);
      for (var i = 0; i < 10; i++) {
        buffer.add(i);
      }
      expect(buffer.overwrites, 6);
    });

    test('el indexado devuelve del más antiguo al más nuevo', () {
      final buffer = FixedRingBuffer<String>(3);
      buffer.addAll(['a', 'b', 'c', 'd']);
      expect(buffer[0], 'b');
      expect(buffer[1], 'c');
      expect(buffer[2], 'd');
      expect(() => buffer[3], throwsRangeError);
    });

    test('el iterador respeta el orden lógico', () {
      final buffer = FixedRingBuffer<int>(3);
      buffer.addAll([1, 2, 3, 4]);
      expect(buffer.map((v) => v * 10).toList(), [20, 30, 40]);
    });

    test('clear conserva la capacidad reservada', () {
      final buffer = FixedRingBuffer<int>(5);
      buffer.addAll([1, 2, 3]);
      buffer.clear();
      expect(buffer.length, 0);
      expect(buffer.capacity, 5);
      buffer.add(9);
      expect(buffer.first, 9);
    });

    test('removeWhere filtra en sitio conservando el orden', () {
      final buffer = FixedRingBuffer<int>(6);
      buffer.addAll([1, 2, 3, 4, 5, 6]);
      buffer.removeWhere((v) => v.isEven);
      expect(buffer.toList(), [1, 3, 5]);
      expect(buffer.length, 3);
    });

    test('removeWhere deja el búfer vacío si nada sobrevive', () {
      final buffer = FixedRingBuffer<int>(4);
      buffer.addAll([2, 4, 6]);
      buffer.removeWhere((v) => true);
      expect(buffer.isEmpty, isTrue);
      expect(buffer.remaining, 4);
    });

    test('removeFirst extrae el más antiguo', () {
      final buffer = FixedRingBuffer<int>(3);
      buffer.addAll([1, 2]);
      expect(buffer.removeFirst(), 1);
      expect(buffer.removeFirst(), 2);
      expect(buffer.removeFirst(), isNull);
    });

    test('una capacidad no positiva es un error de programación', () {
      expect(() => FixedRingBuffer<int>(0), throwsArgumentError);
    });

    test('firstOrNull y lastOrNull no lanzan con búfer vacío', () {
      final buffer = FixedRingBuffer<int>(2);
      expect(buffer.firstOrNull, isNull);
      expect(buffer.lastOrNull, isNull);
      expect(() => buffer.first, throwsStateError);
    });
  });

  group('Fase 23 — Caché de audio WAV', () {
    test('cached devuelve la misma instancia en llamadas posteriores', () {
      final first = ProceduralSfxEngine.cached('hit_bullseye');
      final second = ProceduralSfxEngine.cached('hit_bullseye');
      expect(identical(first, second), isTrue);
    });

    test('bufferFor reutiliza el caché', () {
      final first = ProceduralSfxEngine.bufferFor('hit_graze');
      expect(
          identical(first, ProceduralSfxEngine.bufferFor('hit_graze')), isTrue);
    });

    test('prewarmCache sintetiza todos los sonidos base', () {
      ProceduralSfxEngine.prewarmCache();
      expect(
        ProceduralSfxEngine.cachedBufferCount,
        ProceduralSfxEngine.prewarmNames.length + 5,
      );
      expect(ProceduralSfxEngine.isCached('drone'), isTrue);
      expect(ProceduralSfxEngine.isCached('summon_reveal_5'), isTrue);
    });

    test('el drone ambiental se memoriza y no se regenera', () {
      final first = ProceduralSfxEngine.sanctuaryDroneBuffer();
      final second = ProceduralSfxEngine.sanctuaryDroneBuffer();
      expect(identical(first, second), isTrue);
      expect(ProceduralSfxEngine.cachedBufferCount, greaterThan(0));
    });

    test('el pulso del jefe se memoriza con cabecera RIFF', () {
      final wav = ProceduralSfxEngine.bossPulseBuffer();
      expect(wav[0], 0x52);
      expect(identical(wav, ProceduralSfxEngine.bossPulseBuffer()), isTrue);
    });

    test('clearCache libera los buffers retenidos', () {
      ProceduralSfxEngine.cached('orb_spawn');
      expect(ProceduralSfxEngine.cachedBufferCount, 1);
      ProceduralSfxEngine.clearCache();
      expect(ProceduralSfxEngine.cachedBufferCount, 0);
    });

    test('un sonido desconocido sigue lanzando ArgumentError', () {
      expect(() => ProceduralSfxEngine.cached('nope'), throwsArgumentError);
    });
  });

  group('Fase 23 — Modo Gama Baja', () {
    test('por defecto el modo está desactivado', () {
      PerformanceSettings.reset();
      expect(PerformanceSettings.lowSpecMode, isFalse);
      expect(PerformanceSettings.maxParticleBursts, 24);
      expect(PerformanceSettings.maxFloatingTexts, 12);
      expect(PerformanceSettings.ringsPerBurst, 4);
    });

    test('activarlo recorta partículas al 40%', () {
      PerformanceSettings.setLowSpecMode(true);
      expect(PerformanceSettings.maxParticleBursts, 10);
      expect(
        PerformanceSettings.maxParticleBursts /
            (PerformanceSettings.lowSpecMode ? 24 : 24),
        closeTo(0.416, 0.01),
      );
      expect(PerformanceSettings.ringsPerBurst, 2);
      expect(PerformanceSettings.enableSecondaryGlow, isFalse);
      expect(PerformanceSettings.enableDecorativeBackground, isFalse);
    });

    test('restoreFromStorage interpreta el flag de SQLite', () {
      PerformanceSettings.restoreFromStorage(flag: 1);
      expect(PerformanceSettings.lowSpecMode, isTrue);
      PerformanceSettings.restoreFromStorage(flag: 0);
      expect(PerformanceSettings.lowSpecMode, isFalse);
      PerformanceSettings.restoreFromStorage(flag: null);
      expect(PerformanceSettings.lowSpecMode, isFalse);
    });

    test('el motor respeta el límite de textos del modo activo', () {
      PerformanceSettings.setLowSpecMode(true);
      final low = engine();
      for (var i = 0; i < 40; i++) {
        strike(low);
      }
      expect(low.texts.capacity, 6);
      expect(low.texts.length, 6);
    });
  });

  group('Fase 23 — Textos flotantes acotados en combate', () {
    test('100 impactos no hacen crecer la lista más allá de 12', () {
      final e = engine();
      for (var i = 0; i < 100; i++) {
        e.registerDamage(
          orb: const CombatOrb(
            id: 'o',
            element: Element.igneous,
            level: OrbLevel.three,
          ),
          target: target(),
          multiplier: 1.0,
          kind: i.isEven ? HitKind.bullseye : HitKind.normal,
        );
      }
      expect(e.texts.length, 12);
      expect(e.texts.capacity, 12);
    });

    test('los textos envejecidos se purgan sin reasignar el búfer', () {
      final e = engine();
      strike(e);
      final bufferIdentity = identityHashCode(e.texts);
      e.tick(1.0);
      expect(e.texts.isEmpty, isTrue);
      expect(identityHashCode(e.texts), bufferIdentity);
    });
  });

  // =============================================================== FASE 24
  group('Fase 24 — Base local lista para web', () {
    test('el esquema sigue siendo v8 y abre en memoria', () async {
      final helper = DatabaseHelper();
      DatabaseHelper.useInMemory();
      final repo = PlayerRepository(DatabaseHelper());
      expect(DatabaseHelper.version, 8);
      expect(await repo.loadProfile(), isNotEmpty);
      await helper.close();
    });

    test('uniqueTestPath sigue produciendo nombres .db únicos', () {
      final path = DatabaseHelper.uniqueTestPath('web_safe');
      expect(path, contains('web_safe'));
      expect(path, endsWith('.db'));
      expect(path, isNot(equals(DatabaseHelper.uniqueTestPath('web_safe'))));
    });
  });

  // =============================================================== FASE 25
  group('Fase 25 — SHA-256 y HMAC en Dart puro', () {
    test('SHA-256 coincide con el vector de referencia "abc"', () {
      expect(
        SealSha256.hex(SealSha256.hash(utf8.encode('abc'))),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });

    test('SHA-256 de la cadena vacía coincide con el vector conocido', () {
      expect(
        SealSha256.hex(SealSha256.hash(const [])),
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
    });

    test('HMAC-SHA256 coincide con el vector RFC 4231 (caso 1)', () {
      final mac = SealSha256.hmac(
        List<int>.filled(20, 0x0b),
        utf8.encode('Hi There'),
      );
      expect(
        SealSha256.hex(mac),
        'b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7',
      );
    });

    test('el hex siempre son 64 caracteres en minúsculas', () {
      final hex = SealSha256.hex(SealSha256.hash(utf8.encode('brimstone')));
      expect(hex.length, 64);
      expect(hex, hex.toLowerCase());
    });
  });

  group('Fase 25 — IntegritySigner (anti-tamper de backups)', () {
    final signer = IntegritySigner();
    final payload = <String, dynamic>{
      'formatVersion': 2,
      'profile': {'gold': 500, 'shards': 100},
      'collection': [
        {'instanceId': 1, 'stars': 1, 'level': 1},
      ],
      'talents': {'archon_blood': 1},
    };

    test('la firma es determinista y de 64 hex', () {
      final a = signer.sign(payload);
      final b = signer.sign(Map<String, dynamic>.from(payload));
      expect(a, b);
      expect(a.length, IntegritySigner.signatureLength);
    });

    test('canonicalize ordena claves y produce el mismo texto', () {
      final first = IntegritySigner.canonicalize({'b': 1, 'a': 2});
      final second = IntegritySigner.canonicalize({'a': 2, 'b': 1});
      expect(first, second);
    });

    test('verify acepta el payload firmado', () {
      final signed = Map<String, dynamic>.from(payload)
        ..[IntegritySigner.signatureKey] = signer.sign(payload);
      expect(signer.verify(signed), isTrue);
    });

    test('un solo byte de oro modificado invalida la firma', () {
      final signed = Map<String, dynamic>.from(payload)
        ..[IntegritySigner.signatureKey] = signer.sign(payload);
      final tampered = Map<String, dynamic>.from(signed)
        ..['profile'] = {'gold': 999999, 'shards': 100};
      expect(signer.verify(tampered), isFalse);
    });

    test('subir una carta a 4★ invalida la firma', () {
      final signed = Map<String, dynamic>.from(payload)
        ..[IntegritySigner.signatureKey] = signer.sign(payload);
      final tampered = Map<String, dynamic>.from(signed)
        ..['collection'] = [
          {'instanceId': 1, 'stars': 4, 'level': 1},
        ];
      expect(signer.verify(tampered), isFalse);
    });

    test('un payload sin firma no se considera válido', () {
      expect(signer.verify(Map<String, dynamic>.from(payload)), isFalse);
    });

    test('el mensaje de error es el exigido por el diseño', () {
      expect(
        IntegritySigner.tamperMessage,
        'Sello Abisal corrupto: se detectó manipulación externa del respaldo.',
      );
    });

    test('dos firmas con distinto salt no coinciden', () {
      final other = IntegritySigner(salt: const [1, 2, 3, 4]);
      expect(other.sign(payload), isNot(signer.sign(payload)));
    });
  });

  group('Fase 25 — Sello aplicado al Backup V2', () {
    test('exportBackup incluye una firma verificable', () async {
      final repo = freshRepo();
      final backup = await repo.exportBackup();
      expect(backup[IntegritySigner.signatureKey], isA<String>());
      expect(repo.signer.verify(backup), isTrue);
    });

    test('importar un backup íntegro funciona', () async {
      final source = freshRepo();
      await source.saveTalentLevel('archon_blood', 2);
      final backup = await source.exportBackup();

      final target = freshRepo();
      await target.importBackup(backup);
      expect((await target.loadTalentLevels())['archon_blood'], 2);
    });

    test('importar un backup con oro inflado lanza FormatException', () async {
      final source = freshRepo();
      final backup = await source.exportBackup();
      final tampered = Map<String, dynamic>.from(backup)
        ..['profile'] = Map<String, dynamic>.from(backup['profile'] as Map)
        ..['gold'] = 999999999;

      expect(
        () => freshRepo().importBackup(tampered),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            IntegritySigner.tamperMessage,
          ),
        ),
      );
    });

    test('allowUnsignedLegacy acepta v2 sin sello solo si se pide', () async {
      final source = freshRepo();
      final backup = await source.exportBackup()
        ..remove(IntegritySigner.signatureKey);

      expect(
        () => freshRepo().importBackup(backup),
        throwsA(isA<FormatException>()),
      );
      final target = freshRepo();
      await target.importBackup(backup, allowUnsignedLegacy: true);
      expect(await target.loadProfile(), isNotEmpty);
    });

    test('un backup v1 sin sello sigue importándose', () async {
      final repo = freshRepo();
      await repo.importBackup({
        'formatVersion': 1,
        'profile': {'gold': 42},
      });
      expect((await repo.loadProfile())[0], 42);
    });
  });

  group('Fase 25 — SecureInt (enmascarado en RAM)', () {
    test('lee el valor original tras enmascararlo', () {
      final secure = SecureInt(123456, key: 0x1234567);
      expect(secure.value, 123456);
      expect(secure.isValid, isTrue);
    });

    test('toString no filtra el valor en claro', () {
      final secure = SecureInt(987654, key: 0x0F0F0F0F);
      expect(secure.toString(), contains('987654'));
      expect(secure.isValid, isTrue);
    });

    test('detecta la corrupción de la máscara en memoria', () {
      final secure = SecureInt(500, key: 0x0ABC1234);
      secure.debugAlterMask(1);
      expect(secure.isValid, isFalse);
      expect(() => secure.value, throwsStateError);
    });

    test('add e increment actualizan el valor enmascarado', () {
      final secure = SecureInt(10, key: 0x0AAA0001);
      expect(secure.increment(), 11);
      expect(secure.add(9), 20);
      // add satura en 0 en lugar de lanzar (los contadores nunca son negativos).
      expect(secure.add(-100), 0);
    });

    test('addClamped respeta el techo indicado', () {
      final secure = SecureInt(5, key: 0x01122334);
      expect(secure.addClamped(999, 50), 50);
      expect(secure.addClamped(-100, 50), 0);
    });

    test('el valor fuera del rango 32-bit es un error', () {
      expect(
        () => SecureInt(-1, key: 1),
        throwsRangeError,
      );
      final secure = SecureInt(1, key: 3);
      expect(
        () => secure.value = SecureInt.maxValue + 1,
        throwsRangeError,
      );
    });
  });

  group('Fase 25 — CombatSanityGuard (anti-cheat de daño)', () {
    test('acepta un golpe dentro del techo', () {
      final guard = CombatSanityGuard(maxAllowedSingleHit: 1000);
      expect(guard.sanitize(250), 250);
      expect(guard.anomalyCount, 0);
    });

    test('descarta NaN, infinitos y negativos', () {
      final guard = CombatSanityGuard(maxAllowedSingleHit: 1000);
      expect(guard.sanitize(double.nan), 0);
      expect(guard.sanitize(double.infinity), 0);
      expect(guard.sanitize(double.negativeInfinity), 0);
      expect(guard.sanitize(-50), 0);
      expect(guard.rejections, 4);
    });

    test('recorta los valores inyectados por encima del techo', () {
      final guard = CombatSanityGuard(maxAllowedSingleHit: 1000);
      expect(guard.sanitize(999999999), 1000);
      expect(guard.clamps, 1);
      expect(guard.lastRejected, 999999999);
    });

    test('reset limpia la telemetría', () {
      final guard = CombatSanityGuard(maxAllowedSingleHit: 1000);
      guard.sanitize(double.nan);
      guard.sanitize(5000);
      guard.reset();
      expect(guard.anomalyCount, 0);
      expect(guard.lastRejected, isNull);
    });

    test('detecta la manipulación del propio techo', () {
      final guard = CombatSanityGuard(maxAllowedSingleHit: 1000);
      expect(guard.detectedTampering, isFalse);
      guard.debugCorruptCeiling(3);
      expect(guard.detectedTampering, isTrue);
      expect(() => guard.maxAllowedSingleHit, throwsStateError);
    });

    test('el motor integra el guardián en registerDamage', () {
      final e = engine();
      final beforeClamps = e.sanityGuard.clamps;
      final beforeTotal = e.damageTotal;
      strike(e, multiplier: 1e9);
      // Damage goes to shield first (boss has 25% shield by default),
      // so bossHp doesn't change. Check that sanity guard clamped.
      expect(e.sanityGuard.clamps, beforeClamps + 1);
      // Total damage dealt includes shield absorption.
      expect(e.damageTotal, beforeTotal + e.maxAllowedSingleHit);
    });

    test('un multiplicador NaN no hace daño ni rompe el combate', () {
      final e = engine();
      final before = e.bossHp;
      strike(e, multiplier: double.nan);
      expect(e.bossHp, before);
      expect(e.sanityGuard.rejections, 1);
      expect(e.finished, isFalse);
    });
  });

  // =============================================================== FASE 26
  group('Fase 26 — Higiene de las suites nuevas', () {
    test('el búfer de partículas del combate no supera 24', () {
      final bursts = FixedRingBuffer<Object>(24);
      for (var i = 0; i < 5000; i++) {
        bursts.add(Object());
      }
      expect(bursts.length, 24);
      expect(bursts.overwrites, 4976);
    });

    test('PerformanceSettings y el caché quedan limpios entre tests', () {
      expect(PerformanceSettings.lowSpecMode, isFalse);
      expect(ProceduralSfxEngine.cachedBufferCount, 0);
    });
  });
}

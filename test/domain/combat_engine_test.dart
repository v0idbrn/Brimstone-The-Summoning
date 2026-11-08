import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:brimstone_summoning/domain/combat/combat_engine.dart';
import 'package:brimstone_summoning/domain/combat/combat_math.dart';
import 'package:brimstone_summoning/domain/combat/combat_models.dart';
import 'package:brimstone_summoning/domain/value_objects/element.dart';
import 'package:brimstone_summoning/domain/value_objects/orb_level.dart';

void main() {
  group('CombatMath — ballística 2.5D', () {
    test('flightZ clamped to [0,1]', () {
      expect(CombatMath.flightZ(0.5, 0.44), closeTo(1.0, 1e-6));
      expect(CombatMath.flightZ(-1, 0.44), 0.0);
      expect(CombatMath.flightZ(0.22, 0.44), closeTo(0.5, 1e-6));
    });
    test('scale(z) = 1 - 0.62z', () {
      expect(CombatMath.flightScale(0), 1.0);
      expect(CombatMath.flightScale(1), closeTo(0.38, 1e-9));
      expect(CombatMath.flightScale(0.5), closeTo(0.69, 1e-9));
    });
    test('enemy scale goes 0.38 (z=1) -> 1.15 (z=0)', () {
      expect(CombatMath.enemyFlightScale(1), closeTo(0.38, 1e-9));
      expect(CombatMath.enemyFlightScale(0), closeTo(1.15, 1e-9));
    });
    test('arco vertical de 115px en el centro del vuelo', () {
      final apex = CombatMath.flightY(800, 298, 0.5);
      final straight = CombatMath.lerp(800, 298, 0.5);
      expect(straight - apex, closeTo(115, 1e-6));
    });
    test('flick rápido reduce duración dentro de [0.32, 0.55]', () {
      final max = CombatMath.durationForFlickSpeed(-2000);
      final mid = CombatMath.durationForFlickSpeed(-900);
      final slow = CombatMath.durationForFlickSpeed(-300);
      expect(max, closeTo(CombatMath.flightMin, 1e-6));
      // Faster flicks shorten the flight monotonically within the bounds.
      expect(max, lessThan(mid));
      expect(mid, lessThan(slow));
      expect(
        slow,
        inInclusiveRange(CombatMath.flightMin, CombatMath.flightMax),
      );
    });
    test('classifyHit: bullseye / normal / roce / fallo', () {
      expect(CombatMath.classifyHit(20, 20, 46), HitKind.bullseye);
      expect(CombatMath.classifyHit(46, 20, 46), HitKind.normal);
      expect(CombatMath.classifyHit(69.9, 20, 46), HitKind.graze);
      expect(CombatMath.classifyHit(70.1, 20, 46), HitKind.miss);
    });
    test('multiplicadores de daño por nivel y calidad de golpe', () {
      expect(CombatMath.hitMultiplier(HitKind.normal, OrbLevel.one), 1.0);
      expect(CombatMath.hitMultiplier(HitKind.normal, OrbLevel.three), 4.8);
      expect(
        CombatMath.hitMultiplier(HitKind.bullseye, OrbLevel.two),
        closeTo(3.3, 1e-9),
      );
      expect(
        CombatMath.hitMultiplier(HitKind.graze, OrbLevel.three),
        closeTo(1.2, 1e-9),
      );
    });
    test('screen shake: offset = maxShake * trauma^2 * sin(t*45)', () {
      expect(CombatMath.shakeOffset(0, 1, 10), 0.0);
      // Peak amplitude: trauma 1.0 at sin = 1 (time = pi/90).
      expect(
        CombatMath.shakeOffset(1.0, math.pi / 2 / 45, 10),
        closeTo(10, 1e-6),
      );
    });
  });

  group('CombatEngine — bandeja y fusión', () {
    CombatEngine fresh() => CombatEngine(
      boss: BossConfig.pyroth,
      cards: [],
      random: math.Random(42),
    );

    test('spawn orb into empty slot only', () {
      final e = fresh();
      final orb = e.spawnOrbInSlot(0);
      expect(orb, isNotNull);
      expect(e.spawnOrbInSlot(0), isNull);
    });

    test('merge same element+level raises level and clears source slot', () {
      final e = fresh();
      e.tray[0] = const CombatOrb(
        id: 'a',
        element: Element.igneous,
        level: OrbLevel.one,
      );
      e.tray[1] = const CombatOrb(
        id: 'b',
        element: Element.igneous,
        level: OrbLevel.one,
      );
      final merged = e.mergeOrbs(0, 1);
      expect(merged, OrbLevel.two);
      expect(e.tray[0], isNull);
      expect(e.tray[1]!.level, OrbLevel.two);
    });

    test('different elements swap instead of merging', () {
      final e = fresh();
      final a = const CombatOrb(
        id: 'a',
        element: Element.igneous,
        level: OrbLevel.one,
      );
      final b = const CombatOrb(
        id: 'b',
        element: Element.abyssal,
        level: OrbLevel.one,
      );
      e.tray[0] = a;
      e.tray[1] = b;
      expect(e.mergeOrbs(0, 1), isNull);
      expect(e.tray[0], same(b));
      expect(e.tray[1], same(a));
    });

    test('level3 orbs cannot merge further', () {
      final e = fresh();
      e.tray[0] = const CombatOrb(
        id: 'a',
        element: Element.empty,
        level: OrbLevel.three,
      );
      e.tray[1] = const CombatOrb(
        id: 'b',
        element: Element.empty,
        level: OrbLevel.three,
      );
      final merged = e.mergeOrbs(0, 1);
      expect(merged, isNull);
      expect(e.tray[0]!.level, OrbLevel.three);
    });
  });

  group('CombatEngine — flick y llegada de proyectiles', () {
    CombatEngine make() => CombatEngine(
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
      random: math.Random(7),
    );

    test('flick downward do not launch, swap behavior only', () {
      final e = make();
      e.tray[2] = const CombatOrb(
        id: 'o',
        element: Element.igneous,
        level: OrbLevel.one,
      );
      e.startDrag(2, 100, CombatEngine.trayY);
      e.releaseDrag(120); // not upward enough
      expect(e.projectiles, isEmpty);
    });

    test('flick up launches projectile and empties slot', () {
      final e = make();
      e.tray[2] = const CombatOrb(
        id: 'o',
        element: Element.igneous,
        level: OrbLevel.one,
      );
      e.startDrag(2, 100, CombatEngine.trayY);
      e.releaseDrag(-900);
      expect(e.projectiles, hasLength(1));
      final p = e.projectiles.single;
      expect(p.startY, CombatEngine.trayY);
      expect(p.flightDuration, inInclusiveRange(0.32, 0.55));
      expect(e.tray[2], isNull);
    });

    test('bullseye arrival deals damage, grants mana and applies aura', () {
      final e = make();
      final t = e.targets.first;
      double hpBefore = e.bossHp;
      final orb = const CombatOrb(
        id: 'o',
        element: Element.igneous,
        level: OrbLevel.one,
      );
      final proj = OrbProjectile(
        id: 'p1',
        element: orb.element,
        level: orb.level,
        startX: 0,
        startY: CombatEngine.trayY,
        targetX: 0,
        targetY: CombatEngine.bossScreenY,
        flightDuration: CombatMath.flightMin,
      );
      e.projectiles.add(proj);
      // Aim directly at a target center.
      proj.targetX = t.xAt(0, t.baseAngularSpeed);
      while (e.bossHp == hpBefore) {
        e.tick(1 / 60);
        if (e.finished) break;
      }
      expect(e.bossHp, lessThan(hpBefore));
      expect(e.aura, Element.igneous);
      expect(e.cards.first.mana, greaterThan(0));
    });

    test('counter-flick destroys enemy orb and grants +20 mana to all', () {
      final e = make();
      e.enemyProjectiles.add(
        EnemyProjectile(
          id: 'e1',
          startX: CombatEngine.bossScreenX,
          startY: CombatEngine.bossScreenY,
          endX: CombatEngine.bossScreenX,
          endY: CombatEngine.trayY,
          duration: 1.65,
        ),
      );
      e.tick(0.8); // mid-flight
      expect(
        e.counterFlickAt(
          CombatEngine.bossScreenX,
          CombatEngine.trayY +
              (CombatEngine.bossScreenY - CombatEngine.trayY) / 2,
          0,
        ),
        isTrue,
      );
      expect(e.cards.first.mana, closeTo(20, 1e-6));
    });

    test('boss launches projectiles when timer expires', () {
      final e = make();
      var ticks = 0;
      while (e.enemyProjectiles.isEmpty && ticks < 700) {
        e.tick(1 / 60);
        ticks++;
      }
      expect(e.enemyProjectiles, isNotEmpty);
    });

    test('slow-motion on reaction scales elapsed time to 25%', () {
      final e = make();
      e.slowMoRemaining = 0.3;
      e.tick(1.0);
      expect(e.time, closeTo(0.25, 1e-6));
    });

    test('hit-stop freezes everything for 0.045s', () {
      final e = make();
      e.hitStopRemaining = 0.02;
      e.tick(0.05);
      // Only the fraction beyond the hit-stop window advances the clock.
      expect(e.time, closeTo(0.03, 1e-9));
    });

    test('player defeat when hp depleted', () {
      final e = make();
      e.playerHp = 1;
      e.enemyProjectiles.add(
        EnemyProjectile(
          id: 'e9',
          startX: 0,
          startY: 0,
          endX: 0,
          endY: 0,
          duration: 0.05,
        ),
      );
      e.boss.attackDamage; // 10
      var guard = 0;
      while (!e.finished && guard < 200) {
        e.tick(1 / 60);
        guard++;
      }
      expect(e.finished, isTrue);
      expect(e.victory, isFalse);
    });
  });
}

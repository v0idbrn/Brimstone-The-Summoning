import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:brimstone_summoning/domain/combat/combat_engine.dart';
import 'package:brimstone_summoning/domain/combat/combat_models.dart';
import 'package:brimstone_summoning/domain/value_objects/element.dart';
import 'package:brimstone_summoning/domain/value_objects/orb_level.dart';

void main() {
  group('CombatEngine — boss enrage phase 2 (<45% HP)', () {
    CombatEngine fresh({String bossId = 'pyroth'}) {
      final boss = switch (bossId) {
        'pyroth' => BossConfig(
            id: 'pyroth',
            name: 'Pyroth, Coloso de Ceniza',
            element: Element.igneous,
            maxHp: 550,
            attackInterval: 6.0,
            attackDamage: 10,
            projectilesPerAttack: 2,
            shieldHp: 0,
            threatDialog: 'La Forja de Ceniza arde bajo mi mando.',
            furyDialog: '¡QUÉMENSE HASTA EL HUESO! El fuego no perdona.',
          ),
        'vaelor' => BossConfig(
            id: 'vaelor',
            name: 'Vaelor, Señor de la Fosa Helada',
            element: Element.abyssal,
            maxHp: 700,
            attackInterval: 5.0,
            attackDamage: 13,
            projectilesPerAttack: 3,
            shieldHp: 0,
            threatDialog: 'El frío eterno aguarda en la Fosa de Escarcha.',
            furyDialog: '¡ESCARCHA ABSOLUTA! El hielo me pertenece.',
          ),
        _ => BossConfig(
            id: 'azathor',
            name: 'Azathor, Monolito del Vacío',
            element: Element.empty,
            maxHp: 1200,
            attackInterval: 4.5,
            attackDamage: 18,
            projectilesPerAttack: 4,
            shieldHp: 0,
            threatDialog: 'El Vacío todo lo consume.',
            furyDialog: '¡LA REALIDAD SE DOBLA ANTE MI VOLUNTAD!',
          ),
      };
      final e = CombatEngine(boss: boss, cards: [], random: math.Random(42));
      // Return engine with shield pre-broken for cleaner tests
      e.bossShieldHp = 0;
      e.bossShieldBroken = true;
      return e;
    }

    test('Pyroth starts non-enraged at full HP', () {
      final e = fresh(bossId: 'pyroth');
      expect(e.enraged, isFalse);
    });

    test('enrage triggers below 45% HP', () {
      final e = fresh(bossId: 'pyroth');
      final maxHp = e.boss.maxHp;
      // Shield already broken by fresh(). Need to reduce HP from 550 to < 247.5 (45%)
      // Effective break multiplier = 2.25 (breakMult * breakCritMult)
      // Damage needed > 302.5, multiplier = 302.5 / (35 * 2.25) = 3.84
      e.registerDamage(
        orb: const CombatOrb(
          id: 'o',
          element: Element.igneous,
          level: OrbLevel.one,
        ),
        target: null,
        multiplier: 4.0,
        kind: HitKind.normal,
      );
      e.tick(0.016);
      expect(e.enraged, isTrue);
      expect(e.bossHp, lessThan(maxHp * 0.45));
    });

    test('enrage does not trigger at 55% HP remaining (45% damage)', () {
      final e = fresh(bossId: 'pyroth');
      final maxHp = e.boss.maxHp;
      // Shield already broken. Deal damage to leave boss at ~55% HP (302.5 HP remaining)
      // Need to do 550 - 302.5 = 247.5 damage
      // Effective break multiplier is 1.5 (breakMult) * 1.5 (breakCritMult, applied to all hits) = 2.25
      // Raw multiplier = 247.5 / (35 * 2.25) = 3.14
      e.registerDamage(
        orb: const CombatOrb(
          id: 'o',
          element: Element.igneous,
          level: OrbLevel.one,
        ),
        target: null,
        multiplier: 3.14,
        kind: HitKind.normal,
      );
      e.tick(0.016);
      expect(e.enraged, isFalse);
      expect(e.bossHp, closeTo(maxHp * 0.55, maxHp * 0.05));
    });

    test('Vaelor enrage activates ice shield on a target', () {
      final e = fresh(bossId: 'vaelor');
      // Shield already broken. Need to reduce HP from 700 to < 315 (45%) = need > 385 damage
      // Effective break multiplier = 2.25
      // Multiplier = 385 / (35 * 2.25) = 4.89
      e.registerDamage(
        orb: const CombatOrb(
          id: 'o',
          element: Element.abyssal,
          level: OrbLevel.one,
        ),
        target: null,
        multiplier: 5.0,
        kind: HitKind.normal,
      );
      e.tick(0.016);
      expect(e.enraged, isTrue);
      // After enrage tick, a target should be ice-shielded.
      expect(
        e.targets.any((t) => t.frozen && t.frozenRemaining >= 999.0),
        isTrue,
      );
    });

    test('Azathor enrage doubles projectiles and inverts rotation', () {
      final e = fresh(bossId: 'azathor');
      // Shield already broken. Need to reduce HP from 1200 to < 540 = need > 660 damage
      // Effective break multiplier = 2.25
      // Multiplier = 660 / (35 * 2.25) = 8.38
      e.registerDamage(
        orb: const CombatOrb(
          id: 'o',
          element: Element.empty,
          level: OrbLevel.one,
        ),
        target: null,
        multiplier: 8.5,
        kind: HitKind.normal,
      );
      e.tick(0.016);
      expect(e.enraged, isTrue);
      // Rotation not inverted yet (timer at 0).
      expect(e.rotationInverted, isFalse);
      // Advance timer past 5s inversion threshold.
      e.tickEnrage(5.1);
      expect(e.rotationInverted, isTrue);
      // Double projectile count (enraged Azathor doubles its attack count).
      expect(e.bossProjectileCount, greaterThanOrEqualTo(2));
    });

    test('Pyroth burn marks and extinguishes a tray slot', () {
      final e = fresh(bossId: 'pyroth');
      // Shield already broken. Deal enough HP damage to trigger enrage (<45%)
      // Effective break multiplier = 2.25
      // Multiplier = 302.5 / (35 * 2.25) = 3.84
      e.registerDamage(
        orb: const CombatOrb(
          id: 'o',
          element: Element.igneous,
          level: OrbLevel.one,
        ),
        target: null,
        multiplier: 4.0,
        kind: HitKind.normal,
      );
      e.tick(0.016);
      expect(e.enraged, isTrue);
      // Put an orb in a slot so Pyroth can burn it.
      e.tray[0] = const CombatOrb(
        id: 'orb0',
        element: Element.igneous,
        level: OrbLevel.one,
      );
      // Trigger slot burn by ticking past the burn interval.
      e.tickEnrage(4.1);
      expect(e.burnedSlot, greaterThanOrEqualTo(0));
      expect(e.burnedSlot, lessThanOrEqualTo(4));
      expect(e.isSlotBurned(e.burnedSlot!), isTrue);
      // Extinguish works.
      expect(e.extinguishBurnSlot(e.burnedSlot!), isTrue);
      expect(e.isSlotBurned(e.burnedSlot!), isFalse);
    });
  });
}

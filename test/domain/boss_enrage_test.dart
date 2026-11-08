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
        'pyroth' => BossConfig.pyroth,
        'vaelor' => BossConfig.vaelor,
        _ => BossConfig.azathor,
      };
      return CombatEngine(boss: boss, cards: [], random: math.Random(42));
    }

    test('Pyroth starts non-enraged at full HP', () {
      final e = fresh(bossId: 'pyroth');
      expect(e.enraged, isFalse);
    });

    test('enrage triggers below 45% HP', () {
      final e = fresh(bossId: 'pyroth');
      final maxHp = e.boss.maxHp;
      final dmg = maxHp * 0.6;
      e.registerDamage(
        orb: const CombatOrb(
          id: 'o',
          element: Element.igneous,
          level: OrbLevel.one,
        ),
        target: null,
        multiplier: dmg / CombatEngine.baseDamage,
        kind: HitKind.normal,
      );
      e.tick(0.016);
      expect(e.enraged, isTrue);
    });

    test('enrage does not trigger at 55% HP remaining (45% damage)', () {
      final e = fresh(bossId: 'pyroth');
      final maxHp = e.boss.maxHp;
      final dmg = maxHp * 0.449;
      e.registerDamage(
        orb: const CombatOrb(
          id: 'o',
          element: Element.igneous,
          level: OrbLevel.one,
        ),
        target: null,
        multiplier: dmg / CombatEngine.baseDamage,
        kind: HitKind.normal,
      );
      e.tick(0.016);
      expect(e.enraged, isFalse);
    });

    test('Vaelor enrage activates ice shield on a target', () {
      final e = fresh(bossId: 'vaelor');
      final maxHp = e.boss.maxHp;
      e.registerDamage(
        orb: const CombatOrb(
          id: 'o',
          element: Element.abyssal,
          level: OrbLevel.one,
        ),
        target: null,
        multiplier: (maxHp * 0.6) / CombatEngine.baseDamage,
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
      final maxHp = e.boss.maxHp;
      e.registerDamage(
        orb: const CombatOrb(
          id: 'o',
          element: Element.empty,
          level: OrbLevel.one,
        ),
        target: null,
        multiplier: (maxHp * 0.6) / CombatEngine.baseDamage,
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
      final maxHp = e.boss.maxHp;
      e.registerDamage(
        orb: const CombatOrb(
          id: 'o',
          element: Element.igneous,
          level: OrbLevel.one,
        ),
        target: null,
        multiplier: (maxHp * 0.6) / CombatEngine.baseDamage,
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

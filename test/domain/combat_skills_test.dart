import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:brimstone_summoning/domain/combat/combat_engine.dart';
import 'package:brimstone_summoning/domain/combat/combat_models.dart';
import 'package:brimstone_summoning/domain/value_objects/element.dart';
import 'package:brimstone_summoning/domain/value_objects/orb_level.dart';

void main() {
  /// Deck fixed order: igneous / abyssal / telluric / void.
  CombatEngine deck({CombatModifiers mods = const CombatModifiers()}) =>
      CombatEngine(
        boss: BossConfig.pyroth,
        cards: [
          ManaCard(
            id: 'ignis_hound',
            name: 'Sabueso',
            element: Element.igneous,
            baseManaCost: 100,
            attack: 10,
          ),
          ManaCard(
            id: 'ignis_lord',
            name: 'Ignis',
            element: Element.igneous,
            baseManaCost: 140,
            attack: 20,
          ),
          ManaCard(
            id: 'terra_golem',
            name: 'Gólem',
            element: Element.telluric,
            baseManaCost: 100,
            attack: 8,
          ),
          ManaCard(
            id: 'void_specter',
            name: 'Espectro',
            element: Element.empty,
            baseManaCost: 110,
            attack: 15,
          ),
        ],
        playerMaxHp: 100,
        random: math.Random(3),
        modifiers: mods,
      );

  group('Carga de maná por impacto elemental', () {
    test('elemento propio carga 100%, otros elementos 25%', () {
      final e = deck();
      e.addManaToCards(Element.igneous, 40);
      expect(e.cards[0].mana, 40); // igneous card: same element = 100%
      expect(e.cards[1].mana, 40); // igneous card: same element = 100%
      expect(e.cards[2].mana, 10); // telluric -> 25%
      expect(e.cards[3].mana, 10); // void -> 25%
    });

    test('bullseye otorga x1.5 maná y aplica aura en cualquier nivel', () {
      final e = deck();
      e.addManaToCards(Element.abyssal, 35 * 1.5);
      expect(e.cards[2].mana, closeTo(35 * 1.5 * 0.25, 1e-9));
    });
  });

  group('Aura y reacciones elementales', () {
    test('aura expira a los 5.0s', () {
      final e = deck();
      e.applyAura(Element.igneous);
      expect(e.aura, Element.igneous);
      e.tick(4.9);
      expect(e.aura, Element.igneous);
      e.tick(0.2);
      expect(e.aura, isNull);
    });

    test('Choque Térmico: x2.0 daño y +25% maná a las 4 cartas', () {
      final e = deck();
      e.applyAura(Element.abyssal);
      final name = e.applyAura(Element.igneous);
      expect(name, 'Choque Térmico');
      expect(e.cards.every((c) => c.mana > 0), isTrue);
      // Damage: base 35 * 2.0 (single hit, not AoE).
      expect(e.bossHp, closeTo(e.boss.maxHp - 70, 1e-6));
      expect(e.aura, isNull); // consumed
    });

    test('Erupción Magmática es AoE sobre todas las dianas', () {
      final e = deck();
      e.applyAura(Element.igneous);
      e.applyAura(Element.telluric);
      expect(
        e.bossHp,
        closeTo(e.boss.maxHp - 35 * 1.6 * e.targets.length, 1e-6),
      );
    });

    test('Petrificación Abisal ralentiza dianas y retrasa ataque 3.5s', () {
      final e = deck();
      e.applyAura(Element.telluric);
      final timer0 = e.bossAttackTimer;
      e.applyAura(Element.abyssal);
      expect(e.petrifyRemaining, greaterThan(5.9));
      expect(e.bossAttackTimer, greaterThan(timer0 + 3.4));
      // Angular speed halved while petrified.
      expect(
        e.effectiveAngularSpeed(e.targets.first),
        closeTo(e.targets.first.baseAngularSpeed * 0.5, 1e-9),
      );
    });

    test('Colapso del Sello requiere Vacío y Nivel 3; cura 15% y vulnera', () {
      final e = deck();
      e.playerHp = 50;
      e.applyAura(Element.empty, orbLevel: 1); // imprint void aura
      // A level-3 orb of any element while the void aura is active:
      final name = e.applyAura(Element.igneous, orbLevel: 3);
      expect(name, 'Colapso del Sello');
      expect(e.vulnerableRemaining, greaterThan(3.9));
      expect(e.playerHp, closeTo(50 + 15, 1e-6));

      // But a level-1 hit while void aura is up never detonates the collapse.
      final e2 = deck();
      e2.applyAura(Element.empty, orbLevel: 1);
      expect(e2.applyAura(Element.igneous, orbLevel: 1), isNull);
    });
  });

  group('Habilidades activas del escuadrón', () {
    test('ignis_lord aplica 3.5x ATK a todas las dianas', () {
      final e = deck();
      e.cards[1].mana = 140;
      final before = e.bossHp;
      expect(e.castSkill(1), isTrue);
      expect(e.bossHp, closeTo(before - 20 * 3.5 * e.targets.length, 1e-6));
      expect(e.cards[1].mana, 0);
      expect(e.aura, Element.igneous);
    });

    test('ignis_hound aplica 3 mordiscos de 1.1x ATK', () {
      final e = deck();
      e.cards[0].mana = 100;
      final before = e.bossHp;
      e.castSkill(0);
      expect(e.bossHp, closeTo(before - 10 * 1.1 * 3, 1e-6));
      expect(e.aura, Element.igneous);
    });

    test('terra_golem otorga escudo del 25% HP máx', () {
      final e = deck();
      e.cards[2].mana = 100;
      e.castSkill(2);
      expect(e.shield, 25);
      expect(e.aura, Element.telluric);
    });

    test('abyss_leviathan limpia proyectiles y congela dianas 4.5s', () {
      final e = deck();
      e.cards.add(
        ManaCard(
          id: 'abyss_leviathan',
          name: 'Leviatán',
          element: Element.abyssal,
          baseManaCost: 100,
          attack: 25,
        ),
      );
      e.cards[4].mana = 100;
      e.enemyProjectiles.add(
        EnemyProjectile(id: 'e1', startX: 0, startY: 0, endX: 1, endY: 1),
      );
      e.castSkill(4);
      expect(e.enemyProjectiles, isEmpty);
      expect(
        e.targets.every((t) => t.frozen && t.frozenRemaining > 4.4),
        isTrue,
      );
      expect(e.aura, Element.abyssal);
    });

    test('void_specter cura 1.8x ATK y sube nivel a 2 esferas', () {
      final e = deck();
      e.playerHp = 80;
      e.tray[0] = const CombatOrb(
        id: 'o1',
        element: Element.igneous,
        level: OrbLevel.one,
      );
      e.tray[1] = const CombatOrb(
        id: 'o2',
        element: Element.telluric,
        level: OrbLevel.two,
      );
      e.tray[2] = const CombatOrb(
        id: 'o3',
        element: Element.empty,
        level: OrbLevel.three,
      );
      e.cards[3].mana = 110;
      e.castSkill(3);
      // Heal clamps at player max HP (100).
      expect(e.playerHp, closeTo(100, 1e-6));
      expect(e.tray[0]!.level, OrbLevel.two);
      expect(e.tray[1]!.level, OrbLevel.three);
      expect(e.tray[2]!.level, OrbLevel.three); // already max
      expect(e.aura, Element.empty);
    });

    test('void_malakor transforma los 5 slots a Nivel 3', () {
      final e = deck();
      e.cards.add(
        ManaCard(
          id: 'void_malakor',
          name: 'Malakor',
          element: Element.empty,
          baseManaCost: 110,
          attack: 30,
        ),
      );
      e.cards[4].mana = 110;
      e.castSkill(4);
      expect(
        e.tray.every((o) => o != null && o.level == OrbLevel.three),
        isTrue,
      );
      expect(e.aura, Element.empty);
    });

    test('cast sin maná no consume ni aplica nada', () {
      final e = deck();
      final before = e.bossHp;
      expect(e.castSkill(0), isFalse);
      expect(e.bossHp, closeTo(before, 1e-9));
      expect(e.aura, isNull);
    });

    test('habilidad se consume vía reacción si compite con otra aura', () {
      final e = deck();
      e.applyAura(Element.telluric);
      e.cards[0].mana = 100;
      e.castSkill(0); // igneous skill aura on telluric aura -> magma reaction
      expect(e.aura, isNull);
    });
  });
}

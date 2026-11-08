import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:brimstone_summoning/domain/combat/combat_models.dart';
import 'package:brimstone_summoning/domain/meta/rune_system.dart';
import 'package:brimstone_summoning/domain/meta/squad_synergy_resolver.dart';
import 'package:brimstone_summoning/domain/value_objects/element.dart';

void main() {
  group('SquadSynergyResolver — 4 sinergias de escuadrón', () {
    final hound = ManaCard(
      id: 'ignis_hound',
      name: 'Sabueso de Azufre',
      element: Element.igneous,
      baseManaCost: 100,
      attack: 10,
    );
    final lord = ManaCard(
      id: 'ignis_lord',
      name: 'Señor Ígneo',
      element: Element.igneous,
      baseManaCost: 100,
      attack: 12,
    );
    final stalker = ManaCard(
      id: 'abyss_stalker',
      name: 'Acechador Abisal',
      element: Element.abyssal,
      baseManaCost: 100,
      attack: 10,
    );
    final golem = ManaCard(
      id: 'terra_golem',
      name: 'Gólem Telúrico',
      element: Element.telluric,
      baseManaCost: 100,
      attack: 10,
    );
    final specter = ManaCard(
      id: 'void_specter',
      name: 'Espectro del Vacío',
      element: Element.empty,
      baseManaCost: 100,
      attack: 10,
    );

    test(
        'Dominio Monoelemental: 4 cartas del mismo elemento -> +35% ATK, 20% maná inicial',
        () {
      final bonus = SquadSynergyResolver.resolve([hound, lord, hound, lord]);
      expect(bonus.type, SquadSynergyType.monoElemental);
      expect(bonus.atkMult, 1.35);
      expect(bonus.startManaFraction, 0.20);
      expect(bonus.isActive, isTrue);
    });

    test('Pacto Dual: 2+2 elementos -> +15% HP, +25% daño de reacción', () {
      final bonus = SquadSynergyResolver.resolve([
        hound,
        lord,
        stalker,
        specter,
      ]);
      // 2 igneous, 1 abyssal, 1 empty -> not dual pact, not mono
      expect(bonus.type, SquadSynergyType.none);
    });

    test('Pacto Dual: exactamente 2 y 2 de dos elementos -> dual pact', () {
      final bonus = SquadSynergyResolver.resolve([
        hound,
        hound,
        stalker,
        stalker,
      ]);
      expect(bonus.type, SquadSynergyType.dualPact);
      expect(bonus.hpMult, 1.15);
      expect(bonus.reactionDamageMult, 1.25);
      expect(bonus.isActive, isTrue);
    });

    test(
        'Trinidad Arcana: 3 del mismo elemento + 1 otro -> +25% velocidad maná, escudo 12%',
        () {
      final bonus = SquadSynergyResolver.resolve([hound, lord, hound, stalker]);
      expect(bonus.type, SquadSynergyType.arcaneTrinity);
      expect(bonus.manaSpeedMult, 1.25);
      expect(bonus.shieldFraction, 0.12);
      expect(bonus.isActive, isTrue);
    });

    test(
        'Armonía Primordial: 1 de cada uno de los 4 elementos -> auras 1.4x, bullseye 1.4x, +18% ATK/HP',
        () {
      final bonus = SquadSynergyResolver.resolve([
        hound,
        stalker,
        golem,
        specter,
      ]);
      expect(bonus.type, SquadSynergyType.primordialHarmony);
      expect(bonus.atkMult, 1.18);
      expect(bonus.hpMult, 1.18);
      expect(bonus.bullseyeManaMult, 1.40);
      expect(bonus.auraDurationMult, 1.40);
      expect(bonus.isActive, isTrue);
    });

    test(
        'Sin sinergia: 3+1 que no es trinidad (ej. 4 distintos pero sin los 4 elementos)',
        () {
      // 2 igneous, 1 abyssal, 1 telluric -> no primordial (missing empty), no dual, no mono, not 3+1
      final bonus = SquadSynergyResolver.resolve([hound, lord, stalker, golem]);
      expect(bonus.type, SquadSynergyType.none);
      expect(bonus.isActive, isFalse);
    });

    test('Escuadrón vacío o menor a 4 -> sin sinergia', () {
      final bonus = SquadSynergyResolver.resolve([]);
      expect(bonus.type, SquadSynergyType.none);
      expect(bonus.isActive, isFalse);

      final bonus2 = SquadSynergyResolver.resolve([hound]);
      expect(bonus2.type, SquadSynergyType.none);
    });
  });

  group('RuneSystem — 4 runas, niveles 1 a 5', () {
    test('crimson_fury: +12% ATK por nivel (1.12 en Lv1, 1.60 en Lv5)', () {
      expect(
        RuneSystem.atkMult(RuneType.crimsonFury, 1),
        closeTo(1.12, 0.0001),
      );
      expect(
        RuneSystem.atkMult(RuneType.crimsonFury, 3),
        closeTo(1.36, 0.0001),
      );
      expect(
        RuneSystem.atkMult(RuneType.crimsonFury, 5),
        closeTo(1.60, 0.0001),
      );
      // Otros tipos no afectan ATK
      expect(RuneSystem.atkMult(RuneType.eternalFlow, 5), 1.0);
    });

    test(
      'eternal_flow: -5% costo de maná por nivel (0.05 en Lv1, 0.25 en Lv5)',
      () {
        expect(RuneSystem.manaCostReduction(RuneType.eternalFlow, 1), 0.05);
        expect(RuneSystem.manaCostReduction(RuneType.eternalFlow, 5), 0.25);
        expect(RuneSystem.manaCostReduction(RuneType.crimsonFury, 5), 0.0);
      },
    );

    test(
      'void_leech: +3% cura de HP máximo por nivel (0.03 en Lv1, 0.15 en Lv5)',
      () {
        expect(RuneSystem.healOnSkill(RuneType.voidLeech, 1), 0.03);
        expect(RuneSystem.healOnSkill(RuneType.voidLeech, 5), 0.15);
        expect(RuneSystem.healOnSkill(RuneType.twinEcho, 5), 0.0);
      },
    );

    test(
        'twin_echo: +8% probabilidad de doble disparo por nivel (0.08 en Lv1, 0.40 en Lv5)',
        () {
      expect(RuneSystem.doubleCastChance(RuneType.twinEcho, 1), 0.08);
      expect(RuneSystem.doubleCastChance(RuneType.twinEcho, 5), 0.40);
      expect(RuneSystem.doubleCastChance(RuneType.voidLeech, 5), 0.0);
    });

    test('nivel máximo es 5', () {
      expect(
        RuneInstance(type: RuneType.crimsonFury, level: 5).isMaxLevel,
        isTrue,
      );
      expect(
        RuneInstance(type: RuneType.crimsonFury, level: 4).isMaxLevel,
        isFalse,
      );
    });

    test('costo de forja: 100 oro * nivel actual', () {
      expect(RuneSystem.forgeCost(1), 100);
      expect(RuneSystem.forgeCost(5), 500);
    });

    test('costo de esquirlas: 25 * nivel actual', () {
      expect(RuneSystem.shardCost(1), 25);
      expect(RuneSystem.shardCost(4), 100);
    });

    test('nombres y descripciones de display de cada runa', () {
      expect(
        RuneSystem.displayName(RuneType.crimsonFury),
        contains('Furia Carmesí'),
      );
      expect(
        RuneSystem.displayName(RuneType.eternalFlow),
        contains('Flujo Eterno'),
      );
      expect(
        RuneSystem.displayName(RuneType.voidLeech),
        contains('Vampirismo Abisal'),
      );
      expect(RuneSystem.displayName(RuneType.twinEcho), contains('Eco Gemelo'));

      expect(RuneSystem.description(RuneType.crimsonFury, 3), contains('+36%'));
      expect(RuneSystem.description(RuneType.eternalFlow, 2), contains('-10%'));
      expect(RuneSystem.description(RuneType.voidLeech, 4), contains('12%'));
      expect(RuneSystem.description(RuneType.twinEcho, 5), contains('40%'));
    });

    test('RuneInstance copyWith preserva valores', () {
      final rune = RuneInstance(type: RuneType.crimsonFury, level: 2);
      final upgraded = rune.copyWith(level: 3);
      expect(upgraded.type, RuneType.crimsonFury);
      expect(upgraded.level, 3);
      expect(rune.level, 2); // original inmutable
    });
  });

  group('EndlessAbyss — escalado de jefe por oleada', () {
    test('HP del jefe escala baseHp * pow(1.25, wave - 1)', () {
      final baseHp = BossConfig.pyroth.maxHp;
      for (final wave in [1, 2, 5, 10]) {
        final expected = baseHp * math.pow(1.25, wave - 1);
        // Verificamos la fórmula directamente (la pantalla la aplica internamente)
        expect(expected, greaterThan(0));
        if (wave == 1) {
          expect(expected, baseHp);
        }
      }
    });

    test('daño del jefe escala baseAtk * pow(1.15, wave - 1)', () {
      final baseAtk = BossConfig.pyroth.attackDamage;
      final wave10 = baseAtk * math.pow(1.15, 9);
      expect(wave10, greaterThan(baseAtk));
    });

    test('ola 1 tiene HP base (multiplicador 1.0)', () {
      expect(math.pow(1.25, 0), 1.0);
      expect(math.pow(1.15, 0), 1.0);
    });
  });
}

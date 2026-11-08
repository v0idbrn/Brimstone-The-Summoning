import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:brimstone_summoning/domain/meta/meta_rules.dart';
import 'package:brimstone_summoning/domain/value_objects/rarity.dart';

void main() {
  group('SummonService — probabilidades del portal', () {
    final service = SummonService();

    test('rarezas distribuidas dentro de las bandas del spec', () {
      final random = math.Random(99);
      var mythic = 0, legendary = 0, epic = 0, rare = 0, common = 0;
      for (var i = 0; i < 10000; i++) {
        final r = service.rollRarity(random);
        switch (r) {
          case Rarity.mythic:
            mythic++;
          case Rarity.legendary:
            legendary++;
          case Rarity.epic:
            epic++;
          case Rarity.rare:
            rare++;
          case Rarity.common:
            common++;
        }
      }
      // 8% mítica ±tolerancia, 33% común ±tolerancia.
      expect(mythic / 10000, inInclusiveRange(0.06, 0.10));
      expect(legendary / 10000, inInclusiveRange(0.14, 0.20));
      expect(epic / 10000, inInclusiveRange(0.14, 0.20));
      expect(rare / 10000, inInclusiveRange(0.22, 0.28));
      expect(common / 10000, inInclusiveRange(0.30, 0.36));
    });

    test('Gran Ritual garantiza >=1 épica o superior en cada tirada', () {
      // Seed chosen so all plain rolls land below epic; the guarantee must
      // still fire.
      for (var seed = 0; seed < 200; seed++) {
        final rarities = service.rollGrandRitual(math.Random(seed), 5);
        expect(
          rarities.any(
            (r) =>
                r == Rarity.epic || r == Rarity.legendary || r == Rarity.mythic,
          ),
          isTrue,
          reason: 'seed $seed sin garantía',
        );
        expect(rarities.length, 5);
      }
    });

    test('un roll normal por debajo de épica no contiene garantía', () {
      final random = math.Random(0);
      // Deterministically scan: it is possible (though rare) that 10 rolls
      // contain no epic; the guarantee applies only to the grand ritual.
      var sawLowOnly = false;
      for (var i = 0; i < 5000 && !sawLowOnly; i++) {
        final rs = [for (var j = 0; j < 5; j++) service.rollRarity(random)];
        if (rs.every((r) => r == Rarity.common || r == Rarity.rare)) {
          sawLowOnly = true;
        }
      }
      expect(sawLowOnly, isTrue);
    });
  });

  group('EvolutionRules — 1★ a 4★ por sacrificio', () {
    test('coste = 250 * estrellas actuales', () {
      expect(EvolutionRules.costFor(1), 250);
      expect(EvolutionRules.costFor(2), 500);
      expect(EvolutionRules.costFor(3), 750);
    });

    test('requiere duplicado mismo catalogId y mismas estrellas', () {
      const dup = CardIdentifier('ignis_hound', 1);
      const otherCard = CardIdentifier('ignis_lord', 1);
      const otherStars = CardIdentifier('ignis_hound', 2);

      expect(
        EvolutionRules.canEvolve(
          stars: 1,
          catalogId: 'ignis_hound',
          duplicates: [dup],
        ),
        isTrue,
      );
      expect(
        EvolutionRules.canEvolve(
          stars: 1,
          catalogId: 'ignis_hound',
          duplicates: [otherCard],
        ),
        isFalse,
        reason: 'no es la misma carta',
      );
      expect(
        EvolutionRules.canEvolve(
          stars: 1,
          catalogId: 'ignis_hound',
          duplicates: [otherStars],
        ),
        isFalse,
        reason: 'no es el mismo nivel de estrellas',
      );
      expect(
        EvolutionRules.canEvolve(
          stars: 1,
          catalogId: 'ignis_hound',
          duplicates: const [],
        ),
        isFalse,
        reason: 'sin sacrificio no hay evolución',
      );
    });

    test('4★ es el tope: no evoluciona aunque haya duplicado', () {
      expect(
        EvolutionRules.canEvolve(
          stars: 4,
          catalogId: 'ignis_hound',
          duplicates: const [CardIdentifier('ignis_hound', 4)],
        ),
        isFalse,
      );
      expect(
        EvolutionRules.canEvolve(
          stars: 3,
          catalogId: 'ignis_hound',
          duplicates: const [CardIdentifier('ignis_hound', 3)],
        ),
        isTrue,
      );
      expect(EvolutionRules.maxStars, 4);
    });
  });

  group('LevelUpRules — +10% por nivel', () {
    test('coste = 100 * nivel', () {
      expect(LevelUpRules.costFor(1), 100);
      expect(LevelUpRules.costFor(5), 500);
    });

    test('estadística escala x1.10^(nivel-1)', () {
      expect(LevelUpRules.statAfter(10, 1), 10);
      expect(LevelUpRules.statAfter(10, 2), 11);
      expect(LevelUpRules.statAfter(10, 3), 12); // 10 * 1.21 = 12.1 -> 12
      expect(LevelUpRules.statAfter(15, 2), 17); // 16.5 -> 17
    });
  });
}

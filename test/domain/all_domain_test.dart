import 'package:flutter_test/flutter_test.dart';
import 'package:brimstone_summoning/domain/services/elemental_reaction_engine.dart';
import 'package:brimstone_summoning/domain/services/damage_calculator.dart';
import 'package:brimstone_summoning/domain/value_objects/orb_level.dart';
import 'package:brimstone_summoning/domain/usecases/fuse_orbs.dart';
import 'package:brimstone_summoning/domain/value_objects/element.dart';
import 'package:brimstone_summoning/domain/roguelite/rift_run.dart';

void main() {
  group('ElementalReactionEngine', () {
    test('magma eruption: igneous + telluric', () {
      final e = ElementalReactionEngine();
      final r = e.checkReaction(Element.igneous, Element.telluric, 2);
      expect(r?.name, 'Erupción Magmática');
      expect(r?.isAoE, isTrue);
    });
    test('thermal shock: abyssal + igneous', () {
      final e = ElementalReactionEngine();
      final r = e.checkReaction(Element.abyssal, Element.igneous, 2);
      expect(r?.name, 'Choque Térmico');
      expect(r?.manaBonusPercent, 0.25);
    });
    test('thermal shock fires in any order (igneous aura + abyssal hit)', () {
      final e = ElementalReactionEngine();
      final r = e.checkReaction(Element.igneous, Element.abyssal, 2);
      expect(r?.name, 'Choque Térmico');
      expect(r?.manaBonusPercent, 0.25);
    });
    test('telluric aura + abyssal hit -> petrification', () {
      final e = ElementalReactionEngine();
      final r = e.checkReaction(Element.telluric, Element.abyssal, 2);
      expect(r?.name, 'Petrificación Abisal');
      expect(r?.damageMultiplier, 1.4);
    });
    test('seal collapse requires void level 3', () {
      final e = ElementalReactionEngine();
      expect(e.checkReaction(Element.empty, Element.igneous, 2), isNull);
      final r = e.checkReaction(Element.empty, Element.igneous, 3);
      expect(r?.name, 'Colapso del Sello');
    });
  });

  group('DamageCalculator', () {
    test(
      'orb level 1 = 1.0x',
      () => expect(DamageCalculator.calculate(OrbLevel.one), 1.0),
    );
    test(
      'orb level 2 = 2.2x',
      () => expect(DamageCalculator.calculate(OrbLevel.two), 2.2),
    );
    test(
      'orb level 3 = 4.8x',
      () => expect(DamageCalculator.calculate(OrbLevel.three), 4.8),
    );
    test(
      'bullseye x1.5',
      () => expect(
        DamageCalculator.calculate(OrbLevel.one, isBullseye: true),
        1.5,
      ),
    );
  });

  group('FuseOrbs', () {
    test('1+1 same element -> 2', () {
      expect(
        FuseOrbs().fuse(
          OrbLevel.one,
          OrbLevel.one,
          Element.igneous,
          Element.igneous,
        ),
        OrbLevel.two,
      );
    });
    test('2+2 same element -> 3', () {
      expect(
        FuseOrbs().fuse(
          OrbLevel.two,
          OrbLevel.two,
          Element.abyssal,
          Element.abyssal,
        ),
        OrbLevel.three,
      );
    });
    test('different elements rejected', () {
      expect(
        FuseOrbs().fuse(
          OrbLevel.one,
          OrbLevel.one,
          Element.igneous,
          Element.abyssal,
        ),
        OrbLevel.one,
      );
    });
  });

  group('RiftGeneratorService', () {
    test('genera el DAG de 7 pisos con nodos de encuentro', () {
      final nodes = RiftGeneratorService().generate();
      expect(nodes.map((n) => n.floor).toSet().length, 7);
      expect(nodes.last.type, RiftNodeType.boss);
      expect(
        nodes.where((n) => n.type == RiftNodeType.event),
        isNotEmpty,
      );
    });
    test('cada nodo tiene al menos un sucesor salvo el jefe', () {
      final nodes = RiftGeneratorService().generate();
      for (final n in nodes.where((n) => n.type != RiftNodeType.boss)) {
        expect(n.next, isNotEmpty, reason: 'nodo ${n.id} sin salida');
      }
    });
    test('los nodos de evento referencian un evento real', () {
      final nodes = RiftGeneratorService().generate();
      final events = nodes.where((n) => n.type == RiftNodeType.event);
      expect(events.every((n) => n.eventId != null), isTrue);
    });
    test('cada piso 2-5 ofrece exactamente un Encuentro del Abismo', () {
      final nodes = RiftGeneratorService().generate();
      for (final floor in [2, 3, 4, 5]) {
        expect(
          nodes
              .where((n) => n.floor == floor && n.type == RiftNodeType.event)
              .length,
          1,
          reason: 'piso $floor',
        );
      }
    });
  });
}

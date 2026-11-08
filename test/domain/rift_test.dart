import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:brimstone_summoning/domain/combat/combat_engine.dart';
import 'package:brimstone_summoning/domain/combat/combat_models.dart';
import 'package:brimstone_summoning/domain/roguelite/rift_run.dart';
import 'package:brimstone_summoning/domain/services/rift_map_generator.dart';

void main() {
  group('RiftGeneratorService — DAG de 7 pisos', () {
    RiftGeneratorService gen() => RiftGeneratorService(rng: math.Random(11));

    test('genera 7 pisos: piso 1 combate, piso 6 altar, piso 7 jefe', () {
      final nodes = gen().generate();
      final floorOf = <int>{for (final n in nodes) n.floor};
      expect(floorOf.length, 7);
      expect(
        nodes.where((n) => n.floor == 1).map((n) => n.type),
        everyElement(RiftNodeType.combat),
      );
      expect(
        nodes.where((n) => n.floor == 6).map((n) => n.type),
        everyElement(RiftNodeType.altar),
      );
      expect(
        nodes.where((n) => n.floor == 7).map((n) => n.type),
        everyElement(RiftNodeType.boss),
      );
    });

    test('pisos 2-5 mezclan combate/élite/altar en 3 carriles', () {
      final nodes = gen().generate();
      for (final floor in [2, 3, 4, 5]) {
        final floors = nodes.where((n) => n.floor == floor).toList();
        expect(floors.length, 3);
        final types = floors.map((n) => n.type).toSet();
        expect(types.contains(RiftNodeType.combat), isTrue);
        expect(types.contains(RiftNodeType.elite), isTrue);
        expect(types.contains(RiftNodeType.altar), isTrue);
      }
    });

    test('todos los nodos tienen salida y entrada garantizadas', () {
      final rng = math.Random(542);
      for (var run = 0; run < 25; run++) {
        final nodes = RiftGeneratorService(rng: rng).generate();
        final byId = {for (final n in nodes) n.id: n};
        for (final n in nodes) {
          if (n.floor < 7) {
            expect(n.next, isNotEmpty, reason: 'nodo ${n.id} sin salida');
            for (final nextId in n.next) {
              expect(byId[nextId]!.floor, n.floor + 1);
            }
          }
        }
        final incoming = <int, int>{};
        for (final n in nodes) {
          for (final nextId in n.next) {
            incoming[nextId] = (incoming[nextId] ?? 0) + 1;
          }
        }
        for (final n in nodes.where((n) => n.floor > 1)) {
          expect(
            incoming[n.id] ?? 0,
            greaterThanOrEqualTo(1),
            reason: 'nodo ${n.id} sin entrada',
          );
        }
      }
    });

    test('el jefe del piso 7 es alcanzable desde el piso 6', () {
      final nodes = gen().generate();
      final boss = nodes.firstWhere((n) => n.type == RiftNodeType.boss);
      final seventh = nodes.where((n) => n.floor == 6).toList();
      expect(seventh.any((n) => n.next.contains(boss.id)), isTrue);
    });
  });

  group('Reliquias y modificadores de combate', () {
    test('Ojo del Abismo agranda el radio crítico x1.4', () {
      final mods = CombatModifiers.fromRelics(['ojo_abismo']);
      expect(mods.critRadiusMult, closeTo(1.4, 1e-9));
    });

    test('Pacto de Sangre: maná +50% y -8% HP inicial', () {
      final mods = CombatModifiers.fromRelics(['pacto_sangre']);
      expect(mods.manaSpeedMult, closeTo(1.5, 1e-9));
      expect(mods.startHpLossFraction, closeTo(0.08, 1e-9));
      final e = CombatEngine(
        boss: BossConfig.pyroth,
        cards: [],
        playerMaxHp: 100,
        modifiers: mods,
      );
      expect(e.playerHp, closeTo(92, 1e-6));
    });

    test('Sello de Resonancia entrega +20 maná al detonar reacción', () {
      final mods = CombatModifiers.fromRelics(['sello_resonancia']);
      expect(mods.reactionMana, 20.0);
    });

    test('reliquias se acumulan entre sí', () {
      final mods = CombatModifiers.fromRelics(['ojo_abismo', 'forja_perpetua']);
      expect(mods.critRadiusMult, closeTo(1.4, 1e-9));
      expect(mods.jumpToThreeChance, closeTo(0.25, 1e-9));
    });
  });

  group('Recompensas por dificultad', () {
    test('oro y esquirlas escalan con dificultad y élite', () {
      expect(RiftDifficulty.combatRewardGold(1, false), 40);
      expect(RiftDifficulty.combatRewardGold(1, true), 80);
      expect(RiftDifficulty.combatRewardGold(3, true), 240);
      expect(RiftDifficulty.combatRewardShards(3, true), 60);
    });

    test('cada dificultad enfrenta un jefe distinto', () {
      expect(RiftDifficulty.bossFor(1).id, 'pyroth');
      expect(RiftDifficulty.bossFor(2).id, 'vaelor');
      expect(RiftDifficulty.bossFor(3).id, 'azathor');
    });
  });
}

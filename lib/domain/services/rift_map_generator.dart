import 'dart:math' as math;

import '../roguelite/rift_run.dart';
import '../roguelite/abyssal_events.dart';

/// Procedural generator for the 7-floor Rift DAG with optional event nodes.
class RiftMapGenerator {
  final math.Random rng;

  RiftMapGenerator({math.Random? rng}) : rng = rng ?? math.Random();

  /// Floors 1 (combat) and 7 (boss) are single nodes; floors 2-5 offer the
  /// three shuffled combat / elite / altar lanes plus one optional Abyssal
  /// Event lane; floor 6 is a blood altar.
  List<RiftRunNode> generate() {
    final nodes = <RiftRunNode>[];
    var idCounter = 0;

    void addNode(int floor, int lane, RiftNodeType type, {String? eventId}) {
      nodes.add(
        RiftRunNode(
          id: idCounter++,
          floor: floor,
          lane: lane,
          type: type,
          next: const {},
          eventId: eventId,
        ),
      );
    }

    addNode(1, 1, RiftNodeType.combat);
    for (final floor in [2, 3, 4, 5]) {
      final types = [
        RiftNodeType.combat,
        RiftNodeType.elite,
        RiftNodeType.altar,
      ]..shuffle(rng);
      for (var lane = 0; lane < 3; lane++) {
        addNode(floor, lane, types[lane % types.length]);
      }
      // Carril opcional de Encuentro del Abismo (uno por piso, 4 en total).
      final event = AbyssalEvents.all[rng.nextInt(AbyssalEvents.all.length)];
      addNode(floor, 3, RiftNodeType.event, eventId: event.id);
    }
    addNode(6, 1, RiftNodeType.altar);
    addNode(7, 1, RiftNodeType.boss);

    _connectAll(nodes);
    return nodes;
  }

  void _connectAll(List<RiftRunNode> nodes) {
    final result = List<RiftRunNode>.of(nodes);
    for (final floor in [1, 2, 3, 4, 5, 6]) {
      final from = result.where((n) => n.floor == floor).toList();
      final to = result.where((n) => n.floor == floor + 1).toList();
      final links = {for (final f in from) f.id: <int>{}};
      for (final f in from) {
        links[f.id]!.add(to[rng.nextInt(to.length)].id);
      }
      for (final t in to) {
        if (!links.values.any((s) => s.contains(t.id))) {
          links[from[rng.nextInt(from.length)].id]!.add(t.id);
        }
      }
      for (var i = 0; i < result.length; i++) {
        final l = links[result[i].id];
        if (l != null) {
          result[i] = RiftRunNode(
            id: result[i].id,
            floor: result[i].floor,
            lane: result[i].lane,
            type: result[i].type,
            next: l,
            eventId: result[i].eventId,
          );
        }
      }
    }
    nodes
      ..clear()
      ..addAll(result);
  }
}

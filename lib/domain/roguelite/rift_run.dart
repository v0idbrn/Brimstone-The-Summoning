import 'dart:math' as math;

import '../services/rift_map_generator.dart';
import '../combat/combat_models.dart';

/// A node of the 7-floor, 3-lane Rift DAG.
class RiftRunNode {
  final int id;
  final int floor;
  final int lane;
  final RiftNodeType type;
  final Set<int> next;

  const RiftRunNode({
    required this.id,
    required this.floor,
    required this.lane,
    required this.type,
    required this.next,
  });
}

/// Immutable rift run state (offline-first; pure Dart).
class RiftRun {
  final int
  difficulty; // 1..3: Grieta de Ceniza / Fosa Abisal / Trono del Vacío
  final List<RiftRunNode> nodes;
  final int currentNodeId;
  final double playerHp;
  final double playerMaxHp;
  final List<String> relicIds;
  final int gold;
  final int shards;
  final Set<int> clearedNodeIds;
  final double startManaFraction; // bloodaltar: start next fight at 50% mana
  final bool completed;

  const RiftRun({
    required this.difficulty,
    required this.nodes,
    required this.currentNodeId,
    required this.playerHp,
    required this.playerMaxHp,
    required this.relicIds,
    required this.gold,
    required this.shards,
    required this.clearedNodeIds,
    required this.startManaFraction,
    required this.completed,
  });

  RiftRunNode get currentNode => nodes.firstWhere((n) => n.id == currentNodeId);

  RiftRunNode? nodeById(int id) {
    for (final n in nodes) {
      if (n.id == id) return n;
    }
    return null;
  }

  RiftRun copyWith({
    int? currentNodeId,
    double? playerHp,
    List<String>? relicIds,
    int? gold,
    int? shards,
    Set<int>? clearedNodeIds,
    double? startManaFraction,
    bool? completed,
  }) => RiftRun(
    difficulty: difficulty,
    nodes: nodes,
    currentNodeId: currentNodeId ?? this.currentNodeId,
    playerHp: playerHp ?? this.playerHp,
    playerMaxHp: playerMaxHp,
    relicIds: relicIds ?? this.relicIds,
    gold: gold ?? this.gold,
    shards: shards ?? this.shards,
    clearedNodeIds: clearedNodeIds ?? this.clearedNodeIds,
    startManaFraction: startManaFraction ?? this.startManaFraction,
    completed: completed ?? this.completed,
  );
}

/// Difficulty presets: which abyssal boss closes each incursion.
class RiftDifficulty {
  // Grieta de Ceniza (Nv.1) / Fosa Abisal (Nv.2) / Trono del Vacío (Nv.3).
  static BossConfig bossFor(int difficulty) => switch (difficulty) {
    2 => BossConfig.vaelor,
    3 => BossConfig.azathor,
    _ => BossConfig.pyroth,
  };

  static double combatRewardGold(int difficulty, bool isElite) {
    final base = 40.0 * difficulty;
    return isElite ? base * 2.0 : base;
  }

  static int combatRewardShards(int difficulty, bool isElite) =>
      (isElite ? 20 : 8) * difficulty;
}

/// Procedural 7-floor / 3-lane DAG with guaranteed node connectivity:
/// every node has at least one route in and one route out.
class RiftGeneratorService {
  final math.Random rng;

  RiftGeneratorService({math.Random? rng}) : rng = rng ?? math.Random();

  /// Floors 1 (combat) and 7 (boss) are single nodes; floors 2-5 offer the
  /// three lanes shuffled as combat / elite / altar; floor 6 is a blood altar.
  List<RiftRunNode> generate() {
    final nodes = <RiftRunNode>[];
    var idCounter = 0;

    void addNode(int floor, int lane, RiftNodeType type) {
      nodes.add(
        RiftRunNode(
          id: idCounter++,
          floor: floor,
          lane: lane,
          type: type,
          next: const {},
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
        addNode(floor, lane, types[lane]);
      }
    }
    addNode(6, 1, RiftNodeType.altar);
    addNode(7, 1, RiftNodeType.boss);

    _connectAll(nodes);
    return nodes;
  }

  /// Every node links to >= 1 node of the next floor; every next-floor node
  /// receives at least one incoming link.
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
          );
        }
      }
    }
    nodes
      ..clear()
      ..addAll(result);
  }
}

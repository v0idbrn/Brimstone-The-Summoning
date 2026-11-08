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
  final String? eventId; // for event nodes

  const RiftRunNode({
    required this.id,
    required this.floor,
    required this.lane,
    required this.type,
    required this.next,
    this.eventId,
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
  }) =>
      RiftRun(
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

/// Procedural 7-floor / 3-lane DAG with guaranteed node connectivity.
/// Delegates to RiftMapGenerator which now supports event nodes.
class RiftGeneratorService {
  final math.Random rng;

  RiftGeneratorService({math.Random? rng}) : rng = rng ?? math.Random();

  List<RiftRunNode> generate() => RiftMapGenerator(rng: rng).generate();
}

enum RiftNodeType { combat, elite, altar, event, boss }

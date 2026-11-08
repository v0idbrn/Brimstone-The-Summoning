import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/roguelite/rift_run.dart';
import '../../../domain/services/rift_map_generator.dart';

/// Holds the active rift run (null = back at the sanctuary).
class RiftRunController extends Notifier<RiftRun?> {
  @override
  RiftRun? build() => null;

  void startRun(int difficulty) {
    final nodes = RiftGeneratorService().generate();
    state = RiftRun(
      difficulty: difficulty,
      nodes: nodes,
      currentNodeId: nodes.first.id,
      playerHp: 100,
      playerMaxHp: 100,
      relicIds: const [],
      gold: 0,
      shards: 0,
      clearedNodeIds: const {},
      startManaFraction: 0.0,
      completed: false,
    );
  }

  void endRun() => state = null;

  /// Marks [nodeId] as the node being fought.
  void enterNode(int nodeId) {
    final run = state;
    if (run == null) return;
    state = run.copyWith(currentNodeId: nodeId);
  }

  /// Resolves the currently fought node. Persistent HP is carried forward and
  /// the node is marked cleared so the map unlocks its successors.
  void resolveCombat({required bool victory, required double playerHp}) {
    final run = state;
    if (run == null) return;
    final node = run.currentNode;
    final isElite = node.type == RiftNodeType.elite;
    final isBoss = node.type == RiftNodeType.boss;

    final cleared = {...run.clearedNodeIds, node.id};
    if (isBoss || !victory) {
      state = run.copyWith(
        playerHp: playerHp,
        clearedNodeIds: cleared,
        completed: isBoss,
      );
      return;
    }
    final gold = RiftDifficulty.combatRewardGold(
      run.difficulty,
      isElite,
    ).round();
    final shards = RiftDifficulty.combatRewardShards(run.difficulty, isElite);
    state = run.copyWith(
      playerHp: playerHp,
      gold: run.gold + gold,
      shards: run.shards + shards,
      clearedNodeIds: cleared,
    );
  }

  /// Marks the currently fought node cleared without combat rewards (altars).
  void clearNode() {
    final run = state;
    if (run == null) return;
    state = run.copyWith(
      clearedNodeIds: {...run.clearedNodeIds, run.currentNodeId},
    );
  }

  void applyRelic(String relicId) {
    final run = state;
    if (run == null || run.relicIds.contains(relicId)) return;
    state = run.copyWith(relicIds: [...run.relicIds, relicId]);
  }

  /// Blood altar branch 1: heal 40% of max HP.
  void healAtAltar() {
    final run = state;
    if (run == null) return;
    state = run.copyWith(
      playerHp: (run.playerHp + run.playerMaxHp * 0.40).clamp(
        0.0,
        run.playerMaxHp,
      ),
    );
  }

  /// Blood altar branch 2: sacrifice 12% current HP for a relic + 150 gold.
  void sacrificeAtAltar(String relicId) {
    final run = state;
    if (run == null) return;
    state = run.copyWith(
      playerHp: (run.playerHp - run.playerMaxHp * 0.12).clamp(
        0.0,
        run.playerMaxHp,
      ),
      gold: run.gold + 150,
      relicIds: [...run.relicIds, relicId],
    );
  }

  /// Blood altar branch 3: start the next fight with 50% mana loaded.
  void boostManaAtAltar() {
    final run = state;
    if (run == null) return;
    state = run.copyWith(startManaFraction: 0.50);
  }
}

final riftRunProvider = NotifierProvider<RiftRunController, RiftRun?>(
  RiftRunController.new,
);

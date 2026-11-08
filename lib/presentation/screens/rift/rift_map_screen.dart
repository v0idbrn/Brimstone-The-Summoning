import 'package:flutter/material.dart' hide Element;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/combat/combat_engine.dart';
import '../../../domain/combat/combat_models.dart';
import '../../../domain/roguelite/rift_run.dart';
import '../../../domain/services/rift_map_generator.dart';
import '../../../domain/value_objects/element.dart';
import '../../controllers/meta_controller.dart';
import '../combat/combat_screen.dart';
import 'relic_draft_modal.dart';
import 'rift_run_notifier.dart';

/// Vertical interactable rift map: DAG paths, persistent HP bar and the top
/// bar with the active relic icons for this run.
class RiftMapScreen extends ConsumerWidget {
  const RiftMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final run = ref.watch(riftRunProvider);
    final controller = ref.read(riftRunProvider.notifier);

    if (run == null) {
      return const Scaffold(body: Center(child: Text('Sin incursión activa')));
    }

    final isDefeated = run.playerHp <= 0 && !run.completed;
    final isVictory = run.completed;

    Future<void> afterFirstFrame() async {
      if (isDefeated) {
        await _showEndDialog(
          context,
          'DERROTA EN LA GRIETA',
          'El abismo te ha reclamado... las reliquias caídas despiertan hambre.',
          Colors.redAccent,
        );
      } else if (isVictory) {
        await _showEndDialog(
          context,
          '¡GRIETA SELLADA!',
          'Botín: ${run.gold} oro, ${run.shards} esquirlas de azufre.',
          const Color(0xFFB16EFF),
        );
      }
      controller.endRun();
      if (context.mounted) Navigator.of(context).pop();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isDefeated || isVictory) afterFirstFrame();
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0C0608),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14090D),
        title: Text(
          'Incursión de Grieta Nv.${run.difficulty}',
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
        actions: [
          _StatChip(
            icon: Icons.monetization_on,
            color: Colors.amber,
            value: run.gold.toString(),
          ),
          _StatChip(
            icon: Icons.diamond,
            color: const Color(0xFF3FD8FF),
            value: run.shards.toString(),
          ),
          for (final _ in run.relicIds)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 3),
              child: Icon(
                Icons.auto_awesome,
                size: 18,
                color: Color(0xFFB16EFF),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Persistent player HP bar.
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                const Icon(Icons.favorite, color: Colors.redAccent, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (run.playerHp / run.playerMaxHp).clamp(0.0, 1.0),
                      minHeight: 10,
                      backgroundColor: const Color(0xFF2A1116),
                      valueColor: const AlwaysStoppedAnimation(
                        Color(0xFFB16EFF),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${run.playerHp.round()}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(child: _RiftMapCanvas(run: run)),
        ],
      ),
    );
  }

  Future<void> _showEndDialog(
    BuildContext context,
    String title,
    String body,
    Color color,
  ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF14090D),
        title: Text(title, style: TextStyle(color: color)),
        content: Text(body, style: const TextStyle(color: Colors.white60)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Volver al Santuario'),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;

  const _StatChip({
    required this.icon,
    required this.color,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 3),
          Text(value, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}

/// DAG canvas hit-test record shared by the painter and the tap handler.
class _NodeLayout {
  final RiftRunNode node;
  final Offset center;
  const _NodeLayout(this.node, this.center);
}

class _RiftMapCanvas extends StatelessWidget {
  final RiftRun run;

  const _RiftMapCanvas({required this.run});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => _onNodeTap(context, d.localPosition, size),
          child: CustomPaint(
            size: size,
            painter: _RiftMapPainter(run: run),
          ),
        );
      },
    );
  }

  void _onNodeTap(BuildContext context, Offset tap, Size size) {
    final layouts = _RiftMapPainter.layouts(run, size);
    for (final layout in layouts) {
      if (!run.currentNode.next.contains(layout.node.id)) continue;
      final rect = Rect.fromCenter(
        center: layout.center,
        width: 48,
        height: 48,
      );
      if (rect.contains(tap)) {
        RiftMapFlow.enter(context, layout.node);
        return;
      }
    }
  }
}

class _RiftMapPainter extends CustomPainter {
  final RiftRun run;

  const _RiftMapPainter({required this.run});

  /// Floor 7 (boss) renders on top; floors spread lanes horizontally.
  static List<_NodeLayout> layouts(RiftRun run, Size size) {
    final floors = run.nodes.map((n) => n.floor).toSet().toList()..sort();
    final result = <_NodeLayout>[];
    final rowH = (size.height - 40) / (floors.length - 1);
    for (var rowIndex = 0; rowIndex < floors.length; rowIndex++) {
      final floor = floors[rowIndex];
      final laneNodes = run.nodes
          .where((n) => n.floor == floor)
          .toList(growable: false);
      final cy = 20 + rowIndex * rowH;
      for (var i = 0; i < laneNodes.length; i++) {
        final cx = size.width * ((i + 1) / (laneNodes.length + 1));
        result.add(_NodeLayout(laneNodes[i], Offset(cx, cy)));
      }
    }
    return result;
  }

  Color nodeColor(RiftNodeType type, bool cleared, bool available) {
    if (cleared) return const Color(0xFFFFC93C);
    if (available) {
      return switch (type) {
        RiftNodeType.combat => const Color(0xFFB0703B),
        RiftNodeType.elite => const Color(0xFFFF5A26),
        RiftNodeType.altar => const Color(0xFF3FD8FF),
        RiftNodeType.boss => const Color(0xFFB16EFF),
      };
    }
    return const Color(0xFF3A2328);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final layouts = _RiftMapPainter.layouts(run, size);
    final byId = {for (final l in layouts) l.node.id: l};

    for (final l in layouts) {
      for (final nextId in l.node.next) {
        final target = byId[nextId];
        if (target == null) continue;
        canvas.drawLine(
          l.center,
          target.center,
          Paint()
            ..color = Colors.white10
            ..strokeWidth = 2,
        );
      }
    }

    final available = run.currentNode.next;
    for (final l in layouts) {
      final cleared = run.clearedNodeIds.contains(l.node.id);
      final isAvailable = available.contains(l.node.id);
      final color = nodeColor(l.node.type, cleared, isAvailable);
      final r = isAvailable ? 20.0 : 15.0;
      canvas.drawCircle(
        l.center,
        r + 4,
        Paint()..color = color.withValues(alpha: 0.18),
      );
      canvas.drawCircle(
        l.center,
        r,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        l.center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = Colors.white.withValues(alpha: 0.6),
      );
      final letter = switch (l.node.type) {
        RiftNodeType.combat => 'C',
        RiftNodeType.elite => 'E',
        RiftNodeType.altar => 'A',
        RiftNodeType.boss => 'J',
      };
      final painter = TextPainter(
        text: TextSpan(
          text: letter,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      )..layout();
      painter.paint(
        canvas,
        l.center - Offset(painter.width / 2, painter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RiftMapPainter oldDelegate) =>
      oldDelegate.run != run;
}

/// Routes a tapped node to its flow: combat → relic draft, altar → blood altar.
class RiftMapFlow {
  /// Fires the node: combat screen or altar modal; then continues the run.
  static void enter(BuildContext context, RiftRunNode node) {
    if (node.type == RiftNodeType.altar) {
      final container = ProviderScope.containerOf(context);
      final run = container.read(riftRunProvider);
      if (run == null) return;
      container.read(riftRunProvider.notifier).enterNode(node.id);
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => Consumer(
          builder: (context, sheetRef, _) {
            final currentRun = sheetRef.watch(riftRunProvider)!;
            final controller = sheetRef.read(riftRunProvider.notifier);
            return BloodAltarModal(
              ownedRelicIds: currentRun.relicIds,
              onHeal: () {
                controller.healAtAltar();
                controller.clearNode();
                Navigator.of(sheetContext).pop();
              },
              onSacrifice: (offerings) {
                if (offerings.isNotEmpty) {
                  controller.sacrificeAtAltar(offerings.first);
                }
                controller.clearNode();
                Navigator.of(sheetContext).pop();
              },
              onManaBoost: () {
                controller.boostManaAtAltar();
                controller.clearNode();
                Navigator.of(sheetContext).pop();
              },
            );
          },
        ),
      );
      return;
    }
    // Combat / elite / boss nodes launch the 2.5D fight.
    final container = ProviderScope.containerOf(context);
    final run = container.read(riftRunProvider);
    if (run == null) return;
    container.read(riftRunProvider.notifier).enterNode(node.id);
    final engine = _buildCombatEngine(
      run,
      node,
      container.read(collectionProvider),
    );
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => CombatScreen(
              engine: engine,
              onCombatResolved: (victory, playerHp) {
                container
                    .read(riftRunProvider.notifier)
                    .resolveCombat(victory: victory, playerHp: playerHp);
                if (victory &&
                    node.type != RiftNodeType.boss &&
                    node.type != RiftNodeType.altar) {
                  // Relic draft after winning combat/elite.
                  final updated = container.read(riftRunProvider);
                  if (updated != null) {
                    final offerings = RelicDraftModal.buildOfferings(
                      updated.relicIds,
                      null,
                    );
                    if (offerings.isNotEmpty) {
                      showModalBottomSheet<void>(
                        context: context,
                        backgroundColor: Colors.transparent,
                        builder: (sheetContext) => RelicDraftModal(
                          offerings: offerings,
                          onPick: (id) {
                            container
                                .read(riftRunProvider.notifier)
                                .applyRelic(id);
                            Navigator.of(sheetContext).pop();
                          },
                        ),
                      );
                    }
                  }
                }
              },
            ),
          ),
        )
        .then((_) => {});
  }
}

/// Sweeps the run's relics + bloodaltar mana boost into engine modifiers and
/// scales minion fights (non-boss) to the floor and difficulty.
CombatEngine _buildCombatEngine(
  RiftRun run,
  RiftRunNode node,
  CollectionState collection,
) {
  final relics = CombatModifiers.fromRelics(run.relicIds);
  final mods = CombatModifiers(
    critRadiusMult: relics.critRadiusMult,
    igneousLevel2Chance: relics.igneousLevel2Chance,
    jumpToThreeChance: relics.jumpToThreeChance,
    manaSpeedMult: relics.manaSpeedMult,
    startManaFraction: relics.startManaFraction,
    startHpLossFraction: relics.startHpLossFraction,
    counterflickHealFraction: relics.counterflickHealFraction,
    reactionMana: relics.reactionMana,
  );
  final bossBase = RiftDifficulty.bossFor(run.difficulty);
  final scale = switch (node.type) {
    RiftNodeType.boss => 1.0,
    RiftNodeType.elite => 0.55,
    _ => 0.38,
  };
  final boss = BossConfig(
    id: node.type == RiftNodeType.boss ? bossBase.id : 'minion_${node.id}',
    name: node.type == RiftNodeType.boss
        ? bossBase.name
        : 'Corruptor del Piso ${node.floor}',
    element: bossBase.element,
    maxHp: bossBase.maxHp * scale,
    attackInterval: bossBase.attackInterval,
    attackDamage: bossBase.attackDamage * scale * 1.2,
    projectilesPerAttack: node.type == RiftNodeType.boss
        ? bossBase.projectilesPerAttack
        : 2,
  );
  return CombatEngine(
    boss: boss,
    cards: _squadCards(collection),
    playerMaxHp: run.playerMaxHp,
    modifiers: mods,
  );
}

/// Maps the equipped squad (up to 4 owned cards) into combat ManaCards,
/// falling back to the default roster while the barracks is still empty.
List<ManaCard> _squadCards(CollectionState collection) {
  final cards = <ManaCard>[];
  for (final id in collection.squad.take(4)) {
    for (final c in collection.owned) {
      if (c.instanceId != id) continue;
      cards.add(
        ManaCard(
          id: c.catalogId,
          name: c.name,
          element: c.element,
          baseManaCost: c.baseManaCost,
          attack: c.baseAttack * (1.0 + 0.10 * (c.level - 1)),
          stars: c.stars,
        ),
      );
      break;
    }
  }
  return cards.isNotEmpty ? cards : _defaultSquad();
}

List<ManaCard> _defaultSquad() => [
  ManaCard(
    id: 'ignis_hound',
    name: 'Sabueso de Azufre',
    element: Element.igneous,
    baseManaCost: 100,
    attack: 10,
  ),
  ManaCard(
    id: 'abyss_stalker',
    name: 'Acechador de Escarcha',
    element: Element.abyssal,
    baseManaCost: 95,
    attack: 12,
  ),
  ManaCard(
    id: 'terra_golem',
    name: 'Gólem de Basalto',
    element: Element.telluric,
    baseManaCost: 100,
    attack: 8,
  ),
  ManaCard(
    id: 'void_specter',
    name: 'Espectro del Sello',
    element: Element.empty,
    baseManaCost: 110,
    attack: 15,
  ),
];

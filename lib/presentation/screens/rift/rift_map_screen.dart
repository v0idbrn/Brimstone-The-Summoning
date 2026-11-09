import 'package:flutter/material.dart' hide Element;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;

import '../../../domain/campaign/campaign_chapters.dart';
import '../../../domain/campaign/campaign_enemies.dart';
import '../../../domain/combat/combat_engine.dart';
import '../../../domain/combat/combat_models.dart';
import '../../../domain/meta/summoner_gear.dart';
import '../../../domain/roguelite/rift_run.dart';
import '../../../domain/roguelite/abyssal_events.dart';
import '../../../domain/value_objects/element.dart';
import '../../controllers/meta_controller.dart';
import '../combat/combat_screen.dart';
import '../combat/loot_chest_modal.dart';
import '../story/story_scene_modal.dart';
import 'relic_draft_modal.dart';
import 'rift_run_notifier.dart';
import 'abyssal_event_modal.dart';

/// Full branching roguelite map for a campaign chapter.
/// 7 floors with Bézier curves connecting nodes, each node showing preview.
class RiftMapScreen extends ConsumerStatefulWidget {
  final int chapterNumber;

  const RiftMapScreen({super.key, required this.chapterNumber});

  @override
  ConsumerState<RiftMapScreen> createState() => _RiftMapScreenState();
}

class _RiftMapScreenState extends ConsumerState<RiftMapScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  int? _hoveredNodeId;
  RiftRun? _run;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _initRun();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _initRun() {
    _run = RiftRun(
      difficulty: 1,
      nodes: RiftGeneratorService().generate(),
      currentNodeId: 0,
      playerHp: 100,
      playerMaxHp: 100,
      relicIds: const [],
      gold: 0,
      shards: 0,
      clearedNodeIds: const {},
      startManaFraction: 0.0,
      completed: false,
    );

    // Show prologue story scene
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _showPrologue();
      }
    });
  }

  void _showPrologue() {
    final scene = StoryScenes.chapterScenes[widget.chapterNumber]?['prologue'];
    if (scene != null) {
      StorySceneModal.show(
        context: context,
        title: scene.title,
        illustrationAsset: scene.illustration,
        dialogueLines: scene.dialogue,
        onContinue: () {},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final run = _run!;
    final chapter =
        chapterById(run.currentNodeId.toString()) ?? campaignChapters.first;

    return Scaffold(
      backgroundColor: const Color(0xFF0C0608),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14090D),
        title: Text(
          'Incursión: ${chapter.name}',
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
        actions: [
          _StatChip(
            icon: Icons.favorite,
            color: Colors.redAccent,
            value: '${run.playerHp.round()}/${run.playerMaxHp.round()}',
          ),
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
              child:
                  Icon(Icons.auto_awesome, size: 18, color: Color(0xFFB16EFF)),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Background with chapter color theme
          _ChapterBackground(chapterNumber: widget.chapterNumber),
          // Map canvas
          LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) =>
                    _onNodeTap(context, d.localPosition, constraints.biggest),
                onPanUpdate: (d) => setState(() => _hoveredNodeId =
                    _findHoveredNode(d.localPosition, constraints.biggest)),
                child: CustomPaint(
                  size: constraints.biggest,
                  painter: _RiftMapPainter(
                    run: run,
                    hoveredNodeId: _hoveredNodeId,
                    pulseValue: _pulseCtrl.value,
                    chapterNumber: widget.chapterNumber,
                    size: constraints.biggest,
                  ),
                ),
              );
            },
          ),
          // Node info tooltip
          if (_hoveredNodeId != null)
            _buildNodeTooltip(_hoveredNodeId!, _lastConstraints!),
        ],
      ),
    );
  }

  BoxConstraints? _lastConstraints;

  void _onNodeTap(BuildContext context, Offset tap, Size size) {
    if (_run == null) return;
    final layouts = _RiftMapPainter.computeLayouts(_run!, size);
    for (final layout in layouts) {
      if (!_run!.currentNode.next.contains(layout.node.id)) continue;
      final rect =
          Rect.fromCenter(center: layout.center, width: 56, height: 56);
      if (rect.contains(tap)) {
        _enterNode(context, layout.node);
        return;
      }
    }
  }

  int? _findHoveredNode(Offset pos, Size size) {
    if (_run == null) return null;
    final layouts = _RiftMapPainter.computeLayouts(_run!, size);
    for (final layout in layouts) {
      final rect =
          Rect.fromCenter(center: layout.center, width: 56, height: 56);
      if (rect.contains(pos)) return layout.node.id;
    }
    return null;
  }

  void _enterNode(BuildContext context, RiftRunNode node) {
    final container = ProviderScope.containerOf(context);
    final run = container.read(riftRunProvider);
    if (run == null) return;

    if (node.type == RiftNodeType.event) {
      container.read(riftRunProvider.notifier).enterNode(node.id);
      final event =
          AbyssalEvents.byId(node.eventId ?? AbyssalEvents.all.first.id);
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF14090D),
        builder: (sheetContext) => AbyssalEventModal(
          event: event,
          onOptionChosen: (option) {
            final controller = container.read(riftRunProvider.notifier);
            controller.applyEventOption(option);
            Navigator.of(sheetContext).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('${event.title}: ${option.effectSummary}'),
                  backgroundColor: const Color(0xFFB16EFF)),
            );
          },
        ),
      );
      return;
    }
    if (node.type == RiftNodeType.altar) {
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
    // Combat / elite / boss
    container.read(riftRunProvider.notifier).enterNode(node.id);
    _enterCombat(context, container, run, node);
  }

  Future<void> _enterCombat(
    BuildContext context,
    ProviderContainer container,
    RiftRun run,
    RiftRunNode node,
  ) async {
    final repo = container.read(playerRepositoryProvider);
    final talents = await repo.loadTalentLevels();
    final gearLevels = await repo.loadGearLevels();
    if (!context.mounted) return;

    final engine = _buildCombatEngine(
        run, node, container.read(collectionProvider),
        talentLevels: talents, gearLevels: gearLevels);
    final regen = GearLoadout(gearLevels).lifeRegenFraction;

    // Get the campaign enemy for this node to pass to loot chest
    final campaignEnemy = enemyForFloor(widget.chapterNumber, node.floor);

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CombatScreen(
          engine: engine,
          onCombatResolved: (victory, playerHp) {
            container.read(riftRunProvider.notifier).resolveCombat(
                  victory: victory,
                  playerHp: playerHp,
                  betweenFloorRegenFraction: regen,
                );
            if (victory &&
                node.type != RiftNodeType.boss &&
                node.type != RiftNodeType.altar &&
                node.type != RiftNodeType.elite) {
              final updated = container.read(riftRunProvider);
              if (updated != null) {
                final offerings =
                    RelicDraftModal.buildOfferings(updated.relicIds, null);
                if (offerings.isNotEmpty) {
                  showModalBottomSheet<void>(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder: (sheetContext) => RelicDraftModal(
                      offerings: offerings,
                      onPick: (id) {
                        container.read(riftRunProvider.notifier).applyRelic(id);
                        Navigator.of(sheetContext).pop();
                      },
                    ),
                  );
                }
              }
            }
            // Show miniboss story scene on floor 4 (elite node) victory
            if (victory && node.type == RiftNodeType.elite && mounted) {
              final scene =
                  StoryScenes.chapterScenes[widget.chapterNumber]?['miniboss'];
              if (scene != null) {
                StorySceneModal.show(
                  context: context,
                  title: scene.title,
                  illustrationAsset: scene.illustration,
                  dialogueLines: scene.dialogue,
                  onContinue: () {},
                );
              }
            }
            // Show epilogue after boss victory
            if (victory && node.type == RiftNodeType.boss && mounted) {
              final scene =
                  StoryScenes.chapterScenes[widget.chapterNumber]?['epilogue'];
              if (scene != null) {
                StorySceneModal.show(
                  context: context,
                  title: scene.title,
                  illustrationAsset: scene.illustration,
                  dialogueLines: scene.dialogue,
                  onContinue: () {},
                );
              }
            }
            // Show loot chest for mini-boss (elite) and chapter boss victories
            if (victory &&
                campaignEnemy != null &&
                (node.type == RiftNodeType.elite ||
                    node.type == RiftNodeType.boss) &&
                mounted) {
              LootChestModal.show(
                context: context,
                enemy: campaignEnemy,
                isChapterBoss: node.type == RiftNodeType.boss,
                onContinue: () {},
              );
            }
          },
        ),
      ),
    );
  }

  CombatEngine _buildCombatEngine(
    RiftRun run,
    RiftRunNode node,
    CollectionState collection, {
    Map<String, int> talentLevels = const {},
    Map<String, int> gearLevels = const {},
  }) {
    final mods = CombatModifiers.fromRelics(run.relicIds).copyWith(
      startManaFraction:
          run.startManaFraction > 0 ? run.startManaFraction : null,
    );

    final campaignEnemy = enemyForFloor(widget.chapterNumber, node.floor);
    final boss = campaignEnemy?.toBossConfig() ??
        BossConfig(
          id: 'fallback_${node.id}',
          name: 'Enemigo Desconocido',
          element: Element.igneous,
          maxHp: 300,
          attackInterval: 6.0,
          attackDamage: 15,
          projectilesPerAttack: 2,
        );

    return CombatEngine(
      boss: boss,
      cards: _squadCards(collection),
      playerMaxHp: run.playerMaxHp,
      modifiers: mods,
      talentLevels: talentLevels,
      summonerGear: gearLevels,
      startHp: run.playerHp,
    );
  }

  List<ManaCard> _squadCards(CollectionState collection) {
    final cards = <ManaCard>[];
    for (final id in collection.squad.take(4)) {
      for (final c in collection.owned) {
        if (c.instanceId != id) continue;
        cards.add(ManaCard(
          id: c.catalogId,
          name: c.name,
          element: c.element,
          baseManaCost: c.baseManaCost,
          attack: c.baseAttack * (1.0 + 0.10 * (c.level - 1)),
          stars: c.stars,
        ));
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
            attack: 10),
        ManaCard(
            id: 'abyss_stalker',
            name: 'Acechador de Escarcha',
            element: Element.abyssal,
            baseManaCost: 95,
            attack: 12),
        ManaCard(
            id: 'terra_golem',
            name: 'Gólem de Basalto',
            element: Element.telluric,
            baseManaCost: 100,
            attack: 8),
        ManaCard(
            id: 'void_specter',
            name: 'Espectro del Sello',
            element: Element.empty,
            baseManaCost: 110,
            attack: 15),
      ];

  Widget _buildNodeTooltip(int nodeId, BoxConstraints constraints) {
    final run = _run!;
    final node = run.nodes.firstWhere((n) => n.id == nodeId);
    final enemy = campaignEnemies.firstWhere(
      (e) =>
          e.chapterNumber == widget.chapterNumber &&
          e.floor == node.floor &&
          e.tier == _nodeTier(node.type),
      orElse: () => campaignEnemies.first,
    );
    final isAvailable = run.currentNode.next.contains(node.id);
    final isCleared = run.clearedNodeIds.contains(node.id);

    return Positioned(
      top: constraints.maxHeight * 0.05,
      left: 10,
      right: 10,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF14090D),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: isAvailable
                      ? const Color(0xFFB16EFF)
                      : const Color(0xFF2A151A),
                  width: 2),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 10,
                    spreadRadius: 2)
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(enemy.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                    '${enemy.maxHp.round()} HP  •  ${enemy.targetCount} dianas  •  Piso ${node.floor}',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(_nodeIcon(node.type),
                      color: _nodeColor(node.type, isCleared, isAvailable),
                      size: 18),
                  const SizedBox(width: 8),
                  Text(
                    isCleared
                        ? 'COMPLETADO'
                        : (isAvailable ? 'DISPONIBLE' : 'BLOQUEADO'),
                    style: TextStyle(
                      color: isCleared
                          ? const Color(0xFFFFC93C)
                          : (isAvailable
                              ? const Color(0xFF4FFFA3)
                              : Colors.white38),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  EnemyTier _nodeTier(RiftNodeType type) {
    return switch (type) {
      RiftNodeType.combat => EnemyTier.minion,
      RiftNodeType.elite => EnemyTier.minion,
      RiftNodeType.boss => EnemyTier.chapterBoss,
      _ => EnemyTier.minion,
    };
  }

  IconData _nodeIcon(RiftNodeType type) => switch (type) {
        RiftNodeType.combat => Icons.sports_mma,
        RiftNodeType.elite => Icons.star,
        RiftNodeType.boss => Icons.emoji_events,
        RiftNodeType.altar => Icons.local_fire_department,
        RiftNodeType.event => Icons.help_outline,
      };

  Color _nodeColor(RiftNodeType type, bool cleared, bool available) {
    if (cleared) return const Color(0xFFFFC93C);
    if (available) {
      return switch (type) {
        RiftNodeType.combat => const Color(0xFFB0703B),
        RiftNodeType.elite => const Color(0xFFFF5A26),
        RiftNodeType.boss => const Color(0xFFB16EFF),
        RiftNodeType.altar => const Color(0xFF3FD8FF),
        RiftNodeType.event => const Color(0xFFFFC93C),
      };
    }
    return const Color(0xFF3A2328);
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  const _StatChip(
      {required this.icon, required this.color, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 3),
        Text(value, style: TextStyle(color: color, fontSize: 12))
      ]),
    );
  }
}

/// Background with chapter theme color
class _ChapterBackground extends StatelessWidget {
  final int chapterNumber;
  const _ChapterBackground({required this.chapterNumber});

  Color get _color => switch (chapterNumber) {
        1 => const Color(0xFFFF5A26), // Ígneo - lava
        2 => const Color(0xFF3FD8FF), // Abisal - hielo
        3 => const Color(0xFF4FFFA3), // Telúrico - esmeralda
        4 => const Color(0xFFB16EFF), // Vacío - púrpura
        5 => const Color(0xFFFFC93C), // Sello Roto - oro carmesí
        _ => const Color(0xFFB16EFF),
      };

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5,
            colors: [
              _color.withValues(alpha: 0.08),
              const Color(0xFF0C0608),
              const Color(0xFF0C0608),
            ],
          ),
        ),
      ),
    );
  }
}

class _RiftMapPainter extends CustomPainter {
  final RiftRun run;
  final int? hoveredNodeId;
  final double pulseValue;
  final int chapterNumber;
  final Size size;

  const _RiftMapPainter({
    required this.run,
    this.hoveredNodeId,
    required this.pulseValue,
    required this.chapterNumber,
    required this.size,
  });

  Color get _chapterColor => switch (chapterNumber) {
        1 => const Color(0xFFFF5A26),
        2 => const Color(0xFF3FD8FF),
        3 => const Color(0xFF4FFFA3),
        4 => const Color(0xFFB16EFF),
        5 => const Color(0xFFFFC93C),
        _ => const Color(0xFFB16EFF),
      };

  static List<_NodeLayout> computeLayouts(RiftRun run, Size size) {
    final floors = run.nodes.map((n) => n.floor).toSet().toList()..sort();
    final result = <_NodeLayout>[];
    final rowH = (size.height - 80) / math.max(1, floors.length - 1);
    for (var rowIndex = 0; rowIndex < floors.length; rowIndex++) {
      final floor = floors[rowIndex];
      final laneNodes =
          run.nodes.where((n) => n.floor == floor).toList(growable: false);
      final cy = 40 + rowIndex * rowH;
      for (var i = 0; i < laneNodes.length; i++) {
        final cx = size.width * ((i + 1) / (laneNodes.length + 1));
        result.add(_NodeLayout(laneNodes[i], Offset(cx, cy)));
      }
    }
    return result;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final layouts = computeLayouts(run, size);
    final byId = {for (final l in layouts) l.node.id: l};
    final available = run.currentNode.next;
    final cleared = run.clearedNodeIds;

    // Draw Bézier curves between nodes
    for (final l in layouts) {
      for (final nextId in l.node.next) {
        final target = byId[nextId];
        if (target == null) continue;
        final isPathAvailable = available.contains(nextId);
        final isPathCleared =
            cleared.contains(l.node.id) && cleared.contains(nextId);

        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = isPathAvailable ? 3.0 : 2.0
          ..strokeCap = StrokeCap.round;

        final path = Path();
        path.moveTo(l.center.dx, l.center.dy);
        final midX = (l.center.dx + target.center.dx) / 2;
        path.cubicTo(
          midX,
          l.center.dy,
          midX,
          target.center.dy,
          target.center.dx,
          target.center.dy,
        );

        if (isPathCleared) {
          // Gold path for completed
          paint.shader = const LinearGradient(
            colors: [Color(0xFFFFC93C), Color(0xFFFFD700), Color(0xFFFFC93C)],
          ).createShader(Rect.fromPoints(l.center, target.center));
        } else if (isPathAvailable) {
          // Pulsing green/amber for available
          final alpha = 0.5 + 0.3 * math.sin(pulseValue * 2 * math.pi);
          paint.color = _chapterColor.withValues(alpha: alpha);
        } else {
          // Dark grey for locked
          paint.color = Colors.white10;
        }
        canvas.drawPath(path, paint);

        // Glow effect for available paths
        if (isPathAvailable && !isPathCleared) {
          final glowPaint = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6.0
            ..strokeCap = StrokeCap.round
            ..color = _chapterColor.withValues(
                alpha: 0.15 * (0.5 + 0.5 * math.sin(pulseValue * 2 * math.pi)));
          canvas.drawPath(path, glowPaint);
        }
      }
    }

    // Draw nodes
    for (final l in layouts) {
      final isCleared = cleared.contains(l.node.id);
      final isAvailable = available.contains(l.node.id);
      final isHovered = hoveredNodeId == l.node.id;
      final isCurrent = l.node.id == run.currentNode.id;

      final baseColor = _nodeColor(l.node.type, isCleared, isAvailable);
      final r = isAvailable ? 24.0 : (isCurrent ? 22.0 : 18.0);

      // Outer glow for available/current/hovered
      if (isAvailable || isCurrent || isHovered) {
        final glowR =
            r + 8 + (isAvailable ? 4 * math.sin(pulseValue * 2 * math.pi) : 0);
        canvas.drawCircle(
          l.center,
          glowR,
          Paint()..color = baseColor.withValues(alpha: isAvailable ? 0.2 : 0.1),
        );
      }

      // Node background circle
      canvas.drawCircle(
        l.center,
        r + 2,
        Paint()..color = baseColor.withValues(alpha: 0.2),
      );

      // Main node circle
      final nodePaint = Paint()
        ..style = PaintingStyle.fill
        ..color = baseColor;
      if (isHovered) {
        nodePaint.color = baseColor.withValues(alpha: 0.9);
      }
      canvas.drawCircle(l.center, r, nodePaint);

      // Border
      canvas.drawCircle(
        l.center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = isAvailable ? 2.5 : 1.5
          ..color = Colors.white.withValues(alpha: isAvailable ? 0.9 : 0.4),
      );

      // Orbital aura for boss
      if (l.node.type == RiftNodeType.boss) {
        final auraR = r + 6 + 3 * math.sin(pulseValue * 2 * math.pi);
        canvas.drawCircle(
          l.center,
          auraR,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = baseColor.withValues(alpha: 0.5),
        );
      }

      // Node icon
      final textPainter = TextPainter(
        text: TextSpan(
          text: _nodeLetter(l.node.type),
          style: TextStyle(
            color: Colors.white,
            fontSize: r * 0.7,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 2)
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas,
          l.center - Offset(textPainter.width / 2, textPainter.height / 2));

      // Mini portrait for combat nodes
      if (l.node.type == RiftNodeType.combat ||
          l.node.type == RiftNodeType.elite ||
          l.node.type == RiftNodeType.boss) {
        final portraitRect = Rect.fromCenter(
          center: l.center + Offset(0, r + 18),
          width: 28,
          height: 28,
        );
        canvas.drawCircle(
          portraitRect.center,
          14,
          Paint()..color = const Color(0xFF0A0407),
        );
        canvas.drawCircle(
          portraitRect.center,
          14,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = baseColor.withValues(alpha: 0.5),
        );
        // Element color indicator
        final enemy = enemyForFloor(chapterNumber, l.node.floor);
        if (enemy != null) {
          canvas.drawCircle(
            portraitRect.center,
            10,
            Paint()
              ..color = _elementColor(enemy.element).withValues(alpha: 0.6),
          );
        }
      }

      // State indicator
      if (isCleared) {
        _drawCheckmark(canvas, l.center + Offset(r * 0.7, -r * 0.7), r * 0.5);
      } else if (isCurrent) {
        _drawPulseRing(canvas, l.center, r + 4, pulseValue);
      }
    }
  }

  void _drawCheckmark(Canvas canvas, Offset center, double size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = Colors.white
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(center.dx - size * 0.4, center.dy)
      ..lineTo(center.dx - size * 0.1, center.dy + size * 0.3)
      ..lineTo(center.dx + size * 0.4, center.dy - size * 0.3);
    canvas.drawPath(path, paint);
  }

  void _drawPulseRing(
      Canvas canvas, Offset center, double radius, double pulse) {
    canvas.drawCircle(
      center,
      radius + 3 * math.sin(pulse * 2 * math.pi),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white
            .withValues(alpha: 0.5 + 0.3 * math.sin(pulse * 2 * math.pi)),
    );
  }

  Color _nodeColor(RiftNodeType type, bool cleared, bool available) {
    if (cleared) return const Color(0xFFFFC93C);
    if (available) {
      return switch (type) {
        RiftNodeType.combat => const Color(0xFFB0703B),
        RiftNodeType.elite => const Color(0xFFFF5A26),
        RiftNodeType.boss => const Color(0xFFB16EFF),
        RiftNodeType.altar => const Color(0xFF3FD8FF),
        RiftNodeType.event => const Color(0xFFFFC93C),
      };
    }
    return const Color(0xFF3A2328);
  }

  String _nodeLetter(RiftNodeType type) => switch (type) {
        RiftNodeType.combat => '⚔',
        RiftNodeType.elite => '★',
        RiftNodeType.boss => '👑',
        RiftNodeType.altar => '🩸',
        RiftNodeType.event => '?',
      };

  Color _elementColor(Element e) => switch (e) {
        Element.igneous => const Color(0xFFFF5A26),
        Element.abyssal => const Color(0xFF3FD8FF),
        Element.telluric => const Color(0xFFB0703B),
        Element.empty => const Color(0xFFB16EFF),
      };

  @override
  bool shouldRepaint(covariant _RiftMapPainter oldDelegate) =>
      oldDelegate.run != run ||
      oldDelegate.hoveredNodeId != hoveredNodeId ||
      oldDelegate.pulseValue != pulseValue ||
      oldDelegate.chapterNumber != chapterNumber ||
      oldDelegate.size != size;
}

class _NodeLayout {
  final RiftRunNode node;
  final Offset center;
  const _NodeLayout(this.node, this.center);
}

// --- Blood Altar Modal (moved here for convenience) ---
class BloodAltarModal extends StatelessWidget {
  final List<String> ownedRelicIds;
  final VoidCallback onHeal;
  final void Function(List<String>) onSacrifice;
  final VoidCallback onManaBoost;

  const BloodAltarModal({
    super.key,
    required this.ownedRelicIds,
    required this.onHeal,
    required this.onSacrifice,
    required this.onManaBoost,
  });

  @override
  Widget build(BuildContext context) {
    final availableRelics = [
      'ojo_abismo',
      'pacto_sangre',
      'sello_resonancia',
      'reloj_ceniza',
      'piel_basalto',
      'canalizacion_runica',
      'yelmo_abismo',
      'guanteletes_titan',
    ].where((r) => !ownedRelicIds.contains(r)).toList();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF14090D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3FD8FF), width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('HOGUERA / ALTAR DE CURACIÓN',
              style: TextStyle(
                  color: Color(0xFF3FD8FF),
                  fontSize: 18,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('Elige tu bendición:',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 16),
          _AltarOption(
            icon: Icons.favorite,
            color: Colors.redAccent,
            title: 'Curación (45% HP)',
            subtitle: 'Recupera 45% de tu vida máxima',
            onTap: onHeal,
          ),
          _AltarOption(
            icon: Icons.auto_awesome,
            color: const Color(0xFFFFD700),
            title: 'Sacrificio',
            subtitle: 'Pierde 12% HP → Ganas 150 oro + Reliquia',
            onTap: () => onSacrifice(availableRelics.take(1).toList()),
            disabled: availableRelics.isEmpty,
          ),
          _AltarOption(
            icon: Icons.bolt,
            color: const Color(0xFFB16EFF),
            title: 'Canalización de Maná',
            subtitle: 'La próxima batalla inicia con 50% de maná',
            onTap: onManaBoost,
          ),
        ],
      ),
    );
  }
}

class _AltarOption extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool disabled;

  const _AltarOption({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color:
                  disabled ? const Color(0xFF1A0A0F) : const Color(0xFF1A0A0F),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: disabled ? Colors.white10 : color.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: disabled ? Colors.white24 : color, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              color: disabled ? Colors.white38 : Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: TextStyle(
                              color: disabled ? Colors.white24 : Colors.white70,
                              fontSize: 11)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: disabled ? Colors.white24 : color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

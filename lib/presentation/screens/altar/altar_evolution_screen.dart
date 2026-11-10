import 'package:flutter/material.dart' hide Element;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/procedural_sfx_engine.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../domain/entities/owned_card.dart';
import '../../../domain/meta/meta_rules.dart';
import '../../../domain/meta/mythic_ascension.dart';
import '../../../domain/meta/rune_system.dart';
import '../../../domain/value_objects/card_skin.dart';
import '../../../domain/value_objects/element.dart';
import '../../../domain/value_objects/rarity.dart';
import '../../controllers/meta_controller.dart';
import '../../graphics/art_registry.dart';
import '../../graphics/painted_backdrop.dart';
import '../../graphics/rift_effect.dart';
import '../../widgets/brimstone_button.dart';
import '../../widgets/tcg_card_widget.dart';

/// Helper to convert domain RuneSystem values to Flutter UI types.
extension RuneSystemUI on RuneType {
  Color get color => Color(RuneSystem.runeColorValue(this));
  IconData get icon => _iconFromName(RuneSystem.runeIconName(this));
  String description([int level = 1]) =>
      RuneSystem.runeDescription(this, level);
}

IconData _iconFromName(String name) {
  switch (name) {
    case 'local_fire_department':
      return Icons.local_fire_department;
    case 'waves':
      return Icons.waves;
    case 'bloodtype':
      return Icons.bloodtype;
    case 'compare_arrows':
      return Icons.compare_arrows;
    default:
      return Icons.help_outline;
  }
}

/// Altar Triple: 3 Ritual Tabs (Block 5)
/// Tab 1 - EvoluciÃ³n (Batch Evolve): Evolve duplicates in bulk
/// Tab 2 - Alquimia de Runas (Rune Synthesis): Forge specific runes or upgrade to Level 5 (Mythic)
/// Tab 3 - CreaciÃ³n de Almas (Soul Crafting): Forge any of the 20 catalog cards with shards
class AltarEvolutionScreen extends ConsumerStatefulWidget {
  const AltarEvolutionScreen({super.key});

  @override
  ConsumerState<AltarEvolutionScreen> createState() =>
      _AltarEvolutionScreenState();
}

class _AltarEvolutionScreenState extends ConsumerState<AltarEvolutionScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final collectionState = ref.watch(collectionProvider);
    final allCards = collectionState.owned;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0407),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14090D),
        elevation: 2,
        shadowColor: Colors.black87,
        title: const Text(
          'ALTAR TRIPLE',
          style: TextStyle(
            color: Color(0xFFD4AF37),
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFD4AF37)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFFC93C),
          indicatorWeight: 3,
          labelColor: const Color(0xFFFFC93C),
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(
              fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5),
          unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5),
          tabs: const [
            Tab(icon: Icon(Icons.auto_fix_high, size: 18), text: 'EVOLUCIÃ“N'),
            Tab(icon: Icon(Icons.science, size: 18), text: 'ALQUIMIA'),
            Tab(
                icon: Icon(Icons.auto_awesome, size: 18),
                text: 'FORJA DE ALMAS'),
            Tab(icon: Icon(Icons.diamond, size: 18), text: 'ASCENSIÓN'),
          ],
        ),
      ),
      body: PaintedBackdrop(
        asset: ArtRegistry.metaScenes['altar']!,
        tint: const Color(0xFFFFC93C),
        darkness: 0.35,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Forge aura: the rift burns dimly behind the altar tabs.
            Positioned.fill(
              child: IgnorePointer(
                child: AbyssalRiftView(
                  color: const Color(0xFFFFC93C),
                  intensity: 0.5,
                ),
              ),
            ),
            TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Batch Evolve
                _BatchEvolveTab(allCards: allCards),
                // Tab 2: Rune Synthesis
                _RuneSynthesisTab(allCards: allCards),
                // Tab 3: Soul Crafting
                _SoulCraftingTab(allCards: allCards),
                // Tab 4: 5★ Primordial Ascension
                _MythicAscensionTab(allCards: allCards),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================
/// TAB 1: BATCH EVOLVE - Evolve all eligible duplicates at once
/// ============================================================
class _BatchEvolveTab extends ConsumerWidget {
  final List<OwnedCard> allCards;

  const _BatchEvolveTab({required this.allCards});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final evolvableGroups = _getEvolvableGroups(allCards);
    final totalCost = evolvableGroups.fold<int>(0,
        (sum, g) => sum + EvolutionRules.costFor(g.baseCard.stars) * g.count);
    final profile = ref.watch(profileProvider);

    if (evolvableGroups.isEmpty) {
      return _EmptyState(
        icon: Icons.auto_fix_high,
        title: 'SIN EVOLUCIONES DISPONIBLES',
        subtitle:
            'Necesitas duplicados de la misma carta y estrellas para evolucionar.',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Summary Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                const Color(0xFF1A0A0F),
                const Color(0xFF0C0608),
              ]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFFFFC93C).withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_fix_high,
                        color: Color(0xFFFFC93C), size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'EVOLUCIÃ“N EN LOTE',
                        style: const TextStyle(
                          color: Color(0xFFFFC93C),
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFC93C).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${evolvableGroups.fold<int>(0, (s, g) => s + g.count)} cartas',
                        style: const TextStyle(
                          color: Color(0xFFFFC93C),
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Se encontraron ${evolvableGroups.length} grupos de duplicados evolucionables.',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.attach_money,
                        color: Color(0xFFFFD700), size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Costo total: $totalCost oro',
                      style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      profile.gold >= totalCost
                          ? 'âœ“ FONDOS SUFICIENTES'
                          : 'âœ— ORO INSUFICIENTE',
                      style: TextStyle(
                        color: profile.gold >= totalCost
                            ? const Color(0xFF4FFFA3)
                            : Colors.redAccent,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // List of evolvable groups
          ...evolvableGroups.map((group) => _EvolvableGroupTile(
                group: group,
                onTap: () => _showEvolveDetail(context, ref, group),
              )),
          const SizedBox(height: 16),
          // Batch Evolve Button
          BrimstoneButton(
            width: double.infinity,
            height: 56,
            icon: Icons.auto_fix_high,
            label:
                'âš¡ EVOLUCIONAR DUPLICADOS EN LOTE (${evolvableGroups.fold<int>(0, (s, g) => s + g.count)} cartas)',
            onPressed: profile.gold >= totalCost && totalCost > 0
                ? () => _batchEvolve(context, ref, evolvableGroups, totalCost)
                : null,
          ),
        ],
      ),
    );
  }

  List<_EvolvableGroup> _getEvolvableGroups(List<OwnedCard> cards) {
    final groups = <String, List<OwnedCard>>{};
    for (final card in cards) {
      if (card.stars < EvolutionRules.maxStars) {
        final key = '${card.catalogId}_${card.stars}';
        groups.putIfAbsent(key, () => []).add(card);
      }
    }

    final result = <_EvolvableGroup>[];
    for (final entry in groups.entries) {
      final cardsInGroup = entry.value;
      if (cardsInGroup.length >= 2) {
        // Each evolution consumes 1 duplicate
        final pairs = cardsInGroup.length ~/ 2;
        if (pairs > 0) {
          result.add(_EvolvableGroup(
            baseCard: cardsInGroup.first,
            count: pairs,
            totalCost: EvolutionRules.costFor(cardsInGroup.first.stars) * pairs,
          ));
        }
      }
    }
    return result;
  }

  void _showEvolveDetail(
      BuildContext context, WidgetRef ref, _EvolvableGroup group) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF14090D),
      isScrollControlled: true,
      builder: (ctx) => _EvolveDetailSheet(group: group),
    );
  }

  Future<void> _batchEvolve(BuildContext context, WidgetRef ref,
      List<_EvolvableGroup> groups, int totalCost) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A0E14),
        title: const Text('CONFIRMAR EVOLUCIÃ“N EN LOTE',
            style: TextStyle(
                color: Color(0xFFFFC93C), fontWeight: FontWeight.w900)),
        content: Text(
            'Se evolucionarÃ¡n ${groups.fold<int>(0, (s, g) => s + g.count)} cartas por $totalCost oro. Â¿Continuar?',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCELAR')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('EVOLUCIONAR',
                  style: TextStyle(
                      color: Color(0xFFFFC93C), fontWeight: FontWeight.w900))),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final collection = ref.read(collectionProvider.notifier);
    int evolvedCount = 0;
    for (final group in groups) {
      for (int i = 0; i < group.count; i++) {
        final ok = await collection.evolve(group.baseCard.instanceId);
        if (ok) evolvedCount++;
      }
    }

    if (context.mounted) {
      if (evolvedCount > 0) {
        ProceduralSfxEngine.playEvolutionSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Â¡$evolvedCount cartas evolucionadas exitosamente!'),
              backgroundColor: const Color(0xFF4FFFA3)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No se pudo evolucionar ninguna carta.'),
              backgroundColor: Colors.redAccent),
        );
      }
    }
  }
}

class _EvolvableGroup {
  final OwnedCard baseCard;
  final int count;
  final int totalCost;

  const _EvolvableGroup(
      {required this.baseCard, required this.count, required this.totalCost});
}

class _EvolvableGroupTile extends StatelessWidget {
  final _EvolvableGroup group;
  final VoidCallback onTap;

  const _EvolvableGroupTile({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final card = group.baseCard;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A0E14),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: const Color(0xFFFFC93C).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            TcgCardWidget.fromOwnedCard(card: card, width: 60, height: 82),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(card.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12)),
                  Text(
                      '${card.stars}â˜… â†’ ${card.stars + 1}â˜…  â€¢  ATK ${card.baseAttack} â†’ ${(card.baseAttack * 1.35).round()}',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 10)),
                  Text(
                      '${group.count} evoluciÃ³n(es)  â€¢  ${group.totalCost} oro',
                      style: const TextStyle(
                          color: Color(0xFFFFC93C),
                          fontWeight: FontWeight.w700,
                          fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}

class _EvolveDetailSheet extends StatelessWidget {
  final _EvolvableGroup group;

  const _EvolveDetailSheet({required this.group});

  @override
  Widget build(BuildContext context) {
    final card = group.baseCard;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        height: MediaQuery.of(context).size.height * 0.5,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('DETALLE DE EVOLUCIÃ“N',
                style: const TextStyle(
                    color: Color(0xFFD4AF37),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5)),
            const SizedBox(height: 16),
            TcgCardWidget.fromOwnedCard(card: card, raised: true),
            const SizedBox(height: 12),
            Text('${group.count} evoluciÃ³n(es) disponibles',
                style: const TextStyle(
                    color: Color(0xFFFFC93C), fontWeight: FontWeight.w900)),
            Text(
                'Costo por evoluciÃ³n: ${EvolutionRules.costFor(card.stars)} oro',
                style: const TextStyle(color: Colors.white70)),
            Text('Costo total: ${group.totalCost} oro',
                style: const TextStyle(
                    color: Color(0xFFFFD700), fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            Text('Preview:',
                style: const TextStyle(color: Colors.white54, fontSize: 11)),
            const SizedBox(height: 8),
            TcgCardWidget.fromOwnedCard(
              card: OwnedCard(
                instanceId: -1,
                catalogId: card.catalogId,
                name: card.name,
                element: card.element,
                rarity: card.rarity,
                baseManaCost: card.baseManaCost,
                baseAttack: (card.baseAttack * 1.35).round(),
                baseHealth: (card.baseHealth * 1.35).round(),
                level: card.level,
                stars: (card.stars + 1).clamp(1, 4),
                skillLevel: card.skillLevel,
                masteryXp: card.masteryXp,
              ),
              raised: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================
/// TAB 2: RUNE SYNTHESIS - Forge specific runes or upgrade to Level 5 (Mythic)
/// ============================================================
class _RuneSynthesisTab extends ConsumerWidget {
  final List<OwnedCard> allCards;

  const _RuneSynthesisTab({required this.allCards});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final runes = RuneType.values.toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                const Color(0xFF1A0A0F),
                const Color(0xFF0C0608),
              ]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFFB16EFF).withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.science,
                        color: Color(0xFFB16EFF), size: 24),
                    const SizedBox(width: 10),
                    const Text(
                      'ALQUIMIA DE RUNAS',
                      style: TextStyle(
                        color: Color(0xFFB16EFF),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Forja una Runa especÃ­fica o sube una equipada a Nivel 5 (MÃ­tica) usando Esquirlas.',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.diamond,
                        color: Color(0xFFB16EFF), size: 16),
                    const SizedBox(width: 6),
                    Text('Esquirlas: ${profile.shards}',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w900)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Forge new rune section
          const Text('FORJAR RUNA NUEVA',
              style: TextStyle(
                  color: Color(0xFFB16EFF),
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 0.5)),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.0,
            ),
            itemCount: runes.length,
            itemBuilder: (context, index) {
              final rune = runes[index];
              return _RuneForgeTile(
                rune: rune,
                shards: profile.shards,
                onTap: () => _showForgeRuneDialog(context, ref, rune),
              );
            },
          ),
          const SizedBox(height: 20),
          // Upgrade equipped rune to Level 5 section
          const Text('MEJORAR RUNA EQUIPADA A NIVEL 5 (MÃTICA)',
              style: TextStyle(
                  color: Color(0xFFB16EFF),
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 0.5)),
          const SizedBox(height: 8),
          _UpgradeEquippedRuneSection(allCards: allCards),
        ],
      ),
    );
  }

  void _showForgeRuneDialog(
      BuildContext context, WidgetRef ref, RuneType rune) {
    final profile = ref.read(profileProvider);
    final cost = RuneSystem.forgeCost(rune);
    final canAfford = profile.shards >= cost;

    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A0E14),
        title: Text('FORJAR ${rune.name.toUpperCase()}',
            style: const TextStyle(
                color: Color(0xFFB16EFF), fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Costo: $cost esquirlas',
                style: const TextStyle(color: Colors.white)),
            Text(RuneSystem.description(rune, 1),
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
            const SizedBox(height: 12),
            Text(canAfford ? 'Â¿Forjar esta runa?' : 'Esquirlas insuficientes',
                style: TextStyle(
                    color:
                        canAfford ? const Color(0xFF4FFFA3) : Colors.redAccent,
                    fontWeight: FontWeight.w700)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCELAR')),
          TextButton(
            onPressed: canAfford
                ? () async {
                    Navigator.pop(context);
                    await ref.read(collectionProvider.notifier).forgeRune(rune);
                    if (context.mounted) {
                      ProceduralSfxEngine.playOrbMerge(2);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Â¡Runa ${rune.name} forjada!'),
                            backgroundColor: const Color(0xFF4FFFA3)),
                      );
                    }
                  }
                : null,
            child: Text('FORJAR',
                style: TextStyle(
                    color: canAfford ? const Color(0xFFB16EFF) : Colors.white38,
                    fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

class _RuneForgeTile extends StatelessWidget {
  final RuneType rune;
  final int shards;
  final VoidCallback onTap;

  const _RuneForgeTile(
      {required this.rune, required this.shards, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cost = RuneSystem.forgeCost(rune);
    final canAfford = shards >= cost;
    final color = rune.color;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: canAfford ? color.withValues(alpha: 0.8) : Colors.white12,
              width: canAfford ? 2 : 1),
          gradient: LinearGradient(
              colors: canAfford
                  ? [
                      color.withValues(alpha: 0.2),
                      color.withValues(alpha: 0.05)
                    ]
                  : [const Color(0xFF1A0E14), const Color(0xFF0C0608)]),
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(rune.icon, color: color, size: 32),
                const SizedBox(height: 8),
                Text(rune.name.toUpperCase(),
                    style: TextStyle(
                        color: canAfford ? color : Colors.white38,
                        fontWeight: FontWeight.w900,
                        fontSize: 9,
                        letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Text('Nivel 1',
                    style: TextStyle(
                        color: canAfford ? Colors.white70 : Colors.white24,
                        fontSize: 9)),
              ],
            ),
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.diamond, size: 12, color: Color(0xFFB16EFF)),
                  const SizedBox(width: 4),
                  Text('$cost',
                      style: TextStyle(
                          color: canAfford
                              ? const Color(0xFFB16EFF)
                              : Colors.white38,
                          fontWeight: FontWeight.w900,
                          fontSize: 10)),
                ],
              ),
            ),
            if (!canAfford)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                      child: Icon(Icons.lock, color: Colors.white38, size: 24)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _UpgradeEquippedRuneSection extends ConsumerWidget {
  final List<OwnedCard> allCards;

  const _UpgradeEquippedRuneSection({required this.allCards});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runesMapAsync = ref.watch(cardRunesMapProvider);

    return runesMapAsync.when(
      data: (runesMap) {
        final cardsWithRunes = allCards
            .where((card) => runesMap.containsKey(card.instanceId))
            .toList();

        if (cardsWithRunes.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A0E14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: const Text('No tienes runas equipadas para mejorar.',
                style: TextStyle(color: Colors.white38, fontSize: 11),
                textAlign: TextAlign.center),
          );
        }

        return Column(
          children: cardsWithRunes.map((card) {
            final rune = runesMap[card.instanceId]!;
            final isMax = rune.level >= 5;
            final cost = isMax ? 0 : RuneSystem.upgradeCost(rune);
            return _EquippedRuneUpgradeTile(
              card: card,
              rune: rune,
              cost: cost,
              isMax: isMax,
              onTap: isMax
                  ? null
                  : () => _showUpgradeDialog(context, ref, card, rune, cost),
            );
          }).toList(),
        );
      },
      loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFFB16EFF))),
      error: (_, __) => Container(
        padding: const EdgeInsets.all(16),
        child: const Text('Error cargando runas',
            style: TextStyle(color: Colors.redAccent)),
      ),
    );
  }

  void _showUpgradeDialog(BuildContext context, WidgetRef ref, OwnedCard card,
      RuneInstance rune, int cost) {
    final profile = ref.read(profileProvider);
    final canAfford = profile.shards >= cost;

    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A0E14),
        title: Text(
            'MEJORAR ${rune.type.name.toUpperCase()} Nv.${rune.level} â†’ Nv.${rune.level + 1}',
            style: const TextStyle(
                color: Color(0xFFB16EFF), fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Costo: $cost esquirlas',
                style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 8),
            Text(
                canAfford
                    ? 'Â¿Mejorar a Nivel ${rune.level + 1}?'
                    : 'Esquirlas insuficientes',
                style: TextStyle(
                    color:
                        canAfford ? const Color(0xFF4FFFA3) : Colors.redAccent,
                    fontWeight: FontWeight.w700)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCELAR')),
          TextButton(
            onPressed: canAfford
                ? () async {
                    Navigator.pop(context);
                    await ref
                        .read(collectionProvider.notifier)
                        .upgradeRune(card.instanceId);
                    if (context.mounted) {
                      ProceduralSfxEngine.playOrbMerge(rune.level);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                'Â¡Runa mejorada a Nivel ${rune.level + 1}!'),
                            backgroundColor: const Color(0xFF4FFFA3)),
                      );
                    }
                  }
                : null,
            child: Text('MEJORAR',
                style: TextStyle(
                    color: canAfford ? const Color(0xFFB16EFF) : Colors.white38,
                    fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

class _EquippedRuneUpgradeTile extends StatelessWidget {
  final OwnedCard card;
  final RuneInstance rune;
  final int cost;
  final bool isMax;
  final VoidCallback? onTap;

  const _EquippedRuneUpgradeTile(
      {required this.card,
      required this.rune,
      required this.cost,
      required this.isMax,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = rune.type.color;
    final rarityColor = rune.level >= 5 ? const Color(0xFFFFD700) : color;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            const Color(0xFF1A0E14),
            const Color(0xFF0C0608),
          ]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isMax
                  ? const Color(0xFFFFD700).withValues(alpha: 0.5)
                  : color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            TcgCardWidget.fromOwnedCard(card: card, width: 50, height: 68),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(rune.type.icon, color: rarityColor, size: 18),
                      const SizedBox(width: 6),
                      Text(
                          '${rune.type.name.toUpperCase()}  Nv.${rune.level}${isMax ? ' (MÃX.)' : ''}',
                          style: TextStyle(
                              color: rarityColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 11)),
                    ],
                  ),
                  Text(card.name,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 10)),
                  Text(rune.type.description(rune.level),
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 9)),
                ],
              ),
            ),
            if (!isMax) ...[
              const Icon(Icons.diamond, color: Color(0xFFB16EFF), size: 16),
              const SizedBox(width: 4),
              Text('$cost',
                  style: const TextStyle(
                      color: Color(0xFFB16EFF),
                      fontWeight: FontWeight.w900,
                      fontSize: 12)),
              const SizedBox(width: 8),
            ],
            if (isMax)
              const Chip(
                label: Text('MÃTICA',
                    style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 9)),
                backgroundColor: Color(0xFFFFD700),
                padding: EdgeInsets.zero,
              ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================
/// TAB 3: SOUL CRAFTING - Forge any of the 20 catalog cards with shards
/// ============================================================
class _SoulCraftingTab extends ConsumerWidget {
  final List<OwnedCard> allCards;

  const _SoulCraftingTab({required this.allCards});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final catalog = _getFullCatalog();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                const Color(0xFF1A0A0F),
                const Color(0xFF0C0608),
              ]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome,
                        color: Color(0xFFFFD700), size: 24),
                    const SizedBox(width: 10),
                    const Text(
                      'CREACIÃ“N DE ALMAS',
                      style: TextStyle(
                        color: Color(0xFFFFD700),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Forja directamente cualquier carta del catÃ¡logo pagando Esquirlas.',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.diamond,
                        color: Color(0xFFB16EFF), size: 16),
                    const SizedBox(width: 6),
                    Text('Esquirlas: ${profile.shards}',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w900)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Catalog grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.74,
            ),
            itemCount: catalog.length,
            itemBuilder: (context, index) {
              final entry = catalog[index];
              final owned = allCards.any((c) => c.catalogId == entry['id']);
              return _SoulCraftTile(
                entry: entry,
                owned: owned,
                shards: profile.shards,
                onTap: () => _showCraftDialog(context, ref, entry),
              );
            },
          ),
        ],
      ),
    );
  }

  List<Map<String, Object>> _getFullCatalog() {
    return [
      // Common (120 shards)
      {
        'id': 'ignis_hound',
        'name': 'Sabueso de Azufre',
        'element': Element.igneous,
        'rarity': Rarity.common,
        'cost': 120
      },
      {
        'id': 'abyss_stalker',
        'name': 'Acechador de Escarcha',
        'element': Element.abyssal,
        'rarity': Rarity.common,
        'cost': 120
      },
      {
        'id': 'terra_golem',
        'name': 'GÃ³lem de Basalto',
        'element': Element.telluric,
        'rarity': Rarity.common,
        'cost': 120
      },
      // Rare (240 shards)
      {
        'id': 'ignis_drake',
        'name': 'Draco de Ceniza',
        'element': Element.igneous,
        'rarity': Rarity.rare,
        'cost': 240
      },
      {
        'id': 'abyss_siren',
        'name': 'Sirena del Abismo',
        'element': Element.abyssal,
        'rarity': Rarity.rare,
        'cost': 240
      },
      {
        'id': 'terra_warden',
        'name': 'GuardiÃ¡n TectÃ³nico',
        'element': Element.telluric,
        'rarity': Rarity.rare,
        'cost': 240
      },
      {
        'id': 'void_reaper',
        'name': 'Segador del VacÃ­o',
        'element': Element.empty,
        'rarity': Rarity.rare,
        'cost': 240
      },
      {
        'id': 'void_specter',
        'name': 'Espectro del Sello',
        'element': Element.empty,
        'rarity': Rarity.rare,
        'cost': 240
      },
      // Epic (450 shards)
      {
        'id': 'ignis_lord',
        'name': 'SeÃ±or de la Llama',
        'element': Element.igneous,
        'rarity': Rarity.epic,
        'cost': 450
      },
      {
        'id': 'terra_titan',
        'name': 'TitÃ¡n de Piedra',
        'element': Element.telluric,
        'rarity': Rarity.epic,
        'cost': 450
      },
      {
        'id': 'ignis_seraph',
        'name': 'SerafÃ­n de Fuego',
        'element': Element.igneous,
        'rarity': Rarity.epic,
        'cost': 450
      },
      {
        'id': 'abyss_kraken',
        'name': 'Kraken Abisal',
        'element': Element.abyssal,
        'rarity': Rarity.epic,
        'cost': 450
      },
      {
        'id': 'terra_hydra',
        'name': 'Hidra TelÃºrica',
        'element': Element.telluric,
        'rarity': Rarity.epic,
        'cost': 450
      },
      {
        'id': 'void_oracle',
        'name': 'OrÃ¡culo del VacÃ­o',
        'element': Element.empty,
        'rarity': Rarity.epic,
        'cost': 450
      },
      // Legendary (900 shards)
      {
        'id': 'ignis_colossus',
        'name': 'Vulcanor, Rey del CrÃ¡ter',
        'element': Element.igneous,
        'rarity': Rarity.legendary,
        'cost': 900
      },
      {
        'id': 'abyss_leviathan',
        'name': 'LeviatÃ¡n del Foso',
        'element': Element.abyssal,
        'rarity': Rarity.legendary,
        'cost': 900
      },
      {
        'id': 'terra_behemoth',
        'name': 'Behemoth MonolÃ­tico',
        'element': Element.telluric,
        'rarity': Rarity.legendary,
        'cost': 900
      },
      {
        'id': 'abyss_wraith',
        'name': 'Espectro Abisal',
        'element': Element.abyssal,
        'rarity': Rarity.legendary,
        'cost': 900
      },
      {
        'id': 'void_archon',
        'name': 'Xal\'atoh, Arconte del VacÃ­o',
        'element': Element.empty,
        'rarity': Rarity.legendary,
        'cost': 900
      },
      // Mythic (would be 1500 but not craftable directly)
    ];
  }

  void _showCraftDialog(
      BuildContext context, WidgetRef ref, Map<String, Object> entry) {
    final profile = ref.read(profileProvider);
    final cost = entry['cost'] as int;
    final canAfford = profile.shards >= cost;

    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A0E14),
        title: Text('FORJAR ${entry['name']}',
            style: const TextStyle(
                color: Color(0xFFFFD700), fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                '${entry['element']}  â€¢  ${entry['rarity'].toString().split('.').last.toUpperCase()}',
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
            const SizedBox(height: 8),
            Text('Costo: $cost esquirlas',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text(canAfford ? 'Â¿Forjar esta carta?' : 'Esquirlas insuficientes',
                style: TextStyle(
                    color:
                        canAfford ? const Color(0xFF4FFFA3) : Colors.redAccent,
                    fontWeight: FontWeight.w700)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCELAR')),
          TextButton(
            onPressed: canAfford
                ? () async {
                    Navigator.pop(context);
                    await ref
                        .read(playerRepositoryProvider)
                        .spend(shards: cost);
                    await ref
                        .read(collectionProvider.notifier)
                        .summon(grandRitual: false);
                    // Insert specific card
                    await ref
                        .read(playerRepositoryProvider)
                        .insertSummonedCard(entry['id'] as String);
                    if (context.mounted) {
                      ref.invalidate(collectionProvider);
                      ProceduralSfxEngine.playSummonReveal(1);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Â¡${entry['name']} forjada!'),
                            backgroundColor: const Color(0xFF4FFFA3)),
                      );
                    }
                  }
                : null,
            child: Text('FORJAR',
                style: TextStyle(
                    color: canAfford ? const Color(0xFFFFD700) : Colors.white38,
                    fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

class _SoulCraftTile extends StatelessWidget {
  final Map<String, Object> entry;
  final bool owned;
  final int shards;
  final VoidCallback onTap;

  const _SoulCraftTile(
      {required this.entry,
      required this.owned,
      required this.shards,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final element = entry['element'] as Element;
    final rarity = entry['rarity'] as Rarity;
    final cost = entry['cost'] as int;
    final canAfford = shards >= cost;
    final rarityColor = _rarityColor(rarity);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: owned
                ? const Color(0xFF4FFFA3).withValues(alpha: 0.8)
                : (canAfford
                    ? rarityColor.withValues(alpha: 0.8)
                    : Colors.white12),
            width: 1.5,
          ),
          gradient: LinearGradient(
              colors: owned
                  ? [
                      const Color(0xFF4FFFA3).withValues(alpha: 0.15),
                      const Color(0xFF0C0608)
                    ]
                  : (canAfford
                      ? [
                          rarityColor.withValues(alpha: 0.15),
                          const Color(0xFF0C0608)
                        ]
                      : [const Color(0xFF1A0E14), const Color(0xFF0C0608)])),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: TcgCardWidget.fromOwnedCard(
                    card: OwnedCard(
                      instanceId: -1,
                      catalogId: entry['id'] as String,
                      name: entry['name'] as String,
                      element: element,
                      rarity: rarity,
                      baseManaCost: 100,
                      baseAttack: 10,
                      baseHealth: 15,
                      level: 1,
                      stars: 1,
                      skillLevel: 1,
                      masteryXp: 0,
                    ),
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(10)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Icon(Icons.diamond,
                          size: 12, color: Color(0xFFB16EFF)),
                      Text('$cost',
                          style: TextStyle(
                              color: canAfford
                                  ? const Color(0xFFB16EFF)
                                  : Colors.white38,
                              fontWeight: FontWeight.w900,
                              fontSize: 9)),
                    ],
                  ),
                ),
              ],
            ),
            if (owned)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4FFFA3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('POSEÃDA',
                      style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 7)),
                ),
              ),
            if (!canAfford && !owned)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                      child: Icon(Icons.lock, color: Colors.white38, size: 24)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _rarityColor(Rarity r) => switch (r) {
        Rarity.common => Colors.white70,
        Rarity.rare => const Color(0xFF00FFFF),
        Rarity.epic => const Color(0xFFB16EFF),
        Rarity.legendary => const Color(0xFFFFD700),
        Rarity.mythic => const Color(0xFFFF5A26),
      };
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white24, size: 64),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    color: Colors.white38,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 0.5),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle,
                style: const TextStyle(color: Colors.white24, fontSize: 11),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// ============================================================
/// TAB 4: 5★ PRIMORDIAL ASCENSION - the mythic ceiling above 4★
/// ============================================================
class _MythicAscensionTab extends ConsumerWidget {
  final List<OwnedCard> allCards;

  const _MythicAscensionTab({required this.allCards});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final candidates = [
      for (final card in allCards)
        if (MythicAscension.canAscend(card.stars)) card,
    ];
    final mythic = [
      for (final card in allCards)
        if (card.isMythic) card,
    ];
    final affordable = profile.shards >= MythicAscension.shardCost &&
        profile.gold >= MythicAscension.goldCost;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF14121E), Color(0xFF07060C)],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFE6E9F5).withValues(alpha: 0.55),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.diamond,
                        color: Color(0xFFE6E9F5), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ASCENSIÓN PRIMORDIAL 5\u2605',
                        style: BrimstoneFonts.cinzel(
                          size: 13,
                          weight: FontWeight.w900,
                          color: const Color(0xFFE6E9F5),
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Sacrificá ${MythicAscension.shardCost} esquirlas y '
                  '${MythicAscension.goldCost} oro para despertar la forma '
                  'mítica: '
                  '+${((MythicAscension.statMultiplier - 1) * 100).round()}% '
                  'ATK/HP, -${MythicAscension.manaReduction} maná y '
                  '${MythicAscension.passiveLabel}.',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                const SizedBox(height: 6),
                Text(
                  'Esquirlas: ${profile.shards}  ·  Oro: ${profile.gold}',
                  style: TextStyle(
                    color: affordable
                        ? const Color(0xFF4FFFA3)
                        : const Color(0xFFFF8A6A),
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (candidates.isEmpty && mythic.isEmpty)
            const _EmptyState(
              icon: Icons.diamond_outlined,
              title: 'SIN CARTAS 4\u2605',
              subtitle:
                  'Evolucioná una carta hasta 4 estrellas para ascenderla.',
            ),
          for (final card in candidates) ...[
            _MythicCandidateTile(
              card: card,
              affordable: affordable,
              onAscend: () => _confirmAscension(context, ref, card),
            ),
            const SizedBox(height: 10),
          ],
          if (mythic.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'SKINS MÍTICAS',
              style: BrimstoneFonts.cinzel(
                size: 12,
                weight: FontWeight.w900,
                color: const Color(0xFFFFC93C),
                letterSpacing: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            for (final card in mythic)
              _MythicSkinPicker(
                card: card,
                onPick: (skin) async {
                  await ref
                      .read(collectionProvider.notifier)
                      .setSkin(card.instanceId, skin);
                },
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmAscension(
    BuildContext context,
    WidgetRef ref,
    OwnedCard card,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF100A14),
        title: Text(
          '¿ASCENDER A 5\u2605?',
          style: BrimstoneFonts.cinzel(
            size: 14,
            weight: FontWeight.w900,
            color: const Color(0xFFE6E9F5),
          ),
        ),
        content: Text(
          '${card.name} despertará su forma primordial. '
          'La ascensión consume ${MythicAscension.shardCost} esquirlas y '
          '${MythicAscension.goldCost} oro.',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('CANCELAR'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('ASCENDER'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final ok = await ref
        .read(collectionProvider.notifier)
        .ascendMythic(card.instanceId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF14121E),
        content: Text(
          ok
              ? '${card.name} asciende: ¡SELLO PRIMORDIAL ABIERTO!'
              : 'No alcanzan las esquirlas o el oro.',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}

class _MythicCandidateTile extends StatelessWidget {
  final OwnedCard card;
  final bool affordable;
  final VoidCallback onAscend;

  const _MythicCandidateTile({
    required this.card,
    required this.affordable,
    required this.onAscend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF120E1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE6E9F5).withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        children: [
          TcgCardWidget.fromOwnedCard(card: card, width: 58, height: 80),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '4\u2605 \u2192 5\u2605  ·  ATK ${card.baseAttack} \u2192 '
                  '${MythicAscension.attackAfter(card.baseAttack)}  ·  '
                  'HP ${card.baseHealth} \u2192 '
                  '${MythicAscension.healthAfter(card.baseHealth)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
                const SizedBox(height: 4),
                Text(
                  MythicAscension.passiveLabel,
                  style: const TextStyle(
                    color: Color(0xFFB16EFF),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          FilledButton(
            onPressed: affordable ? onAscend : null,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB0102C),
              disabledBackgroundColor: const Color(0xFF2A2030),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            child: Text(
              'ASCENDER',
              style: BrimstoneFonts.cinzel(
                size: 9,
                weight: FontWeight.w900,
                color: affordable ? Colors.white : Colors.white38,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MythicSkinPicker extends StatelessWidget {
  final OwnedCard card;
  final ValueChanged<CardSkin> onPick;

  const _MythicSkinPicker({required this.card, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0A12),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFFE6E9F5).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          TcgCardWidget.fromOwnedCard(card: card, width: 54, height: 74),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final skin in CardSkin.values)
                      GestureDetector(
                        onTap: () => onPick(skin),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: card.skin == skin
                                ? const Color(0xFFB0102C)
                                : const Color(0xFF1A1420),
                            border: Border.all(
                              color: const Color(0xFFE6E9F5)
                                  .withValues(alpha: 0.35),
                              width: 0.7,
                            ),
                          ),
                          child: Text(
                            skin.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

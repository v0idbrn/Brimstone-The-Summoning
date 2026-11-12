import 'package:flutter/material.dart' hide Element;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/roguelite/relic_catalog.dart';
import '../../controllers/meta_controller.dart';
import '../../combat_engine/card_procedural_artwork.dart';
import '../../widgets/brimstone_button.dart';

/// Helper to calculate global bonus from milestones.
int _getGlobalBonus(List<_Milestone> milestones, int uniqueCreatures) {
  final reached = milestones.where((m) => m.count <= uniqueCreatures).toList();
  if (reached.isEmpty) return 0;
  final totalBonus = reached.fold<double>(0, (sum, m) => sum + m.globalBonus);
  return (totalBonus * 100).toInt();
}

/// Abyssal Codex modal: 3 tabs â€” reaction grimoire, summon/relic gallery,
/// boss annals. Reaction detonation counts come from the codex DB table.
class CodexModal extends ConsumerStatefulWidget {
  const CodexModal({super.key});

  @override
  ConsumerState<CodexModal> createState() => _CodexModalState();
}

class _CodexModalState extends ConsumerState<CodexModal>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reactions = ref.watch(codexReactionsProvider);
    final collection = ref.watch(collectionProvider);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF14090D),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          border: Border.all(
            color: const Color(0xFFB16EFF).withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 6),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text(
                    'CA“DICE ABISAL',
                    style: TextStyle(
                      color: Color(0xFFB16EFF),
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 2,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tab,
              labelColor: const Color(0xFFB16EFF),
              unselectedLabelColor: Colors.white54,
              indicatorColor: const Color(0xFFB16EFF),
              isScrollable: true,
              tabs: const [
                Tab(text: 'GRIMORIO'),
                Tab(text: 'GALERAA'),
                Tab(text: 'ANNALES'),
                Tab(text: 'HITOS'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _ReactionGrimoire(reactions: reactions),
                  _SummonGallery(),
                  _BossAnnals(),
                  _CollectionMilestones(collection: collection),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tab 1: reaction table with detonation counts and quick simulator.
class _ReactionGrimoire extends ConsumerWidget {
  final List<CodexReaction> reactions;

  const _ReactionGrimoire({required this.reactions});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: reactions.length,
      itemBuilder: (context, i) {
        final r = reactions[i];
        return Card(
          color: const Color(0xFF1F1116),
          child: ListTile(
            title: Text(
              r.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.description,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.play_circle_fill,
                      color: Color(0xFFFF5A26),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Detonaciones: ${r.detonations}',
                      style: const TextStyle(
                        color: Color(0xFFFFC93C),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        r.trigger,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.flash_on, color: Color(0xFFB16EFF)),
              onPressed: () {
                ref.read(playerRepositoryProvider).incrementCodexReaction(r.id);
              },
              tooltip: 'Simular detonacion',
            ),
          ),
        );
      },
    );
  }
}

/// Milestone data class for Collection Milestones.
class _Milestone {
  final int count;
  final int shards;
  final double globalBonus;
  final bool claimed;

  const _Milestone({
    required this.count,
    required this.shards,
    required this.globalBonus,
    required this.claimed,
  });
}

/// Milestone tile widget for Collection Milestones.
class _MilestoneTile extends StatelessWidget {
  final _Milestone milestone;
  final int currentCount;
  final VoidCallback onClaim;

  const _MilestoneTile({
    required this.milestone,
    required this.currentCount,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final reached = currentCount >= milestone.count;
    final canClaim = reached && !milestone.claimed;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: canClaim
                ? [
                    const Color(0xFFFFD700).withValues(alpha: 0.2),
                    const Color(0xFFFF5A26).withValues(alpha: 0.1),
                  ]
                : reached
                    ? [
                        const Color(0xFF4FFFA3).withValues(alpha: 0.15),
                        const Color(0xFF0D040A),
                      ]
                    : [
                        const Color(0xFF1A0E14),
                        const Color(0xFF0D040A),
                      ]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: canClaim
              ? const Color(0xFFFFD700)
              : reached
                  ? const Color(0xFF4FFFA3)
                  : Colors.white12,
          width: canClaim ? 2 : 1,
        ),
        boxShadow: canClaim
            ? [
                BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                    blurRadius: 12)
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: canClaim
                      ? [const Color(0xFFFFD700), const Color(0xFFFF5A26)]
                      : reached
                          ? [
                              const Color(0xFF4FFFA3),
                              const Color(0xFF4FFFA3).withValues(alpha: 0.5)
                            ]
                          : [Colors.white24, Colors.white12]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '${milestone.count}',
                style: TextStyle(
                  color: canClaim
                      ? Colors.black
                      : (reached ? Colors.white : Colors.white38),
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reached ? 'HITO DESBLOQUEADO' : 'HITO ${milestone.count}/20',
                  style: TextStyle(
                    color: canClaim
                        ? const Color(0xFFFFD700)
                        : (reached ? const Color(0xFF4FFFA3) : Colors.white54),
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Recompensa: ${milestone.shards} esquirlas +${(milestone.globalBonus * 100).toInt()}% ATK/HP global',
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ],
            ),
          ),
          if (canClaim)
            BrimstoneButton(
              label: 'RECLAMAR',
              icon: Icons.card_giftcard,
              onPressed: onClaim,
              isSecondary: true,
            )
          else if (reached)
            const Icon(Icons.check_circle, color: Color(0xFF4FFFA3), size: 28)
          else
            const Icon(Icons.lock, color: Colors.white24, size: 28),
        ],
      ),
    );
  }
}

/// Block 6: Collection Milestones - rewards for unique creatures collected.
class _CollectionMilestones extends ConsumerWidget {
  final CollectionState collection;

  const _CollectionMilestones({required this.collection});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uniqueCreatures =
        collection.owned.map((c) => c.catalogId).toSet().length;

    final milestones = [
      _Milestone(count: 4, shards: 250, globalBonus: 0.05, claimed: false),
      _Milestone(count: 8, shards: 400, globalBonus: 0.10, claimed: false),
      _Milestone(count: 12, shards: 600, globalBonus: 0.15, claimed: false),
      _Milestone(count: 16, shards: 800, globalBonus: 0.20, claimed: false),
      _Milestone(count: 20, shards: 1000, globalBonus: 0.25, claimed: false),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Progress Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                const Color(0xFF1A0E14),
                const Color(0xFF0D040A),
              ]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.menu_book,
                        color: Color(0xFFFFD700), size: 28),
                    const SizedBox(width: 12),
                    const Text(
                      'ALBUM DE CRIATURAS',
                      style: TextStyle(
                        color: Color(0xFFFFD700),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '$uniqueCreatures / 20 CRIATURAS AšNICAS',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),
                Stack(
                  children: [
                    Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A0008),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: (uniqueCreatures / 20).clamp(0.0, 1.0),
                      child: Container(
                        height: 10,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [
                            Color(0xFFFFD700),
                            Color(0xFFFF5A26),
                          ]),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Row(
                        children: milestones
                            .map((m) => Expanded(
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 2),
                                    child: Center(
                                      child: Container(
                                        width: 4,
                                        height: 14,
                                        decoration: BoxDecoration(
                                          color: uniqueCreatures >= m.count
                                              ? const Color(0xFF4FFFA3)
                                              : Colors.white24,
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                      ),
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Global Bonus Display
          if (uniqueCreatures >= 4)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  const Color(0xFF4FFFA3).withValues(alpha: 0.2),
                  const Color(0xFF4FFFA3).withValues(alpha: 0.05),
                ]),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF4FFFA3).withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bolt, color: Color(0xFF4FFFA3), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'BONO GLOBAL ACTIVO: +${_getGlobalBonus(milestones, uniqueCreatures)}% ATK/HP A TODAS LAS CARTAS',
                      style: const TextStyle(
                        color: Color(0xFF4FFFA3),
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          // Milestones List
          ...milestones.map((m) => _MilestoneTile(
                milestone: m,
                currentCount: uniqueCreatures,
                onClaim: () => _claimMilestone(context, ref, m),
              )),
        ],
      ),
    );
  }

  void _claimMilestone(
      BuildContext context, WidgetRef ref, _Milestone milestone) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '!Hito de ${milestone.count} criaturas reclamado! +${milestone.shards} esquirlas +${(milestone.globalBonus * 100).toInt()}% ATK/HP global'),
        backgroundColor: const Color(0xFF4FFFA3),
      ),
    );
  }
}

/// Tab 2: gallery of 8 cards x 4 star stages + 6 relics.
class _SummonGallery extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cardIds = const [
      'ignis_hound',
      'ignis_lord',
      'abyss_stalker',
      'abyss_leviathan',
      'terra_golem',
      'terra_titan',
      'void_specter',
      'void_malakor',
    ];
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'INVOCACIONES',
            style: TextStyle(
              color: Color(0xFFB16EFF),
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: 1,
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.85,
          ),
          itemCount: cardIds.length,
          itemBuilder: (context, i) {
            final id = cardIds[i];
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var s = 1; s <= 4; s++)
                  SizedBox(
                    height: 60,
                    width: 60,
                    child: CreaturePortrait(cardId: id, stars: s, size: 60),
                  ),
                const SizedBox(height: 4),
                Text(
                  id.replaceAll('_', ' ').toUpperCase(),
                  style: const TextStyle(color: Colors.white54, fontSize: 8),
                  textAlign: TextAlign.center,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'RELIQUIAS ABISALES',
            style: TextStyle(
              color: Color(0xFFB16EFF),
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: 1,
            ),
          ),
        ),
        ...RelicCatalog.all.map(
          (r) => ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            leading: const Icon(
              Icons.diamond,
              color: Color(0xFFFFC93C),
              size: 22,
            ),
            title: Text(
              r.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              r.description,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}

/// Tab 3: boss history, weaknesses, enrage mechanics, kill counts.
class _BossAnnals extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final bosses = const [
      {
        'id': 'pyroth',
        'name': 'Pyroth, Coloso de Ceniza',
        'element': 'Agneo',
        'weakness': 'Agua/Abyssal',
        'enrage': 'Quema 1 ranura de bandeja por 4s (tocar 2A— apaga).',
        'kills': 0,
      },
      {
        'id': 'vaelor',
        'name': 'Vaelor, Senor de la Fosa Helada',
        'element': 'Abyssal',
        'weakness': 'Agneo (rompe escudo de hielo)',
        'enrage':
            'Escuda una diana con hielo (necesita golpe Agneo para romper).',
        'kills': 0,
      },
      {
        'id': 'azathor',
        'name': 'Azathor, Monolito del Vacio',
        'element': 'Vacio',
        'weakness': 'Ninguna conocida',
        'enrage':
            'Invierte rotacion cada 5s + proyectiles dobles de Counter-Flick.',
        'kills': 0,
      },
    ];
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: bosses.length,
      itemBuilder: (context, i) {
        final b = bosses[i];
        return Card(
          color: const Color(0xFF1F1116),
          child: ListTile(
            leading: const Icon(
              Icons.device_hub,
              color: Color(0xFFFF5A26),
              size: 32,
            ),
            title: Text(
              b['name'] as String,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'Elemento: ${b['element']} . Debilidad: ${b['weakness']}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  'Furia: ${b['enrage']}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  'Derrotas: ${b['kills']}',
                  style: const TextStyle(
                    color: Color(0xFFFFC93C),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

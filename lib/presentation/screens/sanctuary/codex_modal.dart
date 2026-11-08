import 'package:flutter/material.dart' hide Element;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/roguelite/relic_catalog.dart';
import '../../controllers/meta_controller.dart';
import '../../combat_engine/card_procedural_artwork.dart';

/// Abyssal Codex modal: 3 tabs — reaction grimoire, summon/relic gallery,
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
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reactions = ref.watch(codexReactionsProvider);
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
                    'CÓDICE ABISAL',
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
              tabs: const [
                Tab(text: 'GRIMORIO'),
                Tab(text: 'GALERÍA'),
                Tab(text: 'ANNALES'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _ReactionGrimoire(reactions: reactions),
                  _SummonGallery(),
                  _BossAnnals(),
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
              tooltip: 'Simular detonación',
            ),
          ),
        );
      },
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
        'element': 'Ígneo',
        'weakness': 'Agua/Abyssal',
        'enrage': 'Quema 1 ranura de bandeja por 4s (tocar 2× apaga).',
        'kills': 0,
      },
      {
        'id': 'vaelor',
        'name': 'Vaelor, Señor de la Fosa Helada',
        'element': 'Abyssal',
        'weakness': 'Ígneo (rompe escudo de hielo)',
        'enrage':
            'Escuda una diana con hielo (necesita golpe Ígneo para romper).',
        'kills': 0,
      },
      {
        'id': 'azathor',
        'name': 'Azathor, Monolito del Vacío',
        'element': 'Vacío',
        'weakness': 'Ninguna conocida',
        'enrage':
            'Invierte rotación cada 5s + proyectiles dobles de Counter-Flick.',
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
                  'Elemento: ${b['element']} · Debilidad: ${b['weakness']}',
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

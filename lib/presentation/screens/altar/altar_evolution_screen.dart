import 'package:flutter/material.dart' hide Element;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/procedural_sfx_engine.dart';
import '../../../domain/entities/owned_card.dart';
import '../../../domain/meta/meta_rules.dart';
import '../../controllers/meta_controller.dart';
import '../meta/widgets.dart';

/// Altar of Evolution: sacrifice a duplicate (same catalogId & stars) plus
/// 250xp gold to ascend a card 1 star, up to the 4-star golden halo.
class AltarEvolutionScreen extends ConsumerStatefulWidget {
  const AltarEvolutionScreen({super.key});

  @override
  ConsumerState<AltarEvolutionScreen> createState() =>
      _AltarEvolutionScreenState();
}

class _AltarEvolutionScreenState extends ConsumerState<AltarEvolutionScreen> {
  int? _selectedId;

  @override
  Widget build(BuildContext context) {
    final collection = ref.watch(collectionProvider);
    final cards = collection.owned;
    OwnedCard? selected;
    for (final c in cards) {
      if (c.instanceId == _selectedId) selected = c;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0C0608),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14090D),
        title: const Text(
          'ALTAR DE EVOLUCIÓN',
          style: TextStyle(
            color: Color(0xFFFFC93C),
            fontWeight: FontWeight.w900,
            fontSize: 15,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: Column(
        children: [
          const CurrencyBar(),
          const SizedBox(height: 4),
          if (selected == null)
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'Selecciona una carta para iniciar el ritual de evolución.',
                style: TextStyle(color: Colors.white24, fontSize: 12),
              ),
            )
          else
            _EvolutionDetail(
              card: selected,
              allCards: cards,
              onEvolved: () => setState(() => _selectedId = null),
            ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.74,
              ),
              itemCount: cards.length,
              itemBuilder: (context, i) {
                final c = cards[i];
                return CardTileSmall(
                  card: c,
                  raised: c.instanceId == _selectedId,
                  onTap: () => setState(() => _selectedId = c.instanceId),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Selected-card ritual panel: header, duplicate/cost status and the CTA.
class _EvolutionDetail extends ConsumerStatefulWidget {
  final OwnedCard card;
  final List<OwnedCard> allCards;
  final VoidCallback onEvolved;

  const _EvolutionDetail({
    required this.card,
    required this.allCards,
    required this.onEvolved,
  });

  @override
  ConsumerState<_EvolutionDetail> createState() => _EvolutionDetailState();
}

class _EvolutionDetailState extends ConsumerState<_EvolutionDetail> {
  List<OwnedCard> get _duplicates => widget.allCards
      .where(
        (c) =>
            c.instanceId != widget.card.instanceId &&
            c.catalogId == widget.card.catalogId &&
            c.stars == widget.card.stars,
      )
      .toList();

  int get _cost => EvolutionRules.costFor(widget.card.stars);

  bool get _canEvolve =>
      widget.card.stars < EvolutionRules.maxStars && _duplicates.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final c = widget.card;
    final ctx = context;
    final messenger = ScaffoldMessenger.of(ctx);
    final card = widget.card;
    final duplicates = _duplicates;
    final cost = _cost;
    final canEvolve = _canEvolve;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              Text(
                card.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var s = 1; s <= EvolutionRules.maxStars; s++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        s <= card.stars ? Icons.star : Icons.star_border,
                        size: 26,
                        color: s <= card.stars
                            ? const Color(0xFFFFC93C)
                            : Colors.white12,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'ATK ${card.baseAttack} · HP ${card.baseHealth}',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            card.stars >= EvolutionRules.maxStars
                ? 'Esta carta ya alcanzó su forma final de 4★.'
                : duplicates.isEmpty
                    ? 'Necesitas otro duplicado de ${card.name} a ${card.stars}★ como sacrificio.'
                    : 'Sacrificio: ${duplicates.length} duplicado(s) a ${card.stars}★ · Coste: $cost oro',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor:
                  canEvolve ? const Color(0xFFFFC93C) : Colors.white24,
              foregroundColor:
                  canEvolve ? const Color(0xFF14090D) : Colors.white54,
              minimumSize: const Size.fromHeight(52),
            ),
            icon: const Icon(Icons.auto_fix_high),
            label: Text(
              canEvolve
                  ? 'EVOLUCIONAR A ${card.stars + 1}★ — $cost ORO'
                  : 'EVOLUCIÓN BLOQUEADA',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            onPressed: canEvolve
                ? () async {
                    final ok = await ref
                        .read(collectionProvider.notifier)
                        .evolve(c.instanceId);
                    if (!mounted) return;
                    if (ok) {
                      ProceduralSfxEngine.playEvolutionSuccess();
                      ref.read(bountyProvider.notifier).increment('evolution');
                    } else {
                      ProceduralSfxEngine.playEvolutionFail();
                    }
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? '¡${c.name} asciende a ${c.stars + 1}★!'
                              : 'Ritual fallido: faltan duplicados u oro.',
                        ),
                      ),
                    );
                    widget.onEvolved();
                  }
                : null,
          ),
        ),
      ],
    );
  }
}

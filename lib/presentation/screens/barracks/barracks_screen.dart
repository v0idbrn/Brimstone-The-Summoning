import 'package:flutter/material.dart' hide Element;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/owned_card.dart';
import '../../../domain/value_objects/element.dart';
import '../../controllers/meta_controller.dart';
import '../meta/widgets.dart';

/// Barracks: build the active 4-card squad, filter the collection, inspect
/// cards and level them up with gold.
class BarracksScreen extends ConsumerStatefulWidget {
  const BarracksScreen({super.key});

  @override
  ConsumerState<BarracksScreen> createState() => _BarracksScreenState();
}

class _BarracksScreenState extends ConsumerState<BarracksScreen> {
  Element? _filterElement;
  int? _filterStars;

  @override
  Widget build(BuildContext context) {
    final collection = ref.watch(collectionProvider);
    final cards = collection.owned.where(_matchesFilter).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0C0608),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14090D),
        title: const Text(
          'CUARTEL',
          style: TextStyle(
            color: Color(0xFFB16EFF),
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
          // Squad slots (tap to remove).
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                for (var slot = 0; slot < 4; slot++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: slot == 3 ? 0 : 6),
                      child: _squadSlot(collection, slot),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Filters.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  children: [
                    FilterChip(
                      label: const Text('Ígneo'),
                      selected: _filterElement == Element.igneous,
                      onSelected: (_) => setState(
                        () => _filterElement = _filterElement == Element.igneous
                            ? null
                            : Element.igneous,
                      ),
                    ),
                    FilterChip(
                      label: const Text('Abisal'),
                      selected: _filterElement == Element.abyssal,
                      onSelected: (_) => setState(
                        () => _filterElement = _filterElement == Element.abyssal
                            ? null
                            : Element.abyssal,
                      ),
                    ),
                    FilterChip(
                      label: const Text('Telúrico'),
                      selected: _filterElement == Element.telluric,
                      onSelected: (_) => setState(
                        () =>
                            _filterElement = _filterElement == Element.telluric
                            ? null
                            : Element.telluric,
                      ),
                    ),
                    FilterChip(
                      label: const Text('Vacío'),
                      selected: _filterElement == Element.empty,
                      onSelected: (_) => setState(
                        () => _filterElement = _filterElement == Element.empty
                            ? null
                            : Element.empty,
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final stars in [1, 2, 3, 4])
                      FilterChip(
                        label: Text('★' * stars),
                        selected: _filterStars == stars,
                        onSelected: (_) => setState(
                          () => _filterStars = _filterStars == stars
                              ? null
                              : stars,
                        ),
                      ),
                    if (_filterElement != null || _filterStars != null)
                      TextButton(
                        onPressed: () => setState(() {
                          _filterElement = null;
                          _filterStars = null;
                        }),
                        child: const Text('Limpiar'),
                      ),
                  ],
                ),
              ],
            ),
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
              itemBuilder: (context, i) => CardTileSmall(
                card: cards[i],
                onTap: () => _showInspector(context, cards[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _matchesFilter(OwnedCard c) {
    if (_filterElement != null && c.element != _filterElement) return false;
    if (_filterStars != null && c.stars != _filterStars) return false;
    return true;
  }

  Widget _squadSlot(CollectionState collection, int slot) {
    final id = slot < collection.squad.length ? collection.squad[slot] : null;
    final card = id == null
        ? null
        : collection.owned.where((c) => c.instanceId == id).firstOrNullWhere();
    if (card == null) {
      return Container(
        height: 78,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: const Center(
          child: Text(
            'Vacío',
            style: TextStyle(color: Colors.white24, fontSize: 10),
          ),
        ),
      );
    }
    return CardTileSmall(
      card: card,
      onTap: () => ref.read(collectionProvider.notifier).unequip(slot),
    );
  }

  void _showInspector(BuildContext context, OwnedCard card) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => CardInspectorModal(card: card),
    );
  }
}

extension FirstOrNullWhere on Iterable<OwnedCard> {
  OwnedCard? firstOrNullWhere() => isEmpty ? null : first;
}

/// Card detail: effective stats, level-up cost and equip action.
class CardInspectorModal extends ConsumerWidget {
  final OwnedCard card;

  const CardInspectorModal({super.key, required this.card});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collection = ref.watch(collectionProvider);
    final live = collection.owned.firstWhere(
      (c) => c.instanceId == card.instanceId,
      orElse: () => card,
    );
    final cost = live.level * 100;
    final inSquad = collection.squad.contains(live.instanceId);
    final canEquip = !inSquad && collection.squad.length < 4;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF14090D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (var s = 0; s < live.stars; s++)
                const Icon(Icons.star, size: 16, color: Color(0xFFFFC93C)),
              const Spacer(),
              Text(
                'Nivel ${live.level}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            live.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ATK ${live.baseAttack} · HP ${live.baseHealth} · Maná ${live.baseManaCost} · ${live.rarity.name}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 16),
          if (canEquip)
            FilledButton.tonal(
              onPressed: () async {
                final ok = await ref
                    .read(collectionProvider.notifier)
                    .equip(live.instanceId);
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ok ? 'Carta equipada al escuadrón' : 'No se puede equipar: dupllicado o escuadrón lleno',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Equipar al escuadrón'),
            ),
          if (inSquad)
            FilledButton.tonal(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Ya está equipada'),
            ),
          const SizedBox(height: 8),
          FilledButton.icon(
            icon: const Icon(Icons.trending_up, size: 16),
            label: Text('Subir de nivel — $cost oro (+10% ATK/HP)'),
            onPressed: () async {
              final result = await ref
                  .read(collectionProvider.notifier)
                  .levelUp(live.instanceId);
              if (context.mounted) {
                if (result == -1) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Oro insuficiente')),
                  );
                } else {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Carta subida a Nivel ${live.level + 1}'),
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}

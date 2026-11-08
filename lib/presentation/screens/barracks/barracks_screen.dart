import 'package:flutter/material.dart' hide Element;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/combat/combat_models.dart';
import '../../../domain/entities/owned_card.dart';
import '../../../domain/meta/rune_system.dart';
import '../../../domain/meta/squad_synergy_resolver.dart';
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
          // Sinergia activa del escuadrón (banner en vivo).
          _synergyBanner(collection),
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
                        () => _filterElement =
                            _filterElement == Element.telluric
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
                          () => _filterStars =
                              _filterStars == stars ? null : stars,
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

  /// Banner de sinergia activo basado en las 4 cartas del escuadrón actual.
  Widget _synergyBanner(CollectionState collection) {
    final squad = <ManaCard>[];
    for (final id in collection.squad.take(4)) {
      final c = collection.owned.firstWhere(
        (card) => card.instanceId == id,
        orElse: () => throw StateError('card $id not found'),
      );
      squad.add(
        ManaCard(
          id: c.catalogId,
          name: c.name,
          element: c.element,
          baseManaCost: c.baseManaCost,
          attack: c.baseAttack.toDouble(),
          stars: c.stars,
        ),
      );
    }
    final synergy = SquadSynergyResolver.resolve(squad);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0E14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: synergy.isActive ? const Color(0xFFB16EFF) : Colors.white12,
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            synergy.isActive ? Icons.auto_awesome : Icons.close,
            color: synergy.isActive ? const Color(0xFFB16EFF) : Colors.white38,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  synergy.name,
                  style: TextStyle(
                    color: synergy.isActive ? Colors.white : Colors.white54,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                Text(
                  synergy.description,
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 10, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CardTileSmall(
          card: card,
          onTap: () => ref.read(collectionProvider.notifier).unequip(slot),
        ),
        if (slot == 0)
          Positioned(
            top: -8,
            left: -8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFFC93C),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'LÍDER',
                style: TextStyle(
                  color: Color(0xFF0C0608),
                  fontWeight: FontWeight.w900,
                  fontSize: 8,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
      ],
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

/// Sección interactiva de forja y equipamiento de runas para una carta propia.
class _RuneForgeSection extends ConsumerStatefulWidget {
  final OwnedCard card;
  const _RuneForgeSection({required this.card});

  @override
  ConsumerState<_RuneForgeSection> createState() => _RuneForgeSectionState();
}

class _RuneForgeSectionState extends ConsumerState<_RuneForgeSection> {
  RuneType? _selectedType;
  RuneInstance? _current;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rune = await ref
        .read(playerRepositoryProvider)
        .loadCardRune(widget.card.instanceId);
    if (!mounted) return;
    setState(() {
      _current = rune;
      _selectedType = rune?.type;
    });
  }

  String _runeIcon(RuneType t) => switch (t) {
        RuneType.crimsonFury => '⚔️',
        RuneType.eternalFlow => '🌊',
        RuneType.voidLeech => '💧',
        RuneType.twinEcho => '🔊',
      };

  Future<void> _forgeOrChange() async {
    final type = _selectedType;
    if (type == null) return;
    final repo = ref.read(playerRepositoryProvider);
    final gold = 150;
    final shards = 50;
    final ok = await ref
        .read(profileProvider.notifier)
        .spend(gold: gold, shards: shards);
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Oro o esquirlas insuficientes')),
        );
      }
      return;
    }
    await repo.saveCardRune(
      widget.card.instanceId,
      RuneInstance(type: type, level: 1),
    );
    if (!mounted) return;
    final forged = RuneInstance(type: type, level: 1);
    setState(() => _current = forged);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Runa ${RuneSystem.displayName(type)} forjada Nv.1'),
      ),
    );
  }

  Future<void> _upgrade() async {
    final current = _current;
    if (current == null || current.isMaxLevel) return;
    final repo = ref.read(playerRepositoryProvider);
    final cost = 200 * current.level;
    final ok = await ref.read(profileProvider.notifier).spend(gold: cost);
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Oro insuficiente para mejorar')),
        );
      }
      return;
    }
    await repo.saveCardRune(
      widget.card.instanceId,
      current.copyWith(level: current.level + 1),
    );
    if (!mounted) return;
    setState(() => _current = current.copyWith(level: current.level + 1));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Runa mejorada a Nivel ${current.level + 1}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final equipped = _current;
    final hasRune = equipped != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0E14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasRune ? const Color(0xFFB16EFF) : Colors.white24,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome,
                  size: 16, color: Color(0xFFB16EFF)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  hasRune
                      ? '${_runeIcon(equipped.type)} ${RuneSystem.displayName(equipped.type)} — Nivel ${equipped.level}'
                      : 'Sin runa equipada',
                  style: TextStyle(
                    color: hasRune ? Colors.white : Colors.white54,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (hasRune) ...[
            Text(
              RuneSystem.description(equipped.type, equipped.level),
              style: const TextStyle(
                  color: Colors.white70, fontSize: 11, height: 1.3),
            ),
            const SizedBox(height: 8),
          ],
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: RuneType.values.map((t) {
              final chosen = _selectedType == t;
              final alreadyEquipped = hasRune && equipped.type == t;
              return ChoiceChip(
                label: Text(
                  '${_runeIcon(t)} ${RuneSystem.displayName(t)}',
                  style: TextStyle(
                    color:
                        alreadyEquipped ? Colors.greenAccent : Colors.white70,
                    fontSize: 10,
                  ),
                ),
                selected: chosen || alreadyEquipped,
                onSelected: (_) => setState(() => _selectedType = t),
                backgroundColor: const Color(0xFF0C0608),
                selectedColor: const Color(0xFF1A0E14),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (hasRune && !equipped.isMaxLevel)
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: _upgrade,
                    child: Text(
                        'Mejorar a Nv.${equipped.level + 1} — ${200 * equipped.level} oro'),
                  ),
                )
              else if (!hasRune)
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: _selectedType == null ? null : _forgeOrChange,
                    child: const Text('Forjar Runa — 150 oro + 50 esq.'),
                  ),
                )
              else
                const Expanded(child: Text('Runa al nivel máximo')),
            ],
          ),
          if (hasRune)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Quitar'),
                onPressed: () async {
                  await ref
                      .read(playerRepositoryProvider)
                      .removeCardRune(widget.card.instanceId);
                  if (!context.mounted) return;
                  setState(() => _current = null);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Runa removida')),
                  );
                },
              ),
            ),
        ],
      ),
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
                        ok
                            ? 'Carta equipada al escuadrón'
                            : 'No se puede equipar: dupllicado o escuadrón lleno',
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
          const SizedBox(height: 16),
          // ================= Forja de Runas Abisales =================
          const Text(
            'RUNAS ABIASALES',
            style: TextStyle(
              color: Color(0xFFB16EFF),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          _RuneForgeSection(card: live),
        ],
      ),
    );
  }
}

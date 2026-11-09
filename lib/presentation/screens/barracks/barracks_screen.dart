import 'package:flutter/material.dart' hide Element;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/combat/combat_models.dart';
import '../../../domain/entities/owned_card.dart';
import '../../../domain/meta/rune_system.dart';
import '../../../domain/meta/squad_synergy_resolver.dart';
import '../../../domain/value_objects/element.dart';
import '../../controllers/meta_controller.dart';
import '../../widgets/brimstone_button.dart';
import '../../widgets/tcg_card_widget.dart';
import '../meta/widgets.dart';
import '../training/training_arena_screen.dart';

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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(deckPresetProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final collection = ref.watch(collectionProvider);
    final cards = collection.owned.where(_matchesFilter).toList();
    final deckPresets = ref.watch(deckPresetProvider);

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
        actions: [
          IconButton(
            icon: const Icon(Icons.fitness_center, color: Color(0xFF3FD8FF)),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TrainingArenaScreen()),
            ),
            tooltip: 'Arena de Entrenamiento (Prueba Mazo)',
          ),
        ],
      ),
      body: Column(
        children: [
          const CurrencyBar(),
          const SizedBox(height: 4),
          // Deck Preset Selector + Auto-Arm
          _buildDeckPresetSelector(deckPresets, collection),
          const SizedBox(height: 8),
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

  Widget _buildDeckPresetSelector(
      DeckPresetState presetsState, CollectionState collection) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MAZOS GUARDADOS',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 10,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              // Preset buttons (Mazo I, II, III)
              for (var i = 0; i < 3; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i == 2 ? 0 : 4),
                    child: _PresetButton(
                      index: i,
                      name: [
                        'Mazo I: Ígneo',
                        'Mazo II: Abisal',
                        'Mazo III: Táctico'
                      ][i],
                      isActive: presetsState.activePresetIndex == i,
                      hasPreset: i < presetsState.presets.length,
                      onTap: () =>
                          ref.read(deckPresetProvider.notifier).loadPreset(i),
                      onLongPress: () => ref
                          .read(deckPresetProvider.notifier)
                          .savePreset(i, collection.squad),
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              // Auto-arm button
              _AutoArmButton(
                onPressed: () =>
                    ref.read(deckPresetProvider.notifier).autoArmBest(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Toca para cargar · Mantén para guardar · ⚡ Auto-armar mejor mazo',
            style: TextStyle(color: Colors.white24, fontSize: 9),
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

/// Preset button for saved deck (tap to load, long-press to save).
class _PresetButton extends StatelessWidget {
  final int index;
  final String name;
  final bool isActive;
  final bool hasPreset;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _PresetButton({
    required this.index,
    required this.name,
    required this.isActive,
    required this.hasPreset,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFFFF5A26), // Ígneo
      const Color(0xFF3FD8FF), // Abisal
      const Color(0xFF4FFFA3), // Telúrico
    ];
    final color = colors[index];

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(colors: [
                  color.withValues(alpha: 0.9),
                  color.withValues(alpha: 0.7),
                ])
              : hasPreset
                  ? LinearGradient(colors: [
                      color.withValues(alpha: 0.3),
                      color.withValues(alpha: 0.15),
                    ])
                  : LinearGradient(colors: [
                      const Color(0xFF1A0E14),
                      const Color(0xFF0C0608),
                    ]),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? color
                : hasPreset
                    ? color.withValues(alpha: 0.5)
                    : Colors.white12,
            width: isActive ? 2 : 1.2,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 8,
                      spreadRadius: 1)
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name.split(': ')[1],
              style: TextStyle(
                color: isActive
                    ? Colors.black
                    : (hasPreset ? color : Colors.white54),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              hasPreset ? '✓ Guardado' : 'Vacío',
              style: TextStyle(
                color: isActive
                    ? Colors.black54
                    : (hasPreset
                        ? color.withValues(alpha: 0.7)
                        : Colors.white24),
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Auto-arm button that selects the best 4 cards by ATK * stars.
class _AutoArmButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _AutoArmButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon:
            const Icon(Icons.auto_fix_high, size: 16, color: Color(0xFFB16EFF)),
        label: const Text(
          'AUTO',
          style: TextStyle(
            color: Color(0xFFB16EFF),
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          minimumSize: const Size(0, 44),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          side: const BorderSide(color: Color(0xFFB16EFF), width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}

extension FirstOrNullWhere on Iterable<OwnedCard> {
  OwnedCard? firstOrNullWhere() => isEmpty ? null : first;
}

/// Skill Level Upgrade Section (Block 1: Maestría de Criaturas).
class _SkillUpgradeSection extends ConsumerWidget {
  final OwnedCard card;

  const _SkillUpgradeSection({required this.card});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canUpgrade = card.skillLevel < 5;
    final goldCost = 200 * card.skillLevel;
    final shardsCost = 40 * card.skillLevel;
    final isAwakened = card.skillLevel >= 5 || card.masteryRank >= 5;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0E14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAwakened
              ? const Color(0xFFFFD700)
              : canUpgrade
                  ? const Color(0xFFB16EFF)
                  : Colors.white24,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                isAwakened ? Icons.star : Icons.bolt,
                size: 16,
                color: isAwakened
                    ? const Color(0xFFFFD700)
                    : const Color(0xFFB16EFF),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isAwakened
                      ? '★ DESPERTAR ABISAL ACTIVO ★'
                      : 'MEJORAR HABILIDAD (Nv.${card.skillLevel} → Nv.${card.skillLevel + 1})',
                  style: TextStyle(
                    color: isAwakened ? const Color(0xFFFFD700) : Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (isAwakened)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [
                      Color(0xFFFFD700),
                      Color(0xFFFF5A26),
                    ]),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'AWAKENED',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isAwakened
                ? 'Al invocarse en combate: genera 1 esfera Nv.2 de ${_elementDisplayName(card.element)} + 5% HP escudo/curación.'
                : 'Efecto: +15% daño/efecto habilidad  •  Costo maná: -4  •  Costo: $goldCost oro + $shardsCost esquirlas',
            style: const TextStyle(
                color: Colors.white70, fontSize: 10, height: 1.3),
          ),
          const SizedBox(height: 8),
          if (canUpgrade)
            BrimstoneButton(
              label:
                  'MEJORAR HABILIDAD — $goldCost ORO + $shardsCost ESQUIRLAS',
              icon: Icons.upgrade,
              onPressed: () async {
                final repo = ref.read(playerRepositoryProvider);
                final profile = await repo.loadProfile();
                if (profile[0] < goldCost || profile[1] < shardsCost) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Oro o esquirlas insuficientes')),
                    );
                  }
                  return;
                }
                await repo.spend(gold: goldCost, shards: shardsCost);
                await repo.updateOwnedCard(
                  card.copyWith(skillLevel: card.skillLevel + 1),
                );
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isAwakened || card.skillLevel + 1 >= 5
                            ? '¡DESPERTAR ABISAL DESBLOQUEADO!'
                            : 'Habilidad mejorada a Nivel ${card.skillLevel + 1}',
                      ),
                      backgroundColor: const Color(0xFF4FFFA3),
                    ),
                  );
                }
              },
            )
          else if (!isAwakened)
            const Center(
              child: Text(
                'Nivel máximo de habilidad alcanzado',
                style: TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ),
        ],
      ),
    );
  }

  String _elementDisplayName(Element e) => switch (e) {
        Element.igneous => 'Ígneo',
        Element.abyssal => 'Abisal',
        Element.telluric => 'Telúrico',
        Element.empty => 'Vacío',
      };
}

/// Card detail: effective stats, level-up cost, rune forge, dismantle and equip action.
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
    // Debe conservar al menos 4 cartas después de la operación.
    final canDisenchant = !inSquad && collection.owned.length > 4;

    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF14090D),
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Center large TcgCardWidget preview
            Center(
              child: SizedBox(
                width: 140,
                height: 194,
                child: TcgCardWidget.fromOwnedCard(
                  card: live,
                  raised: true,
                ),
              ),
            ),
            const SizedBox(height: 14),

            Text(
              live.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),

            // Stat pills: ATK, HP, MANA, RARITY
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _statBadge(
                    'ATK', '${live.baseAttack}', const Color(0xFFFF5A26)),
                const SizedBox(width: 8),
                _statBadge('HP', '${live.baseHealth}', const Color(0xFF4FFFA3)),
                const SizedBox(width: 8),
                _statBadge(
                    'MANÁ', '${live.baseManaCost}', const Color(0xFF3FD8FF)),
                const SizedBox(width: 8),
                _statBadge(
                    'ESTRELLAS', '${live.stars}★', const Color(0xFFFFD700)),
              ],
            ),
            const SizedBox(height: 14),

            // Skill descriptions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E0E16),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.bolt, size: 14, color: Color(0xFFFFD700)),
                      SizedBox(width: 4),
                      Text(
                        'HABILIDAD ACTIVA',
                        style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Inflige ${live.baseAttack * 2} de daño directo al impactar la diana dimensional y purga 1 proyectil.',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: const [
                      Icon(Icons.military_tech,
                          size: 14, color: Color(0xFFFF5A26)),
                      SizedBox(width: 4),
                      Text(
                        'HABILIDAD DE LÍDER (Slot 0)',
                        style: TextStyle(
                          color: Color(0xFFFF5A26),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Otorga +15% de daño elemental y +10% de velocidad de generación de maná.',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Equip / Squad state
            if (canEquip)
              BrimstoneButton(
                label: 'EQUIPAR AL ESCUADRÓN',
                icon: Icons.add_moderator,
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
                              : 'No se puede equipar: duplicado o escuadrón lleno',
                        ),
                      ),
                    );
                  }
                },
              ),
            if (inSquad)
              const Center(
                child: Text(
                  '✓ Carta equipada en el escuadrón activo',
                  style: TextStyle(
                    color: Color(0xFF4FFFA3),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(height: 10),

            // Level Up button
            BrimstoneButton(
              label:
                  'SUBIR NIVEL (Nv.${live.level + 1}) — $cost ORO (+10% ATK/HP)',
              icon: Icons.trending_up,
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
            const SizedBox(height: 10),

            // Skill Level Upgrade (Block 1: Maestría de Criaturas)
            _SkillUpgradeSection(card: live),
            const SizedBox(height: 10),

            // Desmantelar Copia
            BrimstoneButton(
              isSecondary: true,
              label: canDisenchant
                  ? 'DESMANTELAR (+${50 * live.stars} esq. / +${150 * live.stars} oro)'
                  : 'DESMANTELAR COPIA (BLOQUEADO)',
              icon: Icons.delete_forever,
              onPressed: canDisenchant
                  ? () async {
                      final repo = ref.read(playerRepositoryProvider);
                      final rewards =
                          await repo.disenchantCopy(live.instanceId);
                      if (rewards == null) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'No puedes desmantelar: el escuadrón debe conservar '
                                'al menos 4 cartas.',
                              ),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                        return;
                      }
                      await ref.read(profileProvider.notifier).load();
                      await ref.read(collectionProvider.notifier).load();
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Desmantelado: +${rewards['shards']} esquirlas, '
                              '+${rewards['gold']} oro',
                            ),
                            backgroundColor: const Color(0xFF4FFFA3),
                          ),
                        );
                      }
                    }
                  : null,
            ),
            const SizedBox(height: 16),

            // Forja de Runas Abisales
            const Text(
              'FORJA DE RUNAS ABISALES',
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
      ),
    );
  }

  static Widget _statBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E0E16),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
                color: color, fontSize: 8, fontWeight: FontWeight.bold),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

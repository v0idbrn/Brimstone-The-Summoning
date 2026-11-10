import 'dart:math' as math;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/procedural_sfx_engine.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../domain/combat/combat_engine.dart';
import '../../../domain/combat/combat_models.dart';
import '../../../domain/meta/elemental_chambers.dart';
import '../../../domain/meta/rune_system.dart';
import '../../../domain/value_objects/element.dart';
import '../../controllers/meta_controller.dart';
import '../../graphics/painted_backdrop.dart';
import '../../graphics/art_registry.dart';
import '../../widgets/gothic_modal_frame.dart';
import '../combat/combat_screen.dart';

/// Las Cuatro Cámaras Elementales — daily forge dungeons.
///
/// Each chamber runs at Normal / Pesadilla / Infierno. A squad that brings the
/// chamber's opposite element doubles the haul (×2 esencias, oro y maestría);
/// mastery is tripled on every clear and runes can drop directly.
class ElementalChambersScreen extends ConsumerStatefulWidget {
  const ElementalChambersScreen({super.key});

  @override
  ConsumerState<ElementalChambersScreen> createState() =>
      _ElementalChambersScreenState();
}

class _ElementalChambersScreenState
    extends ConsumerState<ElementalChambersScreen> {
  Map<String, ChamberClear> _clears = const {};
  Map<String, int> _essences = const {};
  Map<String, int> _talents = const {};
  Map<String, int> _gear = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final repo = ref.read(playerRepositoryProvider);
    final clears = await repo.loadChamberClears();
    final essences = await repo.loadEssences();
    final talents = await repo.loadTalentLevels();
    final gear = await repo.loadGearLevels();
    await ref.read(collectionProvider.notifier).load();
    if (!mounted) return;
    setState(() {
      _clears = clears;
      _essences = essences;
      _talents = talents;
      _gear = gear;
      _loading = false;
    });
  }

  List<ManaCard> _squadCards() {
    final state = ref.read(collectionProvider);
    final byId = {for (final c in state.owned) c.instanceId: c};
    final cards = <ManaCard>[];
    for (final id in state.squad.take(4)) {
      final owned = byId[id];
      if (owned == null) continue;
      cards.add(
        ManaCard(
          id: owned.catalogId,
          name: owned.name,
          element: owned.element,
          baseManaCost: owned.baseManaCost,
          attack: owned.baseAttack.toDouble(),
          stars: owned.stars,
          skillLevel: owned.skillLevel,
          masteryRank: owned.masteryRank,
        ),
      );
    }
    return cards;
  }

  bool _hasFavouredCard(ElementalChamber chamber) {
    final state = ref.read(collectionProvider);
    final byId = {for (final c in state.owned) c.instanceId: c};
    for (final id in state.squad) {
      final card = byId[id];
      if (card != null && card.element == chamber.favoured) return true;
    }
    return false;
  }

  Future<void> _enter(
    ElementalChamber chamber,
    ChamberDifficulty difficulty,
  ) async {
    ProceduralSfxEngine.playUIHeavyClick();
    final squad = _squadCards();
    if (squad.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Necesitás un escuadrón equipado.')),
      );
      return;
    }
    final bonus = _hasFavouredCard(chamber);
    final guardian = BossConfig(
      id: 'chamber_${chamber.id}_${difficulty.name}',
      name: 'Guardián de la ${chamber.name.split(' ').last}',
      element: chamber.element,
      maxHp: ChamberRules.bossHpFor(difficulty: difficulty, chapterHp: 620),
      attackInterval: 5.4 - difficulty.index * 0.6,
      attackDamage: 13 + difficulty.index * 6,
      projectilesPerAttack: 2 + difficulty.index,
      shieldHp: (ChamberRules.bossHpFor(
                difficulty: difficulty,
                chapterHp: 620,
              ) *
              0.20)
          .roundToDouble(),
      threatDialog: chamber.tagline,
      furyDialog: '¡LA FORJA DEVORA A LOS DÉBILES!',
    );
    final engine = CombatEngine(
      boss: guardian,
      cards: squad,
      playerMaxHp: 110,
      playerDamageMult: bonus
          ? ChamberRules.elementBonus(
              squadElement: chamber.favoured,
              chamberElement: chamber.element,
            )
          : 1.0,
      talentLevels: _talents,
      summonerGear: _gear,
    );
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CombatScreen(
          engine: engine,
          onCombatResolved: (victory, _) async {
            if (!victory) return;
            await _grant(chamber, difficulty, oppositeBonus: bonus);
          },
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _grant(
    ElementalChamber chamber,
    ChamberDifficulty difficulty, {
    required bool oppositeBonus,
  }) async {
    final repo = ref.read(playerRepositoryProvider);
    final rewards = ChamberRules.rewardsFor(
      chamber: chamber,
      difficulty: difficulty,
      oppositeBonus: oppositeBonus,
    );
    final first = await repo.recordChamberClear(chamber, difficulty);
    await repo.addEssence(chamber.element, rewards.essences);
    await ref
        .read(profileProvider.notifier)
        .grant(gold: rewards.gold, shards: first ? 120 : 0);
    // ×3 maestría para las cartas equipadas (una pasada por carta).
    final squad = ref.read(collectionProvider).squad;
    for (final instanceId in squad) {
      await repo.addMasteryXp(instanceId, rewards.masteryXp);
    }
    var runeDropped = false;
    if (math.Random().nextDouble() < rewards.runeChance) {
      final rune =
          RuneType.values[math.Random().nextInt(RuneType.values.length)];
      await repo.addRuneToProfile(rune);
      runeDropped = true;
    }
    await ref.read(collectionProvider.notifier).load();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => GothicModalFrame(
        title: 'CÁMARA PURIFICADA',
        subtitle: '${chamber.name} · ${difficulty.label}'
            '${first ? ' · PRIMERA VICTORIA' : ''}',
        icon: Icons.local_fire_department,
        accent: const Color(0xFFFFC93C),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'CONTINUAR',
              style: BrimstoneFonts.cinzel(
                size: 11,
                weight: FontWeight.w800,
                color: BrimstoneTokens.goldPrimary,
              ),
            ),
          ),
        ],
        children: [
          Text(
            '+${rewards.essences} esencias de ${chamber.element.name.toUpperCase()}'
            '  ·  +${rewards.gold} oro\n'
            '+${rewards.masteryXp} XP de maestría por carta equipada'
            '${oppositeBonus ? '\nBONO x2 por elemento opuesto' : ''}'
            '${runeDropped ? '\n¡Runa de forja obtenida!' : ''}',
            style: BrimstoneFonts.sans(
              size: 12,
              color: BrimstoneTokens.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07050A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14090D),
        title: Text(
          'CÁMARAS ELEMENTALES',
          style: BrimstoneFonts.cinzel(
            size: 14,
            weight: FontWeight.w900,
            color: const Color(0xFFFFC93C),
            letterSpacing: 1.6,
          ),
        ),
      ),
      body: PaintedBackdrop(
        asset: ArtRegistry.metaScenes['altar']!,
        tint: const Color(0xFFFFC93C),
        darkness: 0.8,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFFFC93C)),
              )
            : ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  Text(
                    'CALABOZOS DE FORJA',
                    style: BrimstoneTypography.labelXS,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Cada cámara entrega esencias de su elemento, oro masivo y '
                    'maestría ×3. Llevar el elemento opuesto duplica el botín.',
                    style: BrimstoneFonts.sans(
                      size: 10,
                      color: Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final chamber in ElementalChambers.all) ...[
                    _ChamberCard(
                      chamber: chamber,
                      clears: _clears,
                      essences: _essences[chamber.element.name] ?? 0,
                      favoured: _hasFavouredCard(chamber),
                      onEnter: (difficulty) => _enter(chamber, difficulty),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
      ),
    );
  }
}

class _ChamberCard extends StatelessWidget {
  const _ChamberCard({
    required this.chamber,
    required this.clears,
    required this.essences,
    required this.favoured,
    required this.onEnter,
  });

  final ElementalChamber chamber;
  final Map<String, ChamberClear> clears;
  final int essences;
  final bool favoured;
  final ValueChanged<ChamberDifficulty> onEnter;

  Color get _color => switch (chamber.element) {
        Element.igneous => const Color(0xFFFF5A26),
        Element.abyssal => const Color(0xFF3FD8FF),
        Element.telluric => const Color(0xFFB0703B),
        Element.empty => const Color(0xFFB16EFF),
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _color.withValues(alpha: 0.16),
            const Color(0xFF07050A),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _color.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                switch (chamber.element) {
                  Element.igneous => Icons.local_fire_department,
                  Element.abyssal => Icons.water_drop,
                  Element.telluric => Icons.shield,
                  Element.empty => Icons.auto_awesome,
                },
                color: _color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  chamber.name.toUpperCase(),
                  style: BrimstoneFonts.cinzel(
                    size: 12,
                    weight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                '$essences ESENCIAS',
                style: BrimstoneFonts.sans(
                  size: 9,
                  color: _color,
                  weight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            chamber.tagline,
            style: BrimstoneFonts.sans(size: 10, color: Colors.white60),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                favoured ? Icons.check_circle : Icons.info_outline,
                size: 12,
                color: favoured ? const Color(0xFF4FFFA3) : Colors.white38,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  favoured
                      ? 'BONO ×2 ACTIVO · ${chamber.favoured.name.toUpperCase()} EN EL MAZO'
                      : 'BONO ×2 con el elemento ${chamber.favoured.name.toUpperCase()}',
                  style: BrimstoneFonts.sans(
                    size: 9,
                    color: favoured ? const Color(0xFF4FFFA3) : Colors.white38,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final difficulty in ChamberDifficulty.values) ...[
                Expanded(
                  child: _DifficultyButton(
                    difficulty: difficulty,
                    color: _color,
                    cleared: clears.containsKey(
                      ChamberRules.clearKey(chamber, difficulty),
                    ),
                    onTap: () => onEnter(difficulty),
                  ),
                ),
                if (difficulty != ChamberDifficulty.values.last)
                  const SizedBox(width: 6),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DifficultyButton extends StatelessWidget {
  const _DifficultyButton({
    required this.difficulty,
    required this.color,
    required this.cleared,
    required this.onTap,
  });

  final ChamberDifficulty difficulty;
  final Color color;
  final bool cleared;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: difficulty.isNightmarePlus
              ? color.withValues(alpha: 0.22)
              : const Color(0xFF120C10),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.55)),
        ),
        child: Column(
          children: [
            Text(
              difficulty.label,
              style: BrimstoneFonts.cinzel(
                size: 8.5,
                weight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.8,
              ),
            ),
            Text(
              cleared
                  ? 'SUPERADA'
                  : '×${difficulty.rewardScale.toStringAsFixed(1)}',
              style: BrimstoneFonts.sans(
                size: 8,
                color: cleared ? const Color(0xFF4FFFA3) : Colors.white54,
                weight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

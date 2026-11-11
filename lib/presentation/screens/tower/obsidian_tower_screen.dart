import 'package:flutter/material.dart' hide Element;
import 'package:flutter_riverpod/flutter_riverpod.dart';

// import 'package:brimstone_summoning/core/audio/procedural_sfx_engine.dart';
// import 'package:brimstone_summoning/domain/campaign/campaign_chapters.dart';
// import 'package:brimstone_summoning/domain/combat/combat_engine.dart';
import 'package:brimstone_summoning/domain/combat/combat_models.dart';
import 'package:brimstone_summoning/presentation/screens/combat/combat_screen.dart';
import 'package:brimstone_summoning/domain/meta/obsidian_tower.dart';
import 'package:brimstone_summoning/domain/meta/rune_system.dart';
import 'package:brimstone_summoning/domain/meta/squad_synergy_resolver.dart';
import 'package:brimstone_summoning/domain/value_objects/element.dart';
import 'package:brimstone_summoning/presentation/controllers/meta_controller.dart';
import 'package:brimstone_summoning/presentation/utils/element_ui.dart';
import 'package:brimstone_summoning/presentation/widgets/brimstone_button.dart';

/// Pantalla de la Torre de los 50 Sellos (Pilar 5, Etapa III).
class ObsidianTowerScreen extends ConsumerStatefulWidget {
  const ObsidianTowerScreen({super.key});

  @override
  ConsumerState<ObsidianTowerScreen> createState() =>
      _ObsidianTowerScreenState();
}

class _ObsidianTowerScreenState extends ConsumerState<ObsidianTowerScreen> {
  int _bestFloor = 0;
  String? _lastSweepDay;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(playerRepositoryProvider);
    final (best, sweepMs, sweepDay) = await repo.loadTowerProgress();
    if (mounted) {
      setState(() {
        _bestFloor = best;
        _lastSweepDay = sweepDay;
        _loading = false;
      });
    }
  }

  Future<void> _climbNextFloor() async {
    final nextFloor = _bestFloor + 1;
    if (nextFloor > ObsidianTower.maxFloor) return;

    final repo = ref.read(playerRepositoryProvider);
    final collection = ref.read(collectionProvider);
    final squadIds = collection.squad;
    final owned = collection.owned;
    final cards = squadIds
        .take(4)
        .map((id) => owned.firstWhere((c) => c.instanceId == id))
        .map((c) => ManaCard(
              id: c.catalogId,
              name: c.name,
              element: c.element,
              baseManaCost: c.baseManaCost,
              attack: c.baseAttack.toDouble(),
              stars: c.stars.clamp(1, 3),
              skillLevel: c.skillLevel,
              masteryRank: c.masteryRank,
            ))
        .toList();
    if (cards.length < 4) return;

    final synergy = SquadSynergyResolver.resolve(cards);
    final cardRunes = <String, RuneInstance>{};
    for (final id in squadIds.take(4)) {
      try {
        final c = owned.firstWhere((card) => card.instanceId == id);
        final manaCard = cards.firstWhere((mc) => mc.id == c.catalogId);
        final rune = await repo.loadCardRune(c.instanceId);
        if (rune != null) cardRunes[manaCard.id] = rune;
      } catch (_) {}
    }

    final bossElement = Element.values[nextFloor % 4];
    final isGuardian = ObsidianTower.isGuardianFloor(nextFloor);
    final boss = BossConfig(
      id: 'tower_floor_$nextFloor',
      name: isGuardian
          ? 'Guardián del Piso $nextFloor'
          : 'Eco Abisal del Piso $nextFloor',
      element: bossElement,
      maxHp: ObsidianTower.floorBossHp(nextFloor),
      attackInterval: 5.0,
      attackDamage: ObsidianTower.floorAttack(nextFloor),
      projectilesPerAttack: isGuardian ? 3 : 2,
      shieldHp: isGuardian ? ObsidianTower.floorBossHp(nextFloor) * 0.25 : 0.0,
    );

    final playerMaxHp = (100 * synergy.hpMult).roundToDouble();
    final engine = CombatScreen.buildEngine(
      boss: boss,
      cards: cards,
      playerMaxHp: playerMaxHp,
      synergy: synergy,
      cardRunes: cardRunes,
      playerDamageMult: 1.0,
      startHp: playerMaxHp,
      startManaFull: false,
    );

    if (!mounted) return;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CombatScreen(engine: engine),
        fullscreenDialog: true,
      ),
    );

    if (result == true && mounted) {
      await repo.saveTowerBestFloor(nextFloor);
      final (gold, shards) = ObsidianTower.floorReward(nextFloor);
      await ref
          .read(profileProvider.notifier)
          .grant(gold: gold, shards: shards);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('Piso $nextFloor superado. +$gold oro, +$shards esquirlas'),
          backgroundColor: const Color(0xFF4FFFA3),
        ));
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Derrota en la torre.'),
        backgroundColor: Colors.redAccent,
      ));
    }
  }

  Future<void> _claimSweep() async {
    final dayKey = ObsidianTower.dayKeyOf(DateTime.now());
    final repo = ref.read(playerRepositoryProvider);
    final reward = ObsidianTower.sweepReward(_bestFloor, dayKey,
        lastSweepDay: _lastSweepDay);
    if (reward == null) {
      if (_lastSweepDay?.isNotEmpty == true && _lastSweepDay == dayKey) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Barrido ya cobrado hoy.'),
          backgroundColor: Colors.orangeAccent,
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Exige al menos 5 pisos de récord.'),
          backgroundColor: Colors.orangeAccent,
        ));
      }
      return;
    }
    final (gold, shards) = reward;
    await repo.saveTowerSweep(DateTime.now().millisecondsSinceEpoch, dayKey);
    await ref.read(profileProvider.notifier).grant(gold: gold, shards: shards);
    _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Barrido rápido: +$gold oro, +$shards esquirlas'),
        backgroundColor: const Color(0xFF4FFFA3),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0608),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14090D),
        title: const Text(
          'TORRE DE OBSIDIANA',
          style: TextStyle(
            color: Color(0xFFB16EFF),
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFB16EFF)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14090D),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: const Color(0xFFB16EFF), width: 2),
                    ),
                    child: Column(
                      children: [
                        Text('50 Sellos de Ascenso',
                            style: TextStyle(
                                color: const Color(0xFFB16EFF),
                                fontWeight: FontWeight.w800,
                                fontSize: 16)),
                        const SizedBox(height: 8),
                        Text(
                            'Mejor piso: $_bestFloor / ${ObsidianTower.maxFloor}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 20)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: BrimstoneButton(
                                label: 'ESCALAR LA TORRE',
                                onPressed: _bestFloor >= ObsidianTower.maxFloor
                                    ? null
                                    : _climbNextFloor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: BrimstoneButton(
                                label: 'BARRIDO RÁPIDO DIARIO',
                                onPressed: _claimSweep,
                                isSecondary: true,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('PRÓXIMOS PISOS',
                      style: TextStyle(
                          color: Color(0xFF3FD8FF),
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 1)),
                  const SizedBox(height: 8),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 5,
                    itemBuilder: (_, i) {
                      final floor = _bestFloor + 1 + i;
                      if (floor > ObsidianTower.maxFloor) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF14090D),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Text('Piso $floor',
                                  style: TextStyle(
                                      color: Colors.white38,
                                      fontWeight: FontWeight.w600)),
                              const Spacer(),
                              const Text('CUMBRE ALCANZADA',
                                  style: TextStyle(
                                      color: Color(0xFF4FFFA3),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11)),
                            ],
                          ),
                        );
                      }
                      final isGuardian = ObsidianTower.isGuardianFloor(floor);
                      final hp = ObsidianTower.floorBossHp(floor).round();
                      final atk = ObsidianTower.floorAttack(floor).round();
                      final element = Element.values[floor % 4];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF14090D),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: isGuardian
                                  ? const Color(0xFFFFC93C)
                                  : const Color(0xFFB16EFF),
                              width: isGuardian ? 2 : 1),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: element.color.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(element.icon,
                                  color: element.color, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Piso $floor',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800)),
                                  Text(
                                      isGuardian
                                          ? 'GUARDIÁN DEL SELLO'
                                          : 'Esbirro abisal',
                                      style: TextStyle(
                                          color: isGuardian
                                              ? const Color(0xFFFFC93C)
                                              : Colors.white70,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('$hp HP',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13)),
                                Text('$atk ATK',
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}

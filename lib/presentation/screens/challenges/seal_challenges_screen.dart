import 'package:flutter/material.dart' hide Element;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/design_tokens.dart';
import '../../../domain/combat/combat_engine.dart';
import '../../../domain/combat/combat_models.dart';
import '../../../domain/meta/seal_challenge_rules.dart';
import '../../../domain/value_objects/element.dart';
import '../../controllers/meta_controller.dart';
import '../combat/combat_screen.dart';
import '../meta/widgets.dart';
import '../../widgets/gothic_modal_frame.dart';

/// Los 10 Desafíos del Sello: pruebas tácticas con mutadores que se evalúan
/// dentro de [CombatEngine]. La primera victoria de cada prueba otorga
/// 250 esquirlas + 500 oro y queda registrada en SQLite.
class SealChallengesScreen extends ConsumerStatefulWidget {
  const SealChallengesScreen({super.key});

  @override
  ConsumerState<SealChallengesScreen> createState() =>
      _SealChallengesScreenState();
}

class _SealChallengesScreenState extends ConsumerState<SealChallengesScreen> {
  Set<String> _cleared = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final repo = ref.read(playerRepositoryProvider);
    final cleared = await repo.loadClearedChallenges();
    if (!mounted) return;
    setState(() {
      _cleared = cleared.toSet();
      _loading = false;
    });
  }

  Future<List<ManaCard>> _buildSquad() async {
    final collection = ref.read(collectionProvider);
    if (collection.owned.isEmpty) {
      await ref.read(collectionProvider.notifier).load();
    }
    final state = ref.read(collectionProvider);
    final cards = <ManaCard>[];
    final byId = {for (final c in state.owned) c.instanceId: c};
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
    if (cards.isNotEmpty) return cards;
    // Escuadrón de emergencia para probar el desafío sin colección.
    const elements = {
      'ignis_hound': Element.igneous,
      'abyss_stalker': Element.abyssal,
      'terra_golem': Element.telluric,
      'void_specter': Element.empty,
    };
    for (final id in SealChallengeRules.fallbackSquad) {
      cards.add(
        ManaCard(
          id: id,
          name: id.replaceAll('_', ' '),
          element: elements[id] ?? Element.igneous,
          baseManaCost: 100,
          attack: 10,
          skillLevel: 1,
          masteryRank: 1,
        ),
      );
    }
    return cards;
  }

  Future<void> _enter(SealChallenge challenge) async {
    final repo = ref.read(playerRepositoryProvider);
    final cards = await _buildSquad();
    final talents = await repo.loadTalentLevels();
    final gear = await repo.loadGearLevels();
    if (!mounted) return;

    final engine = CombatEngine(
      boss: challenge.boss,
      cards: cards,
      playerMaxHp: challenge.playerMaxHp,
      modifiers: const CombatModifiers(),
      mutators: challenge.mutators,
      talentLevels: talents,
      summonerGear: gear,
    );

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CombatScreen(
          engine: engine,
          mutators: challenge.mutators,
          onCombatResolved: (victory, playerHp) async {
            if (!victory) return;
            final firstWin = await repo.markChallengeCleared(
              challenge.id,
              rewardGold: challenge.rewardGold,
              rewardShards: challenge.rewardShards,
            );
            await repo.recordCombatResult(
              victory: true,
              damageTotal: engine.damageTotal,
              maxHit: engine.maxHit.toInt(),
              bullseyes: engine.bullseyes,
              bestBullseyeStreak: engine.bestBullseyeStreak,
              reactions: engine.reactions,
              counterflicks: engine.counterflicks,
              bossKilled: true,
            );
            await ref.read(profileProvider.notifier).load();
            if (!mounted) return;
            await _load();
            if (!mounted) return;
            await showDialog<void>(
              context: context,
              builder: (_) => GothicModalFrame(
                title: challenge.title.toUpperCase(),
                subtitle: 'SELLO SUPERADO',
                icon: Icons.military_tech,
                accent: const Color(0xFF4FFFA3),
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
                    firstWin
                        ? 'Primera victoria: +${challenge.rewardShards} '
                            'esquirlas, +${challenge.rewardGold} oro.'
                        : 'Sello superado de nuevo. Ya cobraste la recompensa.',
                    style: BrimstoneFonts.sans(
                      size: 12,
                      color: BrimstoneTokens.textPrimary,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0608),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14090D),
        title: const Text(
          'DESAFÍOS DEL SELLO',
          style: TextStyle(
            color: Color(0xFFB16EFF),
            fontWeight: FontWeight.w900,
            fontSize: 15,
            letterSpacing: 1.5,
          ),
        ),
        actions: const [Padding(padding: EdgeInsets.only(right: 8))],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFB16EFF)),
            )
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                const CurrencyBar(),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A0E14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFF5A26)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.gavel,
                        color: Color(0xFFFF5A26),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_cleared.length}/10 sellos superados · '
                          'Recompensa por sello: 250 esquirlas + 500 oro',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                for (final challenge in SealChallengeRules.allChallenges)
                  _ChallengeCard(
                    challenge: challenge,
                    cleared: _cleared.contains(challenge.id),
                    onEnter: () => _enter(challenge),
                  ),
              ],
            ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  final SealChallenge challenge;
  final bool cleared;
  final VoidCallback onEnter;

  const _ChallengeCard({
    required this.challenge,
    required this.cleared,
    required this.onEnter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1116),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cleared ? const Color(0xFF4FFFA3) : const Color(0xFFFF5A26),
          width: 1.3,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                cleared ? Icons.verified : Icons.local_fire_department,
                color:
                    cleared ? const Color(0xFF4FFFA3) : const Color(0xFFFF5A26),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  challenge.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              if (cleared)
                const Text(
                  'SUPERADO',
                  style: TextStyle(
                    color: Color(0xFF4FFFA3),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            challenge.description,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              _MutatorChip(
                label: challenge.boss.name.split(',').first,
                color: const Color(0xFFB16EFF),
              ),
              for (final mutator in challenge.mutators)
                _MutatorChip(
                    label: mutator.label, color: const Color(0xFFFFC93C)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${challenge.rewardShards} esquirlas · ${challenge.rewardGold} oro',
                style: const TextStyle(color: Colors.white38, fontSize: 9),
              ),
              const Spacer(),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: cleared
                      ? const Color(0xFF2A1116)
                      : const Color(0xFFFF5A26),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onPressed: onEnter,
                child: Text(
                  cleared ? 'REPETIR' : 'ENTRAR',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MutatorChip extends StatelessWidget {
  final String label;
  final Color color;

  const _MutatorChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

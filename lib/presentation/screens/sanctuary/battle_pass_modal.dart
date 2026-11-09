import 'dart:math' as math;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/meta_controller.dart';

/// Battle Pass Modal - 20 tiers, free + premium tracks.
/// Accessible from SanctuaryScreen.
class BattlePassModal extends ConsumerStatefulWidget {
  const BattlePassModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const BattlePassModal(),
    );
  }

  @override
  ConsumerState<BattlePassModal> createState() => _BattlePassModalState();
}

class _BattlePassModalState extends ConsumerState<BattlePassModal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  int _currentXp = 0;
  int _currentLevel = 1;
  Set<int> _claimedFree = {};
  Set<int> _claimedPremium = {};
  bool _premiumUnlocked = false;

  static const int _xpPerLevel = 200;
  static const int _maxLevel = 20;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadProgress();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProgress() async {
    final repo = ref.read(playerRepositoryProvider);
    final data = await repo.loadBattlePass();
    if (!mounted) return;
    setState(() {
      _currentXp = data['xp'] as int? ?? 0;
      _currentLevel = math.min((_currentXp ~/ _xpPerLevel) + 1, _maxLevel);
      _claimedFree = (data['claimedFree'] as List?)?.cast<int>().toSet() ?? {};
      _claimedPremium =
          (data['claimedPremium'] as List?)?.cast<int>().toSet() ?? {};
      _premiumUnlocked = data['premiumUnlocked'] as bool? ?? false;
    });
    _animCtrl.forward();
  }

  Future<void> _saveProgress() async {
    final repo = ref.read(playerRepositoryProvider);
    await repo.saveBattlePass({
      'xp': _currentXp,
      'claimedFree': _claimedFree.toList(),
      'claimedPremium': _claimedPremium.toList(),
      'premiumUnlocked': _premiumUnlocked,
    });
  }

  Future<void> _claimReward(int level, bool isPremium) async {
    final claimedSet = isPremium ? _claimedPremium : _claimedFree;
    if (claimedSet.contains(level) || level > _currentLevel) return;

    if (isPremium && !_premiumUnlocked) {
      // Unlock premium with shards
      final profile = ref.read(profileProvider.notifier);
      const unlockCost = 1500;
      if (!await profile.spend(shards: unlockCost)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Esquirlas insuficientes para desbloquear Carril Arconte')),
        );
        return;
      }
      setState(() => _premiumUnlocked = true);
    }

    final reward = _getRewardForLevel(level, isPremium);
    if (reward == null) return;

    // Grant rewards
    if (reward.gold > 0 || reward.shards > 0) {
      await ref
          .read(profileProvider.notifier)
          .grant(gold: reward.gold, shards: reward.shards);
    }
    if (reward.card != null) {
      final repo = ref.read(playerRepositoryProvider);
      final card = await repo.insertSummonedCard(reward.card!);
      ref.read(collectionProvider.notifier).addCard(card);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('¡Carta obtenida: ${card.name}!')),
      );
    }

    setState(() {
      if (isPremium) {
        _claimedPremium.add(level);
      } else {
        _claimedFree.add(level);
      }
    });
    await _saveProgress();
  }

  _BattlePassReward? _getRewardForLevel(int level, bool isPremium) {
    // Level 5, 10, 15, 20 give special cards
    final specialCards = {
      5: (free: 'ignis_drake', premium: 'ignis_lord'),
      10: (free: 'abyss_siren', premium: 'abyss_kraken'),
      15: (free: 'terra_warden', premium: 'terra_titan'),
      20: (free: 'void_reaper', premium: 'void_archon'),
    };

    if (specialCards.containsKey(level)) {
      final cardId =
          isPremium ? specialCards[level]!.premium : specialCards[level]!.free;
      return _BattlePassReward(card: cardId);
    }

    // Regular rewards scale with level
    final baseGold = 300 + (level * 85);
    final baseShards = 100 + (level * 35);
    final premiumMult = isPremium ? 2.0 : 1.0;

    return _BattlePassReward(
      gold: (baseGold * premiumMult).round(),
      shards: (baseShards * premiumMult).round(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final xpInLevel = _currentXp % _xpPerLevel;
    final progress = _currentLevel >= _maxLevel ? 1.0 : xpInLevel / _xpPerLevel;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Color(0xFF0C0608),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: Color(0xFFB16EFF), width: 2)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A0A0F), Color(0xFF0C0608)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              border: Border(
                  bottom: BorderSide(color: Color(0xFFB16EFF), width: 1)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.military_tech,
                        color: Color(0xFFFFC93C), size: 24),
                    const SizedBox(width: 8),
                    const Text(
                      'PASE DEL SELLO ABISAL',
                      style: TextStyle(
                        color: Color(0xFFFFC93C),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          const Color(0xFFB16EFF).withValues(alpha: 0.9),
                          const Color(0xFFB16EFF).withValues(alpha: 0.7),
                        ]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Temporada 1: Cenizas del Trono',
                        style: const TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // XP Bar
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'NIVEL $_currentLevel / $_maxLevel',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                '$_currentXp XP total',
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 10),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Stack(
                            children: [
                              Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E0A0E),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 500),
                                width: MediaQuery.of(context).size.width *
                                    0.7 *
                                    progress,
                                height: 8,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [
                                    Color(0xFFFFC93C),
                                    Color(0xFFFFD700),
                                    Color(0xFFB16EFF),
                                  ]),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      children: [
                        Text(
                          '+50 XP / enemigo',
                          style: TextStyle(color: Colors.white70, fontSize: 10),
                        ),
                        Text(
                          '+150 XP / jefe',
                          style: TextStyle(
                              color: const Color(0xFFFF5A26),
                              fontSize: 10,
                              fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ],
                ),
                // Premium unlock button
                if (!_premiumUnlocked)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: OutlinedButton.icon(
                      onPressed: () => _claimReward(1, true), // Triggers unlock
                      icon: const Icon(Icons.star,
                          size: 16, color: Color(0xFFFFC93C)),
                      label: const Text(
                        'DESBLOQUEAR CARRIL ARCONTE (1500 esq.)',
                        style: TextStyle(
                            color: Color(0xFFFFC93C),
                            fontWeight: FontWeight.w900,
                            fontSize: 11),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: Color(0xFFFFC93C), width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          const Color(0xFFFFC93C).withValues(alpha: 0.3),
                          const Color(0xFFB16EFF).withValues(alpha: 0.3),
                        ]),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: const Color(0xFFFFC93C), width: 1),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, color: Color(0xFFFFC93C), size: 16),
                          SizedBox(width: 4),
                          Text(
                            'CARRIL ARCONTE ACTIVO',
                            style: TextStyle(
                                color: Color(0xFFFFC93C),
                                fontWeight: FontWeight.w900,
                                fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Tier list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _maxLevel,
              itemBuilder: (context, index) {
                final level = index + 1;
                final freeReward = _getRewardForLevel(level, false);
                final premiumReward = _getRewardForLevel(level, true);
                final isCurrentLevel = level == _currentLevel;
                final isClaimableFree =
                    level <= _currentLevel && !_claimedFree.contains(level);
                final isClaimablePremium = _premiumUnlocked &&
                    level <= _currentLevel &&
                    !_claimedPremium.contains(level);
                final isClaimedFree = _claimedFree.contains(level);
                final isClaimedPremium = _claimedPremium.contains(level);

                return _TierRow(
                  level: level,
                  isCurrentLevel: isCurrentLevel,
                  freeReward: freeReward!,
                  premiumReward: premiumReward!,
                  isClaimableFree: isClaimableFree,
                  isClaimablePremium: isClaimablePremium,
                  isClaimedFree: isClaimedFree,
                  isClaimedPremium: isClaimedPremium,
                  premiumUnlocked: _premiumUnlocked,
                  onClaimFree:
                      isClaimableFree ? () => _claimReward(level, false) : null,
                  onClaimPremium: isClaimablePremium
                      ? () => _claimReward(level, true)
                      : null,
                );
              },
            ),
          ),
          // Close button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text(
                  'CERRAR',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BattlePassReward {
  final int gold;
  final int shards;
  final String? card;

  const _BattlePassReward({this.gold = 0, this.shards = 0, this.card});
}

class _TierRow extends StatelessWidget {
  final int level;
  final bool isCurrentLevel;
  final _BattlePassReward freeReward;
  final _BattlePassReward premiumReward;
  final bool isClaimableFree;
  final bool isClaimablePremium;
  final bool isClaimedFree;
  final bool isClaimedPremium;
  final bool premiumUnlocked;
  final VoidCallback? onClaimFree;
  final VoidCallback? onClaimPremium;

  const _TierRow({
    required this.level,
    required this.isCurrentLevel,
    required this.freeReward,
    required this.premiumReward,
    required this.isClaimableFree,
    required this.isClaimablePremium,
    required this.isClaimedFree,
    required this.isClaimedPremium,
    required this.premiumUnlocked,
    this.onClaimFree,
    this.onClaimPremium,
  });

  @override
  Widget build(BuildContext context) {
    final isSpecial = [5, 10, 15, 20].contains(level);
    final bgColor = isCurrentLevel
        ? const Color(0xFF1A0A0F).withValues(alpha: 0.8)
        : const Color(0xFF14090D);
    final borderColor =
        isCurrentLevel ? const Color(0xFFB16EFF) : Colors.white12;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: isCurrentLevel ? 2 : 1),
        boxShadow: isCurrentLevel
            ? [
                BoxShadow(
                    color: const Color(0xFFB16EFF).withValues(alpha: 0.3),
                    blurRadius: 10)
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: isSpecial
                          ? [const Color(0xFFFFC93C), const Color(0xFFFFD700)]
                          : [const Color(0xFFB16EFF), const Color(0xFF3FD8FF)]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '$level',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (isCurrentLevel)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [
                      Color(0xFFB16EFF),
                      Color(0xFF3FD8FF),
                    ]),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'ACTUAL',
                    style: TextStyle(
                        color: Colors.black,
                        fontSize: 8,
                        fontWeight: FontWeight.w900),
                  ),
                ),
              if (isSpecial && !isCurrentLevel) ...[
                const SizedBox(width: 8),
                const Icon(Icons.auto_awesome,
                    color: Color(0xFFFFC93C), size: 16),
              ],
            ],
          ),
          const SizedBox(height: 10),
          // Free track
          _RewardTrack(
            label: 'GRATIS',
            color: Colors.white70,
            reward: freeReward,
            isClaimable: isClaimableFree,
            isClaimed: isClaimedFree,
            onClaim: onClaimFree,
            showCard: freeReward.card != null,
          ),
          const SizedBox(height: 6),
          // Premium track
          _RewardTrack(
            label: premiumUnlocked ? 'ARCONTE' : 'ARCONTE 🔒',
            color: premiumUnlocked ? const Color(0xFFFFC93C) : Colors.white24,
            reward: premiumReward,
            isClaimable: isClaimablePremium,
            isClaimed: isClaimedPremium,
            onClaim: onClaimPremium,
            showCard: premiumReward.card != null,
            locked: !premiumUnlocked,
          ),
        ],
      ),
    );
  }
}

class _RewardTrack extends StatelessWidget {
  final String label;
  final Color color;
  final _BattlePassReward reward;
  final bool isClaimable;
  final bool isClaimed;
  final VoidCallback? onClaim;
  final bool showCard;
  final bool locked;

  const _RewardTrack({
    required this.label,
    required this.color,
    required this.reward,
    required this.isClaimable,
    required this.isClaimed,
    this.onClaim,
    this.showCard = false,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            children: [
              if (reward.gold > 0)
                _RewardChip(
                    icon: Icons.monetization_on,
                    color: Colors.amber,
                    value: '+${reward.gold}'),
              if (reward.shards > 0)
                _RewardChip(
                    icon: Icons.diamond,
                    color: const Color(0xFF3FD8FF),
                    value: '+${reward.shards}'),
              if (showCard)
                _RewardChip(
                    icon: Icons.style,
                    color: const Color(0xFFB16EFF),
                    value: 'CARTA'),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (locked)
          const Icon(Icons.lock, color: Colors.white24, size: 18)
        else if (isClaimed)
          const Icon(Icons.check_circle, color: Color(0xFF4FFFA3), size: 22)
        else if (isClaimable)
          IconButton(
            onPressed: onClaim,
            icon: const Icon(Icons.card_giftcard,
                color: Color(0xFFB16EFF), size: 22),
            tooltip: 'Reclamar',
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFB16EFF).withValues(alpha: 0.15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          )
        else
          const Icon(Icons.lock_clock, color: Colors.white24, size: 18),
      ],
    );
  }
}

class _RewardChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;

  const _RewardChip(
      {required this.icon, required this.color, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 9, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/procedural_sfx_engine.dart';
import '../../../domain/combat/combat_engine.dart';
import '../../../domain/combat/combat_models.dart';
import '../../../domain/value_objects/element.dart';
import '../../controllers/meta_controller.dart';
import '../../graphics/art_registry.dart';
import '../../graphics/painted_backdrop.dart';
import '../../screens/combat/combat_screen.dart';
import '../../widgets/brimstone_button.dart';

/// Pantalla de Cacería de Titanes (World Boss Raids) - Block 2.
///
/// 4 Titanes Colosales con HP persistente en SQLite.
/// Cada intento: 60 segundos de combate, daño acumulativo.
/// Recompensas por hitos: 25%, 50%, 75%, 100% (Golpe de Gracia + Ascensión).
class AbyssalRaidScreen extends ConsumerStatefulWidget {
  const AbyssalRaidScreen({super.key});

  @override
  ConsumerState<AbyssalRaidScreen> createState() => _AbyssalRaidScreenState();
}

class _AbyssalRaidScreenState extends ConsumerState<AbyssalRaidScreen> {
  List<Map<String, Object?>> _raidBosses = [];
  Timer? _refreshTimer;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRaidBosses();
    _refreshTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _loadRaidBosses());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRaidBosses() async {
    final repo = ref.read(playerRepositoryProvider);
    final bosses = await repo.loadRaidBosses();
    if (mounted) {
      setState(() {
        _raidBosses = bosses;
        _loading = false;
      });
    }
  }

  Future<void> _startRaid(String bossId) async {
    final repo = ref.read(playerRepositoryProvider);
    final bossData = await repo.loadRaidBoss(bossId);
    if (bossData == null) return;

    final baseHp = bossData['base_hp'] as int;
    final currentHp = bossData['current_hp'] as int;
    final ascension = bossData['ascension_level'] as int;
    final elementStr = bossData['element'] as String;
    final element = Element.values
        .firstWhere((e) => e.name == elementStr, orElse: () => Element.igneous);

    // Build raid boss config with shield HP (25% of max HP) - Block 3
    final shieldHp = (baseHp * 0.25).round();
    final boss = BossConfig(
      id: bossId,
      name: bossData['name'] as String,
      element: element,
      maxHp: baseHp.toDouble(),
      attackInterval: 5.0,
      attackDamage: 25 + ascension * 5,
      projectilesPerAttack: 3,
      shieldHp: shieldHp.toDouble(),
      threatDialog: _getThreatDialog(bossId, ascension),
      furyDialog: _getFuryDialog(bossId),
    );

    final maxHpWithAscension = (baseHp * math.pow(1.8, ascension)).round();

    if (!mounted) return;
    ProceduralSfxEngine.playUIHeavyClick();

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => _RaidCombatWrapper(
          bossId: bossId,
          boss: boss,
          maxHpWithAscension: maxHpWithAscension,
          currentHp: currentHp,
          shieldHp: shieldHp,
          ascension: ascension,
          element: element,
        ),
      ),
    );

    if (result == true && mounted) {
      await _loadRaidBosses();
    }
  }

  String _getThreatDialog(String bossId, int ascension) {
    switch (bossId) {
      case 'titan_igneous':
        return ascension == 0
            ? '¡Bahamut de Escoria despierta! ¡Siente el calor de mil soles!'
            : '¡Bahamut regresa en Ascensión $ascension! ¡Su furia arde más fuerte!';
      case 'titan_abyssal':
        return ascension == 0
            ? 'Jörmungandr del Foso emerge de las profundidades...'
            : 'El Foso no olvida. Jörmungandr Ascensión $ascension te espera.';
      case 'titan_telluric':
        return ascension == 0
            ? 'Atlas Monolítico sostiene el peso del mundo... y lo aplastará.'
            : 'Atlas Ascensión $ascension: la montaña se mueve.';
      case 'titan_void':
        return ascension == 0
            ? 'Nyarlathotep del Eclipse susurra: "Tu fin comienza ahora."'
            : 'El Eclipse se profundiza. Nyarlathotep Ascensión $ascension observa.';
      default:
        return 'Un Titán despierta...';
    }
  }

  String _getFuryDialog(String bossId) {
    switch (bossId) {
      case 'titan_igneous':
        return '¡LLAMA ETERNA!';
      case 'titan_abyssal':
        return '¡ABISMO INFINITO!';
      case 'titan_telluric':
        return '¡TERREMOTO PRIMORDIAL!';
      case 'titan_void':
        return '¡VACÍO ABSOLUTO!';
      default:
        return '¡FURIA TITÁNICA!';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PaintedBackdrop(
        asset: ArtRegistry.raid,
        tint: const Color(0xFF8B4FD9),
        darkness: 0.7,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF0A0008).withValues(alpha: 0.55),
                const Color(0xFF1A0010).withValues(alpha: 0.35),
                const Color(0xFF0D0015).withValues(alpha: 0.75),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      BrimstoneButton(
                        isSecondary: true,
                        label: 'SANTUARIO',
                        icon: Icons.arrow_back,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '🐉 CACERÍA DE TITANES',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFFFD700),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            shadows: [
                              Shadow(color: Color(0xFF8B0000), blurRadius: 4),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white70),
                        onPressed: _loadRaidBosses,
                      ),
                    ],
                  ),
                ),
                // Timer indicator
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A0010),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF8B0000)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.timer,
                          color: Color(0xFFFFD700), size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Cada incursión dura 60 segundos. El daño se acumula permanentemente.',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Boss List
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFFFFD700)))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _raidBosses.length,
                          itemBuilder: (context, index) {
                            final boss = _raidBosses[index];
                            return _RaidBossCard(
                              boss: boss,
                              onTap: () => _startRaid(boss['id'] as String),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RaidBossCard extends ConsumerWidget {
  final Map<String, Object?> boss;
  final VoidCallback onTap;

  const _RaidBossCard({required this.boss, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baseHp = boss['base_hp'] as int;
    final currentHp = boss['current_hp'] as int;
    final ascension = boss['ascension_level'] as int;
    final elementStr = boss['element'] as String;
    final element = Element.values
        .firstWhere((e) => e.name == elementStr, orElse: () => Element.igneous);
    final name = boss['name'] as String;
    final id = boss['id'] as String;

    final maxHpWithAscension = (baseHp * math.pow(1.8, ascension)).round();
    final hpPercent =
        maxHpWithAscension > 0 ? currentHp / maxHpWithAscension : 0.0;
    final isDefeated = currentHp <= 0;

    final elementColor = _elementColor(element);
    final milestone25 = (maxHpWithAscension * 0.75).round();
    final milestone50 = (maxHpWithAscension * 0.50).round();
    final milestone75 = (maxHpWithAscension * 0.25).round();

    final reached25 = currentHp <= milestone25;
    final reached50 = currentHp <= milestone50;
    final reached75 = currentHp <= milestone75;
    final reached100 = isDefeated;

    return GestureDetector(
      onTap: isDefeated ? null : onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDefeated
                ? [const Color(0xFF1A1A1A), const Color(0xFF0A0A0A)]
                : [
                    const Color(0xFF1A0E14).withValues(alpha: 0.9),
                    const Color(0xFF0D0015).withValues(alpha: 0.9),
                  ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDefeated
                ? Colors.white24
                : elementColor.withValues(alpha: 0.6),
            width: 2,
          ),
          boxShadow: isDefeated
              ? []
              : [
                  BoxShadow(
                    color: elementColor.withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: painted titan portrait + Name + Ascension + Element
            Row(
              children: [
                // Imposing titan medallion, blended into the elemental glow.
                Container(
                  width: 58,
                  height: 58,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDefeated
                          ? Colors.white24
                          : elementColor.withValues(alpha: 0.8),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: elementColor.withValues(alpha: 0.45),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      ArtRegistry.portrait(_raidPortraitId(id)),
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (_, __, ___) => ColoredBox(
                        color: elementColor.withValues(alpha: 0.25),
                        child: Center(
                          child: Icon(
                            Icons.local_fire_department,
                            color: elementColor,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      elementColor,
                      elementColor.withValues(alpha: 0.7)
                    ]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _elementDisplayName(element),
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                if (ascension > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFF5A26)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'ASCENSIÓN $ascension',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                if (isDefeated)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4FFFA3).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF4FFFA3)),
                    ),
                    child: const Text(
                      'ABATIDO ✓',
                      style: TextStyle(
                        color: Color(0xFF4FFFA3),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // HP Bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isDefeated
                          ? 'DERROTADO'
                          : 'HP: $currentHp / $maxHpWithAscension',
                      style: TextStyle(
                        color:
                            isDefeated ? const Color(0xFF4FFFA3) : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${(hpPercent * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: isDefeated
                            ? const Color(0xFF4FFFA3)
                            : Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Stack(
                  children: [
                    Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A0008),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white12),
                      ),
                    ),
                    // HP Bar
                    FractionallySizedBox(
                      widthFactor: hpPercent.clamp(0.0, 1.0),
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            elementColor,
                            elementColor.withValues(alpha: 0.6)
                          ]),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    // Milestone markers
                    Positioned.fill(
                      child: Row(
                        children: [
                          _MilestoneMarker(
                            fraction: 0.75,
                            color: reached25
                                ? const Color(0xFF4FFFA3)
                                : Colors.white38,
                            reached: reached25,
                          ),
                          _MilestoneMarker(
                            fraction: 0.50,
                            color: reached50
                                ? const Color(0xFF4FFFA3)
                                : Colors.white38,
                            reached: reached50,
                          ),
                          _MilestoneMarker(
                            fraction: 0.25,
                            color: reached75
                                ? const Color(0xFF4FFFA3)
                                : Colors.white38,
                            reached: reached75,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Milestone Rewards
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _RewardBadge(
                  label: '25%',
                  icon: Icons.diamond_outlined,
                  claimed: reached25,
                  color: const Color(0xFF4FFFA3),
                ),
                _RewardBadge(
                  label: '50%',
                  icon: Icons.diamond_outlined,
                  claimed: reached50,
                  color: const Color(0xFFB16EFF),
                ),
                _RewardBadge(
                  label: '75%',
                  icon: Icons.diamond,
                  claimed: reached75,
                  color: const Color(0xFFFFD700),
                ),
                _RewardBadge(
                  label: '100%',
                  icon: Icons.star,
                  claimed: reached100,
                  color: const Color(0xFFFF5A26),
                  isUltimate: true,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Enter Button
            SizedBox(
              width: double.infinity,
              child: BrimstoneButton(
                label: isDefeated
                    ? (ascension < 5
                        ? 'ASCENDER TITÁN (Nv. ${ascension + 1})'
                        : 'MÁX. ASCENSIÓN ALCANZADA')
                    : 'INICIAR INCURSIÓN (60s)',
                icon: isDefeated ? Icons.trending_up : Icons.flash_on,
                isSecondary: isDefeated,
                onPressed: isDefeated
                    ? (ascension < 5
                        ? () async {
                            final repo = ref.read(playerRepositoryProvider);
                            await repo.ascendRaidBoss(id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      '$name ascendido a Nivel ${ascension + 1}!'),
                                  backgroundColor: const Color(0xFFFFD700),
                                ),
                              );
                              // Reload handled by parent
                            }
                          }
                        : null)
                    : onTap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Maps raid boss ids to their curated titan painting.
  String _raidPortraitId(String id) => switch (id) {
        'titan_igneous' => 'titan_bahamut',
        'titan_abyssal' => 'titan_jormungandr',
        'titan_telluric' => 'titan_atlas',
        'titan_void' => 'titan_nyarlathotep',
        _ => id,
      };

  Color _elementColor(Element e) => switch (e) {
        Element.igneous => const Color(0xFFFF5A26),
        Element.abyssal => const Color(0xFF00FFFF),
        Element.telluric => const Color(0xFF8B5A2B),
        Element.empty => const Color(0xFFB16EFF),
      };

  String _elementDisplayName(Element e) => switch (e) {
        Element.igneous => 'ÍGNEO',
        Element.abyssal => 'ABISAL',
        Element.telluric => 'TELÚRICO',
        Element.empty => 'VACÍO',
      };
}

class _MilestoneMarker extends StatelessWidget {
  final double fraction;
  final Color color;
  final bool reached;

  const _MilestoneMarker({
    required this.fraction,
    required this.color,
    required this.reached,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: fraction,
          child: Container(
            width: 2,
            height: 16,
            margin: const EdgeInsets.only(top: -2),
            decoration: BoxDecoration(
              color: reached ? color : Colors.transparent,
              borderRadius: BorderRadius.circular(1),
              boxShadow:
                  reached ? [BoxShadow(color: color, blurRadius: 4)] : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _RewardBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool claimed;
  final Color color;
  final bool isUltimate;

  const _RewardBadge({
    required this.label,
    required this.icon,
    required this.claimed,
    required this.color,
    this.isUltimate = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: claimed
            ? LinearGradient(colors: [
                color.withValues(alpha: 0.3),
                color.withValues(alpha: 0.1)
              ])
            : null,
        color: claimed ? null : const Color(0xFF1A0E14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: claimed ? color : Colors.white12,
          width: claimed ? 1.5 : 1,
        ),
        boxShadow: claimed
            ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8)]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: claimed ? color : Colors.white38),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: claimed ? color : Colors.white38,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (claimed) ...[
            const SizedBox(width: 4),
            Icon(Icons.check, size: 10, color: color),
          ],
        ],
      ),
    );
  }
}

/// Wrapper that runs the raid combat with 60-second timer and damage accumulation.
class _RaidCombatWrapper extends ConsumerStatefulWidget {
  final String bossId;
  final BossConfig boss;
  final int maxHpWithAscension;
  final int currentHp;
  final int shieldHp;
  final int ascension;
  final Element element;

  const _RaidCombatWrapper({
    required this.bossId,
    required this.boss,
    required this.maxHpWithAscension,
    required this.currentHp,
    required this.shieldHp,
    required this.ascension,
    required this.element,
  });

  @override
  ConsumerState<_RaidCombatWrapper> createState() => _RaidCombatWrapperState();
}

class _RaidCombatWrapperState extends ConsumerState<_RaidCombatWrapper> {
  Timer? _raidTimer;
  double _timeLeft = 60.0;
  bool _combatEnded = false;
  int _damageDealt = 0;

  @override
  void initState() {
    super.initState();
    _startRaidTimer();
  }

  void _startRaidTimer() {
    _raidTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted || _combatEnded) {
        timer.cancel();
        return;
      }
      setState(() {
        _timeLeft -= 0.1;
        if (_timeLeft <= 0) {
          _timeLeft = 0;
          timer.cancel();
          _endRaidCombat(timeUp: true);
        }
      });
    });
  }

  void _endRaidCombat({required bool timeUp}) async {
    if (_combatEnded) return;
    _combatEnded = true;
    _raidTimer?.cancel();

    final repo = ref.read(playerRepositoryProvider);

    // Apply damage to raid boss in SQLite
    if (_damageDealt > 0) {
      final defeated =
          await repo.dealDamageToRaidBoss(widget.bossId, _damageDealt);
      if (defeated && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '¡${widget.boss.name} HA SIDO ABATIDO! Recompensas de Golpe de Gracia desbloqueadas.'),
            backgroundColor: const Color(0xFF4FFFA3),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }

    if (!mounted) return;

    // Show result
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A0E14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
              color: _damageDealt > 0
                  ? const Color(0xFFFFD700)
                  : const Color(0xFFFF5A26)),
        ),
        title: Text(
          timeUp ? '⏱️ TIEMPO AGOTADO' : '💀 DERROTA',
          style: const TextStyle(
              color: Color(0xFFFFD700), fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Daño infligido: $_damageDealt',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
            ),
            Text(
              'HP restante del Titán: ${math.max(0, widget.currentHp - _damageDealt)}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Text(
              'El daño se ha guardado permanentemente. ¡Vuelve a intentarlo!',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context)
                  .pop(true); // Return to raid screen with refresh
            },
            child: const Text('VOLVER',
                style: TextStyle(
                    color: Color(0xFFFFD700), fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _raidTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final engine = CombatEngine(
      boss: widget.boss,
      cards: _buildRaidSquad(),
      playerMaxHp: 100,
      modifiers: const CombatModifiers(),
    );
    engine.onHit = (kind, damage, x, y, element) {
      if (kind != HitKind.miss) {
        _damageDealt += damage;
      }
    };
    return CombatScreen(
      engine: engine,
      onCombatResolved: (victory, playerHp) {
        if (!_combatEnded) {
          _endRaidCombat(timeUp: false);
        }
      },
    );
  }

  List<ManaCard> _buildRaidSquad() {
    // Use player's current squad or default
    // For simplicity, use a default strong squad
    return [
      ManaCard(
        id: 'ignis_hound',
        name: 'Sabueso de Azufre',
        element: Element.igneous,
        baseManaCost: 100,
        attack: 25,
        stars: 3,
        skillLevel: 3,
        masteryRank: 3,
      ),
      ManaCard(
        id: 'abyss_stalker',
        name: 'Acechador de Escarcha',
        element: Element.abyssal,
        baseManaCost: 95,
        attack: 30,
        stars: 3,
        skillLevel: 3,
        masteryRank: 3,
      ),
      ManaCard(
        id: 'terra_golem',
        name: 'Gólem de Basalto',
        element: Element.telluric,
        baseManaCost: 100,
        attack: 20,
        stars: 3,
        skillLevel: 3,
        masteryRank: 3,
      ),
      ManaCard(
        id: 'void_specter',
        name: 'Espectro del Sello',
        element: Element.empty,
        baseManaCost: 110,
        attack: 35,
        stars: 3,
        skillLevel: 3,
        masteryRank: 3,
      ),
    ];
  }
}

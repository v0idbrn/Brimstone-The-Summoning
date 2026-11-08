import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/procedural_sfx_engine.dart';
import '../../../domain/meta/summoner_gear.dart';
import '../../../domain/meta/talent_rules.dart';
import '../../controllers/meta_controller.dart';
import '../meta/widgets.dart';

/// Modal del Árbol de Talentos permanentes y la Armadura del Invocador.
///
/// Los 8 talentos suben de Nivel 0 a 5 pagando oro + esquirlas. Las 3 piezas
/// de armadura se forjan y mejoran de la misma forma. Todo se persiste en
/// SQLite (schema v6) vía [PlayerRepository].
class TalentTreeModal extends ConsumerStatefulWidget {
  const TalentTreeModal({super.key});

  @override
  ConsumerState<TalentTreeModal> createState() => _TalentTreeModalState();
}

class _TalentTreeModalState extends ConsumerState<TalentTreeModal>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  Map<String, int> _talentLevels = const {};
  Map<String, int> _gearLevels = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(playerRepositoryProvider);
    final talents = await repo.loadTalentLevels();
    final gear = await repo.loadGearLevels();
    if (!mounted) return;
    setState(() {
      _talentLevels = talents;
      _gearLevels = gear;
      _loading = false;
    });
  }

  Future<void> _upgradeTalent(Talent talent) async {
    final repo = ref.read(playerRepositoryProvider);
    final current = _talentLevels[talent.id] ?? 0;
    final cost = TalentRules.costFor(talent.id, current);
    if (cost == null) return;
    final ok = await repo.upgradeTalent(talent.id);
    if (!mounted) return;
    if (!ok) {
      _snack('Oro o esquirlas insuficientes', Colors.redAccent);
      return;
    }
    ProceduralSfxEngine.playEvolutionSuccess();
    await ref.read(profileProvider.notifier).load();
    await _load();
    if (!mounted) return;
    _snack(
      '${talent.name} → Nivel ${current + 1}',
      const Color(0xFF4FFFA3),
    );
  }

  Future<void> _forgeGear(SummonerGearPiece piece) async {
    final repo = ref.read(playerRepositoryProvider);
    final current = _gearLevels[piece.id] ?? 0;
    final cost = SummonerGearRules.costFor(piece.id, current);
    if (cost == null) return;
    final ok = await repo.forgeGear(piece.id);
    if (!mounted) return;
    if (!ok) {
      _snack('Oro o esquirlas insuficientes', Colors.redAccent);
      return;
    }
    ProceduralSfxEngine.playOrbMerge(2);
    await ref.read(profileProvider.notifier).load();
    await _load();
    if (!mounted) return;
    _snack(
      '${piece.name} → Nivel ${current + 1}',
      const Color(0xFF3FD8FF),
    );
  }

  void _snack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tree = TalentTree(_talentLevels);
    final loadout = GearLoadout(_gearLevels);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: const BoxDecoration(
        color: Color(0xFF14090D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            'ÁRBOL DE TALENTOS DEL INVOCADOR',
            style: TextStyle(
              color: Color(0xFFB16EFF),
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Niveles invertidos: ${tree.totalLevels}/${TalentRules.allTalents.length * TalentRules.maxLevel}',
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
          const SizedBox(height: 8),
          const CurrencyBar(),
          TabBar(
            controller: _tabs,
            indicatorColor: const Color(0xFFB16EFF),
            labelColor: const Color(0xFFB16EFF),
            unselectedLabelColor: Colors.white54,
            tabs: const [
              Tab(text: 'TALENTOS'),
              Tab(text: 'ARMADURA'),
            ],
          ),
          SizedBox(
            height: 430,
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFB16EFF)),
                  )
                : TabBarView(
                    controller: _tabs,
                    children: [
                      _talentsTab(),
                      _gearTab(loadout),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _talentsTab() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: TalentRules.allTalents.length,
      itemBuilder: (context, index) {
        final talent = TalentRules.allTalents[index];
        final level = _talentLevels[talent.id] ?? 0;
        final cost = TalentRules.costFor(talent.id, level);
        final maxed = cost == null;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF1F1116),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: level > 0
                  ? const Color(0xFFB16EFF).withValues(alpha: 0.5)
                  : Colors.white12,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      talent.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Text(
                    'Nv.$level/${TalentRules.maxLevel}',
                    style: const TextStyle(
                      color: Color(0xFFFFC93C),
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                talent.description,
                style: const TextStyle(color: Colors.white54, fontSize: 10),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _LevelPips(
                    level: level,
                    max: TalentRules.maxLevel,
                    color: const Color(0xFFB16EFF),
                  ),
                  const Spacer(),
                  Text(
                    maxed
                        ? 'MÁXIMO'
                        : '${cost.gold} oro · ${cost.shards} esquirlas',
                    style: TextStyle(
                      color: maxed ? const Color(0xFF4FFFA3) : Colors.white38,
                      fontSize: 9,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.add_circle,
                      color: maxed ? Colors.white24 : const Color(0xFFB16EFF),
                    ),
                    tooltip: 'Mejorar ${talent.name}',
                    onPressed: maxed ? null : () => _upgradeTalent(talent),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _gearTab(GearLoadout loadout) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF1A0E14),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF3FD8FF)),
          ),
          child: Row(
            children: [
              const Icon(Icons.shield, color: Color(0xFF3FD8FF), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Aura x${loadout.auraDurationMult.toStringAsFixed(2)} · '
                  'Bullseye x${loadout.bullseyeRadiusMult.toStringAsFixed(2)} · '
                  'Regen ${(loadout.lifeRegenFraction * 100).round()}%/piso',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ...SummonerGearRules.allGear.map((piece) {
          final level = _gearLevels[piece.id] ?? 0;
          final cost = SummonerGearRules.costFor(piece.id, level);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1F1116),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: level > 0 ? const Color(0xFF3FD8FF) : Colors.white12,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        piece.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      level <= 0 ? 'NO FORJADA' : 'Nv.$level/5',
                      style: TextStyle(
                        color: level <= 0
                            ? Colors.white38
                            : const Color(0xFFFFC93C),
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${piece.description} (${piece.labelAt(level <= 0 ? 1 : level)})',
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _LevelPips(
                      level: level,
                      max: SummonerGearRules.maxLevel,
                      color: const Color(0xFF3FD8FF),
                    ),
                    const Spacer(),
                    Text(
                      cost == null
                          ? 'MÁXIMO'
                          : '${cost.gold} oro · ${cost.shards} esquirlas',
                      style: TextStyle(
                        color: cost == null
                            ? const Color(0xFF4FFFA3)
                            : Colors.white38,
                        fontSize: 9,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        level <= 0 ? Icons.build_circle : Icons.upgrade,
                        color: cost == null
                            ? Colors.white24
                            : const Color(0xFF3FD8FF),
                      ),
                      tooltip: level <= 0
                          ? 'Forjar ${piece.name}'
                          : 'Mejorar ${piece.name}',
                      onPressed: cost == null ? null : () => _forgeGear(piece),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _LevelPips extends StatelessWidget {
  final int level;
  final int max;
  final Color color;

  const _LevelPips({
    required this.level,
    required this.max,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < max; i++)
          Container(
            width: 12,
            height: 6,
            margin: const EdgeInsets.only(right: 3),
            decoration: BoxDecoration(
              color: i < level ? color : Colors.white12,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}

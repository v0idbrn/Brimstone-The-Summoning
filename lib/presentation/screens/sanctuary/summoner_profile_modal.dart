import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/procedural_sfx_engine.dart';
import '../../../domain/meta/summoner_titles.dart';
import '../../../domain/meta/talent_rules.dart';
import '../../controllers/meta_controller.dart';

/// Modal del Perfil del Invocador: métricas históricas globales y los 12
/// Títulos desbloqueables equipables.
class SummonerProfileModal extends ConsumerStatefulWidget {
  const SummonerProfileModal({super.key});

  @override
  ConsumerState<SummonerProfileModal> createState() =>
      _SummonerProfileModalState();
}

class _SummonerProfileModalState extends ConsumerState<SummonerProfileModal> {
  SummonerStats _stats = SummonerStats.empty;
  Map<String, int> _talentLevels = const {};
  String? _activeTitleId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final repo = ref.read(playerRepositoryProvider);
    final stats = await repo.loadStats();
    final talents = await repo.loadTalentLevels();
    final title = await repo.loadActiveTitle();
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _talentLevels = talents;
      _activeTitleId = title;
      _loading = false;
    });
  }

  Future<void> _equip(SummonerTitle title) async {
    if (!title.isUnlocked(_stats)) return;
    final repo = ref.read(playerRepositoryProvider);
    await repo.saveActiveTitle(title.id);
    if (!mounted) return;
    ProceduralSfxEngine.playOrbMerge(2);
    setState(() => _activeTitleId = title.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Título equipado: ${title.name}'),
        backgroundColor: const Color(0xFFB16EFF),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final equipped = SummonerTitles.resolve(_activeTitleId, _stats);
    final tree = TalentTree(_talentLevels);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: const BoxDecoration(
        color: Color(0xFF14090D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Center(
            child: Text(
              'PERFIL DEL INVOCADOR',
              style: TextStyle(
                color: Color(0xFFB16EFF),
                fontWeight: FontWeight.w900,
                fontSize: 15,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (_loading)
            const SizedBox(
              height: 380,
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFFB16EFF)),
              ),
            )
          else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1A0E14),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFC93C)),
              ),
              child: Column(
                children: [
                  const Text(
                    'TÍTULO EQUIPADO',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 9,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    equipped.name,
                    style: const TextStyle(
                      color: Color(0xFFFFC93C),
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _StatRow(label: 'Combates Ganados', value: '${_stats.combatsWon}'),
            _StatRow(label: 'Jefes Abatidos', value: '${_stats.bossesSlain}'),
            _StatRow(label: 'Golpe Máximo', value: '${_stats.maxHit}'),
            _StatRow(
              label: 'Mayor Racha de Bullseyes',
              value: '${_stats.bestBullseyeStreak}',
            ),
            _StatRow(
              label: 'Reacciones Detonadas',
              value: '${_stats.reactions}',
            ),
            _StatRow(
              label: 'Capítulos',
              value: '${_stats.chaptersCleared}/5',
            ),
            _StatRow(
              label: 'Desafíos del Sello',
              value: '${_stats.challengesCleared}/10',
            ),
            _StatRow(label: 'Cartas', value: '${_stats.cardsOwned}/20'),
            _StatRow(
              label: 'Récord Abismo Sin Fin',
              value: '${_stats.endlessRecord}',
            ),
            _StatRow(
              label: 'Talentos Invertidos',
              value: '${tree.totalLevels}/40',
            ),
            const SizedBox(height: 10),
            const Text(
              'TÍTULOS DESBLOQUEABLES (12)',
              style: TextStyle(
                color: Color(0xFFB16EFF),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 260,
              child: ListView.builder(
                itemCount: SummonerTitles.titles.length,
                itemBuilder: (context, index) {
                  final title = SummonerTitles.titles[index];
                  final unlocked = title.isUnlocked(_stats);
                  final active = title.id == equipped.id;
                  return ListTile(
                    dense: true,
                    title: Text(
                      title.name,
                      style: TextStyle(
                        color: active
                            ? const Color(0xFFFFC93C)
                            : unlocked
                                ? Colors.white
                                : Colors.white38,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    subtitle: Text(
                      unlocked
                          ? title.requirement
                          : title.progressLabel(_stats),
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                      ),
                    ),
                    leading: Icon(
                      active
                          ? Icons.check_circle
                          : unlocked
                              ? Icons.workspace_premium
                              : Icons.lock,
                      color: active
                          ? const Color(0xFFFFC93C)
                          : unlocked
                              ? const Color(0xFFB16EFF)
                              : Colors.white24,
                      size: 18,
                    ),
                    trailing: unlocked && !active
                        ? TextButton(
                            onPressed: () => _equip(title),
                            child: const Text(
                              'EQUIPAR',
                              style: TextStyle(
                                color: Color(0xFFB16EFF),
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          )
                        : null,
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

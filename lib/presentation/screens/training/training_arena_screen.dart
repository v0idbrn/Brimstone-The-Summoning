import 'package:flutter/material.dart' hide Element;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/combat/combat_engine.dart';
import '../../../domain/combat/combat_models.dart';
import '../../../domain/meta/summoner_gear.dart';
import '../../../domain/meta/talent_rules.dart';
import '../../../domain/value_objects/element.dart';
import '../../controllers/meta_controller.dart';
import '../combat/combat_screen.dart';

/// Arena de Entrenamiento: práctica libre contra el Gólem de Pruebas Abisal.
///
/// No cuesta oro ni esquirlas, no otorga recompensas y no guarda récords: sirve
/// para probar mazos, sinergias y runas con un medidor de DPS en vivo y un
/// botón de maná instantáneo.
class TrainingArenaScreen extends ConsumerStatefulWidget {
  const TrainingArenaScreen({super.key});

  @override
  ConsumerState<TrainingArenaScreen> createState() =>
      _TrainingArenaScreenState();
}

class _TrainingArenaScreenState extends ConsumerState<TrainingArenaScreen> {
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
    final talents = await repo.loadTalentLevels();
    final gear = await repo.loadGearLevels();
    await ref.read(collectionProvider.notifier).load();
    if (!mounted) return;
    setState(() {
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
        ),
      );
    }
    if (cards.isNotEmpty) return cards;
    return [
      ManaCard(
        id: 'ignis_hound',
        name: 'Sabueso de Azufre',
        element: Element.igneous,
        baseManaCost: 100,
        attack: 10,
      ),
      ManaCard(
        id: 'abyss_stalker',
        name: 'Acechador de Escarcha',
        element: Element.abyssal,
        baseManaCost: 95,
        attack: 12,
      ),
      ManaCard(
        id: 'terra_golem',
        name: 'Gólem de Basalto',
        element: Element.telluric,
        baseManaCost: 100,
        attack: 8,
      ),
      ManaCard(
        id: 'void_specter',
        name: 'Espectro del Sello',
        element: Element.empty,
        baseManaCost: 110,
        attack: 15,
      ),
    ];
  }

  void _startPractice() {
    final engine = CombatEngine(
      boss: BossConfig.trainingGolem,
      cards: _squadCards(),
      playerMaxHp: 100,
      modifiers: const CombatModifiers(),
      talentLevels: _talents,
      summonerGear: _gear,
      trainingMode: true,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CombatScreen(
          engine: engine,
          showTrainingTools: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tree = TalentTree(_talents);
    final gear = GearLoadout(_gear);
    final squad = _squadCards();
    return Scaffold(
      backgroundColor: const Color(0xFF0C0608),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14090D),
        title: const Text(
          'ARENA DE ENTRENAMIENTO',
          style: TextStyle(
            color: Color(0xFF3FD8FF),
            fontWeight: FontWeight.w900,
            fontSize: 15,
            letterSpacing: 1.4,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF3FD8FF)),
            )
          : ListView(
              padding: const EdgeInsets.all(14),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A0E14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF3FD8FF)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.smart_toy,
                            color: Color(0xFF3FD8FF),
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              BossConfig.trainingGolem.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Maniquí indestructible con 50.000 HP y ataque leve. '
                        'Sin coste, sin recompensas, sin récords.',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _InfoRow(
                        icon: Icons.speed,
                        label: 'Medidor de DPS en vivo en el combate',
                      ),
                      _InfoRow(
                        icon: Icons.bolt,
                        label: 'Botón MANÁ para llenar el maná al instante',
                      ),
                      _InfoRow(
                        icon: Icons.refresh,
                        label: 'REINICIAR para volver a empezar la prueba',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'ESCUADRÓN EN PRUEBA',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                for (final card in squad)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 8,
                          color: switch (card.element) {
                            Element.igneous => const Color(0xFFFF5A26),
                            Element.abyssal => const Color(0xFF3FD8FF),
                            Element.telluric => const Color(0xFFB0703B),
                            Element.empty => const Color(0xFFB16EFF),
                          },
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            card.name,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        Text(
                          'ATK ${card.attack.toInt()}',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A0E14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(
                    'Talentos: ATK x${tree.orbDamageMult.toStringAsFixed(2)} · '
                    'HP x${tree.maxHpMult.toStringAsFixed(2)} · '
                    'Aura x${gear.auraDurationMult.toStringAsFixed(2)} · '
                    'Bullseye x${gear.bullseyeRadiusMult.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF3FD8FF),
                    foregroundColor: const Color(0xFF0C0608),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _startPractice,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text(
                    'INICIAR PRÁCTICA',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 13, color: const Color(0xFF3FD8FF)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}

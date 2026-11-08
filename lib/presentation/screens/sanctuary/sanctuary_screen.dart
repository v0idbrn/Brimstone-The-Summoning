import 'package:flutter/material.dart' hide Element;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/procedural_sfx_engine.dart';
import '../../../domain/meta/squad_synergy_resolver.dart';
import '../../../domain/combat/combat_models.dart';
import '../../controllers/meta_controller.dart';
import '../meta/how_to_play_modal.dart';
import '../meta/widgets.dart';
import '../rift/rift_map_screen.dart';
import '../endless/endless_abyss_screen.dart';
import '../rift/rift_run_notifier.dart';
import 'bounties_modal.dart';
import 'codex_modal.dart';
import 'backup_restore_modal.dart';

/// Main hub: summoner level, currencies, active squad preview, rift difficulty
/// selector and the main play CTA.
class SanctuaryScreen extends ConsumerStatefulWidget {
  const SanctuaryScreen({super.key});

  @override
  ConsumerState<SanctuaryScreen> createState() => _SanctuaryScreenState();
}

class _SanctuaryScreenState extends ConsumerState<SanctuaryScreen> {
  int _difficulty = 1;
  int _highestEndlessWave = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(profileProvider.notifier).load();
      await ref.read(collectionProvider.notifier).load();
      await ref.read(bountyProvider.notifier).load();
      final wave =
          await ref.read(playerRepositoryProvider).loadHighestEndlessWave();
      if (mounted) setState(() => _highestEndlessWave = wave);
    });
  }

  void _toggleAudio() {
    final next = !ProceduralSfxEngine.isMuted;
    ProceduralSfxEngine.setMuted(next);
    ProceduralSfxEngine.playOrbSpawn();
  }

  @override
  Widget build(BuildContext context) {
    final collection = ref.watch(collectionProvider);
    final squad = [
      for (final id in collection.squad.take(4))
        if (collection.owned.any((c) => c.instanceId == id))
          collection.owned.firstWhere((c) => c.instanceId == id),
    ];
    final manaCards = squad
        .map(
          (c) => ManaCard(
            id: c.catalogId,
            name: c.name,
            element: c.element,
            baseManaCost: c.baseManaCost,
            attack: c.baseAttack.toDouble(),
            stars: c.stars,
          ),
        )
        .toList();
    final synergy = SquadSynergyResolver.resolve(manaCards);

    return Scaffold(
      backgroundColor: const Color(0xFF0C0608),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14090D),
        title: const Text(
          'SANTUARIO DEL AZUFRE',
          style: TextStyle(
            color: Color(0xFFB16EFF),
            fontWeight: FontWeight.w900,
            fontSize: 15,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              ProceduralSfxEngine.isMuted ? Icons.volume_off : Icons.volume_up,
              color: ProceduralSfxEngine.isMuted
                  ? Colors.white38
                  : const Color(0xFFB16EFF),
            ),
            onPressed: _toggleAudio,
            tooltip: ProceduralSfxEngine.isMuted
                ? 'Audio activado'
                : 'Audio desactivado',
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.menu_book, color: Color(0xFFB16EFF)),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: const Color(0xFF14090D),
              builder: (_) => const CodexModal(),
            ),
            tooltip: 'Códice Abisal',
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.backup, color: Color(0xFFB16EFF)),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const BackupRestoreModal(),
            ),
            tooltip: 'Backup / Restaurar',
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.military_tech, color: Color(0xFFFFC93C)),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: const Color(0xFF14090D),
              builder: (_) => const BountiesModal(),
            ),
            tooltip: 'Juramentos de Azufre',
          ),
          SizedBox(width: 220, child: const CurrencyBar()),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.help_outline, color: Color(0xFFB16EFF)),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: const Color(0xFF14090D),
              builder: (_) => const HowToPlayModal(),
            ),
            tooltip: 'Cómo jugar',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          const Text(
            'Escuadrón activo',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < 4; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i == 3 ? 0 : 6),
                    child: (i < squad.length)
                        ? CardTileSmall(card: squad[i], raised: true)
                        : Container(
                            height: 84,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: const Center(
                              child: Icon(Icons.add, color: Colors.white24),
                            ),
                          ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Banner de sinergia activa.
          if (synergy.isActive)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A0E14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFB16EFF), width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    color: Color(0xFFB16EFF),
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          synergy.description,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 18),
          const Text(
            'Dificultad de la Grieta',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 1, label: Text('Ceniza Nv.1')),
              ButtonSegment(value: 2, label: Text('Fosa Nv.2')),
              ButtonSegment(value: 3, label: Text('Vacío Nv.3')),
            ],
            selected: {_difficulty},
            onSelectionChanged: (s) => setState(() => _difficulty = s.first),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB16EFF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.local_fire_department),
            label: const Text(
              'DESCENDER A LA GRIETA',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
            ),
            onPressed: () {
              ref.read(riftRunProvider.notifier).startRun(_difficulty);
              Navigator.of(context)
                  .push(
                MaterialPageRoute<void>(
                  builder: (_) => const RiftMapScreen(),
                ),
              )
                  .then((_) {
                // Loot from the finished run lands in the profile.
                final run = ref.read(riftRunProvider);
                if (run != null && (run.gold > 0 || run.shards > 0)) {
                  ref
                      .read(profileProvider.notifier)
                      .grant(gold: run.gold, shards: run.shards);
                }
              });
            },
          ),
          const SizedBox(height: 14),
          // Insignia del récord del Abismo Sin Fin.
          if (_highestEndlessWave > 0)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A0E14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFC93C), width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.emoji_events,
                    color: Color(0xFFFFC93C),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Abismo Sin Fin — Récord',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Oleada máxima alcanzada: $_highestEndlessWave',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF802020),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.rocket_launch),
            label: const Text(
              'ABISMO SIN FIN (ENDLESS)',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const EndlessAbyssScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          const Center(
            child: Text(
              'Forja esferas, invoca cartas, evoluciona tu escuadrón y sella la Grieta.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white24, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

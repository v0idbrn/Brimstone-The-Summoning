import 'package:flutter/material.dart' hide Element;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/meta_controller.dart';
import '../meta/widgets.dart';
import '../rift/rift_map_screen.dart';
import '../rift/rift_run_notifier.dart';

/// Main hub: summoner level, currencies, active squad preview, rift difficulty
/// selector and the main play CTA.
class SanctuaryScreen extends ConsumerStatefulWidget {
  const SanctuaryScreen({super.key});

  @override
  ConsumerState<SanctuaryScreen> createState() => _SanctuaryScreenState();
}

class _SanctuaryScreenState extends ConsumerState<SanctuaryScreen> {
  int _difficulty = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(profileProvider.notifier).load();
      await ref.read(collectionProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final collection = ref.watch(collectionProvider);
    final squad = [
      for (final id in collection.squad.take(4))
        if (collection.owned.any((c) => c.instanceId == id))
          collection.owned.firstWhere((c) => c.instanceId == id),
    ];

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
        actions: [SizedBox(width: 220, child: const CurrencyBar())],
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

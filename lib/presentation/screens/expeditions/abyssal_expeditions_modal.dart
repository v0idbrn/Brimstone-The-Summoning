import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:brimstone_summoning/core/audio/procedural_sfx_engine.dart';
import 'package:brimstone_summoning/domain/meta/abyssal_expeditions.dart';
import 'package:brimstone_summoning/domain/entities/owned_card.dart';
import 'package:brimstone_summoning/presentation/controllers/meta_controller.dart';
import 'package:brimstone_summoning/presentation/widgets/brimstone_button.dart';

/// Modal de Expediciones Abisales (Pilar 6, Etapa III).
class AbyssalExpeditionsModal extends ConsumerStatefulWidget {
  const AbyssalExpeditionsModal({super.key});

  @override
  ConsumerState<AbyssalExpeditionsModal> createState() =>
      _AbyssalExpeditionsModalState();
}

class _AbyssalExpeditionsModalState
    extends ConsumerState<AbyssalExpeditionsModal> {
  late Timer _timer;
  List<ExpeditionSlot> _slots = [];
  List<OwnedCard> _bench = [];

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _tick() => setState(() {});

  Future<void> _load() async {
    final repo = ref.read(playerRepositoryProvider);
    final collection = ref.read(collectionProvider);
    final slots = await repo.loadExpeditionSlots();
    final squadIds = collection.squad.toSet();
    final bench = collection.owned
        .where((c) => !squadIds.contains(c.instanceId))
        .toList();
    if (mounted) {
      setState(() {
        _slots = slots;
        _bench = bench;
      });
    }
  }

  Future<void> _send(String missionId, List<int> instanceIds) async {
    final repo = ref.read(playerRepositoryProvider);
    final now = DateTime.now().millisecondsSinceEpoch;
    await repo.startExpedition(missionId, instanceIds, now);
    ProceduralSfxEngine.playUIHeavyClick();
    _load();
  }

  Future<void> _claim(String missionId, int cardCount) async {
    final repo = ref.read(playerRepositoryProvider);
    final mission = missionById(missionId);
    final (gold, shards, _) = expeditionRewardFor(mission, cardCount);
    await repo.clearExpedition(missionId);
    await ref.read(profileProvider.notifier).grant(gold: gold, shards: shards);
    ProceduralSfxEngine.playChestOpen();
    _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Reclamado: +$gold oro, +$shards esquirlas'),
        backgroundColor: const Color(0xFF4FFFA3),
      ));
    }
  }

  String _fmt(int ms) {
    if (ms <= 0) return '0s';
    final h = ms ~/ 3600000;
    final m = (ms % 3600000) ~/ 60000;
    final s = (ms % 60000) ~/ 1000;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF14090D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: SingleChildScrollView(
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
            Row(
              children: [
                const Icon(Icons.auto_stories,
                    color: Color(0xFFB16EFF), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('EXPEDICIONES ABISALES',
                      style: const TextStyle(
                          color: Color(0xFFB16EFF),
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          letterSpacing: 1)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text('Suplentes fuera del escuadrón',
                style: TextStyle(color: Colors.white54, fontSize: 11)),
            const SizedBox(height: 16),
            ..._slots.map((slot) => _MissionTile(
                  slot: slot,
                  bench: _bench,
                  onSend: (ids) => _send(slot.missionId, ids),
                  onClaim: (count) => _claim(slot.missionId, count),
                  fmt: _fmt,
                )),
          ],
        ),
      ),
    );
  }
}

class _MissionTile extends StatelessWidget {
  final ExpeditionSlot slot;
  final List<OwnedCard> bench;
  final void Function(List<int>) onSend;
  final void Function(int) onClaim;
  final String Function(int) fmt;

  const _MissionTile({
    required this.slot,
    required this.bench,
    required this.onSend,
    required this.onClaim,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final mission = missionById(slot.missionId);
    final now = DateTime.now().millisecondsSinceEpoch;
    final isActive = slot.isActive;
    final isComplete = slot.isComplete(now);
    final remaining = slot.remainingMs(now);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0E14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isActive
                ? (isComplete
                    ? const Color(0xFF4FFFA3)
                    : const Color(0xFF3FD8FF))
                : Colors.white12,
            width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mission.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13)),
                    Text(mission.description,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 10)),
                  ],
                ),
              ),
              if (isActive)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isComplete
                        ? const Color(0xFF4FFFA3).withValues(alpha: 0.2)
                        : const Color(0xFF3FD8FF).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isComplete ? '¡DE VUELTA!' : 'EN RUTA ${fmt(remaining)}',
                    style: TextStyle(
                      color: isComplete
                          ? const Color(0xFF4FFFA3)
                          : const Color(0xFF3FD8FF),
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (!isActive) ...[
            _BenchSelector(
              bench: bench,
              maxSelect: 4,
              onSelected: onSend,
            ),
          ] else if (isComplete) ...[
            SizedBox(
              width: double.infinity,
              child: BrimstoneButton(
                label: 'RECLAMAR',
                onPressed: () => onClaim(slot.cardInstanceIds.length),
                isSecondary: true,
              ),
            ),
          ] else ...[
            LinearProgressIndicator(
              value: 1.0 - remaining / mission.duration.millis,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation(Color(0xFF3FD8FF)),
              minHeight: 4,
            ),
            const SizedBox(height: 6),
            Text('Tiempo restante: ${fmt(remaining)}',
                style: const TextStyle(color: Colors.white38, fontSize: 10)),
            if (slot.cardInstanceIds.isNotEmpty)
              Text('Cartas: ${slot.cardInstanceIds.length}',
                  style: const TextStyle(color: Colors.white54, fontSize: 10)),
          ],
        ],
      ),
    );
  }
}

class _BenchSelector extends ConsumerStatefulWidget {
  final List<OwnedCard> bench;
  final int maxSelect;
  final void Function(List<int>) onSelected;

  const _BenchSelector({
    required this.bench,
    required this.maxSelect,
    required this.onSelected,
  });

  @override
  ConsumerState<_BenchSelector> createState() => _BenchSelectorState();
}

class _BenchSelectorState extends ConsumerState<_BenchSelector> {
  final Set<int> _selected = {};

  void _toggle(int id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else if (_selected.length < widget.maxSelect) {
        _selected.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.bench.isEmpty) {
      return const Text('No hay suplentes disponibles.',
          style: TextStyle(color: Colors.white38, fontSize: 11));
    }
    return Column(
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: widget.bench.map((c) {
            final sel = _selected.contains(c.instanceId);
            return FilterChip(
              selected: sel,
              onSelected: (_) => _toggle(c.instanceId),
              label: Text(c.name,
                  style: TextStyle(
                      color: sel ? Colors.black : Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
              backgroundColor: const Color(0xFF1A0E14),
              selectedColor: const Color(0xFFB16EFF),
              checkmarkColor: Colors.black,
              side: BorderSide(
                  color: sel ? const Color(0xFFB16EFF) : Colors.white12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: BrimstoneButton(
            label: 'ENVIAR (${_selected.length}/${widget.maxSelect})',
            onPressed: _selected.isEmpty
                ? null
                : () => widget.onSelected(_selected.toList()),
          ),
        ),
      ],
    );
  }
}

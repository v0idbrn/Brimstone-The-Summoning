import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// import 'package:brimstone_summoning/core/audio/procedural_sfx_engine.dart';
import 'package:brimstone_summoning/domain/meta/battle_log.dart';
import 'package:brimstone_summoning/presentation/controllers/meta_controller.dart';

/// Modal del Historial de Batallas (Pilar 10, Etapa III).
class BattleLogModal extends ConsumerWidget {
  const BattleLogModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        child: _BattleLogContent(),
      ),
    );
  }
}

class _BattleLogContent extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(playerRepositoryProvider);
    return FutureBuilder<List<BattleLogEntry>>(
      future: repo.loadBattleLog(),
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(
              child: Padding(
            padding: EdgeInsets.all(40),
            child: CircularProgressIndicator(color: Color(0xFFB16EFF)),
          ));
        }
        final log = snap.data ?? [];
        if (log.isEmpty) {
          return Column(
            mainAxisSize: MainAxisSize.min,
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
              const SizedBox(height: 20),
              const Text('HISTORIAL DE BATALLAS',
                  style: TextStyle(
                      color: Color(0xFFB16EFF),
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      letterSpacing: 1)),
              const SizedBox(height: 16),
              const Text('Aún no hay batallas registradas.',
                  style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 40),
            ],
          );
        }

        return Column(
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
                const Icon(Icons.history, color: Color(0xFFB16EFF), size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('HISTORIAL DE BATALLAS',
                      style: TextStyle(
                          color: Color(0xFFB16EFF),
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          letterSpacing: 1)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Últimas ${BattleLogEntry.historyLimit} batallas',
                style: const TextStyle(color: Colors.white54, fontSize: 11)),
            const SizedBox(height: 16),
            if (log.isNotEmpty) ...[
              _DamageBreakdownCard(entry: log.first),
              const SizedBox(height: 16),
            ],
            const Text('REGISTRO',
                style: TextStyle(
                    color: Color(0xFF3FD8FF),
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 1)),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: log.length,
              itemBuilder: (_, i) => _LogTile(entry: log[i]),
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
}

class _DamageBreakdownCard extends StatelessWidget {
  final BattleLogEntry entry;

  const _DamageBreakdownCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final total = entry.damageByCard.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();

    final sorted = entry.damageByCard.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0E14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFB16EFF), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart, color: Color(0xFFB16EFF), size: 16),
              const SizedBox(width: 6),
              const Text('APORTE DE DAÑO',
                  style: TextStyle(
                      color: Color(0xFFB16EFF),
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 0.5)),
              const Spacer(),
              if (entry.mvpCardId.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC93C),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('★ MVP ${entry.mvpCardId}',
                      style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 9)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ...sorted.map((e) => _DamageBar(
                cardId: e.key,
                damage: e.value,
                total: total,
                isMvp: e.key == entry.mvpCardId,
              )),
        ],
      ),
    );
  }
}

class _DamageBar extends StatelessWidget {
  final String cardId;
  final int damage;
  final int total;
  final bool isMvp;

  const _DamageBar({
    required this.cardId,
    required this.damage,
    required this.total,
    required this.isMvp,
  });

  @override
  Widget build(BuildContext context) {
    final pct = damage / total;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(cardId,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: isMvp ? const Color(0xFFFFC93C) : Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: pct.clamp(0.0, 1.0),
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: isMvp
                          ? const Color(0xFFFFC93C)
                          : const Color(0xFFB16EFF),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 55,
            child: Text('${(pct * 100).round()}%  $damage',
                textAlign: TextAlign.right,
                style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                    fontSize: 10)),
          ),
        ],
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  final BattleLogEntry entry;

  const _LogTile({required this.entry});

  String _fmt(int epochMs) {
    final dt = DateTime.fromMillisecondsSinceEpoch(epochMs, isUtc: true);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} '
        '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0E14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: entry.victory ? const Color(0xFF4FFFA3) : Colors.redAccent,
            width: entry.victory ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(entry.enemyName,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: entry.victory
                      ? const Color(0xFF4FFFA3).withValues(alpha: 0.2)
                      : Colors.redAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  entry.victory ? 'VICTORIA' : 'DERROTA',
                  style: TextStyle(
                      color: entry.victory
                          ? const Color(0xFF4FFFA3)
                          : Colors.redAccent,
                      fontWeight: FontWeight.w900,
                      fontSize: 9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(_fmt(entry.epochMs),
                  style: const TextStyle(color: Colors.white54, fontSize: 10)),
              const SizedBox(width: 12),
              if (entry.mvpCardId.isNotEmpty)
                Text('★ MVP: ${entry.mvpCardId}',
                    style: const TextStyle(
                        color: Color(0xFFFFC93C),
                        fontWeight: FontWeight.w800,
                        fontSize: 10)),
              const Spacer(),
              Text('DMG: ${entry.damageTotal}',
                  style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w700,
                      fontSize: 10)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
              'Max: ${entry.maxHit}  •  Bullseyes: ${entry.bullseyes}  •  Contraesquirlas: ${entry.counterflicks}  •  HP: ${entry.playerHpLeft}',
              style: const TextStyle(color: Colors.white38, fontSize: 9)),
        ],
      ),
    );
  }
}

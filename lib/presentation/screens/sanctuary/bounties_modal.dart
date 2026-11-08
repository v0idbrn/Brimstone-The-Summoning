import 'package:flutter/material.dart' hide Element;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/meta_controller.dart';

/// Bounties modal (Juramentos de Azufre): 6 missions tracked in SQLite with
/// shard/gold rewards claimable when complete.
class BountiesModal extends ConsumerStatefulWidget {
  const BountiesModal({super.key});

  @override
  ConsumerState<BountiesModal> createState() => _BountiesModalState();
}

class _BountiesModalState extends ConsumerState<BountiesModal> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(bountyProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bounties = ref.watch(bountyProvider);
    final active = activeBounties(bounties);
    final claimable = claimableBounties(bounties);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF14090D),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          border: Border.all(
            color: const Color(0xFFFFC93C).withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 6),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'JURAMENTOS DE AZUFRE',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFFFFC93C),
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${claimable.length} para reclamar',
                    style: const TextStyle(
                      color: Color(0xFFFFC93C),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (claimable.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.redeem,
                      color: Color(0xFFFFC93C),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Tienes ${claimable.length} juramento(s) listo(s) para reclamar.',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.builder(
                controller: controller,
                padding: const EdgeInsets.all(12),
                itemCount: active.length,
                itemBuilder: (context, i) {
                  final b = active[i];
                  final complete = b.isComplete;
                  return _BountyRow(bounty: b, complete: complete);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Single bounty row with progress bar and claim button.
class _BountyRow extends ConsumerWidget {
  final Bounty bounty;
  final bool complete;

  const _BountyRow({required this.bounty, required this.complete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pct = (bounty.progress / bounty.target).clamp(0.0, 1.0);
    final canClaim = bounty.isClaimable;
    final kindLabel = switch (bounty.kind) {
      'merge_to_three' => 'FUSIONES N3',
      'bullseye_hits' => 'BULLSEYES',
      'reactions' => 'REACCIONES',
      'counterflicks' => 'CONTRA-FLICKS',
      'evolution' => 'EVOLUCIONES',
      'rift_clear' => 'GRIETA P7',
      _ => bounty.kind.toUpperCase(),
    };

    return Card(
      color: const Color(0xFF1F1116),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            bounty.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (complete)
                            const Icon(
                              Icons.check_circle,
                              color: Color(0xFFFFC93C),
                              size: 18,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        kindLabel,
                        style: const TextStyle(
                          color: Color(0xFFFFC93C),
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        bounty.description,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Text(
                  '${bounty.progress} / ${bounty.target}',
                  style: TextStyle(
                    color: complete ? const Color(0xFFFFC93C) : Colors.white38,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation(
                  complete ? const Color(0xFFFFC93C) : const Color(0xFFB16EFF),
                ),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.stars, color: Color(0xFF80E8FF), size: 16),
                const SizedBox(width: 4),
                Text(
                  '${bounty.rewardShards}',
                  style: const TextStyle(
                    color: Color(0xFF80E8FF),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (bounty.rewardGold > 0) ...[
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.monetization_on,
                    color: Color(0xFFFFC93C),
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${bounty.rewardGold}',
                    style: const TextStyle(
                      color: Color(0xFFFFC93C),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                const Spacer(),
                if (canClaim)
                  FilledButton.tonal(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final ok = await ref
                          .read(bountyProvider.notifier)
                          .claim(bounty.id);
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            ok
                                ? '¡Reclamado: ${bounty.title}!'
                                : 'No se pudo reclamar.',
                          ),
                        ),
                      );
                    },
                    child: const Text('RECLAMAR'),
                  )
                else if (complete)
                  const Text(
                    'LISTO PARA RECLAMAR',
                    style: TextStyle(
                      color: Color(0xFFFFC93C),
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  )
                else
                  Text(
                    'En progreso',
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

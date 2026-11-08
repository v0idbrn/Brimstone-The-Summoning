import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/roguelite/relic_catalog.dart';

/// Post-combat reward: pick 1 of 3 abyssal relics not yet owned.
class RelicDraftModal extends StatelessWidget {
  final List<String> offerings;
  final ValueChanged<String> onPick;

  const RelicDraftModal({
    super.key,
    required this.offerings,
    required this.onPick,
  });

  /// Builds 3 distinct offerings from the catalog excluding owned ones.
  static List<String> buildOfferings(
    List<String> ownedIds,
    math.Random? random,
  ) {
    final pool = RelicCatalog.all
        .map((r) => r.id)
        .where((id) => !ownedIds.contains(id))
        .toList();
    if (random != null) pool.shuffle(random);
    return pool.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        color: Color(0xFF14090D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'RELIQUIA ABISAL',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFB16EFF),
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Elige una reliquia para tu incursión',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 12),
          for (final id in offerings) ...[
            _RelicCard(meta: RelicCatalog.byId(id), onPick: () => onPick(id)),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _RelicCard extends StatelessWidget {
  final RelicMeta meta;
  final VoidCallback onPick;

  const _RelicCard({required this.meta, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF2A1116),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFB16EFF).withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Color(0xFFB16EFF)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meta.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      meta.description,
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
      ),
    );
  }
}

/// The blood altar decisions before the abyssal boss.
class BloodAltarModal extends StatelessWidget {
  final List<String> ownedRelicIds;
  final VoidCallback onHeal;
  final void Function(List<String> offerings) onSacrifice;
  final VoidCallback onManaBoost;

  const BloodAltarModal({
    super.key,
    required this.ownedRelicIds,
    required this.onHeal,
    required this.onSacrifice,
    required this.onManaBoost,
  });

  @override
  Widget build(BuildContext context) {
    final offerings = RelicDraftModal.buildOfferings(
      ownedRelicIds,
      math.Random(7),
    );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        color: Color(0xFF14090D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'ALTAR DE SANGRE',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFFF5A26),
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          _AltarOption(
            title: 'Ofrenda de vida',
            subtitle: 'Restaura el 40% de tu vida máxima',
            color: Colors.greenAccent,
            onTap: onHeal,
          ),
          _AltarOption(
            title: 'Sacrificio de sangre',
            subtitle:
                'Pierde 12% de tu vida actual y obtén una reliquia + 150 oro',
            color: const Color(0xFFB16EFF),
            onTap: () => onSacrifice(offerings),
          ),
          _AltarOption(
            title: 'Resonancia de maná',
            subtitle:
                'El próximo combate empieza con 50% de maná en todas tus cartas',
            color: const Color(0xFF3FD8FF),
            onTap: onManaBoost,
          ),
        ],
      ),
    );
  }
}

class _AltarOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _AltarOption({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF2A1116),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Icon(Icons.emoji_events, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
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
        ),
      ),
    );
  }
}

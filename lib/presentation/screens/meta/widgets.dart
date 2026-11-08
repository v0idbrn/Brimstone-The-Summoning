import 'package:flutter/material.dart' hide Element;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/owned_card.dart';
import '../../../domain/value_objects/element.dart';
import '../../../domain/value_objects/rarity.dart';
import '../../controllers/meta_controller.dart';

/// Shared visual helpers for the gothic meta screens.
Color elementColor(Element e) => switch (e) {
      Element.igneous => const Color(0xFFFF5A26),
      Element.abyssal => const Color(0xFF3FD8FF),
      Element.telluric => const Color(0xFFB0703B),
      Element.empty => const Color(0xFFB16EFF),
    };

Color rarityColor(Rarity r) => switch (r) {
      Rarity.common => const Color(0xFF9AA4A8),
      Rarity.rare => const Color(0xFF4FC3F7),
      Rarity.epic => const Color(0xFFB16EFF),
      Rarity.legendary => const Color(0xFFFFC93C),
      Rarity.mythic => const Color(0xFFFF5A26),
    };

/// Compact card tile reused by squad preview, barracks and evolution altar.
class CardTileSmall extends StatelessWidget {
  final OwnedCard card;
  final VoidCallback? onTap;
  final bool raised;

  const CardTileSmall({
    super.key,
    required this.card,
    this.onTap,
    this.raised = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = elementColor(card.element);
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 0.74,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A0E14),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: rarityColor(card.rarity),
              width: raised ? 2.4 : 1.6,
            ),
            boxShadow: card.stars >= 4
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.5),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    for (var s = 0; s < card.stars; s++)
                      const Icon(Icons.star, size: 9, color: Color(0xFFFFC93C)),
                    const Spacer(),
                    Text(
                      'Nv.${card.level}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 8,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.85),
                      border: Border.all(color: Colors.white70),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 2, right: 2),
                child: Text(
                  card.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Currency row shown in the app bar of every meta screen.
class CurrencyBar extends ConsumerWidget {
  const CurrencyBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _cu(
            icon: Icons.workspace_premium,
            color: const Color(0xFFB16EFF),
            label: 'Nv.${profile.summonerLevel}',
          ),
          _cu(
            icon: Icons.monetization_on,
            color: Colors.amber,
            label: '${profile.gold}',
          ),
          _cu(
            icon: Icons.diamond,
            color: const Color(0xFF3FD8FF),
            label: '${profile.shards}',
          ),
          _cu(
            icon: Icons.bolt,
            color: Colors.greenAccent,
            label: '${profile.energy}',
          ),
        ],
      ),
    );
  }

  static Widget _cu({
    required IconData icon,
    required Color color,
    required String label,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 2),
            Text(label, style: TextStyle(color: color, fontSize: 10)),
          ],
        ),
      );
}

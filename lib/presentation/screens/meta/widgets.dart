import 'package:flutter/material.dart' hide Element;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/owned_card.dart';
import '../../../domain/value_objects/element.dart';
import '../../../domain/value_objects/rarity.dart';
import '../../controllers/meta_controller.dart';
import '../../widgets/tcg_card_widget.dart';

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
/// Backed by high-fidelity master [TcgCardWidget].
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
    return AspectRatio(
      aspectRatio: 0.72,
      child: TcgCardWidget.fromOwnedCard(
        card: card,
        onTap: onTap,
        raised: raised,
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

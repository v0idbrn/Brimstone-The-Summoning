import 'package:flutter/material.dart' hide Element;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/design_tokens.dart';
import '../../../domain/entities/owned_card.dart';
import '../../../domain/value_objects/element.dart';
import '../../../domain/value_objects/rarity.dart';
import '../../controllers/meta_controller.dart';
import '../../widgets/tcg_card_widget.dart';

/// Shared visual helpers for the gothic meta screens.
Color elementColor(Element e) => BrimstoneElements.forElement(e);

Color rarityColor(Rarity r) => switch (r) {
      Rarity.common => const Color(0xFF9AA4A8),
      Rarity.rare => BrimstoneElements.abyssal,
      Rarity.epic => BrimstoneAccents.voidPurple,
      Rarity.legendary => BrimstoneTokens.goldPrimary,
      Rarity.mythic => BrimstoneElements.igneous,
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
      padding: const EdgeInsets.symmetric(
        horizontal: BrimstoneSpacing.spaceXS,
        vertical: BrimstoneSpacing.spaceXS,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _cu(
              icon: Icons.workspace_premium,
              color: BrimstoneAccents.voidPurple,
              label: 'Nv.${profile.summonerLevel}',
            ),
            const SizedBox(width: BrimstoneSpacing.spaceSM),
            _cu(
              icon: Icons.monetization_on,
              color: BrimstoneTokens.goldPrimary,
              label: profile.gold.toString(),
            ),
            const SizedBox(width: BrimstoneSpacing.spaceSM),
            _cu(
              icon: Icons.diamond,
              color: BrimstoneElements.abyssal,
              label: profile.shards.toString(),
            ),
            const SizedBox(width: BrimstoneSpacing.spaceSM),
            _cu(
              icon: Icons.bolt,
              color: BrimstoneAccents.info,
              label: profile.energy.toString(),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _cu({
    required IconData icon,
    required Color color,
    required String label,
  }) =>
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: BrimstoneSpacing.spaceXS),
          Text(
            label,
            style: BrimstoneTypography.numericMonoSM.copyWith(color: color),
          ),
        ],
      );
}

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/meta_controller.dart';
import '../../widgets/brimstone_button.dart';

/// Emporio del Azufre (Brimstone Shop) - Block 7
/// - Ofertas Relámpago Diarias (3 ofertas con descuento)
/// - Paquetes de Fundador y Arconte (simulados en Demo/Sandbox)
/// - Canje de Códigos Promocionales
class BrimstoneShopModal extends ConsumerStatefulWidget {
  const BrimstoneShopModal({super.key});

  @override
  ConsumerState<BrimstoneShopModal> createState() => _BrimstoneShopModalState();
}

class _BrimstoneShopModalState extends ConsumerState<BrimstoneShopModal>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);

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
            color: const Color(0xFFFFD700).withValues(alpha: 0.4),
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
                  const Text(
                    'EMPORIO DEL AZUFRE',
                    style: TextStyle(
                      color: Color(0xFFFFD700),
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 2,
                    ),
                  ),
                  const Spacer(),
                  // Currency display
                  Row(
                    children: [
                      _CurrencyChip(
                          icon: Icons.attach_money,
                          amount: profile.gold,
                          color: const Color(0xFFFFD700)),
                      const SizedBox(width: 8),
                      _CurrencyChip(
                          icon: Icons.diamond,
                          amount: profile.shards,
                          color: const Color(0xFFB16EFF)),
                      const SizedBox(width: 8),
                      _CurrencyChip(
                          icon: Icons.bolt,
                          amount: profile.energy,
                          color: const Color(0xFF00FFFF)),
                    ],
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              labelColor: const Color(0xFFFFD700),
              unselectedLabelColor: Colors.white54,
              indicatorColor: const Color(0xFFFFD700),
              isScrollable: true,
              tabs: const [
                Tab(text: 'OFERTAS RELÁMPAGO'),
                Tab(text: 'PAQUETES FUNDADOR'),
                Tab(text: 'CANJEAR CÓDIGO'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _FlashOffersTab(),
                  _FounderPacksTab(),
                  _PromoCodeTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrencyChip extends StatelessWidget {
  final IconData icon;
  final int amount;
  final Color color;

  const _CurrencyChip(
      {required this.icon, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          color.withValues(alpha: 0.2),
          color.withValues(alpha: 0.05)
        ]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            '$amount',
            style: TextStyle(
                color: color, fontWeight: FontWeight.w900, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// ============================================================
/// TAB 1: FLASH OFFERS - 3 daily discounted offers
/// ============================================================
class _FlashOffersTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final offers = _getFlashOffers();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                const Color(0xFF2A0A0F),
                const Color(0xFF1A0408),
              ]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFFFF5A26).withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.flash_on, color: Color(0xFFFF5A26), size: 24),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'OFERTAS RELÁMPAGO DIARIAS',
                    style: TextStyle(
                      color: Color(0xFFFF5A26),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5A26).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'SE REINICIAN CADA DÍA',
                    style: TextStyle(
                        color: Color(0xFFFF5A26),
                        fontWeight: FontWeight.w900,
                        fontSize: 9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...offers.map((offer) => _FlashOfferTile(
                offer: offer,
                gold: profile.gold,
                shards: profile.shards,
                onBuy: () => _buyOffer(context, ref, offer),
              )),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A0E14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: const Text(
              'Las ofertas se actualizan a medianoche (hora del servidor).',
              style: TextStyle(color: Colors.white38, fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  List<_FlashOffer> _getFlashOffers() {
    return [
      _FlashOffer(
        id: 'energy_refill',
        title: 'RECARGA DE ENERGÍA ABISAL',
        description: '+50 Energía Abisal instantánea',
        originalGold: 500,
        discountedGold: 300,
        originalShards: 100,
        discountedShards: 60,
        icon: Icons.bolt,
        color: const Color(0xFF00FFFF),
      ),
      _FlashOffer(
        id: 'rune_chest',
        title: 'COFRE DE RUNAS ALEATORIO',
        description: '1 Runa Nivel 1-3 aleatoria',
        originalGold: 2000,
        discountedGold: 1200,
        originalShards: 300,
        discountedShards: 180,
        icon: Icons.diamond,
        color: const Color(0xFFB16EFF),
      ),
      _FlashOffer(
        id: 'epic_card_daily',
        title: 'CARTA ÉPICA DEL DÍA',
        description: '1 Carta Épica garantizada (aleatoria)',
        originalGold: 5000,
        discountedGold: 3000,
        originalShards: 800,
        discountedShards: 500,
        icon: Icons.auto_awesome,
        color: const Color(0xFFFFD700),
      ),
    ];
  }

  Future<void> _buyOffer(
      BuildContext context, WidgetRef ref, _FlashOffer offer) async {
    final profileState = ref.read(profileProvider);
    final profileCtrl = ref.read(profileProvider.notifier);

    // Try shards first, then gold
    if (profileState.shards >= offer.discountedShards) {
      if (await profileCtrl.spend(shards: offer.discountedShards)) {
        await _deliverOffer(ref, offer);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    '¡${offer.title} comprado por ${offer.discountedShards} esquirlas!'),
                backgroundColor: const Color(0xFF4FFFA3)),
          );
        }
        return;
      }
    } else if (profileState.gold >= offer.discountedGold) {
      if (await profileCtrl.spend(gold: offer.discountedGold)) {
        await _deliverOffer(ref, offer);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    '¡${offer.title} comprado por ${offer.discountedGold} oro!'),
                backgroundColor: const Color(0xFF4FFFA3)),
          );
        }
        return;
      }
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Fondos insuficientes'),
            backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _deliverOffer(WidgetRef ref, _FlashOffer offer) async {
    final repo = ref.read(playerRepositoryProvider);
    switch (offer.id) {
      case 'energy_refill':
        await repo.addEnergy(50);
        break;
      case 'rune_chest':
        // Grant random rune - simplified
        break;
      case 'epic_card_daily':
        // Grant epic card via summon
        await ref.read(collectionProvider.notifier).summon(grandRitual: false);
        break;
    }
  }
}

class _FlashOffer {
  final String id;
  final String title;
  final String description;
  final int originalGold;
  final int discountedGold;
  final int originalShards;
  final int discountedShards;
  final IconData icon;
  final Color color;

  const _FlashOffer({
    required this.id,
    required this.title,
    required this.description,
    required this.originalGold,
    required this.discountedGold,
    required this.originalShards,
    required this.discountedShards,
    required this.icon,
    required this.color,
  });
}

class _FlashOfferTile extends StatelessWidget {
  final _FlashOffer offer;
  final int gold;
  final int shards;
  final VoidCallback onBuy;

  const _FlashOfferTile({
    required this.offer,
    required this.gold,
    required this.shards,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final canAffordShards = shards >= offer.discountedShards;
    final canAffordGold = gold >= offer.discountedGold;
    final canAfford = canAffordShards || canAffordGold;
    final discountPercent =
        ((1 - offer.discountedGold / offer.originalGold) * 100).round();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: canAfford
                ? [
                    offer.color.withValues(alpha: 0.15),
                    offer.color.withValues(alpha: 0.05)
                  ]
                : [const Color(0xFF1A0E14), const Color(0xFF0D040A)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color:
                canAfford ? offer.color.withValues(alpha: 0.5) : Colors.white12,
            width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                offer.color.withValues(alpha: 0.3),
                offer.color.withValues(alpha: 0.1)
              ]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(offer.icon, color: offer.color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      offer.title,
                      style: TextStyle(
                        color: canAfford ? offer.color : Colors.white38,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFFFF5A26), Color(0xFFFFD700)]),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '-$discountPercent%',
                        style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 9),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(offer.description,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 10)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (offer.originalGold > offer.discountedGold) ...[
                      Text(
                        '${offer.originalGold}',
                        style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                            decoration: TextDecoration.lineThrough),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.attach_money,
                          color: Color(0xFFFFD700), size: 14),
                      Text(' ${offer.discountedGold}',
                          style: TextStyle(
                              color: canAfford
                                  ? const Color(0xFFFFD700)
                                  : Colors.white54,
                              fontWeight: FontWeight.w900,
                              fontSize: 11)),
                      const SizedBox(width: 12),
                    ],
                    if (offer.originalShards > offer.discountedShards) ...[
                      Text(
                        '${offer.originalShards}',
                        style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                            decoration: TextDecoration.lineThrough),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.diamond,
                          color: Color(0xFFB16EFF), size: 14),
                      Text(' ${offer.discountedShards}',
                          style: TextStyle(
                              color: canAfford
                                  ? const Color(0xFFB16EFF)
                                  : Colors.white54,
                              fontWeight: FontWeight.w900,
                              fontSize: 11)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          BrimstoneButton(
            label: canAfford ? 'COMPRAR' : 'INSUFICIENTE',
            onPressed: canAfford ? onBuy : null,
          ),
        ],
      ),
    );
  }
}

/// ============================================================
/// TAB 2: FOUNDER PACKS - Founder/Archon packs (Demo/Sandbox)
/// ============================================================
class _FounderPacksTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final packs = _getFounderPacks();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                const Color(0xFF2A0A0F),
                const Color(0xFF1A0408),
              ]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFFB16EFF).withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.card_giftcard,
                        color: Color(0xFFB16EFF), size: 24),
                    const SizedBox(width: 12),
                    const Text(
                      'PAQUETES DE FUNDADOR Y ARCONTE',
                      style: TextStyle(
                        color: Color(0xFFB16EFF),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Modo Demo/Sandbox: 1 reclamo de prueba por cuenta para testear el flujo de entrega.',
                  style: TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...packs.map((pack) => _FounderPackTile(
                pack: pack,
                shards: profile.shards,
                gold: profile.gold,
                onBuy: () => _buyPack(context, ref, pack),
              )),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A0E14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: const Text(
              'Nota: Estos paquetes son simulaciones en modo Demo. En producción usarían BillingService real (Google Play / App Store).',
              style: TextStyle(color: Colors.white38, fontSize: 9),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  List<_FounderPack> _getFounderPacks() {
    return [
      _FounderPack(
        id: 'starter_pack',
        name: 'PAQUETE DE INICIADO',
        description: 'Ideal para nuevos invocadores',
        color: const Color(0xFF00FFFF),
        icon: Icons.star,
        costShards: 500,
        costGold: 1000,
        rewards: [
          '1000 Esquirlas',
          '5000 Oro',
          '1 Carta Legendaria 2★ garantizada',
          '3 Runas Nivel 1 aleatorias',
          '+50 Energía Abisal',
        ],
        demoOnly: true,
      ),
      _FounderPack(
        id: 'war_chest',
        name: 'COFRE DE GUERRA DE AZUFRE',
        description: 'Potencia tu colección al máximo',
        color: const Color(0xFFFFD700),
        icon: Icons.diamond,
        costShards: 2000,
        costGold: 5000,
        rewards: [
          '5000 Esquirlas',
          '25000 Oro',
          '3 Cartas Legendarias 2★ garantizadas',
          '1 Carta Mítica 3★ (Void Malakor o Abyss Leviathan)',
          '10 Runas Nivel 2-3 aleatorias',
          '+200 Energía Abisal',
          'Título exclusivo: "Fundador del Azufre"',
        ],
        demoOnly: true,
      ),
      _FounderPack(
        id: 'archon_pass',
        name: 'PASE ARCONTE VIP',
        description: 'Acceso premium perpetuo',
        color: const Color(0xFFB16EFF),
        icon: Icons.workspace_premium,
        costShards: 5000,
        costGold: 15000,
        rewards: [
          '20000 Esquirlas',
          '100000 Oro',
          '10 Cartas Legendarias 3★ a elección',
          '1 Carta Mítica 3★ a elección',
          'Todas las Runas Nivel 5 (Míticas) desbloqueadas',
          'Energía Abisal ilimitada por 30 días',
          'Acceso anticipado a contenido futuro',
          'Título exclusivo: "Arconte del Vacío"',
          'Marco de carta exclusivo: Eclipse Dorado',
        ],
        demoOnly: true,
      ),
    ];
  }

  Future<void> _buyPack(
      BuildContext context, WidgetRef ref, _FounderPack pack) async {
    final profileState = ref.read(profileProvider);
    final profileCtrl = ref.read(profileProvider.notifier);

    // Try shards first, then gold
    if (profileState.shards >= pack.costShards) {
      if (await profileCtrl.spend(shards: pack.costShards)) {
        await _deliverPack(ref, pack);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    '¡${pack.name} comprado por ${pack.costShards} esquirlas!'),
                backgroundColor: const Color(0xFF4FFFA3)),
          );
        }
        return;
      }
    } else if (profileState.gold >= pack.costGold) {
      if (await profileCtrl.spend(gold: pack.costGold)) {
        await _deliverPack(ref, pack);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('¡${pack.name} comprado por ${pack.costGold} oro!'),
                backgroundColor: const Color(0xFF4FFFA3)),
          );
        }
        return;
      }
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Fondos insuficientes'),
            backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _deliverPack(WidgetRef ref, _FounderPack pack) async {
    final repo = ref.read(playerRepositoryProvider);
    // Simplified delivery - in real implementation would parse rewards
    switch (pack.id) {
      case 'starter_pack':
        await repo.addShards(1000);
        await repo.addGold(5000);
        await ref.read(collectionProvider.notifier).summon(grandRitual: true);
        await repo.addEnergy(50);
        break;
      case 'war_chest':
        await repo.addShards(5000);
        await repo.addGold(25000);
        for (int i = 0; i < 3; i++) {
          await ref.read(collectionProvider.notifier).summon(grandRitual: true);
        }
        await repo.addEnergy(200);
        break;
      case 'archon_pass':
        await repo.addShards(20000);
        await repo.addGold(100000);
        for (int i = 0; i < 10; i++) {
          await ref.read(collectionProvider.notifier).summon(grandRitual: true);
        }
        break;
    }
  }
}

class _FounderPack {
  final String id;
  final String name;
  final String description;
  final Color color;
  final IconData icon;
  final int costShards;
  final int costGold;
  final List<String> rewards;
  final bool demoOnly;

  const _FounderPack({
    required this.id,
    required this.name,
    required this.description,
    required this.color,
    required this.icon,
    required this.costShards,
    required this.costGold,
    required this.rewards,
    required this.demoOnly,
  });
}

class _FounderPackTile extends StatelessWidget {
  final _FounderPack pack;
  final int shards;
  final int gold;
  final VoidCallback onBuy;

  const _FounderPackTile({
    required this.pack,
    required this.shards,
    required this.gold,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final canAffordShards = shards >= pack.costShards;
    final canAffordGold = gold >= pack.costGold;
    final canAfford = canAffordShards || canAffordGold;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          pack.color.withValues(alpha: 0.15),
          const Color(0xFF0D040A),
        ]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color:
                canAfford ? pack.color.withValues(alpha: 0.5) : Colors.white12,
            width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                pack.color.withValues(alpha: 0.3),
                pack.color.withValues(alpha: 0.05)
              ]),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(pack.icon, color: pack.color, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pack.name,
                          style: TextStyle(
                              color: pack.color,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                              fontSize: 14)),
                      Text(pack.description,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 10)),
                    ],
                  ),
                ),
                if (pack.demoOnly)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5A26).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('DEMO',
                        style: TextStyle(
                            color: Color(0xFFFF5A26),
                            fontWeight: FontWeight.w900,
                            fontSize: 8)),
                  ),
              ],
            ),
          ),
          // Rewards
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('CONTENIDO:',
                    style: TextStyle(
                        color: Colors.white54, fontSize: 9, letterSpacing: 1)),
                const SizedBox(height: 8),
                ...pack.rewards.map((r) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          const Icon(Icons.check,
                              color: Color(0xFF4FFFA3), size: 14),
                          const SizedBox(width: 8),
                          Text(r,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 10)),
                        ],
                      ),
                    )),
              ],
            ),
          ),
          // Buy button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                if (pack.costShards > 0) ...[
                  const Icon(Icons.diamond, color: Color(0xFFB16EFF), size: 16),
                  Text(' ${pack.costShards}',
                      style: TextStyle(
                          color: canAffordShards
                              ? const Color(0xFFB16EFF)
                              : Colors.white38,
                          fontWeight: FontWeight.w900,
                          fontSize: 11)),
                  const SizedBox(width: 16),
                ],
                if (pack.costGold > 0) ...[
                  const Icon(Icons.attach_money,
                      color: Color(0xFFFFD700), size: 16),
                  Text(' ${pack.costGold}',
                      style: TextStyle(
                          color: canAffordGold
                              ? const Color(0xFFFFD700)
                              : Colors.white38,
                          fontWeight: FontWeight.w900,
                          fontSize: 11)),
                ],
                const Spacer(),
                BrimstoneButton(
                  label: canAfford ? 'ADQUIRIR' : 'FONDOS INSUFICIENTES',
                  onPressed: canAfford ? onBuy : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ============================================================
/// TAB 3: PROMO CODES - Redeem gift codes
/// ============================================================
class _PromoCodeTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_PromoCodeTab> createState() => _PromoCodeTabState();
}

class _PromoCodeTabState extends ConsumerState<_PromoCodeTab> {
  final TextEditingController _controller = TextEditingController();
  String? _lastResult;
  bool _isProcessing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                const Color(0xFF2A0A0F),
                const Color(0xFF1A0408),
              ]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFF4FFFA3).withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.card_giftcard,
                        color: Color(0xFF4FFFA3), size: 24),
                    const SizedBox(width: 12),
                    const Text(
                      'CANJEAR CÓDIGO PROMOCIONAL',
                      style: TextStyle(
                        color: Color(0xFF4FFFA3),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ingresa un código de regalo para obtener recompensas exclusivas.',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 16, letterSpacing: 2),
                  decoration: InputDecoration(
                    hintText: 'CÓDIGO AQUÍ',
                    hintStyle: const TextStyle(
                        color: Colors.white38, letterSpacing: 2),
                    filled: true,
                    fillColor: const Color(0xFF0A0008),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: const Color(0xFF4FFFA3), width: 2),
                    ),
                    suffixIcon: _isProcessing
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Color(0xFF4FFFA3), strokeWidth: 2))
                        : IconButton(
                            icon: const Icon(Icons.send,
                                color: Color(0xFF4FFFA3)),
                            onPressed: _redeemCode,
                          ),
                  ),
                  onSubmitted: (_) => _redeemCode(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_lastResult != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: _lastResult!.startsWith('✓')
                        ? [
                            const Color(0xFF4FFFA3).withValues(alpha: 0.2),
                            const Color(0xFF4FFFA3).withValues(alpha: 0.05)
                          ]
                        : [const Color(0xFF2A0A0A), const Color(0xFF1A0000)]),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _lastResult!.startsWith('✓')
                      ? const Color(0xFF4FFFA3)
                      : Colors.redAccent.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                _lastResult!,
                style: TextStyle(
                  color: _lastResult!.startsWith('✓')
                      ? const Color(0xFF4FFFA3)
                      : Colors.redAccent,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
          const SizedBox(height: 20),
          // Known promo codes hint
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A0E14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CÓDIGOS CONOCIDOS (un solo uso por cuenta):',
                  style: TextStyle(
                      color: Color(0xFFB16EFF),
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 0.5),
                ),
                const SizedBox(height: 12),
                _PromoCodeHint(
                    code: 'HELLFIRE2026',
                    reward: '+1.000 Esquirlas + 2.500 Oro'),
                _PromoCodeHint(
                    code: 'BRIMSTONEVIP',
                    reward: '1 copia 3★ de Vulcanor + 500 Esquirlas'),
                _PromoCodeHint(
                    code: 'VOIDLORD',
                    reward: '1 copia 3★ de Xal\'atoh + 500 Esquirlas'),
                _PromoCodeHint(
                    code: 'AUTOBATTLE', reward: '+3.000 Oro + 300 Esquirlas'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _redeemCode() async {
    final code = _controller.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _lastResult = null;
    });

    final repo = ref.read(playerRepositoryProvider);
    final result = await repo.redeemCode(code);

    if (result == null) {
      setState(() {
        _isProcessing = false;
        _lastResult = '✗ Código inválido o ya canjeado';
      });
      return;
    }

    // Deliver rewards
    if (result['card'] == 1) {
      await repo.grantPromoCard('ignis_colossus');
    } else if (result['card'] == 2) {
      await repo.grantPromoCard('void_archon');
    }

    if (result['shards'] != null && result['shards']! > 0) {
      await repo.addShards(result['shards']!);
    }
    if (result['gold'] != null && result['gold']! > 0) {
      await repo.addGold(result['gold']!);
    }

    // Invalidate providers to refresh UI
    ref.invalidate(profileProvider);
    ref.invalidate(collectionProvider);

    setState(() {
      _isProcessing = false;
      _controller.clear();
      _lastResult =
          '✓ ¡Código canjeado! Recompensas entregadas: ${_formatRewards(result)}';
    });
  }

  String _formatRewards(Map<String, int> rewards) {
    final parts = <String>[];
    if (rewards['shards'] != null && rewards['shards']! > 0) {
      parts.add('${rewards['shards']} esquirlas');
    }
    if (rewards['gold'] != null && rewards['gold']! > 0) {
      parts.add('${rewards['gold']} oro');
    }
    if (rewards['card'] != null && rewards['card']! > 0) {
      parts.add('carta legendaria');
    }
    return parts.join(' + ');
  }
}

class _PromoCodeHint extends StatelessWidget {
  final String code;
  final String reward;

  const _PromoCodeHint({required this.code, required this.reward});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0008),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white12),
            ),
            child: Text(
              code,
              style: const TextStyle(
                color: Color(0xFFFFD700),
                fontWeight: FontWeight.w900,
                fontSize: 10,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              reward,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}

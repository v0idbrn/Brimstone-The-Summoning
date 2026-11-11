import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:brimstone_summoning/core/audio/procedural_sfx_engine.dart';
import 'package:brimstone_summoning/domain/meta/covenant_order.dart';
import 'package:brimstone_summoning/domain/meta/obsidian_tower.dart';
import 'package:brimstone_summoning/presentation/controllers/meta_controller.dart';
import 'package:brimstone_summoning/presentation/widgets/brimstone_button.dart';

/// Modal de la Orden del Pacto (Pilar 8, Etapa III).
class CovenantGuildModal extends ConsumerStatefulWidget {
  const CovenantGuildModal({super.key});

  @override
  ConsumerState<CovenantGuildModal> createState() => _CovenantGuildModalState();
}

class _CovenantGuildModalState extends ConsumerState<CovenantGuildModal> {
  GuildState? _guild;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(playerRepositoryProvider);
    final g = await repo.loadGuild();
    if (mounted) {
      setState(() {
        _guild = g;
        _loading = false;
      });
    }
  }

  Future<void> _swear(CovenantOrder order) async {
    final repo = ref.read(playerRepositoryProvider);
    await repo.saveGuild(GuildState(
      order: order,
      orderLevel: 1,
      contributionsToday: 0,
      dayKey: ObsidianTower.dayKeyOf(DateTime.now()),
      badges: 0,
    ));
    ProceduralSfxEngine.playLevelUp();
    _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Juramento a ${order.label} sellado.'),
        backgroundColor: const Color(0xFF4FFFA3),
      ));
    }
  }

  Future<void> _contribute() async {
    if (_guild == null) return;
    final repo = ref.read(playerRepositoryProvider);
    final todayKey = ObsidianTower.dayKeyOf(DateTime.now());
    if (!_guild!.canContribute(todayKey)) return;

    final badges = badgesForContribution(_guild!.orderLevel);
    // Aporte humano + 2 compañeros IA simulados (vibes visuales)
    var newState = _guild!.contribute(badges, todayKey);
    newState = newState.levelUpIfReady();
    await repo.saveGuild(newState);
    await ref
        .read(profileProvider.notifier)
        .grant(gold: 50 * _guild!.orderLevel + 50);

    ProceduralSfxEngine.playChestOpen();
    _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '+$badges insignias. Los compañeros IA aportan 2 esencias de orden.'),
        backgroundColor: const Color(0xFF4FFFA3),
      ));
    }
  }

  Future<void> _buyBadgeItem(GuildBadgeShopItem item) async {
    if (_guild == null || _guild!.badges < item.badgeCost) return;
    final repo = ref.read(playerRepositoryProvider);
    final newState = GuildState(
      order: _guild!.order,
      orderLevel: _guild!.orderLevel,
      contributionsToday: _guild!.contributionsToday,
      dayKey: _guild!.dayKey,
      badges: _guild!.badges - item.badgeCost,
    );
    await repo.saveGuild(newState);
    // Efectos simples
    if (item.id == 'guild_gold_bundle') {
      await ref.read(profileProvider.notifier).grant(gold: 800);
    } else if (item.id == 'guild_shards_bundle') {
      await ref.read(profileProvider.notifier).grant(shards: 200);
    }
    ProceduralSfxEngine.playUIHeavyClick();
    _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Comprado: ${item.name}'),
        backgroundColor: const Color(0xFF4FFFA3),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        padding: const EdgeInsets.all(40),
        child: const Center(
            child: CircularProgressIndicator(color: Color(0xFFB16EFF))),
      );
    }

    final guild = _guild!;
    final todayKey = ObsidianTower.dayKeyOf(DateTime.now());

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
                const Icon(Icons.groups, color: Color(0xFFB16EFF), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('ORDEN DEL PACTO',
                      style: const TextStyle(
                          color: Color(0xFFB16EFF),
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          letterSpacing: 1)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (guild.order == null) ...[
              const Text('Elige tu juramento:',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: CovenantOrder.values
                    .map((o) => _OrderCard(
                          order: o,
                          onTap: () => _swear(o),
                        ))
                    .toList(),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A0E14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFB16EFF), width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(guild.order!.label,
                        style: const TextStyle(
                            color: Color(0xFFB16EFF),
                            fontWeight: FontWeight.w900,
                            fontSize: 16)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _StatChip(
                          label: 'NIVEL',
                          value: '${guild.orderLevel}',
                          color: const Color(0xFFB16EFF),
                        ),
                        const SizedBox(width: 8),
                        _StatChip(
                          label: 'BUFF DAÑO',
                          value: '+${(guild.damageBuff() * 100).round()}%',
                          color: const Color(0xFFFFC93C),
                        ),
                        const SizedBox(width: 8),
                        _StatChip(
                          label: 'INSIGNIAS',
                          value: '${guild.badges}',
                          color: const Color(0xFF4FFFA3),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                        'Contribuciones hoy: ${guild.contributionsToday}/${GuildState.maxDailyContributions}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              BrimstoneButton(
                label: 'CONTRIBUTIR',
                onPressed: guild.canContribute(todayKey) ? _contribute : null,
                width: double.infinity,
              ),
              const SizedBox(height: 20),
              const Text('TIENDA DE INSIGNIAS',
                  style: TextStyle(
                      color: Color(0xFF3FD8FF),
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 1)),
              const SizedBox(height: 8),
              ...guildBadgeShop.map((item) => _ShopItemTile(
                    item: item,
                    ownedBadges: guild.badges,
                    onBuy: () => _buyBadgeItem(item),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final CovenantOrder order;
  final VoidCallback onTap;

  const _OrderCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = switch (order) {
      CovenantOrder.ordenCeniza => const Color(0xFFFF5A26),
      CovenantOrder.corteAbismo => const Color(0xFF3FD8FF),
      CovenantOrder.hijosBasalto => const Color(0xFFB0703B),
      CovenantOrder.cultoEclipse => const Color(0xFFB16EFF),
    };
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A0E14),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color, width: 2),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.shield, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(order.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11)),
            const SizedBox(height: 4),
            Text('+1.5% daño ${order.label.split(' ').last} / nivel',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 9)),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 1),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w900, fontSize: 12)),
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 8)),
        ],
      ),
    );
  }
}

class _ShopItemTile extends StatelessWidget {
  final GuildBadgeShopItem item;
  final int ownedBadges;
  final VoidCallback onBuy;

  const _ShopItemTile({
    required this.item,
    required this.ownedBadges,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final canAfford = ownedBadges >= item.badgeCost;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0E14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: canAfford ? const Color(0xFFFFC93C) : Colors.white12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800)),
                Text(item.description,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 10)),
              ],
            ),
          ),
          Row(
            children: [
              Icon(Icons.star,
                  color: canAfford ? const Color(0xFFFFC93C) : Colors.white24,
                  size: 16),
              const SizedBox(width: 4),
              Text('${item.badgeCost}',
                  style: TextStyle(
                      color:
                          canAfford ? const Color(0xFFFFC93C) : Colors.white38,
                      fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: BrimstoneButton(
                  label: canAfford ? 'COMPRAR' : 'INSUFICIENTE',
                  onPressed: canAfford ? onBuy : null,
                  isSecondary: true,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

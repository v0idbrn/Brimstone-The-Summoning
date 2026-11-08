import 'package:flutter/material.dart' hide Element;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/meta_controller.dart';

/// Copias 1★ disponibles para el Contrato de Élite del Mercader del Vacío.
const List<Map<String, String>> _eliteContractOfferings = [
  {'id': 'ignis_hound', 'name': 'Sabueso de Azufre', 'element': 'Ígneo'},
  {'id': 'abyss_stalker', 'name': 'Acechador de Escarcha', 'element': 'Abisal'},
  {'id': 'terra_golem', 'name': 'Gólem de Basalto', 'element': 'Telúrico'},
  {'id': 'void_specter', 'name': 'Espectro del Sello', 'element': 'Vacío'},
];

/// Modal del Mercader del Vacío: tributo diario, transmutación oro/esquirlas
/// y contrato de élite para comprar una criatura 1★.
class MerchantModal extends ConsumerStatefulWidget {
  const MerchantModal({super.key});

  @override
  ConsumerState<MerchantModal> createState() => _MerchantModalState();
}

class _MerchantModalState extends ConsumerState<MerchantModal> {
  String? _lastTributeDate;
  String _selectedId = _eliteContractOfferings.first['id']!;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final date = await ref.read(playerRepositoryProvider).loadLastTributeDate();
    if (mounted) setState(() => _lastTributeDate = date);
  }

  bool get _tributeClaimed =>
      _lastTributeDate != null &&
      _lastTributeDate == DateTime.now().toIso8601String().substring(0, 10);

  Future<void> _claimTribute() async {
    final repo = ref.read(playerRepositoryProvider);
    final reward = await repo.claimDailyTribute();
    if (reward == null) {
      setState(() => _message = 'Tributo ya reclamado hoy.');
      return;
    }
    await ref.read(profileProvider.notifier).grant(
          gold: reward['gold'],
          shards: reward['shards'],
        );
    await _load();
    setState(() {
      _message =
          'Tributo recibido: +${reward['gold']} oro, +${reward['shards']} esquirlas.';
    });
  }

  Future<void> _transmute(bool goldToShards) async {
    final repo = ref.read(playerRepositoryProvider);
    final ok = goldToShards
        ? await repo.transmuteGoldToShards()
        : await repo.transmuteShardsToGold();
    if (!ok) {
      setState(() => _message = 'Fondos insuficientes para transmutar.');
      return;
    }
    await ref.read(profileProvider.notifier).load();
    setState(() {
      _message = goldToShards
          ? 'Transmutado: 400 oro → 100 esquirlas.'
          : 'Transmutado: 100 esquirlas → 400 oro.';
    });
  }

  Future<void> _purchaseContract() async {
    final repo = ref.read(playerRepositoryProvider);
    final ok = await repo.purchaseEliteContract(_selectedId);
    if (!ok) {
      setState(() => _message = 'Esquirlas insuficientes para el contrato.');
      return;
    }
    await ref.read(collectionProvider.notifier).load();
    setState(() {
      final offering = _eliteContractOfferings.firstWhere(
        (o) => o['id'] == _selectedId,
      );
      _message =
          'Contrato de élite: ${offering['name']} añadido a tu colección.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (_, controller) => Container(
        color: const Color(0xFF14090D),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'MERCADER DEL VACÍO',
              style: TextStyle(
                color: Color(0xFFB16EFF),
                fontWeight: FontWeight.w900,
                fontSize: 17,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Oro: ${profile.gold}   Esquirlas: ${profile.shards}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            if (_message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _message,
                style: TextStyle(
                  color: const Color(0xFF4FFFA3),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 12),
            // Tributo diario.
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1A0E14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _tributeClaimed ? Colors.white38 : Colors.amber,
                  width: 1.2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.card_giftcard,
                          color: Color(0xFFFFC93C), size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tributo diario gratis',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '150 esquirlas + 400 oro (1 vez por día)',
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonal(
                      onPressed: _tributeClaimed ? null : _claimTribute,
                      child: Text(
                        _tributeClaimed
                            ? 'Ya reclamado hoy'
                            : 'RECLAMAR TRIBUTO',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Transmutación oro ↔ esquirlas.
            const Text(
              'Transmutación',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () => _transmute(true),
                    child: const Text(
                      '400 Oro → 100 Esquirlas',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () => _transmute(false),
                    child: const Text(
                      '100 Esquirlas → 400 Oro',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Contrato de élite.
            const Text(
              'Contrato de élite (300 esquirlas)',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 110,
              child: ListView.builder(
                controller: controller,
                itemCount: _eliteContractOfferings.length,
                itemBuilder: (context, i) {
                  final o = _eliteContractOfferings[i];
                  final selected = _selectedId == o['id'];
                  // El sheet pinta sobre un Container con color: el ListTile
                  // necesita su propio Material para que el ripple sea visible.
                  return Material(
                    type: MaterialType.transparency,
                    child: ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A0E14),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selected
                                ? const Color(0xFFB16EFF)
                                : Colors.white24,
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            o['name']!.substring(0, 1),
                            style: TextStyle(
                              color: selected
                                  ? const Color(0xFFB16EFF)
                                  : Colors.white54,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        o['name']!,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight:
                              selected ? FontWeight.w900 : FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${o['element']} · 1★',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 10),
                      ),
                      trailing: selected
                          ? const Icon(
                              Icons.check_circle,
                              color: Color(0xFFB16EFF),
                            )
                          : null,
                      onTap: () => setState(() => _selectedId = o['id']!),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _purchaseContract,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB16EFF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'COMPRAR CONTRATO DE ÉLITE',
                  style: TextStyle(
                      fontWeight: FontWeight.w900, letterSpacing: 1.0),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}

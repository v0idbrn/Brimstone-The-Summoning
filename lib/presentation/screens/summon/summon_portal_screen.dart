import 'dart:math' as math;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/procedural_sfx_engine.dart';
import '../../../domain/entities/owned_card.dart';
import '../../controllers/meta_controller.dart';
import '../meta/widgets.dart';

/// Summon Portal: Pacto Menor (1 card, 100 esquirlas / 500 oro) and
/// Gran Ritual (5 cards, 450 esquirlas, >=1 épica garantizada) with an
/// animated rotating rune circle and a reveal dialog.
class SummonPortalScreen extends ConsumerStatefulWidget {
  const SummonPortalScreen({super.key});

  @override
  ConsumerState<SummonPortalScreen> createState() => _SummonPortalScreenState();
}

class _SummonPortalScreenState extends ConsumerState<SummonPortalScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  )..repeat();
  bool _channeling = false;

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final minorShards = profile.shards >= 100;
    final minorGold = profile.gold >= 500;
    final grand = profile.shards >= 450;

    return Scaffold(
      backgroundColor: const Color(0xFF0C0608),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14090D),
        title: const Text(
          'PORTAL DE INVOCACIÓN',
          style: TextStyle(
            color: Color(0xFFB16EFF),
            fontWeight: FontWeight.w900,
            fontSize: 15,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: Column(
        children: [
          const CurrencyBar(),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _spin,
                  builder: (context, _) => CustomPaint(
                    size: const Size(300, 300),
                    painter: _RuneCirclePainter(
                      angle: _spin.value * 2 * math.pi,
                    ),
                  ),
                ),
                if (_channeling)
                  const Text(
                    'EL RITUAL SE CONSUMA...',
                    style: TextStyle(
                      color: Color(0xFFB16EFF),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SummonButton(
                  title: 'PACTO MENOR',
                  subtitle: minorShards
                      ? '1 carta — 100 esquirlas'
                      : minorGold
                      ? '1 carta — 500 oro (sin esquirlas)'
                      : 'Sin fondos suficientes',
                  enabled: !_channeling && (minorShards || minorGold),
                  onTap: () => _summon(grandRitual: false),
                ),
                const SizedBox(height: 10),
                _SummonButton(
                  title: 'GRAN RITUAL',
                  subtitle: '5 cartas — 450 esquirlas · ≥1 épica garantizada',
                  enabled: !_channeling && grand,
                  onTap: () => _summon(grandRitual: true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _summon({required bool grandRitual}) async {
    setState(() {
      _channeling = true;
    });
    final cards = await ref
        .read(collectionProvider.notifier)
        .summon(grandRitual: grandRitual);
    if (!mounted) return;
    setState(() {
      _channeling = false;
    });
    if (cards == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El ritual falló: fondos insuficientes.')),
      );
      return;
    }
    ProceduralSfxEngine.playSummonReveal(cards.length);
    await showDialog<void>(
      context: context,
      builder: (_) => _RevealDialog(cards: cards),
    );
  }
}

class _SummonButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;

  const _SummonButton({
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled ? const Color(0xFFB16EFF) : Colors.white24;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF2A1116),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color, width: 1.6),
          ),
          child: Row(
            children: [
              Icon(Icons.auto_awesome, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
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
    );
  }
}

/// Rotating gothic rune circle around the summoning sigil.
class _RuneCirclePainter extends CustomPainter {
  final double angle;

  const _RuneCirclePainter({required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.42;

    final glow = Paint()
      ..color = const Color(0xFFB16EFF).withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(c, r + 26, glow);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFFB16EFF).withValues(alpha: 0.8);
    canvas.drawCircle(c, r, ring);
    canvas.drawCircle(c, r * 0.72, ring..strokeWidth = 1.4);

    for (var i = 0; i < 8; i++) {
      final a = angle + i * math.pi / 4;
      final p1 = Offset(
        c.dx + math.cos(a) * r * 0.72,
        c.dy + math.sin(a) * r * 0.72,
      );
      final p2 = Offset(c.dx + math.cos(a) * r, c.dy + math.sin(a) * r);
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = const Color(0xFFFF5A26).withValues(alpha: 0.85)
          ..strokeWidth = 2.4,
      );
      canvas.drawCircle(p2, 4.5, Paint()..color = const Color(0xFFFFC93C));
    }

    // Central sigil.
    canvas.drawCircle(
      c,
      r * 0.3,
      Paint()..color = const Color(0xFFB16EFF).withValues(alpha: 0.22),
    );
    canvas.drawCircle(
      c,
      r * 0.3,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.5),
    );
  }

  @override
  bool shouldRepaint(covariant _RuneCirclePainter oldDelegate) =>
      oldDelegate.angle != angle;
}

/// Post-summon card reveal (5 cards for the Gran Ritual, 1 for the Pacto).
class _RevealDialog extends StatelessWidget {
  final List<OwnedCard> cards;

  const _RevealDialog({required this.cards});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF14090D),
      title: const Text(
        '¡INVOCACIÓN COMPLETADA!',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Color(0xFFB16EFF),
          fontWeight: FontWeight.w900,
          fontSize: 16,
        ),
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in cards)
                  SizedBox(
                    width: 66,
                    child: CardTileSmall(card: c, raised: true),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${cards.length} carta(s) se han unido a tu colección.',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Aceptar'),
        ),
      ],
    );
  }
}

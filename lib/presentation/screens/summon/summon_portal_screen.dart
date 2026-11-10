import 'dart:math' as math;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/procedural_sfx_engine.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../domain/entities/owned_card.dart';
import '../../../domain/value_objects/element.dart';
import '../../controllers/meta_controller.dart';
import '../../graphics/art_registry.dart';
import '../../graphics/painted_backdrop.dart';
import '../../graphics/rift_effect.dart';
import '../../screens/meta/widgets.dart';
import '../../widgets/tcg_card_widget.dart';

/// Summon Portal with Gacha System (Block 4):
/// - 5 Elemental Banners (General, Igneous, Abyssal, Telluric, Void)
/// - Pity Counter (0-20, guaranteed 3★ at 20)
/// - Daily Free Summon
/// - Animated ritual circle
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

  // Gacha state
  int _pityCounter = 0;
  String _activeBanner = 'general';
  bool _freeSummonAvailable = false;
  Map<String, Object?> _gachaState = {};

  @override
  void initState() {
    super.initState();
    _loadGachaState();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  Future<void> _loadGachaState() async {
    final repo = ref.read(playerRepositoryProvider);
    final state = await repo.loadGachaState();
    if (mounted) {
      setState(() {
        _gachaState = state;
        _pityCounter = (state['pityCounter'] as int?) ?? 0;
        _activeBanner = (state['activeBanner'] as String?) ?? 'general';
        _freeSummonAvailable = (state['lastFreeSummonDate'] as String?) !=
            DateTime.now().toIso8601String().substring(0, 10);
      });
    }
  }

  Future<void> _setActiveBanner(String bannerId) async {
    final repo = ref.read(playerRepositoryProvider);
    await repo.setActiveBanner(bannerId);
    if (mounted) {
      setState(() {
        _activeBanner = bannerId;
        _pityCounter = 0;
      });
    }
  }

  Future<void> _summon({required bool grandRitual, bool free = false}) async {
    setState(() => _channeling = true);

    final repo = ref.read(playerRepositoryProvider);
    final profile = await repo.loadProfile();
    final shards = profile[1];
    final gold = profile[0];

    if (!free) {
      if (grandRitual) {
        if (shards < 450) {
          setState(() => _channeling = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content:
                      Text('Esquirlas insuficientes para Gran Ritual (450).')),
            );
          }
          return;
        }
        await repo.spend(shards: 450);
      } else {
        if (shards >= 100) {
          await repo.spend(shards: 100);
        } else if (gold >= 500) {
          await repo.spend(gold: 500);
        } else {
          setState(() => _channeling = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Fondos insuficientes para Pacto Menor.')),
            );
          }
          return;
        }
      }
    } else {
      await repo.markFreeSummonUsed();
    }

    final cards = await ref
        .read(collectionProvider.notifier)
        .summon(grandRitual: grandRitual, banner: _activeBanner);

    if (!mounted) return;
    setState(() => _channeling = false);

    if (cards == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El ritual falló: fondos insuficientes.')),
      );
      return;
    }

    // Update pity counter based on results
    await _updatePityAfterSummon(cards, grandRitual);

    if (!mounted) return;
    ProceduralSfxEngine.playSummonReveal(cards.length);
    await showDialog<void>(
      context: context,
      builder: (_) => _RevealDialog(cards: cards),
    );
    await _loadGachaState(); // Refresh pity/free summon state
  }

  Future<void> _updatePityAfterSummon(
      List<OwnedCard> cards, bool grandRitual) async {
    final repo = ref.read(playerRepositoryProvider);
    for (final card in cards) {
      // Check if any card is Legendary (3★)
      final isLegendary = card.stars >= 3;
      if (!isLegendary) {
        final guaranteed = await repo.incrementPityAndCheckGuaranteed();
        if (guaranteed && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  '¡LLEGASTE AL PITY! Próxima invocación garantiza Legendaria 3★.'),
              backgroundColor: Color(0xFFFFD700),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        // Reset pity on Legendary
        await repo.saveGachaState({
          'pityCounter': 0,
          'activeBanner': _activeBanner,
          'lastFreeSummonDate': _gachaState['lastFreeSummonDate'],
          'dailySummonsToday': _gachaState['dailySummonsToday'] ?? 0,
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final minorShards = profile.shards >= 100;
    final minorGold = profile.gold >= 500;
    final grand = profile.shards >= 450;

    final banners = _BannerData.all;

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
      body: PaintedBackdrop(
        asset: ArtRegistry.portalBlur,
        tint: const Color(0xFF8B4FD9),
        darkness: 0.64,
        child: Column(
          children: [
            const CurrencyBar(),
            // Banner Selector
            _BannerSelector(
              banners: banners,
              activeBanner: _activeBanner,
              onChanged: _setActiveBanner,
            ),
            // Pity Counter Bar
            _PityCounterBar(
              pityCounter: _pityCounter,
              activeBanner: _activeBanner,
              banners: banners,
            ),
            // Daily Free Summon Indicator
            if (_freeSummonAvailable)
              _DailyFreeSummonBanner(
                  onTap: () => _summon(grandRitual: false, free: true)),
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // GPU dimensional vortex behind the ritual circle.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AbyssalRiftView(
                        color: const Color(0xFF8B4FD9),
                        intensity: 0.9,
                      ),
                    ),
                  ),
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
                    title: _freeSummonAvailable
                        ? '✨ INVOCACIÓN DIARIA GRATIS'
                        : 'PACTO MENOR',
                    subtitle: _freeSummonAvailable
                        ? '0 Esquirlas (1 gratis por día)'
                        : (minorShards
                            ? '1 carta — 100 esquirlas'
                            : minorGold
                                ? '1 carta — 500 oro (sin esquirlas)'
                                : 'Sin fondos suficientes'),
                    enabled: !_channeling &&
                        (_freeSummonAvailable || minorShards || minorGold),
                    onTap: () =>
                        _summon(grandRitual: false, free: _freeSummonAvailable),
                    isFree: _freeSummonAvailable,
                  ),
                  const SizedBox(height: 10),
                  _SummonButton(
                    title: 'GRAN RITUAL',
                    subtitle: '5 cartas — 450 esquirlas · ≥1 épica garantizada',
                    enabled: !_channeling && grand,
                    onTap: () => _summon(grandRitual: true),
                    isGrand: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerData {
  final String id;
  final String name;
  final Element? featuredElement;
  final Color color;
  final String description;

  const _BannerData({
    required this.id,
    required this.name,
    this.featuredElement,
    required this.color,
    required this.description,
  });

  static const List<_BannerData> all = [
    _BannerData(
      id: 'general',
      name: 'Grieta Primordial',
      featuredElement: null,
      color: Color(0xFFB16EFF),
      description: 'Pool general de las 20 criaturas.',
    ),
    _BannerData(
      id: 'igneous',
      name: 'Forja de Ignis',
      featuredElement: Element.igneous,
      color: Color(0xFFFF5A26),
      description: '60% probabilidad de cartas Ígneas.',
    ),
    _BannerData(
      id: 'abyssal',
      name: 'Fosa de Leviatán',
      featuredElement: Element.abyssal,
      color: Color(0xFF00FFFF),
      description: '60% probabilidad de cartas Abisales.',
    ),
    _BannerData(
      id: 'telluric',
      name: 'Cumbre del Titán',
      featuredElement: Element.telluric,
      color: Color(0xFF8B5A2B),
      description: '60% probabilidad de cartas Telúricas.',
    ),
    _BannerData(
      id: 'void',
      name: 'Eclipse de Malakor',
      featuredElement: Element.empty,
      color: Color(0xFFB16EFF),
      description: '60% probabilidad de cartas de Vacío.',
    ),
  ];
}

class _BannerSelector extends StatelessWidget {
  final List<_BannerData> banners;
  final String activeBanner;
  final void Function(String) onChanged;

  const _BannerSelector({
    required this.banners,
    required this.activeBanner,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: banners.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final banner = banners[index];
          final isActive = banner.id == activeBanner;
          return GestureDetector(
            onTap: () => onChanged(banner.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 140,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: isActive
                        ? [
                            banner.color.withValues(alpha: 0.4),
                            banner.color.withValues(alpha: 0.2)
                          ]
                        : [const Color(0xFF1A0A0F), const Color(0xFF0C0608)]),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isActive ? banner.color : Colors.white12,
                  width: isActive ? 2 : 1,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                            color: banner.color.withValues(alpha: 0.3),
                            blurRadius: 8)
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    banner.name,
                    style: TextStyle(
                      color: isActive ? banner.color : Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (banner.featuredElement != null) ...[
                    const SizedBox(height: 2),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: banner.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PityCounterBar extends StatelessWidget {
  final int pityCounter;
  final String activeBanner;
  final List<_BannerData> banners;

  const _PityCounterBar({
    required this.pityCounter,
    required this.activeBanner,
    required this.banners,
  });

  @override
  Widget build(BuildContext context) {
    final banner = banners.firstWhere((b) => b.id == activeBanner);
    final progress = pityCounter / 20.0;
    final isGuaranteed = pityCounter >= 20;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          banner.color.withValues(alpha: 0.2),
          banner.color.withValues(alpha: 0.05),
        ]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isGuaranteed
              ? const Color(0xFFFFD700)
              : banner.color.withValues(alpha: 0.5),
          width: 2,
        ),
        boxShadow: isGuaranteed
            ? [
                BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                    blurRadius: 12)
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isGuaranteed ? Icons.star : Icons.auto_awesome,
                color: isGuaranteed ? const Color(0xFFFFD700) : banner.color,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isGuaranteed
                      ? '¡GARANTÍA LEGENDARIA (3★) LISTA!'
                      : 'Garantía Legendaria (3★): $pityCounter / 20 invocaciones',
                  style: TextStyle(
                    color:
                        isGuaranteed ? const Color(0xFFFFD700) : Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (isGuaranteed)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFF5A26)]),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '¡LISTO!',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0008),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: isGuaranteed
                            ? [const Color(0xFFFFD700), const Color(0xFFFF5A26)]
                            : [
                                banner.color,
                                banner.color.withValues(alpha: 0.6)
                              ]),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              // Milestone markers
              Positioned.fill(
                child: Row(
                  children: [
                    for (int i = 1; i <= 19; i++)
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: pityCounter >= i
                                ? banner.color.withValues(alpha: 0.5)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DailyFreeSummonBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _DailyFreeSummonBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF00C853),
              Color(0xFF4FFFA3),
              Color(0xFFFFD700),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00C853).withValues(alpha: 0.4),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.card_giftcard, color: Colors.black, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'INVOCACIÓN DIARIA GRATIS DISPONIBLE',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Text(
                    'Tu pacto menor diario no cuesta nada hoy',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.black, size: 18),
          ],
        ),
      ),
    );
  }
}

class _SummonButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;
  final bool isFree;
  final bool isGrand;

  const _SummonButton({
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
    this.isFree = false,
    this.isGrand = false,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = isFree
        ? const Color(0xFF00C853)
        : isGrand
            ? const Color(0xFFFFD700)
            : const Color(0xFFB16EFF);
    final color = enabled ? baseColor : Colors.white24;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: enabled
                    ? [
                        const Color(0xFF2A1116),
                        const Color(0xFF1A0A0F),
                      ]
                    : [
                        const Color(0xFF14090D),
                        const Color(0xFF0C0608),
                      ]),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color, width: isFree ? 2.5 : 1.6),
            boxShadow: enabled && isFree
                ? [
                    BoxShadow(
                        color: baseColor.withValues(alpha: 0.4), blurRadius: 12)
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    baseColor.withValues(alpha: 0.3),
                    baseColor.withValues(alpha: 0.1),
                  ]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isFree
                      ? Icons.card_giftcard
                      : (isGrand ? Icons.auto_awesome : Icons.casino),
                  color: color,
                  size: 24,
                ),
              ),
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
                        fontSize: isFree ? 14 : 13,
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
              if (enabled)
                Icon(Icons.arrow_forward_ios, color: color, size: 16),
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

/// Post-summon card reveal ceremony.
///
/// Every card lands face-down showing a gothic rune back tinted by its rarity
/// (blue = rare, purple = epic, golden solar burst = legendary 3★+); tapping a
/// card flips it in real 3D perspective, and "REVELAR TODAS" flips the rest.
class _RevealDialog extends StatefulWidget {
  final List<OwnedCard> cards;

  const _RevealDialog({required this.cards});

  @override
  State<_RevealDialog> createState() => _RevealDialogState();
}

class _RevealDialogState extends State<_RevealDialog> {
  late final List<bool> _revealed =
      List<bool>.filled(widget.cards.length, false);

  bool get _allRevealed => _revealed.every((r) => r);

  void _revealCard(int index) {
    if (_revealed[index]) return;
    setState(() => _revealed[index] = true);
    ProceduralSfxEngine.playSummonReveal(widget.cards[index].stars);
  }

  void _revealAll() {
    if (_allRevealed) return;
    setState(() {
      for (var i = 0; i < _revealed.length; i++) {
        _revealed[i] = true;
      }
    });
    final best =
        widget.cards.map((c) => c.stars).fold<int>(1, (a, b) => a > b ? a : b);
    ProceduralSfxEngine.playSummonReveal(best);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B0D14), Color(0xFF0A0508)],
          ),
          border: Border.all(color: BrimstoneTokens.goldPrimary, width: 1.6),
          boxShadow: [
            BoxShadow(
              color: BrimstoneTokens.goldPrimary.withValues(alpha: 0.25),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '¡INVOCACIÓN COMPLETADA!',
              textAlign: TextAlign.center,
              style: BrimstoneFonts.cinzel(
                size: 15,
                weight: FontWeight.w900,
                color: BrimstoneTokens.goldBright,
                letterSpacing: 1.8,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _allRevealed
                  ? '${widget.cards.length} carta(s) se han unido a tu colección.'
                  : 'Toca cada carta para revelar su sello.',
              textAlign: TextAlign.center,
              style: BrimstoneFonts.sans(
                size: 10.5,
                color: BrimstoneTokens.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 10,
              children: [
                for (var i = 0; i < widget.cards.length; i++)
                  GachaFlipCard(
                    card: widget.cards[i],
                    revealed: _revealed[i],
                    onTap: () => _revealCard(i),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _allRevealed ? null : _revealAll,
                    style: TextButton.styleFrom(
                      foregroundColor: BrimstoneTokens.goldPrimary,
                      disabledForegroundColor:
                          BrimstoneTokens.textMuted.withValues(alpha: 0.5),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                        side: BorderSide(
                          color: BrimstoneTokens.goldPrimary
                              .withValues(alpha: _allRevealed ? 0.25 : 0.75),
                        ),
                      ),
                    ),
                    child: Text(
                      'REVELAR TODAS',
                      style: BrimstoneFonts.cinzel(
                        size: 10.5,
                        weight: FontWeight.w800,
                        color: BrimstoneTokens.goldPrimary,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: BrimstoneTokens.textPrimary,
                  ),
                  child: const Text('Aceptar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One gacha card: 3D Y-axis flip between its rune back and the real TCG card.
class GachaFlipCard extends StatelessWidget {
  const GachaFlipCard({
    super.key,
    required this.card,
    required this.revealed,
    required this.onTap,
  });

  final OwnedCard card;
  final bool revealed;
  final VoidCallback onTap;

  static const double width = 82;
  static const double height = 112;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: revealed ? null : onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: revealed ? math.pi : 0),
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeInOutCubic,
        builder: (context, angle, _) {
          final showFront = angle > math.pi / 2;
          final transform = Matrix4.identity()
            ..setEntry(3, 2, 0.0018)
            ..rotateY(angle);
          return Transform(
            alignment: Alignment.center,
            transform: transform,
            child: SizedBox(
              width: width,
              height: height,
              child: showFront
                  ? Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(math.pi),
                      child: TcgCardWidget.fromOwnedCard(card: card),
                    )
                  : GothicCardBack(stars: card.stars),
            ),
          );
        },
      ),
    );
  }
}

/// Rune-sealed card back, tinted by the hidden rarity.
class GothicCardBack extends StatelessWidget {
  const GothicCardBack({super.key, required this.stars});

  final int stars;

  Color get _tint {
    if (stars >= 4) return const Color(0xFFFFD700);
    if (stars == 3) return const Color(0xFFB16EFF);
    return const Color(0xFF4C8DFF);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(const Color(0xFF14090D), _tint, 0.16)!,
            const Color(0xFF07040A),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _tint.withValues(alpha: 0.85), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: _tint.withValues(alpha: 0.35),
            blurRadius: stars >= 3 ? 14 : 7,
            spreadRadius: stars >= 3 ? 1.5 : 0,
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: CustomPaint(painter: GothicCardBackPainter(tint: _tint)),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  stars >= 4
                      ? Icons.wb_sunny
                      : stars == 3
                          ? Icons.auto_awesome
                          : Icons.diamond_outlined,
                  color: _tint,
                  size: 22,
                ),
                const SizedBox(height: 4),
                Text(
                  stars >= 4
                      ? 'LEGENDARIA'
                      : stars == 3
                          ? 'ÉPICA'
                          : 'RARA',
                  style: BrimstoneFonts.cinzel(
                    size: 7.5,
                    weight: FontWeight.w900,
                    color: _tint,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GothicCardBackPainter extends CustomPainter {
  const GothicCardBackPainter({required this.tint});

  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = tint.withValues(alpha: 0.35);
    // Rune lattice.
    for (var i = 0; i < 3; i++) {
      final inset = 4.0 + i * 5.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            inset,
            inset,
            size.width - inset * 2,
            size.height - inset * 2,
          ),
          const Radius.circular(5),
        ),
        paint,
      );
    }
    // Solar rays for mythic pulls.
    if (tint == const Color(0xFFFFD700)) {
      paint.color = tint.withValues(alpha: 0.18);
      for (var i = 0; i < 12; i++) {
        final angle = i * math.pi / 6;
        canvas.drawLine(
          center,
          Offset(
            center.dx + math.cos(angle) * size.width,
            center.dy + math.sin(angle) * size.height,
          ),
          paint,
        );
      }
    }
    // Central seal diamond.
    paint
      ..color = tint.withValues(alpha: 0.5)
      ..strokeWidth = 1.0;
    final r = size.shortestSide * 0.20;
    final diamond = Path()
      ..moveTo(center.dx, center.dy - r)
      ..lineTo(center.dx + r, center.dy)
      ..lineTo(center.dx, center.dy + r)
      ..lineTo(center.dx - r, center.dy)
      ..close();
    canvas.drawPath(diamond, paint);
  }

  @override
  bool shouldRepaint(covariant GothicCardBackPainter old) => old.tint != tint;
}

import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart' hide Element;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/procedural_sfx_engine.dart';
import '../../../domain/entities/owned_card.dart';
import '../../../domain/meta/meta_rules.dart';
import '../../controllers/meta_controller.dart';
import '../../widgets/brimstone_button.dart';
import '../../widgets/tcg_card_widget.dart';

/// Altar of Evolution: sacrifice a duplicate (same catalogId & stars) plus
/// gold to ascend a card 1 star, up to the 4-star golden halo.
/// Redesigned with Ritual Circle: Base Card + Sacrifice Copy → Preview.
class AltarEvolutionScreen extends ConsumerStatefulWidget {
  const AltarEvolutionScreen({super.key});

  @override
  ConsumerState<AltarEvolutionScreen> createState() =>
      _AltarEvolutionScreenState();
}

class _AltarEvolutionScreenState extends ConsumerState<AltarEvolutionScreen> {
  int? _selectedBaseId;
  int? _selectedSacrificeId;

  @override
  Widget build(BuildContext context) {
    final collectionState = ref.watch(collectionProvider);
    final allCards = collectionState.owned;

    final baseCard = _selectedBaseId != null
        ? allCards.firstWhereOrNull((c) => c.instanceId == _selectedBaseId)
        : null;
    final sacrificeCard = _selectedSacrificeId != null
        ? allCards.firstWhereOrNull((c) => c.instanceId == _selectedSacrificeId)
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0407),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14090D),
        elevation: 2,
        shadowColor: Colors.black87,
        title: const Text(
          'ALTAR DE EVOLUCIÓN',
          style: TextStyle(
            color: Color(0xFFD4AF37),
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFD4AF37)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _RitualCircle(
          baseCard: baseCard,
          sacrificeCard: sacrificeCard,
          allCards: allCards,
          onBaseSelected: (id) => setState(() => _selectedBaseId = id),
          onSacrificeSelected: (id) =>
              setState(() => _selectedSacrificeId = id),
        ),
      ),
    );
  }
}

/// Ritual Circle widget: three horizontal positions (Base, Arrow, Sacrifice)
/// with animated background circle when evolution is possible.
class _RitualCircle extends ConsumerWidget {
  const _RitualCircle({
    required this.baseCard,
    required this.sacrificeCard,
    required this.allCards,
    required this.onBaseSelected,
    required this.onSacrificeSelected,
  });

  final OwnedCard? baseCard;
  final OwnedCard? sacrificeCard;
  final List<OwnedCard> allCards;
  final ValueChanged<int> onBaseSelected;
  final ValueChanged<int> onSacrificeSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canEvolve = _canEvolve(baseCard, sacrificeCard);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF14090D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: canEvolve ? const Color(0xFFFFC93C) : Colors.white12,
          width: canEvolve ? 2 : 1,
        ),
        boxShadow: canEvolve
            ? [
                BoxShadow(
                  color: const Color(0xFFFFC93C).withValues(alpha: 0.3),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          Text(
            baseCard == null
                ? 'SELECCIONA CARTA BASE'
                : sacrificeCard == null
                    ? 'SELECCIONA CARTA DE SACRIFICIO'
                    : 'RITUAL LISTO',
            style: TextStyle(
              color: canEvolve ? const Color(0xFFFFC93C) : Colors.white54,
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),

          // Ritual Circle with 3 positions
          _RitualCircleWidget(
            baseCard: baseCard,
            sacrificeCard: sacrificeCard,
            canEvolve: canEvolve,
            allCards: allCards,
            onBaseSelected: onBaseSelected,
            onSacrificeSelected: onSacrificeSelected,
          ),

          const SizedBox(height: 16),

          // PREVIEW CARD
          if (baseCard != null) ...[
            Text(
              'VISTA PREVIA DE EVOLUCIÓN',
              style: TextStyle(
                color: canEvolve ? const Color(0xFF4FFFA3) : Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            _buildPreviewCard(baseCard, sacrificeCard, canEvolve),
            const SizedBox(height: 4),
            Text(
              '${baseCard!.name} ${'★' * baseCard!.stars} → ${'★' * _previewStars(baseCard, canEvolve).clamp(1, 4)}',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
            Text(
              'ATK ${baseCard!.baseAttack} → ${_previewAttack(baseCard, canEvolve)}  |  HP ${baseCard!.baseHealth} → ${_previewHealth(baseCard, canEvolve)}',
              style: const TextStyle(
                  color: Color(0xFFFF9E2C),
                  fontSize: 10,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (sacrificeCard != null)
              Text(
                'Sacrificio: ${sacrificeCard!.name} (${sacrificeCard!.stars}★)',
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            if (canEvolve) ...[
              const SizedBox(height: 12),
              Consumer(
                builder: (context, ref, _) {
                  final cost = EvolutionRules.costFor(baseCard!.stars);
                  final profile = ref.watch(profileProvider);
                  final canAfford = profile.gold >= cost;
                  return BrimstoneButton(
                    width: double.infinity,
                    height: 48,
                    icon: Icons.auto_fix_high,
                    label:
                        'EVOLUCIONAR A ${_previewStars(baseCard, canEvolve)}★ — $cost ORO',
                    onPressed: canAfford && canEvolve
                        ? () async {
                            final ok = await ref
                                .read(collectionProvider.notifier)
                                .evolve(baseCard!.instanceId);
                            if (!context.mounted) return;
                            if (ok) {
                              ProceduralSfxEngine.playEvolutionSuccess();
                              ref
                                  .read(bountyProvider.notifier)
                                  .increment('evolution');
                            } else {
                              ProceduralSfxEngine.playEvolutionFail();
                            }
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    ok
                                        ? '${baseCard!.name} asciende a ${_previewStars(baseCard, canEvolve)}★!'
                                        : 'Ritual fallido: faltan duplicados u oro.',
                                  ),
                                ),
                              );
                            }
                            // Clear selections via callbacks
                            onBaseSelected(-1);
                            onSacrificeSelected(-1);
                          }
                        : null,
                  );
                },
              ),
            ] else if (sacrificeCard != null && !canEvolve) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A0A0A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.5)),
                ),
                child: const Text(
                  'EVOLUCIÓN BLOQUEADA: El sacrificio debe ser el mismo ID y misma cantidad de estrellas.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.redAccent, fontSize: 11),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewCard(
      OwnedCard? base, OwnedCard? sacrifice, bool canEvolve) {
    if (base == null) return const SizedBox.shrink();
    final previewStars = _previewStars(base, canEvolve);
    final previewAttack = _previewAttack(base, canEvolve);
    final previewHealth = _previewHealth(base, canEvolve);
    final previewName = base.name;
    final previewElement = base.element;

    return TcgCardWidget.fromOwnedCard(
      card: OwnedCard(
        instanceId: -1,
        catalogId: base.catalogId,
        name: previewName,
        element: previewElement,
        rarity: base.rarity,
        baseManaCost: base.baseManaCost,
        baseAttack: previewAttack,
        baseHealth: previewHealth,
        level: base.level,
        stars: previewStars.clamp(1, 4),
      ),
      raised: true,
    );
  }

  int _previewStars(OwnedCard? base, bool canEvolve) {
    if (base == null) return 0;
    return base.stars + (canEvolve ? 1 : 0);
  }

  int _previewAttack(OwnedCard? base, bool canEvolve) {
    if (base == null) return 0;
    return canEvolve ? (base.baseAttack * 1.35).round() : base.baseAttack;
  }

  int _previewHealth(OwnedCard? base, bool canEvolve) {
    if (base == null) return 0;
    return canEvolve ? (base.baseHealth * 1.35).round() : base.baseHealth;
  }

  bool _canEvolve(OwnedCard? base, OwnedCard? sacrifice) {
    if (base == null || sacrifice == null) return false;
    if (base.stars >= EvolutionRules.maxStars) return false;
    return base.catalogId == sacrifice.catalogId &&
        base.stars == sacrifice.stars &&
        base.instanceId != sacrifice.instanceId;
  }
}

/// Animated ritual circle with rotating ring and particle effects.
class _RitualCircleWidget extends ConsumerStatefulWidget {
  const _RitualCircleWidget({
    required this.baseCard,
    required this.sacrificeCard,
    required this.canEvolve,
    required this.allCards,
    required this.onBaseSelected,
    required this.onSacrificeSelected,
  });

  final OwnedCard? baseCard;
  final OwnedCard? sacrificeCard;
  final bool canEvolve;
  final List<OwnedCard> allCards;
  final ValueChanged<int> onBaseSelected;
  final ValueChanged<int> onSacrificeSelected;

  @override
  ConsumerState<_RitualCircleWidget> createState() =>
      _RitualCircleWidgetState();
}

class _RitualCircleWidgetState extends ConsumerState<_RitualCircleWidget>
    with SingleTickerProviderStateMixin {
  AnimationController? _animCtrl;

  @override
  void initState() {
    super.initState();
    if (widget.canEvolve) {
      _initAnimation();
    }
  }

  @override
  void didUpdateWidget(covariant _RitualCircleWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.canEvolve && _animCtrl == null) {
      _initAnimation();
    } else if (!widget.canEvolve && _animCtrl != null) {
      _animCtrl?.stop();
      _animCtrl?.dispose();
      _animCtrl = null;
    }
  }

  void _initAnimation() {
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _animCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_animCtrl == null) {
      return _buildStaticCircle(widget.canEvolve);
    }
    return AnimatedBuilder(
      animation: _animCtrl!,
      builder: (context, _) =>
          _buildAnimatedCircle(widget.canEvolve, _animCtrl!.value),
    );
  }

  Widget _buildStaticCircle(bool canEvolve) {
    return Stack(
      alignment: Alignment.center,
      children: [
        CustomPaint(
          size: const Size(340, 180),
          painter: _RitualCirclePainter(
            progress: 0.0,
            active: canEvolve,
          ),
        ),
        _buildSlotsRow(canEvolve),
      ],
    );
  }

  Widget _buildAnimatedCircle(bool canEvolve, double progress) {
    return Stack(
      alignment: Alignment.center,
      children: [
        CustomPaint(
          size: const Size(340, 180),
          painter: _RitualCirclePainter(
            progress: progress,
            active: canEvolve,
          ),
        ),
        _buildSlotsRow(canEvolve, progress: progress),
      ],
    );
  }

  Widget _buildSlotsRow(bool canEvolve, {double progress = 0.0}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // BASE CARD SLOT
        _RitualSlot(
          label: 'CARTA BASE',
          card: widget.baseCard,
          isSelected: widget.baseCard != null,
          size: 100,
          onTap: () => _showCardPicker(
            context,
            label: 'Seleccionar carta base',
            cards: widget.allCards,
            excludeId: widget.sacrificeCard?.instanceId,
            onSelected: widget.onBaseSelected,
          ),
        ),
        // ARROW / TRANSFORM
        AnimatedRotation(
          turns: canEvolve ? progress * 0.5 : 0,
          duration: const Duration(milliseconds: 300),
          child: Icon(
            canEvolve ? Icons.auto_fix_high : Icons.arrow_forward,
            color: canEvolve ? const Color(0xFFFFC93C) : Colors.white24,
            size: 36,
          ),
        ),
        // SACRIFICE CARD SLOT
        _RitualSlot(
          label: 'SACRIFICIO',
          card: widget.sacrificeCard,
          isSelected: widget.sacrificeCard != null,
          size: 100,
          onTap: widget.baseCard == null
              ? null
              : () => _showCardPicker(
                    context,
                    label: 'Seleccionar sacrificio (mismo ID y estrellas)',
                    cards:
                        _getValidSacrifices(widget.baseCard!, widget.allCards),
                    onSelected: widget.onSacrificeSelected,
                  ),
        ),
      ],
    );
  }

  void _showCardPicker(
    BuildContext context, {
    required String label,
    required List<OwnedCard> cards,
    int? excludeId,
    required ValueChanged<int> onSelected,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF14090D),
      isScrollControlled: true,
      builder: (ctx) => _CardPickerSheet(
        title: label,
        cards: cards,
        excludeId: excludeId,
        onSelected: (id) {
          onSelected(id);
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  List<OwnedCard> _getValidSacrifices(
      OwnedCard base, List<OwnedCard> allCards) {
    return allCards
        .where((c) =>
            c.instanceId != base.instanceId &&
            c.catalogId == base.catalogId &&
            c.stars == base.stars)
        .toList();
  }
}

/// Individual ritual slot showing a card or empty placeholder.
class _RitualSlot extends StatelessWidget {
  const _RitualSlot({
    required this.label,
    required this.card,
    required this.isSelected,
    required this.size,
    this.onTap,
  });

  final String label;
  final OwnedCard? card;
  final bool isSelected;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? const Color(0xFFFFC93C) : Colors.white12,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFFC93C).withValues(alpha: 0.4),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: card != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: TcgCardWidget.fromOwnedCard(
                      card: card!,
                      width: size,
                      height: size,
                    ),
                  )
                : Center(
                    child: Icon(
                      Icons.add_circle_outline,
                      color: Colors.white24,
                      size: size * 0.4,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

/// Painter for the animated ritual circle background.
class _RitualCirclePainter extends CustomPainter {
  _RitualCirclePainter({required this.progress, required this.active});

  final double progress;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 20;

    if (!active) return;

    // Outer rotating ring
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..shader = SweepGradient(
        startAngle: progress * 2 * math.pi,
        endAngle: progress * 2 * math.pi + 2 * math.pi,
        colors: [
          const Color(0xFFFFC93C).withValues(alpha: 0.0),
          const Color(0xFFFFC93C).withValues(alpha: 0.8),
          const Color(0xFFFF2A54).withValues(alpha: 0.8),
          const Color(0xFFFFC93C).withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.3, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, ringPaint);

    // Inner pulsing circle
    final pulse = (math.sin(progress * 2 * math.pi * 2) + 1) / 2;
    final innerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFFFFC93C).withValues(alpha: 0.3 + 0.3 * pulse);
    canvas.drawCircle(center, radius * 0.6, innerPaint);

    // Rune symbols at cardinal points
    for (int i = 0; i < 4; i++) {
      final angle = i * math.pi / 2 + progress * 2 * math.pi;
      final r = radius * 0.8;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      final runePaint = Paint()
        ..color = const Color(0xFFFFC93C).withValues(alpha: 0.5 + 0.3 * pulse)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), 3, runePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RitualCirclePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.active != active;
}

/// Card picker bottom sheet for selecting base or sacrifice card.
class _CardPickerSheet extends StatelessWidget {
  const _CardPickerSheet({
    required this.title,
    required this.cards,
    required this.onSelected,
    this.excludeId,
  });

  final String title;
  final List<OwnedCard> cards;
  final ValueChanged<int> onSelected;
  final int? excludeId;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<OwnedCard>>{};
    for (final card in cards) {
      if (excludeId != null && card.instanceId == excludeId) continue;
      grouped.putIfAbsent(card.catalogId, () => []).add(card);
    }

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFFD4AF37),
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.74,
                ),
                itemCount: grouped.length,
                itemBuilder: (context, i) {
                  final catalogId = grouped.keys.elementAt(i);
                  final copies = grouped[catalogId]!;
                  final baseCardId = copies.first.instanceId;
                  final isBase = copies.any((c) => c.instanceId == baseCardId);

                  return _CollectionCardTile(
                    card: copies.first,
                    copies: copies.length,
                    isBase: isBase,
                    onTap: () => onSelected(copies.first.instanceId),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card tile in the collection picker.
class _CollectionCardTile extends StatelessWidget {
  const _CollectionCardTile({
    required this.card,
    required this.copies,
    required this.isBase,
    required this.onTap,
  });

  final OwnedCard card;
  final int copies;
  final bool isBase;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isBase ? const Color(0xFFFFC93C) : Colors.white12,
            width: isBase ? 2 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              TcgCardWidget.fromOwnedCard(
                card: card,
                width: double.infinity,
                height: double.infinity,
              ),
              if (copies > 1)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'x$copies',
                      style: const TextStyle(
                        color: Color(0xFFD4AF37),
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              if (isBase)
                Positioned(
                  bottom: 2,
                  left: 2,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFFFC93C), Color(0xFFFF5A26)],
                      ),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        'BASE',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 7,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
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

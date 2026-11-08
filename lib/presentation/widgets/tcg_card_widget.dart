import 'dart:math' as math;

import 'package:flutter/material.dart' hide Element;

import '../../domain/combat/combat_models.dart';
import '../../domain/entities/owned_card.dart';
import '../../domain/value_objects/element.dart';
import '../../domain/value_objects/rarity.dart';

/// Master Gothic TCG Card Widget used universally across:
/// Combat, Sanctuary, Barracks, Altar of Evolution, and Summon Portal.
///
/// Features:
/// - Beveled gothic metallic frame per star rank (1★ Bronze, 2★ Silver Cyan, 3★ Imperial Gold, 4★ Radiant Crimson Gold).
/// - Full-color Wesnoth painted portrait background (assets/portraits/).
/// - Top bar: Element medallion, stars (★), level (Nv.X), and LEADER badge if in slot 0.
/// - Bottom bar: Creature name, ATK sword indicator, and equipped Rune badge.
/// - Combat mode (`inCombat: true`): Liquid mana rising fill with glow, mana/maxMana text,
///   8px elevation, pulsating gold border, and radiant "¡INVOCAR!" button at 100% mana.
class TcgCardWidget extends StatefulWidget {
  final String cardId;
  final String name;
  final Element element;
  final Rarity rarity;
  final int stars;
  final int level;
  final int attack;
  final int currentMana;
  final int maxMana;
  final bool isLeader;
  final String? runeName;
  final bool inCombat;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final bool raised;

  const TcgCardWidget({
    super.key,
    required this.cardId,
    required this.name,
    required this.element,
    this.rarity = Rarity.common,
    this.stars = 1,
    this.level = 1,
    this.attack = 10,
    this.currentMana = 0,
    this.maxMana = 100,
    this.isLeader = false,
    this.runeName,
    this.inCombat = false,
    this.onTap,
    this.width,
    this.height,
    this.raised = false,
  });

  /// Factory helper for domain [OwnedCard].
  factory TcgCardWidget.fromOwnedCard({
    Key? key,
    required OwnedCard card,
    bool isLeader = false,
    String? runeName,
    bool inCombat = false,
    int currentMana = 0,
    int? maxMana,
    VoidCallback? onTap,
    double? width,
    double? height,
    bool raised = false,
  }) {
    return TcgCardWidget(
      key: key,
      cardId: card.catalogId,
      name: card.name,
      element: card.element,
      rarity: card.rarity,
      stars: card.stars,
      level: card.level,
      attack: card.baseAttack,
      currentMana: currentMana,
      maxMana: maxMana ?? card.baseManaCost,
      isLeader: isLeader,
      runeName: runeName,
      inCombat: inCombat,
      onTap: onTap,
      width: width,
      height: height,
      raised: raised,
    );
  }

  /// Factory helper for combat [ManaCard].
  factory TcgCardWidget.fromCombatCard({
    Key? key,
    required ManaCard card,
    bool isLeader = false,
    String? runeName,
    VoidCallback? onTap,
    double? width,
    double? height,
  }) {
    return TcgCardWidget(
      key: key,
      cardId: card.id,
      name: card.name,
      element: card.element,
      stars: card.stars,
      level: 1,
      attack: card.attack.toInt(),
      currentMana: card.mana.toInt(),
      maxMana: card.baseManaCost.toInt(),
      isLeader: isLeader,
      runeName: runeName,
      inCombat: true,
      onTap: onTap,
      width: width,
      height: height,
    );
  }

  @override
  State<TcgCardWidget> createState() => _TcgCardWidgetState();
}

class _TcgCardWidgetState extends State<TcgCardWidget>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulseCtrl;

  @override
  void initState() {
    super.initState();
    if (widget.inCombat) {
      _pulseCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900),
      )..repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant TcgCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.inCombat && !oldWidget.inCombat) {
      _pulseCtrl ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900),
      )..repeat(reverse: true);
    } else if (!widget.inCombat && oldWidget.inCombat) {
      _pulseCtrl?.stop();
    }
  }

  @override
  void dispose() {
    _pulseCtrl?.dispose();
    super.dispose();
  }

  // 1★ Bronze (#8C6239), 2★ Silver Cyan (#4FC3F7), 3★ Imperial Gold (#D4AF37), 4★ Radiant Crimson Gold (#FF2A54 + #FFD700)
  List<Color> get _frameBorderColors => switch (widget.stars.clamp(1, 4)) {
        1 => const [Color(0xFF8C6239), Color(0xFF5A3A1E)],
        2 => const [Color(0xFF80E8FF), Color(0xFF4FC3F7), Color(0xFF1E88E5)],
        3 => const [Color(0xFFFFDF73), Color(0xFFD4AF37), Color(0xFF8C6D1F)],
        4 => const [Color(0xFFFF2A54), Color(0xFFFFD700), Color(0xFFFF2A54)],
        _ => const [Color(0xFF8C6239), Color(0xFF5A3A1E)],
      };

  Color get _primaryBorderColor => switch (widget.stars.clamp(1, 4)) {
        1 => const Color(0xFF8C6239),
        2 => const Color(0xFF4FC3F7),
        3 => const Color(0xFFD4AF37),
        4 => const Color(0xFFFFD700),
        _ => const Color(0xFF8C6239),
      };

  Color get _elementColor => switch (widget.element) {
        Element.igneous => const Color(0xFFFF5A26),
        Element.abyssal => const Color(0xFF3FD8FF),
        Element.telluric => const Color(0xFFB0703B),
        Element.empty => const Color(0xFFB16EFF),
      };

  IconData get _elementIcon => switch (widget.element) {
        Element.igneous => Icons.local_fire_department,
        Element.abyssal => Icons.water_drop,
        Element.telluric => Icons.shield,
        Element.empty => Icons.auto_awesome,
      };

  bool get _isReady =>
      widget.inCombat && (widget.currentMana >= widget.maxMana);

  String get _portraitAssetPath => 'assets/portraits/${widget.cardId}.webp';

  @override
  Widget build(BuildContext context) {
    final manaFrac = widget.maxMana > 0
        ? (widget.currentMana / widget.maxMana).clamp(0.0, 1.0)
        : 0.0;

    // If not in combat, no pulse animation needed - build directly
    if (!widget.inCombat) {
      return _buildCardContent(0.0, manaFrac);
    }

    // In combat: use AnimatedBuilder for pulse animation
    return AnimatedBuilder(
      animation: _pulseCtrl!,
      builder: (context, _) => _buildCardContent(_pulseCtrl!.value, manaFrac),
    );
  }

  Widget _buildCardContent(double pulse, double manaFrac) {
    final isReady = _isReady;
    final double elevation = isReady ? 8.0 : (widget.raised ? 4.0 : 0.0);

    final List<BoxShadow> shadows = [];
    if (isReady) {
      shadows.add(
        BoxShadow(
          color: const Color(0xFFFFD700).withValues(alpha: 0.6 + 0.4 * pulse),
          blurRadius: 16 + 6 * pulse,
          spreadRadius: 2 + 2 * pulse,
        ),
      );
      shadows.add(
        BoxShadow(
          color: const Color(0xFFFF2A54).withValues(alpha: 0.5 * pulse),
          blurRadius: 24,
          spreadRadius: 3,
        ),
      );
    } else if (widget.stars >= 4) {
      shadows.add(
        BoxShadow(
          color: const Color(0xFFFF2A54).withValues(alpha: 0.45),
          blurRadius: 10,
          spreadRadius: 1,
        ),
      );
    } else if (widget.raised) {
      shadows.add(
        BoxShadow(
          color: _elementColor.withValues(alpha: 0.35),
          blurRadius: 8,
          spreadRadius: 1,
        ),
      );
    }

    final cardWidth = widget.width ?? 112.0;
    final cardHeight = widget.height ?? 160.0;

    // Build stack children as a list to avoid collection-if parsing issues
    final List<Widget> stackChildren = [
      // 1. Full-color painted portrait from Wesnoth
      Positioned.fill(
        child: Image.asset(
          _portraitAssetPath,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          errorBuilder: (context, error, stackTrace) =>
              Container(color: const Color(0xFF1A0A0F)),
        ),
      ),

      // 2. Dark bottom scrim for name/ATK/mana readability
      Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        height: 70,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Color(0xF50A0407),
                Color(0xBB0A0407),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),

      // 3. Dark top scrim for header readability
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        height: 38,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xEE0A0407),
                Color(0x990A0407),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),

      // 4. Liquid Mana Rising Overlay (In Combat)
      if (widget.inCombat && manaFrac > 0)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: cardHeight * manaFrac,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  _elementColor.withValues(alpha: 0.45),
                  _elementColor.withValues(alpha: 0.15),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

      // 5. TOP BAR: Medallion, Stars, Level, Leader Badge
      Positioned(
        top: 4,
        left: 4,
        right: 4,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Element Medallion
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF160910),
                border: Border.all(
                  color: _elementColor,
                  width: 1.2,
                ),
              ),
              child: Center(
                child: Icon(
                  _elementIcon,
                  size: 10,
                  color: _elementColor,
                ),
              ),
            ),
            const SizedBox(width: 3),

            // Stars row - flexible to prevent overflow
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < widget.stars; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 1),
                      child: Icon(
                        Icons.star,
                        size: 9,
                        color: widget.stars >= 4
                            ? const Color(0xFFFFD700)
                            : (widget.stars == 3
                                ? const Color(0xFFFFDF73)
                                : (widget.stars == 2
                                    ? const Color(0xFF80E8FF)
                                    : const Color(0xFFCD7F32))),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(width: 4),

            // Level badge
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: Colors.white24,
                    width: 0.8,
                  ),
                ),
                child: Text(
                  'Nv.${widget.level}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

            // Leader badge
            if (widget.isLeader) ...[
              const SizedBox(width: 2),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 3,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFF5A26)],
                    ),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66FF5A26),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: const Text(
                    'LÍDER',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 7,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),

      // 6. BOTTOM BAR: Name, ATK, Rune badge, Mana bar (inCombat)
      Positioned(
        bottom: 4,
        left: 4,
        right: 4,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Name + Rune
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
                if (widget.runeName != null && widget.runeName!.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(left: 3),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 3,
                      vertical: 0.5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A153A),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: const Color(0xFFB16EFF),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      widget.runeName!,
                      style: const TextStyle(
                        color: Color(0xFFE5D4FF),
                        fontSize: 7.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),

            // ATK + Mana/MaxMana
            Row(
              children: [
                // ATK with sword icon
                const Icon(
                  Icons.colorize,
                  size: 10,
                  color: Color(0xFFFF5A26),
                ),
                const SizedBox(width: 2),
                Text(
                  '${widget.attack}',
                  style: const TextStyle(
                    color: Color(0xFFFF9E2C),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const Spacer(),

                if (widget.inCombat)
                  Text(
                    '${widget.currentMana}/${widget.maxMana}',
                    style: TextStyle(
                      color: isReady ? const Color(0xFFFFD700) : Colors.white70,
                      fontSize: 9,
                      fontWeight: isReady ? FontWeight.w900 : FontWeight.w600,
                    ),
                  ),
              ],
            ),

            // Mana bar indicator in combat
            if (widget.inCombat) ...[
              const SizedBox(height: 2),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: Container(
                  height: 3,
                  color: const Color(0xFF1E0A12),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: manaFrac,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isReady
                              ? const [
                                  Color(0xFFFFD700),
                                  Color(0xFFFF2A54),
                                ]
                              : [
                                  _elementColor,
                                  _elementColor.withValues(alpha: 0.7),
                                ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),

      // 7. ¡INVOCAR! Button when 100% mana (at bottom edge, not covering art)
      if (isReady)
        Positioned(
          bottom: 4,
          left: 4,
          right: 4,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF2A54), Color(0xFFFFD700)],
                ),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.8),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
                border: Border.all(
                  color: Colors.white,
                  width: 1.2,
                ),
              ),
              child: const Text(
                '¡INVOCAR!',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
        ),

      // 8. Golden flaming border frame when ready
      if (isReady)
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _ReadyFramePainter(
                pulse: pulse,
                borderWidth: 2.8,
              ),
            ),
          ),
        ),

      // 9. Beveled Metallic Gothic Border Frame
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            painter: _GothicBeveledFramePainter(
              borderColors: isReady
                  ? [
                      Color.lerp(
                        const Color(0xFFFFD700),
                        Colors.white,
                        pulse,
                      )!,
                      const Color(0xFFFF2A54),
                    ]
                  : _frameBorderColors,
              primaryColor:
                  isReady ? const Color(0xFFFFD700) : _primaryBorderColor,
              borderWidth: isReady ? 2.8 : (widget.raised ? 2.4 : 1.8),
              stars: widget.stars,
            ),
          ),
        ),
      ),
    ];

    return Transform.translate(
      offset: Offset(0, isReady ? -elevation : 0),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: cardWidth,
          height: cardHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF22111A), Color(0xFF10070B), Color(0xFF070205)],
            ),
            boxShadow: shadows,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              fit: StackFit.expand,
              children: stackChildren,
            ),
          ),
        ),
      ),
    );
  }
}

/// Painter for the golden flaming border when card is ready to invoke.
class _ReadyFramePainter extends CustomPainter {
  final double pulse;
  final double borderWidth;

  _ReadyFramePainter({required this.pulse, required this.borderWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    const cornerCut = 7.0;

    final path = Path()
      ..moveTo(cornerCut, 0)
      ..lineTo(size.width - cornerCut, 0)
      ..lineTo(size.width, cornerCut)
      ..lineTo(size.width, size.height - cornerCut)
      ..lineTo(size.width - cornerCut, size.height)
      ..lineTo(cornerCut, size.height)
      ..lineTo(0, size.height - cornerCut)
      ..lineTo(0, cornerCut)
      ..close();

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(const Color(0xFFFFD700), Colors.white,
              math.sin(pulse * math.pi))!,
          const Color(0xFFFF2A54),
          Color.lerp(const Color(0xFFFFD700), Colors.white,
              math.sin(pulse * math.pi + 1))!,
        ],
      ).createShader(rect);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ReadyFramePainter oldDelegate) =>
      oldDelegate.pulse != pulse || oldDelegate.borderWidth != borderWidth;
}

/// Gothic beveled metallic frame painter with corner facets.
class _GothicBeveledFramePainter extends CustomPainter {
  final List<Color> borderColors;
  final Color primaryColor;
  final double borderWidth;
  final int stars;

  _GothicBeveledFramePainter({
    required this.borderColors,
    required this.primaryColor,
    required this.borderWidth,
    required this.stars,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    const cornerCut = 7.0;

    // Beveled octagonal path
    final path = Path()
      ..moveTo(cornerCut, 0)
      ..lineTo(size.width - cornerCut, 0)
      ..lineTo(size.width, cornerCut)
      ..lineTo(size.width, size.height - cornerCut)
      ..lineTo(size.width - cornerCut, size.height)
      ..lineTo(cornerCut, size.height)
      ..lineTo(0, size.height - cornerCut)
      ..lineTo(0, cornerCut)
      ..close();

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    if (borderColors.length > 1) {
      paint.shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: borderColors,
      ).createShader(rect);
    } else {
      paint.color = primaryColor;
    }

    canvas.drawPath(path, paint);

    // Corner rivet / jewel accents on high star ranks
    if (stars >= 2) {
      final accentPaint = Paint()
        ..color = primaryColor
        ..style = PaintingStyle.fill;
      for (final p in [
        const Offset(cornerCut, cornerCut),
        Offset(size.width - cornerCut, cornerCut),
        Offset(cornerCut, size.height - cornerCut),
        Offset(size.width - cornerCut, size.height - cornerCut),
      ]) {
        canvas.drawCircle(p, stars >= 3 ? 2.2 : 1.6, accentPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GothicBeveledFramePainter oldDelegate) =>
      oldDelegate.primaryColor != primaryColor ||
      oldDelegate.borderWidth != borderWidth ||
      oldDelegate.stars != stars;
}

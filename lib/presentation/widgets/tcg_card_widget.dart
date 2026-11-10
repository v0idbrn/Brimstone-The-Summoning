import 'dart:math' as math;

import 'package:flutter/material.dart' hide Element;

import '../../core/theme/design_tokens.dart';
import '../../domain/combat/combat_models.dart';
import '../../domain/entities/owned_card.dart';
import '../../domain/value_objects/element.dart';
import '../../domain/value_objects/rarity.dart';
import '../graphics/art_registry.dart';
import '../graphics/rift_effect.dart';

/// Master Gothic TCG card, used everywhere: combat hand, Sanctuary squad,
/// Barracks, Altar of Evolution, Summon Portal, loot chests and the Codex.
///
/// Commercial-grade composition:
///   * **Multi-layer metallic frame** — dark outer bevel, engraved gold fillet,
///     chiselled gothic corner pieces and a bevelled light/shadow pass.
///   * **Evolution drama** — Bronze (1★), Runic Frost Silver (2★), Imperial
///     Gold with holographic foil (3★), Mythic Obsidian/Crimson with animated
///     foil + ember veins (4★).
///   * **Jewel socket** top-left with the elemental sigil and a glowing crown of
///     stars.
///   * **Clean interior** — painted art on the upper 74%, vignette grade, a
///     frosted dark-glass ribbon with a hairline gold fillet, Cinzel nameplate,
///     metallic sword ATK emblem, Mastery/Rune badge.
///   * **Combat mode** — liquid mana climbing the side and bottom edges; at
///     100% the whole card ignites with gold/elemental energy and shows
///     «¡INVOCAR!».
class TcgCardWidget extends StatefulWidget {
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

  int get _starRank => widget.stars.clamp(1, 4);

  /// Evolution palette: bronze → frost silver → imperial gold → mythic crimson.
  List<Color> get _frameColors => switch (_starRank) {
        1 => const [Color(0xFFB07B4A), Color(0xFF6E4626), Color(0xFF3A2313)],
        2 => const [Color(0xFFEAF7FF), Color(0xFF8FD8F5), Color(0xFF3B7FA8)],
        3 => const [Color(0xFFFFF0B8), Color(0xFFD4AF37), Color(0xFF8C6D1F)],
        _ => const [Color(0xFFFFD700), Color(0xFFFF2A54), Color(0xFF3A0512)],
      };

  Color get _primary => switch (_starRank) {
        1 => const Color(0xFFB07B4A),
        2 => const Color(0xFF8FD8F5),
        3 => const Color(0xFFD4AF37),
        _ => const Color(0xFFFFC93C),
      };

  Color get _elementColor => BrimstoneElements.forElement(widget.element);

  Color get _elementGlow => BrimstoneElements.forElementGlow(widget.element);

  IconData get _elementIcon => switch (widget.element) {
        Element.igneous => Icons.local_fire_department,
        Element.abyssal => Icons.water_drop,
        Element.telluric => Icons.shield,
        Element.empty => Icons.auto_awesome,
      };

  bool get _isReady => widget.inCombat && widget.currentMana >= widget.maxMana;

  String get _portraitAssetPath => ArtRegistry.portrait(widget.cardId);

  @override
  Widget build(BuildContext context) {
    final manaFrac = widget.maxMana > 0
        ? (widget.currentMana / widget.maxMana).clamp(0.0, 1.0)
        : 0.0;

    if (!widget.inCombat) {
      return _buildCard(0.0, manaFrac);
    }
    return AnimatedBuilder(
      animation: _pulseCtrl!,
      builder: (context, _) => _buildCard(_pulseCtrl!.value, manaFrac),
    );
  }

  Widget _buildCard(double pulse, double manaFrac) {
    final isReady = _isReady;
    final cardWidth = widget.width ?? 112.0;
    final cardHeight = widget.height ?? 160.0;
    final showFoil = _starRank >= 3;
    final elevation = isReady ? 8.0 : (widget.raised ? 4.0 : 0.0);

    final shadows = <BoxShadow>[
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.55),
        blurRadius: widget.raised || isReady ? 14 : 6,
        offset: const Offset(0, 4),
      ),
      if (isReady)
        BoxShadow(
          color: const Color(0xFFFFD700).withValues(alpha: 0.55 + 0.4 * pulse),
          blurRadius: 18 + 8 * pulse,
          spreadRadius: 2 + 2 * pulse,
        )
      else if (showFoil)
        BoxShadow(
          color: _primary.withValues(alpha: 0.30),
          blurRadius: 10,
          spreadRadius: 1,
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
            borderRadius: BorderRadius.circular(9),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF22111A), Color(0xFF0E0609), Color(0xFF050203)],
            ),
            boxShadow: shadows,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;
                final ribbonH = h * 0.27;
                final scale = (w / 112.0).clamp(0.55, 1.25);

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // 1. Painted illustration (upper 74%) with grade.
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      bottom: ribbonH,
                      child: Image.asset(
                        _portraitAssetPath,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (_, __, ___) => DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color.lerp(const Color(0xFF1A0A0F),
                                    _elementColor, 0.25)!,
                                const Color(0xFF0A0407),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // 2. Illustration vignette + elemental grade.
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      bottom: ribbonH,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            radius: 1.0,
                            colors: [
                              Colors.transparent,
                              const Color(0xFF06030A).withValues(alpha: 0.55),
                            ],
                            stops: const [0.55, 1.0],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      bottom: ribbonH,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              _elementColor.withValues(alpha: 0.10),
                              Colors.transparent,
                              _elementColor.withValues(alpha: 0.16),
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // 3. Frosted dark-glass ribbon with gold fillet.
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: ribbonH,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              const Color(0xFF1B0E16).withValues(alpha: 0.94),
                              const Color(0xFF07030A).withValues(alpha: 0.98),
                            ],
                          ),
                          border: Border(
                            top: BorderSide(
                              color: _primary.withValues(alpha: 0.75),
                              width: 1.1,
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 5 * scale,
                            vertical: 3 * scale,
                          ),
                          // Squashed cards (mini tiles) shrink the ribbon content
                          // instead of overflowing it.
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              width: (w - 10 * scale).clamp(1.0, 400.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    widget.name.toUpperCase(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        BrimstoneTypography.cardName.copyWith(
                                      fontSize: 10.5 * scale,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(height: 2 * scale),
                                  Row(
                                    children: [
                                      // Metallic sword ATK emblem.
                                      Icon(
                                        Icons.colorize,
                                        size: 10 * scale,
                                        color: _primary,
                                      ),
                                      SizedBox(width: 2 * scale),
                                      Text(
                                        '${widget.attack}',
                                        style: TextStyle(
                                          fontFamily: BrimstoneFonts.body,
                                          fontSize: 10 * scale,
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFFFFC93C),
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                          shadows: const [
                                            Shadow(
                                                color: Colors.black,
                                                blurRadius: 3),
                                          ],
                                        ),
                                      ),
                                      if (widget.runeName != null &&
                                          widget.runeName!.isNotEmpty) ...[
                                        SizedBox(width: 3 * scale),
                                        Flexible(
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 3 * scale,
                                              vertical: 0.5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF2A153A),
                                              borderRadius:
                                                  BorderRadius.circular(3),
                                              border: Border.all(
                                                color: const Color(0xFFB16EFF)
                                                    .withValues(alpha: 0.7),
                                                width: 0.7,
                                              ),
                                            ),
                                            child: Text(
                                              widget.runeName!,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontFamily: BrimstoneFonts.body,
                                                color: const Color(0xFFE5D4FF),
                                                fontSize: 6.5 * scale,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                      const Spacer(),
                                      if (widget.inCombat)
                                        Text(
                                          '${widget.currentMana}/${widget.maxMana}',
                                          style: TextStyle(
                                            fontFamily: BrimstoneFonts.body,
                                            fontSize: 9 * scale,
                                            fontWeight: isReady
                                                ? FontWeight.w900
                                                : FontWeight.w600,
                                            color: isReady
                                                ? const Color(0xFFFFD700)
                                                : Colors.white70,
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // 4. Header: jewel, stars, level, leader.
                    Positioned(
                      top: 4 * scale,
                      left: 4 * scale,
                      right: 4 * scale,
                      child: Row(
                        children: [
                          _JewelSigil(
                            color: _elementColor,
                            glow: _elementGlow,
                            icon: _elementIcon,
                            size: 15 * scale,
                          ),
                          SizedBox(width: 3 * scale),
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (var i = 0; i < widget.stars; i++)
                                  Icon(
                                    Icons.star,
                                    size: 8.5 * scale,
                                    color: _primary,
                                    shadows: [
                                      Shadow(
                                        color: _primary.withValues(alpha: 0.8),
                                        blurRadius: 3,
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 3),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 3 * scale,
                              vertical: 0.5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.22),
                                width: 0.7,
                              ),
                            ),
                            child: Text(
                              'Nv.${widget.level}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: BrimstoneFonts.body,
                                color: Colors.white70,
                                fontSize: 7 * scale,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (widget.isLeader) ...[
                            const SizedBox(width: 2),
                            Flexible(
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 3 * scale,
                                  vertical: 0.5,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFFFD700),
                                      Color(0xFFFF5A26)
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(3),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x66FF5A26),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  'LÍDER',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: BrimstoneFonts.body,
                                    color: Colors.black,
                                    fontSize: 6.2 * scale,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // 5. Combat liquid mana (bottom + side edges).
                    if (widget.inCombat && manaFrac > 0)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _ManaLiquidPainter(
                              fraction: manaFrac,
                              color: _elementColor,
                              glow: _elementGlow,
                              ready: isReady,
                              pulse: pulse,
                            ),
                          ),
                        ),
                      ),
                    // 6. Holographic foil (3★/4★).
                    if (showFoil)
                      Positioned.fill(
                        child: FoilSheen(
                          tint: _starRank >= 4
                              ? const Color(0xFFFF2A54)
                              : const Color(0xFFFFE9A3),
                          intensity: _starRank >= 4 ? 0.62 : 0.30,
                          animate: widget.raised || widget.inCombat,
                          borderRadius: 9,
                        ),
                      ),
                    // 7. Ornate metallic frame on top of everything.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _AaaFramePainter(
                            colors: _frameColors,
                            primary: isReady
                                ? Color.lerp(const Color(0xFFFFD700),
                                    Colors.white, pulse)!
                                : _primary,
                            elementColor: _elementColor,
                            rank: _starRank,
                            ready: isReady,
                            pulse: pulse,
                          ),
                        ),
                      ),
                    ),
                    // 8. ¡INVOCAR! ignition banner.
                    if (isReady)
                      Positioned(
                        left: 4,
                        right: 4,
                        bottom: ribbonH * 0.42,
                        child: Center(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10 * scale,
                              vertical: 2.5 * scale,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF2A54), Color(0xFFFFD700)],
                              ),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: Colors.white, width: 1),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFFD700)
                                      .withValues(alpha: 0.85),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Text(
                              '¡INVOCAR!',
                              style: TextStyle(
                                fontFamily: BrimstoneFonts.display,
                                color: Colors.black,
                                fontSize: 8.5 * scale,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Elemental jewel socket (diamond-cut gem + inner sigil).
class _JewelSigil extends StatelessWidget {
  const _JewelSigil({
    required this.color,
    required this.glow,
    required this.icon,
    required this.size,
  });

  final Color color;
  final Color glow;
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.35),
          colors: [
            Colors.white,
            glow,
            color,
            Color.lerp(color, Colors.black, 0.6)!
          ],
          stops: const [0.0, 0.28, 0.68, 1.0],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.55),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(color: glow.withValues(alpha: 0.6), blurRadius: size * 0.5),
        ],
      ),
      child: Center(
        child: Icon(icon, size: size * 0.58, color: Colors.white),
      ),
    );
  }
}

/// Ornate multi-layer frame: dark bevel, engraved fillet, gothic corners,
/// crown lug and (for 4★) ember veins.
class _AaaFramePainter extends CustomPainter {
  _AaaFramePainter({
    required this.colors,
    required this.primary,
    required this.elementColor,
    required this.rank,
    required this.ready,
    required this.pulse,
  });

  final List<Color> colors;
  final Color primary;
  final Color elementColor;
  final int rank;
  final bool ready;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    const cut = 8.0;

    final outline = Path()
      ..moveTo(cut, 0)
      ..lineTo(size.width - cut, 0)
      ..lineTo(size.width, cut)
      ..lineTo(size.width, size.height - cut)
      ..lineTo(size.width - cut, size.height)
      ..lineTo(cut, size.height)
      ..lineTo(0, size.height - cut)
      ..lineTo(0, cut)
      ..close();

    // 1. Outer shadow bevel.
    final shadow = Path()..addPath(outline, Offset.zero);
    canvas.drawPath(
      shadow,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0
        ..color = Colors.black.withValues(alpha: 0.65),
    );

    // 2. Metallic gradient body of the frame.
    canvas.drawPath(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ).createShader(rect),
    );

    // 3. Inner engraved fillet (light top-left, dark bottom-right).
    final inner = Path()..addPath(outline, Offset.zero);
    canvas.save();
    canvas.clipPath(inner);
    canvas.drawLine(
      Offset(0, 5),
      Offset(size.width, 5),
      Paint()
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.22),
    );
    canvas.drawLine(
      Offset(0, size.height - 5),
      Offset(size.width, size.height - 5),
      Paint()
        ..strokeWidth = 1.2
        ..color = Colors.black.withValues(alpha: 0.65),
    );
    canvas.restore();

    // 4. Chiselled gothic corner filigree.
    final corner = Paint()
      ..style = PaintingStyle.fill
      ..color = primary.withValues(alpha: 0.85);
    final cornerDark = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.black.withValues(alpha: 0.7);
    void cornerPiece(double x, double y, double dx, double dy) {
      final path = Path()
        ..moveTo(x, y)
        ..lineTo(x + dx * 7, y)
        ..quadraticBezierTo(x + dx * 4, y + dy * 4, x, y + dy * 7)
        ..close();
      canvas.drawPath(path, cornerDark);
      canvas.drawPath(
        Path()
          ..moveTo(x + dx * 1.4, y + dy * 1.4)
          ..lineTo(x + dx * 4.4, y + dy * 1.4)
          ..quadraticBezierTo(
              x + dx * 2.6, y + dy * 2.6, x + dx * 1.4, y + dy * 4.4)
          ..close(),
        corner,
      );
    }

    cornerPiece(0, 0, 1, 1);
    cornerPiece(size.width, 0, -1, 1);
    cornerPiece(0, size.height, 1, -1);
    cornerPiece(size.width, size.height, -1, -1);

    // 5. Elemental energy seam at the ribbon junction.
    canvas.drawLine(
      Offset(4, size.height * 0.73),
      Offset(size.width - 4, size.height * 0.73),
      Paint()
        ..strokeWidth = 1.0
        ..color = elementColor.withValues(alpha: 0.35),
    );

    // 6. 4★ ember veins crawling the frame.
    if (rank >= 4) {
      final vein = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = const Color(0xFFFF5A26)
            .withValues(alpha: 0.35 + 0.25 * math.sin(pulse * math.pi));
      final vp = Path()
        ..moveTo(size.width * 0.5, 0)
        ..quadraticBezierTo(
          size.width * 0.62,
          size.height * 0.2,
          size.width * 0.52,
          size.height * 0.4,
        );
      canvas.drawPath(vp, vein);
      final vp2 = Path()
        ..moveTo(size.width, size.height * 0.45)
        ..quadraticBezierTo(
          size.width * 0.85,
          size.height * 0.66,
          size.width * 0.94,
          size.height * 0.92,
        );
      canvas.drawPath(vp2, vein);
    }

    // 7. Ready ignition overlay.
    if (ready) {
      final glow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..shader = SweepGradient(
          colors: [
            const Color(0xFFFFD700),
            Colors.white,
            const Color(0xFFFF2A54),
            const Color(0xFFFFD700),
          ],
          transform: GradientRotation(pulse * math.pi * 2),
        ).createShader(rect);
      canvas.drawPath(outline, glow);
      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        size.longestSide * 0.32,
        Paint()
          ..color = const Color(0xFFFFD700).withValues(alpha: 0.10 * pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AaaFramePainter oldDelegate) =>
      oldDelegate.pulse != pulse ||
      oldDelegate.ready != ready ||
      oldDelegate.rank != rank ||
      oldDelegate.primary != primary;
}

/// Liquid mana climbing the side and bottom edges of a combat card.
class _ManaLiquidPainter extends CustomPainter {
  _ManaLiquidPainter({
    required this.fraction,
    required this.color,
    required this.glow,
    required this.ready,
    required this.pulse,
  });

  final double fraction;
  final Color color;
  final Color glow;
  final bool ready;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final bodyH = size.height * 0.73 * fraction;
    final bottom = size.height * 0.73;

    // Rising liquid body inside the art window.
    final liquidRect = Rect.fromLTWH(0, bottom - bodyH, size.width, bodyH);
    final wave = math.sin(pulse * math.pi * 2) * 2.0;
    final path = Path()
      ..moveTo(0, bottom)
      ..lineTo(0, bottom - bodyH + wave)
      ..quadraticBezierTo(
        size.width * 0.5,
        bottom - bodyH - wave * 1.6,
        size.width,
        bottom - bodyH + wave,
      )
      ..lineTo(size.width, bottom)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            color.withValues(alpha: 0.50),
            color.withValues(alpha: 0.16),
            Colors.transparent,
          ],
        ).createShader(liquidRect),
    );

    // Side rails.
    final railH = size.height * fraction;
    final rail = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [glow, color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, size.height - railH, 3, railH));
    canvas.drawRect(Rect.fromLTWH(1, size.height - railH, 2.2, railH), rail);
    canvas.drawRect(
      Rect.fromLTWH(size.width - 3.2, size.height - railH, 2.2, railH),
      rail,
    );

    // 100%: luminous energy entire-card wash.
    if (ready) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..color = const Color(0xFFFFD700).withValues(alpha: 0.10 * pulse)
          ..blendMode = BlendMode.plus,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ManaLiquidPainter oldDelegate) =>
      oldDelegate.fraction != fraction ||
      oldDelegate.ready != ready ||
      oldDelegate.pulse != pulse ||
      oldDelegate.color != color;
}

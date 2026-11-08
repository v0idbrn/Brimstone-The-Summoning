import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Element;

import '../../domain/combat/combat_engine.dart';
import '../../domain/combat/combat_models.dart';
import '../../domain/value_objects/element.dart';
import 'card_procedural_artwork.dart';

/// Overlay HUD on top of the 2.5D combat: structured header with boss name,
/// HP bar with elemental aura, 4 TCG cards with CreaturePortrait artwork,
/// metallic star borders and animated mana bars.
class CombatHudOverlay extends StatefulWidget {
  final CombatEngine engine;
  final VoidCallback? onVictory;
  final VoidCallback? onDefeat;
  final VoidCallback? onHelpPressed;
  final VoidCallback? onSettingsPressed;
  final String? bossDialog;

  const CombatHudOverlay({
    super.key,
    required this.engine,
    this.onVictory,
    this.onDefeat,
    this.onHelpPressed,
    this.onSettingsPressed,
    this.bossDialog,
  });

  @override
  State<CombatHudOverlay> createState() => _CombatHudOverlayState();
}

class _CombatHudOverlayState extends State<CombatHudOverlay>
    with SingleTickerProviderStateMixin {
  Timer? _ticker;
  String? _banner;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _ticker = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (widget.engine.finished) {
        widget.engine.victory
            ? widget.onVictory?.call()
            : widget.onDefeat?.call();
        _ticker?.cancel();
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  /// Border color by star tier: 1★ bronze, 2★ silver, 3★ gold, 4★ crimson-gold.
  Color _starBorderColor(int stars) => switch (stars) {
        1 => const Color(0xFF8B6914),
        2 => const Color(0xFFC0C0C0),
        3 => const Color(0xFFFFD700),
        _ => const Color(0xFFFF6B35),
      };

  Color _elementColor(Element e) => switch (e) {
        Element.igneous => const Color(0xFFFF5A26),
        Element.abyssal => const Color(0xFF3FD8FF),
        Element.telluric => const Color(0xFFB0703B),
        Element.empty => const Color(0xFFB16EFF),
      };

  String _elementLabel(Element e) => switch (e) {
        Element.igneous => '🔥 Íg.',
        Element.abyssal => '❄ Ab.',
        Element.telluric => '⛰ Tel.',
        Element.empty => '✨ Vac.',
      };

  @override
  Widget build(BuildContext context) {
    final e = widget.engine;
    final hpFrac = (e.playerHp / e.playerMaxHp).clamp(0.0, 1.0);
    final shieldFrac = (e.shield / e.playerMaxHp).clamp(0.0, 1.0);
    final hpLossFrac = ((e.playerHp + e.shield) - e.playerMaxHp) < 0
        ? 1.0 - hpFrac - shieldFrac
        : 0.0;
    final bossHpFrac = (e.bossHp / e.boss.maxHp).clamp(0.0, 1.0);
    final bossElemColor = _elementColor(e.boss.element);

    return Stack(
      children: [
        // ── STRUCTURED HEADER ──────────────────────────────────────────
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Container(
              color: Colors.black.withValues(alpha: 0.55),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Row 1: back | boss name | help + settings
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Back button placeholder (pop handled by parent)
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => Navigator.of(context).maybePop(),
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(
                              Icons.arrow_back,
                              color: Color(0xFFB16EFF),
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      // Boss name (center)
                      Expanded(
                        child: Text(
                          e.boss.name,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFFFC93C),
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            shadows: [
                              Shadow(
                                color: Color(0xFFFF5A26),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Help + Settings
                      _HudIconBtn(
                        icon: Icons.help_outline,
                        tooltip: 'Cómo jugar',
                        color: const Color(0xFFB16EFF),
                        onPressed: widget.onHelpPressed ?? () {},
                      ),
                      _HudIconBtn(
                        icon: Icons.settings,
                        tooltip: 'Ajustes',
                        color: const Color(0xFFB16EFF),
                        onPressed: widget.onSettingsPressed ?? () {},
                      ),
                    ],
                  ),
                  // Row 2: Boss HP bar 20px with text + elemental aura
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    child: _BossHpBar(
                      bossHpFrac: bossHpFrac,
                      currentHp: e.bossHp,
                      maxHp: e.boss.maxHp,
                      elementColor: bossElemColor,
                      elementLabel: _elementLabel(e.boss.element),
                    ),
                  ),
                  // Fila 3: Banner compacto de diálogo del jefe
                  if (widget.bossDialog != null &&
                      widget.bossDialog!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color:
                                const Color(0xFFFFC93C).withValues(alpha: 0.8),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          widget.bossDialog!,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFFFE082),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        // Player HP + shield bar
        Positioned(
          bottom: 148,
          left: 16,
          child: SizedBox(
            width: 240,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HP ${e.playerHp.round()} / ${e.playerMaxHp.round()}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Row(
                    children: [
                      Expanded(
                        flex: hpFrac > 0 ? (hpFrac * 100).round() : 1,
                        child: Container(height: 9, color: Colors.greenAccent),
                      ),
                      if (shieldFrac > 0)
                        Expanded(
                          flex: (shieldFrac * 100).round(),
                          child: Container(height: 9, color: Colors.amber),
                        ),
                      if (hpLossFrac > 0)
                        Expanded(
                          flex: (hpLossFrac * 100).round(),
                          child: Container(height: 9, color: Colors.red),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Squad cards
        Positioned(
          bottom: 218,
          left: 10,
          right: 10,
          child: Row(
            children: [
              for (var i = 0; i < e.cards.length; i++) ...[
                Expanded(
                  child: GestureDetector(
                    onTap: () => _cast(i),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _CardTile(
                          card: e.cards[i],
                          elementColor: _elementColor(e.cards[i].element),
                          starBorderColor: _starBorderColor(e.cards[i].stars),
                          pulseValue: _pulseCtrl.value,
                        ),
                        if (i == 0)
                          Positioned(
                            top: -6,
                            left: -6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFC93C),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'LÍDER',
                                style: TextStyle(
                                  color: Color(0xFF0C0608),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 8,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (i < e.cards.length - 1) const SizedBox(width: 6),
              ],
            ],
          ),
        ),

        // Invocation banner
        if (_banner != null)
          Positioned(
            bottom: 306,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFB16EFF)),
                  ),
                  child: Text(
                    '¡$_banner INVOCADO!',
                    style: const TextStyle(
                      color: Color(0xFFB16EFF),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _cast(int index) {
    final e = widget.engine;
    final card = e.cards[index];
    if (e.castSkill(index)) {
      setState(() => _banner = card.name);
      Timer(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _banner = null);
      });
    }
  }
}

// ── Boss HP Bar widget ────────────────────────────────────────────────────────

class _BossHpBar extends StatelessWidget {
  final double bossHpFrac;
  final double currentHp;
  final double maxHp;
  final Color elementColor;
  final String elementLabel;

  const _BossHpBar({
    required this.bossHpFrac,
    required this.currentHp,
    required this.maxHp,
    required this.elementColor,
    required this.elementLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: const Color(0xFF3A1A20),
          width: 1.5,
        ),
        color: const Color(0xFF2A0D10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          children: [
            // Crimson gradient fill
            FractionallySizedBox(
              widthFactor: bossHpFrac,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF8B0000), Color(0xFFDC143C)],
                  ),
                ),
              ),
            ),
            // HP text + elemental aura label centred over bar
            Center(
              child: Directionality(
                textDirection: ui.TextDirection.ltr,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'HP ${currentHp.round()} / ${maxHp.round()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      elementLabel,
                      style: TextStyle(
                        color: elementColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Minimal icon button ───────────────────────────────────────────────────────

class _HudIconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onPressed;

  const _HudIconBtn({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      ),
    );
  }
}

// ── Card tile with CreaturePortrait ──────────────────────────────────────────

class _CardTile extends StatelessWidget {
  final ManaCard card;
  final Color elementColor;
  final Color starBorderColor;
  final double pulseValue;

  const _CardTile({
    required this.card,
    required this.elementColor,
    required this.starBorderColor,
    required this.pulseValue,
  });

  String _starStr() => '★' * card.stars.clamp(1, 4);

  Color _glowBorderColor() {
    if (!card.isReady) return starBorderColor;
    return const Color(0xFFFFD700);
  }

  double _borderWidth() => card.isReady ? 2.5 : 1.4;

  List<BoxShadow>? _boxShadow() {
    if (!card.isReady) return null;
    final glow = 0.5 + 0.5 * pulseValue;
    return [
      BoxShadow(
        color: const Color(0xFFFFD700).withValues(alpha: glow * 0.7),
        blurRadius: 14,
        spreadRadius: 2,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final frac = (card.mana / card.baseManaCost).clamp(0.0, 1.0);
    return AspectRatio(
      aspectRatio: 0.72,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: card.isReady ? 1.0 : 0.80,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A0E14).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _glowBorderColor(),
              width: _borderWidth(),
            ),
            boxShadow: _boxShadow(),
          ),
          child: Column(
            children: [
              // Stars + ATK row
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 3, 4, 0),
                child: Row(
                  children: [
                    Text(
                      _starStr(),
                      style: TextStyle(
                        color: starBorderColor,
                        fontSize: 8,
                        height: 1,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'ATK${card.attack.toInt()}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 8,
                      ),
                    ),
                  ],
                ),
              ),
              // Creature portrait (procedural art)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: CustomPaint(
                      size: const Size(double.infinity, double.infinity),
                      painter: _CreaturePortraitPainter(
                        cardId: card.id,
                        stars: card.stars,
                        manaFrac: frac,
                      ),
                    ),
                  ),
                ),
              ),
              // Card name
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Text(
                  card.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // INVOCAR! label
              if (card.isReady)
                const Padding(
                  padding: EdgeInsets.only(bottom: 1),
                  child: Text(
                    '¡INVOCAR!',
                    style: TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              // Gradient mana bar
              Directionality(
                textDirection: ui.TextDirection.ltr,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(9),
                    bottomRight: Radius.circular(9),
                  ),
                  child: SizedBox(
                    height: 5,
                    child: LinearProgressIndicator(
                      value: frac,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation(
                        card.isReady ? const Color(0xFFFFD700) : elementColor,
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

// ── CreaturePortrait CustomPainter ───────────────────────────────────────────

/// Wraps [CreatureProceduralArt.drawPortrait] in a [CustomPainter] so it can
/// be embedded inside the card tile's [CustomPaint] widget.
class _CreaturePortraitPainter extends CustomPainter {
  final String cardId;
  final int stars;
  final double manaFrac;

  const _CreaturePortraitPainter({
    required this.cardId,
    required this.stars,
    required this.manaFrac,
  });

  @override
  void paint(Canvas canvas, Size size) {
    CreatureProceduralArt.drawPortrait(
      canvas,
      Rect.fromLTWH(0, 0, size.width, size.height),
      cardId,
      stars: stars,
      time: manaFrac * math.pi * 2,
    );
  }

  @override
  bool shouldRepaint(_CreaturePortraitPainter old) =>
      old.cardId != cardId || old.stars != stars || old.manaFrac != manaFrac;
}

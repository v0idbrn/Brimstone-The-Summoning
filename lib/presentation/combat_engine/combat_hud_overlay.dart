import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Element;

import '../../domain/combat/combat_engine.dart';
import '../../domain/value_objects/element.dart';
import '../widgets/tcg_card_widget.dart';

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

        // Squad cards - strictly contained in SizedBox(height: 122)
        Positioned(
          bottom: 218,
          left: 10,
          right: 10,
          child: SizedBox(
            height: 122,
            child: Row(
              children: [
                for (var i = 0; i < e.cards.length; i++) ...[
                  SizedBox(
                    width: 96,
                    height: 122,
                    child: TcgCardWidget.fromCombatCard(
                      card: e.cards[i],
                      isLeader: i == 0,
                      onTap: () => _cast(i),
                    ),
                  ),
                  if (i < e.cards.length - 1) const SizedBox(width: 6),
                ],
              ],
            ),
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

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Element;

import '../../domain/combat/combat_engine.dart';
import '../../domain/combat/combat_models.dart';
import '../../domain/value_objects/element.dart';

/// Overlay HUD on top of the 2.5D combat: player/boss health, the 4 active
/// TCG cards with star frames and animated mana bars, and the invocation
/// banner shown when a skill is cast. Cards fire their skill on tap.
class CombatHudOverlay extends StatefulWidget {
  final CombatEngine engine;
  final VoidCallback? onVictory;
  final VoidCallback? onDefeat;

  const CombatHudOverlay({
    super.key,
    required this.engine,
    this.onVictory,
    this.onDefeat,
  });

  @override
  State<CombatHudOverlay> createState() => _CombatHudOverlayState();
}

class _CombatHudOverlayState extends State<CombatHudOverlay> {
  Timer? _ticker;
  String? _banner;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  Color borderColor(int stars) => switch (stars) {
        1 => const Color(0xFF9AA4A8),
        2 => const Color(0xFF4FC3F7),
        3 => const Color(0xFFB16EFF),
        _ => const Color(0xFFFFC93C),
      };

  Color elementColor(Element e) => switch (e) {
        Element.igneous => const Color(0xFFFF5A26),
        Element.abyssal => const Color(0xFF3FD8FF),
        Element.telluric => const Color(0xFFB0703B),
        Element.empty => const Color(0xFFB16EFF),
      };

  @override
  Widget build(BuildContext context) {
    final e = widget.engine;
    final hpFrac = (e.playerHp / e.playerMaxHp).clamp(0.0, 1.0);
    final shieldFrac = (e.shield / e.playerMaxHp).clamp(0.0, 1.0);
    final hpLossFrac = ((e.playerHp + e.shield) - e.playerMaxHp) < 0
        ? 1.0 - hpFrac - shieldFrac
        : 0.0;

    return Stack(
      children: [
        // Boss bar
        Positioned(
          top: 6,
          left: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                e.boss.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(
                  children: [
                    Container(
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A1116),
                        border: Border.all(color: Colors.white24),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: (e.bossHp / e.boss.maxHp).clamp(0.0, 1.0),
                      child: Container(
                        height: 14,
                        color: Colors.redAccent,
                        alignment: Alignment.center,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
                    child: _CardTile(
                      card: e.cards[i],
                      readyCardColor: elementColor(e.cards[i].element),
                      borderColor: borderColor(e.cards[i].stars),
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

class _CardTile extends StatelessWidget {
  final ManaCard card;
  final Color readyCardColor;
  final Color borderColor;

  const _CardTile({
    required this.card,
    required this.readyCardColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final frac = (card.mana / card.baseManaCost).clamp(0.0, 1.0);
    final ready = card.isReady;
    return AspectRatio(
      aspectRatio: 0.72,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: ready ? 1.0 : 0.75,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A0E14).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: ready ? readyCardColor : borderColor,
              width: ready ? 2.5 : 1.4,
            ),
            boxShadow: ready
                ? [
                    BoxShadow(
                      color: readyCardColor.withValues(alpha: 0.6),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    for (var s = 0; s < card.stars; s++)
                      const Icon(
                        Icons.star,
                        size: 10,
                        color: Color(0xFFFFC93C),
                      ),
                    const Spacer(),
                    Text(
                      '${card.mana.round()}/${card.baseManaCost}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: CustomPaint(
                      size: const Size(double.infinity, double.infinity),
                      painter: _CardArtPainter(readyCardColor, levelFrac: frac),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  card.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Mana bar
              Directionality(
                textDirection: ui.TextDirection.ltr,
                child: LinearProgressIndicator(
                  value: frac,
                  minHeight: 5,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation(readyCardColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardArtPainter extends CustomPainter {
  final Color color;
  final double levelFrac;
  _CardArtPainter(this.color, {required this.levelFrac});

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width * 0.28;
    canvas.drawCircle(
      Offset(size.width / 2, size.height * 0.5),
      r,
      Paint()..color = color.withValues(alpha: 0.85),
    );
    canvas.drawCircle(
      Offset(size.width / 2, size.height * 0.5),
      r * (0.35 + 0.42 * levelFrac),
      Paint()..color = Colors.white.withValues(alpha: 0.5),
    );
  }

  @override
  bool shouldRepaint(covariant _CardArtPainter old) =>
      old.levelFrac != levelFrac || old.color != color;
}

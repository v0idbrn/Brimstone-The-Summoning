import 'package:flame/game.dart';
import 'package:flutter/material.dart' hide Element;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/procedural_sfx_engine.dart';
import '../../../domain/combat/combat_engine.dart';
import '../../../domain/combat/combat_math.dart';
import '../../../domain/combat/combat_models.dart';
import '../../../domain/meta/rune_system.dart';
import '../../../domain/meta/squad_synergy_resolver.dart';
import '../../../domain/value_objects/element.dart';
import '../../../domain/value_objects/orb_level.dart';
import '../../controllers/meta_controller.dart';
import '../../combat_engine/brimstone_combat_game.dart';
import '../../combat_engine/combat_hud_overlay.dart';
import '../meta/how_to_play_modal.dart';

/// Full combat screen: Flame game + fullscreen gesture bridge + HUD overlay.
///
/// Pan gestures are routed to the pure [CombatEngine]: dragging an orb in the
/// merge tray, flicking it upward to launch, or tapping a corrupted orb to
/// counter-flick it.
class CombatScreen extends ConsumerStatefulWidget {
  final CombatEngine? engine;
  final void Function(bool victory, double playerHp)? onCombatResolved;

  const CombatScreen({super.key, this.engine, this.onCombatResolved});

  /// Builds the engine from the squad, relics and rift difficulty.
  static CombatEngine buildEngine({
    required BossConfig boss,
    required List<ManaCard> cards,
    required double playerMaxHp,
    CombatModifiers modifiers = const CombatModifiers(),
    SquadSynergyBonus? synergy,
    Map<String, RuneInstance> cardRunes = const {},
    double playerDamageMult = 1.0,
    double? startHp,
    bool startManaFull = false,
  }) =>
      CombatEngine(
        boss: boss,
        cards: cards,
        playerMaxHp: playerMaxHp,
        modifiers: modifiers,
        synergy: synergy,
        cardRunes: cardRunes,
        playerDamageMult: playerDamageMult,
        startHp: startHp,
        startManaFull: startManaFull,
      );

  @override
  ConsumerState<CombatScreen> createState() => _CombatScreenState();
}

class _CombatScreenState extends ConsumerState<CombatScreen>
    with SingleTickerProviderStateMixin {
  CombatEngine? _engine;
  late final BrimstoneCombatGame game;
  late final AnimationController _particleCtrl;
  int _lastPanMs = 0;
  bool _resolved = false;
  String? _reactionBanner;

  CombatEngine get engine => _engine!;

  /// Particle bursts born at exact impact/merge (dx, dy) coordinates.
  final List<_BurstEffect> _bursts = [];

  void _addBurst(double x, double y, Color color) {
    _bursts.add(_BurstEffect(x: x, y: y, color: color));
    _particleCtrl.forward(from: 0);
  }

  Color _elementColor(Element e) => switch (e) {
        Element.igneous => const Color(0xFFFF5A26),
        Element.abyssal => const Color(0xFF3FD8FF),
        Element.telluric => const Color(0xFFB0703B),
        Element.empty => const Color(0xFFB16EFF),
      };

  @override
  void initState() {
    super.initState();
    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _particleCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _bursts.clear());
      }
    });
    _initEngine();
  }

  @override
  void dispose() {
    _particleCtrl.dispose();
    super.dispose();
  }

  Future<void> _initEngine() async {
    final base = widget.engine ?? defaultEngine();
    final cards = base.cards;
    final synergy = SquadSynergyResolver.resolve(cards);
    // Usar las runas pasadas por el constructor (Endless Abyss) o cargarlas desde SQLite.
    final cardRunes = <String, RuneInstance>{};
    cardRunes.addAll(base.cardRunes);
    if (cardRunes.isEmpty) {
      final repo = ref.read(playerRepositoryProvider);
      for (final c in cards) {
        try {
          final rune = await repo.loadCardRune(c.hashCode);
          if (rune != null) cardRunes[c.id] = rune;
        } catch (_) {}
      }
    }
    if (!mounted) return;
    _engine = CombatEngine(
      boss: base.boss,
      cards: cards,
      playerMaxHp: base.playerMaxHp,
      modifiers: base.modifiers,
      synergy: synergy.isActive ? synergy : null,
      cardRunes: cardRunes,
      playerDamageMult: base.playerDamageMult,
    );
    // Wire combat audio + bounty events to the procedural SFX engine.
    _engine!.onHit = (kind, damage, x, y, element) {
      switch (kind) {
        case HitKind.bullseye:
          ProceduralSfxEngine.playHitBullseye();
          ref.read(bountyProvider.notifier).increment('bullseye_hits');
        case HitKind.graze:
          ProceduralSfxEngine.playHitGraze();
        case HitKind.normal:
          ProceduralSfxEngine.playHitNormal();
        case HitKind.miss:
          break;
      }
      _addBurst(x, y, _elementColor(element));
      if (mounted) setState(() {});
    };
    _engine!.onReaction = (name) {
      ProceduralSfxEngine.playElementalReaction();
      ref.read(bountyProvider.notifier).increment('reactions');
      setState(() {
        _reactionBanner = name;
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _reactionBanner = null);
      });
    };
    _engine!.onMerge = (level, x, y, element) {
      ProceduralSfxEngine.playOrbMerge(level.index);
      if (level == OrbLevel.three) {
        ref.read(bountyProvider.notifier).increment('merge_to_three');
      }
      _addBurst(x, y, _elementColor(element));
      if (mounted) setState(() {});
    };
    _engine!.onEnrage = () {
      ProceduralSfxEngine.playBossEnrage();
    };
    game = BrimstoneCombatGame(
      engine: _engine!,
      onVictory: () => _resolve(true),
      onDefeat: () => _resolve(false),
    );
    setState(() {});
  }

  void _resolve(bool victory) {
    if (_resolved) return;
    _resolved = true;
    _showCombatSummary(victory).then((_) {
      widget.onCombatResolved?.call(victory, engine.playerHp);
    });
  }

  Future<void> _showCombatSummary(bool victory) => showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => CombatSummaryDialog(
          victory: victory,
          damageTotal: engine.damageTotal,
          maxHit: engine.maxHit,
          bullseyes: engine.bullseyes,
          reactions: engine.reactions,
          counterflicks: engine.counterflicks,
          mergesToThree: engine.mergesToThree,
        ),
      );

  (double, double) _toEngine(Offset p) => game.toEngineCoords(p.dx, p.dy);

  void _onPanStart(DragStartDetails d) {
    final (x, y) = _toEngine(d.localPosition);
    // Counter-flick takes priority: touch a corrupted orb to destroy it.
    if (engine.counterFlickAt(
      x,
      y,
      DateTime.now().millisecondsSinceEpoch / 1000,
    )) {
      ProceduralSfxEngine.playCounterFlickDestroy();
      ref.read(bountyProvider.notifier).increment('counterflicks');
      return;
    }
    if (y >= CombatEngine.trayY - 60) {
      final slot = _slotFromX(x);
      if (slot != null) engine.startDrag(slot, x, y);
    }
  }

  int? _slotFromX(double x) {
    final slot = (x / (CombatEngine.layoutWidth / 5)).floor();
    return slot < 0 || slot > 4 ? null : slot;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final (x, y) = _toEngine(d.localPosition);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    engine.updateDrag(x, y, (nowMs - _lastPanMs) / 1000.0);
    _lastPanMs = nowMs;
  }

  void _onPanEnd(DragEndDetails d) {
    final vy = d.velocity.pixelsPerSecond.dy / game.viewScale;
    if (vy < CombatMath.flickSpeedThreshold) {
      ProceduralSfxEngine.playOrbFlick();
    }
    engine.releaseDrag(vy);
  }

  void _onTapUp(TapUpDetails d) {
    final (x, y) = _toEngine(d.localPosition);
    if (engine.counterFlickAt(x, y, 0)) {
      ProceduralSfxEngine.playCounterFlickDestroy();
      ref.read(bountyProvider.notifier).increment('counterflicks');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_engine == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0C0608),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFB16EFF)),
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFF0C0608),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        onTapUp: _onTapUp,
        child: Stack(
          children: [
            Positioned.fill(child: GameWidget(game: game)),
            // Particle bursts born at exact impact/merge (dx, dy) coordinates.
            if (_bursts.isNotEmpty)
              Positioned.fill(
                child: CustomPaint(
                  painter: _BurstsPainter(
                    bursts: _bursts,
                    progress: _particleCtrl.value,
                  ),
                ),
              ),
            Positioned.fill(
              child: CombatHudOverlay(
                engine: engine,
                onVictory: () => _resolve(true),
                onDefeat: () => _resolve(false),
              ),
            ),
            // Reaction banner.
            if (_reactionBanner != null)
              Positioned(
                top: 40,
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
                        color: Colors.black.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFF5A26)),
                      ),
                      child: Text(
                        '¡$_reactionBanner!',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            // Help button.
            Positioned(
              top: 10,
              left: 10,
              child: IconButton(
                icon: const Icon(Icons.help_outline, color: Color(0xFFB16EFF)),
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: const Color(0xFF14090D),
                  builder: (_) => const HowToPlayModal(),
                ),
                tooltip: 'Cómo jugar',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

CombatEngine defaultEngine() => CombatEngine(
      boss: BossConfig.pyroth,
      cards: [
        ManaCard(
          id: 'ignis_hound',
          name: 'Sabueso de Azufre',
          element: Element.igneous,
          baseManaCost: 100,
          attack: 10,
        ),
        ManaCard(
          id: 'abyss_stalker',
          name: 'Acechador de Escarcha',
          element: Element.abyssal,
          baseManaCost: 95,
          attack: 12,
        ),
        ManaCard(
          id: 'terra_golem',
          name: 'Gólem de Basalto',
          element: Element.telluric,
          baseManaCost: 100,
          attack: 8,
        ),
        ManaCard(
          id: 'void_specter',
          name: 'Espectro del Sello',
          element: Element.empty,
          baseManaCost: 110,
          attack: 15,
        ),
      ],
      playerMaxHp: 100,
    );

/// Particle burst born at an exact impact/merge (dx, dy) engine coordinate.
class _BurstEffect {
  final double x;
  final double y;
  final Color color;

  _BurstEffect({required this.x, required this.y, required this.color});
}

/// Bursts painter: expanding concentric rings at each (dx, dy) impact point.
class _BurstsPainter extends CustomPainter {
  final List<_BurstEffect> bursts;
  final double progress; // 0..1

  _BurstsPainter({required this.bursts, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    for (final b in bursts) {
      for (var i = 0; i < 4; i++) {
        final p = (progress - i * 0.18).clamp(0.0, 1.0);
        if (p <= 0.0) continue;
        final radius = p * 120.0;
        final alpha = ((1.0 - p) * 0.9).clamp(0.0, 1.0);
        paint.color = b.color.withValues(alpha: alpha);
        canvas.drawCircle(Offset(b.x, b.y), radius, paint);
      }
      // Impact core.
      canvas.drawCircle(
        Offset(b.x, b.y),
        6.0 + progress * 10.0,
        Paint()
          ..color =
              Colors.white.withValues(alpha: (1.0 - progress).clamp(0.0, 1.0)),
      );
    }
  }

  @override
  bool shouldRepaint(_BurstsPainter old) =>
      old.progress != progress || old.bursts != bursts;
}

/// Post-combat tactical summary dialog.
class CombatSummaryDialog extends StatelessWidget {
  final bool victory;
  final int damageTotal;
  final double maxHit;
  final int bullseyes;
  final int reactions;
  final int counterflicks;
  final int mergesToThree;

  const CombatSummaryDialog({
    super.key,
    required this.victory,
    required this.damageTotal,
    required this.maxHit,
    required this.bullseyes,
    required this.reactions,
    required this.counterflicks,
    required this.mergesToThree,
  });

  @override
  Widget build(BuildContext context) {
    final loot = victory ? (damageTotal ~/ 5) : 0;
    return AlertDialog(
      backgroundColor: const Color(0xFF14090D),
      title: Text(
        victory ? 'VICTORIA' : 'DERROTA',
        style: TextStyle(
          color: victory ? const Color(0xFF4FFFA3) : Colors.redAccent,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SummaryRow(label: 'Daño total', value: '$damageTotal'),
          _SummaryRow(label: 'Golpe máximo', value: '${maxHit.toInt()}'),
          _SummaryRow(label: 'Bullseyes conectados', value: '$bullseyes'),
          _SummaryRow(label: 'Reacciones detonadas', value: '$reactions'),
          _SummaryRow(
              label: 'Esferas Nv.3 fusionadas', value: '$mergesToThree'),
          _SummaryRow(label: 'Counter-flicks', value: '$counterflicks'),
          const SizedBox(height: 10),
          _SummaryRow(
            label: 'Botín',
            value: '$loot oro',
            valueColor: const Color(0xFFFFC93C),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'CONTINUAR',
            style: TextStyle(
              color: Color(0xFFB16EFF),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

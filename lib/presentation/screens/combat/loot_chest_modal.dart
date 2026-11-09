import 'dart:math' as math;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/procedural_sfx_engine.dart';
import '../../../domain/campaign/campaign_enemies.dart';
import '../../../domain/entities/owned_card.dart';
import '../../../domain/value_objects/element.dart';
import '../../../domain/value_objects/rarity.dart';
import '../../controllers/meta_controller.dart';
import '../../widgets/tcg_card_widget.dart';

/// Modal shown after defeating a Mini-Boss or Chapter Boss.
/// Animated runic chest that grants gold, shards, and a guaranteed card drop.
class LootChestModal extends ConsumerStatefulWidget {
  final CampaignEnemy enemy;
  final bool isChapterBoss;
  final VoidCallback onContinue;

  const LootChestModal({
    super.key,
    required this.enemy,
    required this.isChapterBoss,
    required this.onContinue,
  });

  static Future<void> show({
    required BuildContext context,
    required CampaignEnemy enemy,
    required bool isChapterBoss,
    required VoidCallback onContinue,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => LootChestModal(
        enemy: enemy,
        isChapterBoss: isChapterBoss,
        onContinue: onContinue,
      ),
    );
  }

  @override
  ConsumerState<LootChestModal> createState() => _LootChestModalState();
}

class _LootChestModalState extends ConsumerState<LootChestModal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _shakeAnim;
  late final Animation<double> _glowAnim;
  late final Animation<double> _burstAnim;

  bool _opened = false;
  OwnedCard? _newCard;
  int _goldGained = 0;
  int _shardsGained = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -6.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: -4.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -4.0, end: 4.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 4.0, end: -2.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -2.0, end: 2.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 2.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.6)));
    _glowAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.0, 0.8, curve: Curves.easeInOut)),
    );
    _burstAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.6, 1.0, curve: Curves.easeOut)),
    );
    // Loop shake while closed
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_opened) {
        _ctrl.repeat(period: const Duration(milliseconds: 1800));
      }
    });
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _openChest() async {
    if (_opened) return;
    _opened = true;
    _ctrl.stop();

    // Play chest open sound
    ProceduralSfxEngine.playChestOpen();

    // Calculate rewards
    _goldGained = widget.isChapterBoss
        ? 800 + math.Random().nextInt(400)
        : 400 + math.Random().nextInt(200);
    _shardsGained = widget.isChapterBoss
        ? 200 + math.Random().nextInt(100)
        : 100 + math.Random().nextInt(50);

    // Grant gold and shards
    await ref
        .read(profileProvider.notifier)
        .grant(gold: _goldGained, shards: _shardsGained);

    // Determine card drop: 100% for chapter boss, 50% for mini-boss
    final dropChance = widget.isChapterBoss ? 1.0 : 0.5;
    if (math.Random().nextDouble() < dropChance) {
      _newCard = await _grantElementalCard();
    }

    // Record boss slain stat
    await ref.read(playerRepositoryProvider).recordCombatResult(
          victory: true,
          bossKilled: true,
        );

    // Show burst animation then reveal rewards
    _ctrl.forward(from: 0.6);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() {});
  }

  Future<OwnedCard?> _grantElementalCard() async {
    final repo = ref.read(playerRepositoryProvider);
    // Pick a card from the chapter's element
    final elementCards = _elementalCardIds(widget.enemy.element);
    final catalogId = elementCards[math.Random().nextInt(elementCards.length)];
    final card = await repo.insertSummonedCard(catalogId);
    // Add to collection
    ref.read(collectionProvider.notifier).addCard(card);
    return card;
  }

  List<String> _elementalCardIds(Element element) {
    return switch (element) {
      Element.igneous => [
          'ignis_hound',
          'ignis_drake',
          'ignis_lord',
          'ignis_colossus',
          'ignis_seraph'
        ],
      Element.abyssal => [
          'abyss_stalker',
          'abyss_siren',
          'abyss_kraken',
          'abyss_leviathan',
          'abyss_wraith'
        ],
      Element.telluric => [
          'terra_golem',
          'terra_warden',
          'terra_titan',
          'terra_behemoth',
          'terra_hydra'
        ],
      Element.empty => [
          'void_specter',
          'void_reaper',
          'void_oracle',
          'void_archon',
          'void_malakor'
        ],
    };
  }

  @override
  Widget build(BuildContext context) {
    final isChapterBoss = widget.isChapterBoss;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final shakeX = _opened ? 0.0 : _shakeAnim.value;
          final glowIntensity = _glowAnim.value;
          final burstProgress = _burstAnim.value;

          return Transform.translate(
            offset: Offset(shakeX, 0),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF0C0608),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFB16EFF)
                      .withValues(alpha: 0.5 + 0.3 * glowIntensity),
                  width: 2 + glowIntensity,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFB16EFF)
                        .withValues(alpha: 0.3 * glowIntensity),
                    blurRadius: 20 + 10 * glowIntensity,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1A0A0F), Color(0xFF0C0608)],
                      ),
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(14)),
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFB16EFF), width: 1),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isChapterBoss ? Icons.emoji_events : Icons.star,
                          color: isChapterBoss
                              ? const Color(0xFFFFC93C)
                              : const Color(0xFFFF5A26),
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isChapterBoss
                              ? '¡JEFE DERROTADO!'
                              : '¡MINI-JEFE VENCIDO!',
                          style: TextStyle(
                            color: isChapterBoss
                                ? const Color(0xFFFFC93C)
                                : const Color(0xFFFF5A26),
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // Chest animation
                          SizedBox(
                            height: 200,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Burst particles
                                if (_opened && burstProgress > 0)
                                  CustomPaint(
                                    size: const Size(300, 300),
                                    painter: _BurstPainter(
                                        progress: burstProgress,
                                        isChapterBoss: isChapterBoss),
                                  ),
                                // Chest
                                GestureDetector(
                                  onTap: _opened ? null : _openChest,
                                  child: _AnimatedChest(
                                    opened: _opened,
                                    isChapterBoss: isChapterBoss,
                                    glowIntensity: glowIntensity,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (!_opened) ...[
                            Text(
                              'Toca el cofre para abrirlo',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Contiene: Oro + Esquirlas + ${isChapterBoss ? 'Carta Garantizada' : '50% Carta'}',
                              style: const TextStyle(
                                color: Color(0xFFB16EFF),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ] else ...[
                            // Rewards
                            _rewardRow(
                              icon: Icons.monetization_on,
                              color: Colors.amber,
                              label: 'Oro',
                              value: '+$_goldGained',
                            ),
                            const SizedBox(height: 8),
                            _rewardRow(
                              icon: Icons.diamond,
                              color: const Color(0xFF3FD8FF),
                              label: 'Esquirlas',
                              value: '+$_shardsGained',
                            ),
                            if (_newCard != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [
                                    const Color(0xFFB16EFF)
                                        .withValues(alpha: 0.3),
                                    const Color(0xFFB16EFF)
                                        .withValues(alpha: 0.1),
                                  ]),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: const Color(0xFFB16EFF), width: 2),
                                ),
                                child: Column(
                                  children: [
                                    const Text(
                                      '¡NUEVA CARTA OBTENIDA!',
                                      style: TextStyle(
                                        color: Color(0xFFFFC93C),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: 140,
                                      height: 194,
                                      child: TcgCardWidget.fromOwnedCard(
                                        card: _newCard!,
                                        raised: true,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _newCard!.name,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        _elementBadge(_newCard!.element),
                                        const SizedBox(width: 8),
                                        _rarityBadge(
                                            _newCard!.rarity, _newCard!.stars),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (!isChapterBoss) ...[
                              const SizedBox(height: 16),
                              Text(
                                'El cofre no contenía cartas esta vez.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                  // Continue button
                  if (_opened)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            widget.onContinue();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFB16EFF),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 4,
                          ),
                          child: const Text(
                            'CONTINUAR',
                            style: TextStyle(
                              fontSize: 14,
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
          );
        },
      ),
    );
  }

  Widget _rewardRow({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: const TextStyle(
              color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w700),
        ),
        Text(
          value,
          style: TextStyle(
              color: color, fontSize: 16, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }

  Widget _elementBadge(Element e) {
    final color = switch (e) {
      Element.igneous => const Color(0xFFFF5A26),
      Element.abyssal => const Color(0xFF3FD8FF),
      Element.telluric => const Color(0xFFB0703B),
      Element.empty => const Color(0xFFB16EFF),
    };
    final name = switch (e) {
      Element.igneous => 'Ígneo',
      Element.abyssal => 'Abisal',
      Element.telluric => 'Telúrico',
      Element.empty => 'Vacío',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(name,
          style: TextStyle(
              color: color, fontSize: 9, fontWeight: FontWeight.w900)),
    );
  }

  Widget _rarityBadge(Rarity r, int stars) {
    final color = switch (r) {
      Rarity.common => Colors.white,
      Rarity.rare => const Color(0xFF3FD8FF),
      Rarity.epic => const Color(0xFFB16EFF),
      Rarity.legendary => const Color(0xFFFFC93C),
      Rarity.mythic => const Color(0xFFFF5A26),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        '${r.name.toUpperCase()} ${'★' * stars}',
        style:
            TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900),
      ),
    );
  }
}

/// Animated runic chest widget.
class _AnimatedChest extends StatelessWidget {
  final bool opened;
  final bool isChapterBoss;
  final double glowIntensity;

  const _AnimatedChest({
    required this.opened,
    required this.isChapterBoss,
    required this.glowIntensity,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(120, 140),
      painter: _ChestPainter(
        opened: opened,
        isChapterBoss: isChapterBoss,
        glowIntensity: glowIntensity,
      ),
    );
  }
}

class _ChestPainter extends CustomPainter {
  final bool opened;
  final bool isChapterBoss;
  final double glowIntensity;

  _ChestPainter({
    required this.opened,
    required this.isChapterBoss,
    required this.glowIntensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final baseColor =
        isChapterBoss ? const Color(0xFFFFC93C) : const Color(0xFFFF5A26);
    final darkColor =
        isChapterBoss ? const Color(0xFF8B6914) : const Color(0xFF8B2500);

    // Glow
    if (glowIntensity > 0) {
      canvas.drawCircle(
        Offset(cx, cy + 20),
        70 * glowIntensity,
        Paint()..color = baseColor.withValues(alpha: 0.15 * glowIntensity),
      );
    }

    // Chest base
    final baseRect = Rect.fromCenter(
      center: Offset(cx, cy + 40),
      width: 100,
      height: 70,
    );
    final basePath = Path()
      ..addRRect(RRect.fromRectAndRadius(baseRect, const Radius.circular(8)));
    canvas.drawPath(basePath, Paint()..color = darkColor);
    canvas.drawPath(
        basePath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = baseColor.withValues(alpha: 0.8));

    // Runes on base
    for (var i = 0; i < 3; i++) {
      final rx = cx - 30 + i * 30;
      final ry = cy + 40;
      _drawRune(canvas, Offset(rx, ry), 12,
          baseColor.withValues(alpha: 0.7 + 0.3 * glowIntensity));
    }

    // Chest lid
    final lidRect = Rect.fromCenter(
      center: Offset(cx, cy - 5 + (opened ? -35 : 0)),
      width: 104,
      height: 40,
    );
    final lidPath = Path()
      ..addRRect(RRect.fromRectAndRadius(lidRect, const Radius.circular(8)));
    canvas.drawPath(lidPath, Paint()..color = darkColor);
    canvas.drawPath(
        lidPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = baseColor.withValues(alpha: 0.8));

    // Lid runes
    for (var i = 0; i < 3; i++) {
      final rx = cx - 30 + i * 30;
      final ry = cy - 5 + (opened ? -35 : 0);
      _drawRune(canvas, Offset(rx, ry), 10,
          baseColor.withValues(alpha: 0.7 + 0.3 * glowIntensity));
    }

    // Lock
    if (!opened) {
      final lockRect =
          Rect.fromCenter(center: Offset(cx, cy + 10), width: 24, height: 30);
      canvas.drawRRect(
        RRect.fromRectAndRadius(lockRect, const Radius.circular(4)),
        Paint()..color = Colors.grey.shade800,
      );
      canvas.drawArc(
        Rect.fromCenter(center: Offset(cx, cy + 5), width: 16, height: 20),
        0,
        math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = baseColor.withValues(alpha: 0.9),
      );
    }
  }

  void _drawRune(Canvas canvas, Offset center, double size, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(center.dx, center.dy - size / 2)
      ..lineTo(center.dx, center.dy + size / 2)
      ..moveTo(center.dx - size / 2, center.dy)
      ..lineTo(center.dx + size / 2, center.dy)
      ..moveTo(center.dx - size / 3, center.dy - size / 3)
      ..lineTo(center.dx + size / 3, center.dy + size / 3)
      ..moveTo(center.dx + size / 3, center.dy - size / 3)
      ..lineTo(center.dx - size / 3, center.dy + size / 3);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ChestPainter oldDelegate) =>
      oldDelegate.opened != opened ||
      oldDelegate.glowIntensity != glowIntensity;
}

class _BurstPainter extends CustomPainter {
  final double progress;
  final bool isChapterBoss;

  _BurstPainter({required this.progress, required this.isChapterBoss});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final color =
        isChapterBoss ? const Color(0xFFFFC93C) : const Color(0xFFFF5A26);
    final secondaryColor =
        isChapterBoss ? const Color(0xFFFFD700) : const Color(0xFFB16EFF);

    final particleCount = 24;
    for (var i = 0; i < particleCount; i++) {
      final angle = (i / particleCount) * 2 * math.pi;
      final radius = 120 * progress;
      final px = cx + math.cos(angle) * radius;
      final py = cy + math.sin(angle) * radius;
      final particleSize = (1.0 - progress) * 12 + 4;
      final alpha = (1.0 - progress).clamp(0.0, 1.0);

      canvas.drawCircle(
        Offset(px, py),
        particleSize,
        Paint()
          ..color =
              (i % 2 == 0 ? color : secondaryColor).withValues(alpha: alpha),
      );
    }

    // Central burst
    canvas.drawCircle(
      Offset(cx, cy),
      80 * progress,
      Paint()..color = color.withValues(alpha: (1.0 - progress) * 0.3),
    );
  }

  @override
  bool shouldRepaint(covariant _BurstPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

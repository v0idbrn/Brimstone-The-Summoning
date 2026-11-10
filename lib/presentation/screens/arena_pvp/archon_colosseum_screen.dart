import 'dart:math' as math;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/procedural_sfx_engine.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../domain/arena/archon_league.dart';
import '../../../domain/combat/combat_engine.dart';
import '../../../domain/combat/combat_models.dart';
import '../../../domain/value_objects/element.dart';
import '../../controllers/meta_controller.dart';
import '../../graphics/art_registry.dart';
import '../../graphics/painted_backdrop.dart';
import '../../widgets/gothic_modal_frame.dart';
import '../../widgets/tcg_card_widget.dart';
import '../combat/combat_screen.dart';

/// Coliseo de los Arcontes — asynchronous competitive ladder.
///
/// Three procedurally generated rivals are offered every visit. Each duel is a
/// 45 s damage race (see [CombatEngine.scoreTarget]): beat the rival's target
/// score to take the trophies, climb the six divisions and open ascension
/// chests.
class ArchonColosseumScreen extends ConsumerStatefulWidget {
  const ArchonColosseumScreen({super.key});

  @override
  ConsumerState<ArchonColosseumScreen> createState() =>
      _ArchonColosseumScreenState();
}

class _ArchonColosseumScreenState extends ConsumerState<ArchonColosseumScreen> {
  ArchonProgress _progress = ArchonProgress.empty;
  List<ArchonRival> _rivals = const [];
  Map<String, int> _talents = const {};
  Map<String, int> _gear = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final repo = ref.read(playerRepositoryProvider);
    final progress = await repo.loadArchonProgress();
    final talents = await repo.loadTalentLevels();
    final gear = await repo.loadGearLevels();
    await ref.read(collectionProvider.notifier).load();
    if (!mounted) return;
    setState(() {
      _progress = progress;
      _talents = talents;
      _gear = gear;
      _rivals = ArchonDuelGenerator.generate(
        random: math.Random(progress.trophies * 31 + DateTime.now().day),
        trophies: progress.trophies,
      );
      _loading = false;
    });
  }

  List<ManaCard> _squadCards() {
    final state = ref.read(collectionProvider);
    final byId = {for (final c in state.owned) c.instanceId: c};
    final cards = <ManaCard>[];
    for (final id in state.squad.take(4)) {
      final owned = byId[id];
      if (owned == null) continue;
      cards.add(
        ManaCard(
          id: owned.catalogId,
          name: owned.name,
          element: owned.element,
          baseManaCost: owned.baseManaCost,
          attack: owned.baseAttack.toDouble(),
          stars: owned.stars,
          skillLevel: owned.skillLevel,
          masteryRank: owned.masteryRank,
        ),
      );
    }
    if (cards.isNotEmpty) return cards;
    return [
      ManaCard(
        id: 'ignis_hound',
        name: 'Sabueso de Azufre',
        element: Element.igneous,
        baseManaCost: 100,
        attack: 10,
      ),
    ];
  }

  Future<void> _challenge(ArchonRival rival) async {
    ProceduralSfxEngine.playUIHeavyClick();
    final guardian = BossConfig(
      id: 'archon_${rival.name.toLowerCase()}',
      name: rival.name,
      element: rival.cards.first.element,
      maxHp: 900 + _progress.trophies * 0.4 + rival.tier.points * 3,
      attackInterval: 5.0 - rival.tier.index * 0.4,
      attackDamage: 14 + rival.tier.index * 4,
      projectilesPerAttack: 2 + rival.tier.index,
      shieldHp: 0,
      threatDialog: '${rival.title} — el Coliseo exige sangre.',
      furyDialog: '¡MI MAZO NO CONOCE LA DERROTA!',
    );
    final engine = CombatEngine(
      boss: guardian,
      cards: _squadCards(),
      playerMaxHp: 110,
      talentLevels: _talents,
      summonerGear: _gear,
      scoreTarget: rival.targetScore,
    );
    final beforeLeague = _progress.league;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CombatScreen(
          engine: engine,
          onCombatResolved: (victory, _) async {
            await _recordDuel(rival, victory: victory);
          },
        ),
      ),
    );
    if (!mounted) return;
    final after = _progress;
    if (after.league.index > beforeLeague.index) {
      await _showPromotion(beforeLeague, after.league);
    }
    await _load();
  }

  Future<void> _recordDuel(ArchonRival rival, {required bool victory}) async {
    final repo = ref.read(playerRepositoryProvider);
    final previous = _progress;
    final next = victory
        ? previous.recordWin(tier: rival.tier, bonus: 0)
        : previous.recordLoss();
    await repo.saveArchonProgress(next);
    ArchonRewards? rewards;
    if (victory) {
      rewards = previous.rewardsFor(rival.tier);
      await ref.read(profileProvider.notifier).grant(
            shards: rewards.shards,
            gold: rewards.gold,
          );
      if (rewards.hasGoldenCard) {
        await repo.insertSummonedCard(
          rival.cards[math.min(3, rival.cards.length - 1)].catalogId,
        );
      }
    }
    await ref.read(collectionProvider.notifier).load();
    if (!mounted) return;
    setState(() => _progress = next);
    if (rewards != null) {
      await _showChest(rewards, rival);
    }
  }

  Future<void> _showChest(ArchonRewards rewards, ArchonRival rival) =>
      showDialog<void>(
        context: context,
        builder: (_) => GothicModalFrame(
          title: 'ARCA DE ASCENSO',
          subtitle: '${rival.name} · ${rival.title}',
          icon: Icons.workspace_premium,
          accent: const Color(0xFFE7BE5A),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'CONTINUAR',
                style: BrimstoneFonts.cinzel(
                  size: 11,
                  weight: FontWeight.w800,
                  color: BrimstoneTokens.goldPrimary,
                ),
              ),
            ),
          ],
          children: [
            Text(
              '+${rewards.shards} esquirlas  ·  +${rewards.gold} oro  ·  '
              '+${rewards.trophies} trofeos'
              '${rewards.hasGoldenCard ? '\n¡Carta dorada del rival reclamada!' : ''}',
              style: BrimstoneFonts.sans(
                size: 12,
                color: BrimstoneTokens.textPrimary,
              ),
            ),
          ],
        ),
      );

  Future<void> _showPromotion(ArchonLeague from, ArchonLeague to) =>
      showDialog<void>(
        context: context,
        builder: (_) => GothicModalFrame(
          title: 'ASCENSO DE LIGA',
          subtitle: '${from.label} → ${to.label}',
          icon: Icons.military_tech,
          accent: Color(to.emblemColor),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'CONTINUAR',
                style: BrimstoneFonts.cinzel(
                  size: 11,
                  weight: FontWeight.w800,
                  color: BrimstoneTokens.goldPrimary,
                ),
              ),
            ),
          ],
          children: [
            Text(
              'El Coliseo reconoce tu poder. Nuevos rivales y cofres con más '
              'esquirlas te esperan en ${to.label}.',
              style: BrimstoneFonts.sans(
                size: 12,
                color: BrimstoneTokens.textPrimary,
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final league = _progress.league;
    return Scaffold(
      backgroundColor: const Color(0xFF08060C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14090D),
        title: Text(
          'COLISEO DE LOS ARCONTES',
          style: BrimstoneFonts.cinzel(
            size: 14,
            weight: FontWeight.w900,
            color: const Color(0xFFE7BE5A),
            letterSpacing: 1.6,
          ),
        ),
      ),
      body: PaintedBackdrop(
        asset: ArtRegistry.metaScenes['rift']!,
        tint: const Color(0xFFE7BE5A),
        darkness: 0.4,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFE7BE5A)),
              )
            : ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  _LeagueHeader(progress: _progress),
                  const SizedBox(height: 14),
                  Text(
                    'RIVALES DISPONIBLES',
                    style: BrimstoneTypography.labelXS,
                  ),
                  const SizedBox(height: 8),
                  for (final rival in _rivals) ...[
                    _RivalCard(
                      rival: rival,
                      league: league,
                      onChallenge: () => _challenge(rival),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    'Cada duelo dura 45 s: superá el Puntaje Objetivo del rival '
                    'para sumar trofeos. Perder cuesta 12 trofeos (nunca bajás '
                    'del piso de tu liga).',
                    style: BrimstoneFonts.sans(
                      size: 10,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _LeagueHeader extends StatelessWidget {
  const _LeagueHeader({required this.progress});

  final ArchonProgress progress;

  @override
  Widget build(BuildContext context) {
    final league = progress.league;
    final accent = Color(league.emblemColor);
    final next = ArchonRanking.nextThreshold(progress.trophies);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1016), Color(0xFF08060C)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: CustomPaint(
                  painter: ArchonEmblemPainter(color: accent, league: league),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      league.label,
                      style: BrimstoneFonts.cinzel(
                        size: 16,
                        weight: FontWeight.w900,
                        color: accent,
                        letterSpacing: 1.4,
                      ),
                    ),
                    Text(
                      '${progress.trophies} trofeos  ·  '
                      '${progress.wins}V / ${progress.losses}D  ·  '
                      'racha ${progress.streak} (mejor ${progress.bestStreak})',
                      style: BrimstoneFonts.sans(
                        size: 10.5,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          MetallicProgressBar(
            value: ArchonRanking.progressToNext(progress.trophies),
            label: next == null
                ? 'CIMA DEL COLISEO'
                : 'PRÓXIMA LIGA · $next TROFEOS',
            color: accent,
          ),
        ],
      ),
    );
  }
}

class _RivalCard extends StatelessWidget {
  const _RivalCard({
    required this.rival,
    required this.league,
    required this.onChallenge,
  });

  final ArchonRival rival;
  final ArchonLeague league;
  final VoidCallback onChallenge;

  Color get _tierColor => switch (rival.tier) {
        ArchonDuelTier.facil => const Color(0xFF4FFFA3),
        ArchonDuelTier.parejo => const Color(0xFFFFC93C),
        ArchonDuelTier.desafio => const Color(0xFFFF5A26),
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0A10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _tierColor.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rival.name,
                      style: BrimstoneFonts.cinzel(
                        size: 13,
                        weight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      rival.title,
                      style: BrimstoneFonts.sans(
                        size: 9,
                        color: Colors.white54,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _tierColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _tierColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  rival.tier.label,
                  style: BrimstoneFonts.cinzel(
                    size: 8,
                    weight: FontWeight.w900,
                    color: _tierColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 116,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: rival.cards.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final card = rival.cards[index];
                return TcgCardWidget(
                  cardId: card.catalogId,
                  name: card.name,
                  element: card.element,
                  stars: card.stars,
                  attack: 12 + card.stars * 4,
                  width: 74,
                  height: 106,
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'PWR ${rival.power}',
                style: BrimstoneFonts.cinzel(
                  size: 10,
                  weight: FontWeight.w900,
                  color: BrimstoneTokens.goldPrimary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Puntaje objetivo ${rival.targetScore}',
                  style: BrimstoneFonts.sans(
                    size: 10,
                    color: Colors.white70,
                  ),
                ),
              ),
              Text(
                '+${rival.pointsAtStake} trofeos',
                style: BrimstoneFonts.sans(
                  size: 10,
                  color: _tierColor,
                  weight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            child: FilledButton(
              onPressed: onChallenge,
              style: FilledButton.styleFrom(
                backgroundColor: _tierColor.withValues(alpha: 0.22),
                side: BorderSide(color: _tierColor.withValues(alpha: 0.7)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: Text(
                'RETAR · ${league.label}',
                style: BrimstoneFonts.cinzel(
                  size: 10,
                  weight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Metallic league crest: bevelled shield, division pips and rune star.
class ArchonEmblemPainter extends CustomPainter {
  const ArchonEmblemPainter({required this.color, required this.league});

  final Color color;
  final ArchonLeague league;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final r = math.min(size.width, size.height) * 0.46;

    final shield = Path()
      ..moveTo(center.dx, center.dy - r)
      ..lineTo(center.dx + r * 0.82, center.dy - r * 0.45)
      ..lineTo(center.dx + r * 0.66, center.dy + r * 0.42)
      ..lineTo(center.dx, center.dy + r)
      ..lineTo(center.dx - r * 0.66, center.dy + r * 0.42)
      ..lineTo(center.dx - r * 0.82, center.dy - r * 0.45)
      ..close();

    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          color.withValues(alpha: 0.95),
          Color.lerp(color, Colors.black, 0.65)!,
        ],
      ).createShader(rect);
    canvas.drawPath(shield, fill);

    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = const Color(0xFFFFF3C4).withValues(alpha: 0.75);
    canvas.drawPath(shield, rim);

    // Division pips along the upper bevel.
    final pips = league.index + 1;
    final pipPaint = Paint()..color = const Color(0xFFFFF3C4);
    for (var i = 0; i < pips; i++) {
      final x = center.dx + (i - (pips - 1) / 2) * (r * 0.30);
      canvas.drawCircle(Offset(x, center.dy - r * 0.30), r * 0.055, pipPaint);
    }

    final star = Path();
    const points = 5;
    for (var i = 0; i < points * 2; i++) {
      final radius = i.isEven ? r * 0.34 : r * 0.15;
      final angle = -math.pi / 2 + i * math.pi / points;
      final p = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      if (i == 0) {
        star.moveTo(p.dx, p.dy);
      } else {
        star.lineTo(p.dx, p.dy);
      }
    }
    star.close();
    canvas.drawPath(star, Paint()..color = const Color(0xFFFFF3C4));
  }

  @override
  bool shouldRepaint(covariant ArchonEmblemPainter old) =>
      old.color != color || old.league != league;
}

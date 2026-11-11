import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../presentation/widgets/brimstone_button.dart';

/// Sala de Trofeos - 30 Medallas/Trofeos Abisales con barra de completitud.
class TrophyRoomScreen extends ConsumerStatefulWidget {
  const TrophyRoomScreen({super.key});

  static void show(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TrophyRoomScreen()),
    );
  }

  @override
  ConsumerState<TrophyRoomScreen> createState() => _TrophyRoomScreenState();
}

class _TrophyRoomScreenState extends ConsumerState<TrophyRoomScreen>
    with TickerProviderStateMixin {
  late final AnimationController _progressCtrl;
  late final AnimationController _particleCtrl;
  String _filter = 'all'; // all, earned, locked

  @override
  void initState() {
    super.initState();
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trophies = TrophyCatalog.all;
    final earnedCount = trophies.where((t) => t.isEarned).length;
    final totalCount = trophies.length;
    final completion = earnedCount / totalCount;

    final filtered = trophies.where((t) {
      if (_filter == 'earned') return t.isEarned;
      if (_filter == 'locked') return !t.isEarned;
      return true;
    }).toList();

    final isDesktop = MediaQuery.of(context).size.width > 560;

    return Scaffold(
      backgroundColor: const Color(0xFF0C0608),
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: CustomPaint(
              painter: _TrophyBackgroundPainter(
                progress: _particleCtrl.value,
                completion: completion,
              ),
            ),
          ),

          // Content
          CustomScrollView(
            slivers: [
              // App Bar
              SliverAppBar(
                expandedHeight: 140,
                pinned: true,
                backgroundColor: const Color(0xFF0C0608),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF1A0A0F),
                          const Color(0xFF0C0608),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 50),
                          ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [
                                BrimstoneTokens.goldPrimary,
                                BrimstoneTokens.goldMuted,
                                BrimstoneTokens.goldPrimary,
                              ],
                            ).createShader(bounds),
                            child: Text(
                              AppStrings.t('trophy.title'),
                              style: BrimstoneTokens.headingXL.copyWith(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Completion bar
                          SizedBox(
                            width: isDesktop ? 400 : double.infinity,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${AppStrings.t('trophy.completion')}: ${(completion * 100).round()}%',
                                        style:
                                            BrimstoneTypography.bodyMD.copyWith(
                                          color: BrimstoneTokens.goldPrimary,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Text(
                                        '$earnedCount / $totalCount',
                                        style:
                                            BrimstoneTypography.bodyMD.copyWith(
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  AnimatedBuilder(
                                    animation: _progressCtrl,
                                    builder: (_, __) => ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        height: 10,
                                        color: Colors.white12,
                                        child: FractionallySizedBox(
                                          alignment: Alignment.centerLeft,
                                          widthFactor:
                                              completion * _progressCtrl.value,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  BrimstoneTokens.goldPrimary,
                                                  BrimstoneTokens.goldMuted,
                                                ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),

              // Filter tabs
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _FilterChip(
                        label: AppStrings.t('trophy.earned'),
                        selected: _filter == 'earned',
                        onTap: () => setState(() => _filter = 'earned'),
                        count: earnedCount,
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: AppStrings.t('trophy.locked'),
                        selected: _filter == 'locked',
                        onTap: () => setState(() => _filter = 'locked'),
                        count: totalCount - earnedCount,
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Todos',
                        selected: _filter == 'all',
                        onTap: () => setState(() => _filter = 'all'),
                        count: totalCount,
                      ),
                    ],
                  ),
                ),
              ),

              // Trophy grid
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isDesktop ? 5 : 3,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.78,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _TrophyCard(
                      trophy: filtered[index],
                      onTap: () => _showTrophyDetail(filtered[index]),
                    ),
                    childCount: filtered.length,
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ],
      ),
    );
  }

  void _showTrophyDetail(Trophy trophy) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _TrophyDetailSheet(trophy: trophy),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int count;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  colors: [
                    BrimstoneTokens.goldPrimary.withValues(alpha: 0.3),
                    BrimstoneTokens.goldMuted.withValues(alpha: 0.1),
                  ],
                )
              : null,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? BrimstoneTokens.goldPrimary.withValues(alpha: 0.6)
                : Colors.white12,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? BrimstoneTokens.goldPrimary : Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selected
                    ? BrimstoneTokens.goldPrimary.withValues(alpha: 0.3)
                    : Colors.white12,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color:
                      selected ? BrimstoneTokens.goldPrimary : Colors.white54,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrophyCard extends StatelessWidget {
  final Trophy trophy;
  final VoidCallback onTap;

  const _TrophyCard({required this.trophy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: trophy.isEarned
                ? [
                    trophy.color.withValues(alpha: 0.15),
                    trophy.color.withValues(alpha: 0.05),
                    const Color(0xFF0C0608),
                  ]
                : [
                    const Color(0xFF14090D),
                    const Color(0xFF0C0608),
                    const Color(0xFF0C0608),
                  ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: trophy.isEarned
                ? trophy.color.withValues(alpha: 0.5)
                : Colors.white12,
            width: trophy.isEarned ? 1.5 : 1,
          ),
          boxShadow: trophy.isEarned
              ? [
                  BoxShadow(
                    color: trophy.color.withValues(alpha: 0.15),
                    blurRadius: 15,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Trophy icon
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: trophy.isEarned
                        ? LinearGradient(
                            colors: [
                              trophy.color.withValues(alpha: 0.3),
                              trophy.color.withValues(alpha: 0.1),
                            ],
                          )
                        : null,
                    color: trophy.isEarned ? null : Colors.white10,
                    border: Border.all(
                      color: trophy.isEarned
                          ? trophy.color.withValues(alpha: 0.6)
                          : Colors.white12,
                      width: 2,
                    ),
                    boxShadow: trophy.isEarned
                        ? [
                            BoxShadow(
                              color: trophy.color.withValues(alpha: 0.3),
                              blurRadius: 20,
                              spreadRadius: 3,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    trophy.icon,
                    size: 36,
                    color: trophy.isEarned ? trophy.color : Colors.white38,
                  ),
                ),
                if (!trophy.isEarned)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.6),
                        border: Border.all(color: Colors.white12, width: 2),
                      ),
                      child: const Center(
                        child:
                            Icon(Icons.lock, color: Colors.white38, size: 24),
                      ),
                    ),
                  ),
                if (trophy.isEarned && trophy.tier == TrophyTier.mythic)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.red.shade700, Colors.red.shade900],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'MÍTICO',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 7,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 10),

            // Name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                AppStrings.t(trophy.nameKey),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: trophy.isEarned ? Colors.white : Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
            ),

            const SizedBox(height: 4),

            // Progress bar (for locked trophies with progress)
            if (!trophy.isEarned && trophy.progress > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: Container(
                        height: 4,
                        color: Colors.white12,
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: trophy.progress,
                          child: Container(
                            color: trophy.color.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${(trophy.progress * 100).round()}%',
                      style: TextStyle(
                        color: trophy.color.withValues(alpha: 0.8),
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              )
            else if (trophy.isEarned)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  AppStrings.t('trophy.earned'),
                  style: TextStyle(
                    color: trophy.color,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  AppStrings.t('trophy.locked'),
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TrophyDetailSheet extends StatelessWidget {
  final Trophy trophy;

  const _TrophyDetailSheet({required this.trophy});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0608),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: trophy.isEarned
              ? trophy.color.withValues(alpha: 0.5)
              : Colors.white12,
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Trophy icon large
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: trophy.isEarned
                  ? LinearGradient(
                      colors: [
                        trophy.color.withValues(alpha: 0.3),
                        trophy.color.withValues(alpha: 0.1),
                      ],
                    )
                  : null,
              color: trophy.isEarned ? null : Colors.white10,
              border: Border.all(
                color: trophy.isEarned
                    ? trophy.color.withValues(alpha: 0.6)
                    : Colors.white12,
                width: 3,
              ),
              boxShadow: trophy.isEarned
                  ? [
                      BoxShadow(
                        color: trophy.color.withValues(alpha: 0.4),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              trophy.icon,
              size: 50,
              color: trophy.isEarned ? trophy.color : Colors.white38,
            ),
          ),

          const SizedBox(height: 16),

          // Name
          Text(
            AppStrings.t(trophy.nameKey),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 8),

          // Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: trophy.isEarned
                  ? trophy.color.withValues(alpha: 0.2)
                  : Colors.white12,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              trophy.isEarned
                  ? AppStrings.t('trophy.earned')
                  : AppStrings.t('trophy.locked'),
              style: TextStyle(
                color: trophy.isEarned ? trophy.color : Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Description
          Text(
            AppStrings.t(trophy.descKey),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
          ),

          if (!trophy.isEarned && trophy.progress > 0) ...[
            const SizedBox(height: 16),
            Column(
              children: [
                Text(
                  '${AppStrings.t('trophy.progress')}: ${(trophy.progress * 100).round()}%',
                  style: BrimstoneTypography.bodySM
                      .copyWith(color: Colors.white54),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    height: 10,
                    color: Colors.white12,
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: trophy.progress,
                      child: Container(
                        decoration: BoxDecoration(
                          color: trophy.color,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 24),

          // Close button
          BrimstoneButton(
            width: double.infinity,
            label: AppStrings.t('common.close'),
            onPressed: () => Navigator.pop(context),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _TrophyBackgroundPainter extends CustomPainter {
  final double progress;
  final double completion;

  _TrophyBackgroundPainter({required this.progress, required this.completion});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // Base gradient
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final baseGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF1A0A0F),
        const Color(0xFF0C0608),
      ],
    );
    paint.shader = baseGradient.createShader(rect);
    canvas.drawRect(rect, paint);

    // Floating particles
    for (int i = 0; i < 30; i++) {
      final x = (i * 127.3 + progress * size.width * 0.5) % size.width;
      final y = (i * 73.7 + progress * size.height * 0.3) % size.height;
      final r = 1.0 + (math.sin(progress * math.pi * 2 + i) * 0.5 + 0.5) * 2.0;

      paint.shader = null;
      paint.color = BrimstoneTokens.goldPrimary.withValues(
        alpha: 0.1 + 0.05 * math.sin(progress * math.pi * 4 + i),
      );
      canvas.drawCircle(Offset(x, y), r, paint);
    }

    // Completion glow at top
    if (completion > 0) {
      final glowPaint = Paint()
        ..shader = RadialGradient(
          center: Alignment.topCenter,
          radius: 1.5,
          colors: [
            BrimstoneTokens.goldPrimary.withValues(alpha: 0.15 * completion),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.6));
      canvas.drawRect(
          Rect.fromLTWH(0, 0, size.width, size.height * 0.6), glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TrophyBackgroundPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.completion != completion;
}

/// Catálogo de 30 Trofeos/Logros.
enum TrophyTier { bronze, silver, gold, mythic }

class Trophy {
  final String id;
  final String nameKey;
  final String descKey;
  final IconData icon;
  final Color color;
  final TrophyTier tier;
  final bool isEarned;
  final double progress; // 0.0 - 1.0 para trofeos con progreso

  const Trophy({
    required this.id,
    required this.nameKey,
    required this.descKey,
    required this.icon,
    required this.color,
    required this.tier,
    required this.isEarned,
    this.progress = 0.0,
  });

  Trophy copyWith({bool? isEarned, double? progress}) => Trophy(
        id: id,
        nameKey: nameKey,
        descKey: descKey,
        icon: icon,
        color: color,
        tier: tier,
        isEarned: isEarned ?? this.isEarned,
        progress: progress ?? this.progress,
      );
}

class TrophyCatalog {
  static List<Trophy> get all {
    return [
      // 1. Primera Victoria
      Trophy(
        id: 'first_victory',
        nameKey: 'achievement.first_victory.name',
        descKey: 'achievement.first_victory.desc',
        icon: Icons.emoji_events,
        color: const Color(0xFFCD7F32), // Bronze
        tier: TrophyTier.bronze,
        isEarned: _check('first_victory'),
      ),
      // 2-11. Capítulos 1-10
      Trophy(
        id: 'chapter_1_clear',
        nameKey: 'achievement.chapter_1_clear.name',
        descKey: 'achievement.chapter_1_clear.desc',
        icon: Icons.local_fire_department,
        color: const Color(0xFFFF5A26),
        tier: TrophyTier.bronze,
        isEarned: _check('chapter_1_clear'),
      ),
      Trophy(
        id: 'chapter_2_clear',
        nameKey: 'achievement.chapter_2_clear.name',
        descKey: 'achievement.chapter_2_clear.desc',
        icon: Icons.ac_unit,
        color: const Color(0xFF00BCD4),
        tier: TrophyTier.bronze,
        isEarned: _check('chapter_2_clear'),
      ),
      Trophy(
        id: 'chapter_3_clear',
        nameKey: 'achievement.chapter_3_clear.name',
        descKey: 'achievement.chapter_3_clear.desc',
        icon: Icons.landscape,
        color: const Color(0xFF8D6E63),
        tier: TrophyTier.bronze,
        isEarned: _check('chapter_3_clear'),
      ),
      Trophy(
        id: 'chapter_4_clear',
        nameKey: 'achievement.chapter_4_clear.name',
        descKey: 'achievement.chapter_4_clear.desc',
        icon: Icons.dark_mode,
        color: const Color(0xFF7B1FA2),
        tier: TrophyTier.bronze,
        isEarned: _check('chapter_4_clear'),
      ),
      Trophy(
        id: 'chapter_5_clear',
        nameKey: 'achievement.chapter_5_clear.name',
        descKey: 'achievement.chapter_5_clear.desc',
        icon: Icons.gavel,
        color: const Color(0xFFB16EFF),
        tier: TrophyTier.silver,
        isEarned: _check('chapter_5_clear'),
      ),
      Trophy(
        id: 'chapter_6_clear',
        nameKey: 'achievement.chapter_6_clear.name',
        descKey: 'achievement.chapter_6_clear.desc',
        icon: Icons.water_drop,
        color: const Color(0xFF006064),
        tier: TrophyTier.silver,
        isEarned: _check('chapter_6_clear'),
      ),
      Trophy(
        id: 'chapter_7_clear',
        nameKey: 'achievement.chapter_7_clear.name',
        descKey: 'achievement.chapter_7_clear.desc',
        icon: Icons.star,
        color: const Color(0xFF4527A0),
        tier: TrophyTier.silver,
        isEarned: _check('chapter_7_clear'),
      ),
      Trophy(
        id: 'chapter_8_clear',
        nameKey: 'achievement.chapter_8_clear.name',
        descKey: 'achievement.chapter_8_clear.desc',
        icon: Icons.church,
        color: const Color(0xFFD84315),
        tier: TrophyTier.silver,
        isEarned: _check('chapter_8_clear'),
      ),
      Trophy(
        id: 'chapter_9_clear',
        nameKey: 'achievement.chapter_9_clear.name',
        descKey: 'achievement.chapter_9_clear.desc',
        icon: Icons.hourglass_full,
        color: const Color(0xFFE65100),
        tier: TrophyTier.silver,
        isEarned: _check('chapter_9_clear'),
      ),
      Trophy(
        id: 'chapter_10_clear',
        nameKey: 'achievement.chapter_10_clear.name',
        descKey: 'achievement.chapter_10_clear.desc',
        icon: Icons.favorite,
        color: const Color(0xFFB71C1C),
        tier: TrophyTier.gold,
        isEarned: _check('chapter_10_clear'),
      ),
      // 12. Torre Piso 50
      Trophy(
        id: 'tower_50',
        nameKey: 'achievement.tower_50.name',
        descKey: 'achievement.tower_50.desc',
        icon: Icons.account_tree,
        color: const Color(0xFF4A148C),
        tier: TrophyTier.gold,
        isEarned: _check('tower_50'),
      ),
      // 13. 30 Barridos
      Trophy(
        id: 'tower_sweep_30',
        nameKey: 'achievement.tower_sweep_30.name',
        descKey: 'achievement.tower_sweep_30.desc',
        icon: Icons.cleaning_services,
        color: const Color(0xFF6A1B9A),
        tier: TrophyTier.gold,
        isEarned: _check('tower_sweep_30'),
      ),
      // 14. 40 Criaturas
      Trophy(
        id: 'all_40_creatures',
        nameKey: 'achievement.all_40_creatures.name',
        descKey: 'achievement.all_40_creatures.desc',
        icon: Icons.pets,
        color: const Color(0xFFB16EFF),
        tier: TrophyTier.gold,
        isEarned: _check('all_40_creatures'),
      ),
      // 15. Todas Míticas
      Trophy(
        id: 'all_mythic',
        nameKey: 'achievement.all_mythic.name',
        descKey: 'achievement.all_mythic.desc',
        icon: Icons.diamond,
        color: const Color(0xFFFFD700),
        tier: TrophyTier.mythic,
        isEarned: _check('all_mythic'),
      ),
      // 16. Paragon 100
      Trophy(
        id: 'paragon_100',
        nameKey: 'achievement.paragon_100.name',
        descKey: 'achievement.paragon_100.desc',
        icon: Icons.star_border,
        color: const Color(0xFFFFD700),
        tier: TrophyTier.mythic,
        isEarned: _check('paragon_100'),
      ),
      // 17. 12 Soul Bonds max
      Trophy(
        id: 'soul_bonds_all',
        nameKey: 'achievement.soul_bonds_all.name',
        descKey: 'achievement.soul_bonds_all.desc',
        icon: Icons.favorite,
        color: const Color(0xFFE91E63),
        tier: TrophyTier.mythic,
        isEarned: _check('soul_bonds_all'),
      ),
      // 18. Runas max con sub-stats
      Trophy(
        id: 'rune_max_all',
        nameKey: 'achievement.rune_max_all.name',
        descKey: 'achievement.rune_max_all.desc',
        icon: Icons.hexagon,
        color: const Color(0xFF00E676),
        tier: TrophyTier.gold,
        isEarned: _check('rune_max_all'),
      ),
      // 19. Login 365
      Trophy(
        id: 'login_365',
        nameKey: 'achievement.login_365.name',
        descKey: 'achievement.login_365.desc',
        icon: Icons.calendar_today,
        color: const Color(0xFF29B6F6),
        tier: TrophyTier.gold,
        isEarned: _check('login_365'),
      ),
      // 20. 4 Titanes Raid
      Trophy(
        id: 'raid_titan',
        nameKey: 'achievement.raid_titan.name',
        descKey: 'achievement.raid_titan.desc',
        icon: Icons.person,
        color: const Color(0xFFFF5A26),
        tier: TrophyTier.gold,
        isEarned: _check('raid_titan'),
      ),
      // 21. 100 Counter-flicks
      Trophy(
        id: 'counter_flick_100',
        nameKey: 'achievement.counter_flick_100.name',
        descKey: 'achievement.counter_flick_100.desc',
        icon: Icons.flash_on,
        color: const Color(0xFFFFD700),
        tier: TrophyTier.gold,
        isEarned: _check('counter_flick_100'),
      ),
      // 22. 50 Overdrive
      Trophy(
        id: 'overdrive_50',
        nameKey: 'achievement.overdrive_50.name',
        descKey: 'achievement.overdrive_50.desc',
        icon: Icons.bolt,
        color: const Color(0xFFFFB300),
        tier: TrophyTier.silver,
        isEarned: _check('overdrive_50'),
      ),
      // 23. Todos Artefactos
      Trophy(
        id: 'artifact_master',
        nameKey: 'achievement.artifact_master.name',
        descKey: 'achievement.artifact_master.desc',
        icon: Icons.auto_awesome,
        color: const Color(0xFFB16EFF),
        tier: TrophyTier.gold,
        isEarned: _check('artifact_master'),
      ),
      // 24. Nightmare
      Trophy(
        id: 'nightmare_clear',
        nameKey: 'achievement.nightmare_clear.name',
        descKey: 'achievement.nightmare_clear.desc',
        icon: Icons.nightlight,
        color: const Color(0xFF311B92),
        tier: TrophyTier.mythic,
        isEarned: _check('nightmare_clear'),
      ),
      // 25. 20 Bullseye streak
      Trophy(
        id: 'bullseye_streak_20',
        nameKey: 'achievement.bullseye_streak_20.name',
        descKey: 'achievement.bullseye_streak_20.desc',
        icon: Icons.center_focus_strong,
        color: const Color(0xFFFFD700),
        tier: TrophyTier.gold,
        isEarned: _check('bullseye_streak_20'),
      ),
      // 26. 500 Fusions
      Trophy(
        id: 'fusion_500',
        nameKey: 'achievement.fusion_500.name',
        descKey: 'achievement.fusion_500.desc',
        icon: Icons.merge,
        color: const Color(0xFF00E676),
        tier: TrophyTier.silver,
        isEarned: _check('fusion_500'),
      ),
      // 27. 100 Summons
      Trophy(
        id: 'summon_100',
        nameKey: 'achievement.summon_100.name',
        descKey: 'achievement.summon_100.desc',
        icon: Icons.casino,
        color: const Color(0xFF29B6F6),
        tier: TrophyTier.silver,
        isEarned: _check('summon_100'),
      ),
      // 28. 50 Expeditions
      Trophy(
        id: 'expedition_50',
        nameKey: 'achievement.expedition_50.name',
        descKey: 'achievement.expedition_50.desc',
        icon: Icons.explore,
        color: const Color(0xFF00BCD4),
        tier: TrophyTier.silver,
        isEarned: _check('expedition_50'),
      ),
      // 29. Guild Level 10
      Trophy(
        id: 'guild_level_10',
        nameKey: 'achievement.guild_level_10.name',
        descKey: 'achievement.guild_level_10.desc',
        icon: Icons.groups,
        color: const Color(0xFFB16EFF),
        tier: TrophyTier.gold,
        isEarned: _check('guild_level_10'),
      ),
      // 30. 6 Relics
      Trophy(
        id: 'all_relics',
        nameKey: 'achievement.all_relics.name',
        descKey: 'achievement.all_relics.desc',
        icon: Icons.museum,
        color: const Color(0xFFFFD700),
        tier: TrophyTier.gold,
        isEarned: _check('all_relics'),
      ),
    ];
  }

  static bool _check(String id) {
    // TODO: Integrar con persistence real (SharedPreferences/SQLite)
    // Por ahora, todos false para mostrar estado bloqueado
    return false;
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../presentation/widgets/brimstone_button.dart';

/// Live-Ops Hub Modal — Pilar 5: Calendario de 7 días + Eventos rotativos por día de la semana.
///
/// Se abre desde el Santuario. Todo se resuelve localmente con DateTime.now()
/// y la regla semanal fija (no requiere servidor).
class LiveOpsHubModal extends ConsumerStatefulWidget {
  const LiveOpsHubModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const LiveOpsHubModal(),
    );
  }

  @override
  ConsumerState<LiveOpsHubModal> createState() => _LiveOpsHubModalState();
}

class _LiveOpsHubModalState extends ConsumerState<LiveOpsHubModal>
    with TickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _glowCtrl;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _todayIndex);
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  int get _todayIndex => DateTime.now().weekday - 1; // 0=Mon ... 6=Sun

  @override
  void dispose() {
    _pageController.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 560;

    return Container(
      height: isDesktop ? 580 : MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: const Color(0xFF0C0608),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
            color: BrimstoneTokens.goldMuted.withValues(alpha: 0.5),
            width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _glowCtrl,
                  builder: (_, __) => ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [
                        BrimstoneTokens.goldPrimary,
                        BrimstoneTokens.goldMuted,
                        BrimstoneTokens.goldPrimary,
                      ],
                      stops: [
                        0.0,
                        0.5 + 0.3 * math.sin(_glowCtrl.value * 2 * math.pi),
                        1.0
                      ],
                    ).createShader(bounds),
                    child: Text(
                      AppStrings.t('live_ops.title'),
                      style: BrimstoneTokens.headingLG.copyWith(
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white70),
                ),
              ],
            ),
          ),

          // Tabs: Login Calendar / Weekly Events
          _TabBar(
            currentPage: _currentPage,
            onTap: (i) {
              _pageController.animateToPage(
                i,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
              );
            },
          ),

          // Page View
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _currentPage = i),
              children: [
                _LoginCalendarPage(todayIndex: _todayIndex),
                _WeeklyEventsPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  final int currentPage;
  final ValueChanged<int> onTap;

  const _TabBar({required this.currentPage, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tabs = [
      (AppStrings.t('live_ops.tab.login'), Icons.calendar_today),
      (AppStrings.t('live_ops.tab.events'), Icons.event),
    ];

    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF14090D),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final selected = i == currentPage;
          return Expanded(
            child: InkWell(
              onTap: () => onTap(i),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  gradient: selected
                      ? LinearGradient(
                          colors: [
                            BrimstoneTokens.goldPrimary.withValues(alpha: 0.3),
                            BrimstoneTokens.goldMuted.withValues(alpha: 0.1),
                          ],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? BrimstoneTokens.goldPrimary.withValues(alpha: 0.6)
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        tabs[i].$2,
                        size: 16,
                        color: selected
                            ? BrimstoneTokens.goldPrimary
                            : Colors.white54,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        tabs[i].$1,
                        style: TextStyle(
                          color: selected
                              ? BrimstoneTokens.goldPrimary
                              : Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Página 1: Pacto de los Siete Soles (7-day login)
class _LoginCalendarPage extends ConsumerWidget {
  final int todayIndex;

  const _LoginCalendarPage({required this.todayIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewards = LoginRewards.all;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.t('live_ops.login.subtitle'),
            style: BrimstoneTokens.bodyMD.copyWith(color: Colors.white54),
          ),
          const SizedBox(height: 16),

          // 7 day cards
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(7, (i) {
              final reward = rewards[i];
              final isToday = i == todayIndex;
              final isPast = i < todayIndex;
              return _LoginDayCard(
                day: i + 1,
                reward: reward,
                isToday: isToday,
                isPast: isPast,
                isClaimed: false,
                canClaim: isToday,
                onClaim: () {},
              );
            }),
          ),

          const SizedBox(height: 24),

          // Weekly progress
          _WeeklyProgressBar(claimedCount: 0),
        ],
      ),
    );
  }
}

class _LoginDayCard extends StatelessWidget {
  final int day;
  final LoginReward reward;
  final bool isToday;
  final bool isPast;
  final bool isClaimed;
  final bool canClaim;
  final VoidCallback onClaim;

  const _LoginDayCard({
    required this.day,
    required this.reward,
    required this.isToday,
    required this.isPast,
    required this.isClaimed,
    required this.canClaim,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Day circle
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isToday && !isClaimed
                ? LinearGradient(
                    colors: [
                      BrimstoneTokens.goldPrimary,
                      BrimstoneTokens.goldMuted,
                    ],
                  )
                : isClaimed
                    ? LinearGradient(
                        colors: [Colors.green.shade700, Colors.green.shade900],
                      )
                    : LinearGradient(
                        colors: [Colors.grey.shade800, Colors.grey.shade900],
                      ),
            border: Border.all(
              color: isToday && !isClaimed
                  ? BrimstoneTokens.goldPrimary
                  : isClaimed
                      ? Colors.green
                      : Colors.white12,
              width: isToday ? 3 : 1.5,
            ),
            boxShadow: isToday && !isClaimed
                ? [
                    BoxShadow(
                      color: BrimstoneTokens.goldPrimary.withValues(alpha: 0.4),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                '$day',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (isClaimed)
                const Icon(Icons.check, color: Colors.white, size: 24),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Reward preview
        Container(
          width: 70,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF14090D),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            children: [
              Icon(reward.icon),
              const SizedBox(height: 2),
              Text(
                reward.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),

        // Claim button / status
        if (canClaim)
          SizedBox(
            width: 70,
            child: BrimstoneButton(
              height: 28,
              label: AppStrings.t('live_ops.login.claim'),
              onPressed: onClaim,
            ),
          )
        else if (isClaimed)
          Text(
            AppStrings.t('live_ops.login.claimed'),
            style: const TextStyle(
                color: Colors.green, fontSize: 9, fontWeight: FontWeight.w800),
          )
        else if (isPast)
          Text(
            AppStrings.t('live_ops.login.expired'),
            style: const TextStyle(color: Colors.white38, fontSize: 9),
          )
        else
          Text(
            AppStrings.t('live_ops.login.coming'),
            style: const TextStyle(color: Colors.white38, fontSize: 9),
          ),
      ],
    );
  }
}

class _WeeklyProgressBar extends StatelessWidget {
  final int claimedCount;

  const _WeeklyProgressBar({required this.claimedCount});

  @override
  Widget build(BuildContext context) {
    final progress = claimedCount / 7.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppStrings.t('live_ops.login.weekly_progress'),
              style: BrimstoneTokens.bodySM.copyWith(color: Colors.white70),
            ),
            Text(
              '$claimedCount / 7',
              style: BrimstoneTokens.bodySM.copyWith(
                color: BrimstoneTokens.goldPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 10,
            color: Colors.white12,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      BrimstoneTokens.goldPrimary,
                      BrimstoneTokens.goldMuted
                    ],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          progress == 1.0
              ? AppStrings.t('live_ops.login.complete')
              : AppStrings.t('live_ops.login.remaining'),
          style: BrimstoneTokens.bodySM.copyWith(color: Colors.white54),
        ),
      ],
    );
  }
}

/// Página 2: Eventos rotativos por día de la semana
class _WeeklyEventsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final todayEvent = WeeklyLiveEventResolver.currentEvent();
    final allEvents = WeeklyLiveEventResolver.allEvents();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Today's event highlight
          _TodaysEventCard(event: todayEvent),
          const SizedBox(height: 24),

          // All events list
          Text(
            AppStrings.t('live_ops.events.all_events'),
            style: BrimstoneTokens.headingSM.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 12),

          ...allEvents
              .map((e) => _EventListTile(event: e, isToday: e == todayEvent)),
        ],
      ),
    );
  }
}

class _TodaysEventCard extends StatelessWidget {
  final WeeklyEvent event;

  const _TodaysEventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            event.color.withValues(alpha: 0.25),
            event.color.withValues(alpha: 0.1),
            const Color(0xFF0C0608),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: event.color.withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: event.color.withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: event.color.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  AppStrings.t('live_ops.events.today'),
                  style: TextStyle(
                    color: event.color,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              Icon(event.icon, color: event.color, size: 28),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            AppStrings.t(event.nameKey),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.t(event.descKey),
            style: const TextStyle(
                color: Colors.white70, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _EventListTile extends StatelessWidget {
  final WeeklyEvent event;
  final bool isToday;

  const _EventListTile({required this.event, required this.isToday});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isToday
            ? event.color.withValues(alpha: 0.15)
            : const Color(0xFF14090D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isToday ? event.color.withValues(alpha: 0.5) : Colors.white12,
          width: isToday ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: event.color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(event.icon, color: event.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      AppStrings.t(event.nameKey),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (isToday) ...[
                      const SizedBox(width: 8),
                      Text(
                        AppStrings.t('live_ops.events.active_now'),
                        style: TextStyle(
                          color: event.color,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  AppStrings.t(event.descKey),
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Recompensa del calendario de 7 días
class LoginReward {
  final String label;
  final IconData icon;
  final String type; // 'gold', 'shards', 'card', 'rune', 'energy'
  final int amount;

  const LoginReward({
    required this.label,
    required this.icon,
    required this.type,
    required this.amount,
  });
}

class LoginRewards {
  static const List<LoginReward> all = [
    LoginReward(
        label: '+5.000 Oro',
        icon: Icons.monetization_on,
        type: 'gold',
        amount: 5000),
    LoginReward(
        label: 'Carta Rara', icon: Icons.style, type: 'card', amount: 1),
    LoginReward(
        label: '+300 Esquirlas',
        icon: Icons.diamond,
        type: 'shards',
        amount: 300),
    LoginReward(
        label: '+1.000 Oro',
        icon: Icons.monetization_on,
        type: 'gold',
        amount: 1000),
    LoginReward(
        label: 'Runa Nv.3', icon: Icons.hexagon, type: 'rune', amount: 3),
    LoginReward(
        label: '+500 Esquirlas',
        icon: Icons.diamond,
        type: 'shards',
        amount: 500),
    LoginReward(
        label: 'Legendaria 3★', icon: Icons.star, type: 'card', amount: 1),
  ];
}

/// Evento semanal resuelto por día de la semana (Weekday-based, no server needed)
class WeeklyEvent {
  final int weekday; // 1-7
  final String nameKey;
  final String descKey;
  final IconData icon;
  final Color color;
  final List<String> effectKeys; // claves de localización para efectos

  const WeeklyEvent({
    required this.weekday,
    required this.nameKey,
    required this.descKey,
    required this.icon,
    required this.color,
    required this.effectKeys,
  });
}

/// Resuelve eventos live-ops por día de la semana (Weekday-based, no server needed)
class WeeklyLiveEventResolver {
  static const List<WeeklyEvent> _events = [
    // Lunes: Forja
    WeeklyEvent(
      weekday: 1,
      nameKey: 'live_ops.event.monday.name',
      descKey: 'live_ops.event.monday.desc',
      icon: Icons.auto_fix_high,
      color: Color(0xFFFFB300),
      effectKeys: ['live_ops.event.monday.effect1'],
    ),
    // Martes: Cacería
    WeeklyEvent(
      weekday: 2,
      nameKey: 'live_ops.event.tuesday.name',
      descKey: 'live_ops.event.tuesday.desc',
      icon: Icons.track_changes,
      color: Color(0xFFFF5A26),
      effectKeys: ['live_ops.event.tuesday.effect1'],
    ),
    // Miércoles: Alquímico
    WeeklyEvent(
      weekday: 3,
      nameKey: 'live_ops.event.wednesday.name',
      descKey: 'live_ops.event.wednesday.desc',
      icon: Icons.science,
      color: Color(0xFF00E676),
      effectKeys: ['live_ops.event.wednesday.effect1'],
    ),
    // Jueves: Torre
    WeeklyEvent(
      weekday: 4,
      nameKey: 'live_ops.event.thursday.name',
      descKey: 'live_ops.event.thursday.desc',
      icon: Icons.account_tree,
      color: Color(0xFFB16EFF),
      effectKeys: ['live_ops.event.thursday.effect1'],
    ),
    // Viernes: Invocación
    WeeklyEvent(
      weekday: 5,
      nameKey: 'live_ops.event.friday.name',
      descKey: 'live_ops.event.friday.desc',
      icon: Icons.auto_awesome,
      color: Color(0xFF29B6F6),
      effectKeys: ['live_ops.event.friday.effect1'],
    ),
    // Sábado: Frenesí Abisal
    WeeklyEvent(
      weekday: 6,
      nameKey: 'live_ops.event.saturday.name',
      descKey: 'live_ops.event.saturday.desc',
      icon: Icons.flash_on,
      color: Color(0xFFFF1744),
      effectKeys: [
        'live_ops.event.weekend.effect1',
        'live_ops.event.weekend.effect2'
      ],
    ),
    // Domingo: Frenesí Abisal
    WeeklyEvent(
      weekday: 7,
      nameKey: 'live_ops.event.sunday.name',
      descKey: 'live_ops.event.sunday.desc',
      icon: Icons.whatshot,
      color: Color(0xFFFF1744),
      effectKeys: [
        'live_ops.event.weekend.effect1',
        'live_ops.event.weekend.effect2'
      ],
    ),
  ];

  /// Evento actual basado en DateTime.now().weekday
  static WeeklyEvent currentEvent() {
    final weekday = DateTime.now().weekday; // 1=Mon ... 7=Sun
    return _events.firstWhere((e) => e.weekday == weekday);
  }

  static List<WeeklyEvent> allEvents() => List.unmodifiable(_events);

  /// Efectos numéricos para el motor de juego
  static double goldCostReduction() => currentEvent().weekday == 1 ? 0.25 : 0.0;
  static double raidLootBonus() => currentEvent().weekday == 2 ? 0.50 : 0.0;
  static double elementalReactionBonus() =>
      currentEvent().weekday == 3 ? 0.25 : 0.0;
  static double towerSweepMultiplier() =>
      currentEvent().weekday == 4 ? 2.0 : 1.0;
  static double summonShardDiscount() =>
      currentEvent().weekday == 5 ? 0.15 : 0.0;
  static double overdriveChargeSpeed() =>
      (currentEvent().weekday == 6 || currentEvent().weekday == 7) ? 0.50 : 0.0;
  static double weekendGoldXpBonus() =>
      (currentEvent().weekday == 6 || currentEvent().weekday == 7) ? 0.50 : 0.0;
}

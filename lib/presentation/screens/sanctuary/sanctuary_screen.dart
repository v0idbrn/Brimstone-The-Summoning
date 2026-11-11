import 'package:flutter/material.dart' hide Element;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:brimstone_summoning/core/audio/procedural_sfx_engine.dart';
import 'package:brimstone_summoning/core/l10n/app_strings.dart';
import 'package:brimstone_summoning/core/performance/performance_settings.dart';
import 'package:brimstone_summoning/core/theme/design_tokens.dart';
import 'package:brimstone_summoning/domain/campaign/campaign_chapters.dart';
import 'package:brimstone_summoning/domain/combat/combat_models.dart';
import 'package:brimstone_summoning/presentation/screens/combat/combat_screen.dart';
import 'package:brimstone_summoning/domain/entities/owned_card.dart';
// import 'package:brimstone_summoning/presentation/utils/element_ui.dart';
import 'package:brimstone_summoning/domain/meta/abyssal_expeditions.dart';
import 'package:brimstone_summoning/domain/meta/covenant_order.dart';
import 'package:brimstone_summoning/domain/meta/obsidian_tower.dart';
import 'package:brimstone_summoning/domain/meta/rune_system.dart';
import 'package:brimstone_summoning/domain/meta/squad_synergy_resolver.dart';
import 'package:brimstone_summoning/presentation/controllers/meta_controller.dart';
import 'package:brimstone_summoning/presentation/graphics/art_registry.dart';
import 'package:brimstone_summoning/presentation/graphics/painted_backdrop.dart';
import 'package:brimstone_summoning/presentation/widgets/brimstone_button.dart';
import 'package:brimstone_summoning/presentation/widgets/tcg_card_widget.dart';
import 'package:brimstone_summoning/presentation/widgets/interactive_pressable.dart';
// import '../meta/how_to_play_modal.dart';
import '../endless/endless_abyss_screen.dart';
import '../tower/obsidian_tower_screen.dart';
import '../challenges/seal_challenges_screen.dart';
import '../training/training_arena_screen.dart';
import '../arena_pvp/archon_colosseum_screen.dart';
import '../dungeons/elemental_chambers_screen.dart';
import '../raids/abyssal_raid_screen.dart';
// import '../shop/brimstone_shop_modal.dart';
import 'bounties_modal.dart';
import 'codex_modal.dart';
import 'battle_pass_modal.dart' show BattlePassModal; // solo modal, no conflict
import 'backup_restore_modal.dart';
import 'merchant_modal.dart';
import 'settings_modal.dart';
import 'summoner_profile_modal.dart';
import 'talent_tree_modal.dart';
import 'battle_log_modal.dart';
import '../expeditions/abyssal_expeditions_modal.dart';
import '../guild/covenant_guild_modal.dart';
import '../../../../domain/meta/summoner_titles.dart';

/// Main hub del Santuario reorganizado en 4 pestañas ilustradas (Pilar 11).
///
/// 1. Historia (Actos I–II) — Capítulos 1-10 + selector Normal/Pesadilla
/// 2. Torre & Cámaras — Torre de Obsidiana (50 pisos) + Cámaras Elementales
/// 3. Coliseo & Raids — Coliseo Arcontes + Cacería de Titanes + Abismo sin Fin
/// 4. Orden & Expediciones — Orden del Pacto + Expediciones Abisales + Juramentos
///
/// Incluye toggle ES/EN instantáneo persistido en SQLite v10, badges de
/// notificación en pestañas con expediciones/barrido listos, y 0 overflow
/// en 430x932 y 440x900.
class SanctuaryScreen extends ConsumerStatefulWidget {
  const SanctuaryScreen({super.key});

  @override
  ConsumerState<SanctuaryScreen> createState() => _SanctuaryScreenState();
}

class _SanctuaryScreenState extends ConsumerState<SanctuaryScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  Set<String> _clearedChapters = {};
  int _highestEndlessWave = 0;
  SummonerStats _stats = SummonerStats.empty;
  String? _activeTitleId;
  int _battlePassXp = 0;
  int _battlePassLevel = 1;
  int _towerBestFloor = 0;
  String? _towerLastSweepDay;
  String _storySelectedChapterId = 'chapter_ceniza';
  List<ExpeditionSlot> _expeditionSlots = [];
  GuildState? _guild;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMeta());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMeta() async {
    await ref.read(profileProvider.notifier).load();
    await ref.read(collectionProvider.notifier).load();
    await ref.read(bountyProvider.notifier).load();

    final repo = ref.read(playerRepositoryProvider);
    final cleared = await repo.loadClearedChapters();
    final wave = await repo.loadHighestEndlessWave();
    final stats = await repo.loadStats();
    final title = await repo.loadActiveTitle();
    final bpData = await repo.loadBattlePass();
    final rawSettings = await repo.loadRawStats();

    final tower = await repo.loadTowerProgress();
    final expeditions = await repo.loadExpeditionSlots();
    final guild = await repo.loadGuild();

    PerformanceSettings.restoreFromStorage(
      flag: rawSettings[PerformanceSettings.lowSpecKey],
    );
    if (!mounted) return;
    setState(() {
      _clearedChapters = cleared.toSet();
      _highestEndlessWave = wave;
      _stats = stats;
      _activeTitleId = title;
      _battlePassXp = bpData['xp'] as int? ?? 0;
      _battlePassLevel = (_battlePassXp ~/ 200) + 1;
      _towerBestFloor = tower.$1;
      _towerLastSweepDay = tower.$3;
      _expeditionSlots = expeditions;
      _guild = guild;
    });
  }

  /// Whether daily tower sweep is claimable.
  bool get _towerSweepReady {
    if (_towerBestFloor < ObsidianTower.bossInterval) return false;
    final todayKey = ObsidianTower.dayKeyOf(DateTime.now());
    if (_towerLastSweepDay == todayKey) return false;
    return ObsidianTower.sweepReward(_towerBestFloor, todayKey,
            lastSweepDay: _towerLastSweepDay) !=
        null;
  }

  /// Whether any expedition is complete and claimable.
  bool get _expeditionsReady {
    final now = DateTime.now().millisecondsSinceEpoch;
    return _expeditionSlots.any((s) => s.isComplete(now));
  }

  /// Whether guild daily contribution is available.
  bool get _guildContributionReady {
    if (_guild?.order == null) return false;
    final todayKey = ObsidianTower.dayKeyOf(DateTime.now());
    return _guild!.canContribute(todayKey);
  }

  String _equippedTitleName() =>
      SummonerTitles.resolve(_activeTitleId, _stats).name;

  // ——— Navigation helpers ———

  Future<void> _openTalentTree() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF14090D),
      builder: (_) => const TalentTreeModal(),
    );
    if (mounted) await _loadMeta();
  }

  Future<void> _openCodex() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF14090D),
      builder: (_) => const CodexModal(),
    );
  }

  Future<void> _openBackup() async {
    await showDialog<void>(
      context: context,
      builder: (_) => const BackupRestoreModal(),
    );
  }

  Future<void> _openBounties() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF14090D),
      builder: (_) => const BountiesModal(),
    );
  }

  Future<void> _openMerchant() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF14090D),
      builder: (_) => const MerchantModal(),
    );
  }

  Future<void> _openSettings() async {
    await showDialog<void>(
      context: context,
      builder: (_) => const SettingsModal(),
    );
  }

  Future<void> _openChallenges() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SealChallengesScreen()),
    );
  }

  Future<void> _openColosseum() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ArchonColosseumScreen(),
      ),
    );
    if (mounted) await _loadMeta();
  }

  Future<void> _openChambers() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ElementalChambersScreen(),
      ),
    );
    if (mounted) await _loadMeta();
  }

  Future<void> _openTraining() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TrainingArenaScreen()),
    );
  }

  Future<void> _openProfile() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF14090D),
      builder: (_) => const SummonerProfileModal(),
    );
    if (mounted) await _loadMeta();
  }

  Future<void> _openTower() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ObsidianTowerScreen(),
      ),
    );
    if (mounted) await _loadMeta();
  }

  Future<void> _openExpeditions() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF14090D),
      builder: (_) => const AbyssalExpeditionsModal(),
    );
    if (mounted) await _loadMeta();
  }

  Future<void> _openGuild() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF14090D),
      builder: (_) => const CovenantGuildModal(),
    );
    if (mounted) await _loadMeta();
  }

  Future<void> _openBattleLog() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF14090D),
      builder: (_) => const BattleLogModal(),
    );
  }

  void _toggleAudio() {
    final next = !ProceduralSfxEngine.isMuted;
    ProceduralSfxEngine.setMuted(next);
    ProceduralSfxEngine.playOrbSpawn();
  }

  // ——— Tab content builders ———

  Widget _buildStoryTab() {
    final collection = ref.watch(collectionProvider);
    final squad = [
      for (final id in collection.squad.take(4))
        if (collection.owned.any((c) => c.instanceId == id))
          collection.owned.firstWhere((c) => c.instanceId == id),
    ];
    final manaCards = squad
        .map(
          (c) => ManaCard(
            id: c.catalogId,
            name: c.name,
            element: c.element,
            baseManaCost: c.baseManaCost,
            attack: c.baseAttack.toDouble(),
            stars: c.stars,
          ),
        )
        .toList();
    final synergy = SquadSynergyResolver.resolve(manaCards);

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _CurrencyBar(),
        const SizedBox(height: 10),
        _SummonerHeader(
          titleName: _equippedTitleName(),
        ),
        const SizedBox(height: 12),
        _MetaActionsPanel(
          onTalentTree: _openTalentTree,
          onGear: _openTalentTree,
          onChallenges: _openChallenges,
          onTraining: _openTraining,
          onProfile: _openProfile,
          onSettings: _openSettings,
          onMerchant: _openMerchant,
          onCodex: _openCodex,
          onBounties: _openBounties,
          onColosseum: _openColosseum,
          onChambers: _openChambers,
          onBackup: _openBackup,
        ),
        const SizedBox(height: 12),
        _battlePassProgressBar(
          xp: _battlePassXp,
          level: _battlePassLevel,
          onTap: () => BattlePassModal.show(context),
        ),
        const SizedBox(height: 12),
        _SquadAltar(
          squad: squad,
          synergy: synergy,
        ),
        const SizedBox(height: 18),
        Text(
          AppStrings.t('common.chapters'),
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 8),
        ...campaignChapters.map(_chapterTile),
        const SizedBox(height: 18),
        BrimstoneButton(
          width: double.infinity,
          height: 52,
          icon: Icons.play_arrow,
          label: _chapterLocked
              ? AppStrings.t('common.defeat')
              : AppStrings.t('play.rift'),
          onPressed: _chapterLocked ? null : _startChapter,
        ),
        const SizedBox(height: 12),
        BrimstoneButton(
          isSecondary: true,
          width: double.infinity,
          height: 50,
          icon: Icons.rocket_launch,
          label: _highestEndlessWave > 0
              ? 'ABISMO SIN FIN (RÉCORD: OLA $_highestEndlessWave)'
              : 'ABISMO SIN FIN (ENDLESS)',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const EndlessAbyssScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildTowerTab() {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _CurrencyBar(),
        const SizedBox(height: 10),
        _TowerSummaryCard(
          bestFloor: _towerBestFloor,
          sweepReady: _towerSweepReady,
          onClimb: _openTower,
        ),
        const SizedBox(height: 12),
        BrimstoneButton(
          width: double.infinity,
          height: 52,
          icon: Icons.keyboard_arrow_up,
          label: 'ESCALAR LA TORRE (Piso ${_towerBestFloor + 1})',
          onPressed: _openTower,
        ),
        const SizedBox(height: 10),
        BrimstoneButton(
          isSecondary: true,
          width: double.infinity,
          height: 50,
          icon: Icons.travel_explore,
          label: 'CÁMARAS ELEMENTALES',
          onPressed: _openChambers,
        ),
        const SizedBox(height: 10),
        BrimstoneButton(
          isSecondary: true,
          width: double.infinity,
          height: 50,
          icon: Icons.auto_awesome,
          label: 'DESAFÍOS DEL SELLO',
          onPressed: _openChallenges,
        ),
        const SizedBox(height: 20),
        _MetaActionsPanel(
          onTalentTree: _openTalentTree,
          onGear: _openTalentTree,
          onChallenges: _openChallenges,
          onTraining: _openTraining,
          onProfile: _openProfile,
          onSettings: _openSettings,
          onMerchant: _openMerchant,
          onCodex: _openCodex,
          onBounties: _openBounties,
          onColosseum: _openColosseum,
          onChambers: _openChambers,
          onBackup: _openBackup,
        ),
      ],
    );
  }

  Widget _buildArenaTab() {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _CurrencyBar(),
        const SizedBox(height: 10),
        _SummonerHeader(titleName: _equippedTitleName()),
        const SizedBox(height: 12),
        BrimstoneButton(
          width: double.infinity,
          height: 52,
          icon: Icons.workspace_premium,
          label: 'COLOSEO DE LOS ARCONTES',
          onPressed: _openColosseum,
        ),
        const SizedBox(height: 10),
        BrimstoneButton(
          width: double.infinity,
          height: 52,
          icon: Icons.dangerous,
          label: 'CACERÍA DE TITANES (RAID)',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AbyssalRaidScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        BrimstoneButton(
          isSecondary: true,
          width: double.infinity,
          height: 50,
          icon: Icons.rocket_launch,
          label: _highestEndlessWave > 0
              ? 'ABISMO SIN FIN (RÉCORD: OLA $_highestEndlessWave)'
              : 'ABISMO SIN FIN (ENDLESS)',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const EndlessAbyssScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        BrimstoneButton(
          isSecondary: true,
          width: double.infinity,
          height: 50,
          icon: Icons.fitness_center,
          label: 'ARENA DE ENTRENAMIENTO',
          onPressed: _openTraining,
        ),
        const SizedBox(height: 20),
        _MetaActionsPanel(
          onTalentTree: _openTalentTree,
          onGear: _openTalentTree,
          onChallenges: _openChallenges,
          onTraining: _openTraining,
          onProfile: _openProfile,
          onSettings: _openSettings,
          onMerchant: _openMerchant,
          onCodex: _openCodex,
          onBounties: _openBounties,
          onColosseum: _openColosseum,
          onChambers: _openChambers,
          onBackup: _openBackup,
        ),
      ],
    );
  }

  Widget _buildOrderTab() {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _CurrencyBar(),
        const SizedBox(height: 10),
        _SummonerHeader(titleName: _equippedTitleName()),
        const SizedBox(height: 12),
        // Expediciones con badge si hay lista
        Stack(
          clipBehavior: Clip.none,
          children: [
            BrimstoneButton(
              width: double.infinity,
              height: 52,
              icon: Icons.auto_stories,
              label: 'EXPEDICIONES ABISALES',
              onPressed: _openExpeditions,
            ),
            if (_expeditionsReady)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4FFFA3),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        // Orden del Pacto con badge si contribución lista
        Stack(
          clipBehavior: Clip.none,
          children: [
            BrimstoneButton(
              width: double.infinity,
              height: 52,
              icon: Icons.groups,
              label: 'ORDEN DEL PACTO',
              onPressed: _openGuild,
            ),
            if (_guildContributionReady)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFC93C),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        BrimstoneButton(
          isSecondary: true,
          width: double.infinity,
          height: 50,
          icon: Icons.military_tech,
          label: 'JURAMENTOS DE AZUFRE',
          onPressed: _openBounties,
        ),
        const SizedBox(height: 10),
        BrimstoneButton(
          isSecondary: true,
          width: double.infinity,
          height: 50,
          icon: Icons.history,
          label: 'HISTORIAL DE BATALLAS',
          onPressed: _openBattleLog,
        ),
        const SizedBox(height: 10),
        BrimstoneButton(
          isSecondary: true,
          width: double.infinity,
          height: 50,
          icon: Icons.store,
          label: 'MERCADO DEL VACÍO',
          onPressed: _openMerchant,
        ),
        const SizedBox(height: 20),
        _MetaActionsPanel(
          onTalentTree: _openTalentTree,
          onGear: _openTalentTree,
          onChallenges: _openChallenges,
          onTraining: _openTraining,
          onProfile: _openProfile,
          onSettings: _openSettings,
          onMerchant: _openMerchant,
          onCodex: _openCodex,
          onBounties: _openBounties,
          onColosseum: _openColosseum,
          onChambers: _openChambers,
          onBackup: _openBackup,
        ),
      ],
    );
  }

  // ——— Chapter logic ———

  bool get _chapterLocked {
    final chapter = chapterById(_storySelectedChapterId);
    if (chapter == null) return true;
    return !chapterUnlocked(chapter.id, _clearedChapters.toList());
  }

  Future<void> _startChapter() async {
    final chapter = chapterById(_storySelectedChapterId);
    if (chapter == null || _chapterLocked) return;

    final repo = ref.read(playerRepositoryProvider);
    final collection = ref.read(collectionProvider);
    final squadIds = collection.squad;
    final owned = collection.owned;
    final cards = squadIds
        .take(4)
        .map((id) => owned.firstWhere((c) => c.instanceId == id))
        .map((c) => ManaCard(
              id: c.catalogId,
              name: c.name,
              element: c.element,
              baseManaCost: c.baseManaCost,
              attack: c.baseAttack.toDouble(),
              stars: c.stars.clamp(1, 3),
              skillLevel: c.skillLevel,
              masteryRank: c.masteryRank,
            ))
        .toList();
    if (cards.length < 4) return;

    final synergy = SquadSynergyResolver.resolve(cards);
    final cardRunes = <String, RuneInstance>{};
    for (final id in squadIds.take(4)) {
      try {
        final c = owned.firstWhere((card) => card.instanceId == id);
        final manaCard = cards.firstWhere((mc) => mc.id == c.catalogId);
        final rune = await repo.loadCardRune(c.instanceId);
        if (rune != null) cardRunes[manaCard.id] = rune;
      } catch (_) {}
    }

    final playerMaxHp = (100 * synergy.hpMult).roundToDouble();
    final startHp = playerMaxHp;
    final engine = CombatScreen.buildEngine(
      boss: chapter.boss,
      cards: cards,
      playerMaxHp: playerMaxHp,
      synergy: synergy,
      cardRunes: cardRunes,
      playerDamageMult: 1.0,
      startHp: startHp,
      startManaFull: false,
    );

    if (!mounted) return;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CombatScreen(engine: engine),
        fullscreenDialog: true,
      ),
    );

    if (result == true && mounted) {
      await repo.markChapterCleared(
        chapter.id,
        rewardGold: chapter.rewardGold,
        rewardShards: chapter.rewardShards,
      );
      await ref
          .read(profileProvider.notifier)
          .grant(gold: chapter.rewardGold, shards: chapter.rewardShards);
      _loadMeta();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '¡${chapter.name} completado! +${chapter.rewardGold} oro, +${chapter.rewardShards} esquirlas'),
          backgroundColor: const Color(0xFF4FFFA3),
        ));
      }
    }
  }

  Widget _chapterTile(CampaignChapter chapter) {
    final unlocked = chapterUnlocked(chapter.id, _clearedChapters.toList());
    final cleared = _clearedChapters.contains(chapter.id);
    final selected = _storySelectedChapterId == chapter.id;
    final boss = chapter.boss;

    // Nightmare mode available if cleared.
    final showNightmare = cleared;

    return GestureDetector(
      onTap: unlocked
          ? () => setState(() => _storySelectedChapterId = chapter.id)
          : null,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: selected
                ? const [Color(0xFF32121D), Color(0xFF1E0A12)]
                : const [Color(0xFF1A0E14), Color(0xFF0F060A)],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? const Color(0xFFFFD700)
                : (cleared
                    ? const Color(0xFF4FFFA3)
                    : unlocked
                        ? const Color(0xFFD4AF37)
                        : Colors.white12),
            width: selected ? 2.0 : 1.2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.35),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: cleared
                        ? const Color(0xFF4FFFA3).withValues(alpha: 0.2)
                        : unlocked
                            ? const Color(0xFFFFD700).withValues(alpha: 0.2)
                            : Colors.white10,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: cleared
                          ? const Color(0xFF4FFFA3)
                          : unlocked
                              ? const Color(0xFFFFD700)
                              : Colors.white24,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${chapter.number}',
                      style: TextStyle(
                        color: cleared
                            ? const Color(0xFF4FFFA3)
                            : unlocked
                                ? const Color(0xFFFFD700)
                                : Colors.white38,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              chapter.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: cleared
                                    ? const Color(0xFF4FFFA3)
                                    : unlocked
                                        ? Colors.white
                                        : Colors.white38,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (cleared)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0x334FFFA3),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'COMPLETADO',
                                style: TextStyle(
                                  color: Color(0xFF4FFFA3),
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          else if (unlocked)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0x33FFD700),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'DESBLOQUEADO',
                                style: TextStyle(
                                  color: Color(0xFFFFD700),
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          else
                            const Icon(
                              Icons.lock,
                              color: Colors.white38,
                              size: 14,
                            ),
                          if (showNightmare) ...[
                            const SizedBox(width: 6),
                            _NightmareChip(
                              onTap: () => _startNightmare(chapter),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Jefe: ${boss.name} (${chapter.bossTitle})',
                        style: TextStyle(
                          color: unlocked
                              ? const Color(0xFFFF9E2C)
                              : Colors.white38,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Recompensa: +${chapter.rewardGold} oro, +${chapter.rewardShards} esquirlas',
                        style: const TextStyle(
                          color: Color(0xFFFFC93C),
                          fontSize: 9.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startNightmare(CampaignChapter chapter) async {
    final repo = ref.read(playerRepositoryProvider);
    final collection = ref.read(collectionProvider);
    final squadIds = collection.squad;
    final owned = collection.owned;
    final cards = squadIds
        .take(4)
        .map((id) => owned.firstWhere((c) => c.instanceId == id))
        .map((c) => ManaCard(
              id: c.catalogId,
              name: c.name,
              element: c.element,
              baseManaCost: c.baseManaCost,
              attack: c.baseAttack.toDouble(),
              stars: c.stars.clamp(1, 3),
              skillLevel: c.skillLevel,
              masteryRank: c.masteryRank,
            ))
        .toList();
    if (cards.length < 4) return;

    final synergy = SquadSynergyResolver.resolve(cards);
    final cardRunes = <String, RuneInstance>{};
    for (final id in squadIds.take(4)) {
      try {
        final c = owned.firstWhere((card) => card.instanceId == id);
        final manaCard = cards.firstWhere((mc) => mc.id == c.catalogId);
        final rune = await repo.loadCardRune(c.instanceId);
        if (rune != null) cardRunes[manaCard.id] = rune;
      } catch (_) {}
    }

    final nightmareBoss = NightmareMode.scale(chapter.boss);
    final (gold, shards) = NightmareMode.scaledRewards(chapter);
    final playerMaxHp = (100 * synergy.hpMult).roundToDouble();

    final engine = CombatScreen.buildEngine(
      boss: nightmareBoss,
      cards: cards,
      playerMaxHp: playerMaxHp,
      synergy: synergy,
      cardRunes: cardRunes,
      playerDamageMult: 1.0,
      startHp: playerMaxHp,
      startManaFull: false,
    );

    if (!mounted) return;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CombatScreen(engine: engine),
        fullscreenDialog: true,
      ),
    );

    if (result == true && mounted) {
      await ref
          .read(profileProvider.notifier)
          .grant(gold: gold, shards: shards);
      _loadMeta();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('¡Pesadilla superada! +$gold oro, +$shards esquirlas'),
          backgroundColor: const Color(0xFF4FFFA3),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Cargar idioma persistido al iniciar
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: appLanguageNotifier,
      builder: (_, lang, __) {
        return Scaffold(
          backgroundColor: const Color(0xFF0C0608),
          appBar: AppBar(
            backgroundColor: const Color(0xFF14090D),
            title: Text(
              AppStrings.t('sanctuary.title'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFB16EFF),
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: 0.6,
              ),
            ),
            actions: [
              // Language toggle ES/EN
              IconButton(
                icon: Text(
                  lang == AppLanguage.es ? 'ES' : 'EN',
                  style: const TextStyle(
                    color: Color(0xFFB16EFF),
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
                onPressed: () {
                  setAppLanguage(
                      lang == AppLanguage.es ? AppLanguage.en : AppLanguage.es);
                  ref.read(playerRepositoryProvider).saveSetting(
                      'language', lang == AppLanguage.es ? 'en' : 'es');
                  ProceduralSfxEngine.playOrbSpawn();
                },
                tooltip: AppStrings.t('settings.language'),
              ),
              IconButton(
                icon: Icon(
                  ProceduralSfxEngine.isMuted
                      ? Icons.volume_off
                      : Icons.volume_up,
                  color: ProceduralSfxEngine.isMuted
                      ? Colors.white38
                      : const Color(0xFFB16EFF),
                ),
                onPressed: _toggleAudio,
                tooltip: ProceduralSfxEngine.isMuted
                    ? 'Audio activado'
                    : 'Audio desactivado',
              ),
              IconButton(
                icon: const Icon(Icons.person, color: Color(0xFFB16EFF)),
                onPressed: _openProfile,
                tooltip: 'Perfil de Invocador',
              ),
              IconButton(
                icon: const Icon(Icons.account_tree, color: Color(0xFF4FFFA3)),
                onPressed: _openTalentTree,
                tooltip: 'Árbol de Talentos y Armadura',
              ),
              IconButton(
                icon: const Icon(Icons.settings, color: Color(0xFFB16EFF)),
                onPressed: _openSettings,
                tooltip: AppStrings.t('settings.title'),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: false,
              labelColor: const Color(0xFFB16EFF),
              unselectedLabelColor: Colors.white38,
              indicatorColor: const Color(0xFFB16EFF),
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 10,
                letterSpacing: 0.5,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 10,
                letterSpacing: 0.5,
              ),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                          child: Text(AppStrings.t('sanctuary.tab.story'),
                              overflow: TextOverflow.ellipsis)),
                      if (_expeditionsReady || _towerSweepReady) ...[
                        const SizedBox(width: 4),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4FFFA3),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                          child: Text(AppStrings.t('sanctuary.tab.tower'),
                              overflow: TextOverflow.ellipsis)),
                      if (_towerSweepReady) ...[
                        const SizedBox(width: 4),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4FFFA3),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Tab(
                  child: Text(AppStrings.t('sanctuary.tab.arena'),
                      overflow: TextOverflow.ellipsis),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                          child: Text(AppStrings.t('sanctuary.tab.order'),
                              overflow: TextOverflow.ellipsis)),
                      if (_expeditionsReady || _guildContributionReady) ...[
                        const SizedBox(width: 4),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFC93C),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          body: PaintedBackdrop(
            asset: ArtRegistry.sanctuaryBlur,
            tint: BrimstoneAccents.voidPurple,
            darkness: 0.35,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildStoryTab(),
                _buildTowerTab(),
                _buildArenaTab(),
                _buildOrderTab(),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ——— Shared widgets ———

class _CurrencyBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF14090D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFB16EFF), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _CurrencyChip(
            icon: Icons.monetization_on,
            color: const Color(0xFFFFC93C),
            value: profile.gold.toString(),
            label: AppStrings.t('common.gold'),
          ),
          _CurrencyChip(
            icon: Icons.diamond,
            color: const Color(0xFF3FD8FF),
            value: profile.shards.toString(),
            label: AppStrings.t('common.shards'),
          ),
          _CurrencyChip(
            icon: Icons.bolt,
            color: const Color(0xFF4FFFA3),
            value: '${profile.energy}/20',
            label: AppStrings.t('common.energy'),
          ),
          _CurrencyChip(
            icon: Icons.star,
            color: const Color(0xFFB16EFF),
            value: profile.summonerLevel.toString(),
            label: AppStrings.t('common.level'),
          ),
        ],
      ),
    );
  }
}

class _CurrencyChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _CurrencyChip({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ],
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 8),
        ),
      ],
    );
  }
}

class _SummonerHeader extends StatelessWidget {
  final String titleName;

  const _SummonerHeader({required this.titleName});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF22111A), Color(0xFF140810), Color(0xFF0D040A)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFD4AF37),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33D4AF37),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [
                  Color(0xFFFFD700),
                  Color(0xFFFF5A26),
                  Color(0xFF2E050C)
                ],
              ),
              border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
            ),
            child: const Center(
              child: Icon(Icons.shield, color: Colors.white, size: 24),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'INVOCADOR DEL AZUFRE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  titleName,
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaActionsPanel extends StatelessWidget {
  const _MetaActionsPanel({
    required this.onTalentTree,
    required this.onGear,
    required this.onChallenges,
    required this.onTraining,
    required this.onProfile,
    required this.onSettings,
    required this.onMerchant,
    required this.onCodex,
    required this.onBounties,
    required this.onColosseum,
    required this.onChambers,
    required this.onBackup,
  });

  final VoidCallback onTalentTree;
  final VoidCallback onGear;
  final VoidCallback onChallenges;
  final VoidCallback onTraining;
  final VoidCallback onProfile;
  final VoidCallback onSettings;
  final VoidCallback onMerchant;
  final VoidCallback onCodex;
  final VoidCallback onBounties;
  final VoidCallback onColosseum;
  final VoidCallback onChambers;
  final VoidCallback onBackup;

  @override
  Widget build(BuildContext context) {
    final actions = <_MetaAction>[
      _MetaAction(
          AppStrings.t('common.barracks'), Icons.account_tree, onTalentTree),
      _MetaAction('Armadura', Icons.shield_moon, onGear),
      _MetaAction('Desafíos', Icons.gavel, onChallenges),
      _MetaAction('Arena', Icons.fitness_center, onTraining),
      _MetaAction('Perfil', Icons.person, onProfile),
      _MetaAction(AppStrings.t('settings.title'), Icons.settings, onSettings),
      _MetaAction(AppStrings.t('common.summon'), Icons.store, onMerchant),
      _MetaAction('Códice', Icons.menu_book, onCodex),
      _MetaAction('Juramentos', Icons.military_tech, onBounties),
      _MetaAction('Backup', Icons.backup, onBackup),
      _MetaAction('Coliseo', Icons.workspace_premium, onColosseum),
      _MetaAction('Cámaras', Icons.travel_explore, onChambers),
    ];

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: BrimstoneTokens.surfaceBase,
        borderRadius: BorderRadius.circular(BrimstoneRadii.radiusLG),
        border: BrimstoneBorders.hairline,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MESA DEL INVOCADOR',
            style: BrimstoneTypography.labelXS,
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.6,
            ),
            itemCount: actions.length,
            itemBuilder: (context, index) {
              final action = actions[index];
              return _MetaActionButton(action: action);
            },
          ),
        ],
      ),
    );
  }
}

class _MetaAction {
  const _MetaAction(this.label, this.icon, this.onTap);

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

class _MetaActionButton extends StatelessWidget {
  const _MetaActionButton({required this.action});

  final _MetaAction action;

  @override
  Widget build(BuildContext context) {
    return InteractivePressable(
      onTap: action.onTap,
      borderRadius: BorderRadius.circular(BrimstoneRadii.radiusMD),
      padding: const EdgeInsets.all(6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            action.icon,
            size: 16,
            color: BrimstoneTokens.goldPrimary,
          ),
          const SizedBox(height: 4),
          Flexible(
            child: Text(
              action.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: BrimstoneTypography.labelSM.copyWith(fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }
}

class _SquadAltar extends StatelessWidget {
  final List<OwnedCard> squad;
  final SquadSynergyBonus synergy;

  const _SquadAltar({required this.squad, required this.synergy});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF140810),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'ALTAR DEL ESCUADRÓN',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFD4AF37),
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'PWR: ${squad.fold<int>(0, (sum, c) => sum + c.baseAttack)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFFF9E2C),
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < 4; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i == 3 ? 0 : 6),
                    child: (i < squad.length)
                        ? AspectRatio(
                            aspectRatio: 0.72,
                            child: TcgCardWidget.fromOwnedCard(
                              card: squad[i],
                              isLeader: i == 0,
                              raised: true,
                            ),
                          )
                        : AspectRatio(
                            aspectRatio: 0.72,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF0C0508),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: const Center(
                                child: Icon(Icons.add, color: Colors.white24),
                              ),
                            ),
                          ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TowerSummaryCard extends StatelessWidget {
  final int bestFloor;
  final bool sweepReady;
  final VoidCallback onClimb;

  const _TowerSummaryCard({
    required this.bestFloor,
    required this.sweepReady,
    required this.onClimb,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF14090D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFB16EFF), width: 2),
      ),
      child: Column(
        children: [
          Text('TORRE DE OBSIDIANA',
              style: TextStyle(
                  color: const Color(0xFFB16EFF),
                  fontWeight: FontWeight.w800,
                  fontSize: 16)),
          const SizedBox(height: 8),
          Text('50 Sellos de Ascenso',
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _TowerStat(
                  label: 'MEJOR PISO',
                  value: '$bestFloor / 50',
                  color: const Color(0xFFB16EFF),
                ),
              ),
              Expanded(
                child: _TowerStat(
                  label: 'PRÓXIMO',
                  value: bestFloor >= 50 ? 'CÚSPIDE' : '${bestFloor + 1}',
                  color: const Color(0xFF3FD8FF),
                ),
              ),
              Expanded(
                child: _TowerStat(
                  label: sweepReady ? 'BARRIDO LISTO' : 'BARRIDO',
                  value: sweepReady ? '¡COBRAR!' : 'DIARIO',
                  color: sweepReady
                      ? const Color(0xFF4FFFA3)
                      : const Color(0xFFFFC93C),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TowerStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _TowerStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w900, fontSize: 16)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9)),
      ],
    );
  }
}

class _NightmareChip extends StatelessWidget {
  final VoidCallback onTap;

  const _NightmareChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: const Color(0x33FF5A26),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFFF5A26)),
        ),
        child: const Text(
          'PESADILLA',
          style: TextStyle(
            color: Color(0xFFFF5A26),
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// Battle Pass progress bar widget (copied from original).
Widget _battlePassProgressBar({
  required int xp,
  required int level,
  required VoidCallback onTap,
}) {
  const maxLevel = 20;
  const xpPerLevel = 200;
  final xpInLevel = xp % xpPerLevel;
  final progress = level >= maxLevel ? 1.0 : xpInLevel / xpPerLevel;
  final displayLevel = level.clamp(1, maxLevel);

  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1A0E14),
            const Color(0xFF0F060A),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFC93C), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.emoji_events,
                        color: Color(0xFFFFC93C), size: 16),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'PASE NIVEL $displayLevel',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xFFFFC93C),
                            fontWeight: FontWeight.w900,
                            fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
              Text('$xpInLevel / $xpPerLevel XP',
                  style: const TextStyle(color: Colors.white70, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white12,
            valueColor: const AlwaysStoppedAnimation(Color(0xFFFFC93C)),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    ),
  );
}

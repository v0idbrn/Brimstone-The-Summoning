import 'package:flutter/material.dart' hide Element;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/procedural_sfx_engine.dart';
import '../../../core/performance/performance_settings.dart';
import '../../../domain/campaign/campaign_chapters.dart';
import '../../../domain/meta/squad_synergy_resolver.dart';
import '../../../domain/combat/combat_models.dart';
import '../../controllers/meta_controller.dart';
import '../../widgets/brimstone_button.dart';
import '../../widgets/tcg_card_widget.dart';
import '../rift/rift_map_screen.dart';
import '../meta/how_to_play_modal.dart';
import '../meta/widgets.dart';
import '../endless/endless_abyss_screen.dart';
import 'bounties_modal.dart';
import 'codex_modal.dart';
import 'battle_pass_modal.dart';
import 'backup_restore_modal.dart';
import 'merchant_modal.dart';
import 'settings_modal.dart';
import 'summoner_profile_modal.dart';
import 'talent_tree_modal.dart';
import '../challenges/seal_challenges_screen.dart';
import '../training/training_arena_screen.dart';
import '../../../domain/meta/summoner_titles.dart';

/// Main hub: summoner level, currencies, active squad preview, rift difficulty
/// selector and the main play CTA.
class SanctuaryScreen extends ConsumerStatefulWidget {
  const SanctuaryScreen({super.key});

  @override
  ConsumerState<SanctuaryScreen> createState() => _SanctuaryScreenState();
}

/// Accesos directos del Santuario en una cuadrícula que nunca desborda.
///
/// El AppBar mantiene los iconos compactos; este panel aporta etiquetas
/// legibles y garantiza que las diez pantallas/modales de las fases 15–22
/// estén a un toque en cualquier ancho de pantalla.
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
  final VoidCallback onBackup;

  @override
  Widget build(BuildContext context) {
    final actions = <_MetaAction>[
      _MetaAction(
        'Talentos',
        Icons.account_tree,
        const Color(0xFF4FFFA3),
        onTalentTree,
      ),
      _MetaAction(
        'Armadura',
        Icons.shield_moon,
        const Color(0xFF4FFFA3),
        onGear,
      ),
      _MetaAction(
        'Desafíos',
        Icons.gavel,
        const Color(0xFFFF5A26),
        onChallenges,
      ),
      _MetaAction(
        'Arena',
        Icons.fitness_center,
        const Color(0xFF3FD8FF),
        onTraining,
      ),
      _MetaAction('Perfil', Icons.person, const Color(0xFFB16EFF), onProfile),
      _MetaAction(
        'Ajustes',
        Icons.settings,
        const Color(0xFFB16EFF),
        onSettings,
      ),
      _MetaAction('Mercader', Icons.store, const Color(0xFFB16EFF), onMerchant),
      _MetaAction('Códice', Icons.menu_book, const Color(0xFFB16EFF), onCodex),
      _MetaAction(
        'Juramentos',
        Icons.military_tech,
        const Color(0xFFFFC93C),
        onBounties,
      ),
      _MetaAction('Backup', Icons.backup, const Color(0xFFB16EFF), onBackup),
    ];
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF14090D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MESA DEL INVOCADOR',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 10,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final action in actions) _MetaActionChip(action)],
          ),
        ],
      ),
    );
  }
}

class _MetaAction {
  const _MetaAction(this.label, this.icon, this.color, this.onTap);

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class _MetaActionChip extends StatelessWidget {
  const _MetaActionChip(this.action);

  final _MetaAction action;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: action.onTap,
      icon: Icon(action.icon, size: 15, color: action.color),
      label: Text(
        action.label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        side: BorderSide(color: action.color.withValues(alpha: 0.45)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _SanctuaryScreenState extends ConsumerState<SanctuaryScreen> {
  String _selectedChapterId = 'chapter_ceniza';
  Set<String> _clearedChapters = {};
  int _highestEndlessWave = 0;
  SummonerStats _stats = SummonerStats.empty;
  String? _activeTitleId;
  // Battle Pass progress
  int _battlePassXp = 0;
  int _battlePassLevel = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMeta());
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
    });
  }

  /// Nombre del título equipado (o el título por defecto).
  String _equippedTitleName() =>
      SummonerTitles.resolve(_activeTitleId, _stats).name;

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

  Future<void> _openTraining() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TrainingArenaScreen()),
    );
  }

  Future<void> _openHowToPlay() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF14090D),
      builder: (_) => const HowToPlayModal(),
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

  void _toggleAudio() {
    final next = !ProceduralSfxEngine.isMuted;
    ProceduralSfxEngine.setMuted(next);
    ProceduralSfxEngine.playOrbSpawn();
  }

  @override
  Widget build(BuildContext context) {
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

    return Scaffold(
      backgroundColor: const Color(0xFF0C0608),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14090D),
        title: const Text(
          'SANTUARIO DEL AZUFRE',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Color(0xFFB16EFF),
            fontWeight: FontWeight.w900,
            fontSize: 13,
            letterSpacing: 0.6,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              ProceduralSfxEngine.isMuted ? Icons.volume_off : Icons.volume_up,
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
            tooltip: 'Ajustes',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Color(0xFFB16EFF)),
            tooltip: 'Más accesos',
            color: const Color(0xFF14090D),
            onSelected: (value) {
              switch (value) {
                case 'codex':
                  _openCodex();
                case 'backup':
                  _openBackup();
                case 'bounties':
                  _openBounties();
                case 'merchant':
                  _openMerchant();
                case 'challenges':
                  _openChallenges();
                case 'training':
                  _openTraining();
                case 'howto':
                  _openHowToPlay();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'codex',
                child: Text('Códice Abisal',
                    style: TextStyle(color: Colors.white)),
              ),
              PopupMenuItem(
                value: 'backup',
                child: Text('Backup / Restaurar',
                    style: TextStyle(color: Colors.white)),
              ),
              PopupMenuItem(
                value: 'bounties',
                child: Text('Juramentos de Azufre',
                    style: TextStyle(color: Colors.white)),
              ),
              PopupMenuItem(
                value: 'merchant',
                child: Text('Mercader del Vacío',
                    style: TextStyle(color: Colors.white)),
              ),
              PopupMenuItem(
                value: 'challenges',
                child: Text('Desafíos del Sello',
                    style: TextStyle(color: Colors.white)),
              ),
              PopupMenuItem(
                value: 'training',
                child: Text('Arena de Entrenamiento',
                    style: TextStyle(color: Colors.white)),
              ),
              PopupMenuItem(
                value: 'howto',
                child:
                    Text('Cómo jugar', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          const CurrencyBar(),
          const SizedBox(height: 10),
          // Header de Invocador ornamentado
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF22111A),
                  Color(0xFF140810),
                  Color(0xFF0D040A)
                ],
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
                    border:
                        Border.all(color: const Color(0xFFD4AF37), width: 1.5),
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
                        _equippedTitleName(),
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
            onBackup: _openBackup,
          ),
          const SizedBox(height: 12),
          // Battle Pass Progress Bar
          _battlePassProgressBar(
            xp: _battlePassXp,
            level: _battlePassLevel,
            onTap: () => BattlePassModal.show(context),
          ),
          const SizedBox(height: 12),
          // Altar del Escuadrón con PWR total y TcgCardWidget
          Container(
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
                        style: TextStyle(
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
                        'PWR TOTAL: ${squad.fold<int>(0, (sum, c) => sum + c.baseAttack)}',
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
                                      child: Icon(Icons.add,
                                          color: Colors.white24),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Banner de sinergia activa.
          if (synergy.isActive)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A0E14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFB16EFF), width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    color: Color(0xFFB16EFF),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          synergy.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          synergy.description,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 18),
          const Text(
            'Capítulos de la Campaña',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 8),
          ...campaignChapters.map(_chapterTile),
          const SizedBox(height: 18),
          BrimstoneButton(
            width: double.infinity,
            height: 52,
            icon: Icons.play_arrow,
            label: _chapterLocked
                ? 'CAPÍTULO BLOQUEADO'
                : 'INICIAR INCURSIÓN DE GRIETA',
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
          const SizedBox(height: 14),
          const Center(
            child: Text(
              'Forja esferas, invoca cartas, evoluciona tu escuadrón y sella la Grieta.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white24, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  bool get _chapterLocked {
    final chapter = chapterById(_selectedChapterId);
    if (chapter == null) return true;
    return !chapterUnlocked(chapter.id, _clearedChapters.toList());
  }

  Widget _chapterTile(CampaignChapter chapter) {
    final unlocked = chapterUnlocked(chapter.id, _clearedChapters.toList());
    final cleared = _clearedChapters.contains(chapter.id);
    final selected = _selectedChapterId == chapter.id;
    final boss = chapter.boss;

    return GestureDetector(
      onTap: unlocked
          ? () => setState(() => _selectedChapterId = chapter.id)
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
        child: Row(
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
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Jefe: ${boss.name} (${chapter.bossTitle})',
                    style: TextStyle(
                      color:
                          unlocked ? const Color(0xFFFF9E2C) : Colors.white38,
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
      ),
    );
  }

  /// Battle Pass progress bar widget.
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
          border: Border.all(
            color: const Color(0xFFB16EFF).withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFB16EFF).withValues(alpha: 0.15),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.military_tech,
                    color: Color(0xFFFFC93C), size: 18),
                const SizedBox(width: 6),
                const Text(
                  'PASE DEL SELLO ABISAL',
                  style: TextStyle(
                    color: Color(0xFFFFC93C),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      const Color(0xFFB16EFF).withValues(alpha: 0.3),
                      const Color(0xFF3FD8FF).withValues(alpha: 0.3),
                    ]),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Nivel $displayLevel / $maxLevel',
                    style: const TextStyle(
                      color: Color(0xFFFFC93C),
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Stack(
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E0A0E),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [
                        Color(0xFFFFC93C),
                        Color(0xFFFFD700),
                        Color(0xFFB16EFF),
                      ]),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    '$xpInLevel / $xpPerLevel XP',
                    style: const TextStyle(color: Colors.white54, fontSize: 8),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '+50 XP/enemigo  •  +150 XP/jefe',
                    style: const TextStyle(
                        color: Color(0xFFB16EFF),
                        fontSize: 8,
                        fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              'Toca para ver recompensas (20 niveles, Carril Gratis + Arconte)',
              style: const TextStyle(color: Colors.white24, fontSize: 7),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startChapter() async {
    final chapter = chapterById(_selectedChapterId);
    if (chapter == null) return;
    if (!chapterUnlocked(chapter.id, _clearedChapters.toList())) return;

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RiftMapScreen(chapterNumber: chapter.number),
      ),
    );
    // Refresh chapter cleared state after returning from rift map
    if (!mounted) return;
    final cleared =
        await ref.read(playerRepositoryProvider).loadClearedChapters();
    setState(() => _clearedChapters = cleared.toSet());
  }
}

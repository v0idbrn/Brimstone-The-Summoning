import 'package:flutter/material.dart' hide Element;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/procedural_sfx_engine.dart';
import '../../../domain/campaign/campaign_chapters.dart';
import '../../../domain/meta/squad_synergy_resolver.dart';
import '../../../domain/combat/combat_models.dart';
import '../../../domain/value_objects/element.dart';
import '../../controllers/meta_controller.dart';
import '../combat/combat_screen.dart';
import '../meta/how_to_play_modal.dart';
import '../meta/widgets.dart';
import '../endless/endless_abyss_screen.dart';
import 'bounties_modal.dart';
import 'codex_modal.dart';
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

class _SanctuaryScreenState extends ConsumerState<SanctuaryScreen> {
  String _selectedChapterId = 'chapter_ceniza';
  Set<String> _clearedChapters = {};
  int _highestEndlessWave = 0;
  SummonerStats _stats = SummonerStats.empty;
  String? _activeTitleId;

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
    if (!mounted) return;
    setState(() {
      _clearedChapters = cleared.toSet();
      _highestEndlessWave = wave;
      _stats = stats;
      _activeTitleId = title;
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
          style: TextStyle(
            color: Color(0xFFB16EFF),
            fontWeight: FontWeight.w900,
            fontSize: 15,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          // Barra desplazable: el Santuario tiene 11 accesos y la app es
          // portrait, así que los iconos nunca deben desbordar el AppBar.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
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
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.menu_book, color: Color(0xFFB16EFF)),
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: const Color(0xFF14090D),
                    builder: (_) => const CodexModal(),
                  ),
                  tooltip: 'Códice Abisal',
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.backup, color: Color(0xFFB16EFF)),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const BackupRestoreModal(),
                  ),
                  tooltip: 'Backup / Restaurar',
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon:
                      const Icon(Icons.military_tech, color: Color(0xFFFFC93C)),
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: const Color(0xFF14090D),
                    builder: (_) => const BountiesModal(),
                  ),
                  tooltip: 'Juramentos de Azufre',
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.store, color: Color(0xFFB16EFF)),
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: const Color(0xFF14090D),
                    builder: (_) => const MerchantModal(),
                  ),
                  tooltip: 'Mercader del Vacío',
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.settings, color: Color(0xFFB16EFF)),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const SettingsModal(),
                  ),
                  tooltip: 'Ajustes',
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.person, color: Color(0xFFB16EFF)),
                  onPressed: _openProfile,
                  tooltip: 'Perfil de Invocador',
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon:
                      const Icon(Icons.account_tree, color: Color(0xFF4FFFA3)),
                  onPressed: _openTalentTree,
                  tooltip: 'Árbol de Talentos y Armadura',
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.gavel, color: Color(0xFFFF5A26)),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const SealChallengesScreen()),
                  ),
                  tooltip: 'Desafíos del Sello',
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.fitness_center,
                      color: Color(0xFF3FD8FF)),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const TrainingArenaScreen()),
                  ),
                  tooltip: 'Arena de Entrenamiento',
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon:
                      const Icon(Icons.help_outline, color: Color(0xFFB16EFF)),
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: const Color(0xFF14090D),
                    builder: (_) => const HowToPlayModal(),
                  ),
                  tooltip: 'Cómo jugar',
                ),
              ],
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          const CurrencyBar(),
          const SizedBox(height: 10),
          // Perfil del Invocador: título equipado bajo el nombre.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1A0E14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFFFC93C).withValues(alpha: 0.6),
              ),
            ),
            child: Column(
              children: [
                const Text(
                  'INVOCADOR DEL AZUFRE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _equippedTitleName(),
                  style: const TextStyle(
                    color: Color(0xFFFFC93C),
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Escuadrón activo',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < 4; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i == 3 ? 0 : 6),
                    child: (i < squad.length)
                        ? Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CardTileSmall(card: squad[i], raised: true),
                              if (i == 0)
                                Positioned(
                                  top: -8,
                                  left: -8,
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
                          )
                        : Container(
                            height: 84,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: const Center(
                              child: Icon(Icons.add, color: Colors.white24),
                            ),
                          ),
                  ),
                ),
            ],
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
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB16EFF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.play_arrow),
              label: Text(
                _chapterLocked ? 'CAPÍTULO BLOQUEADO' : 'INICIAR CAPÍTULO',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              onPressed: _chapterLocked ? null : _startChapter,
            ),
          ),
          const SizedBox(height: 14),
          // Insignia del récord del Abismo Sin Fin.
          if (_highestEndlessWave > 0)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A0E14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFC93C), width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.emoji_events,
                    color: Color(0xFFFFC93C),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Abismo Sin Fin — Récord',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Oleada máxima alcanzada: $_highestEndlessWave',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF802020),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.rocket_launch),
            label: const Text(
              'ABISMO SIN FIN (ENDLESS)',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
            ),
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
    return GestureDetector(
      onTap: unlocked
          ? () => setState(() => _selectedChapterId = chapter.id)
          : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A0E14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cleared
                ? const Color(0xFF4FFFA3)
                : unlocked
                    ? const Color(0xFFB16EFF)
                    : Colors.white38,
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: cleared
                    ? const Color(0xFF4FFFA3).withValues(alpha: 0.2)
                    : unlocked
                        ? const Color(0xFFB16EFF).withValues(alpha: 0.2)
                        : Colors.white10,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${chapter.number}',
                style: TextStyle(
                  color: cleared ? const Color(0xFF4FFFA3) : Colors.white,
                  fontWeight: FontWeight.w900,
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
                      Text(
                        chapter.name,
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
                      if (cleared)
                        const Icon(
                          Icons.check_circle,
                          color: Color(0xFF4FFFA3),
                          size: 16,
                        ),
                      if (!unlocked)
                        const Icon(
                          Icons.lock,
                          color: Colors.white38,
                          size: 16,
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    chapter.bossTitle,
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Primera victoria: +${chapter.rewardGold} oro, +${chapter.rewardShards} esquirlas',
                    style: const TextStyle(
                      color: Color(0xFFFFC93C),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: Color(0xFFB16EFF), size: 20)
            else
              const SizedBox(width: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _startChapter() async {
    final chapter = chapterById(_selectedChapterId);
    if (chapter == null) return;
    if (!chapterUnlocked(chapter.id, _clearedChapters.toList())) return;

    final collectionState = ref.read(collectionProvider);
    final cards = <ManaCard>[];
    for (final id in collectionState.squad.take(4)) {
      final owned = collectionState.owned.firstWhere(
        (c) => c.instanceId == id,
      );
      cards.add(
        ManaCard(
          id: owned.catalogId,
          name: owned.name,
          element: owned.element,
          baseManaCost: owned.baseManaCost,
          attack: owned.baseAttack.toDouble(),
          stars: owned.stars,
        ),
      );
    }
    if (cards.isEmpty) {
      cards.addAll(
        [
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
      );
    }
    final engine = CombatScreen.buildEngine(
      boss: chapter.boss,
      cards: cards,
      playerMaxHp: 100,
    );
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CombatScreen(
          engine: engine,
          onCombatResolved: (victory, playerHp) async {
            if (!victory) return;
            final firstWin =
                await ref.read(playerRepositoryProvider).markChapterCleared(
                      chapter.id,
                      rewardGold: chapter.rewardGold,
                      rewardShards: chapter.rewardShards,
                    );
            if (!mounted) return;
            final cleared =
                await ref.read(playerRepositoryProvider).loadClearedChapters();
            setState(() => _clearedChapters = cleared.toSet());
            if (!mounted) return;
            await showDialog<void>(
              context: context,
              builder: (_) => AlertDialog(
                backgroundColor: const Color(0xFF14090D),
                title: Text(
                  'CAPÍTULO ${chapter.number} COMPLETADO',
                  style: const TextStyle(
                    color: Color(0xFF4FFFA3),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                content: Text(
                  firstWin
                      ? 'Primera victoria: +${chapter.rewardGold} oro, +${chapter.rewardShards} esquirlas.'
                      : 'Capítulo ya limpiado previamente.',
                  style: const TextStyle(color: Colors.white),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'CONTINUAR',
                      style: TextStyle(color: Color(0xFFB16EFF)),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

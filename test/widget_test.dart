import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:brimstone_summoning/data/database/database_helper.dart';
import 'package:brimstone_summoning/data/repositories/player_repository.dart';
import 'package:brimstone_summoning/domain/meta/rune_system.dart';
import 'package:brimstone_summoning/domain/meta/summoner_titles.dart';
import 'package:brimstone_summoning/domain/entities/owned_card.dart';
import 'package:brimstone_summoning/domain/value_objects/element.dart';
import 'package:brimstone_summoning/domain/value_objects/rarity.dart';
import 'package:brimstone_summoning/presentation/controllers/meta_controller.dart';
import 'package:brimstone_summoning/presentation/screens/altar/altar_evolution_screen.dart';
import 'package:brimstone_summoning/presentation/screens/barracks/barracks_screen.dart';
import 'package:brimstone_summoning/presentation/screens/challenges/seal_challenges_screen.dart';
import 'package:brimstone_summoning/presentation/screens/meta/widgets.dart';
import 'package:brimstone_summoning/presentation/screens/meta/how_to_play_modal.dart';
import 'package:brimstone_summoning/presentation/screens/sanctuary/backup_restore_modal.dart';
import 'package:brimstone_summoning/presentation/screens/sanctuary/bounties_modal.dart';
import 'package:brimstone_summoning/presentation/screens/sanctuary/codex_modal.dart';
import 'package:brimstone_summoning/presentation/screens/sanctuary/merchant_modal.dart';
import 'package:brimstone_summoning/presentation/screens/sanctuary/sanctuary_screen.dart';
import 'package:brimstone_summoning/presentation/screens/sanctuary/settings_modal.dart';
import 'package:brimstone_summoning/presentation/screens/sanctuary/summoner_profile_modal.dart';
import 'package:brimstone_summoning/presentation/screens/sanctuary/talent_tree_modal.dart';
import 'package:brimstone_summoning/presentation/screens/summon/summon_portal_screen.dart';
import 'package:brimstone_summoning/presentation/screens/training/training_arena_screen.dart';
import 'package:brimstone_summoning/main.dart';
import 'package:flutter/material.dart' hide Element;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMeta {
  final String name;
  final Element element;
  final Rarity rarity;
  const _FakeMeta(this.name, this.element, this.rarity);
}

const _catalogMeta = <String, _FakeMeta>{
  'ignis_hound': _FakeMeta('Sabueso de Azufre', Element.igneous, Rarity.common),
  'abyss_stalker': _FakeMeta('Acechador', Element.abyssal, Rarity.common),
  'terra_golem': _FakeMeta('Gólem de Basalto', Element.telluric, Rarity.common),
  'terra_titan': _FakeMeta('Titán', Element.telluric, Rarity.epic),
  'void_specter': _FakeMeta('Espectro del Sello', Element.empty, Rarity.rare),
  'ignis_lord': _FakeMeta(
    'Ignis, Señor de Brasas',
    Element.igneous,
    Rarity.epic,
  ),
  'abyss_leviathan': _FakeMeta('Leviatán', Element.abyssal, Rarity.legendary),
  'void_malakor': _FakeMeta('Malakor', Element.empty, Rarity.mythic),
};

/// Mock DatabaseHelper that doesn't open a real database.
class _MockDatabaseHelper extends DatabaseHelper {
  _MockDatabaseHelper() : super();

  @override
  Future<Database> get db async =>
      throw UnimplementedError('Use fake repo methods');
}

/// Fake repository implementing all PlayerRepository methods without DB access.
class _FakePlayerRepository extends PlayerRepository {
  _FakePlayerRepository() : super(_MockDatabaseHelper());

  var _nextId = 1;
  final _cards = <OwnedCard>[];
  final _squad = <int>[];
  var _profileGold = 500;
  var _profileShards = 100;

  @override
  Future<List<int>> loadProfile() async => [
        _profileGold,
        _profileShards,
        20,
        1,
      ];

  @override
  Future<void> saveProfile({
    required int gold,
    required int shards,
    required int energy,
    required int summonerLevel,
  }) async {
    _profileGold = gold;
    _profileShards = shards;
  }

  @override
  Future<List<OwnedCard>> loadCollection() async => List.of(_cards);

  @override
  Future<OwnedCard> insertSummonedCard(String catalogId) async {
    final meta = _catalogMeta[catalogId] ?? _catalogMeta['ignis_hound']!;
    final card = OwnedCard(
      instanceId: _nextId++,
      catalogId: catalogId,
      name: meta.name,
      element: meta.element,
      rarity: meta.rarity,
      baseManaCost: 100,
      baseAttack: 10,
      baseHealth: 15,
      level: 1,
      stars: 1,
      skillLevel: 1,
      masteryXp: 0,
    );
    _cards.insert(0, card);
    return card;
  }

  @override
  Future<void> deleteOwnedCard(int instanceId) async {
    _cards.removeWhere((c) => c.instanceId == instanceId);
    _squad.remove(instanceId);
  }

  @override
  Future<void> updateOwnedCard(OwnedCard card) async {
    for (var i = 0; i < _cards.length; i++) {
      if (_cards[i].instanceId == card.instanceId) _cards[i] = card;
    }
  }

  @override
  Future<List<int>> loadSquad() async => List.of(_squad);

  @override
  Future<void> saveSquad(List<int> instanceIds) async {
    _squad
      ..clear()
      ..addAll(instanceIds);
  }

  @override
  Future<List<String>> loadClearedChapters() async => [];

  @override
  Future<int> loadHighestEndlessWave() async => 0;

  @override
  Future<SummonerStats> loadStats() async => SummonerStats(
      combatsWon: _cards.isEmpty ? 0 : 1, cardsOwned: _cards.length);

  @override
  Future<String?> loadActiveTitle() async => null;

  @override
  Future<void> saveActiveTitle(String? titleId) async {}

  @override
  Future<void> saveHighestEndlessWave(int wave) async {}

  @override
  Future<String?> loadLastTributeDate() async => null;

  @override
  Future<List<Map<String, Object?>>> loadBounties() async => [];

  @override
  Future<void> saveBounties(List<Map<String, Object?>> rows) async {}

  @override
  Future<bool> markChapterCleared(String chapterId,
          {required int rewardGold, required int rewardShards}) async =>
      false;

  @override
  Future<RuneInstance?> loadCardRune(int instanceId) async => null;

  @override
  Future<Map<String, int>> loadRawStats() async => const {};

  @override
  Future<void> writeStat(String key, int value) async {}

  @override
  Future<Map<String, int>> loadTalentLevels() async => const {};

  @override
  Future<Map<String, int>> loadGearLevels() async => const {};

  @override
  Future<List<String>> loadClearedChallenges() async => const [];

  @override
  Future<Map<String, int>> loadCodexDetonations() async => const {};

  @override
  Future<void> incrementCodexReaction(String nameOrId) async {}

  @override
  Future<bool> upgradeTalent(String talentId) async => false;

  @override
  Future<bool> forgeGear(String gearId) async => false;

  @override
  Future<bool> markChallengeCleared(
    String challengeId, {
    int rewardGold = 500,
    int rewardShards = 250,
  }) async =>
      false;

  @override
  Future<void> recordCombatResult({
    required bool victory,
    int damageTotal = 0,
    int maxHit = 0,
    int bullseyes = 0,
    int bestBullseyeStreak = 0,
    int reactions = 0,
    int counterflicks = 0,
    bool bossKilled = false,
  }) async {}

  @override
  Future<Map<String, Object?>> loadBattlePass() async {
    return {
      'xp': 0,
      'claimedFree': <int>[],
      'claimedPremium': <int>[],
      'premiumUnlocked': 0,
    };
  }

  @override
  Future<void> saveBattlePass(Map<String, Object?> data) async {}

  @override
  Future<List<Map<String, Object?>>> loadDeckPresets() async {
    return const [];
  }

  @override
  Future<void> saveDeckPresets(List<Map<String, Object?>> rows) async {}
}

Override _fakeRepoOverride() =>
    playerRepositoryProvider.overrideWithValue(_FakePlayerRepository());

/// Wraps a screen in ProviderScope with the fake repository.
Widget _screen(Widget child) => ProviderScope(
      overrides: [_fakeRepoOverride()],
      // Los modales se muestran de verdad dentro de un sheet/dialog (que aportan
      // Material); el Scaffold reproduce ese ancestro en los smoke tests.
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(body: child),
      ),
    );

void main() {
  group('Widget smoke — meta screens', () {
    testWidgets('SanctuaryScreen renders title', (tester) async {
      await tester.pumpWidget(_screen(const SanctuaryScreen()));
      await tester.pumpAndSettle();
      expect(find.text('SANTUARIO DEL AZUFRE'), findsOneWidget);
    });

    testWidgets('BarracksScreen renders title', (tester) async {
      await tester.pumpWidget(_screen(const BarracksScreen()));
      await tester.pumpAndSettle();
      expect(find.text('CUARTEL'), findsOneWidget);
    });

    testWidgets('AltarEvolutionScreen renders title', (tester) async {
      await tester.pumpWidget(_screen(const AltarEvolutionScreen()));
      await tester.pumpAndSettle();
      expect(find.text('ALTAR DE EVOLUCIÓN'), findsOneWidget);
    });

    // SummonPortal uses pump (300ms) instead of pumpAndSettle because of the
    // infinite AnimationController.
    testWidgets('SummonPortalScreen renders both buttons', (tester) async {
      await tester.pumpWidget(_screen(const SummonPortalScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('PORTAL DE INVOCACIÓN'), findsOneWidget);
      expect(find.text('PACTO MENOR'), findsOneWidget);
      expect(find.text('GRAN RITUAL'), findsOneWidget);
    });

    testWidgets('CurrencyBar renders all 4 currencies', (tester) async {
      await tester.pumpWidget(_screen(const CurrencyBar()));
      await tester.pumpAndSettle();
      expect(find.text('Nv.1'), findsOneWidget);
      expect(find.text('500'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
      expect(find.text('20'), findsOneWidget);
    });
  });

  group('Widget smoke — pantallas y modales de las fases 15–22 (430x932)', () {
    setUp(() {});

    Future<void> pumpMobile(WidgetTester tester, Widget widget) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(_screen(widget));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('el Santuario expone la mesa del invocador sin overflow',
        (tester) async {
      await pumpMobile(tester, const SanctuaryScreen());
      expect(find.text('MESA DEL INVOCADOR'), findsOneWidget);
      for (final label in [
        'Talentos',
        'Armadura',
        'Desafíos',
        'Arena',
        'Perfil',
        'Ajustes',
        'Mercader',
        'Códice',
        'Juramentos',
        'Backup',
      ]) {
        expect(find.text(label), findsWidgets, reason: 'falta $label');
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('el Santuario mantiene los accesos primarios del AppBar',
        (tester) async {
      await pumpMobile(tester, const SanctuaryScreen());
      for (final tooltip in [
        'Perfil de Invocador',
        'Árbol de Talentos y Armadura',
        'Ajustes',
        'Más accesos',
      ]) {
        expect(find.byTooltip(tooltip), findsOneWidget, reason: tooltip);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('el menú «Más accesos» lista las siete entradas restantes',
        (tester) async {
      await pumpMobile(tester, const SanctuaryScreen());
      await tester.tap(find.byTooltip('Más accesos'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      for (final label in [
        'Códice Abisal',
        'Backup / Restaurar',
        'Juramentos de Azufre',
        'Mercader del Vacío',
        'Desafíos del Sello',
        'Arena de Entrenamiento',
        'Cómo jugar',
      ]) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('tocar Talentos abre el árbol de talentos', (tester) async {
      await pumpMobile(tester, const SanctuaryScreen());
      await tester.tap(find.byTooltip('Árbol de Talentos y Armadura'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('TALENTOS'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tocar Perfil abre el perfil de invocador', (tester) async {
      await pumpMobile(tester, const SanctuaryScreen());
      await tester.tap(find.byTooltip('Perfil de Invocador'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('PERFIL DEL INVOCADOR'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tocar Ajustes abre el modal de ajustes', (tester) async {
      await pumpMobile(tester, const SanctuaryScreen());
      await tester.tap(find.byTooltip('Ajustes'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('AJUSTES'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('TalentTreeModal renderiza talentos y armadura',
        (tester) async {
      await pumpMobile(tester, const TalentTreeModal());
      expect(find.text('TALENTOS'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('SummonerProfileModal muestra métricas y títulos',
        (tester) async {
      await pumpMobile(tester, const SummonerProfileModal());
      expect(find.text('PERFIL DEL INVOCADOR'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('SettingsModal incluye el Modo Gama Baja', (tester) async {
      await pumpMobile(tester, const SettingsModal());
      expect(find.text('AJUSTES'), findsOneWidget);
      expect(find.text('Modo Gama Baja'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('CodexModal renderiza el códice abisal', (tester) async {
      await pumpMobile(tester, const CodexModal());
      expect(tester.takeException(), isNull);
    });

    testWidgets('BountiesModal renderiza los juramentos', (tester) async {
      await pumpMobile(tester, const BountiesModal());
      expect(tester.takeException(), isNull);
    });

    testWidgets('MerchantModal renderiza el mercader', (tester) async {
      await pumpMobile(tester, const MerchantModal());
      expect(tester.takeException(), isNull);
    });

    testWidgets('BackupRestoreModal renderiza el respaldo', (tester) async {
      await pumpMobile(tester, const BackupRestoreModal());
      expect(tester.takeException(), isNull);
    });

    testWidgets('HowToPlayModal renderiza la ayuda', (tester) async {
      await pumpMobile(tester, const HowToPlayModal());
      expect(tester.takeException(), isNull);
    });

    testWidgets('SealChallengesScreen lista los 10 desafíos', (tester) async {
      await pumpMobile(tester, const SealChallengesScreen());
      expect(tester.takeException(), isNull);
    });

    testWidgets('TrainingArenaScreen renderiza la arena', (tester) async {
      await pumpMobile(tester, const TrainingArenaScreen());
      expect(tester.takeException(), isNull);
    });
  });

  group('Widget smoke — marco arcade web (1280x800)', () {
    Future<void> pumpDesktop(WidgetTester tester, Widget widget) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(_screen(widget));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('la app se envuelve en el gabinete arcade', (tester) async {
      await pumpDesktop(tester, const WebArcadeFrame(child: HomeShell()));
      expect(find.byKey(WebArcadeFrame.frameKey), findsOneWidget);
      expect(find.text('BRIMSTONE: THE SUMMONING'), findsOneWidget);
      expect(find.text('CLICK + ARRASTRAR · Fusionar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('el Santuario dentro del gabinete no desborda', (tester) async {
      await pumpDesktop(tester, const WebArcadeFrame(child: SanctuaryScreen()));
      expect(find.byKey(WebArcadeFrame.frameKey), findsOneWidget);
      expect(find.text('SANTUARIO DEL AZUFRE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('en móvil no se dibuja el gabinete', (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(_screen(const WebArcadeFrame(child: SizedBox())));
      await tester.pump();
      expect(find.byKey(WebArcadeFrame.frameKey), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('justo en el breakpoint (560px) sigue siendo móvil',
        (tester) async {
      tester.view.physicalSize = const Size(560, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(_screen(const WebArcadeFrame(child: SizedBox())));
      await tester.pump();
      expect(find.byKey(WebArcadeFrame.frameKey), findsNothing);
    });
  });
}

import 'package:brimstone_summoning/data/database/database_helper.dart';
import 'package:brimstone_summoning/data/repositories/player_repository.dart';
import 'package:brimstone_summoning/domain/entities/owned_card.dart';
import 'package:brimstone_summoning/domain/value_objects/element.dart';
import 'package:brimstone_summoning/domain/value_objects/rarity.dart';
import 'package:brimstone_summoning/presentation/controllers/meta_controller.dart';
import 'package:brimstone_summoning/presentation/screens/altar/altar_evolution_screen.dart';
import 'package:brimstone_summoning/presentation/screens/barracks/barracks_screen.dart';
import 'package:brimstone_summoning/presentation/screens/meta/widgets.dart';
import 'package:brimstone_summoning/presentation/screens/sanctuary/sanctuary_screen.dart';
import 'package:brimstone_summoning/presentation/screens/summon/summon_portal_screen.dart';
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

class _FakePlayerRepository extends PlayerRepository {
  _FakePlayerRepository() : super(DatabaseHelper());

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
}

Override _fakeRepoOverride() =>
    playerRepositoryProvider.overrideWithValue(_FakePlayerRepository());

/// Wraps a screen in ProviderScope with the fake repository.
Widget _screen(Widget child) => ProviderScope(
      overrides: [_fakeRepoOverride()],
      child: MaterialApp(theme: ThemeData.dark(), home: child),
    );

void main() {
  group('Widget smoke — meta screens', () {
    testWidgets('SanctuaryScreen renders title and CTA', (tester) async {
      await tester.pumpWidget(_screen(const SanctuaryScreen()));
      await tester.pumpAndSettle();
      expect(find.text('SANTUARIO DEL AZUFRE'), findsOneWidget);
      expect(find.text('DESCENDER A LA GRIETA'), findsOneWidget);
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
}

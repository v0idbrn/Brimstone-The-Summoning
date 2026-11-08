import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:brimstone_summoning/data/database/database_helper.dart';
import 'package:brimstone_summoning/data/repositories/player_repository.dart';
import 'package:brimstone_summoning/presentation/controllers/meta_controller.dart';

class _FakeBountyRepo extends PlayerRepository {
  _FakeBountyRepo() : super(DatabaseHelper());
  final Map<String, Map<String, Object?>> _rows = {};

  @override
  Future<List<Map<String, Object?>>> loadBounties() async {
    return _rows.values.toList();
  }

  @override
  Future<void> saveBounties(List<Map<String, Object?>> rows) async {
    for (final row in rows) {
      _rows[row['id'] as String] = Map<String, Object?>.from(row);
    }
  }

  @override
  Future<List<int>> loadProfile() async => const [500, 100, 20, 1];

  @override
  Future<void> saveProfile({
    required int gold,
    required int shards,
    required int energy,
    required int summonerLevel,
  }) async {}

  void seed(List<Map<String, Object?>> bounties) {
    for (final b in bounties) {
      _rows[b['id'] as String] = Map<String, Object?>.from(b);
    }
  }
}

Override _fakeBountyRepoOverride() =>
    playerRepositoryProvider.overrideWithValue(_FakeBountyRepo());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('BountyController — Juramentos de Azufre', () {
    late ProviderContainer container;

    void seedBounties() {
      final repo = container.read(playerRepositoryProvider) as _FakeBountyRepo;
      repo.seed([
        {
          'id': 'forge_master',
          'title': 'Maestro de la Forja',
          'description': 'Fusiona 25 esferas a Nivel 3.',
          'kind': 'merge_to_three',
          'target': 25,
          'reward_shards': 150,
          'reward_gold': 0,
          'progress': 0,
          'claimed': 0,
        },
        {
          'id': 'hawk_eye',
          'title': 'Ojo de Halcón',
          'description': 'Conecta 15 impactos críticos Bullseye.',
          'kind': 'bullseye_hits',
          'target': 15,
          'reward_shards': 150,
          'reward_gold': 0,
          'progress': 0,
          'claimed': 0,
        },
        {
          'id': 'elemental_alchemist',
          'title': 'Alquimista Elemental',
          'description': 'Detona 10 Reacciones Elementales.',
          'kind': 'reactions',
          'target': 10,
          'reward_shards': 200,
          'reward_gold': 0,
          'progress': 0,
          'claimed': 0,
        },
        {
          'id': 'spell_breaker',
          'title': 'Rompe-Hechizos',
          'description': 'Destruye 10 orbes enemigos con Counter-Flick.',
          'kind': 'counterflicks',
          'target': 10,
          'reward_shards': 0,
          'reward_gold': 300,
          'progress': 0,
          'claimed': 0,
        },
        {
          'id': 'dark_ascension',
          'title': 'Ascensión Oscura',
          'description': 'Evoluciona cualquier carta en el Altar.',
          'kind': 'evolution',
          'target': 1,
          'reward_shards': 250,
          'reward_gold': 0,
          'progress': 0,
          'claimed': 0,
        },
        {
          'id': 'rift_conqueror',
          'title': 'Conquistador de la Grieta',
          'description':
              'Completa una Incursión de Grieta venciendo al Jefe del Piso 7.',
          'kind': 'rift_clear',
          'target': 1,
          'reward_shards': 500,
          'reward_gold': 1000,
          'progress': 0,
          'claimed': 0,
        },
      ]);
    }

    setUp(() async {
      container = ProviderContainer(overrides: [_fakeBountyRepoOverride()]);
      seedBounties();
      await container.read(bountyProvider.notifier).load();
    });

    tearDown(() {
      container.dispose();
    });

    test('bounties load with all 6 missions', () async {
      final notifier = container.read(bountyProvider.notifier);
      await notifier.load();
      final state = container.read(bountyProvider);
      expect(state.bounties.length, 6);
      final ids = state.bounties.map((b) => b.id).toSet();
      expect(ids, contains('forge_master'));
      expect(ids, contains('hawk_eye'));
      expect(ids, contains('elemental_alchemist'));
      expect(ids, contains('spell_breaker'));
      expect(ids, contains('dark_ascension'));
      expect(ids, contains('rift_conqueror'));
      for (final b in state.bounties) {
        expect(b.claimed, isFalse);
        expect(b.progress, 0);
      }
    });

    test('increment raises progress toward target', () {
      final notifier = container.read(bountyProvider.notifier);
      notifier.increment('merge_to_three', amount: 5);
      final b = notifier.byId('forge_master')!;
      expect(b.progress, 5);
      expect(b.isComplete, isFalse);
      expect(b.isClaimable, isFalse);
    });

    test('reaching target makes bounty claimable', () {
      final notifier = container.read(bountyProvider.notifier);
      notifier.increment('evolution', amount: 1);
      final b = notifier.byId('dark_ascension')!;
      expect(b.progress, 1);
      expect(b.isComplete, isTrue);
      expect(b.isClaimable, isTrue);
    });

    test('claiming marks bounty as claimed', () async {
      final notifier = container.read(bountyProvider.notifier);
      notifier.increment('evolution', amount: 1);
      final ok = await notifier.claim('dark_ascension');
      expect(ok, isTrue);
      final b = notifier.byId('dark_ascension')!;
      expect(b.claimed, isTrue);
      expect(b.isClaimable, isFalse);
    });

    test('claiming incomplete bounty returns false', () async {
      final notifier = container.read(bountyProvider.notifier);
      final ok = await notifier.claim('forge_master');
      expect(ok, isFalse);
    });

    test(
      'activeBounties excludes claimed; claimableBounties only complete',
      () async {
        final notifier = container.read(bountyProvider.notifier);
        notifier.increment('evolution', amount: 1);
        final state = container.read(bountyProvider);
        expect(activeBounties(state).length, 6);
        expect(claimableBounties(state).length, 1);
        await notifier.claim('dark_ascension');
        final state2 = container.read(bountyProvider);
        expect(activeBounties(state2).length, 5);
        expect(claimableBounties(state2).length, 0);
      },
    );
  });
}

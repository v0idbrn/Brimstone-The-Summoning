import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/database_helper.dart';
import '../../data/repositories/player_repository.dart';
import '../../domain/entities/owned_card.dart';
import '../../domain/meta/meta_rules.dart';
import '../../domain/value_objects/rarity.dart';

final playerRepositoryProvider = Provider<PlayerRepository>((ref) {
  return PlayerRepository(DatabaseHelper());
});

final profileProvider = NotifierProvider<ProfileController, ProfileState>(
  ProfileController.new,
);

final collectionProvider =
    NotifierProvider<CollectionController, CollectionState>(
      CollectionController.new,
    );

/// Summoner profile currencies.
class ProfileState {
  final int gold;
  final int shards;
  final int energy;
  final int summonerLevel;
  const ProfileState({
    required this.gold,
    required this.shards,
    required this.energy,
    required this.summonerLevel,
  });
}

class ProfileController extends Notifier<ProfileState> {
  @override
  ProfileState build() =>
      const ProfileState(gold: 500, shards: 100, energy: 20, summonerLevel: 1);

  Future<void> load() async {
    final row = await ref.read(playerRepositoryProvider).loadProfile();
    state = ProfileState(
      gold: row[0],
      shards: row[1],
      energy: row[2],
      summonerLevel: row[3],
    );
  }

  Future<bool> spend({int? gold, int? shards}) async {
    final s = state;
    if ((gold != null && s.gold < gold) ||
        (shards != null && s.shards < shards)) {
      return false;
    }
    final next = ProfileState(
      gold: s.gold - (gold ?? 0),
      shards: s.shards - (shards ?? 0),
      energy: s.energy,
      summonerLevel: s.summonerLevel,
    );
    state = next;
    await _persist(next);
    return true;
  }

  Future<void> grant({int? gold, int? shards}) async {
    final s = state;
    final next = ProfileState(
      gold: s.gold + (gold ?? 0),
      shards: s.shards + (shards ?? 0),
      energy: s.energy,
      summonerLevel: s.summonerLevel,
    );
    state = next;
    await _persist(next);
  }

  Future<void> _persist(ProfileState p) => ref
      .read(playerRepositoryProvider)
      .saveProfile(
        gold: p.gold,
        shards: p.shards,
        energy: p.energy,
        summonerLevel: p.summonerLevel,
      );
}

/// Owned card collection + active squad with progression actions.
class CollectionState {
  final List<OwnedCard> owned;
  final List<int> squad;

  const CollectionState({required this.owned, required this.squad});
}

class CollectionController extends Notifier<CollectionState> {
  static final math.Random _random = math.Random();

  @override
  CollectionState build() => const CollectionState(owned: [], squad: []);

  OwnedCard _card(int instanceId) => state.owned.firstWhere(
    (c) => c.instanceId == instanceId,
    orElse: () => throw StateError('card $instanceId not found'),
  );

  Future<void> load() async {
    final repo = ref.read(playerRepositoryProvider);
    state = CollectionState(
      owned: await repo.loadCollection(),
      squad: await repo.loadSquad(),
    );
  }

  /// Adds a card to the squad if there is room and no duplicate catalogId.
  Future<bool> equip(int instanceId) async {
    if (state.squad.length >= 4) return false;
    final card = _card(instanceId);
    final duplicate = state.squad.any(
      (id) => _card(id).catalogId == card.catalogId,
    );
    if (duplicate) return false;
    final next = [...state.squad, instanceId];
    state = CollectionState(owned: state.owned, squad: next);
    await ref.read(playerRepositoryProvider).saveSquad(next);
    return true;
  }

  Future<void> unequip(int slot) async {
    final next = [...state.squad]..removeAt(slot);
    state = CollectionState(owned: state.owned, squad: next);
    await ref.read(playerRepositoryProvider).saveSquad(next);
  }

  /// +10% ATK/HP per level for 100*level gold. Returns the cost, or -1 on
  /// insufficient funds.
  Future<int> levelUp(int instanceId) async {
    final card = _card(instanceId);
    final cost = LevelUpRules.costFor(card.level);
    final ok = await ref.read(profileProvider.notifier).spend(gold: cost);
    if (!ok) return -1;
    final updated = card.copyWith(level: card.level + 1);
    state = CollectionState(
      owned: [
        for (final c in state.owned)
          if (c.instanceId == instanceId) updated else c,
      ],
      squad: state.squad,
    );
    await ref.read(playerRepositoryProvider).updateOwnedCard(updated);
    return cost;
  }

  /// Evolves by sacrificing a duplicate copy of the same catalogId & stars:
  /// stars+1, ATK/HP x1.35, min 4 stars cap. False if cannot evolve.
  Future<bool> evolve(int instanceId) async {
    final card = _card(instanceId);
    final duplicates = [
      for (final c in state.owned)
        if (c.instanceId != instanceId) CardIdentifier(c.catalogId, c.stars),
    ];
    if (!EvolutionRules.canEvolve(
      stars: card.stars,
      catalogId: card.catalogId,
      duplicates: duplicates,
    )) {
      return false;
    }
    final cost = EvolutionRules.costFor(card.stars);
    final ok = await ref.read(profileProvider.notifier).spend(gold: cost);
    if (!ok) return false;
    final sacrifice = state.owned.firstWhere(
      (c) =>
          c.instanceId != instanceId &&
          c.catalogId == card.catalogId &&
          c.stars == card.stars,
    );
    await ref
        .read(playerRepositoryProvider)
        .deleteOwnedCard(sacrifice.instanceId);
    final evolved = card.copyWith(
      stars: card.stars + 1,
      attack: (card.baseAttack * 1.35).round(),
      health: (card.baseHealth * 1.35).round(),
    );
    state = CollectionState(
      owned: [
        for (final c in state.owned)
          if (c.instanceId != sacrifice.instanceId)
            c.instanceId == instanceId ? evolved : c,
      ],
      squad: state.squad,
    );
    await ref.read(playerRepositoryProvider).updateOwnedCard(evolved);
    return true;
  }

  /// Portal gacha. Pacto Menor: 100 shards (fallback 500 gold) for 1 card.
  /// Gran Ritual: 450 shards for 5 cards, at least one epic-or-better.
  Future<List<OwnedCard>?> summon({required bool grandRitual}) async {
    final profile = ref.read(profileProvider.notifier);
    if (grandRitual) {
      if (!await profile.spend(shards: 450)) return null;
    } else {
      if (!await profile.spend(shards: 100) &&
          !await profile.spend(gold: 500)) {
        return null;
      }
    }
    final repo = ref.read(playerRepositoryProvider);
    final summoned = <OwnedCard>[];
    if (grandRitual) {
      final rarities = SummonService().rollGrandRitual(_random, 5);
      for (final rarity in rarities) {
        summoned.add(await repo.insertSummonedCard(_catalogFor(rarity)));
      }
    } else {
      summoned.add(
        await repo.insertSummonedCard(
          _catalogFor(SummonService().rollRarity(_random)),
        ),
      );
    }
    state = CollectionState(
      owned: [...summoned, ...state.owned],
      squad: state.squad,
    );
    return summoned;
  }
}

/// Picks a concrete card id matching the rolled rarity.
String _catalogFor(Rarity r) => switch (r) {
  Rarity.mythic => ['void_malakor', 'abyss_leviathan'],
  Rarity.legendary => ['abyss_leviathan', 'void_malakor'],
  Rarity.epic => ['ignis_lord', 'terra_titan', 'void_specter'],
  Rarity.rare => ['void_specter', 'terra_golem'],
  Rarity.common => ['ignis_hound', 'abyss_stalker', 'terra_golem'],
}.first;

// =========================================================================
// Bounties (Juramentos de Azufre)
// =========================================================================

/// A single bounty mission tracked in SQLite.
class Bounty {
  final String id;
  final String title;
  final String description;
  final String kind; // merge_to_three | bullseye_hits | reactions | counterflicks | evolution | rift_clear
  final int target;
  final int rewardShards;
  final int rewardGold;
  int progress;
  bool claimed;

  Bounty({
    required this.id,
    required this.title,
    required this.description,
    required this.kind,
    required this.target,
    required this.rewardShards,
    required this.rewardGold,
    this.progress = 0,
    this.claimed = false,
  });

  Bounty copyWith({int? progress, bool? claimed}) {
    return Bounty(
      id: id,
      title: title,
      description: description,
      kind: kind,
      target: target,
      rewardShards: rewardShards,
      rewardGold: rewardGold,
      progress: progress ?? this.progress,
      claimed: claimed ?? this.claimed,
    );
  }

  bool get isComplete => progress >= target;
  bool get isClaimable => isComplete && !claimed;
}

class BountyState {
  final List<Bounty> bounties;
  const BountyState({this.bounties = const []});
}

class BountyController extends Notifier<BountyState> {
  @override
  BountyState build() => const BountyState();

  Future<void> load() async {
    final repo = ref.read(playerRepositoryProvider);
    final rows = await repo.loadBounties();
    final bounties = rows
        .map(
          (r) => Bounty(
            id: r['id'] as String,
            title: r['title'] as String,
            description: r['description'] as String,
            kind: r['kind'] as String,
            target: r['target'] as int,
            rewardShards: r['reward_shards'] as int,
            rewardGold: r['reward_gold'] as int,
            progress: r['progress'] as int,
            claimed: (r['claimed'] as int) == 1,
          ),
        )
        .toList();
    state = BountyState(bounties: bounties);
  }

  /// Records progress for a bounty of [kind]. Call from combat/meta screens.
  void increment(String kind, {int amount = 1}) {
    final next = <Bounty>[];
    for (final b in state.bounties) {
      if (b.kind == kind && !b.claimed) {
        next.add(b.copyWith(progress: b.progress + amount));
      } else {
        next.add(b);
      }
    }
    state = BountyState(bounties: next);
    ref
        .read(playerRepositoryProvider)
        .saveBounties(
          next
              .map(
                (b) => <String, Object?>{
                  'id': b.id,
                  'progress': b.progress,
                  'claimed': b.claimed ? 1 : 0,
                },
              )
              .toList(),
        );
  }

  /// Claims [id] if complete, granting shards and gold to the profile.
  Future<bool> claim(String id) async {
    final b = state.bounties.firstWhere(
      (x) => x.id == id,
      orElse: () => throw StateError('bounty $id not found'),
    );
    if (!b.isClaimable) return false;
    final profile = ref.read(profileProvider.notifier);
    await profile.grant(gold: b.rewardGold, shards: b.rewardShards);
    final next = <Bounty>[];
    for (final x in state.bounties) {
      if (x.id == id) {
        next.add(x.copyWith(claimed: true));
      } else {
        next.add(x);
      }
    }
    state = BountyState(bounties: next);
    ref
        .read(playerRepositoryProvider)
        .saveBounties(
          next
              .map(
                (b) => <String, Object?>{
                  'id': b.id,
                  'progress': b.progress,
                  'claimed': b.claimed ? 1 : 0,
                },
              )
              .toList(),
        );
    return true;
  }

  Bounty? byId(String id) =>
      state.bounties.where((x) => x.id == id).firstOrNull;
}

final bountyProvider = NotifierProvider<BountyController, BountyState>(
  BountyController.new,
);

/// Convenience: bounties grouped by claimable status.
List<Bounty> claimableBounties(BountyState s) =>
    s.bounties.where((b) => b.isClaimable).toList();

List<Bounty> activeBounties(BountyState s) =>
    s.bounties.where((b) => !b.claimed).toList();

// =========================================================================
// Codex reactions (detonation history)
// =========================================================================

class CodexReaction {
  final String id;
  final String name;
  final String description;
  final String trigger;
  int detonations;

  CodexReaction({
    required this.id,
    required this.name,
    required this.description,
    required this.trigger,
    this.detonations = 0,
  });

  CodexReaction copyWith({int? detonations}) {
    return CodexReaction(
      id: id,
      name: name,
      description: description,
      trigger: trigger,
      detonations: detonations ?? this.detonations,
    );
  }
}

final codexReactionsProvider = Provider<List<CodexReaction>>((ref) {
  return [
    CodexReaction(
      id: 'erupcion_magmatica',
      name: 'Erupción Magmática',
      description: 'Ígnea + Abyssal: daño en área a todas las dianas y explosión de fuego.',
      trigger: 'Aura Ígnea + impacto Abyssal',
    ),
    CodexReaction(
      id: 'choque_termico',
      name: 'Choque Térmico',
      description:
          'Abyssal + Telluric: restaura maná a todas las cartas y sobrecarga.',
      trigger: 'Aura Abyssal + impacto Telúrico',
    ),
    CodexReaction(
      id: 'petrificacion_abisal',
      name: 'Petrificación Abisal',
      description:
          'Telluric + Void: congela las dianas y retrasa el ataque del jefe.',
      trigger: 'Aura Telúrica + impacto Vacío',
    ),
    CodexReaction(
      id: 'colapso_del_sello',
      name: 'Colapso del Sello',
      description: 'Void + Igneous: cura al jugador y deja al jefe vulnerable.',
      trigger: 'Aura Vacío + impacto Ígneo',
    ),
  ];
});

/// Records a reaction detonation in the codex (called from CombatScreen).
void recordCodexReaction(WidgetRef ref, String name) {
  // The codex list is static; detonation counts live in the DB via the repo.
  ref.read(playerRepositoryProvider).incrementCodexReaction(name);
}

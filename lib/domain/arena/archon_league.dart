import 'dart:math' as math;

import '../value_objects/element.dart';

/// Competitive divisions of the Archon Colosseum.
enum ArchonLeague {
  ceniza('CENIZA', 0),
  hierro('HIERRO', 300),
  bronce('BRONCE', 700),
  plata('PLATA', 1200),
  oroImperial('ORO IMPERIAL', 1800),
  granArconte('GRAN ARCONTE ABISAL', 2600);

  const ArchonLeague(this.label, this.minTrophies);

  final String label;
  final int minTrophies;

  bool get isTop => index == ArchonLeague.values.length - 1;

  /// Player-facing crest colour (hex), consumed by the UI painters.
  int get emblemColor => switch (this) {
        ArchonLeague.ceniza => 0xFF8A7A6A,
        ArchonLeague.hierro => 0xFF9FA8B4,
        ArchonLeague.bronce => 0xFFC87F42,
        ArchonLeague.plata => 0xFFD9E2EC,
        ArchonLeague.oroImperial => 0xFFE7BE5A,
        ArchonLeague.granArconte => 0xFFB16EFF,
      };
}

/// Pure trophy maths: division lookup, ladder progress and demotion floor.
class ArchonRanking {
  const ArchonRanking._();

  static ArchonLeague leagueFor(int trophies) {
    var league = ArchonLeague.ceniza;
    for (final candidate in ArchonLeague.values) {
      if (trophies >= candidate.minTrophies) league = candidate;
    }
    return league;
  }

  /// Trophies required for the next division, or null at the apex.
  static int? nextThreshold(int trophies) {
    for (final league in ArchonLeague.values) {
      if (trophies < league.minTrophies) return league.minTrophies;
    }
    return null;
  }

  /// 0→1 progress inside the current division (1 at the apex).
  static double progressToNext(int trophies) {
    final current = leagueFor(trophies);
    final next = nextThreshold(trophies);
    if (next == null) return 1.0;
    final span = next - current.minTrophies;
    if (span <= 0) return 1.0;
    return ((trophies - current.minTrophies) / span).clamp(0.0, 1.0);
  }

  /// Trophies lost on a loss: 12, never dropping below the armoured floor of
  /// the division reached (so a bad streak cannot erase a whole league).
  static int trophiesAfterLoss(int trophies) {
    final league = leagueFor(trophies);
    return math.max(league.minTrophies, trophies - 12);
  }
}

/// Difficulty of a colosseum duel and its trophy payout.
enum ArchonDuelTier {
  facil('FÁCIL', 45, 0.85),
  parejo('PAREJO', 85, 1.0),
  desafio('DESAFÍO SUPERIOR', 140, 1.18);

  const ArchonDuelTier(this.label, this.points, this.powerScale);

  final String label;
  final int points;
  final double powerScale;
}

/// Projection of one rival card, enough for a [TcgCardWidget].
class ArchonCard {
  const ArchonCard({
    required this.catalogId,
    required this.name,
    required this.element,
    required this.stars,
  });

  final String catalogId;
  final String name;
  final Element element;
  final int stars;
}

/// A procedurally generated rival archon.
class ArchonRival {
  const ArchonRival({
    required this.name,
    required this.title,
    required this.tier,
    required this.cards,
    required this.targetScore,
  });

  final String name;
  final String title;
  final ArchonDuelTier tier;
  final List<ArchonCard> cards;

  /// Damage the rival scores in 45 s: beat it to win the duel.
  final int targetScore;

  int get pointsAtStake => tier.points;

  /// Total PWR shown on the challenge card.
  int get power => cards.fold<int>(
        0,
        (sum, card) => sum + 140 + card.stars * 260,
      );
}

/// Deterministic rival generator: the same seed always shows the same board.
class ArchonDuelGenerator {
  const ArchonDuelGenerator._();

  static const List<ArchonCard> _roster = [
    ArchonCard(
      catalogId: 'ignis_colossus',
      name: 'Vulcanor, Rey del Cráter',
      element: Element.igneous,
      stars: 4,
    ),
    ArchonCard(
      catalogId: 'abyss_leviathan',
      name: 'Leviatán del Foso',
      element: Element.abyssal,
      stars: 4,
    ),
    ArchonCard(
      catalogId: 'terra_behemoth',
      name: 'Behemot Rompecumbres',
      element: Element.telluric,
      stars: 4,
    ),
    ArchonCard(
      catalogId: 'void_archon',
      name: 'Arconte del Vacío',
      element: Element.empty,
      stars: 4,
    ),
    ArchonCard(
      catalogId: 'ignis_seraph',
      name: 'Serafín Carbonizado',
      element: Element.igneous,
      stars: 3,
    ),
    ArchonCard(
      catalogId: 'abyss_wraith',
      name: 'Espectro Glacial',
      element: Element.abyssal,
      stars: 3,
    ),
    ArchonCard(
      catalogId: 'terra_hydra',
      name: 'Hidra de Raíz Pétrea',
      element: Element.telluric,
      stars: 3,
    ),
    ArchonCard(
      catalogId: 'void_oracle',
      name: 'Oráculo del Eclipse',
      element: Element.empty,
      stars: 3,
    ),
    ArchonCard(
      catalogId: 'ignis_drake',
      name: 'Draco de Escoria',
      element: Element.igneous,
      stars: 2,
    ),
    ArchonCard(
      catalogId: 'abyss_kraken',
      name: 'Kraken de la Fosa',
      element: Element.abyssal,
      stars: 3,
    ),
    ArchonCard(
      catalogId: 'terra_warden',
      name: 'Guardián de Obsidiana',
      element: Element.telluric,
      stars: 2,
    ),
    ArchonCard(
      catalogId: 'void_reaper',
      name: 'Segador Astral',
      element: Element.empty,
      stars: 2,
    ),
  ];

  static const List<String> _names = [
    'Malakor',
    'Nyxara',
    'Gorgath',
    'Vexarian',
    'Seraphine',
    'Thal-Gor',
    'Ilyandra',
    'Vorlag',
    'Ashkarel',
    'Morgrave',
  ];

  static const List<String> _titles = [
    'VERDUGO DE CENIZA',
    'SEÑOR DE LA FOSA',
    'CUSTODIO DEL MONOLITO',
    'HERALDO DEL ECLIPSE',
    'PORTADOR DEL SELLO ROTO',
    'TIRANO DE LAS SIETE GRIETAS',
  ];

  /// Builds the three rivals offered in the lobby for a given trophy count.
  static List<ArchonRival> generate({
    required math.Random random,
    required int trophies,
  }) =>
      [
        for (final tier in ArchonDuelTier.values)
          _rival(random: random, trophies: trophies, tier: tier),
      ];

  static ArchonRival _rival({
    required math.Random random,
    required int trophies,
    required ArchonDuelTier tier,
  }) {
    final cards = <ArchonCard>[];
    final used = <String>{};
    while (cards.length < 4) {
      final pick = _roster[random.nextInt(_roster.length)];
      if (!used.add(pick.catalogId)) continue;
      cards.add(pick);
    }
    final base = 520 + (trophies * 0.42).round() + tier.points * 2;
    final jitter = random.nextInt(80) - 30;
    final target = (((base + jitter) * tier.powerScale) / 10).round() * 10;
    return ArchonRival(
      name: _names[random.nextInt(_names.length)],
      title: _titles[random.nextInt(_titles.length)],
      tier: tier,
      cards: List<ArchonCard>.unmodifiable(cards),
      targetScore: math.max(120, target),
    );
  }
}

/// Ascension chest contents.
class ArchonRewards {
  const ArchonRewards({
    required this.shards,
    required this.gold,
    required this.trophies,
    required this.goldenCardChance,
  });

  final int shards;
  final int gold;
  final int trophies;
  final double goldenCardChance;

  bool get hasGoldenCard => goldenCardChance >= 0.5;
}

/// Trophy ledger persisted in SQLite (v9).
class ArchonProgress {
  const ArchonProgress({
    this.trophies = 0,
    this.wins = 0,
    this.losses = 0,
    this.streak = 0,
    this.bestStreak = 0,
  });

  final int trophies;
  final int wins;
  final int losses;
  final int streak;
  final int bestStreak;

  ArchonLeague get league => ArchonRanking.leagueFor(trophies);

  ArchonProgress recordWin({required ArchonDuelTier tier, required int bonus}) {
    final gained = tier.points + math.min(streak, 5) * 5 + bonus;
    final nextStreak = streak + 1;
    return ArchonProgress(
      trophies: trophies + gained,
      wins: wins + 1,
      losses: losses,
      streak: nextStreak,
      bestStreak: math.max(bestStreak, nextStreak),
    );
  }

  ArchonProgress recordLoss() => ArchonProgress(
        trophies: ArchonRanking.trophiesAfterLoss(trophies),
        wins: wins,
        losses: losses + 1,
        streak: 0,
        bestStreak: bestStreak,
      );

  ArchonProgress copyWith({
    int? trophies,
    int? wins,
    int? losses,
    int? streak,
    int? bestStreak,
  }) =>
      ArchonProgress(
        trophies: trophies ?? this.trophies,
        wins: wins ?? this.wins,
        losses: losses ?? this.losses,
        streak: streak ?? this.streak,
        bestStreak: bestStreak ?? this.bestStreak,
      );

  static const ArchonProgress empty = ArchonProgress();

  /// Chest rewards scale with division and difficulty.
  ArchonRewards rewardsFor(ArchonDuelTier tier) {
    final leagueIndex = league.index;
    return ArchonRewards(
      shards: 140 + tier.points * 3 + leagueIndex * 90,
      gold: 220 + tier.points * 4 + leagueIndex * 120,
      trophies: tier.points,
      goldenCardChance: 0.15 + leagueIndex * 0.10 + tier.powerScale * 0.10,
    );
  }
}

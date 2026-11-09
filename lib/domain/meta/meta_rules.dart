import 'dart:math' as math;

import '../value_objects/rarity.dart';
import '../value_objects/element.dart';

/// Rarity weights for the summoning portal (Pacto Menor / Gran Ritual).
class SummonService {
  static const double epicFloor = 1.0; // at least 1 epic in a grand ritual

  Rarity rollRarity(math.Random random) {
    final roll = random.nextInt(100) + 1; // 1..100
    if (roll <= 8) return Rarity.mythic; // 8%
    if (roll <= 25) return Rarity.legendary; // 17%
    if (roll <= 42) return Rarity.epic; // 17%
    if (roll <= 67) return Rarity.rare; // 25%
    return Rarity.common; // 33%
  }

  /// Grand Ritual guarantee: at least one epic or legendary in a 5-pull.
  List<Rarity> rollGrandRitual(math.Random random, int count) {
    final results = [for (var i = 0; i < count; i++) rollRarity(random)];
    final hasHigh = results.any(
      (r) => r == Rarity.epic || r == Rarity.legendary || r == Rarity.mythic,
    );
    if (!hasHigh) results[results.length - 1] = Rarity.epic;
    return results;
  }

  /// Returns a catalog ID for the given rarity and banner.
  /// Banner 'general' = all elements.
  /// Elemental banners = 60% chance for featured element, 40% for others.
  String catalogFor(Rarity rarity,
      {String banner = 'general', math.Random? random}) {
    final rnd = random ?? math.Random();
    final allCards = _catalogFor(rarity);
    if (banner == 'general') {
      return allCards.first;
    }

    // Elemental banner: 60% featured element, 40% others.
    final featuredElement = _bannerToElement(banner);
    if (featuredElement == null) {
      return allCards[rnd.nextInt(allCards.length)];
    }

    final featured = allCards
        .where((id) => _elementForCatalog(id) == featuredElement)
        .toList();
    final others = allCards
        .where((id) => _elementForCatalog(id) != featuredElement)
        .toList();

    if (rnd.nextDouble() < 0.6 && featured.isNotEmpty) {
      return featured[rnd.nextInt(featured.length)];
    }
    return others.isNotEmpty
        ? others[rnd.nextInt(others.length)]
        : allCards[rnd.nextInt(allCards.length)];
  }

  Element? _bannerToElement(String banner) => switch (banner) {
        'igneous' => Element.igneous,
        'abyssal' => Element.abyssal,
        'telluric' => Element.telluric,
        'void' => Element.empty,
        _ => null,
      };

  Element _elementForCatalog(String catalogId) {
    // Map catalog IDs to elements.
    if (catalogId.startsWith('ignis_')) return Element.igneous;
    if (catalogId.startsWith('abyss_')) return Element.abyssal;
    if (catalogId.startsWith('terra_')) return Element.telluric;
    if (catalogId.startsWith('void_')) return Element.empty;
    if (catalogId.startsWith('malakor')) return Element.empty;
    if (catalogId.startsWith('leviathan')) return Element.abyssal;
    if (catalogId.startsWith('colossus')) return Element.igneous;
    if (catalogId.startsWith('behemoth')) return Element.telluric;
    if (catalogId.startsWith('archon')) return Element.empty;
    if (catalogId.startsWith('wraith')) return Element.abyssal;
    if (catalogId.startsWith('seraph')) return Element.igneous;
    if (catalogId.startsWith('kraken')) return Element.abyssal;
    if (catalogId.startsWith('hydra')) return Element.telluric;
    if (catalogId.startsWith('oracle')) return Element.empty;
    if (catalogId.startsWith('lord')) return Element.igneous;
    if (catalogId.startsWith('titan')) return Element.telluric;
    if (catalogId.startsWith('reaper')) return Element.empty;
    if (catalogId.startsWith('warden')) return Element.telluric;
    if (catalogId.startsWith('siren')) return Element.abyssal;
    if (catalogId.startsWith('drake')) return Element.igneous;
    if (catalogId.startsWith('hound')) return Element.igneous;
    if (catalogId.startsWith('stalker')) return Element.abyssal;
    if (catalogId.startsWith('golem')) return Element.telluric;
    if (catalogId.startsWith('specter')) return Element.empty;
    return Element.igneous;
  }

  List<String> _catalogFor(Rarity r) => switch (r) {
        Rarity.mythic => ['void_malakor', 'abyss_leviathan'],
        Rarity.legendary => [
            'abyss_leviathan',
            'void_malakor',
            'ignis_colossus',
            'abyss_wraith',
            'terra_behemoth',
            'void_archon',
          ],
        Rarity.epic => [
            'ignis_lord',
            'terra_titan',
            'void_specter',
            'ignis_seraph',
            'abyss_kraken',
            'terra_hydra',
            'void_oracle',
          ],
        Rarity.rare => [
            'void_specter',
            'terra_golem',
            'ignis_drake',
            'abyss_siren',
            'terra_warden',
            'void_reaper',
          ],
        Rarity.common => ['ignis_hound', 'abyss_stalker', 'terra_golem'],
      };
}

/// evolution rules: 1★ -> 4★ sacrificing a duplicate catalogId & stars.
class EvolutionRules {
  static const int maxStars = 4;

  /// Gold cost ascending stars: 250*stars.
  static int costFor(int stars) => 250 * stars;

  static bool canEvolve({
    required int stars,
    required String catalogId,
    required List<CardIdentifier> duplicates,
  }) {
    if (stars >= maxStars) return false;
    return duplicates.any((d) => d.catalogId == catalogId && d.stars == stars);
  }
}

/// Lightweight identity projection consumed by the rules above.
class CardIdentifier {
  final String catalogId;
  final int stars;
  const CardIdentifier(this.catalogId, this.stars);
}

/// Level-up rules: +10% ATK/HP per level, gold cost 100*level.
class LevelUpRules {
  static int costFor(int level) => 100 * level;

  static int statAfter(int baseStat, int level) =>
      (baseStat * math.pow(1.10, level - 1)).round();
}

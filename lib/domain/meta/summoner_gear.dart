/// Equipamiento permanente del Invocador: 3 piezas forjables de Nivel 1 a 5.
library;

enum GearStat {
  auraDuration,
  bullseyeRadius,
  lifeRegenBetweenFloors,
}

/// Coste de forja o mejora de una pieza.
class GearCost {
  final int gold;
  final int shards;

  const GearCost({required this.gold, required this.shards});

  @override
  bool operator ==(Object other) =>
      other is GearCost && other.gold == gold && other.shards == shards;

  @override
  int get hashCode => Object.hash(gold, shards);
}

class SummonerGearPiece {
  final String id;
  final String name;
  final String description;
  final GearStat stat;
  final double baseValue;
  final double perLevel;

  const SummonerGearPiece({
    required this.id,
    required this.name,
    required this.description,
    required this.stat,
    required this.baseValue,
    required this.perLevel,
  });

  /// Valor de la pieza al [level] indicado (1..[SummonerGearRules.maxLevel]).
  double valueAt(int level) {
    if (level <= 0) return 0.0;
    final capped =
        level > SummonerGearRules.maxLevel ? SummonerGearRules.maxLevel : level;
    return baseValue + perLevel * (capped - 1);
  }

  /// Porcentaje legible a un nivel dado (por ejemplo +30%).
  String labelAt(int level) {
    final percent = ((valueAt(level) -
                (stat == GearStat.auraDuration ||
                        stat == GearStat.bullseyeRadius
                    ? 1.0
                    : 0.0)) *
            100)
        .round();
    return percent >= 0 ? '+$percent%' : '$percent%';
  }
}

class SummonerGearRules {
  static const int maxLevel = 5;
  static const int baseGoldCost = 300;
  static const int baseShardCost = 90;

  static const List<SummonerGearPiece> allGear = [
    SummonerGearPiece(
      id: 'yelmo_abisal',
      name: 'Yelmo Abisal',
      description: 'Mejora la duración de las Auras Elementales',
      stat: GearStat.auraDuration,
      baseValue: 1.0,
      perLevel: 0.15, // +15% duración por nivel
    ),
    SummonerGearPiece(
      id: 'guanteletes_lanzamiento',
      name: 'Guanteletes de Lanzamiento',
      description: 'Aumenta el radio del Bullseye crítico',
      stat: GearStat.bullseyeRadius,
      baseValue: 1.0,
      perLevel: 0.10, // +10% radio por nivel
    ),
    SummonerGearPiece(
      id: 'amuleto_sello',
      name: 'Amuleto del Sello',
      description: 'Regenera vida entre pisos de la Grieta',
      stat: GearStat.lifeRegenBetweenFloors,
      baseValue: 0.0,
      perLevel: 0.05, // +5% HP máximo por piso
    ),
  ];

  /// Coste para forjar (currentLevel == 0) o mejorar la pieza.
  static GearCost? costFor(String gearId, int currentLevel) {
    if (byId(gearId) == null) return null;
    if (currentLevel >= maxLevel) return null;
    final next = currentLevel <= 0 ? 1 : currentLevel + 1;
    return GearCost(
      gold: baseGoldCost * next,
      shards: baseShardCost * next,
    );
  }

  static SummonerGearPiece? byId(String id) {
    for (final g in allGear) {
      if (g.id == id) return g;
    }
    return null;
  }
}

/// Equipamiento activo del jugador (gearId → nivel, 0/ausente = no forjado).
class GearLoadout {
  final Map<String, int> levels;

  const GearLoadout([this.levels = const {}]);

  int levelOf(String gearId) {
    final value = levels[gearId] ?? 0;
    if (value < 0) return 0;
    return value > SummonerGearRules.maxLevel
        ? SummonerGearRules.maxLevel
        : value;
  }

  /// Multiplicador de duración de aura (Yelmo Abisal).
  double get auraDurationMult {
    final piece = SummonerGearRules.byId('yelmo_abisal');
    final level = levelOf('yelmo_abisal');
    return level <= 0 ? 1.0 : piece!.valueAt(level);
  }

  /// Multiplicador del radio de Bullseye (Guanteletes de Lanzamiento).
  double get bullseyeRadiusMult {
    final piece = SummonerGearRules.byId('guanteletes_lanzamiento');
    final level = levelOf('guanteletes_lanzamiento');
    return level <= 0 ? 1.0 : piece!.valueAt(level);
  }

  /// Fracción de vida máxima regenerada al pasar de piso (Amuleto del Sello).
  double get lifeRegenFraction {
    final piece = SummonerGearRules.byId('amuleto_sello');
    final level = levelOf('amuleto_sello');
    return level <= 0 ? 0.0 : piece!.valueAt(level);
  }

  bool get hasAny => levels.values.any((l) => l > 0);

  GearLoadout withLevel(String gearId, int level) {
    final capped = level.clamp(0, SummonerGearRules.maxLevel);
    return GearLoadout({...levels, gearId: capped});
  }
}

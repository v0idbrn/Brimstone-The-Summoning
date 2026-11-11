import 'dart:math' as math;

/// Tipo de Runa Abisal equipable en una carta (Nivel 1 a 5).
enum RuneType { crimsonFury, eternalFlow, voidLeech, twinEcho }

/// Una runa equipada en una instancia de carta propia, con su nivel de mejora.
class RuneInstance {
  final RuneType type;
  int level;

  RuneInstance({required this.type, this.level = 1});

  bool get isMaxLevel => level >= 5;

  RuneInstance copyWith({RuneType? type, int? level}) =>
      RuneInstance(type: type ?? this.type, level: level ?? this.level);
}

/// Efectos numéricos de cada runa por nivel. Dominio puro, sin Flutter.
class RuneSystem {
  static const int maxLevel = 5;

  /// Costo en esquirlas para forjar una runa nueva (Nivel 1).
  /// Base cost varies by type.
  static int forgeCost(RuneType type) => switch (type) {
        RuneType.crimsonFury => 200,
        RuneType.eternalFlow => 200,
        RuneType.voidLeech => 250,
        RuneType.twinEcho => 300,
      };

  /// Costo en esquirlas para subir la runa al siguiente nivel.
  static int upgradeCost(RuneInstance rune) {
    if (rune.level >= maxLevel) return 0;
    final baseCost = forgeCost(rune.type);
    return baseCost * rune.level; // Increases each level
  }

  /// Costo en oro para forjar/subir la runa al siguiente nivel (legacy).
  static int goldCost(int currentLevel) => 100 * currentLevel;

  /// Costo en esquirlas para forjar/subir la runa al siguiente nivel (legacy).
  static int shardCost(int currentLevel) => 25 * currentLevel;

  /// Multiplicador de ATK de la carta equipada (crimson_fury): +12% por nivel.
  static double atkMult(RuneType type, int level) {
    if (type != RuneType.crimsonFury) return 1.0;
    return 1.0 + 0.12 * level; // 1.12 .. 1.60
  }

  /// Reducción fraccional del costo máximo de maná (eternal_flow): -5% por nivel.
  static double manaCostReduction(RuneType type, int level) {
    if (type != RuneType.eternalFlow) return 0.0;
    return 0.05 * level; // 0.05 .. 0.25
  }

  /// Cura al jugador como fracción de su HP máximo al activar la habilidad
  /// (void_leech): 3% por nivel.
  static double healOnSkill(RuneType type, int level) {
    if (type != RuneType.voidLeech) return 0.0;
    return 0.03 * level; // 0.03 .. 0.15
  }

  /// Probabilidad de que la habilidad se dispare dos veces sin costo extra
  /// (twin_echo): 8% por nivel.
  static double doubleCastChance(RuneType type, int level) {
    if (type != RuneType.twinEcho) return 0.0;
    return 0.08 * level; // 0.08 .. 0.40
  }

  /// Nombre de display de cada tipo de runa.
  static String displayName(RuneType type) => switch (type) {
        RuneType.crimsonFury => 'Runa de Furia Carmesí',
        RuneType.eternalFlow => 'Runa de Flujo Eterno',
        RuneType.voidLeech => 'Runa de Vampirismo Abisal',
        RuneType.twinEcho => 'Runa de Eco Gemelo',
      };

  /// Descripción de efecto de cada tipo de runa.
  static String description(RuneType type, int level) => switch (type) {
        RuneType.crimsonFury =>
          '+${(0.12 * level * 100).round()}% ATK de la carta equipada.',
        RuneType.eternalFlow =>
          '-${(0.05 * level * 100).round()}% costo de maná de la habilidad.',
        RuneType.voidLeech =>
          'Curar ${(0.03 * level * 100).round()}% HP máximo al activar la habilidad.',
        RuneType.twinEcho =>
          '${(0.08 * level * 100).round()}% probabilidad de doble disparo de habilidad sin costo.',
      };

  /// Color value (ARGB int) asociado a cada tipo de runa.
  static int runeColorValue(RuneType type) => switch (type) {
        RuneType.crimsonFury => 0xFFD32F2F,
        RuneType.eternalFlow => 0xFF00BCD4,
        RuneType.voidLeech => 0xFF7B1FA2,
        RuneType.twinEcho => 0xFFFFC107,
      };

  /// Icon name asociado a cada tipo de runa.
  static String runeIconName(RuneType type) => switch (type) {
        RuneType.crimsonFury => 'local_fire_department',
        RuneType.eternalFlow => 'waves',
        RuneType.voidLeech => 'bloodtype',
        RuneType.twinEcho => 'compare_arrows',
      };

  /// Descripción de efecto de cada tipo de runa (alias for description).
  static String runeDescription(RuneType type, [int level = 1]) =>
      description(type, level);
}

/// ═══════════════════════════════════════════════════════════════════════════
/// SUB-STATS SYSTEM (Pilar 6) — Reforja Mística de Runas Nv.5
/// ═══════════════════════════════════════════════════════════════════════════

/// Sub-estadística aleatoria que puede encantar una Runa Nv.5
enum RuneSubstat {
  bullseyeCritChance, // Crítico Bullseye +8%
  traySpeed, // Velocidad de Bandeja +10%
  startingMana, // Maná Inicial +12
  shieldDamage, // Daño a Escudos +20%
  lifesteal, // Robo de Vida +4%
}

extension RuneSubstatMeta on RuneSubstat {
  String get label => switch (this) {
        RuneSubstat.bullseyeCritChance => 'Crítico Bullseye',
        RuneSubstat.traySpeed => 'Vel. Bandeja',
        RuneSubstat.startingMana => 'Maná Inicial',
        RuneSubstat.shieldDamage => 'Daño a Escudos',
        RuneSubstat.lifesteal => 'Robo de Vida',
      };

  String get valueFormat => switch (this) {
        RuneSubstat.bullseyeCritChance => '+{value}%',
        RuneSubstat.traySpeed => '+{value}%',
        RuneSubstat.startingMana => '+{value}',
        RuneSubstat.shieldDamage => '+{value}%',
        RuneSubstat.lifesteal => '+{value}%',
      };

  double get baseValue => switch (this) {
        RuneSubstat.bullseyeCritChance => 0.08, // 8%
        RuneSubstat.traySpeed => 0.10, // 10%
        RuneSubstat.startingMana => 12.0,
        RuneSubstat.shieldDamage => 0.20, // 20%
        RuneSubstat.lifesteal => 0.04, // 4%
      };

  int runeColorValue() => switch (this) {
        RuneSubstat.bullseyeCritChance => 0xFFFFD700,
        RuneSubstat.traySpeed => 0xFF00E676,
        RuneSubstat.startingMana => 0xFF29B6F6,
        RuneSubstat.shieldDamage => 0xFFFF5A26,
        RuneSubstat.lifesteal => 0xFFE91E63,
      };
}

/// Una sub-estadística encanjada en una runa (con su valor).
class EnchantedSubstat {
  final RuneSubstat type;
  final double value; // Valor final (puede variar ligeramente por RNG)

  const EnchantedSubstat({required this.type, required this.value});

  String formattedValue() => type.valueFormat.replaceAll(
      '{value}',
      type == RuneSubstat.startingMana
          ? value.round().toString()
          : (value * 100).round().toString());
}

/// Runa Nv.5 con sub-stats encanjados (máx 2).
class RuneWithSubstats {
  final RuneInstance baseRune;
  final List<EnchantedSubstat> substats; // 0-2 items

  const RuneWithSubstats({required this.baseRune, this.substats = const []});

  bool get canEnchant => baseRune.level >= 5 && substats.length < 2;
  bool get isFullyEnchanted => substats.length >= 2;

  RuneWithSubstats addSubstat(EnchantedSubstat substat) {
    if (!canEnchant) return this;
    return RuneWithSubstats(
        baseRune: baseRune, substats: [...substats, substat]);
  }

  RuneWithSubstats reforgeSubstat(int index) {
    if (index < 0 || index >= substats.length) return this;
    final current = substats[index].type;
    final others =
        RuneSubstatSystem.allSubstats.where((t) => t != current).toList();
    final type = others[math.Random().nextInt(others.length)];
    final variance = 0.9 + math.Random().nextDouble() * 0.2; // 0.9 - 1.1
    final newSubstats = [...substats];
    newSubstats[index] =
        EnchantedSubstat(type: type, value: type.baseValue * variance);
    return RuneWithSubstats(baseRune: baseRune, substats: newSubstats);
  }
}

/// Sistema de encantamiento/reforja de sub-stats (Pilar 6)
class RuneSubstatSystem {
  static const List<RuneSubstat> allSubstats = RuneSubstat.values;

  /// Genera una sub-estadística aleatoria con valor base ±10% RNG.
  static EnchantedSubstat randomSubstat() {
    final type = allSubstats[math.Random().nextInt(allSubstats.length)];
    final variance = 0.9 + math.Random().nextDouble() * 0.2; // 0.9 - 1.1
    return EnchantedSubstat(type: type, value: type.baseValue * variance);
  }

  /// Costo en esquirlas/polvo para encantar una runa Nv.5 (primera substat).
  static int enchantCost({required int currentSubstats}) {
    return [500, 1000][currentSubstats.clamp(0, 1)];
  }

  /// Costo en esquirlas/polvo para reforjar una substat existente.
  static const int reforgeCost = 750;

  /// Aplica los efectos de sub-stats a un mapa de bonos (para el motor de combate).
  static Map<String, double> applySubstats(List<EnchantedSubstat> substats) {
    final bonuses = <String, double>{};
    for (final s in substats) {
      switch (s.type) {
        case RuneSubstat.bullseyeCritChance:
          bonuses['bullseye_crit_chance'] =
              (bonuses['bullseye_crit_chance'] ?? 0) + s.value;
          break;
        case RuneSubstat.traySpeed:
          bonuses['tray_speed'] = (bonuses['tray_speed'] ?? 0) + s.value;
          break;
        case RuneSubstat.startingMana:
          bonuses['starting_mana'] = (bonuses['starting_mana'] ?? 0) + s.value;
          break;
        case RuneSubstat.shieldDamage:
          bonuses['shield_damage'] = (bonuses['shield_damage'] ?? 0) + s.value;
          break;
        case RuneSubstat.lifesteal:
          bonuses['lifesteal'] = (bonuses['lifesteal'] ?? 0) + s.value;
          break;
      }
    }
    return bonuses;
  }
}

/// ═══════════════════════════════════════════════════════════════════════════
/// SUMMONER PARAGON LEVELS 1-100 (Pilar 6)
/// ═══════════════════════════════════════════════════════════════════════════

/// Nivel de Paragón del Invocador (1-100) con recompensas por nivel.
class SummonerParagon {
  static const int maxLevel = 100;
  static const int baseXpPerLevel = 1000; // XP base, escala cuadrática

  /// XP total requerido para alcanzar un nivel dado (fórmula cuadrática suave).
  static int xpForLevel(int level) {
    if (level <= 1) return 0;
    // Fórmula: base * (level-1)^1.5 ≈ curva suave
    return (baseXpPerLevel * math.pow(level - 1, 1.5)).round();
  }

  /// XP total acumulado para llegar al nivel.
  static int totalXpForLevel(int level) {
    int total = 0;
    for (int i = 2; i <= level; i++) {
      total += xpForLevel(i);
    }
    return total;
  }

  /// Calcula el nivel actual dado XP total.
  static int levelFromXp(int totalXp) {
    int level = 1;
    while (level < maxLevel && totalXpForLevel(level + 1) <= totalXp) {
      level++;
    }
    return level.clamp(1, maxLevel);
  }

  /// Recompensas por subir de nivel:
  /// - +2 Energía Máxima cada nivel
  /// - +50 Esquirlas cada nivel
  /// - Cada 10 niveles: bonos especiales
  static ParagonRewards rewardsForLevel(int level) {
    int maxEnergy = 2 * level;
    int shards = 50 * level;

    // Bonos cada 10 niveles
    int bonusEnergy = 0;
    int bonusShards = 0;
    String? specialReward;

    if (level % 10 == 0) {
      bonusEnergy = 10;
      bonusShards = 500;
      switch (level) {
        case 10:
          specialReward = 'paragon.reward.l10';
          break;
        case 20:
          specialReward = 'paragon.reward.l20';
          break;
        case 30:
          specialReward = 'paragon.reward.l30';
          break;
        case 40:
          specialReward = 'paragon.reward.l40';
          break;
        case 50:
          specialReward = 'paragon.reward.l50';
          break;
        case 60:
          specialReward = 'paragon.reward.l60';
          break;
        case 70:
          specialReward = 'paragon.reward.l70';
          break;
        case 80:
          specialReward = 'paragon.reward.l80';
          break;
        case 90:
          specialReward = 'paragon.reward.l90';
          break;
        case 100:
          specialReward = 'paragon.reward.l100';
          break;
      }
    }

    return ParagonRewards(
      maxEnergy: maxEnergy + bonusEnergy,
      totalShards: shards + bonusShards,
      specialRewardKey: specialReward,
    );
  }

  /// Progreso hacia el siguiente nivel (0.0 - 1.0).
  static double progressToNext(int totalXp) {
    final level = levelFromXp(totalXp);
    if (level >= maxLevel) return 1.0;
    final currentThreshold = totalXpForLevel(level);
    final nextThreshold = totalXpForLevel(level + 1);
    return (totalXp - currentThreshold) / (nextThreshold - currentThreshold);
  }
}

class ParagonRewards {
  final int maxEnergy;
  final int totalShards;
  final String? specialRewardKey;

  const ParagonRewards({
    required this.maxEnergy,
    required this.totalShards,
    this.specialRewardKey,
  });
}

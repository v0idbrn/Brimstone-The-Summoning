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

  /// Costo en oro para forjar/subir la runa al siguiente nivel.
  static int forgeCost(int currentLevel) => 100 * currentLevel;

  /// Costo en esquirlas para forjar/subir la runa al siguiente nivel.
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
}

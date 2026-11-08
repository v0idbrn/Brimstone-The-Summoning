/// Árbol de Talentos del Invocador: 8 talentos permanentes, Nivel 0 → 5.
///
/// Dominio puro. Los bonos agregados se exponen a través de [TalentTree] y son
/// consumidos por `CombatEngine` y por las recompensas de las pantallas.
library;

enum TalentStat {
  maxHp,
  orbAttack,
  maxMana,
  bullseyeDamage,
  reactionDamage,
  damageTakenReduction,
  goldGain,
  shardsGain,
}

/// Coste de una mejora concreta del árbol.
class TalentCost {
  final int gold;
  final int shards;

  const TalentCost({required this.gold, required this.shards});

  @override
  bool operator ==(Object other) =>
      other is TalentCost && other.gold == gold && other.shards == shards;

  @override
  int get hashCode => Object.hash(gold, shards);

  @override
  String toString() => 'TalentCost(gold: $gold, shards: $shards)';
}

class Talent {
  final String id;
  final String name;
  final String description;
  final TalentStat stat;
  final double baseValue;
  final double perLevel;

  const Talent({
    required this.id,
    required this.name,
    required this.description,
    required this.stat,
    required this.baseValue,
    required this.perLevel,
  });

  /// Valor acumulado del bono para [level] (0..[TalentRules.maxLevel]).
  double valueAt(int level) {
    if (level <= 0) return baseValue;
    final capped = level > TalentRules.maxLevel ? TalentRules.maxLevel : level;
    return baseValue + perLevel * capped;
  }

  /// Descripción legible del bono para el nivel indicado.
  String bonusLabel(int level) {
    final value = valueAt(level);
    final percent = (value * 100).round();
    return switch (stat) {
      TalentStat.damageTakenReduction => '-$percent% daño recibido',
      _ => '+$percent%',
    };
  }
}

class TalentRules {
  /// Nivel máximo por talento.
  static const int maxLevel = 5;

  /// Coste base en oro para pasar de `level` a `level + 1`.
  static const int baseGoldCost = 250;

  /// Coste base en esquirlas para pasar de `level` a `level + 1`.
  static const int baseShardCost = 75;

  static const List<Talent> allTalents = [
    Talent(
      id: 'archon_blood',
      name: 'Sangre de Arconte',
      description: '+6% HP máximo por nivel',
      stat: TalentStat.maxHp,
      baseValue: 0.0,
      perLevel: 0.06,
    ),
    Talent(
      id: 'sulfur_fury',
      name: 'Furia de Azufre',
      description: '+5% ATK de esferas por nivel',
      stat: TalentStat.orbAttack,
      baseValue: 0.0,
      perLevel: 0.05,
    ),
    Talent(
      id: 'runic_channeling',
      name: 'Canalización Rúnica',
      description: '+6% maná por nivel',
      stat: TalentStat.maxMana,
      baseValue: 0.0,
      perLevel: 0.06,
    ),
    Talent(
      id: 'deadly_eye',
      name: 'Ojo Letal',
      description: '+8% daño Bullseye por nivel',
      stat: TalentStat.bullseyeDamage,
      baseValue: 0.0,
      perLevel: 0.08,
    ),
    Talent(
      id: 'elemental_mastery',
      name: 'Maestría Elemental',
      description: '+7% daño de Reacciones por nivel',
      stat: TalentStat.reactionDamage,
      baseValue: 0.0,
      perLevel: 0.07,
    ),
    Talent(
      id: 'basalt_skin',
      name: 'Piel de Basalto',
      description: '-4% daño recibido por nivel',
      stat: TalentStat.damageTakenReduction,
      baseValue: 0.0,
      perLevel: 0.04,
    ),
    Talent(
      id: 'void_greed',
      name: 'Avaricia del Vacío',
      description: '+10% Oro por nivel',
      stat: TalentStat.goldGain,
      baseValue: 0.0,
      perLevel: 0.10,
    ),
    Talent(
      id: 'shard_echo',
      name: 'Eco de Esquirlas',
      description: '+10% Esquirlas por nivel',
      stat: TalentStat.shardsGain,
      baseValue: 0.0,
      perLevel: 0.10,
    ),
  ];

  /// Coste para subir [talentId] desde [currentLevel].
  /// Devuelve null si el talento no existe o ya está al máximo.
  static TalentCost? costFor(String talentId, int currentLevel) {
    final talent = byId(talentId);
    if (talent == null || currentLevel >= maxLevel) return null;
    final nextLevel = currentLevel + 1;
    return TalentCost(
      gold: baseGoldCost * nextLevel,
      shards: baseShardCost * nextLevel,
    );
  }

  static Talent? byId(String id) {
    for (final t in allTalents) {
      if (t.id == id) return t;
    }
    return null;
  }

  static TalentStat? statOf(String id) => byId(id)?.stat;
}

/// Estado agregado del árbol de talentos del jugador.
class TalentTree {
  final Map<String, int> levels;

  const TalentTree([this.levels = const {}]);

  /// Nivel de [talentId] (0 si no fue mejorado).
  int levelOf(String talentId) {
    final value = levels[talentId] ?? 0;
    if (value < 0) return 0;
    return value > TalentRules.maxLevel ? TalentRules.maxLevel : value;
  }

  /// Suma de los bonos de todos los talentos con [stat].
  double bonusFor(TalentStat stat) {
    var total = 0.0;
    for (final t in TalentRules.allTalents) {
      if (t.stat != stat) continue;
      total += t.valueAt(levelOf(t.id));
    }
    return total;
  }

  /// Multiplicador de HP máximo (+6% por nivel de Sangre de Arconte).
  double get maxHpMult => 1.0 + bonusFor(TalentStat.maxHp);

  /// Multiplicador de daño de esferas.
  double get orbDamageMult => 1.0 + bonusFor(TalentStat.orbAttack);

  /// Multiplicador de maná (Canalización Rúnica).
  double get manaMult => 1.0 + bonusFor(TalentStat.maxMana);

  /// Multiplicador de daño de Bullseye.
  double get bullseyeDamageMult => 1.0 + bonusFor(TalentStat.bullseyeDamage);

  /// Multiplicador de daño de Reacciones Elementales.
  double get reactionDamageMult => 1.0 + bonusFor(TalentStat.reactionDamage);

  /// Multiplicador de daño recibido (siempre > 0).
  double get damageTakenMult =>
      (1.0 - bonusFor(TalentStat.damageTakenReduction)).clamp(0.25, 1.0);

  /// Multiplicador de oro obtenido.
  double get goldGainMult => 1.0 + bonusFor(TalentStat.goldGain);

  /// Multiplicador de esquirlas obtenidas.
  double get shardsGainMult => 1.0 + bonusFor(TalentStat.shardsGain);

  /// Total de niveles invertidos (para títulos y métricas).
  int get totalLevels {
    var total = 0;
    for (final t in TalentRules.allTalents) {
      total += levelOf(t.id);
    }
    return total;
  }

  /// Aplica el oro/esquilas ganados con los multiplicadores del árbol.
  int applyGoldGain(int base) => (base * goldGainMult).round();
  int applyShardsGain(int base) => (base * shardsGainMult).round();

  TalentTree withLevel(String talentId, int level) {
    final capped = level.clamp(0, TalentRules.maxLevel);
    return TalentTree({...levels, talentId: capped});
  }
}

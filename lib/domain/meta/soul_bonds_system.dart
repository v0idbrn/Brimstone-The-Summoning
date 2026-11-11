import '../entities/owned_card.dart';

/// Vínculo de Almas (Soul Bond) — bonos pasivos globales por coleccionar
/// pares/tríos legendarios específicos de las 40 criaturas.
///
/// Al subir las criaturas del vínculo de estrellas (1★ → 5★), el vínculo
/// sube de Nivel 1 a Nivel 5, otorgando bonos permanentes a toda la cuenta
/// y desbloqueando relatos de lore en el Códice.
class SoulBond {
  final String id;
  final String nameKey;
  final String descKey;
  final String loreKey;
  final List<String> memberIds; // IDs de OwnedCard que forman el vínculo
  final List<SoulBondBonus> bonuses; // bonuses[level-1] para nivel 1-5

  const SoulBond({
    required this.id,
    required this.nameKey,
    required this.descKey,
    required this.loreKey,
    required this.memberIds,
    required this.bonuses,
  });

  /// Nivel actual del vínculo basado en el mínimo de estrellas de sus miembros.
  int currentLevel(List<OwnedCard> collection) {
    int minStars = 5;
    for (final memberId in memberIds) {
      final stars = _starsOf(collection, memberId);
      if (stars < minStars) minStars = stars;
    }
    return minStars.clamp(0, 5);
  }

  /// Bono activo para el nivel actual (null si nivel 0).
  SoulBondBonus? activeBonus(List<OwnedCard> collection) {
    final level = currentLevel(collection);
    if (level == 0) return null;
    return bonuses[level - 1];
  }

  /// Si el vínculo está completo (todos los miembros al máximo 5★).
  bool isMaxed(List<OwnedCard> collection) => currentLevel(collection) == 5;

  /// Progreso hacia el siguiente nivel (0.0 - 1.0).
  double progressToNext(List<OwnedCard> collection) {
    final level = currentLevel(collection);
    if (level >= 5) return 1.0;
    // Progreso basado en cuántos miembros ya alcanzan el siguiente nivel
    int ready = 0;
    for (final memberId in memberIds) {
      if (_starsOf(collection, memberId) >= level + 1) ready++;
    }
    return ready / memberIds.length;
  }
}

/// Devuelve las estrellas de un miembro de la colección (0 si no se posee).
int _starsOf(List<OwnedCard> collection, String memberId) {
  for (final c in collection) {
    if (c.catalogId == memberId) return c.stars;
  }
  return 0;
}

/// Bono pasivo otorgado por un nivel de Vínculo de Almas.
class SoulBondBonus {
  final SoulBondBonusType type;
  final double value; // valor numérico del bono
  final String descKey; // clave de localización para descripción

  const SoulBondBonus({
    required this.type,
    required this.value,
    required this.descKey,
  });
}

enum SoulBondBonusType {
  /// +% Oro global en todas las fuentes
  goldGain,

  /// +% Esquirlas global
  shardGain,

  /// +% XP global
  xpGain,

  /// + Energía máxima
  maxEnergy,

  /// -% Costo de mejora (oro/esquirlas)
  upgradeCostReduction,

  /// +% Daño de reacciones elementales
  elementalReactionDamage,

  /// +% Velocidad de carga de maná
  manaChargeSpeed,

  /// +% Probabilidad de crítico en Bullseye
  bullseyeCritChance,

  /// +% Daño a jefes
  bossDamage,

  /// Reduce cooldown de artefacto
  artifactCooldownReduction,

  /// + Slots de escuadrón (máx 5)
  extraSquadSlot,

  /// Desbloquea velocidad 2x en combate
  unlockSpeed2x,
}

/// Catálogo de los 12 Vínculos de Almas del lore de Brimstone.
class SoulBondCatalog {
  static const List<SoulBond> all = [
    // 1. SEÑORES DEL CRÁTER — Ignis Hound + Ignis Drake + Ignis Lord
    SoulBond(
      id: 'bond_crater_lords',
      nameKey: 'soul_bond.crater_lords.name',
      descKey: 'soul_bond.crater_lords.desc',
      loreKey: 'soul_bond.crater_lords.lore',
      memberIds: ['ignis_hound', 'ignis_drake', 'ignis_lord'],
      bonuses: [
        SoulBondBonus(
            type: SoulBondBonusType.goldGain,
            value: 0.05,
            descKey: 'soul_bond.bonus.gold_5'),
        SoulBondBonus(
            type: SoulBondBonusType.goldGain,
            value: 0.10,
            descKey: 'soul_bond.bonus.gold_10'),
        SoulBondBonus(
            type: SoulBondBonusType.elementalReactionDamage,
            value: 0.15,
            descKey: 'soul_bond.bonus.reaction_15'),
        SoulBondBonus(
            type: SoulBondBonusType.elementalReactionDamage,
            value: 0.25,
            descKey: 'soul_bond.bonus.reaction_25'),
        SoulBondBonus(
            type: SoulBondBonusType.unlockSpeed2x,
            value: 1,
            descKey: 'soul_bond.bonus.speed2x'),
      ],
    ),

    // 2. ESFINGES ÍGNEAS — Ignis Seraph + Ignis Colossus + Miniboss Ignarok
    SoulBond(
      id: 'bond_igneous_sphinxes',
      nameKey: 'soul_bond.igneous_sphinxes.name',
      descKey: 'soul_bond.igneous_sphinxes.desc',
      loreKey: 'soul_bond.igneous_sphinxes.lore',
      memberIds: ['ignis_seraph', 'ignis_colossus', 'miniboss_ignarok'],
      bonuses: [
        SoulBondBonus(
            type: SoulBondBonusType.shardGain,
            value: 0.05,
            descKey: 'soul_bond.bonus.shards_5'),
        SoulBondBonus(
            type: SoulBondBonusType.shardGain,
            value: 0.12,
            descKey: 'soul_bond.bonus.shards_12'),
        SoulBondBonus(
            type: SoulBondBonusType.bullseyeCritChance,
            value: 0.10,
            descKey: 'soul_bond.bonus.crit_10'),
        SoulBondBonus(
            type: SoulBondBonusType.bullseyeCritChance,
            value: 0.20,
            descKey: 'soul_bond.bonus.crit_20'),
        SoulBondBonus(
            type: SoulBondBonusType.bossDamage,
            value: 0.30,
            descKey: 'soul_bond.bonus.boss_30'),
      ],
    ),

    // 3. TERROR DE LAS FOSAS — Abyss Stalker + Abyss Siren + Abyss Kraken
    SoulBond(
      id: 'bond_abyssal_terror',
      nameKey: 'soul_bond.abyssal_terror.name',
      descKey: 'soul_bond.abyssal_terror.desc',
      loreKey: 'soul_bond.abyssal_terror.lore',
      memberIds: ['abyss_stalker', 'abyss_siren', 'abyss_kraken'],
      bonuses: [
        SoulBondBonus(
            type: SoulBondBonusType.xpGain,
            value: 0.08,
            descKey: 'soul_bond.bonus.xp_8'),
        SoulBondBonus(
            type: SoulBondBonusType.xpGain,
            value: 0.15,
            descKey: 'soul_bond.bonus.xp_15'),
        SoulBondBonus(
            type: SoulBondBonusType.manaChargeSpeed,
            value: 0.10,
            descKey: 'soul_bond.bonus.mana_10'),
        SoulBondBonus(
            type: SoulBondBonusType.manaChargeSpeed,
            value: 0.20,
            descKey: 'soul_bond.bonus.mana_20'),
        SoulBondBonus(
            type: SoulBondBonusType.artifactCooldownReduction,
            value: 0.25,
            descKey: 'soul_bond.bonus.artifact_cd_25'),
      ],
    ),

    // 4. LEVIATÁN Y SU CORTE — Abyss Leviathan + Abyss Wraith + Miniboss Cryon
    SoulBond(
      id: 'bond_leviathan_court',
      nameKey: 'soul_bond.leviathan_court.name',
      descKey: 'soul_bond.leviathan_court.desc',
      loreKey: 'soul_bond.leviathan_court.lore',
      memberIds: ['abyss_leviathan', 'abyss_wraith', 'miniboss_cryon'],
      bonuses: [
        SoulBondBonus(
            type: SoulBondBonusType.maxEnergy,
            value: 1,
            descKey: 'soul_bond.bonus.energy_1'),
        SoulBondBonus(
            type: SoulBondBonusType.maxEnergy,
            value: 2,
            descKey: 'soul_bond.bonus.energy_2'),
        SoulBondBonus(
            type: SoulBondBonusType.bossDamage,
            value: 0.20,
            descKey: 'soul_bond.bonus.boss_20'),
        SoulBondBonus(
            type: SoulBondBonusType.bossDamage,
            value: 0.35,
            descKey: 'soul_bond.bonus.boss_35'),
        SoulBondBonus(
            type: SoulBondBonusType.extraSquadSlot,
            value: 1,
            descKey: 'soul_bond.bonus.squad_slot'),
      ],
    ),

    // 5. COLOSSOS PRIMORDIALES — Terra Golem + Terra Warden + Terra Titan
    SoulBond(
      id: 'bond_primordial_colossi',
      nameKey: 'soul_bond.primordial_colossi.name',
      descKey: 'soul_bond.primordial_colossi.desc',
      loreKey: 'soul_bond.primordial_colossi.lore',
      memberIds: ['terra_golem', 'terra_warden', 'terra_titan'],
      bonuses: [
        SoulBondBonus(
            type: SoulBondBonusType.upgradeCostReduction,
            value: 0.05,
            descKey: 'soul_bond.bonus.upgrade_5'),
        SoulBondBonus(
            type: SoulBondBonusType.upgradeCostReduction,
            value: 0.12,
            descKey: 'soul_bond.bonus.upgrade_12'),
        SoulBondBonus(
            type: SoulBondBonusType.maxEnergy,
            value: 1,
            descKey: 'soul_bond.bonus.energy_1'),
        SoulBondBonus(
            type: SoulBondBonusType.maxEnergy,
            value: 3,
            descKey: 'soul_bond.bonus.energy_3'),
        SoulBondBonus(
            type: SoulBondBonusType.goldGain,
            value: 0.20,
            descKey: 'soul_bond.bonus.gold_20'),
      ],
    ),

    // 6. HIDRA Y BEHEMOTH — Terra Hydra + Terra Behemoth + Miniboss Krag
    SoulBond(
      id: 'bond_hydra_behemoth',
      nameKey: 'soul_bond.hydra_behemoth.name',
      descKey: 'soul_bond.hydra_behemoth.desc',
      loreKey: 'soul_bond.hydra_behemoth.lore',
      memberIds: ['terra_hydra', 'terra_behemoth', 'miniboss_krag'],
      bonuses: [
        SoulBondBonus(
            type: SoulBondBonusType.shardGain,
            value: 0.08,
            descKey: 'soul_bond.bonus.shards_8'),
        SoulBondBonus(
            type: SoulBondBonusType.shardGain,
            value: 0.15,
            descKey: 'soul_bond.bonus.shards_15'),
        SoulBondBonus(
            type: SoulBondBonusType.bullseyeCritChance,
            value: 0.08,
            descKey: 'soul_bond.bonus.crit_8'),
        SoulBondBonus(
            type: SoulBondBonusType.bullseyeCritChance,
            value: 0.18,
            descKey: 'soul_bond.bonus.crit_18'),
        SoulBondBonus(
            type: SoulBondBonusType.elementalReactionDamage,
            value: 0.30,
            descKey: 'soul_bond.bonus.reaction_30'),
      ],
    ),

    // 7. CORTE DEL ECLIPSE — Void Specter + Void Reaper + Void Oracle
    SoulBond(
      id: 'bond_eclipse_court',
      nameKey: 'soul_bond.eclipse_court.name',
      descKey: 'soul_bond.eclipse_court.desc',
      loreKey: 'soul_bond.eclipse_court.lore',
      memberIds: ['void_specter', 'void_reaper', 'void_oracle'],
      bonuses: [
        SoulBondBonus(
            type: SoulBondBonusType.xpGain,
            value: 0.10,
            descKey: 'soul_bond.bonus.xp_10'),
        SoulBondBonus(
            type: SoulBondBonusType.xpGain,
            value: 0.20,
            descKey: 'soul_bond.bonus.xp_20'),
        SoulBondBonus(
            type: SoulBondBonusType.manaChargeSpeed,
            value: 0.15,
            descKey: 'soul_bond.bonus.mana_15'),
        SoulBondBonus(
            type: SoulBondBonusType.manaChargeSpeed,
            value: 0.25,
            descKey: 'soul_bond.bonus.mana_25'),
        SoulBondBonus(
            type: SoulBondBonusType.artifactCooldownReduction,
            value: 0.30,
            descKey: 'soul_bond.bonus.artifact_cd_30'),
      ],
    ),

    // 8. MALAKOR Y EL ARCONTE — Void Malakor + Void Archon + Miniboss Morvath
    SoulBond(
      id: 'bond_malakor_archon',
      nameKey: 'soul_bond.malakor_archon.name',
      descKey: 'soul_bond.malakor_archon.desc',
      loreKey: 'soul_bond.malakor_archon.lore',
      memberIds: ['void_malakor', 'void_archon', 'miniboss_morvath'],
      bonuses: [
        SoulBondBonus(
            type: SoulBondBonusType.goldGain,
            value: 0.10,
            descKey: 'soul_bond.bonus.gold_10'),
        SoulBondBonus(
            type: SoulBondBonusType.goldGain,
            value: 0.20,
            descKey: 'soul_bond.bonus.gold_20'),
        SoulBondBonus(
            type: SoulBondBonusType.bossDamage,
            value: 0.25,
            descKey: 'soul_bond.bonus.boss_25'),
        SoulBondBonus(
            type: SoulBondBonusType.bossDamage,
            value: 0.40,
            descKey: 'soul_bond.bonus.boss_40'),
        SoulBondBonus(
            type: SoulBondBonusType.unlockSpeed2x,
            value: 1,
            descKey: 'soul_bond.bonus.speed2x'),
      ],
    ),

    // 9. REYES DE CORAL NEGRO — Boss Kaelith + Miniboss Thalor + Minion Coral Sirena
    SoulBond(
      id: 'bond_coral_kings',
      nameKey: 'soul_bond.coral_kings.name',
      descKey: 'soul_bond.coral_kings.desc',
      loreKey: 'soul_bond.coral_kings.lore',
      memberIds: ['boss_kaelith', 'miniboss_thalor', 'minion_coral_sirena'],
      bonuses: [
        SoulBondBonus(
            type: SoulBondBonusType.shardGain,
            value: 0.10,
            descKey: 'soul_bond.bonus.shards_10'),
        SoulBondBonus(
            type: SoulBondBonusType.shardGain,
            value: 0.18,
            descKey: 'soul_bond.bonus.shards_18'),
        SoulBondBonus(
            type: SoulBondBonusType.elementalReactionDamage,
            value: 0.20,
            descKey: 'soul_bond.bonus.reaction_20'),
        SoulBondBonus(
            type: SoulBondBonusType.elementalReactionDamage,
            value: 0.30,
            descKey: 'soul_bond.bonus.reaction_30'),
        SoulBondBonus(
            type: SoulBondBonusType.maxEnergy,
            value: 2,
            descKey: 'soul_bond.bonus.energy_2'),
      ],
    ),

    // 10. VIGILANTES ESTELARES — Boss Astreon + Miniboss Sideris + Minion Estelar Oraculo
    SoulBond(
      id: 'bond_stellar_watchers',
      nameKey: 'soul_bond.stellar_watchers.name',
      descKey: 'soul_bond.stellar_watchers.desc',
      loreKey: 'soul_bond.stellar_watchers.lore',
      memberIds: ['boss_astreon', 'miniboss_sideris', 'minion_estelar_oraculo'],
      bonuses: [
        SoulBondBonus(
            type: SoulBondBonusType.xpGain,
            value: 0.12,
            descKey: 'soul_bond.bonus.xp_12'),
        SoulBondBonus(
            type: SoulBondBonusType.xpGain,
            value: 0.22,
            descKey: 'soul_bond.bonus.xp_22'),
        SoulBondBonus(
            type: SoulBondBonusType.manaChargeSpeed,
            value: 0.12,
            descKey: 'soul_bond.bonus.mana_12'),
        SoulBondBonus(
            type: SoulBondBonusType.manaChargeSpeed,
            value: 0.22,
            descKey: 'soul_bond.bonus.mana_22'),
        SoulBondBonus(
            type: SoulBondBonusType.artifactCooldownReduction,
            value: 0.35,
            descKey: 'soul_bond.bonus.artifact_cd_35'),
      ],
    ),

    // 11. CATEDRAL DE HUESO — Boss Malakor Reborn + Miniboss Seraphon + Minion Catedral Incipiente
    SoulBond(
      id: 'bond_bone_cathedral',
      nameKey: 'soul_bond.bone_cathedral.name',
      descKey: 'soul_bond.bone_cathedral.desc',
      loreKey: 'soul_bond.bone_cathedral.lore',
      memberIds: [
        'boss_malakor',
        'miniboss_seraphon',
        'minion_catedral_incipiente'
      ],
      bonuses: [
        SoulBondBonus(
            type: SoulBondBonusType.upgradeCostReduction,
            value: 0.08,
            descKey: 'soul_bond.bonus.upgrade_8'),
        SoulBondBonus(
            type: SoulBondBonusType.upgradeCostReduction,
            value: 0.18,
            descKey: 'soul_bond.bonus.upgrade_18'),
        SoulBondBonus(
            type: SoulBondBonusType.goldGain,
            value: 0.15,
            descKey: 'soul_bond.bonus.gold_15'),
        SoulBondBonus(
            type: SoulBondBonusType.goldGain,
            value: 0.25,
            descKey: 'soul_bond.bonus.gold_25'),
        SoulBondBonus(
            type: SoulBondBonusType.extraSquadSlot,
            value: 1,
            descKey: 'soul_bond.bonus.squad_slot'),
      ],
    ),

    // 12. CORAZÓN DEL DIOS CAÍDO — Boss Samael + Miniboss Vehemoth + Minion Corazón Serafín
    SoulBond(
      id: 'bond_fallen_god_heart',
      nameKey: 'soul_bond.fallen_god_heart.name',
      descKey: 'soul_bond.fallen_god_heart.desc',
      loreKey: 'soul_bond.fallen_god_heart.lore',
      memberIds: ['boss_samael', 'miniboss_vehemoth', 'minion_corazon_serafin'],
      bonuses: [
        SoulBondBonus(
            type: SoulBondBonusType.bossDamage,
            value: 0.30,
            descKey: 'soul_bond.bonus.boss_30'),
        SoulBondBonus(
            type: SoulBondBonusType.bossDamage,
            value: 0.50,
            descKey: 'soul_bond.bonus.boss_50'),
        SoulBondBonus(
            type: SoulBondBonusType.elementalReactionDamage,
            value: 0.40,
            descKey: 'soul_bond.bonus.reaction_40'),
        SoulBondBonus(
            type: SoulBondBonusType.manaChargeSpeed,
            value: 0.30,
            descKey: 'soul_bond.bonus.mana_30'),
        SoulBondBonus(
            type: SoulBondBonusType.unlockSpeed2x,
            value: 1,
            descKey: 'soul_bond.bonus.speed2x'),
      ],
    ),
  ];

  /// Obtiene un vínculo por ID.
  static SoulBond? getById(String id) {
    try {
      return all.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Todos los bonos activos para una colección dada.
  static List<SoulBondBonus> activeBonuses(List<OwnedCard> collection) {
    final bonuses = <SoulBondBonus>[];
    for (final bond in all) {
      final bonus = bond.activeBonus(collection);
      if (bonus != null) bonuses.add(bonus);
    }
    return bonuses;
  }

  /// Valor agregado de un tipo de bono (suma de todos los vínculos activos).
  static double totalBonus(List<OwnedCard> collection, SoulBondBonusType type) {
    double total = 0;
    for (final bond in all) {
      final bonus = bond.activeBonus(collection);
      if (bonus != null && bonus.type == type) {
        total += bonus.value;
      }
    }
    return total;
  }

  /// Si la velocidad 2x está desbloqueada por algún vínculo.
  static bool hasSpeed2xUnlock(List<OwnedCard> collection) {
    return activeBonuses(collection)
        .any((b) => b.type == SoulBondBonusType.unlockSpeed2x);
  }

  /// Slots extra de escuadrón (0, 1 o 2).
  static int extraSquadSlots(List<OwnedCard> collection) {
    int slots = 0;
    for (final bond in all) {
      final bonus = bond.activeBonus(collection);
      if (bonus != null && bonus.type == SoulBondBonusType.extraSquadSlot) {
        slots += bonus.value.toInt();
      }
    }
    return slots.clamp(0, 2);
  }
}

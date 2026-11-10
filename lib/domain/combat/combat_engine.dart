import 'dart:math' as math;

import '../services/elemental_reaction_engine.dart';
import '../meta/squad_synergy_resolver.dart';
import '../meta/rune_system.dart';
import '../meta/leader_skill.dart';
import '../meta/talent_rules.dart';
import '../meta/summoner_gear.dart';
import '../../core/performance/object_pool.dart';
import '../../core/performance/performance_settings.dart';
import '../../core/security/combat_sanity_guard.dart';
import '../meta/seal_challenge_rules.dart';
import '../value_objects/element.dart';
import '../value_objects/orb_level.dart';
import 'combat_math.dart';
import 'combat_models.dart';

/// Relic-derived combat modifiers for a rift run.
class CombatModifiers {
  final double critRadiusMult;
  final double igneousLevel2Chance;
  final double jumpToThreeChance;
  final double manaSpeedMult;
  final double startManaFraction;
  final double startHpLossFraction;
  final double counterflickHealFraction;
  final double reactionMana;
  // Prismatic Orb (Prisma del Caos): permite fusionar cualquier elemento y detonar cualquier aura.
  final bool prismaticOrb;
  // Reloj de Ceniza: +2s duración de aura
  final double auraDurationBonus;
  // Colmillo Vampírico: +2% curación en Bullseye
  final double bullseyeHealFraction;
  // Sello de Sobrecarga: 100% maná inicial en Líder
  final bool leaderStartManaFull;
  // Esencia del Abismo: +1 nivel base a esferas
  final int baseOrbLevelBonus;
  // Corazón de Fénix: revive una vez
  final bool phoenixRevive;
  // Grimorio Antiguo: -20% maná skills, +15% efecto
  final double skillManaCostMult;
  final double skillEffectMult;
  // Túnica del Vacío: -15% daño, inmunidad proyectiles 3s
  final double damageTakenMult;
  final bool projectileImmunityStart;
  // Martillo del Titán: fusiones siempre Nivel 2+
  final int minMergeLevel;
  final double threeMergeChance;
  // Cadenas del Sello: jefes aturdidos 2s y ataques 25% más lentos
  final double bossStartStun;
  final double bossAttackIntervalMult;
  // Llama Eterna: esferas Ígneas no se gastan 20%
  final double igneousOrbSaveChance;
  // Sombra Perdida: +1 esquirlas/enemigo, +25% crítico Abyssal
  final double abyssalCritMult;
  final double shardsPerEnemyBonus;

  const CombatModifiers({
    this.critRadiusMult = 1.0,
    this.igneousLevel2Chance = 0.0,
    this.jumpToThreeChance = 0.0,
    this.manaSpeedMult = 1.0,
    this.startManaFraction = 0.0,
    this.startHpLossFraction = 0.0,
    this.counterflickHealFraction = 0.0,
    this.reactionMana = 0.0,
    this.prismaticOrb = false,
    this.auraDurationBonus = 0.0,
    this.bullseyeHealFraction = 0.0,
    this.leaderStartManaFull = false,
    this.baseOrbLevelBonus = 0,
    this.phoenixRevive = false,
    this.skillManaCostMult = 1.0,
    this.skillEffectMult = 1.0,
    this.damageTakenMult = 1.0,
    this.projectileImmunityStart = false,
    this.minMergeLevel = 1,
    this.threeMergeChance = 0.0,
    this.bossStartStun = 0.0,
    this.bossAttackIntervalMult = 1.0,
    this.igneousOrbSaveChance = 0.0,
    this.abyssalCritMult = 1.0,
    this.shardsPerEnemyBonus = 0.0,
  });

  /// Builds modifiers from a set of active relic ids.
  factory CombatModifiers.fromRelics(Iterable<String> relicIds) {
    var m = const CombatModifiers();
    for (final id in relicIds) {
      switch (id) {
        case 'ojo_abismo':
          m = m.copyWith(critRadiusMult: 1.4);
        case 'ceniza_volatil':
          m = m.copyWith(igneousLevel2Chance: 0.35);
        case 'sello_resonancia':
          m = m.copyWith(reactionMana: 20.0);
        case 'pacto_sangre':
          m = m.copyWith(manaSpeedMult: 1.5, startHpLossFraction: 0.08);
        case 'forja_perpetua':
          m = m.copyWith(jumpToThreeChance: 0.25);
        case 'coraza_obsidiana':
          m = m.copyWith(counterflickHealFraction: 0.04);
        // New relics
        case 'prisma_caos':
          m = m.copyWith(prismaticOrb: true);
        case 'reloj_ceniza':
          m = m.copyWith(auraDurationBonus: 2.0);
        case 'colmillo_vampirico':
          m = m.copyWith(bullseyeHealFraction: 0.02);
        case 'sello_sobrecarga':
          m = m.copyWith(leaderStartManaFull: true);
        case 'esencia_abismo':
          m = m.copyWith(baseOrbLevelBonus: 1);
        case 'corazon_phoenix':
          m = m.copyWith(phoenixRevive: true);
        case 'grimorio_antiguo':
          m = m.copyWith(skillManaCostMult: 0.8, skillEffectMult: 1.15);
        case 'tunica_vacio':
          m = m.copyWith(damageTakenMult: 0.85, projectileImmunityStart: true);
        case 'martillo_titan':
          m = m.copyWith(minMergeLevel: 2, threeMergeChance: 0.5);
        case 'cadenas_sello':
          m = m.copyWith(bossStartStun: 2.0, bossAttackIntervalMult: 0.75);
        case 'llama_eterna':
          m = m.copyWith(igneousOrbSaveChance: 0.20);
        case 'sombra_perdida':
          m = m.copyWith(abyssalCritMult: 1.25, shardsPerEnemyBonus: 1.0);
      }
    }
    return m;
  }

  CombatModifiers copyWith({
    double? critRadiusMult,
    double? igneousLevel2Chance,
    double? jumpToThreeChance,
    double? manaSpeedMult,
    double? startManaFraction,
    double? startHpLossFraction,
    double? counterflickHealFraction,
    double? reactionMana,
    bool? prismaticOrb,
    double? auraDurationBonus,
    double? bullseyeHealFraction,
    bool? leaderStartManaFull,
    int? baseOrbLevelBonus,
    bool? phoenixRevive,
    double? skillManaCostMult,
    double? skillEffectMult,
    double? damageTakenMult,
    bool? projectileImmunityStart,
    int? minMergeLevel,
    double? threeMergeChance,
    double? bossStartStun,
    double? bossAttackIntervalMult,
    double? igneousOrbSaveChance,
    double? abyssalCritMult,
    double? shardsPerEnemyBonus,
  }) =>
      CombatModifiers(
        critRadiusMult: critRadiusMult ?? this.critRadiusMult,
        igneousLevel2Chance: igneousLevel2Chance ?? this.igneousLevel2Chance,
        jumpToThreeChance: jumpToThreeChance ?? this.jumpToThreeChance,
        manaSpeedMult: manaSpeedMult ?? this.manaSpeedMult,
        startManaFraction: startManaFraction ?? this.startManaFraction,
        startHpLossFraction: startHpLossFraction ?? this.startHpLossFraction,
        counterflickHealFraction:
            counterflickHealFraction ?? this.counterflickHealFraction,
        reactionMana: reactionMana ?? this.reactionMana,
        prismaticOrb: prismaticOrb ?? this.prismaticOrb,
        auraDurationBonus: auraDurationBonus ?? this.auraDurationBonus,
        bullseyeHealFraction: bullseyeHealFraction ?? this.bullseyeHealFraction,
        leaderStartManaFull: leaderStartManaFull ?? this.leaderStartManaFull,
        baseOrbLevelBonus: baseOrbLevelBonus ?? this.baseOrbLevelBonus,
        phoenixRevive: phoenixRevive ?? this.phoenixRevive,
        skillManaCostMult: skillManaCostMult ?? this.skillManaCostMult,
        skillEffectMult: skillEffectMult ?? this.skillEffectMult,
        damageTakenMult: damageTakenMult ?? this.damageTakenMult,
        projectileImmunityStart:
            projectileImmunityStart ?? this.projectileImmunityStart,
        minMergeLevel: minMergeLevel ?? this.minMergeLevel,
        threeMergeChance: threeMergeChance ?? this.threeMergeChance,
        bossStartStun: bossStartStun ?? this.bossStartStun,
        bossAttackIntervalMult:
            bossAttackIntervalMult ?? this.bossAttackIntervalMult,
        igneousOrbSaveChance: igneousOrbSaveChance ?? this.igneousOrbSaveChance,
        abyssalCritMult: abyssalCritMult ?? this.abyssalCritMult,
        shardsPerEnemyBonus: shardsPerEnemyBonus ?? this.shardsPerEnemyBonus,
      );
}

/// Pure Dart combat simulation. The Flame layer only renders and feeds input.
class CombatEngine {
  static const double layoutWidth = 430.0;
  static const double layoutHeight = 932.0;
  static const double bossScreenX = layoutWidth * 0.50;
  static const double bossScreenY = layoutHeight * 0.48;
  static const double trayY = layoutHeight * 0.84;
  static const double spawnInterval = 0.85;
  static const double baseDamage = 35.0;
  static const double outerRadius = 46.0;
  static const double innerRadius = 20.0;
  static const double counterflickMana = 20.0;
  // (reactionManaBonus kept as named constant for HUD reference)

  final BossConfig boss;

  // Anti-cheat ceiling: rawDamage may get amplified by relic/talent stacks.
  // Con 22 * 500 = 11000 como techo legal; los nuevos bosses (380-1650 HP)
  // nunca superarán esto sin modificadores extremos.
  final CombatModifiers modifiers;
  final List<ManaCard> cards;

  /// Sinergia pasiva activa del escuadrón (aplica bonos globales en combate).
  final SquadSynergyBonus? synergy;

  /// Runas equipadas por carta, keyed by [ManaCard.id].
  final Map<String, RuneInstance> cardRunes;

  /// Multiplicador de daño del jugador (bono de bendición Filo de Azufre).
  final double playerDamageMult;

  /// HP inicial del jugador (se conserva entre oleadas del Abismo Sin Fin).
  final double? startHp;

  /// Si todas las cartas empiezan con maná completo (bendición Sobrecarga Arcana).
  final bool startManaFull;

  final List<CombatTarget> targets = [];
  final math.Random random;

  // Boss / player state.
  double bossHp;
  final double playerMaxHp;
  double playerHp;
  double shield = 0;

  // Block 3: Boss Shield Break mechanics.
  double bossShieldHp = 0.0;
  bool bossShieldBroken = false;
  double bossBreakTimer = 0.0; // 5s break duration
  static const double bossBreakDuration = 5.0;
  static const double bossBreakDamageMult = 1.5;
  static const double bossBreakCritMult = 1.5; // +50% crit damage
  static const double bossShieldFraction = 0.25; // 25% of maxHp
  static const double shieldWeaknessMult =
      2.5; // 2.5x damage to shield with weak element/reaction

  // Boss enrage (phase 2 at <45% HP).
  bool enraged = false;
  double _enrageTimer = 0;
  int _burnedSlot = -1;
  double _burnRemaining = 0;
  bool _iceShieldActive = false;
  double _iceShieldRemaining = 0;
  bool _rotationInverted = false;
  double _rotationInvertUntil = 5.0;

  // Gorgath (Telúrico) enrage: petrifica la carta con más maná 4.0s y
  // reduce el radio de las dianas un 20% mientras dura el enrage.
  String? _gorgathPetrifiedCardId;
  double _gorgathPetrifyRemaining = 0;

  // Nyxara (Vacío) enrage: teletransporta las dianas cada 4.0s.
  double _nyxaraTeleportRemaining = 0;

  // Aura & timers.
  Element? aura;
  double auraRemaining = 0;
  double vulnerableRemaining = 0;
  double petrifyRemaining = 0;
  double bossStunRemaining = 0;
  double bossAttackTimer;

  // Tray & projectiles.
  final List<CombatOrb?> tray = List.filled(5, null);
  final List<OrbProjectile> projectiles = [];
  final List<EnemyProjectile> enemyProjectiles = [];

  /// Textos flotantes en un búfer circular de capacidad fija: una ráfaga de
  /// golpes no puede hacer crecer esta lista indefinidamente.
  final FixedRingBuffer<FloatingText> texts = FixedRingBuffer<FloatingText>(
    PerformanceSettings.maxFloatingTexts,
  );

  // Juice.
  double time = 0;
  double trauma = 0;
  double hitStopRemaining = 0;
  double slowMoRemaining = 0;

  // Drag state.
  int? dragSlot;
  double dragX = 0;
  double dragY = 0;
  double dragVelocityY = 0;

  bool finished = false;
  bool victory = false;
  double spawnTimer = 0;
  int _idCounter = 0;

  // Block 3: Auto-Battle AI state.
  bool autoBattleEnabled = false;
  static const double autoBattleTickInterval = 0.75;

  // Módulos 2 & 5: Talentos permanentes y equipamiento del Invocador.
  final TalentTree _talentTree;
  final GearLoadout _gearLoadout;

  /// Mutadores activos de un Desafío del Sello (vacío en combate normal).
  final List<SealMutator> mutators;

  /// Modo práctica de la Arena de Entrenamiento: maná y vida disponibles sin
  /// coste, sin guardar progreso.
  final bool trainingMode;

  /// Racha de Bullseyes consecutivos (se corta al fallar o raspar).
  int bullseyeStreak = 0;

  /// Mejor racha alcanzada en este combate.
  int bestBullseyeStreak = 0;

  bool _phoenixUsed = false;

  /// Anti-cheat: valida cada golpe contra el techo matemático legal.
  // Con baseDamage = 22 y un techo 22 * 500 = 11000; los nuevos bosses
  // (380-1650 HP) nunca superarán esto sin modificadores extremos.
  final CombatSanityGuard sanityGuard = CombatSanityGuard(
    maxAllowedSingleHit: (baseDamage * 500).round(),
  );

  /// Techo legal de daño por golpe (lectura usada por el guardián).
  int get maxAllowedSingleHit => sanityGuard.maxAllowedSingleHit;

  // Combat metrics (populated during the fight, read by CombatSummaryDialog).
  int damageTotal = 0;
  double maxHit = 0;
  int bullseyes = 0;
  int reactions = 0;
  int counterflicks = 0;
  int mergesToThree = 0;

  // Talent damage reduction accessor (used at construction time).
  // Returns the combined TalentStat-based bonuses as a multiplier string list.
  /// Total damage multiplier from talents. Returned here for convenience.

  // Talent damage multiplier accessor (M4 streak bonuses etc.)
  double get talentOrbDamageMult => _talentTree.orbDamageMult;

  /// Árbol de talentos aplicado a este combate.
  TalentTree get talents => _talentTree;

  /// Equipamiento del invocador aplicado a este combate.
  GearLoadout get gear => _gearLoadout;

  /// True si el mutador [m] está activo en esta prueba.
  bool has(SealMutator m) => mutators.contains(m);

  /// Bono de daño por racha crítica: +10% por Bullseye consecutivo a partir
  /// del tercero, con tope de +100%.
  double get bullseyeStreakBonus {
    if (bullseyeStreak < 3) return 1.0;
    final bonus = 0.10 * (bullseyeStreak - 2);
    return 1.0 + (bonus > 1.0 ? 1.0 : bonus);
  }

  /// Daño por segundo acumulado (medidor de DPS de la arena).
  double get dps => damageTotal / (time <= 0.25 ? 0.25 : time);

  /// Vida restante como fracción (para la viñeta de peligro).
  double get hpFraction => playerMaxHp <= 0 ? 0 : playerHp / playerMaxHp;

  /// True cuando el jugador está por debajo del 25% de vida.
  bool get isLowHp => hpFraction < 0.25;

  /// Optional external callbacks (wired by the Flame layer).
  void Function()? onVictory;
  void Function()? onDefeat;
  void Function()? onEnrage;
  void Function(HitKind kind, int damage, double x, double y, Element element)?
      onHit;
  void Function(String)? onReaction;

  /// Fired the moment the boss seal/shield shatters ("RUPTURA DE SELLO").
  void Function()? onShieldBreak;

  /// Fired when a squad skill is successfully invoked. The battle screen uses
  /// it to launch the cinematic hero "cut-in" banner.
  void Function(ManaCard card, int index)? onSkillCast;

  /// Merge callback with exact engine (x, y) slot-center coordinates, resulting
  /// level and element.
  void Function(OrbLevel level, double x, double y, Element element)? onMerge;

  /// Called whenever the tray content changes (orb added/removed/merged) so
  /// the Flutter layer can rebuild the tray widget.
  void Function()? onTrayChanged;

  CombatEngine({
    required this.boss,
    required this.cards,
    double? playerMaxHp,
    CombatModifiers? modifiers,
    math.Random? random,
    this.synergy,
    this.cardRunes = const {},
    this.playerDamageMult = 1.0,
    this.startHp,
    this.startManaFull = false,
    Map<String, int> talentLevels = const {},
    Map<String, int> summonerGear = const {},
    this.mutators = const [],
    this.trainingMode = false,
  })  : modifiers = modifiers ?? const CombatModifiers(),
        _talentTree = TalentTree(talentLevels),
        _gearLoadout = GearLoadout(summonerGear),
        playerMaxHp = (playerMaxHp ?? 100) *
            (synergy?.hpMult ?? 1.0) *
            TalentTree(talentLevels).maxHpMult,
        random = random ?? math.Random(),
        bossHp = boss.maxHp,
        bossShieldHp = boss.shieldHp > 0
            ? boss.shieldHp
            : (boss.maxHp * bossShieldFraction).roundToDouble(),
        playerHp = startHp ??
            (playerMaxHp ?? 100) *
                (synergy?.hpMult ?? 1.0) *
                TalentTree(talentLevels).maxHpMult,
        bossAttackTimer = 0 {
    bossAttackTimer =
        boss.attackInterval * this.modifiers.bossAttackIntervalMult;
    _spawnTargetRing();
    _spawnTargetRing();
    _applyStartModifiers();
    fillTray();
  }

  void _spawnTargetRing() {
    final count = 2 + random.nextInt(3); // 2 to 4 targets
    for (var i = 0; i < count; i++) {
      targets.add(
        CombatTarget(
          id: 'target_$i',
          trajectory: TargetTrajectory.values[i % 3],
          cx: bossScreenX,
          cy: bossScreenY,
          amplitude: 70.0 + i * 14.0,
          baseAngularSpeed: 1.4 + i * 0.35,
          phase: i * 1.6,
        ),
      );
    }
  }

  void _applyStartModifiers() {
    // Sinergia Sobrecarga Arcana: todas las cartas empiezan con maná completo.
    if (startManaFull || trainingMode) {
      fillAllMana();
      return;
    }
    if (modifiers.startManaFraction > 0) {
      for (final c in cards) {
        c.mana = c.baseManaCost * modifiers.startManaFraction;
      }
    }
    // Sinergia monoelemental: las cartas empiezan con 20% de maná.
    if (synergy?.startManaFraction != null && synergy!.startManaFraction > 0) {
      for (final c in cards) {
        c.mana = (c.mana + c.baseManaCost * synergy!.startManaFraction).clamp(
          0.0,
          c.baseManaCost.toDouble(),
        );
      }
    }
    // Sello de Sobrecarga: la carta Líder arranca con el maná completo.
    if (modifiers.leaderStartManaFull && cards.isNotEmpty) {
      cards.first.mana = cards.first.baseManaCost.toDouble();
    }
    if (modifiers.startHpLossFraction > 0) {
      playerHp -= playerMaxHp * modifiers.startHpLossFraction;
    }
    // Cadenas del Sello: los jefes empiezan aturdidos.
    if (modifiers.bossStartStun > 0) {
      bossStunRemaining = modifiers.bossStartStun;
    }
    // Juicio del Emperador: Azathor en Furia desde el segundo 0.
    if (has(SealMutator.azathorFuryStart)) {
      enraged = true;
    }
  }

  /// Llena el maná de todas las cartas al máximo (Arena de Entrenamiento).
  void fillAllMana() {
    for (final c in cards) {
      c.mana = c.baseManaCost.toDouble();
    }
  }

  /// Llena las 5 ranuras de la bandeja con esferas Nivel 1 (o nivel base según reliquias).
  /// Se llama al iniciar el combate y cada 0.85s para rellenar huecos.
  void fillTray() {
    for (var i = 0; i < tray.length; i++) {
      if (tray[i] == null) {
        spawnOrbInSlot(i);
      }
    }
    onTrayChanged?.call();
  }

  /// ATK efectivo de una carta: sinergia + runa de Furia Carmesí + talentos.
  double _effectiveAttack(ManaCard c) {
    var atk = c.attack;
    if (synergy?.atkMult != null && synergy!.atkMult > 1.0) {
      atk *= synergy!.atkMult;
    }
    final rune = cardRunes[c.id];
    if (rune != null) {
      atk *= RuneSystem.atkMult(rune.type, rune.level);
    }
    return atk * _talentTree.orbDamageMult;
  }

  /// Costo de maná efectivo: runa de Flujo Eterno + Grimorio Antiguo.
  double _effectiveManaCost(ManaCard c) {
    final rune = cardRunes[c.id];
    var cost = c.baseManaCost.toDouble();
    if (rune != null && rune.type == RuneType.eternalFlow) {
      cost *= (1.0 - RuneSystem.manaCostReduction(rune.type, rune.level));
    }
    return cost * modifiers.skillManaCostMult;
  }

  /// Velocidad de generación de maná efectiva (modificadores + sinergia Trinidad Arcana).
  double get _effectiveManaSpeedMult =>
      modifiers.manaSpeedMult * (synergy?.manaSpeedMult ?? 1.0);

  /// LeaderSkill de la carta en el Slot 0 del escuadrón (nulo si vacío).
  LeaderSkill? get leaderSkill => cards.isEmpty
      ? null
      : LeaderSkill(element: cards.first.element, stars: cards.first.stars);

  String _nextId(String prefix) => '${prefix}_${_idCounter++}';

  double effectiveAngularSpeed(CombatTarget t) {
    var base = t.baseAngularSpeed * (petrifyRemaining > 0 ? 0.5 : 1.0);
    if (enraged && boss.id == 'azathor' && _rotationInverted) {
      base = -base;
    }
    // Dianas Fugaces: un 25% más rápidas.
    if (has(SealMutator.fastSmallManaBoost)) base *= 1.25;
    return base;
  }

  /// Multiplicador de radio: reliquia + Guanteletes + mutador de dianas.
  double get _targetRadiusMult =>
      modifiers.critRadiusMult *
      _gearLoadout.bullseyeRadiusMult *
      (has(SealMutator.fastSmallManaBoost) ? 0.75 : 1.0);

  double outerRadiusFor(CombatTarget t) {
    final enlarged =
        t.enlargedUntil > time ? (1.0 + t.enlargedRadiusBonus) : 1.0;
    return outerRadius * _targetRadiusMult * enlarged;
  }

  double innerRadiusFor(CombatTarget t) {
    final enlarged =
        t.enlargedUntil > time ? (1.0 + t.enlargedRadiusBonus) : 1.0;
    return innerRadius * _targetRadiusMult * enlarged;
  }

  // ------------------------------------------------------------------ input

  void startDrag(int slot, double x, double y) {
    if (tray[slot] == null) return;
    dragSlot = slot;
    dragX = x;
    dragY = y;
    dragVelocityY = 0;
  }

  void updateDrag(double x, double y, double dt) {
    if (dragSlot == null) return;
    dragVelocityY = dt > 0 ? (y - dragY) / dt : dragVelocityY;
    dragX = x;
    dragY = y;
  }

  /// Releases the drag: flick upward launches a projectile, otherwise swap.
  void releaseDrag(double velocityY) {
    final slot = dragSlot;
    if (slot == null) return;
    dragSlot = null;
    if (velocityY < CombatMath.flickSpeedThreshold) {
      final orb = tray[slot]!;
      final vy = velocityY.abs().clamp(280.0, 2000.0).toDouble();
      projectiles.add(
        OrbProjectile(
          id: _nextId('proj'),
          element: orb.element,
          level: orb.level,
          startX: dragX,
          startY: trayY,
          targetX: dragX,
          targetY: bossScreenY,
          flightDuration: CombatMath.durationForFlickSpeed(-vy),
        ),
      );
      tray[slot] = null;
      return;
    }
    // Not upward enough: treat release as a swap if dropped on another slot.
    final target = _slotAt(dragX, dragY);
    if (target != null && target != slot) {
      swapOrbs(slot, target);
    }
  }

  int? _slotAt(double x, double y) {
    if (y < trayY - 60 || y > layoutHeight) return null;
    final slot = (x / (layoutWidth / 5)).floor();
    if (slot < 0 || slot > 4) return null;
    return slot;
  }

  /// Attempts to counter-flick an enemy orb by touching it (returns true if destroyed).
  bool counterFlickAt(double x, double y, double enemyTime) {
    for (final e in List.of(enemyProjectiles)) {
      if (!e.alive) continue;
      final z = CombatMath.flightZ(e.elapsed, e.duration);
      final ez = 1.0 - z;
      final ex = CombatMath.lerp(e.startX, e.endX, ez);
      final ey = CombatMath.lerp(e.startY, e.endY, ez);
      final dist = math.sqrt((x - ex) * (x - ex) + (y - ey) * (y - ey));
      if (dist < CombatMath.projectileInterceptDistance * 1.5) {
        _destroyEnemyProjectile(e, byCounterflick: true);
        return true;
      }
    }
    return false;
  }

  // -------------------------------------------------------------- tray ops

  CombatOrb? spawnOrbInSlot(int slot) {
    if (tray[slot] != null) return null;
    // Tormenta Bipolar: sólo Ígneo y Abisal.
    final Element element;
    if (has(SealMutator.igneousAbyssalFast)) {
      element = random.nextBool() ? Element.igneous : Element.abyssal;
    } else {
      element = Element.values[random.nextInt(4)];
    }
    // Esencia del Abismo: +1 nivel base.
    final baseIndex = modifiers.baseOrbLevelBonus.clamp(0, 2);
    var level = OrbLevel.values[baseIndex];
    if (element == Element.igneous &&
        level == OrbLevel.one &&
        random.nextDouble() < modifiers.igneousLevel2Chance) {
      level = OrbLevel.two;
    }
    final prismatic = modifiers.prismaticOrb && random.nextDouble() < 0.15;
    final orb = CombatOrb(
      id: _nextId('orb'),
      element: element,
      level: level,
      prismatic: prismatic,
    );
    tray[slot] = orb;
    onTrayChanged?.call();
    return orb;
  }

  OrbLevel? mergeOrbs(int a, int b) {
    final orbA = tray[a];
    final orbB = tray[b];
    if (orbA == null || orbB == null || a == b) return null;
    // Una esfera prismática fusiona con cualquier elemento del mismo nivel.
    final compatible =
        orbA.element == orbB.element || orbA.prismatic || orbB.prismatic;
    if (!compatible || orbA.level != orbB.level) {
      swapOrbs(a, b);
      return null;
    }
    if (orbA.level == OrbLevel.three) {
      swapOrbs(a, b);
      return null;
    }
    final element = orbA.prismatic
        ? (orbB.prismatic ? Element.values[random.nextInt(4)] : orbB.element)
        : orbA.element;
    var newLevel = orbA.level == OrbLevel.one ? OrbLevel.two : OrbLevel.three;
    if (orbA.level == OrbLevel.one) {
      if (random.nextDouble() < modifiers.jumpToThreeChance) {
        newLevel = OrbLevel.three;
      }
      // Martillo del Titán: Nivel 3 garantizado con 50%.
      if (newLevel == OrbLevel.two &&
          random.nextDouble() < modifiers.threeMergeChance) {
        newLevel = OrbLevel.three;
      }
    }
    // Martillo del Titán: ninguna fusión produce menos del nivel mínimo.
    if (newLevel.index + 1 < modifiers.minMergeLevel) {
      newLevel = OrbLevel.values[modifiers.minMergeLevel - 1];
    }
    tray[b] = CombatOrb(
      id: _nextId('orb'),
      element: element,
      level: newLevel,
    );
    tray[a] = null;
    onTrayChanged?.call();
    trauma = (trauma + 0.25).clamp(0.0, 1.0);
    final mergeX = CombatEngine.layoutWidth / 5 * (b + 0.5);
    final mergeY = (CombatEngine.trayY + CombatEngine.layoutHeight) / 2;
    onMerge?.call(newLevel, mergeX, mergeY, element);
    if (newLevel == OrbLevel.three) mergesToThree++;
    return newLevel;
  }

  void swapOrbs(int a, int b) {
    final tmp = tray[a];
    tray[a] = tray[b];
    tray[b] = tmp;
    onTrayChanged?.call();
  }

  // ------------------------------------------------------------- main tick

  void tick(double dt) {
    if (finished || dt <= 0) return;
    if (hitStopRemaining > 0) {
      final consumed = math.min(dt, hitStopRemaining);
      hitStopRemaining -= consumed;
      final rest = dt - consumed;
      if (rest <= 0) {
        trauma = math.max(0, trauma - consumed);
        return;
      }
      dt = rest;
    }

    final timeScale = slowMoRemaining > 0 ? 0.25 : 1.0;
    slowMoRemaining = math.max(0, slowMoRemaining - dt);
    final scaled = dt * timeScale;
    time += scaled;
    trauma = math.max(0, trauma - scaled * 1.2);

    _tickTimers(scaled);
    _tickSpawner(scaled);
    _tickProjectiles(scaled);
    _tickEnemyProjectiles(scaled);
    _tickBoss(scaled);
    tickEnrage(scaled);
    _tickMutators(scaled);
    _tickTexts(scaled);

    // Block 3: Tick boss shield break timer.
    if (bossShieldBroken) {
      bossBreakTimer = math.max(0, bossBreakTimer - scaled);
      if (bossBreakTimer <= 0) {
        bossShieldBroken = false;
      }
    }

    if (bossHp <= 0) {
      finished = true;
      victory = true;
      slowMoRemaining = 0.30;
      onVictory?.call();
    } else if (playerHp <= 0) {
      // Corazón de Fénix: revive una vez con 30% de vida y esferas Nivel 3.
      if (modifiers.phoenixRevive && !_phoenixUsed) {
        _phoenixUsed = true;
        playerHp = playerMaxHp * 0.30;
        for (var i = 0; i < tray.length; i++) {
          final orb = tray[i];
          tray[i] = CombatOrb(
            id: _nextId('orb'),
            element: orb?.element ?? Element.values[random.nextInt(4)],
            level: OrbLevel.three,
          );
        }
        texts.add(
          FloatingText(
            id: _nextId('txt'),
            text: '¡FÉNIX RENACE!',
            x: bossScreenX,
            y: bossScreenY,
            kind: FloatingTextKind.skill,
          ),
        );
        return;
      }
      finished = true;
      victory = false;
      onDefeat?.call();
    }
  }

  /// Block 3: Auto-Battle AI tick.
  /// Called every 0.75s (adjusted by speedMultiplier) when autoBattleEnabled is true.
  /// Priority: 1) Cast skill if any card has mana >= cost.
  ///          2) Merge two orbs of same element and level (< 3).
  ///          3) Fire highest level orb at active target (prioritize weak element).
  void tickAutoBattle(double speedMultiplier) {
    if (!autoBattleEnabled || finished) return;

    // 1) Try to cast a skill if any card has enough mana.
    for (var i = 0; i < cards.length; i++) {
      final c = cards[i];
      final effectiveCost =
          (c.baseManaCost - c.skillManaCostReduction).clamp(0, c.baseManaCost);
      if (c.mana >= effectiveCost) {
        castSkill(i);
        return;
      }
    }

    // 2) Try to merge two orbs of same element and level (< 3).
    for (var i = 0; i < tray.length; i++) {
      final orb1 = tray[i];
      if (orb1 == null || orb1.level == OrbLevel.three) continue;
      for (var j = i + 1; j < tray.length; j++) {
        final orb2 = tray[j];
        if (orb2 == null ||
            orb2.level != orb1.level ||
            orb2.element != orb1.element) {
          continue;
        }
        // Merge them.
        _mergeOrbs(i, j);
        return;
      }
    }

    // 3) Fire the highest level orb at a target.
    // Prioritize weak element orbs.
    var bestOrbIndex = -1;
    var bestOrbLevel = -1;
    var bestIsWeak = false;

    for (var i = 0; i < tray.length; i++) {
      final orb = tray[i];
      if (orb == null) continue;
      final isWeak =
          elementalWeaknessMultiplier(orb.element, boss.element) > 1.0;
      final levelValue = orb.level.index;
      if (bestOrbIndex == -1 ||
          (isWeak && !bestIsWeak) ||
          (isWeak == bestIsWeak && levelValue > bestOrbLevel)) {
        bestOrbIndex = i;
        bestOrbLevel = levelValue;
        bestIsWeak = isWeak;
      }
    }

    if (bestOrbIndex != -1 && targets.isNotEmpty) {
      // Find best target (prefer non-frozen, or first available).
      var targetIndex = 0;
      for (var i = 0; i < targets.length; i++) {
        if (!targets[i].frozen) {
          targetIndex = i;
          break;
        }
      }
      _fireOrbAtTarget(bestOrbIndex, targets[targetIndex]);
    }
  }

  /// Merges orbs at slot i and j (i < j).
  void _mergeOrbs(int i, int j) {
    final orb1 = tray[i]!;
    final orb2 = tray[j]!;
    final newLevel = OrbLevel
        .values[(orb1.level.index + 1).clamp(0, OrbLevel.values.length - 1)];
    tray[i] = CombatOrb(
      id: _nextId('orb'),
      element: orb1.element,
      level: newLevel,
      prismatic: orb1.prismatic || orb2.prismatic,
    );
    tray[j] = null;
    mergesToThree++;
    onMerge?.call(newLevel, _trayX(i), trayY, orb1.element);
  }

  /// Fires orb at slot index towards the given target.
  void _fireOrbAtTarget(int slotIndex, CombatTarget target) {
    final orb = tray[slotIndex];
    if (orb == null) return;
    tray[slotIndex] = null;
    final startX = _trayX(slotIndex);
    projectiles.add(
      OrbProjectile(
        id: _nextId('proj'),
        element: orb.element,
        level: orb.level,
        startX: startX,
        startY: trayY,
        targetX: target.xAt(time, effectiveAngularSpeed(target)),
        targetY: target.yAt(time, effectiveAngularSpeed(target)),
        flightDuration: 0.85,
      ),
    );
  }

  /// Returns the X coordinate of a tray slot center.
  double _trayX(int slot) {
    final slotW = layoutWidth / 5;
    return slotW * (slot + 0.5);
  }

  /// Mutadores con efecto continuo (sangrado del Pacto de Hemorragia).
  void _tickMutators(double s) {
    if (!has(SealMutator.bleedHeal)) return;
    if (trainingMode) return;
    playerHp -= playerMaxHp * 0.02 * s;
  }

  void _tickTimers(double s) {
    if (auraRemaining > 0) {
      auraRemaining -= s;
      if (auraRemaining <= 0) aura = null;
    }
    vulnerableRemaining = math.max(0, vulnerableRemaining - s);
    petrifyRemaining = math.max(0, petrifyRemaining - s);
    for (final t in targets) {
      if (t.frozenRemaining > 0) {
        t.frozenRemaining -= s;
        if (t.frozenRemaining <= 0) t.frozen = false;
      }
      if (t.enlargedUntil > 0) {
        t.enlargedUntil = math.max(0, t.enlargedUntil - s);
      }
    }
  }

  void _tickSpawner(double s) {
    spawnTimer += s;
    final interval = has(SealMutator.igneousAbyssalFast)
        ? spawnInterval * 0.5
        : spawnInterval;
    if (spawnTimer < interval) return;
    spawnTimer = 0;
    final empty = [
      for (var i = 0; i < tray.length; i++)
        if (tray[i] == null) i,
    ];
    if (empty.isEmpty) return;
    // Fill all empty slots (if all 5 are empty, this fills all 5)
    for (final slot in empty) {
      spawnOrbInSlot(slot);
    }
  }

  void _tickProjectiles(double s) {
    for (final p in List.of(projectiles)) {
      if (!p.alive) continue;
      p.elapsed += s;
      final z = CombatMath.flightZ(p.elapsed, p.flightDuration);

      // Counter-flick intercept: own orb crosses enemy orb mid-flight.
      for (final e in List.of(enemyProjectiles)) {
        if (!e.alive) continue;
        final ez = CombatMath.flightZ(e.elapsed, e.duration);
        final enemyZ = 1.0 - ez;
        if ((enemyZ - z).abs() >= CombatMath.interceptZWindow) continue;
        final ex = CombatMath.lerp(e.startX, e.endX, ez);
        final ey = CombatMath.lerp(e.startY, e.endY, ez);
        final px = _projectileX(p, z);
        final py = CombatMath.flightY(p.startY, p.targetY, z);
        final dist = math.sqrt((px - ex) * (px - ex) + (py - ey) * (py - ey));
        if (dist < CombatMath.projectileInterceptDistance) {
          _destroyEnemyProjectile(e, byCounterflick: true);
          if (p.level != OrbLevel.three) p.alive = false;
          trauma = (trauma + 0.4).clamp(0.0, 1.0);
          if (p.level == OrbLevel.three) {
            p.elapsed = p.flightDuration * 0.999; // pierce onward to boss
          }
          break;
        }
      }
      if (!p.alive) continue;

      if (z >= 1.0) {
        p.alive = false;
        _resolveArrival(p);
      }
    }
    projectiles.removeWhere((p) => !p.alive);
  }

  double _projectileX(OrbProjectile p, double z) =>
      CombatMath.lerp(p.startX, p.targetX, z);

  void _resolveArrival(OrbProjectile p) {
    final orb = CombatOrb(id: p.id, element: p.element, level: p.level);
    CombatTarget? best;
    var bestDist = double.infinity;
    var bestKind = HitKind.miss;
    for (final t in targets) {
      final tx = t.xAt(time, effectiveAngularSpeed(t));
      final ty = t.yAt(time, effectiveAngularSpeed(t));
      final d = math.sqrt(
        (p.targetX - tx) * (p.targetX - tx) +
            (p.targetY - ty) * (p.targetY - ty),
      );
      final kind = CombatMath.classifyHit(
        d,
        innerRadiusFor(t),
        outerRadiusFor(t),
      );
      if (_rank(kind) < _rank(bestKind) || (kind == bestKind && d < bestDist)) {
        best = t;
        bestDist = d;
        bestKind = kind;
      }
    }
    if (best == null || bestKind == HitKind.miss) {
      // Fallar corta la racha crítica.
      bullseyeStreak = 0;
      // Nyxara (Vacío) enrage: fallar un tiro drena 10 de maná al escuadrón.
      if (boss.id == 'nyxara' && enraged) {
        for (final c in cards) {
          c.mana = math.max(0, c.mana - 10);
        }
      }
      if (bestKind == HitKind.graze) {
        registerDamage(
          orb: orb,
          target: null,
          multiplier: 0.25,
          kind: HitKind.graze,
        );
      }
      return;
    }
    _resolveHit(orb, best, bestKind);
  }

  static int _rank(HitKind k) => switch (k) {
        HitKind.bullseye => 0,
        HitKind.normal => 1,
        HitKind.graze => 2,
        HitKind.miss => 3,
      };

  void _resolveHit(CombatOrb orb, CombatTarget target, HitKind kind) {
    var mult = CombatMath.hitMultiplier(kind, orb.level);
    if (vulnerableRemaining > 0) mult *= 1.3;
    registerDamage(orb: orb, target: target, multiplier: mult, kind: kind);

    final mana = CombatMath.hitMana(kind, orb.level) *
        modifiers.manaSpeedMult *
        (kind == HitKind.bullseye ? synergy?.bullseyeManaMult ?? 1.0 : 1.0);
    addManaToCards(orb.element, mana);

    if (CombatMath.appliesAura(kind, orb.level)) {
      applyAura(
        orb.element,
        orbLevel: orb.level.index + 1,
        prismatic: orb.prismatic,
      );
    }
    if (kind == HitKind.bullseye) {
      hitStopRemaining = 0.045;
      trauma = (trauma + 0.55).clamp(0.0, 1.0);
    }
    // Llama Eterna: la esfera Ígnea sobrevive al impacto.
    if (orb.element == Element.igneous &&
        random.nextDouble() < modifiers.igneousOrbSaveChance) {
      _returnOrbToTray(orb);
    }
  }

  /// Devuelve una esfera al primer hueco libre de la bandeja.
  void _returnOrbToTray(CombatOrb orb) {
    for (var i = 0; i < tray.length; i++) {
      if (tray[i] == null) {
        tray[i] = CombatOrb(
          id: _nextId('orb'),
          element: orb.element,
          level: orb.level,
          prismatic: orb.prismatic,
        );
        onTrayChanged?.call();
        return;
      }
    }
  }

  /// Applies an elemental imprint or detonates a reaction if one is pending.
  /// Returns the reaction name when one detonates.
  /// Duración efectiva del aura: base + Reloj de Ceniza + Yelmo + sinergia.
  double get auraDuration =>
      (ElementalReactionEngine.auraDuration + modifiers.auraDurationBonus) *
      (synergy?.auraDurationMult ?? 1.0) *
      _gearLoadout.auraDurationMult;

  String? applyAura(
    Element element, {
    int orbLevel = 1,
    bool prismatic = false,
  }) {
    if (aura == null) {
      aura = element;
      auraRemaining = auraDuration;
      return null;
    }
    if (aura == element) {
      auraRemaining = auraDuration;
      return null;
    }
    final engine = ElementalReactionEngine();
    var reaction = engine.checkReaction(aura!, element, orbLevel);
    // Prisma del Caos: una esfera prismática detona cualquier aura activa,
    // incluso combinaciones sin reacción definida.
    if (reaction == null && prismatic) {
      reaction = ReactionResult.prismaticDetonation();
    }
    if (reaction == null) return null;
    aura = null;
    auraRemaining = 0;
    _detonateReaction(reaction, element);
    onReaction?.call(reaction.name);
    reactions++;
    return reaction.name;
  }

  void _detonateReaction(ReactionResult r, Element element) {
    // Maestría Elemental + Crisol Alquímico (+300%).
    final mult = r.damageMultiplier *
        (synergy?.reactionDamageMult ?? 1.0) *
        _talentTree.reactionDamageMult *
        (has(SealMutator.reactionBoost) ? 4.0 : 1.0);
    if (mult > 1.0) {
      final base = baseDamage * mult;
      final hitCount = r.isAoE ? targets.length : 1;
      bossHp -= base * hitCount;
      texts.add(
        FloatingText(
          id: _nextId('txt'),
          text: r.name,
          x: bossScreenX,
          y: bossScreenY - 120,
          kind: FloatingTextKind.reaction,
          element: element,
        ),
      );
    }
    switch (r.name) {
      case 'Choque Térmico':
        for (final c in cards) {
          c.mana = (c.mana + c.baseManaCost * r.manaBonusPercent).clamp(
            0.0,
            c.baseManaCost.toDouble(),
          );
        }
      case 'Petrificación Abisal':
        petrifyRemaining = 6.0;
        bossAttackTimer += 3.5;
      case 'Colapso del Sello':
        playerHp = math.min(playerMaxHp, playerHp + playerMaxHp * 0.15);
        vulnerableRemaining = 4.0;
      case 'Detonación Prismática':
        vulnerableRemaining = 3.0;
      case 'Erupción Magmática':
        break;
      default:
        break;
    }
    if (modifiers.reactionMana > 0) {
      for (final c in cards) {
        c.mana = (c.mana + modifiers.reactionMana).clamp(
          0.0,
          c.baseManaCost.toDouble(),
        );
      }
    }
    slowMoRemaining = 0.30;
    trauma = (trauma + 0.7).clamp(0.0, 1.0);
  }

  void addManaToAllCards(double amount) {
    for (final c in cards) {
      c.mana = (c.mana + amount).clamp(0.0, c.baseManaCost.toDouble());
    }
  }

  void addManaToCards(Element element, double amount) {
    final manaMult = (leaderSkill?.manaGainMult ?? 1.0) *
        _talentTree.manaMult *
        (has(SealMutator.fastSmallManaBoost) ? 2.0 : 1.0);
    for (final c in cards) {
      final gain = amount *
          (c.element == element ? 1.0 : 0.25) *
          _effectiveManaSpeedMult *
          manaMult;
      c.mana = (c.mana + gain).clamp(0.0, c.baseManaCost.toDouble());
    }
  }

  /// Registers damage to the boss. Public for tests and external callers.
  void registerDamage({
    required CombatOrb orb,
    required CombatTarget? target,
    required double multiplier,
    required HitKind kind,
  }) {
    // Racha crítica: se actualiza antes de calcular el daño del golpe actual.
    if (kind == HitKind.bullseye) {
      bullseyeStreak++;
      if (bullseyeStreak > bestBullseyeStreak) {
        bestBullseyeStreak = bullseyeStreak;
      }
    } else if (kind == HitKind.normal || kind == HitKind.graze) {
      bullseyeStreak = 0;
    }

    final orbDmgMult = leaderSkill?.orbDamageMult ?? 1.0;
    final critMult =
        kind == HitKind.bullseye ? leaderSkill?.critBullseyeMult ?? 1.0 : 1.0;
    final talentMult = _talentTree.orbDamageMult *
        (kind == HitKind.bullseye ? _talentTree.bullseyeDamageMult : 1.0);
    final streakMult = kind == HitKind.bullseye ? bullseyeStreakBonus : 1.0;
    // Mutadores de Desafío del Sello.
    var mutatorMult = 1.0;
    if (has(SealMutator.bullseyeOnly) && kind != HitKind.bullseye) {
      mutatorMult = 0.0;
    }
    if (has(SealMutator.lvl3Only) && orb.level != OrbLevel.three) {
      mutatorMult = 0.0;
    }
    if (has(SealMutator.reactionBoost)) mutatorMult *= 0.20;
    if (has(SealMutator.skillDisabledOrbBoost)) mutatorMult *= 2.20;

    // Elemental weakness multiplier (+30% super-effective).
    final weaknessMult = elementalWeaknessMultiplier(orb.element, boss.element);

    // Block 3: Check if hitting shield with weak element or reaction.
    final isWeakHit =
        weaknessMult > 1.0 || (aura != null && aura != orb.element);
    final shieldDamageMult =
        (bossShieldHp > 0 && isWeakHit) ? shieldWeaknessMult : 1.0;

    // Block 3: Break state damage multiplier (+50% damage, +50% crit).
    final breakMult = bossShieldBroken ? bossBreakDamageMult : 1.0;
    final breakCritMult = bossShieldBroken ? bossBreakCritMult : 1.0;

    final rawDamage = baseDamage *
        multiplier *
        playerDamageMult *
        orbDmgMult *
        critMult *
        talentMult *
        streakMult *
        mutatorMult *
        weaknessMult *
        breakMult *
        shieldDamageMult *
        breakCritMult;
    // Anti-cheat: NaN/infinitos/negativos se descartan; los valores inyectados
    // por encima del techo legal se recortan y quedan registrados.
    final dmg = sanityGuard.sanitize(rawDamage);

    // Block 3: Apply damage to shield first, then to HP.
    if (bossShieldHp > 0 && !bossShieldBroken) {
      final shieldDmg = math.min(bossShieldHp, dmg);
      bossShieldHp -= shieldDmg;
      if (bossShieldHp <= 0) {
        _triggerShieldBreak();
      }
    } else {
      bossHp -= dmg;
    }
    damageTotal += dmg.toInt();
    if (dmg > maxHit) maxHit = dmg;
    if (kind == HitKind.bullseye) {
      bullseyes++;
      // Colmillo Vampírico (+2%) y Pacto de Hemorragia (+5%).
      final healFraction = modifiers.bullseyeHealFraction +
          (has(SealMutator.bleedHeal) ? 0.05 : 0.0);
      if (healFraction > 0) {
        playerHp = math.min(playerMaxHp, playerHp + playerMaxHp * healFraction);
      }
    }
    final x = target?.xAt(time, effectiveAngularSpeed(target)) ?? bossScreenX;
    final y = target?.yAt(time, effectiveAngularSpeed(target)) ?? bossScreenY;
    // Floating text: show SUPEREFICAZ when hitting elemental weakness.
    final isSuperEffective = weaknessMult > 1.0 && kind != HitKind.miss;
    texts.add(
      FloatingText(
        id: _nextId('txt'),
        text: switch (kind) {
          HitKind.bullseye => isSuperEffective
              ? '¡SUPEREFICAZ -${dmg.toInt()}!'
              : '¡CRÍTICO -${dmg.toInt()}!',
          HitKind.normal => isSuperEffective
              ? '¡SUPEREFICAZ -${dmg.toInt()}!'
              : '-${dmg.toInt()}',
          HitKind.graze => isSuperEffective
              ? '¡SUPEREFICAZ -${dmg.toInt()}!'
              : '-${dmg.toInt()}',
          HitKind.miss => '',
        },
        x: x,
        y: y,
        kind: isSuperEffective
            ? FloatingTextKind.superEffective
            : (kind == HitKind.bullseye
                ? FloatingTextKind.crit
                : FloatingTextKind.normal),
      ),
    );
    // Block 3: Show shield break banner.
    if (bossShieldHp <= 0 && !bossShieldBroken && boss.shieldHp > 0) {
      texts.add(
        FloatingText(
          id: _nextId('txt'),
          text: '¡RUPTURA DE SELLO! DAÑO CRÍTICO +50%',
          x: bossScreenX,
          y: bossScreenY - 180,
          kind: FloatingTextKind.skill,
          element: orb.element,
        ),
      );
    }
    // Nyxara (Vacío) enrage: fallar un tiro drena 10 de maná al escuadrón.
    if (boss.id == 'nyxara' && kind == HitKind.miss) {
      for (final c in cards) {
        c.mana = math.max(0, c.mana - 10);
      }
    }
    trauma = (trauma + 0.25).clamp(0.0, 1.0);
    onHit?.call(kind, dmg.toInt(), x, y, orb.element);
  }

  /// Block 3: Triggers the Shield Break state when boss shield is depleted.
  void _triggerShieldBreak() {
    if (bossShieldBroken) return;
    bossShieldBroken = true;
    onShieldBreak?.call();
    bossBreakTimer = bossBreakDuration;
    // Stun boss: stop attacks for 5s.
    bossStunRemaining = bossBreakDuration;
    // Enlarge targets by 35% and freeze them.
    for (final t in targets) {
      t.enlargedUntil = bossBreakDuration;
      t.frozen = true;
      t.frozenRemaining = bossBreakDuration;
    }
  }

  // New reaction mana from relic Sello de Resonancia (kept out of const ctor).
  // Hover harness: expose via extension below.

  void _tickEnemyProjectiles(double s) {
    for (final e in List.of(enemyProjectiles)) {
      if (!e.alive) continue;
      e.elapsed += s;
      final ez = CombatMath.flightZ(e.elapsed, e.duration);
      if (ez >= 1.0) {
        e.alive = false;
        hitPlayer();
      }
    }
    enemyProjectiles.removeWhere((e) => !e.alive);
  }

  void hitPlayer() {
    final dmg = boss.attackDamage;
    final absorbed = math.min(shield, dmg);
    shield -= absorbed;
    final taken = (dmg - absorbed) *
        (leaderSkill?.damageTakenMult ?? 1.0) *
        _talentTree.damageTakenMult *
        modifiers.damageTakenMult;
    playerHp -= taken;
    trauma = (trauma + 0.45).clamp(0.0, 1.0);
  }

  void _tickBoss(double s) {
    if (bossStunRemaining > 0) {
      bossStunRemaining -= s;
      return;
    }
    bossAttackTimer -= s;
    if (bossAttackTimer > 0) return;
    bossAttackTimer = boss.attackInterval * modifiers.bossAttackIntervalMult;
    final count = bossProjectileCount;
    for (var i = 0; i < count; i++) {
      enemyProjectiles.add(
        EnemyProjectile(
          id: _nextId('enemy'),
          startX: bossScreenX + (random.nextDouble() * 120 - 60),
          startY: bossScreenY,
          endX: layoutWidth / 5 * (0.5 + random.nextInt(5)) - 43,
          endY: trayY - 40 - random.nextDouble() * 120,
          duration: 1.65 + random.nextDouble() * 0.2,
        ),
      );
    }
  }

  /// Boss enrage phase 2 triggers below 45% HP. Each boss gains a unique
  /// passive and the Flame layer renders the enrage visuals (palette shift,
  /// +15% scale, extra reticle).
  void tickEnrage(double s) {
    _tickEnrage(s);
  }

  void _tickEnrage(double s) {
    final hpFraction = bossHp / boss.maxHp;
    if (!enraged && hpFraction < 0.45) {
      enraged = true;
      onEnrage?.call();
    }
    if (!enraged) return;

    _enrageTimer += s;

    // Phase 2 passives per boss id.
    switch (boss.id) {
      case 'pyroth':
        _tickPyrothEnrage(s);
        break;
      case 'vaelor':
        _tickVaelorEnrage(s);
        break;
      case 'azathor':
        _tickAzathorEnrage(s);
        break;
      case 'gorgath':
        _tickGorgathEnrage(s);
        break;
      case 'nyxara':
        _tickNyxaraEnrage(s);
        break;
    }
  }

  /// Pyroth (Ígneo): burns 1 random tray slot for 4.0s. Tapping the burned
  /// slot twice extinguishes the fire (handled via extinguishBurnSlot()).
  void _tickPyrothEnrage(double s) {
    _burnRemaining = math.max(0, _burnRemaining - s);
    if (_burnRemaining <= 0 && _burnedSlot >= 0) {
      _burnedSlot = -1;
    }
    if (_burnRemaining <= 0) {
      _burnRemaining = 4.0;
      final fill = [
        for (var i = 0; i < tray.length; i++)
          if (tray[i] != null && i != _burnedSlot) i,
      ];
      if (fill.isNotEmpty) {
        _burnedSlot = fill[random.nextInt(fill.length)];
      }
    }
  }

  /// Extinguishes a Pyroth burn on [slot] if it has been tapped twice (calls
  /// must be rate-limited by the caller). Returns true if a burn was active.
  bool extinguishBurnSlot(int slot) {
    if (_burnedSlot == slot) {
      _burnedSlot = -1;
      _burnRemaining = 0;
      return true;
    }
    return false;
  }

  /// Returns true if [slot] is currently burned by Pyroth's enrage.
  bool isSlotBurned(int slot) => _burnedSlot == slot && _burnRemaining > 0;

  /// Vaelor (Abyssal): ice-shields one target. Requires a hit first (or an
  /// Igneous orb) to break the shield.
  void _tickVaelorEnrage(double s) {
    _iceShieldRemaining = math.max(0, _iceShieldRemaining - s);
    if (_iceShieldRemaining <= 0) {
      _iceShieldActive = false;
      // Re-shield a random target every ~6s while enraged.
      if (targets.isNotEmpty && _enrageTimer > 0) {
        // Re-shield cooldown handled by attack interval cadence.
        if (targets.any((t) => !t.frozen)) {
          final t = targets[random.nextInt(targets.length)];
          t.frozen = true;
          t.frozenRemaining = 999.0; // ice shield: permanent until broken
          _iceShieldActive = true;
          _iceShieldRemaining = 6.0;
        }
      }
    }
  }

  /// Breaks Vaelor's ice shield on [target] when hit by an Igneous orb or
  /// after the shield has taken damage. Returns true if a shield was broken.
  bool breakIceShield(CombatTarget target, {required bool byIgneous}) {
    if (!_iceShieldActive || !target.frozen || target.frozenRemaining < 999.0) {
      return false;
    }
    if (!byIgneous) {
      return false;
    }
    target.frozen = false;
    target.frozenRemaining = 0;
    _iceShieldActive = false;
    _iceShieldRemaining = 0;
    return true;
  }

  /// Azathor (Vacío): inverts target rotation every 5.0s and fires double
  /// counter-flick projectiles.
  void _tickAzathorEnrage(double s) {
    _rotationInvertUntil = math.max(0, _rotationInvertUntil - s);
    if (_rotationInvertUntil <= 0) {
      _rotationInverted = !_rotationInverted;
      _rotationInvertUntil = 5.0;
    }
    // Double counter-flick: Azathor fires 2 projectiles per attack instead
    // of the configured count when enraged (handled in _tickBoss via
    // projectilesPerAttack boost).
  }

  /// Gorgath (Telúrico): petrifica por 4.0s la carta con más maná y reduce
  /// un 20% el radio de las dianas mientras está enfurecido.
  void _tickGorgathEnrage(double s) {
    _gorgathPetrifyRemaining = math.max(0, _gorgathPetrifyRemaining - s);
    if (_gorgathPetrifyRemaining <= 0 && cards.isNotEmpty) {
      final leader = cards.reduce(
        (a, b) => a.mana > b.mana ? a : b,
      );
      _gorgathPetrifiedCardId = leader.id;
      _gorgathPetrifyRemaining = 4.0;
    }
    if (boss.id == 'gorgath') {
      for (final t in targets) {
        t.enlargedRadiusBonus = -0.2;
      }
    }
  }

  /// Nyxara (Vacío): teletransporta las dianas cada 4.0s durante el enrage.
  void _tickNyxaraEnrage(double s) {
    _nyxaraTeleportRemaining = math.max(0, _nyxaraTeleportRemaining - s);
    if (_nyxaraTeleportRemaining <= 0 && targets.isNotEmpty) {
      for (final t in targets) {
        t.cx = bossScreenX + 85.0 - random.nextDouble() * 120;
        t.cy = bossScreenY - 30.0 - random.nextDouble() * 100;
      }
      _nyxaraTeleportRemaining = 4.0;
    }
  }

  /// Number of enemy projectiles per boss attack (doubled for Azathor enrage).
  int get bossProjectileCount {
    var base = 1 + random.nextInt(boss.projectilesPerAttack);
    if (enraged && boss.id == 'azathor') base *= 2;
    // Lluvia Corrupta: el jefe dispara el doble.
    if (has(SealMutator.bossDoubleProjectiles)) base *= 2;
    return base;
  }

  /// Whether Azathor's enrage rotation is currently inverted (for tests).
  bool get rotationInverted => _rotationInverted;

  /// Id of the card petrified by Gorgath during enrage (null if none).
  String? get gorgathPetrifiedCardId => _gorgathPetrifiedCardId;

  /// Remaining petrify duration for Gorgath (tests).
  double get gorgathPetrifyRemaining => _gorgathPetrifyRemaining;

  /// Target radius multiplier (0.8 with Gorgath enraged).
  double get targetRadiusMult => enraged && boss.id == 'gorgath' ? 0.8 : 1.0;

  /// Remaining time until Nyxara's next teleport (tests).
  double get nyxaraTeleportRemaining => _nyxaraTeleportRemaining;

  /// Current enrage timer value (for tests).
  double get enrageTimer => _enrageTimer;

  /// Currently burned tray slot index, or null (for tests).
  int? get burnedSlot => _burnedSlot;

  /// Remaining burn duration in seconds (for tests).
  double get burnRemaining => _burnRemaining;

  void _tickTexts(double s) {
    for (final t in texts) {
      t.age += s;
    }
    texts.removeWhere((t) => t.age > 0.75);
  }

  void _destroyEnemyProjectile(
    EnemyProjectile e, {
    required bool byCounterflick,
  }) {
    e.alive = false;
    if (!byCounterflick) return;
    counterflicks++;
    addManaToAllCards(counterflickMana * modifiers.manaSpeedMult);
    // Muralla de Espejos: cada Counter-Flick refleja 12% del HP máximo.
    if (has(SealMutator.counterflickReflect)) {
      final reflected = boss.maxHp * 0.12;
      bossHp -= reflected;
      damageTotal += reflected.toInt();
      if (reflected > maxHit) maxHit = reflected;
    }
    if (cards.isEmpty) return;
    texts.add(
      FloatingText(
        id: _nextId('txt'),
        text: '¡CONTRAATAQUE!',
        x: CombatMath.lerp(
          e.startX,
          e.endX,
          1 - CombatMath.flightZ(e.elapsed, e.duration),
        ),
        y: CombatMath.lerp(
          e.startY,
          e.endY,
          1 - CombatMath.flightZ(e.elapsed, e.duration),
        ),
        kind: FloatingTextKind.skill,
      ),
    );
    if (modifiers.counterflickHealFraction > 0) {
      playerHp = math.min(
        playerMaxHp,
        playerHp + playerMaxHp * modifiers.counterflickHealFraction,
      );
    }
  }

  // ------------------------------------------------------------ skills TCG

  /// Consumes the mana of card [index] and executes its active skill.
  /// Returns false if the card is not ready or the fight is over.
  bool castSkill(int index) {
    // Silencio de Cartas: las habilidades activas están selladas.
    if (has(SealMutator.skillDisabledOrbBoost)) return false;
    if (finished || index < 0 || index >= cards.length) return false;
    final c = cards[index];
    final cost = _effectiveManaCost(c);
    if (c.mana < cost) return false;
    c.mana = (c.mana - cost).clamp(0.0, double.infinity);
    texts.add(
      FloatingText(
        id: _nextId('txt'),
        text: c.name,
        x: bossScreenX,
        y: bossScreenY - 150,
        kind: FloatingTextKind.skill,
      ),
    );
    final atk = _effectiveAttack(c) * playerDamageMult;
    final vuln = vulnerableRemaining > 0 ? 1.3 : 1.0;
    void aoeSkillDamage(double mult) => _skillDamageAll(atk * mult * vuln);
    void singleSkillDamage(double mult) =>
        _skillDamageSingle(atk * mult * vuln);

    switch (c.id) {
      case 'ignis_hound':
        // 3 guided bites round-robin over the targets.
        for (var i = 0; i < 3; i++) {
          final t = targets[i % math.max(1, targets.length)];
          texts.add(
            FloatingText(
              id: _nextId('txt'),
              text: '${(atk * 1.1 * vuln).toInt()}',
              x: t.xAt(time, effectiveAngularSpeed(t)),
              y: t.yAt(time, effectiveAngularSpeed(t)),
              kind: FloatingTextKind.normal,
            ),
          );
        }
        bossHp -= atk * 1.1 * vuln * 3;
        applyAura(Element.igneous);
      case 'ignis_lord':
        aoeSkillDamage(3.5);
        applyAura(Element.igneous);
      case 'abyss_stalker':
        singleSkillDamage(2.4);
        applyAura(Element.abyssal);
      case 'abyss_leviathan':
        for (final e_ in enemyProjectiles) {
          e_.alive = false;
        }
        enemyProjectiles.clear();
        for (final t in targets) {
          t.frozen = true;
          t.frozenRemaining = 4.5;
        }
        aoeSkillDamage(2.8);
        applyAura(Element.abyssal);
      case 'terra_golem':
        shield += playerMaxHp * 0.25;
        aoeSkillDamage(1.5);
        applyAura(Element.telluric);
      case 'terra_titan':
        bossStunRemaining = 3.0;
        for (final t in targets) {
          t.enlargedUntil = time + 8.0;
          t.enlargedRadiusBonus = 0.35;
        }
        aoeSkillDamage(2.6);
        applyAura(Element.telluric);
      case 'void_specter':
        playerHp = math.min(playerMaxHp, playerHp + atk * 1.8);
        for (var i = 0; i < 2; i++) {
          _upgradeRandomOrb();
        }
        applyAura(Element.empty);
      case 'void_malakor':
        for (var i = 0; i < tray.length; i++) {
          final orb = tray[i];
          tray[i] = CombatOrb(
            id: _nextId('orb'),
            element: orb?.element ?? Element.values[random.nextInt(4)],
            level: OrbLevel.three,
          );
        }
        aoeSkillDamage(3.2);
        applyAura(Element.empty);
      case 'ignis_drake':
        singleSkillDamage(1.8);
        applyAura(Element.igneous);
      case 'ignis_seraph':
        aoeSkillDamage(3.0);
        applyAura(Element.igneous);
      case 'ignis_colossus':
        aoeSkillDamage(4.5);
        bossStunRemaining = 2.0;
        applyAura(Element.igneous);
      case 'abyss_siren':
        singleSkillDamage(1.8);
        for (final t in targets) {
          t.frozen = true;
          t.frozenRemaining = 2.0;
        }
        applyAura(Element.abyssal);
      case 'abyss_kraken':
        aoeSkillDamage(2.8);
        applyAura(Element.abyssal);
      case 'abyss_wraith':
        aoeSkillDamage(3.6);
        for (final t in targets) {
          t.frozen = true;
          t.frozenRemaining = 4.0;
        }
        applyAura(Element.abyssal);
      case 'terra_warden':
        shield += playerMaxHp * 0.25;
        applyAura(Element.telluric);
      case 'terra_hydra':
        aoeSkillDamage(2.6);
        applyAura(Element.telluric);
      case 'terra_behemoth':
        aoeSkillDamage(4.0);
        bossStunRemaining = 2.5;
        applyAura(Element.telluric);
      case 'void_reaper':
        singleSkillDamage(2.0);
        playerHp = math.min(playerMaxHp, playerHp + atk * 1.0);
        applyAura(Element.empty);
      case 'void_oracle':
        aoeSkillDamage(3.2);
        applyAura(Element.empty);
      case 'void_archon':
        aoeSkillDamage(4.8);
        vulnerableRemaining = 4.0;
        applyAura(Element.empty);
    }
    // Runa de Vampirismo Abisal: curar al jugador al activar la habilidad.
    final rune = cardRunes[c.id];
    if (rune != null && rune.type == RuneType.voidLeech) {
      final heal = playerMaxHp * RuneSystem.healOnSkill(rune.type, rune.level);
      playerHp = math.min(playerMaxHp, playerHp + heal);
    }
    // Runa de Eco Gemelo: probabilidad de disparar la habilidad dos veces sin costo.
    if (rune != null && rune.type == RuneType.twinEcho) {
      final chance = RuneSystem.doubleCastChance(rune.type, rune.level);
      if (random.nextDouble() < chance) {
        // Doble disparo: repetir el mismo skill sin consumir maná adicional.
        // Se re-ejecuta la lógica de daño del switch sobre la misma carta.
        _applySkillDamage(c, atk, vuln);
      }
    }
    trauma = (trauma + 0.5).clamp(0.0, 1.0);
    hitStopRemaining = 0.045;
    // Cinematic hook: fires once per successful invocation (also for AUTO).
    onSkillCast?.call(c, index);
    return true;
  }

  /// Re-aplica el daño de la habilidad de [c] para el Eco Gemelo (segundo disparo sin costo).
  void _applySkillDamage(ManaCard c, double atk, double vuln) {
    void aoeSkillDamage(double mult) => _skillDamageAll(atk * mult * vuln);
    void singleSkillDamage(double mult) =>
        _skillDamageSingle(atk * mult * vuln);
    switch (c.id) {
      case 'ignis_hound':
        for (var i = 0; i < 3; i++) {
          bossHp -= atk * 1.1 * vuln;
        }
        applyAura(Element.igneous);
      case 'ignis_lord':
        aoeSkillDamage(3.5);
        applyAura(Element.igneous);
      case 'abyss_stalker':
        singleSkillDamage(2.4);
        applyAura(Element.abyssal);
      case 'abyss_leviathan':
        aoeSkillDamage(2.8);
        applyAura(Element.abyssal);
      case 'terra_golem':
        aoeSkillDamage(1.5);
        applyAura(Element.telluric);
      case 'terra_titan':
        aoeSkillDamage(2.6);
        applyAura(Element.telluric);
      case 'void_specter':
        playerHp = math.min(playerMaxHp, playerHp + atk * 1.8);
        applyAura(Element.empty);
      case 'void_malakor':
        aoeSkillDamage(3.2);
        applyAura(Element.empty);
      case 'ignis_drake':
        singleSkillDamage(1.8);
        applyAura(Element.igneous);
      case 'ignis_seraph':
        aoeSkillDamage(3.0);
        applyAura(Element.igneous);
      case 'ignis_colossus':
        aoeSkillDamage(4.5);
        applyAura(Element.igneous);
      case 'abyss_siren':
        singleSkillDamage(1.8);
        applyAura(Element.abyssal);
      case 'abyss_kraken':
        aoeSkillDamage(2.8);
        applyAura(Element.abyssal);
      case 'abyss_wraith':
        aoeSkillDamage(3.6);
        applyAura(Element.abyssal);
      case 'terra_warden':
        applyAura(Element.telluric);
      case 'terra_hydra':
        aoeSkillDamage(2.6);
        applyAura(Element.telluric);
      case 'terra_behemoth':
        aoeSkillDamage(4.0);
        applyAura(Element.telluric);
      case 'void_reaper':
        singleSkillDamage(2.0);
        applyAura(Element.empty);
      case 'void_oracle':
        aoeSkillDamage(3.2);
        applyAura(Element.empty);
      case 'void_archon':
        aoeSkillDamage(4.8);
        applyAura(Element.empty);
      default:
        break;
    }
  }

  void _skillDamageAll(double dmg) {
    bossHp -= dmg * math.max(1, targets.length);
    for (final t in targets) {
      texts.add(
        FloatingText(
          id: _nextId('txt'),
          text: '${(dmg).toInt()}',
          x: t.xAt(time, effectiveAngularSpeed(t)),
          y: t.yAt(time, effectiveAngularSpeed(t)),
          kind: FloatingTextKind.normal,
        ),
      );
    }
  }

  void _skillDamageSingle(double dmg) {
    bossHp -= dmg;
    if (targets.isNotEmpty) {
      final t = targets.first;
      texts.add(
        FloatingText(
          id: _nextId('txt'),
          text: '${dmg.toInt()}',
          x: t.xAt(time, effectiveAngularSpeed(t)),
          y: t.yAt(time, effectiveAngularSpeed(t)),
          kind: FloatingTextKind.crit,
        ),
      );
    }
  }

  void _upgradeRandomOrb() {
    final filled = [
      for (var i = 0; i < tray.length; i++)
        if (tray[i] != null && tray[i]!.level != OrbLevel.three) i,
    ];
    if (filled.isEmpty) return;
    final i = filled[random.nextInt(filled.length)];
    final orb = tray[i]!;
    tray[i] = CombatOrb(
      id: _nextId('orb'),
      element: orb.element,
      level: orb.level == OrbLevel.one ? OrbLevel.two : OrbLevel.three,
    );
  }

  /// Skill metadata used by the HUD banner (id -> display description).
  static const Map<String, String> skillDescriptions = {
    'ignis_hound': '3 mordiscos teledirigidos + aura Ígnea',
    'ignis_lord': 'Meteoro masivo a todas las dianas + aura Ígnea',
    'abyss_stalker': 'Estaca glacial crítica + aura Abisal',
    'abyss_leviathan': 'Rompe proyectiles, congela dianas 4.5s',
    'terra_golem': 'Escudo 25% HP + montaña + aura Telúrica',
    'terra_titan': 'Aturde 3s, dianas +35% radio, terremoto',
    'void_specter': 'Drena vida, sube +1 nivel a 2 esferas',
    'void_malakor': 'Transfiere bandeja a Nivel 3 + grieta abisal',
    'ignis_drake': 'Ráfaga de escoria 1.8x + aura Ígnea',
    'ignis_seraph': 'Descendencia de ceniza 3.0x a todas + aura Ígnea',
    'ignis_colossus': 'Erupción del cráter 4.5x + aturde 2s',
    'abyss_siren': 'Canto glacial 1.8x + congela 2s + aura Abisal',
    'abyss_kraken': 'Tentáculos abisales 2.8x a todas + aura Abisal',
    'abyss_wraith': 'Lamento glacial 3.6x + congela 4s + aura Abisal',
    'terra_warden': 'Piel de obsidiana: escudo + aura Telúrica',
    'terra_hydra': 'Múltiples cabezas 2.6x a todas + aura Telúrica',
    'terra_behemoth': 'Temblor 4.0x + aturde 2.5s + aura Telúrica',
    'void_reaper': 'Hoja del vacío 2.0x + drena vida + aura Vacío',
    'void_oracle': 'Eclipse lunar 3.2x a todas + aura Vacío',
    'void_archon': "Juicio del Arconte 4.8x + vulnera + aura Vacío",
  };
}

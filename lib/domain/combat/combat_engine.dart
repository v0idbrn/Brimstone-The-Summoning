import 'dart:math' as math;

import '../services/elemental_reaction_engine.dart';
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

  const CombatModifiers({
    this.critRadiusMult = 1.0,
    this.igneousLevel2Chance = 0.0,
    this.jumpToThreeChance = 0.0,
    this.manaSpeedMult = 1.0,
    this.startManaFraction = 0.0,
    this.startHpLossFraction = 0.0,
    this.counterflickHealFraction = 0.0,
    this.reactionMana = 0.0,
  });

  /// Builds modifiers from a set of active relic ids.
  factory CombatModifiers.fromRelics(Iterable<String> relicIds) {
    var m = const CombatModifiers();
    for (final id in relicIds) {
      switch (id) {
        case 'ojo_abismo':
          m = CombatModifiers(
            critRadiusMult: 1.4,
            igneousLevel2Chance: m.igneousLevel2Chance,
            jumpToThreeChance: m.jumpToThreeChance,
            manaSpeedMult: m.manaSpeedMult,
            startManaFraction: m.startManaFraction,
            startHpLossFraction: m.startHpLossFraction,
            counterflickHealFraction: m.counterflickHealFraction,
          );
        case 'ceniza_volatil':
          m = CombatModifiers(
            critRadiusMult: m.critRadiusMult,
            igneousLevel2Chance: 0.35,
            jumpToThreeChance: m.jumpToThreeChance,
            manaSpeedMult: m.manaSpeedMult,
            startManaFraction: m.startManaFraction,
            startHpLossFraction: m.startHpLossFraction,
            counterflickHealFraction: m.counterflickHealFraction,
          );
        case 'sello_resonancia':
          m = _with(m, reactionMana: 20.0);
        case 'pacto_sangre':
          m = _with(m, manaSpeedMult: 1.5, startHpLossFraction: 0.08);
        case 'forja_perpetua':
          m = _with(m, jumpToThreeChance: 0.25);
        case 'coraza_obsidiana':
          m = _with(m, counterflickHealFraction: 0.04);
      }
    }
    return m;
  }

  static CombatModifiers _with(
    CombatModifiers base, {
    double? critRadiusMult,
    double? igneousLevel2Chance,
    double? jumpToThreeChance,
    double? manaSpeedMult,
    double? startManaFraction,
    double? startHpLossFraction,
    double? counterflickHealFraction,
    double? reactionMana,
  }) => CombatModifiers(
    critRadiusMult: critRadiusMult ?? base.critRadiusMult,
    igneousLevel2Chance: igneousLevel2Chance ?? base.igneousLevel2Chance,
    jumpToThreeChance: jumpToThreeChance ?? base.jumpToThreeChance,
    manaSpeedMult: manaSpeedMult ?? base.manaSpeedMult,
    startManaFraction: startManaFraction ?? base.startManaFraction,
    startHpLossFraction: startHpLossFraction ?? base.startHpLossFraction,
    counterflickHealFraction:
        counterflickHealFraction ?? base.counterflickHealFraction,
    reactionMana: reactionMana ?? base.reactionMana,
  );
}

/// Pure Dart combat simulation. The Flame layer only renders and feeds input.
class CombatEngine {
  static const double layoutWidth = 430.0;
  static const double layoutHeight = 932.0;
  static const double bossScreenX = layoutWidth * 0.50;
  static const double bossScreenY = layoutHeight * 0.32;
  static const double trayY = layoutHeight * 0.84;
  static const double spawnInterval = 1.2;
  static const double baseDamage = 35.0;
  static const double outerRadius = 46.0;
  static const double innerRadius = 20.0;
  static const double counterflickMana = 20.0;
  // (reactionManaBonus kept as named constant for HUD reference)

  final BossConfig boss;
  final CombatModifiers modifiers;
  final List<ManaCard> cards;
  final List<CombatTarget> targets = [];
  final math.Random random;

  // Boss / player state.
  double bossHp;
  final double playerMaxHp;
  double playerHp;
  double shield = 0;

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
  final List<FloatingText> texts = [];

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

  /// Optional external callbacks (wired by the Flame layer).
  void Function()? onVictory;
  void Function()? onDefeat;

  CombatEngine({
    required this.boss,
    required this.cards,
    double? playerMaxHp,
    CombatModifiers? modifiers,
    math.Random? random,
  }) : modifiers = modifiers ?? const CombatModifiers(),
       playerMaxHp = playerMaxHp ?? 100,
       random = random ?? math.Random(),
       bossHp = boss.maxHp,
       playerHp = playerMaxHp ?? 100,
       bossAttackTimer = boss.attackInterval {
    _spawnTargetRing();
    _applyStartModifiers();
  }

  void _spawnTargetRing() {
    final count = 2 + random.nextInt(3); // 2 to 4 targets
    for (var i = 0; i < count; i++) {
      targets.add(
        CombatTarget(
          id: 'target_$i',
          trajectory: TargetTrajectory.values[i % 3],
          cx: bossScreenX + 85.0 - (i % 2 == 0 ? 60.0 : 10.0),
          cy: bossScreenY - 30.0 - i * 18.0,
          amplitude: 70.0 + i * 14.0,
          baseAngularSpeed: 1.4 + i * 0.35,
          phase: i * 1.6,
        ),
      );
    }
  }

  void _applyStartModifiers() {
    if (modifiers.startManaFraction > 0) {
      for (final c in cards) {
        c.mana = c.baseManaCost * modifiers.startManaFraction;
      }
    }
    if (modifiers.startHpLossFraction > 0) {
      playerHp -= playerMaxHp * modifiers.startHpLossFraction;
    }
  }

  String _nextId(String prefix) => '${prefix}_${_idCounter++}';

  double effectiveAngularSpeed(CombatTarget t) =>
      t.baseAngularSpeed * (petrifyRemaining > 0 ? 0.5 : 1.0);

  double outerRadiusFor(CombatTarget t) {
    final enlarged = t.enlargedUntil > time
        ? (1.0 + t.enlargedRadiusBonus)
        : 1.0;
    return outerRadius * modifiers.critRadiusMult * enlarged;
  }

  double innerRadiusFor(CombatTarget t) {
    final enlarged = t.enlargedUntil > time
        ? (1.0 + t.enlargedRadiusBonus)
        : 1.0;
    return innerRadius * modifiers.critRadiusMult * enlarged;
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
    final element = Element.values[random.nextInt(4)];
    var level = OrbLevel.one;
    if (element == Element.igneous &&
        random.nextDouble() < modifiers.igneousLevel2Chance) {
      level = OrbLevel.two;
    }
    final orb = CombatOrb(id: _nextId('orb'), element: element, level: level);
    tray[slot] = orb;
    return orb;
  }

  OrbLevel? mergeOrbs(int a, int b) {
    final orbA = tray[a];
    final orbB = tray[b];
    if (orbA == null || orbB == null || a == b) return null;
    if (orbA.element != orbB.element || orbA.level != orbB.level) {
      swapOrbs(a, b);
      return null;
    }
    if (orbA.level == OrbLevel.three) {
      swapOrbs(a, b);
      return null;
    }
    var newLevel = orbA.level == OrbLevel.one ? OrbLevel.two : OrbLevel.three;
    if (orbA.level == OrbLevel.one &&
        random.nextDouble() < modifiers.jumpToThreeChance) {
      newLevel = OrbLevel.three;
    }
    tray[b] = CombatOrb(
      id: _nextId('orb'),
      element: orbA.element,
      level: newLevel,
    );
    tray[a] = null;
    trauma = (trauma + 0.25).clamp(0.0, 1.0);
    return newLevel;
  }

  void swapOrbs(int a, int b) {
    final tmp = tray[a];
    tray[a] = tray[b];
    tray[b] = tmp;
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
    _tickTexts(scaled);

    if (bossHp <= 0) {
      finished = true;
      victory = true;
      slowMoRemaining = 0.30;
      onVictory?.call();
    } else if (playerHp <= 0) {
      finished = true;
      victory = false;
      onDefeat?.call();
    }
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
    if (spawnTimer < spawnInterval) return;
    spawnTimer = 0;
    final empty = [
      for (var i = 0; i < tray.length; i++)
        if (tray[i] == null) i,
    ];
    if (empty.isEmpty) return;
    spawnOrbInSlot(empty[random.nextInt(empty.length)]);
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
            (bossScreenY - ty) * (bossScreenY - ty),
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
      if (bestKind == HitKind.graze) {
        _registerDamage(
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
    _registerDamage(orb: orb, target: target, multiplier: mult, kind: kind);

    final mana = CombatMath.hitMana(kind, orb.level) * modifiers.manaSpeedMult;
    addManaToCards(orb.element, mana);

    if (CombatMath.appliesAura(kind, orb.level)) {
      applyAura(orb.element);
    }
    if (kind == HitKind.bullseye) {
      hitStopRemaining = 0.045;
      trauma = (trauma + 0.55).clamp(0.0, 1.0);
    }
  }

  /// Applies an elemental imprint or detonates a reaction if one is pending.
  /// Returns the reaction name when one detonates.
  String? applyAura(Element element, {int orbLevel = 1}) {
    if (aura == null) {
      aura = element;
      auraRemaining = ElementalReactionEngine.auraDuration;
      return null;
    }
    if (aura == element) {
      auraRemaining = ElementalReactionEngine.auraDuration;
      return null;
    }
    final engine = ElementalReactionEngine();
    final reaction = engine.checkReaction(aura!, element, orbLevel);
    if (reaction == null) return null;
    aura = null;
    auraRemaining = 0;
    _detonateReaction(reaction);
    return reaction.name;
  }

  void _detonateReaction(ReactionResult r) {
    final mult = r.damageMultiplier;
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
    for (final c in cards) {
      final gain =
          amount *
          (c.element == element ? 1.0 : 0.25) *
          modifiers.manaSpeedMult;
      c.mana = (c.mana + gain).clamp(0.0, c.baseManaCost.toDouble());
    }
  }

  void _registerDamage({
    required CombatOrb orb,
    required CombatTarget? target,
    required double multiplier,
    required HitKind kind,
  }) {
    final dmg = baseDamage * multiplier;
    bossHp -= dmg;
    final x = target?.xAt(time, effectiveAngularSpeed(target)) ?? bossScreenX;
    final y = target?.yAt(time, effectiveAngularSpeed(target)) ?? bossScreenY;
    texts.add(
      FloatingText(
        id: _nextId('txt'),
        text: kind == HitKind.bullseye
            ? '¡BULLSEYE! ${dmg.toInt()}'
            : kind == HitKind.graze
            ? '${dmg.toInt()}'
            : '${dmg.toInt()}',
        x: x,
        y: y,
        kind: kind == HitKind.bullseye
            ? FloatingTextKind.crit
            : FloatingTextKind.normal,
      ),
    );
    trauma = (trauma + 0.25).clamp(0.0, 1.0);
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
    playerHp -= (dmg - absorbed);
    trauma = (trauma + 0.45).clamp(0.0, 1.0);
  }

  void _tickBoss(double s) {
    if (bossStunRemaining > 0) {
      bossStunRemaining -= s;
      return;
    }
    bossAttackTimer -= s;
    if (bossAttackTimer > 0) return;
    bossAttackTimer = boss.attackInterval;
    final count = 1 + random.nextInt(boss.projectilesPerAttack);
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

  void _tickTexts(double s) {
    for (final t in texts) {
      t.age += s;
    }
    texts.removeWhere((t) => t.age > 1.1);
  }

  void _destroyEnemyProjectile(
    EnemyProjectile e, {
    required bool byCounterflick,
  }) {
    e.alive = false;
    if (!byCounterflick) return;
    addManaToAllCards(counterflickMana * modifiers.manaSpeedMult);
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
    if (finished || index < 0 || index >= cards.length) return false;
    final c = cards[index];
    if (c.mana < c.baseManaCost) return false;
    c.mana = 0;
    texts.add(
      FloatingText(
        id: _nextId('txt'),
        text: c.name,
        x: bossScreenX,
        y: bossScreenY - 150,
        kind: FloatingTextKind.skill,
      ),
    );
    final atk = c.attack;
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
    }
    trauma = (trauma + 0.5).clamp(0.0, 1.0);
    hitStopRemaining = 0.045;
    return true;
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
  };
}

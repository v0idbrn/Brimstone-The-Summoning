import 'dart:math' as math;

import '../value_objects/element.dart';
import '../value_objects/orb_level.dart';

enum TargetTrajectory { orbital, pendular, figure8 }

enum HitKind { bullseye, normal, graze, miss }

/// A mobile dimensional target hovering over the boss.
class CombatTarget {
  final String id;
  final TargetTrajectory trajectory;

  /// Centro base de la órbita; mutable para el teletransporte de Nyxara en
  /// enrage (engine-owned).
  double cx;
  double cy;
  final double amplitude;
  final double baseAngularSpeed;
  final double phase;

  /// Mutable combat modifiers (engine owns mutation).
  double speedMultiplier;
  bool frozen;
  double frozenRemaining;
  double enlargedUntil;
  double enlargedRadiusBonus;

  CombatTarget({
    required this.id,
    required this.trajectory,
    required this.cx,
    required this.cy,
    required this.amplitude,
    required this.baseAngularSpeed,
    this.phase = 0.0,
    this.speedMultiplier = 1.0,
    this.frozen = false,
    this.frozenRemaining = 0.0,
    this.enlargedUntil = 0.0,
    this.enlargedRadiusBonus = 0.0,
  });

  double xAt(double t, double w) {
    final angle = w * t + phase;
    switch (trajectory) {
      case TargetTrajectory.orbital:
      case TargetTrajectory.pendular:
        return cx + amplitude * math.cos(angle);
      case TargetTrajectory.figure8:
        return cx + amplitude * math.sin(angle);
    }
  }

  double yAt(double t, double w) {
    final angle = w * t + phase;
    switch (trajectory) {
      case TargetTrajectory.orbital:
        return cy + amplitude * math.sin(angle);
      case TargetTrajectory.pendular:
        return cy + amplitude * 0.55 * math.sin(angle * 2);
      case TargetTrajectory.figure8:
        return cy + amplitude * 0.6 * math.sin(angle * 2);
    }
  }
}

/// An elemental orb sitting in the player's merge tray.
class CombatOrb {
  final String id;
  final Element element;
  final OrbLevel level;

  /// Esfera Prismática (reliquia Prisma del Caos): fusiona con cualquier
  /// elemento del mismo nivel y detona cualquier aura activa.
  final bool prismatic;

  const CombatOrb({
    required this.id,
    required this.element,
    required this.level,
    this.prismatic = false,
  });
}

/// One of the 4 active TCG cards charged with mana during combat.
class ManaCard {
  final String id;
  final String name;
  final Element element;
  final int baseManaCost;
  final double attack;
  final int stars;
  double mana;

  ManaCard({
    required this.id,
    required this.name,
    required this.element,
    required this.baseManaCost,
    required this.attack,
    this.stars = 1,
    this.mana = 0,
  });

  bool get isReady => mana >= baseManaCost;
}

/// The player's own projectile in flight (tray -> boss plane).
class OrbProjectile {
  final String id;
  final Element element;
  final OrbLevel level;
  final double startX;
  final double startY;
  double targetX;
  double targetY;
  final double flightDuration;
  double elapsed;
  bool alive;
  OrbProjectile({
    required this.id,
    required this.element,
    required this.level,
    required this.startX,
    required this.startY,
    required this.targetX,
    required this.targetY,
    required this.flightDuration,
  })  : elapsed = 0,
        alive = true;
}

/// Boss incoming corrupted projectile (boss plane -> player).
class EnemyProjectile {
  final String id;
  final double startX;
  final double startY;
  final double endX;
  final double endY;
  final double duration;
  double elapsed;
  bool alive;
  EnemyProjectile({
    required this.id,
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    this.duration = 1.65,
  })  : elapsed = 0,
        alive = true;
}

/// Floating combat text event (damage / crit / reaction / skill).
class FloatingText {
  final String id;
  final String text;
  final double x;
  final double y;
  final FloatingTextKind kind;

  /// Originating element for reaction texts (colors the text per element).
  final Element? element;
  double age;
  FloatingText({
    required this.id,
    required this.text,
    required this.x,
    required this.y,
    required this.kind,
    this.element,
  }) : age = 0;
}

enum FloatingTextKind { normal, crit, reaction, skill }

/// Boss configuration handed to the combat engine.
class BossConfig {
  final String id;
  final String name;
  final Element element;
  final double maxHp;
  final double attackInterval;
  final double attackDamage;
  final int projectilesPerAttack;
  const BossConfig({
    required this.id,
    required this.name,
    required this.element,
    required this.maxHp,
    this.attackInterval = 6.0,
    this.attackDamage = 10.0,
    this.projectilesPerAttack = 2,
    this.threatDialog = '',
    this.furyDialog = '',
  });

  /// Diálogo de amenaza mostrado al iniciar la batalla del Piso 7.
  /// --- NUEVO: Configuraciones rebalanceadas para combates de 30 segundos ---

  /// Igneo - Piso 1-5 (enemigo normal): 380 HP (antes 2400). Golpe Bullseye Nv.1: 75 dañó (antes baseDamage*1.5).
  static const BossConfig igniteNormal = BossConfig(
    id: 'ignite_normal',
    name: 'Ignis, Llama Menor',
    element: Element.igneous,
    maxHp: 380, // 65% menos que 2400; rápido de morir en oleadas iniciales
    attackInterval: 6.0,
    attackDamage: 8, // Ajustado para la nueva escala de daño
    projectilesPerAttack: 2,
    threatDialog: 'El fuego comienza a bailar.',
    furyDialog: '¡QUÉMENSE! El fuego no perdona.',
  );

  /// Élite: 600 HP (antes 3200). Bullseye Nv.1: 175 dañó (1/3 vida enemigo normal).
  static const BossConfig elite = BossConfig(
    id: 'elite',
    name: 'Élite Abisal',
    element: Element.abyssal,
    maxHp: 600,
    attackInterval: 5.0,
    attackDamage: 12,
    projectilesPerAttack: 3,
    threatDialog: 'La sombra se alza sobre el campo de batalla.',
    furyDialog: '¡ESCARCHA ABSOLUTA! El hielo me pertenece.',
  );

  /// Jefe de Capítulo (Piso 7): Configuraciones por capítulo.
  /// Cap.I: 650 HP, Cap.II: 850 HP, Cap.III: 1100 HP, Cap.IV: 1350 HP, Cap.V: 1650 HP
  static const BossConfig chapterI = BossConfig(
    id: 'chapter_i',
    name: 'Pyroth, Coloso de Ceniza',
    element: Element.igneous,
    maxHp: 650,
    attackInterval: 6.0,
    attackDamage: 14,
    projectilesPerAttack: 2,
    threatDialog: 'La Forja de Ceniza arde bajo mi mando.',
    furyDialog: '¡QUÉMENSE HASTA EL HUESO! El fuego no perdona.',
  );
  static const BossConfig chapterII = BossConfig(
    id: 'chapter_ii',
    name: 'Vaelor, Señor de la Fosa Helada',
    element: Element.abyssal,
    maxHp: 850,
    attackInterval: 5.0,
    attackDamage: 16,
    projectilesPerAttack: 3,
    threatDialog: 'El frío eterno aguarda en la Fosa de Escarcha.',
    furyDialog: '¡ESCARCHA ABSOLUTA! El hielo me pertenece.',
  );
  static const BossConfig chapterIII = BossConfig(
    id: 'chapter_iii',
    name: 'Gorgath, Monarca de Basalto',
    element: Element.telluric,
    maxHp: 1100,
    attackInterval: 5.5,
    attackDamage: 18,
    projectilesPerAttack: 2,
    threatDialog: 'El Bastión Tectónico no se rinde ante mortales.',
    furyDialog: '¡PETRIFICACIÓN TOTAL! Las dianas se encogen.',
  );
  static const BossConfig chapterIV = BossConfig(
    id: 'chapter_iv',
    name: 'Nyxara, Tejedora del Eclipse',
    element: Element.empty,
    maxHp: 1350,
    attackInterval: 5.0,
    attackDamage: 20,
    projectilesPerAttack: 2,
    threatDialog: 'Sueños rotos bajo el Velo de las Pesadillas.',
    furyDialog: '¡TELEPORTACIÓN ABISAL! Fallar drena tu maná.',
  );
  static const BossConfig chapterV = BossConfig(
    id: 'chapter_v',
    name: 'Azathor, Monolito del Vacío',
    element: Element.empty,
    maxHp: 1650,
    attackInterval: 4.5,
    attackDamage: 22,
    projectilesPerAttack: 3,
    threatDialog: 'El Trono del Sello Roto espera a su cadáver, invocador.',
    furyDialog: '¡EL SELLO ESTÁ ROTO! Cambio de elemento ahora.',
  );

  /// Gólem de Pruebas Abisal: maniquí de la Arena de Entrenamiento.
  static const BossConfig trainingGolem = BossConfig(
    id: 'training_golem',
    name: 'Gólem de Pruebas Abisal',
    element: Element.telluric,
    maxHp: 50000,
    attackInterval: 12.0,
    attackDamage: 4,
    projectilesPerAttack: 1,
    threatDialog: 'Mide tu poder, invocador. Yo no me cansaré.',
    furyDialog: 'El Gólem recalibra su coraza. Sigue golpeando.',
  );
  static const BossConfig nyxara = BossConfig(
    id: 'nyxara',
    name: 'Nyxara, Tejedora del Eclipse',
    element: Element.empty,
    maxHp: 3800,
    attackInterval: 5.0,
    attackDamage: 15,
    projectilesPerAttack: 2,
    threatDialog: 'Sueños rotos bajo el Velo de las Pesadillas.',
    furyDialog: '¡TELEPORTACIÓN ABISAL! Fallar drena tu maná.',
  );

  /// --- FIN CONFIGURACIÓN REBALANCEADA ---

  /// Diálogo de amenaza mostrado al iniciar la batalla del Piso 7.
  final String threatDialog;

  /// Diálogo de Furia Abisal mostrado al entrar en enrage (<45% HP).
  final String furyDialog;

  static const BossConfig pyroth = BossConfig(
    id: 'pyroth',
    name: 'Pyroth, Coloso de Ceniza',
    element: Element.igneous,
    maxHp: 2400,
    attackInterval: 6.0,
    attackDamage: 10,
    projectilesPerAttack: 2,
    threatDialog: 'La Forja de Ceniza arde bajo mi mando.',
    furyDialog: '¡QUÉMENSE HASTA EL HUESO! El fuego no perdona.',
  );
  static const BossConfig vaelor = BossConfig(
    id: 'vaelor',
    name: 'Vaelor, Señor de la Fosa Helada',
    element: Element.abyssal,
    maxHp: 3200,
    attackInterval: 5.0,
    attackDamage: 13,
    projectilesPerAttack: 3,
    threatDialog: 'El frío eterno aguarda en la Fosa de Escarcha.',
    furyDialog: '¡ESCARCHA ABSOLUTA! El hielo me pertenece.',
  );
  static const BossConfig azathor = BossConfig(
    id: 'azathor',
    name: 'Azathor, Monolito del Vacío',
    element: Element.empty,
    maxHp: 4200,
    attackInterval: 4.5,
    attackDamage: 16,
    projectilesPerAttack: 3,
    threatDialog: 'El Trono del Sello Roto espera a su cadáver, invocador.',
    furyDialog: '¡EL SELLO ESTÁ ROTO! Cambio de elemento ahora.',
  );
  static const BossConfig gorgath = BossConfig(
    id: 'gorgath',
    name: 'Gorgath, Monarca de Basalto',
    element: Element.telluric,
    maxHp: 3600,
    attackInterval: 5.5,
    attackDamage: 14,
    projectilesPerAttack: 2,
    threatDialog: 'El Bastión Tectónico no se rinde ante mortales.',
    furyDialog: '¡PETRIFICACIÓN TOTAL! Las dianas se encogen.',
  );
}

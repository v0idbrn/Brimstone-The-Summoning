import '../combat/combat_models.dart';

/// Los 10 Desafíos del Sello: pruebas tácticas con mutadores evaluadas dentro
/// de [CombatEngine].
///
/// Cada desafío se resuelve contra un jefe concreto y otorga 250 esquirlas +
/// 500 oro en la primera victoria. Dominio puro.

/// Mutadores de combate que alteran las reglas de una prueba.
enum SealMutator {
  /// Sólo los impactos Bullseye hacen daño.
  bullseyeOnly,

  /// Daño directo -80%, reacciones elementales +300%.
  reactionBoost,

  /// Sólo las esferas de Nivel 3 dañan al jefe.
  lvl3Only,

  /// Cada Counter-Flick inflige 12% del HP máximo del jefe.
  counterflickReflect,

  /// Pierdes 2% HP/s, pero cada Bullseye cura 5% HP.
  bleedHeal,

  /// Sólo aparecen esferas Ígneas y Abisales, con recarga rápida.
  igneousAbyssalFast,

  /// Habilidades activas bloqueadas, esferas +120% de daño.
  skillDisabledOrbBoost,

  /// El jefe dispara el doble de proyectiles.
  bossDoubleProjectiles,

  /// Dianas -25% de tamaño y más rápidas, pero dan el doble de maná.
  fastSmallManaBoost,

  /// Azathor en Furia Abisal desde el segundo 0.
  azathorFuryStart,
}

/// Etiquetas cortas para la UI del desafío.
extension SealMutatorLabel on SealMutator {
  String get label => switch (this) {
        SealMutator.bullseyeOnly => 'Sólo Bullseye',
        SealMutator.reactionBoost => 'Reacciones x4',
        SealMutator.lvl3Only => 'Sólo Nv.3',
        SealMutator.counterflickReflect => 'Reflejo 12%',
        SealMutator.bleedHeal => 'Hemorragia',
        SealMutator.igneousAbyssalFast => 'Tormenta bipolar',
        SealMutator.skillDisabledOrbBoost => 'Silencio de cartas',
        SealMutator.bossDoubleProjectiles => 'Lluvia corrupta',
        SealMutator.fastSmallManaBoost => 'Dianas fugaces',
        SealMutator.azathorFuryStart => 'Furia desde 0',
      };
}

class SealChallenge {
  final String id;
  final String title;
  final String description;
  final List<SealMutator> mutators;
  final int rewardShards;
  final int rewardGold;

  /// Jefe contra el que se disputa la prueba.
  final BossConfig boss;

  /// HP máximo del jugador al entrar a la prueba.
  final double playerMaxHp;

  const SealChallenge({
    required this.id,
    required this.title,
    required this.description,
    required this.mutators,
    this.rewardShards = 250,
    this.rewardGold = 500,
    this.boss = BossConfig.pyroth,
    this.playerMaxHp = 100,
  });

  bool has(SealMutator m) => mutators.contains(m);
}

class SealChallengeRules {
  static const int firstWinShards = 250;
  static const int firstWinGold = 500;

  static const List<SealChallenge> allChallenges = [
    SealChallenge(
      id: 'abyssal_sniper',
      title: 'Francotirador Abisal',
      description:
          'Sólo los impactos Bullseye hacen daño. Todo lo demás rebota en la coraza del jefe.',
      mutators: [SealMutator.bullseyeOnly],
      boss: BossConfig.vaelor,
    ),
    SealChallenge(
      id: 'alchemical_crucible',
      title: 'Crisol Alquímico',
      description:
          'El daño directo de esferas cae un 80%, pero las Reacciones Elementales detonan un +300%.',
      mutators: [SealMutator.reactionBoost],
      boss: BossConfig.pyroth,
    ),
    SealChallenge(
      id: 'forge_master',
      title: 'Maestro de la Forja',
      description:
          'Sólo las esferas de Nivel 3 perforan al jefe. Fusiona sin descanso.',
      mutators: [SealMutator.lvl3Only],
      boss: BossConfig.gorgath,
    ),
    SealChallenge(
      id: 'mirror_wall',
      title: 'Muralla de Espejos',
      description:
          'Cada Counter-Flick refleja el 12% del HP máximo del jefe de vuelta a su cara.',
      mutators: [SealMutator.counterflickReflect],
      boss: BossConfig.nyxara,
    ),
    SealChallenge(
      id: 'blood_pact',
      title: 'Pacto de Hemorragia',
      description:
          'Pierdes 2% de vida por segundo, pero cada Bullseye te devuelve un 5% de vida.',
      mutators: [SealMutator.bleedHeal],
      boss: BossConfig.vaelor,
    ),
    SealChallenge(
      id: 'bipolar_storm',
      title: 'Tormenta Bipolar',
      description:
          'Sólo aparecen esferas Ígneas y Abisales, y la bandeja se recarga al doble de velocidad.',
      mutators: [SealMutator.igneousAbyssalFast],
      boss: BossConfig.pyroth,
    ),
    SealChallenge(
      id: 'card_silence',
      title: 'Silencio de Cartas',
      description:
          'Las habilidades activas están selladas, pero tus esferas pegan un +120% más fuerte.',
      mutators: [SealMutator.skillDisabledOrbBoost],
      boss: BossConfig.gorgath,
    ),
    SealChallenge(
      id: 'corrupt_rain',
      title: 'Lluvia Corrupta',
      description:
          'El jefe dispara el doble de proyectiles enemigos. Counter-Flick salvavidas.',
      mutators: [SealMutator.bossDoubleProjectiles],
      boss: BossConfig.nyxara,
    ),
    SealChallenge(
      id: 'fleeting_targets',
      title: 'Dianas Fugaces',
      description:
          'Las dianas son un 25% más chicas y veloces, pero otorgan el doble de maná.',
      mutators: [SealMutator.fastSmallManaBoost],
      boss: BossConfig.vaelor,
    ),
    SealChallenge(
      id: 'emperors_judgment',
      title: 'Juicio del Emperador',
      description:
          'Azathor entra en Furia Abisal desde el segundo 0 y no baja el ritmo.',
      mutators: [SealMutator.azathorFuryStart],
      boss: BossConfig.azathor,
    ),
  ];

  static SealChallenge? byId(String id) {
    for (final c in allChallenges) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Plantilla de cartas usada si el jugador no tiene escuadrón.
  static const List<String> fallbackSquad = [
    'ignis_hound',
    'abyss_stalker',
    'terra_golem',
    'void_specter',
  ];
}

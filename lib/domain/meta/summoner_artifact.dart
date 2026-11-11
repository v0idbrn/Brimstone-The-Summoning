/// Artefactos del Invocador — dominio puro (Etapa III, Pilar 7).
///
/// 6 artefactos fabricables y equipables que añaden un **quinto botón
/// táctico** en la barra de HP del CombatScreen, con cooldown de 20s.
enum ArtifactEffect {
  /// Congela a las dianas 3s y detiene los proyectiles enemigos.
  cronomancia,

  /// Convierte todas las esferas de la bandeja en Nv.2 (o Nv.3 con suerte).
  transmutacion,

  /// Sacrifica 10% HP actual e inflige 3 golpes garantizados de bullseye.
  sangriaReal,

  /// Agranda las dianas un 50% durante 8s.
  precision,

  /// Detonación inmediata: daño 4x de área sobre todas las dianas.
  detonacion,

  /// Drena maná del jefe: roba 40 maná para el escuadrón y Vulnerable 5s.
  vacio,
}

class SummonerArtifact {
  final String id;
  final String name;
  final String description;
  final ArtifactEffect effect;

  /// Cooldown táctico pactado: 20 segundos para todos los artefactos.
  static const double cooldownSeconds = 20.0;

  const SummonerArtifact({
    required this.id,
    required this.name,
    required this.description,
    required this.effect,
  });
}

const List<SummonerArtifact> summonerArtifacts = [
  SummonerArtifact(
    id: 'art_reloj_ceniza',
    name: 'Reloj de Arena Quebrado',
    description: 'Congela dianas 3s y detiene los proyectiles enemigos.',
    effect: ArtifactEffect.cronomancia,
  ),
  SummonerArtifact(
    id: 'art_crisol',
    name: 'Crisol Alquímico',
    description: 'Transmuta la bandeja entera a esferas Nv.2 (25% de Nv.3).',
    effect: ArtifactEffect.transmutacion,
  ),
  SummonerArtifact(
    id: 'art_caliz',
    name: 'Cáliz de Sangre Real',
    description: 'Sacrifica 10% HP y lanza 3 golpes garantizados de bullseye.',
    effect: ArtifactEffect.sangriaReal,
  ),
  SummonerArtifact(
    id: 'art_lente',
    name: 'Lente del Francotirador',
    description: 'Agranda las dianas un 50% durante 8s.',
    effect: ArtifactEffect.precision,
  ),
  SummonerArtifact(
    id: 'art_bomba',
    name: 'Bomba de Azufre',
    description: 'Detona un daño 4x de área sobre todas las dianas.',
    effect: ArtifactEffect.detonacion,
  ),
  SummonerArtifact(
    id: 'art_catalizador',
    name: 'Catalizador del Vacío',
    description: 'Roba 40 maná para el escuadrón y Vulnerable 5s al jefe.',
    effect: ArtifactEffect.vacio,
  ),
];

SummonerArtifact artifactById(String id) => summonerArtifacts
    .firstWhere((a) => a.id == id, orElse: () => summonerArtifacts.first);

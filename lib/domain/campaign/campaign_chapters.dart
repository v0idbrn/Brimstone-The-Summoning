import '../combat/combat_models.dart';

/// Un entero capítulo de la campaña narrativa.
///
/// Cada capítulo está ligado a un jefe de Piso 7 y otorga recompensas de
/// primera victoria al ser limpiado. Dominio puro: sin dependencias de
/// Flutter, Flame ni SQLite.
class CampaignChapter {
  /// Número ordinal del capítulo (1, 2, 3).
  final int number;

  /// Id estable del capítulo (se usa para guardar/progresar en SQLite).
  final String id;

  /// Nombre de display del capítulo.
  final String name;

  /// Título del jefe final de este capítulo.
  final String bossTitle;

  /// Configuración del jefe del Piso 7.
  final BossConfig boss;

  /// Oro otorgado por primera victoria.
  final int rewardGold;

  /// Esquirlas otorgadas por primera victoria.
  final int rewardShards;

  /// Capítulo que debe estar limpiado antes de desbloquear este (null = primero).
  final String? previousChapterId;

  const CampaignChapter({
    required this.number,
    required this.id,
    required this.name,
    required this.bossTitle,
    required this.boss,
    required this.rewardGold,
    required this.rewardShards,
    this.previousChapterId,
  });

  /// Título de honor desbloqueado al completar el Capítulo III.
  static const String chapterIIITitle = 'Monarca de Basalto';

  /// Título de honor desbloqueado al completar el Capítulo IV.
  static const String chapterIVTitle = 'Tejedor del Eclipse';

  /// Título de honor desbloqueado al completar el Capítulo V.
  static const String chapterVTitle = 'Gran Arconte del Sello';
}

/// Los 5 capítulos oficiales de la campaña, en orden de progresión.
final List<CampaignChapter> campaignChapters = const [
  CampaignChapter(
    number: 1,
    id: 'chapter_ceniza',
    name: 'La Forja de Ceniza',
    bossTitle: 'Pyroth, Coloso de Ceniza',
    boss: BossConfig.pyroth,
    rewardGold: 800,
    rewardShards: 300,
  ),
  CampaignChapter(
    number: 2,
    id: 'chapter_fosa',
    name: 'La Fosa de Escarcha',
    bossTitle: 'Vaelor, Señor de la Fosa Helada',
    boss: BossConfig.vaelor,
    rewardGold: 1200,
    rewardShards: 500,
    previousChapterId: 'chapter_ceniza',
  ),
  CampaignChapter(
    number: 3,
    id: 'chapter_tectonico',
    name: 'El Bastión Tectónico',
    bossTitle: 'Gorgath, Monarca de Basalto',
    boss: BossConfig.gorgath,
    rewardGold: 1600,
    rewardShards: 700,
    previousChapterId: 'chapter_fosa',
  ),
  CampaignChapter(
    number: 4,
    id: 'chapter_velo',
    name: 'El Velo de las Pesadillas',
    bossTitle: 'Nyxara, Tejedora del Eclipse',
    boss: BossConfig.nyxara,
    rewardGold: 2200,
    rewardShards: 1000,
    previousChapterId: 'chapter_tectonico',
  ),
  CampaignChapter(
    number: 5,
    id: 'chapter_tronco',
    name: 'El Trono del Sello Roto',
    bossTitle: 'Azathor, Gran Arconte del Sello',
    boss: BossConfig.azathor,
    rewardGold: 3500,
    rewardShards: 1800,
    previousChapterId: 'chapter_velo',
  ),
  // ── ACTO II — EL CONTINENTE SUMERGIDO (Leviatán) ──
  CampaignChapter(
    number: 6,
    id: 'chapter_coral',
    name: 'Las Ruinas de Coral Negro',
    bossTitle: 'Kaelith, Reina Ahogada',
    boss: BossConfig.chapterVI,
    rewardGold: 4200,
    rewardShards: 2200,
    previousChapterId: 'chapter_tronco',
  ),
  CampaignChapter(
    number: 7,
    id: 'chapter_observatorio',
    name: 'El Observatorio Estelar Roto',
    bossTitle: 'Astreon, Vigía Ciego',
    boss: BossConfig.chapterVII,
    rewardGold: 5000,
    rewardShards: 2600,
    previousChapterId: 'chapter_coral',
  ),
  CampaignChapter(
    number: 8,
    id: 'chapter_catedral',
    name: 'La Catedral de Hueso y Ceniza',
    bossTitle: 'Malakor Renacido, Pontífice del Fuego',
    boss: BossConfig.chapterVIII,
    rewardGold: 6000,
    rewardShards: 3200,
    previousChapterId: 'chapter_observatorio',
  ),
  CampaignChapter(
    number: 9,
    id: 'chapter_laberinto',
    name: 'El Laberinto del Tiempo Partido',
    bossTitle: 'Chronos-Vex, Devorador de Eras',
    boss: BossConfig.chapterIX,
    rewardGold: 7200,
    rewardShards: 4000,
    previousChapterId: 'chapter_catedral',
  ),
  CampaignChapter(
    number: 10,
    id: 'chapter_corazon',
    name: 'El Corazón del Dios Caído',
    bossTitle: 'Samael, Creador de la Grieta',
    boss: BossConfig.chapterX,
    rewardGold: 10000,
    rewardShards: 6000,
    previousChapterId: 'chapter_laberinto',
  ),
];

/// Modo Pesadilla (New Game+) para capítulos ya limpiados (Etapa III).
///
/// Escala las estadísticas del jefe x2.2 y multiplica las recompensas x2.5.
/// Puramente matemático: no persiste estado, el caller decide qué capítulos
/// se pueden replayar en Pesadilla.
class NightmareMode {
  const NightmareMode._();

  /// Multiplicador de HP/daño/proyectiles-equivalentes del jefe.
  static const double bossStatMult = 2.2;

  /// Multiplicador de recompensas (oro, esquirlas, XP).
  static const double rewardMult = 2.5;

  /// Prefijo de id para el jefe escalado ('nightmare_chapter_x').
  static String scaledBossId(String baseId) => 'nightmare_$baseId';

  /// Escala [boss] a Pesadilla.
  static BossConfig scale(BossConfig boss) => BossConfig(
        id: scaledBossId(boss.id),
        name: 'Pesadilla: ${boss.name}',
        element: boss.element,
        maxHp: (boss.maxHp * bossStatMult).roundToDouble(),
        attackInterval: boss.attackInterval,
        attackDamage: boss.attackDamage * bossStatMult,
        projectilesPerAttack: boss.projectilesPerAttack,
        shieldHp: boss.shieldHp * bossStatMult,
        threatDialog: boss.threatDialog,
        furyDialog: boss.furyDialog,
      );

  /// Recompensas escaladas de un capítulo en Pesadilla.
  static (int gold, int shards) scaledRewards(CampaignChapter c) => (
        (c.rewardGold * rewardMult).round(),
        (c.rewardShards * rewardMult).round(),
      );
}

/// Busca un capítulo por [id]. Retorna null si no existe.
CampaignChapter? chapterById(String id) {
  for (final c in campaignChapters) {
    if (c.id == id) return c;
  }
  return null;
}

/// Indica si [chapterId] está desbloqueado dado los capítulos [cleared] ya
/// limpiados.
bool chapterUnlocked(String chapterId, List<String> cleared) {
  final c = chapterById(chapterId);
  if (c == null) return false;
  return c.previousChapterId == null || cleared.contains(c.previousChapterId);
}

/// Devuelve el primer capítulo no limpiado cuyo requisito ya está cumplido,
/// o null si la campaña está completa.
CampaignChapter? nextLockedChapter(List<String> cleared) {
  for (final c in campaignChapters) {
    if (cleared.contains(c.id)) continue;
    final prev = c.previousChapterId;
    if (prev == null || cleared.contains(prev)) return c;
  }
  return null;
}

/// Cantidad de capítulos limpiados.
int chaptersClearedCount(List<String> cleared) =>
    cleared.where((id) => chapterById(id) != null).length;

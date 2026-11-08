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
  static const String chapterIIITitle = 'Gran Arconte del Sello';
}

/// Los 3 capítulos oficiales de la campaña, en orden de progresión.
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
    id: 'chapter_sello',
    name: 'El Bastión del Sello',
    bossTitle: 'Azathor, Gran Arconte del Sello',
    boss: BossConfig.azathor,
    rewardGold: 2000,
    rewardShards: 900,
    previousChapterId: 'chapter_fosa',
  ),
];

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

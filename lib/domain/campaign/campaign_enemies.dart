import '../value_objects/element.dart';
import '../combat/combat_models.dart';

/// Categorías de enemigos en el Modo Historia.
enum EnemyTier { minion, miniBoss, chapterBoss }

/// Configuración base de un enemigo de campaña.
class CampaignEnemy {
  final String id;
  final String name;
  final Element element;
  final EnemyTier tier;
  final int chapterNumber;
  final int floor; // 1-7 en el árbol de la grieta
  final double maxHp;
  final double attackDamage;
  final double attackInterval;
  final int projectilesPerAttack;
  final int targetCount; // número de dianas
  final String portraitAsset; // en assets/portraits/
  final String? threatDialog;
  final String? furyDialog;

  const CampaignEnemy({
    required this.id,
    required this.name,
    required this.element,
    required this.tier,
    required this.chapterNumber,
    required this.floor,
    required this.maxHp,
    required this.attackDamage,
    required this.attackInterval,
    required this.projectilesPerAttack,
    required this.targetCount,
    required this.portraitAsset,
    this.threatDialog,
    this.furyDialog,
  });

  /// Convierte a [BossConfig] para el motor de combate.
  BossConfig toBossConfig() => BossConfig(
        id: id,
        name: name,
        element: element,
        maxHp: maxHp,
        attackInterval: attackInterval,
        attackDamage: attackDamage,
        projectilesPerAttack: projectilesPerAttack,
        threatDialog: threatDialog ?? '',
        furyDialog: furyDialog ?? '',
      );
}

/// Enemy data for all 25 campaign enemies.
/// 15 Minions + 5 Mini-Bosses + 5 Chapter Bosses = 25 total.
final List<CampaignEnemy> campaignEnemies = const [
  // ===== CAPÍTULO I - ÍGNEO =====
  // Piso 1, 2, 3, 5: 3 Esbirros por capítulo
  CampaignEnemy(
    id: 'minion_ceniza_imp',
    name: 'Imp de Azufre',
    element: Element.igneous,
    tier: EnemyTier.minion,
    chapterNumber: 1,
    floor: 1,
    maxHp: 180,
    attackDamage: 8,
    attackInterval: 6.5,
    projectilesPerAttack: 1,
    targetCount: 2,
    portraitAsset: 'portraits/minion_ceniza_imp.webp',
    threatDialog: 'El fuego me consume... y a ti también.',
  ),
  CampaignEnemy(
    id: 'minion_ceniza_sabueso',
    name: 'Sabueso de Escoria',
    element: Element.igneous,
    tier: EnemyTier.minion,
    chapterNumber: 1,
    floor: 2,
    maxHp: 210,
    attackDamage: 10,
    attackInterval: 6.0,
    projectilesPerAttack: 1,
    targetCount: 2,
    portraitAsset: 'portraits/minion_ceniza_sabueso.webp',
    threatDialog: 'Mi amo Pyroth te hará cenizas.',
  ),
  CampaignEnemy(
    id: 'minion_ceniza_gargola',
    name: 'Gárgola de Ceniza',
    element: Element.igneous,
    tier: EnemyTier.minion,
    chapterNumber: 1,
    floor: 3,
    maxHp: 250,
    attackDamage: 12,
    attackInterval: 5.5,
    projectilesPerAttack: 2,
    targetCount: 2,
    portraitAsset: 'portraits/minion_ceniza_gargola.webp',
    threatDialog: 'La piedra arde bajo mis garras.',
  ),
  // Piso 4: Mini-Jefe
  CampaignEnemy(
    id: 'miniboss_ignarok',
    name: 'Ignarok, Carcelero de Magma',
    element: Element.igneous,
    tier: EnemyTier.miniBoss,
    chapterNumber: 1,
    floor: 4,
    maxHp: 360,
    attackDamage: 15,
    attackInterval: 5.0,
    projectilesPerAttack: 3,
    targetCount: 3,
    portraitAsset: 'portraits/miniboss_ignarok.webp',
    threatDialog: 'La Forja de Ceniza arde bajo mi mando. ¡Nadie escapa!',
    furyDialog: '¡QUÉMENSE HASTA EL HUESO! El fuego no perdona.',
  ),
  // Piso 5: Esbirro élite (usar el 3º esbirro o uno nuevo)
  CampaignEnemy(
    id: 'minion_ceniza_elemental',
    name: 'Elemental de Magma',
    element: Element.igneous,
    tier: EnemyTier.minion,
    chapterNumber: 1,
    floor: 5,
    maxHp: 280,
    attackDamage: 14,
    attackInterval: 5.0,
    projectilesPerAttack: 2,
    targetCount: 2,
    portraitAsset: 'portraits/minion_ceniza_elemental.webp',
    threatDialog: 'El magma fluye por mis venas.',
  ),
  // Piso 7: Jefe Final
  CampaignEnemy(
    id: 'boss_pyroth',
    name: 'Pyroth, Coloso de Ceniza',
    element: Element.igneous,
    tier: EnemyTier.chapterBoss,
    chapterNumber: 1,
    floor: 7,
    maxHp: 550,
    attackDamage: 18,
    attackInterval: 6.0,
    projectilesPerAttack: 3,
    targetCount: 3,
    portraitAsset: 'portraits/boss_pyroth.webp',
    threatDialog: 'La Forja de Ceniza arde bajo mi mando.',
    furyDialog: '¡QUÉMENSE HASTA EL HUESO! El fuego no perdona.',
  ),

  // ===== CAPÍTULO II - ABISAL =====
  CampaignEnemy(
    id: 'minion_fosa_acechador',
    name: 'Acechador de Escarcha',
    element: Element.abyssal,
    tier: EnemyTier.minion,
    chapterNumber: 2,
    floor: 1,
    maxHp: 210,
    attackDamage: 10,
    attackInterval: 6.5,
    projectilesPerAttack: 1,
    targetCount: 2,
    portraitAsset: 'portraits/minion_fosa_acechador.webp',
    threatDialog: 'El frío te cala los huesos.',
  ),
  CampaignEnemy(
    id: 'minion_fosa_naga',
    name: 'Naga de la Fosa',
    element: Element.abyssal,
    tier: EnemyTier.minion,
    chapterNumber: 2,
    floor: 2,
    maxHp: 250,
    attackDamage: 12,
    attackInterval: 6.0,
    projectilesPerAttack: 2,
    targetCount: 2,
    portraitAsset: 'portraits/minion_fosa_naga.webp',
    threatDialog: 'Vaelor reclamará tu calor.',
  ),
  CampaignEnemy(
    id: 'minion_fosa_espectro',
    name: 'Espectro Helado',
    element: Element.abyssal,
    tier: EnemyTier.minion,
    chapterNumber: 2,
    floor: 3,
    maxHp: 290,
    attackDamage: 14,
    attackInterval: 5.5,
    projectilesPerAttack: 2,
    targetCount: 2,
    portraitAsset: 'portraits/minion_fosa_espectro.webp',
    threatDialog: 'El hielo eterno no conoce piedad.',
  ),
  CampaignEnemy(
    id: 'miniboss_cryon',
    name: 'Cryon, Verdugo del Glaciar',
    element: Element.abyssal,
    tier: EnemyTier.miniBoss,
    chapterNumber: 2,
    floor: 4,
    maxHp: 440,
    attackDamage: 18,
    attackInterval: 5.0,
    projectilesPerAttack: 3,
    targetCount: 3,
    portraitAsset: 'portraits/miniboss_cryon.webp',
    threatDialog: 'El Glaciar no perdona a los intrusos.',
    furyDialog: '¡ESCARCHA ABSOLUTA! El hielo me pertenece.',
  ),
  CampaignEnemy(
    id: 'minion_fosa_glaciar',
    name: 'Guardián del Glaciar',
    element: Element.abyssal,
    tier: EnemyTier.minion,
    chapterNumber: 2,
    floor: 5,
    maxHp: 320,
    attackDamage: 16,
    attackInterval: 5.0,
    projectilesPerAttack: 2,
    targetCount: 2,
    portraitAsset: 'portraits/minion_fosa_glaciar.webp',
    threatDialog: 'Mi hoja está forjada en hielo perpetuo.',
  ),
  CampaignEnemy(
    id: 'boss_vaelor',
    name: 'Vaelor, Señor de la Fosa Helada',
    element: Element.abyssal,
    tier: EnemyTier.chapterBoss,
    chapterNumber: 2,
    floor: 7,
    maxHp: 700,
    attackDamage: 20,
    attackInterval: 5.5,
    projectilesPerAttack: 3,
    targetCount: 3,
    portraitAsset: 'portraits/boss_vaelor.webp',
    threatDialog: 'El frío eterno aguarda en la Fosa de Escarcha.',
    furyDialog: '¡ESCARCHA ABSOLUTA! El hielo me pertenece.',
  ),

  // ===== CAPÍTULO III - TELÚRICO =====
  CampaignEnemy(
    id: 'minion_tectonico_centinela',
    name: 'Centinela de Basalto',
    element: Element.telluric,
    tier: EnemyTier.minion,
    chapterNumber: 3,
    floor: 1,
    maxHp: 250,
    attackDamage: 12,
    attackInterval: 6.5,
    projectilesPerAttack: 1,
    targetCount: 2,
    portraitAsset: 'portraits/minion_tectonico_centinela.webp',
    threatDialog: 'La roca aguanta. Tú no.',
  ),
  CampaignEnemy(
    id: 'minion_tectonico_rompehuesos',
    name: 'Rompehuesos de Roca',
    element: Element.telluric,
    tier: EnemyTier.minion,
    chapterNumber: 3,
    floor: 2,
    maxHp: 290,
    attackDamage: 14,
    attackInterval: 6.0,
    projectilesPerAttack: 2,
    targetCount: 2,
    portraitAsset: 'portraits/minion_tectonico_rompehuesos.webp',
    threatDialog: 'Gorgath aplasta a los débiles.',
  ),
  CampaignEnemy(
    id: 'minion_tectonico_vibora',
    name: 'Víbora de Cuarzo',
    element: Element.telluric,
    tier: EnemyTier.minion,
    chapterNumber: 3,
    floor: 3,
    maxHp: 320,
    attackDamage: 16,
    attackInterval: 5.5,
    projectilesPerAttack: 2,
    targetCount: 2,
    portraitAsset: 'portraits/minion_tectonico_vibora.webp',
    threatDialog: 'Mi veneno es polvo de estrellas.',
  ),
  CampaignEnemy(
    id: 'miniboss_krag',
    name: 'Krag, Demoledor Monolítico',
    element: Element.telluric,
    tier: EnemyTier.miniBoss,
    chapterNumber: 3,
    floor: 4,
    maxHp: 510,
    attackDamage: 20,
    attackInterval: 5.0,
    projectilesPerAttack: 3,
    targetCount: 3,
    portraitAsset: 'portraits/miniboss_krag.webp',
    threatDialog: 'La montaña cae sobre ti.',
    furyDialog: '¡LA TIERRA TIEMBLA! Nada resiste al peso.',
  ),
  CampaignEnemy(
    id: 'minion_tectonico_golem',
    name: 'Gólem de Granito',
    element: Element.telluric,
    tier: EnemyTier.minion,
    chapterNumber: 3,
    floor: 5,
    maxHp: 360,
    attackDamage: 18,
    attackInterval: 5.0,
    projectilesPerAttack: 2,
    targetCount: 2,
    portraitAsset: 'portraits/minion_tectonico_golem.webp',
    threatDialog: 'Soy la roca que nunca se rompe.',
  ),
  CampaignEnemy(
    id: 'boss_gorgath',
    name: 'Gorgath, Monarca de Basalto',
    element: Element.telluric,
    tier: EnemyTier.chapterBoss,
    chapterNumber: 3,
    floor: 7,
    maxHp: 850,
    attackDamage: 22,
    attackInterval: 5.0,
    projectilesPerAttack: 4,
    targetCount: 4,
    portraitAsset: 'portraits/boss_gorgath.webp',
    threatDialog: 'El Bastión Tectónico no conoce rendición.',
    furyDialog: '¡LA MONTAÑA CAE! Sepultados en piedra.',
  ),

  // ===== CAPÍTULO IV - VACÍO =====
  CampaignEnemy(
    id: 'minion_velo_sombra',
    name: 'Sombra Devoradora',
    element: Element.empty,
    tier: EnemyTier.minion,
    chapterNumber: 4,
    floor: 1,
    maxHp: 280,
    attackDamage: 14,
    attackInterval: 6.5,
    projectilesPerAttack: 1,
    targetCount: 2,
    portraitAsset: 'portraits/minion_velo_sombra.webp',
    threatDialog: 'La oscuridad todo lo consume.',
  ),
  CampaignEnemy(
    id: 'minion_velo_acolitos',
    name: 'Acólito del Eclipse',
    element: Element.empty,
    tier: EnemyTier.minion,
    chapterNumber: 4,
    floor: 2,
    maxHp: 320,
    attackDamage: 16,
    attackInterval: 6.0,
    projectilesPerAttack: 2,
    targetCount: 2,
    portraitAsset: 'portraits/minion_velo_acolitos.webp',
    threatDialog: 'Nyxara ve tu final.',
  ),
  CampaignEnemy(
    id: 'minion_velo_larva',
    name: 'Larva Astral',
    element: Element.empty,
    tier: EnemyTier.minion,
    chapterNumber: 4,
    floor: 3,
    maxHp: 360,
    attackDamage: 18,
    attackInterval: 5.5,
    projectilesPerAttack: 2,
    targetCount: 2,
    portraitAsset: 'portraits/minion_velo_larva.webp',
    threatDialog: 'Nací de las estrellas muertas.',
  ),
  CampaignEnemy(
    id: 'miniboss_morvath',
    name: 'Morvath, Tejedor de Sombras',
    element: Element.empty,
    tier: EnemyTier.miniBoss,
    chapterNumber: 4,
    floor: 4,
    maxHp: 570,
    attackDamage: 22,
    attackInterval: 5.0,
    projectilesPerAttack: 3,
    targetCount: 3,
    portraitAsset: 'portraits/miniboss_morvath.webp',
    threatDialog: 'El Velo se cierra sobre ti.',
    furyDialog: '¡LA NOCHE ETERNA! No hay escape del vacío.',
  ),
  CampaignEnemy(
    id: 'minion_velo_phantom',
    name: 'Fantasma del Vacío',
    element: Element.empty,
    tier: EnemyTier.minion,
    chapterNumber: 4,
    floor: 5,
    maxHp: 400,
    attackDamage: 20,
    attackInterval: 5.0,
    projectilesPerAttack: 2,
    targetCount: 2,
    portraitAsset: 'portraits/minion_velo_phantom.webp',
    threatDialog: 'No hay luz que me alcance.',
  ),
  CampaignEnemy(
    id: 'boss_nyxara',
    name: 'Nyxara, Tejedora del Eclipse',
    element: Element.empty,
    tier: EnemyTier.chapterBoss,
    chapterNumber: 4,
    floor: 7,
    maxHp: 1000,
    attackDamage: 24,
    attackInterval: 4.5,
    projectilesPerAttack: 4,
    targetCount: 4,
    portraitAsset: 'portraits/boss_nyxara.webp',
    threatDialog: 'El Velo de las Pesadillas te reclama.',
    furyDialog: '¡EL ECLIPSE ES ETERNO! La luz muere aquí.',
  ),

  // ===== CAPÍTULO V - SELLO ROTO =====
  CampaignEnemy(
    id: 'minion_tronco_caballero',
    name: 'Caballero Corrupto',
    element: Element.empty,
    tier: EnemyTier.minion,
    chapterNumber: 5,
    floor: 1,
    maxHp: 330,
    attackDamage: 16,
    attackInterval: 6.5,
    projectilesPerAttack: 1,
    targetCount: 2,
    portraitAsset: 'portraits/minion_tronco_caballero.webp',
    threatDialog: 'Mi lealtad es al Vacío.',
  ),
  CampaignEnemy(
    id: 'minion_tronco_inquisidor',
    name: 'Inquisidor del Vacío',
    element: Element.empty,
    tier: EnemyTier.minion,
    chapterNumber: 5,
    floor: 2,
    maxHp: 370,
    attackDamage: 18,
    attackInterval: 6.0,
    projectilesPerAttack: 2,
    targetCount: 2,
    portraitAsset: 'portraits/minion_tronco_inquisidor.webp',
    threatDialog: 'Azathor exige tu rendición.',
  ),
  CampaignEnemy(
    id: 'minion_tronco_quimera',
    name: 'Quimera Abisal',
    element: Element.empty,
    tier: EnemyTier.minion,
    chapterNumber: 5,
    floor: 3,
    maxHp: 410,
    attackDamage: 20,
    attackInterval: 5.5,
    projectilesPerAttack: 2,
    targetCount: 2,
    portraitAsset: 'portraits/minion_tronco_quimera.webp',
    threatDialog: 'Tres cabezas, un solo hambre.',
  ),
  CampaignEnemy(
    id: 'miniboss_malphas',
    name: 'Malphas, Heraldo del Trono',
    element: Element.empty,
    tier: EnemyTier.miniBoss,
    chapterNumber: 5,
    floor: 4,
    maxHp: 640,
    attackDamage: 24,
    attackInterval: 5.0,
    projectilesPerAttack: 3,
    targetCount: 3,
    portraitAsset: 'portraits/miniboss_malphas.webp',
    threatDialog: 'El Trono del Sello Roto no conoce señor salvo Azathor.',
    furyDialog: '¡EL SELLO SE ROMPE! El Vacío lo devora todo.',
  ),
  CampaignEnemy(
    id: 'minion_tronco_avanguardia',
    name: 'Vanguardia del Trono',
    element: Element.empty,
    tier: EnemyTier.minion,
    chapterNumber: 5,
    floor: 5,
    maxHp: 450,
    attackDamage: 22,
    attackInterval: 5.0,
    projectilesPerAttack: 2,
    targetCount: 2,
    portraitAsset: 'portraits/minion_tronco_avanguardia.webp',
    threatDialog: 'Somos el filo de la nada.',
  ),
  CampaignEnemy(
    id: 'boss_azathor',
    name: 'Azathor, Gran Arconte del Sello',
    element: Element.empty,
    tier: EnemyTier.chapterBoss,
    chapterNumber: 5,
    floor: 7,
    maxHp: 1200,
    attackDamage: 26,
    attackInterval: 4.0,
    projectilesPerAttack: 4,
    targetCount: 4,
    portraitAsset: 'portraits/boss_azathor.webp',
    threatDialog: 'El Trono del Sello Roto es el fin de todo.',
    furyDialog: '¡EL VACÍO ES ABSOLUTO! Nada permanece.',
  ),
];

/// Obtiene todos los enemigos de un capítulo específico.
List<CampaignEnemy> enemiesForChapter(int chapterNumber) =>
    campaignEnemies.where((e) => e.chapterNumber == chapterNumber).toList();

/// Obtiene los esbirros (minions) de un capítulo para pisos específicos.
List<CampaignEnemy> minionsForChapter(int chapterNumber) => campaignEnemies
    .where(
        (e) => e.chapterNumber == chapterNumber && e.tier == EnemyTier.minion)
    .toList();

/// Obtiene el mini-jefe de un capítulo.
CampaignEnemy? miniBossForChapter(int chapterNumber) {
  final matches = campaignEnemies
      .where((e) =>
          e.chapterNumber == chapterNumber && e.tier == EnemyTier.miniBoss)
      .toList();
  return matches.isEmpty ? null : matches.first;
}

/// Obtiene el jefe final de un capítulo.
CampaignEnemy? chapterBossForChapter(int chapterNumber) {
  final matches = campaignEnemies
      .where((e) =>
          e.chapterNumber == chapterNumber && e.tier == EnemyTier.chapterBoss)
      .toList();
  return matches.isEmpty ? null : matches.first;
}

/// Obtiene el enemigo para un piso específico de un capítulo.
CampaignEnemy? enemyForFloor(int chapterNumber, int floor) {
  final matches = campaignEnemies
      .where((e) => e.chapterNumber == chapterNumber && e.floor == floor)
      .toList();
  return matches.isEmpty ? null : matches.first;
}

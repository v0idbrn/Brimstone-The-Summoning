import '../value_objects/element.dart';
import '../value_objects/rarity.dart';

/// Rol táctico de una carta del escuadrón (Etapa III — Leviatán).
///
/// Cada rol otorga un bono pasivo en el motor de combate y condiciona la
/// sinergia de escuadrón que el [SquadSynergyResolver] resuelve.
enum CardRole {
  /// Primera línea: +HP y escudo inicial.
  vanguardia,

  /// Daño puro: multiplica el daño de sus esferas.
  destructor,

  /// Regeneración de maná: acelera la carga de sus habilidades.
  canalizador,

  /// Soporte arcano: amplifica los efectos de reacción y aura.
  arconte,
}

/// Facción narrativa a la que pertenece una carta (lore del Leviatán).
enum CardFaction {
  ordenDeLaCeniza,
  corteDelAbismo,
  hijosDelBasalto,
  cultoDelEclipse,
}

/// Metadatos de display de un rol.
extension CardRoleMeta on CardRole {
  String get label => switch (this) {
        CardRole.vanguardia => 'Vanguardia',
        CardRole.destructor => 'Destructor',
        CardRole.canalizador => 'Canalizador',
        CardRole.arconte => 'Arconte',
      };

  /// Bonos del rol aplicados al motor de combate.
  double get hpMult => switch (this) {
        CardRole.vanguardia => 1.20,
        _ => 1.0,
      };

  double get damageMult => switch (this) {
        CardRole.destructor => 1.15,
        _ => 1.0,
      };

  double get manaSpeedMult => switch (this) {
        CardRole.canalizador => 1.20,
        _ => 1.0,
      };

  double get reactionMult => switch (this) {
        CardRole.arconte => 1.25,
        _ => 1.0,
      };

  /// Escudo inicial que la carta aporta al escuadrón.
  double get startingShield => this == CardRole.vanguardia ? 12.0 : 0.0;
}

/// Metadatos de display de una facción.
extension CardFactionMeta on CardFaction {
  String get label => switch (this) {
        CardFaction.ordenDeLaCeniza => 'Orden de la Ceniza',
        CardFaction.corteDelAbismo => 'Corte del Abismo',
        CardFaction.hijosDelBasalto => 'Hijos del Basalto',
        CardFaction.cultoDelEclipse => 'Culto del Eclipse',
      };
}

/// Facción por defecto de cada elemento (lore del Leviatán).
CardFaction factionForElement(Element e) => switch (e) {
      Element.igneous => CardFaction.ordenDeLaCeniza,
      Element.abyssal => CardFaction.corteDelAbismo,
      Element.telluric => CardFaction.hijosDelBasalto,
      Element.empty => CardFaction.cultoDelEclipse,
    };

/// Definición de una carta del catálogo con su rol y facción (Leviatán).
class CardBlueprint {
  final String id;
  final String name;
  final Element element;
  final Rarity rarity;
  final int baseManaCost;
  final int attack;
  final int health;
  final int stars;
  final String activeSkill;
  final CardRole role;
  final CardFaction faction;

  const CardBlueprint({
    required this.id,
    required this.name,
    required this.element,
    required this.rarity,
    required this.baseManaCost,
    required this.attack,
    required this.health,
    required this.stars,
    required this.activeSkill,
    required this.role,
    required this.faction,
  });
}

/// Las 20 criaturas nuevas de la expansión Leviatán (5 por elemento).
const List<CardBlueprint> leviathanCreatures = [
  // ── Ígneo (Orden de la Ceniza) ──────────────────────────────────────────
  CardBlueprint(
    id: 'ignis_phoenix',
    name: 'Fénix de Ceniza',
    element: Element.igneous,
    rarity: Rarity.legendary,
    baseManaCost: 165,
    attack: 28,
    health: 44,
    stars: 3,
    activeSkill:
        'Renacer de brasas: daño 3.8x a todas las dianas y revive con 30% HP.',
    role: CardRole.destructor,
    faction: CardFaction.ordenDeLaCeniza,
  ),
  CardBlueprint(
    id: 'ignis_berserker',
    name: 'Berserker de Magma',
    element: Element.igneous,
    rarity: Rarity.rare,
    baseManaCost: 105,
    attack: 17,
    health: 21,
    stars: 1,
    activeSkill:
        'Furia de magma: daño 2.2x creciente por cada golpe fallado previo.',
    role: CardRole.destructor,
    faction: CardFaction.ordenDeLaCeniza,
  ),
  CardBlueprint(
    id: 'ignis_alchemist',
    name: 'Alquimista Volcánico',
    element: Element.igneous,
    rarity: Rarity.epic,
    baseManaCost: 140,
    attack: 19,
    health: 30,
    stars: 2,
    activeSkill:
        'Elixir de azufre: sube +1 nivel a dos esferas y aplica aura Ígnea.',
    role: CardRole.canalizador,
    faction: CardFaction.ordenDeLaCeniza,
  ),
  CardBlueprint(
    id: 'ignis_valkyrie',
    name: 'Valkiria Ígnea',
    element: Element.igneous,
    rarity: Rarity.epic,
    baseManaCost: 145,
    attack: 21,
    health: 33,
    stars: 2,
    activeSkill: 'Lanza solar: daño 3.0x y escudo de brasas para el invocador.',
    role: CardRole.vanguardia,
    faction: CardFaction.ordenDeLaCeniza,
  ),
  CardBlueprint(
    id: 'ignis_wyrm',
    name: 'Wyrm de Escoria',
    element: Element.igneous,
    rarity: Rarity.common,
    baseManaCost: 95,
    attack: 11,
    health: 16,
    stars: 1,
    activeSkill: 'Aliento de ceniza: daño 1.6x a una diana y aura Ígnea.',
    role: CardRole.destructor,
    faction: CardFaction.ordenDeLaCeniza,
  ),
  // ── Abisal (Corte del Abismo) ───────────────────────────────────────────
  CardBlueprint(
    id: 'abyss_oracle',
    name: 'Oráculo del Foso',
    element: Element.abyssal,
    rarity: Rarity.epic,
    baseManaCost: 150,
    attack: 20,
    health: 31,
    stars: 2,
    activeSkill:
        'Presagio abisal: agranda las dianas un 30% durante 5s y congela 2s.',
    role: CardRole.arconte,
    faction: CardFaction.corteDelAbismo,
  ),
  CardBlueprint(
    id: 'abyss_executioner',
    name: 'Ejecutor Abisal',
    element: Element.abyssal,
    rarity: Rarity.rare,
    baseManaCost: 115,
    attack: 16,
    health: 22,
    stars: 1,
    activeSkill: 'Sentencia glacial: daño 2.6x a la diana con menor HP.',
    role: CardRole.destructor,
    faction: CardFaction.corteDelAbismo,
  ),
  CardBlueprint(
    id: 'abyss_glacier',
    name: 'Glaciar de las Profundidades',
    element: Element.abyssal,
    rarity: Rarity.legendary,
    baseManaCost: 175,
    attack: 27,
    health: 52,
    stars: 3,
    activeSkill:
        'Avalancha abisal: daño 4.2x, congela todas las dianas 3.5s y escudo.',
    role: CardRole.vanguardia,
    faction: CardFaction.corteDelAbismo,
  ),
  CardBlueprint(
    id: 'abyss_medusa',
    name: 'Medusa del Coral Negro',
    element: Element.abyssal,
    rarity: Rarity.epic,
    baseManaCost: 135,
    attack: 18,
    health: 29,
    stars: 2,
    activeSkill: 'Mirada petrificante: ralentiza las dianas un 50% durante 6s.',
    role: CardRole.arconte,
    faction: CardFaction.corteDelAbismo,
  ),
  CardBlueprint(
    id: 'abyss_emperess',
    name: 'Emperatriz Sumergida',
    element: Element.abyssal,
    rarity: Rarity.legendary,
    baseManaCost: 170,
    attack: 26,
    health: 47,
    stars: 3,
    activeSkill:
        'Marea real: daño 3.9x a todas las dianas y +30 maná al escuadrón.',
    role: CardRole.canalizador,
    faction: CardFaction.corteDelAbismo,
  ),
  // ── Telúrico (Hijos del Basalto) ────────────────────────────────────────
  CardBlueprint(
    id: 'terra_druid',
    name: 'Druida de las Raíces',
    element: Element.telluric,
    rarity: Rarity.rare,
    baseManaCost: 110,
    attack: 13,
    health: 26,
    stars: 1,
    activeSkill:
        'Vigor telúrico: cura 20% HP del invocador y aplica aura Telúrica.',
    role: CardRole.canalizador,
    faction: CardFaction.hijosDelBasalto,
  ),
  CardBlueprint(
    id: 'terra_juggernaut',
    name: 'Juggernaut de Obsidiana',
    element: Element.telluric,
    rarity: Rarity.legendary,
    baseManaCost: 180,
    attack: 29,
    health: 56,
    stars: 3,
    activeSkill: 'Embestida sísmica: daño 4.0x, aturde 2.5s y escudo masivo.',
    role: CardRole.vanguardia,
    faction: CardFaction.hijosDelBasalto,
  ),
  CardBlueprint(
    id: 'terra_scorpion',
    name: 'Escorpión de Ónix',
    element: Element.telluric,
    rarity: Rarity.common,
    baseManaCost: 100,
    attack: 12,
    health: 19,
    stars: 1,
    activeSkill: 'Veneno lítico: daño 1.7x y Vulnerable 4s al jefe.',
    role: CardRole.destructor,
    faction: CardFaction.hijosDelBasalto,
  ),
  CardBlueprint(
    id: 'terra_sentinel',
    name: 'Centinela de Basalto',
    element: Element.telluric,
    rarity: Rarity.epic,
    baseManaCost: 130,
    attack: 17,
    health: 38,
    stars: 2,
    activeSkill:
        'Muralla de piedra: escudo grande y absorbe los 2 próximos golpes.',
    role: CardRole.vanguardia,
    faction: CardFaction.hijosDelBasalto,
  ),
  CardBlueprint(
    id: 'terra_worldtree',
    name: 'Árbol del Mundo',
    element: Element.telluric,
    rarity: Rarity.legendary,
    baseManaCost: 190,
    attack: 25,
    health: 60,
    stars: 3,
    activeSkill:
        'Raíces primordiales: +50 maná al escuadrón y aura Telúrica intensa.',
    role: CardRole.canalizador,
    faction: CardFaction.hijosDelBasalto,
  ),
  // ── Vacío (Culto del Eclipse) ───────────────────────────────────────────
  CardBlueprint(
    id: 'void_assassin',
    name: 'Asesino del Eclipse',
    element: Element.empty,
    rarity: Rarity.rare,
    baseManaCost: 105,
    attack: 18,
    health: 18,
    stars: 1,
    activeSkill: 'Cuchillada sombría: daño 2.8x garantizado como bullseye.',
    role: CardRole.destructor,
    faction: CardFaction.cultoDelEclipse,
  ),
  CardBlueprint(
    id: 'void_puppeteer',
    name: 'Titiritero de Sombras',
    element: Element.empty,
    rarity: Rarity.epic,
    baseManaCost: 145,
    attack: 20,
    health: 30,
    stars: 2,
    activeSkill:
        'Marionetas: invierte el control y devuelve 2 proyectiles enemigos.',
    role: CardRole.arconte,
    faction: CardFaction.cultoDelEclipse,
  ),
  CardBlueprint(
    id: 'void_harbinger',
    name: 'Presagio del Vacío',
    element: Element.empty,
    rarity: Rarity.rare,
    baseManaCost: 120,
    attack: 16,
    health: 23,
    stars: 1,
    activeSkill: 'Sombra anunciadora: Vulnerable 6s y aura de Vacío.',
    role: CardRole.arconte,
    faction: CardFaction.cultoDelEclipse,
  ),
  CardBlueprint(
    id: 'void_lich',
    name: 'Lich del Eclipse',
    element: Element.empty,
    rarity: Rarity.legendary,
    baseManaCost: 165,
    attack: 30,
    health: 46,
    stars: 3,
    activeSkill:
        'Marea de almas: daño 4.3x y roba vida equivalente al 25% del golpe.',
    role: CardRole.destructor,
    faction: CardFaction.cultoDelEclipse,
  ),
  CardBlueprint(
    id: 'void_seraphim',
    name: 'Serafín del Vacío',
    element: Element.empty,
    rarity: Rarity.epic,
    baseManaCost: 155,
    attack: 23,
    health: 36,
    stars: 2,
    activeSkill: 'Coro abisal: daño 3.4x a todas las dianas y cura 15% HP.',
    role: CardRole.canalizador,
    faction: CardFaction.cultoDelEclipse,
  ),
];

/// Catálogo completo: 20 clásicos + 20 Leviatán.
const List<CardBlueprint> fullCatalogBlueprints = leviathanCreatures;

/// Roles de las 20 cartas clásicas (pre-Leviatán), clave = catalog id.
const Map<String, CardRole> classicCardRoles = {
  'ignis_hound': CardRole.destructor,
  'ignis_drake': CardRole.destructor,
  'ignis_lord': CardRole.destructor,
  'ignis_seraph': CardRole.arconte,
  'ignis_colossus': CardRole.destructor,
  'abyss_stalker': CardRole.destructor,
  'abyss_siren': CardRole.arconte,
  'abyss_kraken': CardRole.destructor,
  'abyss_leviathan': CardRole.arconte,
  'abyss_wraith': CardRole.arconte,
  'terra_golem': CardRole.vanguardia,
  'terra_warden': CardRole.vanguardia,
  'terra_titan': CardRole.destructor,
  'terra_hydra': CardRole.destructor,
  'terra_behemoth': CardRole.vanguardia,
  'void_specter': CardRole.arconte,
  'void_reaper': CardRole.destructor,
  'void_oracle': CardRole.arconte,
  'void_malakor': CardRole.canalizador,
  'void_archon': CardRole.destructor,
};

/// Resuelve el rol de un id de catálogo (clásico o Leviatán).
CardRole roleForCatalogId(String catalogId) {
  final assigned = classicCardRoles[catalogId];
  if (assigned != null) return assigned;
  for (final b in leviathanCreatures) {
    if (b.id == catalogId) return b.role;
  }
  return CardRole.destructor;
}

/// Resuelve la facción de un id de catálogo a partir de su elemento/lore.
CardFaction factionForCatalogId(String catalogId, Element element) {
  for (final b in leviathanCreatures) {
    if (b.id == catalogId) return b.faction;
  }
  return factionForElement(element);
}

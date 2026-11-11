/// Orden del Pacto — dominio puro (Etapa III, Pilar 8).
///
/// Gremios offline: el invocador jura lealtad a 1 de las 4 Órdenes
/// elementales, contribuye diariamente con compañeros IA simulados para subir
/// el nivel de la Orden (buffs globales) y compra mejoras en la Tienda de
/// Insignias del Pacto.
enum CovenantOrder {
  ordenCeniza,
  corteAbismo,
  hijosBasalto,
  cultoEclipse,
}

extension CovenantOrderMeta on CovenantOrder {
  String get label => switch (this) {
        CovenantOrder.ordenCeniza => 'Orden de la Ceniza',
        CovenantOrder.corteAbismo => 'Corte del Abismo',
        CovenantOrder.hijosBasalto => 'Hijos del Basalto',
        CovenantOrder.cultoEclipse => 'Culto del Eclipse',
      };

  /// Buff global del daño elemental por nivel de la Orden.
  double damageBuffPerLevel(int level) => (level * 0.015).clamp(0.0, 0.45);
}

/// Estado persistido de la Orden (una fila en SQLite v10).
class GuildState {
  final CovenantOrder? order;
  final int orderLevel;
  final int contributionsToday;
  final String dayKey;
  final int badges;

  const GuildState({
    required this.order,
    required this.orderLevel,
    required this.contributionsToday,
    required this.dayKey,
    required this.badges,
  });

  static const GuildState empty = GuildState(
    order: null,
    orderLevel: 0,
    contributionsToday: 0,
    dayKey: '',
    badges: 0,
  );

  /// Aportes diarios permitidos (con los 3 compañeros IA simulados).
  static const int maxDailyContributions = 3;

  /// XP de Orden necesaria para subir de nivel (escala con el nivel actual).
  static int xpForNextLevel(int level) => 100 + 50 * (level - 1);

  /// Buff de daño global de la Orden (+1.5% por nivel, tope 45%).
  double damageBuff() => (orderLevel * 0.015).clamp(0.0, 0.45);

  bool canContribute(String todayKey) =>
      order != null &&
      (dayKey != todayKey || contributionsToday < maxDailyContributions);

  GuildState contribute(int badgesEarned, String todayKey) => GuildState(
        order: order,
        orderLevel: orderLevel,
        contributionsToday: dayKey == todayKey ? contributionsToday + 1 : 1,
        dayKey: todayKey,
        badges: badges + badgesEarned,
      );

  GuildState levelUpIfReady() {
    // Cada aporte diario sube 25 XP de Orden implícitos: nivel up cada
    // contribucionesNeeded aportes acumulados del día (simplicidad offline).
    const needed = 4;
    if (contributionsToday >= needed) {
      return GuildState(
        order: order,
        orderLevel: orderLevel + 1,
        contributionsToday: 0,
        dayKey: dayKey,
        badges: badges,
      );
    }
    return this;
  }
}

/// Premios de la Tienda de Insignias del Pacto.
class GuildBadgeShopItem {
  final String id;
  final String name;
  final int badgeCost;
  final String description;

  const GuildBadgeShopItem({
    required this.id,
    required this.name,
    required this.badgeCost,
    required this.description,
  });
}

const List<GuildBadgeShopItem> guildBadgeShop = [
  GuildBadgeShopItem(
    id: 'guild_gold_bundle',
    name: 'Ofrenda de Oro',
    badgeCost: 20,
    description: 'Cobra 800 oro del tesoro de la Orden.',
  ),
  GuildBadgeShopItem(
    id: 'guild_shards_bundle',
    name: 'Fragmentos del Pacto',
    badgeCost: 30,
    description: 'Cobra 200 esquirlas del arsenal de la Orden.',
  ),
  GuildBadgeShopItem(
    id: 'guild_banner',
    name: 'Estandarte del Pacto',
    badgeCost: 60,
    description: 'Un infrecuente tiraje del Gran Ritual (5 cartas).',
  ),
  GuildBadgeShopItem(
    id: 'guild_essence',
    name: 'Esencia de Cámara',
    badgeCost: 45,
    description: 'Gana 300 esencias para las Cámaras Elementales.',
  ),
  GuildBadgeShopItem(
    id: 'guild_mana_charm',
    name: 'Amuleto de Maná',
    badgeCost: 25,
    description: 'La próxima batalla inicia con maná al 50%.',
  ),
];

/// Insignias que otorga cada aporte diario (base + nivel de la Orden).
int badgesForContribution(int orderLevel) => 5 + orderLevel;

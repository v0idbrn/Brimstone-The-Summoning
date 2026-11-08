/// The 6 Abyssal Relics available as post-combat rewards and blood-altar
/// sacrifices. Ids mirror the SQLite seed catalog.
class RelicMeta {
  final String id;
  final String name;
  final String description;

  const RelicMeta({
    required this.id,
    required this.name,
    required this.description,
  });
}

class RelicCatalog {
  static const List<RelicMeta> all = [
    RelicMeta(
      id: 'ceniza_volatil',
      name: 'Ceniza Volátil',
      description:
          'Las esferas Ígneas spawnear directamente en Nivel 2 con un 35% de probabilidad.',
    ),
    RelicMeta(
      id: 'ojo_abismo',
      name: 'Ojo del Abismo',
      description:
          'El radio del Bullseye crítico aumenta un 40% en todas las dianas.',
    ),
    RelicMeta(
      id: 'sello_resonancia',
      name: 'Sello de Resonancia',
      description:
          'Detonar cualquier Reacción Elemental devuelve +20 de maná a todas tus cartas.',
    ),
    RelicMeta(
      id: 'pacto_sangre',
      name: 'Pacto de Sangre',
      description:
          'Tus cartas cargan maná un 50% más rápido, pero comienzas cada nodo perdiendo un 8% de vida máxima.',
    ),
    RelicMeta(
      id: 'forja_perpetua',
      name: 'Forja Perpetua',
      description:
          'Al fusionar dos esferas de Nivel 1 hay un 25% de probabilidad de saltar directo a Nivel 3.',
    ),
    RelicMeta(
      id: 'coraza_obsidiana',
      name: 'Coraza de Obsidiana',
      description:
          'Destruir un proyectil enemigo con Counter-Flick te cura un 4% de vida.',
    ),
  ];

  static RelicMeta byId(String id) =>
      all.firstWhere((r) => r.id == id, orElse: () => all.first);
}

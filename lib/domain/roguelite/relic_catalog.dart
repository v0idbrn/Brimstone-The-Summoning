/// The 18 Abyssal Relics available as post-combat rewards and blood-altar
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
          'Las esferas Ígneas spawnean directamente en Nivel 2 con un 35% de probabilidad.',
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
    // --- 12 Reliquias nuevas ---
    RelicMeta(
      id: 'prisma_caos',
      name: 'Prisma del Caos',
      description:
          'Permite que aparezcan Esferas Prismáticas comodín que fusionan con cualquier elemento y detonan cualquier Aura Elemental activa.',
    ),
    RelicMeta(
      id: 'reloj_ceniza',
      name: 'Reloj de Ceniza',
      description:
          'Aumenta la duración de las Auras Elementales en +2 segundos.',
    ),
    RelicMeta(
      id: 'colmillo_vampirico',
      name: 'Colmillo Vampírico',
      description: 'Cada impacto Bullseye cura un +2% de tu vida máxima.',
    ),
    RelicMeta(
      id: 'sello_sobrecarga',
      name: 'Sello de Sobrecarga',
      description: 'La carta Líder comienza el combate con el 100% de su maná.',
    ),
    RelicMeta(
      id: 'esencia_abismo',
      name: 'Esencia del Abismo',
      description: 'Todas las esferas ganan +1 nivel base (mínimo Nivel 2).',
    ),
    RelicMeta(
      id: 'corazon_phoenix',
      name: 'Corazón de Fénix',
      description:
          'Al morir, revives una vez con 30% de vida y todas las esferas en Nivel 3.',
    ),
    RelicMeta(
      id: 'grimorio_antiguo',
      name: 'Grimorio Antiguo',
      description:
          'Las habilidades de cartas cuestan -20% de maná y tienen +15% de efecto.',
    ),
    RelicMeta(
      id: 'tunica_vacio',
      name: 'Túnica del Vacío',
      description:
          'Reduces el daño recibido un 15% y ganas inmunidad a proyectiles por 3s al entrar en combate.',
    ),
    RelicMeta(
      id: 'martillo_titan',
      name: 'Martillo del Titán',
      description:
          'Fusionar esferas siempre produce al menos Nivel 2; Nivel 3 tiene 50% de probabilidad.',
    ),
    RelicMeta(
      id: 'cadenas_sello',
      name: 'Cadenas del Sello',
      description:
          'Los jefes comienzan aturdidos 2s y sus ataques son un 25% más lentos.',
    ),
    RelicMeta(
      id: 'llama_eterna',
      name: 'Llama Eterna',
      description:
          'Las esferas Ígneas nunca se gastan al impactar (probabilidad 20% por golpe).',
    ),
    RelicMeta(
      id: 'sombra_perdida',
      name: 'Sombra Perdida',
      description:
          'Ganas +1 esquirlas por enemigo derrotado y las esferas Abisales tienen +25% crítico.',
    ),
  ];

  static RelicMeta byId(String id) =>
      all.firstWhere((r) => r.id == id, orElse: () => all.first);
}

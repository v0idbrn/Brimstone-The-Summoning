import '../../domain/combat/combat_models.dart';
import '../../domain/value_objects/element.dart';

/// Tipo de sinergia pasiva de escuadrón detectada por la composición elemental.
enum SquadSynergyType {
  none,
  monoElemental,
  dualPact,
  arcaneTrinity,
  primordialHarmony,
}

/// Bonos numéricos aplicados en combate por la sinergia activa del escuadrón.
class SquadSynergyBonus {
  final SquadSynergyType type;
  final String name;
  final String description;

  /// Multiplicador de ATK global del escuadrón (1.0 = sin bono).
  final double atkMult;

  /// Multiplicador de HP máximo del jugador (1.0 = sin bono).
  final double hpMult;

  /// Fracción de maná inicial cargado al empezar cada combate (0.0 = ninguno).
  final double startManaFraction;

  /// Multiplicador de velocidad de generación de maná (1.0 = sin bono).
  final double manaSpeedMult;

  /// Fracción de escudo inicial sobre el HP máximo al empezar cada nodo.
  final double shieldFraction;

  /// Multiplicador de daño de todas las Reacciones Elementales (1.0 = sin bono).
  final double reactionDamageMult;

  /// Multiplicador de maná otorgado por impactos Bullseye (1.0 = sin bono).
  final double bullseyeManaMult;

  /// Multiplicador de duración de auras elementales sobre el jefe (1.0 = sin bono).
  final double auraDurationMult;

  const SquadSynergyBonus({
    required this.type,
    required this.name,
    required this.description,
    this.atkMult = 1.0,
    this.hpMult = 1.0,
    this.startManaFraction = 0.0,
    this.manaSpeedMult = 1.0,
    this.shieldFraction = 0.0,
    this.reactionDamageMult = 1.0,
    this.bullseyeManaMult = 1.0,
    this.auraDurationMult = 1.0,
  });

  bool get isActive => type != SquadSynergyType.none;
}

/// Resuelve la sinergia pasiva de escuadrón a partir de los elementos de las
/// 4 cartas activas. Dominio puro, sin dependencias de Flutter/Flame.
class SquadSynergyResolver {
  /// Evalúa [cards] (hasta 4) y devuelve el [SquadSynergyBonus] correspondiente.
  static SquadSynergyBonus resolve(List<ManaCard> cards) {
    final elements = <Element, int>{};
    for (final c in cards) {
      elements[c.element] = (elements[c.element] ?? 0) + 1;
    }
    final distinct = elements.length;
    final counts = elements.values.toList()..sort();

    // Armonía Primordial: 1 de cada uno de los 4 elementos.
    if (distinct == 4 &&
        elements.containsKey(Element.igneous) &&
        elements.containsKey(Element.abyssal) &&
        elements.containsKey(Element.telluric) &&
        elements.containsKey(Element.empty)) {
      return const SquadSynergyBonus(
        type: SquadSynergyType.primordialHarmony,
        name: 'Armonía Primordial',
        description:
            'Auras del jefe +40% de duración (7.0s), Bullseye +40% de maná, '
            '+18% ATK y HP del escuadrón.',
        atkMult: 1.18,
        hpMult: 1.18,
        bullseyeManaMult: 1.40,
        auraDurationMult: 1.40,
      );
    }

    // Dominio Monoelemental: 4 cartas del mismo elemento.
    if (distinct == 1 && counts.first == 4) {
      return SquadSynergyBonus(
        type: SquadSynergyType.monoElemental,
        name: 'Dominio $_elementName(elements.keys.first)',
        description: 'ATK global +35% y las cartas empiezan cada combate con 20% de maná.',
        atkMult: 1.35,
        startManaFraction: 0.20,
      );
    }

    // Pacto Dual: 2 cartas de un elemento + 2 de otro.
    if (distinct == 2 && counts[0] == 2 && counts[1] == 2) {
      return const SquadSynergyBonus(
        type: SquadSynergyType.dualPact,
        name: 'Pacto Dual',
        description:
            '+25% al multiplicador de daño de todas las Reacciones Elementales '
            'y +15% HP máximo del jugador.',
        hpMult: 1.15,
        reactionDamageMult: 1.25,
      );
    }

    // Trinidad Arcana: 3 cartas del mismo elemento + 1 de otro.
    if (distinct == 2 && counts[0] == 1 && counts[1] == 3) {
      return const SquadSynergyBonus(
        type: SquadSynergyType.arcaneTrinity,
        name: 'Trinidad Arcana',
        description:
            '+25% velocidad de generación de maná y escudo inicial del 12% HP '
            'al empezar cada nodo.',
        manaSpeedMult: 1.25,
        shieldFraction: 0.12,
      );
    }

    return const SquadSynergyBonus(
      type: SquadSynergyType.none,
      name: 'Sin sinergia',
      description:
          'Combiná 4 cartas del mismo elemento o mezcla de elementos '
          'para activar una pasiva global.',
    );
  }

  static String _elementName(Element e) => switch (e) {
    Element.igneous => 'Ígneo',
    Element.abyssal => 'Abisal',
    Element.telluric => 'Telúrico',
    Element.empty => 'Vacío',
  };
}

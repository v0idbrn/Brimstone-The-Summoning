import '../value_objects/element.dart';

class ElementalReactionEngine {
  static const double auraDuration = 5.0;

  ReactionResult? checkReaction(
    Element activeAura,
    Element incomingElement,
    int incomingOrbLevel,
  ) {
    final pair = {activeAura, incomingElement};
    if (pair.length == 2) {
      if (pair.containsAll({Element.igneous, Element.telluric})) {
        return ReactionResult.magmaEruption();
      }
      if (pair.containsAll({Element.abyssal, Element.igneous})) {
        return ReactionResult.thermalShock();
      }
      if (pair.containsAll({Element.telluric, Element.abyssal})) {
        return ReactionResult.abyssalPetrification();
      }
    }
    if (activeAura == Element.empty && incomingOrbLevel >= 3) {
      return ReactionResult.sealCollapse();
    }
    return null;
  }
}

class ReactionResult {
  final String name;
  final double damageMultiplier;
  final bool isAoE;
  final double manaBonusPercent;
  final bool appliesVulnerability;
  const ReactionResult({
    required this.name,
    this.damageMultiplier = 1.0,
    this.isAoE = false,
    this.manaBonusPercent = 0.0,
    this.appliesVulnerability = false,
  });
  factory ReactionResult.magmaEruption() => ReactionResult(
        name: 'Erupción Magmática',
        damageMultiplier: 1.6,
        isAoE: true,
      );
  factory ReactionResult.thermalShock() => ReactionResult(
        name: 'Choque Térmico',
        damageMultiplier: 2.0,
        manaBonusPercent: 0.25,
      );
  factory ReactionResult.abyssalPetrification() =>
      ReactionResult(name: 'Petrificación Abisal', damageMultiplier: 1.4);
  factory ReactionResult.sealCollapse() => ReactionResult(
        name: 'Colapso del Sello',
        damageMultiplier: 1.75,
        appliesVulnerability: true,
      );
}

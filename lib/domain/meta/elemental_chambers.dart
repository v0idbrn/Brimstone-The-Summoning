import 'dart:math' as math;

import '../value_objects/element.dart';

/// One of the four daily Elemental Forge Chambers.
class ElementalChamber {
  const ElementalChamber({
    required this.id,
    required this.name,
    required this.element,
    required this.tagline,
  });

  final String id;
  final String name;
  final Element element;
  final String tagline;

  /// Cards of the element that the chamber's guardians are weak to.
  Element get favoured => elementalWeakness(element);
}

/// The four calabozos, one per element, always open (daily rotation of bonuses
/// is cosmetic: all four grant their own essence).
class ElementalChambers {
  const ElementalChambers._();

  static const ElementalChamber crater = ElementalChamber(
    id: 'crater_igneo',
    name: 'Cámara del Cráter Ígneo',
    element: Element.igneous,
    tagline: 'Escoria viva y vetas de magma que nunca duermen.',
  );

  static const ElementalChamber fosa = ElementalChamber(
    id: 'fosa_abismal',
    name: 'Cámara de la Fosa Abisal',
    element: Element.abyssal,
    tagline: 'Hielo negro bajo un océano que no existe.',
  );

  static const ElementalChamber monolito = ElementalChamber(
    id: 'monolito_telurico',
    name: 'Cámara del Monolito Telúrico',
    element: Element.telluric,
    tagline: 'Piedra que respira y derrumba dinastías.',
  );

  static const ElementalChamber eclipse = ElementalChamber(
    id: 'eclipse_vacio',
    name: 'Cámara del Eclipse de Vacío',
    element: Element.empty,
    tagline: 'Un sol muerto que devora la luz del sello.',
  );

  static const List<ElementalChamber> all = [crater, fosa, monolito, eclipse];

  static ElementalChamber byId(String id) =>
      all.firstWhere((chamber) => chamber.id == id, orElse: () => crater);
}

/// Threat tier of a chamber run.
enum ChamberDifficulty {
  normal('NORMAL', 1.0, 1.0, 1.0),
  pesadilla('PESADILLA', 1.55, 1.9, 2.0),
  infierno('INFIERNO', 2.25, 3.2, 3.0);

  const ChamberDifficulty(
    this.label,
    this.threatScale,
    this.rewardScale,
    this.masteryScale,
  );

  final String label;
  final double threatScale;
  final double rewardScale;
  final double masteryScale;

  bool get isNightmarePlus => this != ChamberDifficulty.normal;
}

/// Reward bundle for a cleared chamber.
class ChamberRewards {
  const ChamberRewards({
    required this.essences,
    required this.gold,
    required this.masteryXp,
    required this.runeChance,
    required this.element,
  });

  final int essences;
  final int gold;
  final int masteryXp;
  final double runeChance;
  final Element element;

  bool get grantsRune => runeChance >= 0.4;
}

/// Persisted record of one cleared chamber run.
class ChamberClear {
  const ChamberClear({required this.clearedAt, required this.firstClear});

  final int clearedAt;
  final bool firstClear;
}

/// Chamber rules: opposite-element bonus (×2), scaling rewards and mastery.
class ChamberRules {
  const ChamberRules._();

  /// Base gold before the difficulty/reward scaling.
  static const int baseGold = 420;
  static const int baseEssences = 24;
  static const int baseMasteryXp = 60;

  /// ×2 for the element opposite to the chamber, ×1 otherwise.
  static double elementBonus({
    required Element squadElement,
    required Element chamberElement,
  }) =>
      squadElement == elementalWeakness(chamberElement) ? 2.0 : 1.0;

  /// Boss HP multiplier for the chamber guardians.
  static double bossHpFor({
    required ChamberDifficulty difficulty,
    required double chapterHp,
  }) =>
      math.max(1, chapterHp * difficulty.threatScale);

  static ChamberRewards rewardsFor({
    required ElementalChamber chamber,
    required ChamberDifficulty difficulty,
    required bool oppositeBonus,
  }) {
    final bonus = oppositeBonus ? 2.0 : 1.0;
    return ChamberRewards(
      essences: (baseEssences * difficulty.rewardScale * bonus)
          .round()
          .clamp(1, 9999),
      gold:
          (baseGold * difficulty.rewardScale * bonus).round().clamp(1, 999999),
      masteryXp: (baseMasteryXp * difficulty.masteryScale * bonus)
          .round()
          .clamp(1, 99999),
      runeChance: (0.18 * difficulty.rewardScale * bonus).clamp(0.0, 1.0),
      element: chamber.element,
    );
  }

  /// `chamberId:dificultad` key used by the clears table.
  static String clearKey(
          ElementalChamber chamber, ChamberDifficulty difficulty) =>
      '${chamber.id}:${difficulty.name}';
}

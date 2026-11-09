import '../entities/owned_card.dart';
import '../value_objects/element.dart';

/// Constants for the Card Mastery System (Block 1).
class CardMasteryConstants {
  /// XP de Maestría por victoria en combate normal.
  static const int masteryXpPerWin = 25;

  /// XP de Maestría por victoria contra Jefe (Mini-Jefe o Jefe de Capítulo).
  static const int masteryXpPerBossWin = 75;

  /// XP requerida para subir 1 Rango de Maestría (cada 100 XP = 1 rango).
  static const int xpPerMasteryRank = 100;

  /// Rango máximo de Maestría.
  static const int maxMasteryRank = 10;

  /// Bonus pasivo de ATK/HP por cada Rango de Maestría (+3%).
  static const double masteryRankStatBonus = 0.03;

  /// Nivel máximo de Habilidad.
  static const int maxSkillLevel = 5;

  /// Costo base de oro para mejorar habilidad (200 * skillLevel).
  static const int baseGoldCost = 200;

  /// Costo base de esquirlas para mejorar habilidad (40 * skillLevel).
  static const int baseShardsCost = 40;

  /// Multiplicador de efecto de habilidad por nivel (+15% por nivel).
  static const double skillEffectMultPerLevel = 0.15;

  /// Reducción de costo de maná por nivel de habilidad (-4 por nivel).
  static const int skillManaCostReductionPerLevel = 4;

  /// Umbral para Despertar Abisal: Skill Level 5 o Mastery Rank 5.
  static const int awakeningSkillLevel = 5;
  static const int awakeningMasteryRank = 5;

  /// Bonus de Despertar: +1 esfera Nivel 2 del elemento al invocar.
  static const int awakeningOrbLevel = 2;

  /// Bonus de Despertar: Escudo/Curación del 5% HP máximo.
  static const double awakeningShieldHealFraction = 0.05;
}

/// Calcula el bonus pasivo total de una carta basado en su Rango de Maestría.
/// Retorna un multiplicador (ej: 1.03 para Rango 2, 1.30 para Rango 11).
double calculateMasteryStatMult(OwnedCard card) {
  final rank = card.masteryRank;
  return 1.0 + (rank - 1) * CardMasteryConstants.masteryRankStatBonus;
}

/// Otorga XP de Maestría a las 4 cartas del escuadrón activo tras una victoria.
/// [isBoss] indica si fue contra un Mini-Jefe o Jefe de Capítulo.
Future<void> grantMasteryXpToSquad({
  required List<int> squadInstanceIds,
  required Map<int, OwnedCard> collectionById,
  required bool isBoss,
  required dynamic repo,
}) async {
  final xpGain = isBoss
      ? CardMasteryConstants.masteryXpPerBossWin
      : CardMasteryConstants.masteryXpPerWin;

  for (final id in squadInstanceIds) {
    final card = collectionById[id];
    if (card == null) continue;
    final newXp =
        (card.masteryXp + xpGain).clamp(0, 999); // Cap at 999 (Rank 10)
    if (newXp != card.masteryXp) {
      await repo.updateOwnedCard(card.copyWith(masteryXp: newXp));
    }
  }
}

/// Calcula el costo en oro para subir al siguiente nivel de habilidad.
int calculateSkillUpgradeGoldCost(int currentSkillLevel) {
  if (currentSkillLevel >= CardMasteryConstants.maxSkillLevel) return 0;
  return CardMasteryConstants.baseGoldCost * currentSkillLevel;
}

/// Calcula el costo en esquirlas para subir al siguiente nivel de habilidad.
int calculateSkillUpgradeShardsCost(int currentSkillLevel) {
  if (currentSkillLevel >= CardMasteryConstants.maxSkillLevel) return 0;
  return CardMasteryConstants.baseShardsCost * currentSkillLevel;
}

/// Verifica si una carta puede mejorar su habilidad (nivel < 5).
bool canUpgradeSkill(OwnedCard card) =>
    card.skillLevel < CardMasteryConstants.maxSkillLevel;

/// Verifica si una carta tiene el Despertar Abisal desbloqueado.
bool hasAwakening(OwnedCard card) =>
    card.skillLevel >= CardMasteryConstants.awakeningSkillLevel ||
    card.masteryRank >= CardMasteryConstants.awakeningMasteryRank;

/// Aplica el efecto de Despertar Abisal al invocar la carta en combate.
/// Retorna una lista de efectos adicionales a aplicar.
List<AwakeningEffect> applyAwakeningEffect(OwnedCard card) {
  if (!hasAwakening(card)) return [];
  return [
    AwakeningEffect.spawnOrb(
      element: card.element,
      level: CardMasteryConstants.awakeningOrbLevel,
    ),
    AwakeningEffect.shieldOrHeal(
      fraction: CardMasteryConstants.awakeningShieldHealFraction,
    ),
  ];
}

/// Efectos del Despertar Abisal.
sealed class AwakeningEffect {
  const AwakeningEffect();

  /// Genera una esfera del elemento de la carta en la bandeja.
  const factory AwakeningEffect.spawnOrb({
    required Element element,
    required int level,
  }) = AwakeningSpawnOrb;

  /// Otorga un escudo o curación equivalente a una fracción del HP máximo.
  const factory AwakeningEffect.shieldOrHeal({
    required double fraction,
  }) = AwakeningShieldHeal;
}

class AwakeningSpawnOrb extends AwakeningEffect {
  final Element element;
  final int level;
  const AwakeningSpawnOrb({required this.element, required this.level});
}

class AwakeningShieldHeal extends AwakeningEffect {
  final double fraction;
  const AwakeningShieldHeal({required this.fraction});
}

/// Repositorio abstracto para evitar dependencia circular en el dominio.
/// La implementación real está en PlayerRepository (data layer).
abstract class PlayerRepository {
  Future<void> updateOwnedCard(OwnedCard card);
}

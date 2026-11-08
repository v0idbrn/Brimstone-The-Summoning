import '../value_objects/element.dart';
import '../combat/combat_models.dart';

/// Pasiva del Líder del escuadrón (carta en el Slot 0).
///
/// La primera carta del escuadrón activo actúa como Líder y otorga un bono
/// de combate según su elemento y su nivel de estrella (1★ a 4★). Dominio
/// puro: sin dependencias de Flutter, Flame ni Riverpod.
class LeaderSkill {
  /// Elemento de la carta líder.
  final Element element;

  /// Nivel de estrella de la carta líder (1..4).
  final int stars;

  const LeaderSkill({required this.element, this.stars = 1});

  /// Multiplicador de daño de esferas/orbes (Ígneo): 1★ +15% … 3★ +30%.
  double get orbDamageMult {
    if (element != Element.igneous) return 1.0;
    final pct = 0.15 + 0.15 * (stars - 1) / 2; // 1★=15%, 2★=22.5%, 3★=30%
    return 1.0 + pct.clamp(0.0, 0.30);
  }

  /// Multiplicador de ganancia de maná (Abisal): 1★ +20% … 3★ +35%.
  double get manaGainMult {
    if (element != Element.abyssal) return 1.0;
    final pct = 0.20 + 0.15 * (stars - 1) / 2; // 1★=20%, 2★=27.5%, 3★=35%
    return 1.0 + pct.clamp(0.0, 0.35);
  }

  /// Reducción de daño recibido (Telúrico): 1★ -15% … 3★ -25%.
  double get damageTakenMult {
    if (element != Element.telluric) return 1.0;
    final pct = 0.15 + 0.10 * (stars - 1) / 2; // 1★=15%, 2★=20%, 3★=25%
    return (1.0 - pct).clamp(0.5, 1.0);
  }

  /// Multiplicador de daño crítico Bullseye (Vacío): 1★ +20% … 3★ +40%.
  double get critBullseyeMult {
    if (element != Element.empty) return 1.0;
    final pct = 0.20 + 0.20 * (stars - 1) / 2; // 1★=20%, 2★=30%, 3★=40%
    return 1.0 + pct.clamp(0.0, 0.40);
  }

  /// Descripción de lectura para la UI.
  String get description {
    switch (element) {
      case Element.igneous:
        return 'Daño de esferas +${((orbDamageMult * 100 - 100).round())}%';
      case Element.abyssal:
        return 'Ganancia de maná +${((manaGainMult * 100 - 100).round())}%';
      case Element.telluric:
        return 'Daño recibido -${(((1 - damageTakenMult) * 100).round())}%';
      case Element.empty:
        return 'Crítico Bullseye +${((critBullseyeMult * 100 - 100).round())}%';
    }
  }

  /// Etiqueta de insignia mostrada sobre la carta líder.
  static const String badgeLabel = 'LÍDER';
}

/// Calcula el [LeaderSkill] a partir de la carta en el Slot 0 del escuadrón.
/// Retorna null si el escuadrón está vacío.
LeaderSkill? leaderSkillOf(List<ManaCard> cards) {
  if (cards.isEmpty) return null;
  final leader = cards.first;
  return LeaderSkill(element: leader.element, stars: leader.stars);
}

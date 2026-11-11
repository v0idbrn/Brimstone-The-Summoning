import 'dart:math' as math;

/// La Torre de los 50 Sellos — dominio puro (Etapa III, Pilar 5).
///
/// Escalada progresiva de 50 pisos con un jefe guardián cada 5 pisos y un
/// "Barrido Rápido Diario (Sweep)" que cobra los recursos del récord de piso
/// sin combatir, una vez por día de calendario.
class ObsidianTower {
  const ObsidianTower._();

  /// Pisos totales de la torre.
  static const int maxFloor = 50;

  /// Un jefe guardián espera cada [bossInterval] pisos (5, 10, 15, ...).
  static const int bossInterval = 5;

  /// HP del esbirro del piso [floor]: curva geométrica suave.
  static double floorBossHp(int floor) {
    final isGuardian = floor % bossInterval == 0;
    return (isGuardian ? 520.0 : 240.0) * math.pow(1.16, floor - 1);
  }

  /// Daño del guardián/esbirro del piso [floor].
  static double floorAttack(int floor) {
    final isGuardian = floor % bossInterval == 0;
    return (isGuardian ? 16.0 : 9.0) * math.pow(1.05, floor - 1);
  }

  /// La torre es infinita en recompensa pero el piso 50 es la cima recordable.
  static bool isGuardianFloor(int floor) => floor % bossInterval == 0;

  /// Recompensa por limpiar el piso [floor] (oro + esquirlas escaladas).
  static (int gold, int shards) floorReward(int floor) {
    final guardian = isGuardianFloor(floor);
    final gold = ((guardian ? 220 : 90) * (1 + floor * 0.08)).round();
    final shards = ((guardian ? 60 : 20) * (1 + floor * 0.06)).round();
    return (gold, shards);
  }

  /// Barrido diario: recursos según el mejor piso alcanzado.
  ///
  /// Equivale al 60% de limpiar hasta ese piso una vez. Solo se puede cobrar
  /// una vez por día de calendario (`2026-11-10`) y exige récord ≥ 5.
  static (int gold, int shards)? sweepReward(int bestFloor, String dayKey,
      {String? lastSweepDay}) {
    if (lastSweepDay == dayKey) return null; // ya cobrado hoy
    if (bestFloor < bossInterval) return null; // exige al menos 5 pisos
    var gold = 0;
    var shards = 0;
    for (var f = 1; f <= bestFloor; f++) {
      final (g, s) = floorReward(f);
      gold += g;
      shards += s;
    }
    return ((gold * 0.6).round(), (shards * 0.6).round());
  }

  /// Clave de día de calendario UTC para el sweep diario.
  static String dayKeyOf(DateTime utc) =>
      '${utc.toUtc().year.toString().padLeft(4, '0')}-'
      '${utc.toUtc().month.toString().padLeft(2, '0')}-'
      '${utc.toUtc().day.toString().padLeft(2, '0')}';
}

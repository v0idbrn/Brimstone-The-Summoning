import 'dart:convert';

/// Gráfico de Aporte de Daño por Carta (★ MVP) — dominio puro (Pilar 10).
///
/// El [CombatEngine] acumula el daño infligido por cada carta y esfera; el
/// resumen de combate muestra barras porcentuales luminosas con insignia ★ MVP
/// y las últimas 15 batallas se guardan en SQLite v10.
class BattleLogEntry {
  final int epochMs;
  final String enemyId;
  final String enemyName;
  final bool victory;
  final int damageTotal;
  final int maxHit;
  final int bullseyes;
  final int counterflicks;
  final int mergesToThree;
  final String mvpCardId;
  final Map<String, int> damageByCard;
  final int playerHpLeft;

  const BattleLogEntry({
    required this.epochMs,
    required this.enemyId,
    required this.enemyName,
    required this.victory,
    required this.damageTotal,
    required this.maxHit,
    required this.bullseyes,
    required this.counterflicks,
    required this.mergesToThree,
    required this.mvpCardId,
    required this.damageByCard,
    required this.playerHpLeft,
  });

  /// Historial de batallas conservado en la BD (Pilar 10: 15 últimas).
  static const int historyLimit = 15;

  Map<String, dynamic> toMap() => {
        'epochMs': epochMs,
        'enemyId': enemyId,
        'enemyName': enemyName,
        'victory': victory,
        'damageTotal': damageTotal,
        'maxHit': maxHit,
        'bullseyes': bullseyes,
        'counterflicks': counterflicks,
        'mergesToThree': mergesToThree,
        'mvpCardId': mvpCardId,
        'damageByCard': damageByCard,
        'playerHpLeft': playerHpLeft,
      };

  Map<String, dynamic> toSql() => {
        'epoch_ms': epochMs,
        'enemy_id': enemyId,
        'enemy_name': enemyName,
        'victory': victory ? 1 : 0,
        'damage_total': damageTotal,
        'max_hit': maxHit,
        'bullseyes': bullseyes,
        'counterflicks': counterflicks,
        'merges_to_three': mergesToThree,
        'mvp_card_id': mvpCardId,
        'breakdown_json': jsonEncode(damageByCard),
        'player_hp_left': playerHpLeft,
      };

  static BattleLogEntry fromMap(Map<String, dynamic> m) {
    final breakdown = m['damageByCard'];
    final parsed = <String, int>{};
    if (breakdown is Map) {
      breakdown.forEach((k, v) {
        if (v is num) parsed['$k'] = v.toInt();
      });
    }
    return BattleLogEntry(
      epochMs: (m['epochMs'] as num?)?.toInt() ?? 0,
      enemyId: (m['enemyId'] as String?) ?? 'unknown',
      enemyName: (m['enemyName'] as String?) ?? 'Desconocido',
      victory: m['victory'] == true || m['victory'] == 1,
      damageTotal: (m['damageTotal'] as num?)?.toInt() ?? 0,
      maxHit: (m['maxHit'] as num?)?.toInt() ?? 0,
      bullseyes: (m['bullseyes'] as num?)?.toInt() ?? 0,
      counterflicks: (m['counterflicks'] as num?)?.toInt() ?? 0,
      mergesToThree: (m['mergesToThree'] as num?)?.toInt() ?? 0,
      mvpCardId: (m['mvpCardId'] as String?) ?? '',
      damageByCard: parsed,
      playerHpLeft: (m['playerHpLeft'] as num?)?.toInt() ?? 0,
    );
  }

  /// Reconstruye una entrada desde una fila SQLite.
  static BattleLogEntry fromSqlRow(Map<String, Object?> row) {
    Map<String, int> breakdown = {};
    final raw = row['breakdown_json'];
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          decoded.forEach((k, v) {
            if (v is num) breakdown['$k'] = v.toInt();
          });
        }
      } catch (_) {}
    }
    return BattleLogEntry(
      epochMs: (row['epoch_ms'] as num?)?.toInt() ?? 0,
      enemyId: (row['enemy_id'] as String?) ?? 'unknown',
      enemyName: (row['enemy_name'] as String?) ?? 'Desconocido',
      victory: (row['victory'] as num?)?.toInt() == 1,
      damageTotal: (row['damage_total'] as num?)?.toInt() ?? 0,
      maxHit: (row['max_hit'] as num?)?.toInt() ?? 0,
      bullseyes: (row['bullseyes'] as num?)?.toInt() ?? 0,
      counterflicks: (row['counterflicks'] as num?)?.toInt() ?? 0,
      mergesToThree: (row['merges_to_three'] as num?)?.toInt() ?? 0,
      mvpCardId: (row['mvp_card_id'] as String?) ?? '',
      damageByCard: breakdown,
      playerHpLeft: (row['player_hp_left'] as num?)?.toInt() ?? 0,
    );
  }

  /// Porcentaje de aporte de una carta (0.0 - 1.0).
  double shareOf(String cardId) {
    final total = damageTotal <= 0
        ? damageByCard.values.fold<int>(0, (a, b) => a + b)
        : damageTotal;
    if (total <= 0) return 0;
    return (damageByCard[cardId] ?? 0) / total;
  }

  /// Id de la carta MVP (mayor aporte) o '' si no hay datos.
  String computeMvp() {
    String best = '';
    int bestVal = -1;
    damageByCard.forEach((k, v) {
      if (v > bestVal) {
        bestVal = v;
        best = k;
      }
    });
    return best;
  }
}

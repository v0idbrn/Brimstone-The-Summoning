/// Expediciones Abisales — dominio puro (Etapa III, Pilar 6).
///
/// El invocador envía cartas **suplentes** (fuera del escuadrón activo) a una
/// de 3 misiones temporales. Al regresar reclama Oro, Esquirlas y XP de
/// Maestría. La persistencia usa `startTimeEpochMs` en SQLite v10.
enum ExpeditionDuration {
  corta(15 * 60 * 1000),
  media(60 * 60 * 1000),
  larga(8 * 60 * 60 * 1000);

  const ExpeditionDuration(this.millis);
  final int millis;

  String get label => switch (this) {
        ExpeditionDuration.corta => 'Reconocimiento (15 min)',
        ExpeditionDuration.media => 'Incursión (1 h)',
        ExpeditionDuration.larga => 'Campaña Abisal (8 h)',
      };
}

/// Las 3 misiones temporales fijas.
class ExpeditionMission {
  final String id;
  final ExpeditionDuration duration;
  final String name;
  final String description;

  const ExpeditionMission({
    required this.id,
    required this.duration,
    required this.name,
    required this.description,
  });
}

const List<ExpeditionMission> expeditionMissions = [
  ExpeditionMission(
    id: 'exp_recon',
    duration: ExpeditionDuration.corta,
    name: 'Reconocimiento del Coral',
    description: 'Batidas rápidas entre las ruinas de coral negro.',
  ),
  ExpeditionMission(
    id: 'exp_raid',
    duration: ExpeditionDuration.media,
    name: 'Incursión al Observatorio',
    description: 'Saquea las torres caídas del observatorio estelar.',
  ),
  ExpeditionMission(
    id: 'exp_campaign',
    duration: ExpeditionDuration.larga,
    name: 'Campaña del Dios Caído',
    description: 'Marcha prolongada hacia el corazón de la Grieta.',
  ),
];

ExpeditionMission missionById(String id) =>
    expeditionMissions.firstWhere((m) => m.id == id);

/// Estado de una misión expedicionaria persistida.
class ExpeditionSlot {
  final String missionId;
  final List<int> cardInstanceIds;

  /// Epoch UTC en ms en que la expedición partió (0 = sin usar).
  final int startedEpochMs;

  const ExpeditionSlot({
    required this.missionId,
    required this.cardInstanceIds,
    required this.startedEpochMs,
  });

  bool get isActive => startedEpochMs > 0;

  bool get isAway => cardInstanceIds.isNotEmpty;

  bool isComplete(int nowEpochMs) =>
      isActive &&
      nowEpochMs - startedEpochMs >= missionById(missionId).duration.millis;

  int remainingMs(int nowEpochMs) => isActive
      ? (missionById(missionId).duration.millis - (nowEpochMs - startedEpochMs))
          .clamp(0, missionById(missionId).duration.millis)
      : 0;

  ExpeditionSlot start(List<int> instanceIds, int nowEpochMs) => ExpeditionSlot(
        missionId: missionId,
        cardInstanceIds: instanceIds,
        startedEpochMs: nowEpochMs,
      );

  ExpeditionSlot reset() => ExpeditionSlot(
      missionId: missionId, cardInstanceIds: const [], startedEpochMs: 0);
}

/// Recompensas base de cada misión: (oro, esquirlas, maestría XP por carta).
(int gold, int shards, int masteryXp) expeditionRewardFor(
    ExpeditionMission m, int cardCount) {
  final factor = cardCount.clamp(1, 4);
  switch (m.duration) {
    case ExpeditionDuration.corta:
      return (60 * factor, 25 * factor, 40 * factor);
    case ExpeditionDuration.media:
      return (260 * factor, 110 * factor, 180 * factor);
    case ExpeditionDuration.larga:
      return (1200 * factor, 520 * factor, 900 * factor);
  }
}

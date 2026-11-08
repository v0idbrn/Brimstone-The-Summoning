import '../entities/relic.dart';

abstract class RelicRepository {
  Future<List<Relic>> getAllRelics();
  Future<void> saveRelic(Relic relic);
}

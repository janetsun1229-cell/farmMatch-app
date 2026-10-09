import '../player_progress.dart';

abstract class ProgressRepository {
  PlayerProgress load();
  Future<void> save(PlayerProgress progress);
}

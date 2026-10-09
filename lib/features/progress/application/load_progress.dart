import '../domain/player_progress.dart';
import '../domain/repositories/progress_repository.dart';

class LoadProgress {
  const LoadProgress(this._repository);

  final ProgressRepository _repository;

  PlayerProgress call() => _repository.load();
}

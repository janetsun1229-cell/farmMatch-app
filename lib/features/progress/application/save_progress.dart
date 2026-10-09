import '../domain/player_progress.dart';
import '../domain/repositories/progress_repository.dart';

class SaveProgress {
  const SaveProgress(this._repository);

  final ProgressRepository _repository;

  Future<void> call(PlayerProgress progress) => _repository.save(progress);
}

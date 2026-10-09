import '../domain/player_progress.dart';
import '../domain/repositories/progress_repository.dart';

class ClearLevel {
  const ClearLevel(this._repository);

  final ProgressRepository _repository;

  Future<PlayerProgress> call(int level) async {
    final current = _repository.load();
    final next = current.copyWith(
      highestCleared:
          level > current.highestCleared ? level : current.highestCleared,
    );
    await _repository.save(next);
    return next;
  }
}

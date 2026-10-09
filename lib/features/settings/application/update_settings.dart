import '../../identity/application/update_nickname.dart';
import '../../identity/domain/repositories/identity_repository.dart';
import '../../progress/domain/player_progress.dart';
import '../../progress/domain/repositories/progress_repository.dart';

class UpdateSettings {
  const UpdateSettings({required this.identity, required this.progress});

  final IdentityRepository identity;
  final ProgressRepository progress;

  Future<String?> rename(String raw) async {
    final result = await UpdateNickname(identity).call(raw);
    return result.ok ? null : result.error;
  }

  Future<PlayerProgress> setMuted(bool muted) {
    final next = progress.load().copyWith(muted: muted);
    return progress.save(next).then((_) => next);
  }
}

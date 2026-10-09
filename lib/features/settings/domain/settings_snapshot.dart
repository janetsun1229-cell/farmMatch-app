import '../../entitlements/domain/entitlements.dart';
import '../../identity/domain/local_user.dart';
import '../../progress/domain/player_progress.dart';

class SettingsSnapshot {
  const SettingsSnapshot(
      {required this.user, required this.progress, required this.entitlements});

  final LocalUser user;
  final PlayerProgress progress;
  final Entitlements entitlements;
}

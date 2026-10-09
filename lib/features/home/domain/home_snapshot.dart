import '../../config/domain/game_config.dart';
import '../../entitlements/domain/entitlements.dart';
import '../../entitlements/domain/level_gate.dart';
import '../../identity/domain/local_user.dart';
import '../../progress/domain/player_progress.dart';

class HomeSnapshot {
  const HomeSnapshot({
    required this.user,
    required this.progress,
    required this.entitlements,
    required this.config,
    required this.level,
    required this.access,
  });

  final LocalUser user;
  final PlayerProgress progress;
  final Entitlements entitlements;
  final GameConfig config;
  final int level;
  final LevelAccess access;
}

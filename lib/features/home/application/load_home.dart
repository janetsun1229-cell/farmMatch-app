import '../../config/domain/game_config.dart';
import '../../entitlements/domain/entitlements.dart';
import '../../entitlements/domain/level_gate.dart';
import '../../identity/domain/local_user.dart';
import '../../progress/domain/player_progress.dart';
import '../domain/home_snapshot.dart';

class LoadHome {
  const LoadHome();

  HomeSnapshot call({
    required LocalUser user,
    required PlayerProgress progress,
    required Entitlements entitlements,
    required GameConfig config,
  }) {
    final level = progress.currentLevel(totalLevels: config.totalLevels);
    return HomeSnapshot(
      user: user,
      progress: progress,
      entitlements: entitlements,
      config: config,
      level: level,
      access: LevelGate(config).check(level, entitlements),
    );
  }
}

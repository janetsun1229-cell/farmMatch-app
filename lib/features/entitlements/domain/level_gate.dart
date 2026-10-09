import '../../config/domain/game_config.dart';
import 'entitlements.dart';

class LevelAccess {
  const LevelAccess({required this.allowed, this.sku});

  final bool allowed;
  final String? sku;
}

class LevelGate {
  const LevelGate(this.config);

  final GameConfig config;

  LevelAccess check(int level, Entitlements entitlements) {
    if (level < 1 || level > config.totalLevels) {
      return const LevelAccess(allowed: false);
    }
    if (level <= config.freeLevelCap) return const LevelAccess(allowed: true);
    final bundle = config.bundleForLevel(level);
    if (bundle == null) return const LevelAccess(allowed: false);
    if (entitlements.owns(bundle.id)) return const LevelAccess(allowed: true);
    return LevelAccess(allowed: false, sku: bundle.id);
  }
}

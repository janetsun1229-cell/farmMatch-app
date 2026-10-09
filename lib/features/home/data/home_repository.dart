import '../../config/domain/game_config.dart';
import '../../entitlements/domain/repositories/entitlement_repository.dart';
import '../../identity/domain/repositories/identity_repository.dart';
import '../../progress/domain/repositories/progress_repository.dart';
import '../application/load_home.dart';
import '../domain/home_snapshot.dart';

class HomeRepository {
  const HomeRepository({
    required this.identity,
    required this.progress,
    required this.entitlements,
    required this.config,
  });

  final IdentityRepository identity;
  final ProgressRepository progress;
  final EntitlementRepository entitlements;
  final GameConfig config;

  HomeSnapshot load() {
    return const LoadHome().call(
      user: identity.loadOrCreate(),
      progress: progress.load(),
      entitlements: entitlements.load(),
      config: config,
    );
  }
}

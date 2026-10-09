import '../../entitlements/domain/repositories/entitlement_repository.dart';
import '../../identity/domain/repositories/identity_repository.dart';
import '../../progress/domain/repositories/progress_repository.dart';
import '../domain/settings_snapshot.dart';

class SettingsRepository {
  const SettingsRepository(
      {required this.identity,
      required this.progress,
      required this.entitlements});

  final IdentityRepository identity;
  final ProgressRepository progress;
  final EntitlementRepository entitlements;

  SettingsSnapshot load() {
    return SettingsSnapshot(
      user: identity.loadOrCreate(),
      progress: progress.load(),
      entitlements: entitlements.load(),
    );
  }
}

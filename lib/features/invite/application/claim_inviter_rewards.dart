import '../../inventory/domain/repositories/inventory_repository.dart';
import '../domain/invite_reward_policy.dart';
import '../domain/ports/invite_directory.dart';

class ClaimInviterRewards {
  const ClaimInviterRewards({
    required InviteDirectory directory,
    required InventoryRepository inventory,
  })  : _directory = directory,
        _inventory = inventory;

  final InviteDirectory _directory;
  final InventoryRepository _inventory;

  /// Applies bundles waiting for this account. Returns how many successes
  /// were collected.
  Future<int> call(String accountId) async {
    final bundles = await _directory.takePendingBundles(accountId);
    if (bundles == 0) return 0;
    final each = InviteRewardPolicy.rewardEach * bundles;
    await _inventory.grant(move: each, undo: each, shuffle: each);
    return bundles;
  }
}

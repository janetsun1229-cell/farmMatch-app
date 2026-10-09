import '../../auth/domain/auth_repository.dart';
import '../../entitlements/domain/entitlements.dart';
import '../../entitlements/domain/repositories/entitlement_repository.dart';
import '../../inventory/domain/repositories/inventory_repository.dart';
import '../../inventory/domain/tool_inventory.dart';
import '../../progress/domain/repositories/progress_repository.dart';
import '../data/local_revision_store.dart';
import '../domain/cloud_snapshot.dart';
import '../domain/merge_policy.dart';
import '../domain/ports/cloud_save_port.dart';

/// Pulls, merges, and pushes when an account is linked.
///
/// Guest play returns immediately and does not call [CloudSavePort]. A failed
/// pull leaves the device record alone.
class SyncCloudSave {
  const SyncCloudSave({
    required AuthRepository auth,
    required CloudSavePort cloud,
    required ProgressRepository progress,
    required InventoryRepository inventory,
    required EntitlementRepository entitlements,
    required LocalRevisionStore revision,
  }) : _auth = auth,
       _cloud = cloud,
       _progress = progress,
       _inventory = inventory,
       _entitlements = entitlements,
       _revision = revision;

  final AuthRepository _auth;
  final CloudSavePort _cloud;
  final ProgressRepository _progress;
  final InventoryRepository _inventory;
  final EntitlementRepository _entitlements;
  final LocalRevisionStore _revision;

  Future<CloudSnapshot?> call() async {
    final link = _auth.loadLink();
    if (link == null) return null;
    final local = _capture(link.accountId);
    final CloudSnapshot? remote;
    try {
      remote = await _cloud.pull(link.accountId);
    } on CloudSaveException {
      return null;
    }
    final merged = CloudMergePolicy.merge(local: local, cloud: remote);
    await _apply(merged);
    try {
      await _cloud.push(merged);
    } on CloudSaveException {
      return merged;
    }
    return merged;
  }

  CloudSnapshot _capture(String accountId) {
    final progress = _progress.load();
    final tools = _inventory.load();
    final entitlements = _entitlements.load();
    return CloudSnapshot(
      accountId: accountId,
      highestCleared: progress.highestCleared,
      move: tools.move,
      undo: tools.undo,
      shuffle: tools.shuffle,
      removeAds: entitlements.removeAds,
      barnBundle: entitlements.barnBundle,
      harvestBundle: entitlements.harvestBundle,
      updatedAt: _revision.read(),
    );
  }

  Future<void> _apply(CloudSnapshot merged) async {
    final progress = _progress.load();
    if (progress.highestCleared != merged.highestCleared) {
      await _progress.save(
        progress.copyWith(highestCleared: merged.highestCleared),
      );
    }
    final tools = _inventory.load();
    if (tools.move != merged.move ||
        tools.undo != merged.undo ||
        tools.shuffle != merged.shuffle) {
      await _inventory.save(
        ToolInventory(
          move: merged.move,
          undo: merged.undo,
          shuffle: merged.shuffle,
        ),
      );
    }
    final entitlements = _entitlements.load();
    if (entitlements.removeAds != merged.removeAds ||
        entitlements.barnBundle != merged.barnBundle ||
        entitlements.harvestBundle != merged.harvestBundle) {
      await _entitlements.save(
        Entitlements(
          removeAds: merged.removeAds,
          barnBundle: merged.barnBundle,
          harvestBundle: merged.harvestBundle,
        ),
      );
    }
    await _revision.write(merged.updatedAt);
  }
}

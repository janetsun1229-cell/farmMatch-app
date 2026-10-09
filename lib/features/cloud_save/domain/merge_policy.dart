import 'cloud_snapshot.dart';

/// Cloud vs local merge.
///
/// 1. `highestCleared` is the max of both sides, so a cleared level never
///    moves backward.
/// 2. Move / Undo / Shuffle counts come from the snapshot with the later
///    `updatedAt`. The clock moves when a level is cleared, tools change, or
///    a gift is claimed. Mute, hints, and nickname stay on the device and do
///    not move it.
/// 3. Equal timestamps take the per-tool max so a tie cannot drop a tool.
/// 4. `removeAds`, `barnBundle`, and `harvestBundle` are OR-combined. They
///    only flip on and are not rolled back by an older device. This is
///    separate from Restore Purchases, which still restores only those three
///    SKUs from the store.
/// 5. The merged `updatedAt` is the later timestamp. A fresh install leaves
///    the local clock at epoch, so the cloud copy restores tools and the
///    higher cleared level.
class CloudMergePolicy {
  const CloudMergePolicy._();

  static CloudSnapshot merge({
    required CloudSnapshot local,
    CloudSnapshot? cloud,
  }) {
    if (cloud == null) return local;
    final localLeads = local.updatedAt.isAfter(cloud.updatedAt);
    final cloudLeads = cloud.updatedAt.isAfter(local.updatedAt);
    final tie = !localLeads && !cloudLeads;
    final int move;
    final int undo;
    final int shuffle;
    if (tie) {
      move = _max(local.move, cloud.move);
      undo = _max(local.undo, cloud.undo);
      shuffle = _max(local.shuffle, cloud.shuffle);
    } else if (localLeads) {
      move = local.move;
      undo = local.undo;
      shuffle = local.shuffle;
    } else {
      move = cloud.move;
      undo = cloud.undo;
      shuffle = cloud.shuffle;
    }
    return CloudSnapshot(
      accountId: local.accountId,
      highestCleared: _max(local.highestCleared, cloud.highestCleared),
      move: move,
      undo: undo,
      shuffle: shuffle,
      removeAds: local.removeAds || cloud.removeAds,
      barnBundle: local.barnBundle || cloud.barnBundle,
      harvestBundle: local.harvestBundle || cloud.harvestBundle,
      updatedAt: localLeads ? local.updatedAt : cloud.updatedAt,
    );
  }

  static int _max(int a, int b) => a > b ? a : b;
}

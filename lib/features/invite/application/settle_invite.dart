import '../../identity/domain/repositories/identity_repository.dart';
import '../../inventory/domain/repositories/inventory_repository.dart';
import '../data/invite_local_store.dart';
import '../domain/invite_reward_policy.dart';
import '../domain/ports/invite_directory.dart';

class SettleInviteResult {
  const SettleInviteResult({
    required this.plan,
    this.inviterName,
    this.message = '',
  });

  final InvitePlan plan;
  final String? inviterName;
  final String message;
}

class SettleInvite {
  const SettleInvite({
    required InviteDirectory directory,
    required InviteLocalStore local,
    required IdentityRepository identity,
    required InventoryRepository inventory,
    this.dayKey,
  })  : _directory = directory,
        _local = local,
        _identity = identity,
        _inventory = inventory;

  final InviteDirectory _directory;
  final InviteLocalStore _local;
  final IdentityRepository _identity;
  final InventoryRepository _inventory;
  final String Function(DateTime now)? dayKey;

  Future<SettleInviteResult> call({
    required int clearedLevel,
    required int highestClearedBefore,
    required DateTime now,
  }) async {
    final local = _local.load();
    final code = local.pendingCode;
    final record = code == null ? null : _directory.lookup(code);
    final user = _identity.loadOrCreate();
    final key = (dayKey ?? _localDay)(now);
    final counts =
        record == null ? null : _directory.counts(record.accountId, key);
    final plan = InviteRewardPolicy.plan(
      clearedLevel: clearedLevel,
      highestClearedBefore: highestClearedBefore,
      accountCreatedAt: user.createdAt,
      now: now,
      alreadyDevice: local.attributed || _directory.deviceUsed(local.deviceId),
      alreadyAccount: _directory.accountUsed(user.id),
      inviterBound: record?.bound ?? false,
      codeKnown: record != null,
      inviterToday: counts?.today ?? 0,
      inviterLifetime: counts?.lifetime ?? 0,
    );
    if (!plan.attribute || record == null) {
      return SettleInviteResult(plan: plan, inviterName: record?.displayName);
    }
    await _directory.markAttributed(
      deviceId: local.deviceId,
      accountId: user.id,
      inviterAccountId: record.accountId,
      dayKey: key,
      payInviter: plan.payInviter,
    );
    await _local.markAttributed();
    if (plan.payInvitee) {
      await _inventory.grant(
        move: InviteRewardPolicy.rewardEach,
        undo: InviteRewardPolicy.rewardEach,
        shuffle: InviteRewardPolicy.rewardEach,
      );
    }
    final message = inviteRewardMessage(
      payInvitee: plan.payInvitee,
      payInviter: plan.payInviter,
      inviterName: record.displayName,
    );
    return SettleInviteResult(
      plan: plan,
      inviterName: record.displayName,
      message: message,
    );
  }

  static String _localDay(DateTime now) {
    final local = now.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

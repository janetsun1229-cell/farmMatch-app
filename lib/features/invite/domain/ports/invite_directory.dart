import '../invite_code.dart';

abstract class InviteDirectory {
  Future<IssuedInvite> issue({
    required String accountId,
    required String displayName,
    required bool bound,
  });

  InviteCodeRecord? lookup(String code);
  bool deviceUsed(String deviceId);
  bool accountUsed(String accountId);
  InviterCount counts(String accountId, String dayKey);
  int pendingBundles(String accountId);

  Future<void> markAttributed({
    required String deviceId,
    required String accountId,
    required String inviterAccountId,
    required String dayKey,
    required bool payInviter,
  });

  Future<int> takePendingBundles(String accountId);
}

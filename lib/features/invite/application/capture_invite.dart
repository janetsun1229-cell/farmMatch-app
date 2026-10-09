import '../../identity/domain/repositories/identity_repository.dart';
import '../data/invite_local_store.dart';
import '../domain/ports/invite_directory.dart';

class CaptureInvite {
  const CaptureInvite({
    required InviteDirectory directory,
    required InviteLocalStore local,
    required IdentityRepository identity,
  })  : _directory = directory,
        _local = local,
        _identity = identity;

  final InviteDirectory _directory;
  final InviteLocalStore _local;
  final IdentityRepository _identity;

  /// Remembers a bound inviter's code. Returns false when this device already
  /// has an attribution or the code cannot pay a reward.
  Future<bool> call(String code) async {
    final local = _local.load();
    if (local.attributed || _directory.deviceUsed(local.deviceId)) {
      return false;
    }
    final record = _directory.lookup(code);
    if (record == null || !record.bound) return false;
    final user = _identity.loadOrCreate();
    if (record.accountId == user.id || _directory.accountUsed(user.id)) {
      return false;
    }
    await _local.setPending(code);
    return true;
  }
}

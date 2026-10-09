import '../domain/cloud_snapshot.dart';
import '../domain/ports/cloud_save_port.dart';

class FakeCloudSaveAdapter implements CloudSavePort {
  FakeCloudSaveAdapter(
    this._store, {
    this.failPull = false,
    this.failPush = false,
  });

  final CloudStore _store;
  final bool failPull;
  final bool failPush;

  @override
  Future<CloudSnapshot?> pull(String accountId) async {
    if (failPull) {
      throw const CloudSaveException('Cloud save is offline.');
    }
    return _store.read(accountId);
  }

  @override
  Future<void> push(CloudSnapshot snapshot) async {
    if (failPush) {
      throw const CloudSaveException('Cloud save is offline.');
    }
    await _store.write(snapshot.accountId, snapshot);
  }
}

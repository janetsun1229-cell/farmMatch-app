import '../cloud_snapshot.dart';

abstract class CloudSavePort {
  Future<CloudSnapshot?> pull(String accountId);
  Future<void> push(CloudSnapshot snapshot);
}

abstract class CloudStore {
  CloudSnapshot? read(String accountId);
  Future<void> write(String accountId, CloudSnapshot snapshot);
}

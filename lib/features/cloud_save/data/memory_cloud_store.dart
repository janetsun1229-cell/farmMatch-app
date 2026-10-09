import '../domain/cloud_snapshot.dart';
import '../domain/ports/cloud_save_port.dart';

class MemoryCloudStore implements CloudStore {
  final Map<String, CloudSnapshot> _rows = {};

  @override
  CloudSnapshot? read(String accountId) => _rows[accountId];

  @override
  Future<void> write(String accountId, CloudSnapshot snapshot) async {
    _rows[accountId] = snapshot;
  }
}

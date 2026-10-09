import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/cloud_snapshot.dart';
import '../domain/ports/cloud_save_port.dart';

/// Stub cloud kept apart from the local progress keys so a test can wipe the
/// device record and still pull the account snapshot.
class PrefsCloudStore implements CloudStore {
  PrefsCloudStore(this._preferences);

  final SharedPreferences _preferences;

  static const key = 'cloud_stub_v1';

  @override
  CloudSnapshot? read(String accountId) {
    final raw = _preferences.getString(key);
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    final row = decoded[accountId];
    if (row is! Map) return null;
    return CloudSnapshot.fromJson(Map<String, dynamic>.from(row));
  }

  @override
  Future<void> write(String accountId, CloudSnapshot snapshot) async {
    final raw = _preferences.getString(key);
    final decoded = raw == null || raw.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(raw);
    final map = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    map[accountId] = snapshot.toJson();
    await _preferences.setString(key, jsonEncode(map));
  }
}

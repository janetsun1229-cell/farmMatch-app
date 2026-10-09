import 'package:shared_preferences/shared_preferences.dart';

class LocalRevisionStore {
  LocalRevisionStore(this._preferences);

  final SharedPreferences _preferences;

  static const key = 'cloud_local_updated_at';

  static final epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  DateTime read() {
    final raw = _preferences.getString(key);
    if (raw == null || raw.isEmpty) return epoch;
    return DateTime.parse(raw).toUtc();
  }

  Future<void> touch([DateTime? now]) => write(now ?? DateTime.now().toUtc());

  Future<void> write(DateTime instant) {
    return _preferences.setString(key, instant.toUtc().toIso8601String());
  }
}

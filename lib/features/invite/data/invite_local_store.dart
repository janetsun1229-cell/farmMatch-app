import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

class InviteLocal {
  const InviteLocal({
    required this.deviceId,
    required this.pendingCode,
    required this.attributed,
  });

  final String deviceId;
  final String? pendingCode;
  final bool attributed;
}

class InviteLocalStore {
  InviteLocalStore(this._preferences);

  final SharedPreferences _preferences;

  static const deviceKey = 'invite_device_id';
  static const pendingKey = 'invite_pending_code';
  static const attributedKey = 'invite_attributed';

  InviteLocal load() {
    return InviteLocal(
      deviceId: _deviceId(),
      pendingCode: _preferences.getString(pendingKey),
      attributed: _preferences.getBool(attributedKey) ?? false,
    );
  }

  Future<void> setPending(String code) async {
    await _preferences.setString(pendingKey, code);
  }

  Future<void> markAttributed() async {
    await _preferences.setBool(attributedKey, true);
    await _preferences.remove(pendingKey);
  }

  String _deviceId() {
    final existing = _preferences.getString(deviceKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final random = Random.secure();
    final id =
        List.generate(16, (_) => random.nextInt(16).toRadixString(16)).join();
    _preferences.setString(deviceKey, id);
    return id;
  }
}

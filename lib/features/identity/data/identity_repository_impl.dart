import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/local_user.dart';
import '../domain/nickname_factory.dart';
import '../domain/repositories/identity_repository.dart';

class IdentityRepositoryImpl implements IdentityRepository {
  IdentityRepositoryImpl(this._preferences, {Random? random})
      : _names = NicknameFactory(random: random);

  static const idKey = 'identity_id';
  static const nicknameKey = 'identity_nickname';
  static const createdKey = 'identity_created_at';

  final SharedPreferences _preferences;
  final NicknameFactory _names;

  @override
  LocalUser? current() {
    final id = _preferences.getString(idKey);
    final nickname = _preferences.getString(nicknameKey);
    final created = _preferences.getString(createdKey);
    if (id == null || nickname == null || created == null) return null;
    return LocalUser(
        id: id, nickname: nickname, createdAt: DateTime.parse(created));
  }

  @override
  LocalUser loadOrCreate() {
    final existing = current();
    if (existing != null) return existing;
    final user = LocalUser(
      id: _newId(),
      nickname: _names.next(),
      createdAt: DateTime.now().toUtc(),
    );
    _preferences.setString(idKey, user.id);
    _preferences.setString(nicknameKey, user.nickname);
    _preferences.setString(createdKey, user.createdAt.toIso8601String());
    return user;
  }

  @override
  Future<LocalUser> updateNickname(String nickname) async {
    final user = loadOrCreate();
    final next = user.copyWith(nickname: NicknameFactory.normalize(nickname));
    await _preferences.setString(nicknameKey, next.nickname);
    return next;
  }

  String _newId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int value) => value.toRadixString(16).padLeft(2, '0');
    final h = bytes.map(hex).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
        '${h.substring(16, 20)}-${h.substring(20)}';
  }
}

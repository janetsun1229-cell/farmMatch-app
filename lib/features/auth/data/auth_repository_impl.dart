import 'package:shared_preferences/shared_preferences.dart';

import '../domain/account_link.dart';
import '../domain/auth_provider_kind.dart';
import '../domain/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._preferences);

  final SharedPreferences _preferences;

  static const providerKey = 'auth_provider';
  static const accountKey = 'auth_account_id';
  static const nameKey = 'auth_display_name';
  static const linkedKey = 'auth_linked_at';
  static const dismissCloudKey = 'auth_dismiss_l5';
  static const dismissInviteKey = 'auth_dismiss_l8';

  @override
  AccountLink? loadLink() {
    final providerName = _preferences.getString(providerKey);
    final accountId = _preferences.getString(accountKey);
    final displayName = _preferences.getString(nameKey);
    final linkedRaw = _preferences.getString(linkedKey);
    if (providerName == null ||
        accountId == null ||
        displayName == null ||
        linkedRaw == null) {
      return null;
    }
    final provider = _parse(providerName);
    if (provider == null) return null;
    return AccountLink(
      provider: provider,
      accountId: accountId,
      displayName: displayName,
      linkedAt: DateTime.parse(linkedRaw).toUtc(),
    );
  }

  @override
  Future<void> saveLink(AccountLink link) async {
    await _preferences.setString(providerKey, link.provider.name);
    await _preferences.setString(accountKey, link.accountId);
    await _preferences.setString(nameKey, link.displayName);
    await _preferences.setString(linkedKey, link.linkedAt.toIso8601String());
  }

  @override
  bool get cloudSaveDismissed => _preferences.getBool(dismissCloudKey) ?? false;

  @override
  bool get inviteDismissed => _preferences.getBool(dismissInviteKey) ?? false;

  @override
  Future<void> dismissCloudSavePrompt() =>
      _preferences.setBool(dismissCloudKey, true);

  @override
  Future<void> dismissInvitePrompt() =>
      _preferences.setBool(dismissInviteKey, true);

  AuthProviderKind? _parse(String raw) {
    for (final kind in AuthProviderKind.values) {
      if (kind.name == raw) return kind;
    }
    return null;
  }
}

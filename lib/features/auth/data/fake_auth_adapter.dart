import '../domain/account_link.dart';
import '../domain/auth_provider_kind.dart';
import '../domain/ports/auth_port.dart';

/// Offline stand-in. Account ids are stable so a later bind hits the same stub
/// cloud record after a local wipe.
class FakeAuthAdapter implements AuthPort {
  FakeAuthAdapter({this.fail = false, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final bool fail;
  final DateTime Function() _clock;

  static String accountIdFor(AuthProviderKind provider) {
    switch (provider) {
      case AuthProviderKind.x:
        return 'stub-x';
      case AuthProviderKind.facebook:
        return 'stub-facebook';
    }
  }

  @override
  Future<AccountLink> bind(AuthProviderKind provider) async {
    if (fail) {
      throw const AuthFailure(
        'Could not link right now. You can keep playing.',
      );
    }
    return AccountLink(
      provider: provider,
      accountId: accountIdFor(provider),
      displayName: provider.label,
      linkedAt: _clock().toUtc(),
    );
  }
}

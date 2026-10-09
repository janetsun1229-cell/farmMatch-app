import 'auth_provider_kind.dart';

class AccountLink {
  const AccountLink({
    required this.provider,
    required this.accountId,
    required this.displayName,
    required this.linkedAt,
  });

  final AuthProviderKind provider;
  final String accountId;
  final String displayName;
  final DateTime linkedAt;
}

class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;
}

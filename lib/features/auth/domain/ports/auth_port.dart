import '../account_link.dart';
import '../auth_provider_kind.dart';

/// Outbound OAuth port. The app ships a fake adapter; a real X or Facebook
/// client can replace it without touching gameplay.
abstract class AuthPort {
  Future<AccountLink> bind(AuthProviderKind provider);
}

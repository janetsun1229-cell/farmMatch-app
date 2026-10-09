import '../domain/account_link.dart';
import '../domain/auth_provider_kind.dart';
import '../domain/auth_repository.dart';
import '../domain/ports/auth_port.dart';

class BindAccount {
  const BindAccount({
    required AuthPort port,
    required AuthRepository repository,
  }) : _port = port,
       _repository = repository;

  final AuthPort _port;
  final AuthRepository _repository;

  Future<AccountLink> call(AuthProviderKind provider) async {
    final link = await _port.bind(provider);
    await _repository.saveLink(link);
    return link;
  }
}

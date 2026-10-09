import '../domain/local_user.dart';
import '../domain/repositories/identity_repository.dart';

class BootstrapIdentity {
  const BootstrapIdentity(this._repository);

  final IdentityRepository _repository;

  LocalUser call() => _repository.loadOrCreate();
}

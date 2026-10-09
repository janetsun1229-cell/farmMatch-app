import '../domain/local_user.dart';
import '../domain/nickname_factory.dart';
import '../domain/repositories/identity_repository.dart';

class UpdateNickname {
  const UpdateNickname(this._repository);

  final IdentityRepository _repository;

  Future<NicknameUpdate> call(String raw) async {
    final error = NicknameFactory.validate(raw);
    if (error != null) return NicknameUpdate.invalid(error);
    final user = await _repository.updateNickname(raw);
    return NicknameUpdate.saved(user);
  }
}

class NicknameUpdate {
  const NicknameUpdate._({this.user, this.error});

  final LocalUser? user;
  final String? error;

  bool get ok => user != null && error == null;

  factory NicknameUpdate.saved(LocalUser user) => NicknameUpdate._(user: user);

  factory NicknameUpdate.invalid(String error) =>
      NicknameUpdate._(error: error);
}

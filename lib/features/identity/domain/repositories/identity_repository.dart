import '../local_user.dart';

abstract class IdentityRepository {
  LocalUser loadOrCreate();
  LocalUser? current();
  Future<LocalUser> updateNickname(String nickname);
}

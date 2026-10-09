import 'account_link.dart';

abstract class AuthRepository {
  AccountLink? loadLink();
  Future<void> saveLink(AccountLink link);
  bool get cloudSaveDismissed;
  bool get inviteDismissed;
  Future<void> dismissCloudSavePrompt();
  Future<void> dismissInvitePrompt();
}

import '../domain/account_link.dart';

class AuthViewState {
  const AuthViewState({
    this.link,
    this.cloudSaveDismissed = false,
    this.inviteDismissed = false,
  });

  final AccountLink? link;
  final bool cloudSaveDismissed;
  final bool inviteDismissed;

  bool get bound => link != null;

  static const guest = AuthViewState();
}

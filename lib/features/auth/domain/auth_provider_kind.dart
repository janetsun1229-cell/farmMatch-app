enum AuthProviderKind { x, facebook }

extension AuthProviderKindLabel on AuthProviderKind {
  String get label {
    switch (this) {
      case AuthProviderKind.x:
        return 'X';
      case AuthProviderKind.facebook:
        return 'Facebook';
    }
  }
}

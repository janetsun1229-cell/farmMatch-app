class LocalUser {
  const LocalUser(
      {required this.id, required this.nickname, required this.createdAt});

  final String id;
  final String nickname;
  final DateTime createdAt;

  LocalUser copyWith({String? nickname}) {
    return LocalUser(
        id: id, nickname: nickname ?? this.nickname, createdAt: createdAt);
  }
}

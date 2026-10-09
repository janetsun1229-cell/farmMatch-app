class IssuedInvite {
  const IssuedInvite({
    required this.link,
    required this.rewards,
    this.code,
  });

  final String link;
  final bool rewards;
  final String? code;
}

class InviteCodeRecord {
  const InviteCodeRecord({
    required this.code,
    required this.accountId,
    required this.displayName,
    required this.bound,
  });

  final String code;
  final String accountId;
  final String displayName;
  final bool bound;
}

class InviterCount {
  const InviterCount({required this.today, required this.lifetime});

  final int today;
  final int lifetime;
}

String inviteCodeFor(String accountId) {
  var hash = 2166136261;
  for (final unit in accountId.codeUnits) {
    hash ^= unit;
    hash = (hash * 16777619) & 0x7fffffff;
  }
  final number = 1000 + (hash % 9000);
  return 'FARM-$number';
}

String inviteLinkFor(String? code) {
  if (code == null || code.isEmpty) return 'farmmatch://';
  return 'farmmatch://invite?code=$code';
}

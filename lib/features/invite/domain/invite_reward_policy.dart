enum InviteDeny {
  ok,
  notLevelOne,
  missingCode,
  alreadyAttributed,
  notNewUser,
  inviterUnbound,
}

class InvitePlan {
  const InvitePlan({
    required this.deny,
    required this.attribute,
    required this.payInvitee,
    required this.payInviter,
  });

  const InvitePlan.skip(this.deny)
      : attribute = false,
        payInvitee = false,
        payInviter = false;

  final InviteDeny deny;
  final bool attribute;
  final bool payInvitee;
  final bool payInviter;

  bool get ok => deny == InviteDeny.ok;
}

/// Bidirectional invite rewards from GAME_FEATURES §3.7.1c / §5.15.
///
/// A success pays both sides Move, Undo, and Shuffle +2. The invitee is
/// attributed once per device and once per account. The inviter is paid only
/// while under 5 successes that day and 50 lifetime. Past the cap the invitee
/// still receives the boost and the attribution is consumed, so the same
/// device cannot shop for another code.
class InviteRewardPolicy {
  const InviteRewardPolicy._();

  static const rewardEach = 2;
  static const dailyMax = 5;
  static const lifetimeMax = 50;
  static const clearLevel = 1;
  static const newAccountMaxAge = Duration(hours: 24);

  static bool qualifiesAsNew({
    required int highestClearedBefore,
    required DateTime accountCreatedAt,
    required DateTime now,
  }) {
    final noOldProgress = highestClearedBefore < clearLevel;
    final young = now.difference(accountCreatedAt) < newAccountMaxAge;
    final notPastL1 = highestClearedBefore < clearLevel;
    return noOldProgress || (young && notPastL1);
  }

  static InvitePlan plan({
    required int clearedLevel,
    required int highestClearedBefore,
    required DateTime accountCreatedAt,
    required DateTime now,
    required bool alreadyDevice,
    required bool alreadyAccount,
    required bool inviterBound,
    required bool codeKnown,
    required int inviterToday,
    required int inviterLifetime,
  }) {
    if (clearedLevel != clearLevel) {
      return const InvitePlan.skip(InviteDeny.notLevelOne);
    }
    if (alreadyDevice || alreadyAccount) {
      return const InvitePlan.skip(InviteDeny.alreadyAttributed);
    }
    if (!codeKnown) return const InvitePlan.skip(InviteDeny.missingCode);
    if (!qualifiesAsNew(
      highestClearedBefore: highestClearedBefore,
      accountCreatedAt: accountCreatedAt,
      now: now,
    )) {
      return const InvitePlan.skip(InviteDeny.notNewUser);
    }
    if (!inviterBound) return const InvitePlan.skip(InviteDeny.inviterUnbound);
    final room = inviterToday < dailyMax && inviterLifetime < lifetimeMax;
    return InvitePlan(
      deny: InviteDeny.ok,
      attribute: true,
      payInvitee: true,
      payInviter: room,
    );
  }
}

String inviteRewardMessage({
  required bool payInvitee,
  required bool payInviter,
  String? inviterName,
}) {
  if (!payInvitee) return '';
  if (payInviter && inviterName != null && inviterName.isNotEmpty) {
    return 'You and $inviterName got boosts!';
  }
  return 'You got free boosts!';
}

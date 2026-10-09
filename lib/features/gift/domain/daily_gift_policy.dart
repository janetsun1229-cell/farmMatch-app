import '../../game/domain/power.dart';

/// Daily gift rules from GAME_FEATURES §3.7.1b and §5.14.
///
/// One tool type per day, at most 3 sends, drawn from a free pool (the
/// caller's inventory is not spent). Each friend can receive at most one gift
/// from you that day. Incoming gifts are not capped at 3; the cap is one per
/// friend per day.
enum GiftDeny { ok, notFriend, poolEmpty, differentTool, alreadyReceived }

class OutboundDay {
  const OutboundDay({
    required this.dayKey,
    this.tool,
    this.sentFriendIds = const [],
  });

  final String dayKey;
  final Power? tool;
  final List<String> sentFriendIds;

  static const maxSends = 3;

  int get sendsUsed => sentFriendIds.length;

  int get sendsLeft => maxSends - sendsUsed;

  OutboundDay copyWith({Power? tool, List<String>? sentFriendIds}) {
    return OutboundDay(
      dayKey: dayKey,
      tool: tool ?? this.tool,
      sentFriendIds: sentFriendIds ?? this.sentFriendIds,
    );
  }
}

class SendPlan {
  const SendPlan._(this.deny, this.next);

  const SendPlan.denied(GiftDeny deny) : this._(deny, null);

  const SendPlan.accepted(OutboundDay next) : this._(GiftDeny.ok, next);

  final GiftDeny deny;
  final OutboundDay? next;

  bool get ok => deny == GiftDeny.ok;
}

class DailyGiftPolicy {
  const DailyGiftPolicy._();

  static String dayKey(DateTime instant) {
    final utc = instant.toUtc();
    final year = utc.year.toString().padLeft(4, '0');
    final month = utc.month.toString().padLeft(2, '0');
    final day = utc.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static OutboundDay forDay(OutboundDay? stored, String dayKey) {
    if (stored == null || stored.dayKey != dayKey) {
      return OutboundDay(dayKey: dayKey);
    }
    return stored;
  }

  static SendPlan planSend({
    required OutboundDay? stored,
    required String dayKey,
    required String friendId,
    required Power tool,
    required bool isFriend,
    required bool friendAlreadyReceivedToday,
  }) {
    if (!isFriend) return const SendPlan.denied(GiftDeny.notFriend);
    final day = forDay(stored, dayKey);
    if (day.tool != null && day.tool != tool) {
      return const SendPlan.denied(GiftDeny.differentTool);
    }
    if (day.sentFriendIds.contains(friendId) || friendAlreadyReceivedToday) {
      return const SendPlan.denied(GiftDeny.alreadyReceived);
    }
    if (day.sendsUsed >= OutboundDay.maxSends) {
      return const SendPlan.denied(GiftDeny.poolEmpty);
    }
    return SendPlan.accepted(
      day.copyWith(tool: tool, sentFriendIds: [...day.sentFriendIds, friendId]),
    );
  }

  static bool acceptIncoming({required bool alreadyFromThisFriendToday}) {
    return !alreadyFromThisFriendToday;
  }
}

String giftDenyMessage(GiftDeny deny, {Power? lockedTool}) {
  switch (deny) {
    case GiftDeny.ok:
      return 'Gift sent.';
    case GiftDeny.notFriend:
      return 'Invite that friend first.';
    case GiftDeny.poolEmpty:
      return "Today's free gifts are all sent.";
    case GiftDeny.differentTool:
      final name = lockedTool?.label ?? 'chosen';
      return "Today's gift is $name.";
    case GiftDeny.alreadyReceived:
      return 'That friend already got a gift today.';
  }
}

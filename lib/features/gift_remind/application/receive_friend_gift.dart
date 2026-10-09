import '../../game/domain/power.dart';
import '../../gift/domain/friend_profile.dart';
import '../../gift/domain/incoming_gift.dart';
import '../../gift/domain/ports/gift_port.dart';
import '../data/gift_remind_store.dart';
import '../domain/gift_notice.dart';
import '../domain/gift_remind_policy.dart';
import '../domain/ports/notification_port.dart';

class ReceiveGiftResult {
  const ReceiveGiftResult({
    required this.gift,
    required this.notice,
    required this.badge,
    required this.askPermission,
  });

  final IncomingGift? gift;
  final GiftNotice? notice;
  final bool badge;
  final bool askPermission;

  static const empty = ReceiveGiftResult(
    gift: null,
    notice: null,
    badge: false,
    askPermission: false,
  );
}

class ReceiveFriendGift {
  const ReceiveFriendGift({
    required GiftPort gifts,
    required GiftRemindStore store,
    required NotificationPort notifications,
  })  : _gifts = gifts,
        _store = store,
        _notifications = notifications;

  final GiftPort _gifts;
  final GiftRemindStore _store;
  final NotificationPort _notifications;

  Future<ReceiveGiftResult> call({
    required String accountId,
    required FriendProfile friend,
    required Power tool,
    required String dayKey,
    required DateTime now,
    required bool inForeground,
  }) async {
    final gift = await _gifts.deliver(
      accountId: accountId,
      friend: friend,
      tool: tool,
      dayKey: dayKey,
    );
    if (gift == null) return ReceiveGiftResult.empty;
    final before = _store.load();
    await _store.markEverReceived();
    final ask = GiftRemindPolicy.permissionAsk(
      granted: before.granted,
      askedAfterInvite: before.askedInvite,
      askedAfterGift: before.askedGift,
      inviteFlowFinished: false,
      firstGiftArrived: !before.everReceived,
    );
    final allow = GiftRemindPolicy.receivePush(
      inForeground: inForeground,
      notificationsEnabled: before.granted,
      lastForFriend: before.lastPushByFriend[friend.id],
      now: now,
    );
    GiftNotice? notice;
    if (allow) {
      notice = GiftNotice(
        id: gift.id,
        body: GiftRemindPolicy.receiveBody(gift.fromName, gift.tool.label),
        link: GiftRemindPolicy.giftLink(
          from: gift.fromName,
          type: GiftRemindPolicy.toolType(gift.tool),
        ),
      );
      await _notifications.show(notice);
      await _store.markPushed(friend.id, now);
    }
    return ReceiveGiftResult(
      gift: gift,
      notice: notice,
      badge: true,
      askPermission: ask == RemindAsk.afterFirstGift,
    );
  }
}

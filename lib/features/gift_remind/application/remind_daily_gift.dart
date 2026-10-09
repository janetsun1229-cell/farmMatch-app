import '../../gift/domain/daily_gift_policy.dart';
import '../../gift/domain/ports/gift_port.dart';
import '../data/gift_remind_store.dart';
import '../domain/gift_notice.dart';
import '../domain/gift_remind_policy.dart';
import '../domain/ports/notification_port.dart';

class DailyRemindResult {
  const DailyRemindResult({required this.notice, required this.badge});

  final GiftNotice? notice;
  final bool badge;

  static const skip = DailyRemindResult(notice: null, badge: false);
}

class RemindDailyGift {
  const RemindDailyGift({
    required GiftPort gifts,
    required GiftRemindStore store,
    required NotificationPort notifications,
  })  : _gifts = gifts,
        _store = store,
        _notifications = notifications;

  final GiftPort _gifts;
  final GiftRemindStore _store;
  final NotificationPort _notifications;

  Future<DailyRemindResult> call({
    required String accountId,
    required bool bound,
    required DateTime now,
    int? slotMinute,
  }) async {
    final dayKey = DailyGiftPolicy.dayKey(now);
    final snapshot = _store.load();
    final friends = await _gifts.listFriends(accountId);
    final outbound = await _gifts.outbound(accountId, dayKey);
    final due = GiftRemindPolicy.dailyDue(
      now: now,
      bound: bound,
      friendCount: friends.length,
      sentToday: outbound.sendsUsed > 0,
      sendsLeft: outbound.sendsLeft,
      alreadyRemindedDay: snapshot.dailyDay,
      dayKey: dayKey,
      slotMinute: slotMinute,
      slotSeed: accountId,
    );
    if (!due) return DailyRemindResult.skip;
    await _store.markDaily(dayKey);
    if (!snapshot.granted) {
      return const DailyRemindResult(notice: null, badge: true);
    }
    final notice = GiftNotice(
      id: 'daily-$dayKey',
      body: GiftRemindPolicy.dailyBody,
      link: GiftRemindPolicy.giftLink(),
    );
    await _notifications.show(notice);
    return DailyRemindResult(notice: notice, badge: true);
  }
}

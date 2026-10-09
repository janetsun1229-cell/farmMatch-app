import '../../game/domain/power.dart';

enum RemindAsk { none, afterInvite, afterFirstGift }

/// Daily gift reminders from GAME_FEATURES §3.7.1f / §5.16.
///
/// GIFT_REMIND_DAILY_WINDOW is 19:00–21:00 local, one reminder that day.
/// GIFT_REMIND_ON_RECEIVE pushes only in the background, once per friend
/// per hour. GIFT_REMIND_ASK_NOTIF_AFTER is the level-8 invite flow or the
/// first gift that arrives during a session. Cold start never asks.
class GiftRemindPolicy {
  const GiftRemindPolicy._();

  static const windowStartHour = 19;
  static const windowEndHour = 21;
  static const windowMinutes = 120;
  static const receiveCooldown = Duration(hours: 1);
  static const dailyMax = 1;
  static const dailyBody = 'Send a boost to a friend today';

  static String receiveBody(String name, String toolLabel) {
    return '$name sent you $toolLabel! Tap to send one back.';
  }

  static String giftLink({String? from, String? type}) {
    final query = <String, String>{
      if (from != null && from.isNotEmpty) 'from': from,
      if (type != null && type.isNotEmpty) 'type': type,
    };
    return Uri(
      scheme: 'farmmatch',
      host: 'gift',
      queryParameters: query.isEmpty ? null : query,
    ).toString();
  }

  static String toolType(Power tool) => tool.name;

  /// Stable minute inside the two-hour window so one account does not
  /// always fire on the hour.
  static int slotMinute(String seed, String dayKey) {
    var hash = 2166136261;
    for (final unit in '$seed|$dayKey'.codeUnits) {
      hash ^= unit;
      hash = (hash * 16777619) & 0x7fffffff;
    }
    return hash % windowMinutes;
  }

  static String localDayKey(DateTime now) {
    final local = now.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static bool inWindow(DateTime now, int minutesAfter19) {
    if (minutesAfter19 < 0 || minutesAfter19 >= windowMinutes) return false;
    final local = now.toLocal();
    final start = DateTime(local.year, local.month, local.day, windowStartHour)
        .add(Duration(minutes: minutesAfter19));
    final end = DateTime(local.year, local.month, local.day, windowEndHour);
    return !local.isBefore(start) && local.isBefore(end);
  }

  static bool dailyDue({
    required DateTime now,
    required bool bound,
    required int friendCount,
    required bool sentToday,
    required int sendsLeft,
    required String? alreadyRemindedDay,
    required String dayKey,
    int? slotMinute,
    String slotSeed = '',
  }) {
    if (!bound || friendCount < 1 || sentToday || sendsLeft <= 0) return false;
    if (alreadyRemindedDay == dayKey) return false;
    final minute = slotMinute ?? GiftRemindPolicy.slotMinute(slotSeed, dayKey);
    return inWindow(now, minute);
  }

  static bool receivePush({
    required bool inForeground,
    required bool notificationsEnabled,
    required DateTime? lastForFriend,
    required DateTime now,
  }) {
    if (inForeground || !notificationsEnabled) return false;
    if (lastForFriend == null) return true;
    return now.difference(lastForFriend) >= receiveCooldown;
  }

  static RemindAsk permissionAsk({
    required bool granted,
    required bool askedAfterInvite,
    required bool askedAfterGift,
    required bool inviteFlowFinished,
    required bool firstGiftArrived,
  }) {
    if (granted) return RemindAsk.none;
    if (inviteFlowFinished && !askedAfterInvite) return RemindAsk.afterInvite;
    if (firstGiftArrived && !askedAfterGift) return RemindAsk.afterFirstGift;
    return RemindAsk.none;
  }
}

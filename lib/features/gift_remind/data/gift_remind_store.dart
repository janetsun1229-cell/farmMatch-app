import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class GiftRemindSnapshot {
  const GiftRemindSnapshot({
    required this.granted,
    required this.askedInvite,
    required this.askedGift,
    required this.everReceived,
    required this.unclaimed,
    required this.dailyDay,
    required this.dailySeenDay,
    required this.lastPushByFriend,
  });

  final bool granted;
  final bool askedInvite;
  final bool askedGift;
  final bool everReceived;
  final int unclaimed;
  final String? dailyDay;
  final String? dailySeenDay;
  final Map<String, DateTime> lastPushByFriend;

  bool showDot(String today) {
    final dailyUnseen = dailyDay == today && dailySeenDay != today;
    return unclaimed > 0 || dailyUnseen;
  }
}

class GiftRemindStore {
  GiftRemindStore(this._preferences);

  final SharedPreferences _preferences;

  static const grantedKey = 'gift_remind_granted';
  static const askedInviteKey = 'gift_remind_asked_l8';
  static const askedGiftKey = 'gift_remind_asked_gift';
  static const everReceivedKey = 'gift_remind_ever_received';
  static const unclaimedKey = 'gift_remind_unclaimed';
  static const dailyDayKey = 'gift_remind_daily_day';
  static const dailySeenKey = 'gift_remind_daily_seen';
  static const pushKey = 'gift_remind_push_at';

  GiftRemindSnapshot load() {
    final raw = _preferences.getString(pushKey);
    final pushes = <String, DateTime>{};
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        for (final entry in decoded.entries) {
          final parsed = DateTime.tryParse('${entry.value}');
          if (parsed != null) pushes['${entry.key}'] = parsed.toUtc();
        }
      }
    }
    return GiftRemindSnapshot(
      granted: _preferences.getBool(grantedKey) ?? false,
      askedInvite: _preferences.getBool(askedInviteKey) ?? false,
      askedGift: _preferences.getBool(askedGiftKey) ?? false,
      everReceived: _preferences.getBool(everReceivedKey) ?? false,
      unclaimed: _preferences.getInt(unclaimedKey) ?? 0,
      dailyDay: _preferences.getString(dailyDayKey),
      dailySeenDay: _preferences.getString(dailySeenKey),
      lastPushByFriend: pushes,
    );
  }

  Future<void> setGranted(bool granted) async {
    await _preferences.setBool(grantedKey, granted);
  }

  Future<void> markAskedInvite() async {
    await _preferences.setBool(askedInviteKey, true);
  }

  Future<void> markAskedGift() async {
    await _preferences.setBool(askedGiftKey, true);
  }

  Future<void> markEverReceived() async {
    await _preferences.setBool(everReceivedKey, true);
  }

  Future<void> setUnclaimed(int count) async {
    await _preferences.setInt(unclaimedKey, count);
  }

  Future<void> markDaily(String dayKey) async {
    await _preferences.setString(dailyDayKey, dayKey);
  }

  Future<void> markDailySeen(String dayKey) async {
    await _preferences.setString(dailySeenKey, dayKey);
  }

  Future<void> markPushed(String friendId, DateTime now) async {
    final snapshot = load();
    final next = Map<String, DateTime>.from(snapshot.lastPushByFriend);
    next[friendId] = now.toUtc();
    await _preferences.setString(
        pushKey,
        jsonEncode({
          for (final entry in next.entries)
            entry.key: entry.value.toUtc().toIso8601String(),
        }));
  }
}

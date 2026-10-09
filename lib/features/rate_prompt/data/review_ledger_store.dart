import 'package:shared_preferences/shared_preferences.dart';

import '../domain/review_snapshot.dart';

class ReviewLedgerStore {
  ReviewLedgerStore(this._preferences);

  final SharedPreferences _preferences;

  static const streakKey = 'review_streak';
  static const saw10Key = 'review_saw_l10';
  static const saw20Key = 'review_saw_l20';
  static const ratedKey = 'review_rated';
  static const shownKey = 'review_shown_at';

  ReviewSnapshot load() {
    final raw = _preferences.getString(shownKey);
    return ReviewSnapshot(
      streak: _preferences.getInt(streakKey) ?? 0,
      sawL10: _preferences.getBool(saw10Key) ?? false,
      sawL20: _preferences.getBool(saw20Key) ?? false,
      firstL10: false,
      firstL20: false,
      rated: _preferences.getBool(ratedKey) ?? false,
      lastShownAt: raw == null ? null : DateTime.tryParse(raw)?.toUtc(),
    );
  }

  Future<ReviewSnapshot> noteClear(int level) async {
    final current = load();
    final next = current.copy(
      streak: current.streak + 1,
      sawL10: current.sawL10 || level == 10,
      sawL20: current.sawL20 || level == 20,
      firstL10: level == 10 && !current.sawL10,
      firstL20: level == 20 && !current.sawL20,
    );
    await _write(next);
    return next;
  }

  Future<ReviewSnapshot> noteFail() async {
    final next = load().copy(streak: 0);
    await _write(next);
    return next;
  }

  Future<void> markShown(DateTime now) async {
    final next = load().copy(lastShownAt: now.toUtc());
    await _write(next);
  }

  Future<void> markRated() async {
    final next = load().copy(rated: true);
    await _write(next);
  }

  Future<void> _write(ReviewSnapshot snapshot) async {
    await _preferences.setInt(streakKey, snapshot.streak);
    await _preferences.setBool(saw10Key, snapshot.sawL10);
    await _preferences.setBool(saw20Key, snapshot.sawL20);
    await _preferences.setBool(ratedKey, snapshot.rated);
    final shown = snapshot.lastShownAt;
    if (shown == null) {
      await _preferences.remove(shownKey);
    } else {
      await _preferences.setString(shownKey, shown.toUtc().toIso8601String());
    }
  }
}

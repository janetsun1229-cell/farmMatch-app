/// Soft in-app review from GAME_FEATURES §3.7.1e / §5.15.
class ReviewPromptGate {
  const ReviewPromptGate._();

  static const streakNeeded = 3;
  static const cooldownDays = 90;
  static const milestoneLevels = [10, 20];

  static bool allow({
    required bool failed,
    required int streak,
    required bool firstClearL10,
    required bool firstClearL20,
    required DateTime? lastShownAt,
    required DateTime now,
    required bool rated,
    required bool blockedByAuthSheet,
  }) {
    if (failed || rated || blockedByAuthSheet) return false;
    if (lastShownAt != null) {
      if (_sameLocalDay(lastShownAt, now)) return false;
      if (now.difference(lastShownAt).inDays < cooldownDays) return false;
    }
    return streak >= streakNeeded || firstClearL10 || firstClearL20;
  }

  static bool _sameLocalDay(DateTime a, DateTime b) {
    final left = a.toLocal();
    final right = b.toLocal();
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }
}

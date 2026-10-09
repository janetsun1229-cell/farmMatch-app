class ReviewSnapshot {
  const ReviewSnapshot({
    required this.streak,
    required this.sawL10,
    required this.sawL20,
    required this.firstL10,
    required this.firstL20,
    required this.rated,
    required this.lastShownAt,
  });

  final int streak;
  final bool sawL10;
  final bool sawL20;
  final bool firstL10;
  final bool firstL20;
  final bool rated;
  final DateTime? lastShownAt;

  static const empty = ReviewSnapshot(
    streak: 0,
    sawL10: false,
    sawL20: false,
    firstL10: false,
    firstL20: false,
    rated: false,
    lastShownAt: null,
  );

  ReviewSnapshot copy({
    int? streak,
    bool? sawL10,
    bool? sawL20,
    bool? firstL10,
    bool? firstL20,
    bool? rated,
    DateTime? lastShownAt,
    bool clearShown = false,
  }) {
    return ReviewSnapshot(
      streak: streak ?? this.streak,
      sawL10: sawL10 ?? this.sawL10,
      sawL20: sawL20 ?? this.sawL20,
      firstL10: firstL10 ?? false,
      firstL20: firstL20 ?? false,
      rated: rated ?? this.rated,
      lastShownAt: clearShown ? null : (lastShownAt ?? this.lastShownAt),
    );
  }
}

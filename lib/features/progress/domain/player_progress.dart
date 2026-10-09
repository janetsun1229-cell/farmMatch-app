class PlayerProgress {
  const PlayerProgress({
    required this.highestCleared,
    required this.muted,
    required this.l1HintShown,
    required this.moveHintShown,
    required this.undoHintShown,
    required this.shuffleHintShown,
  });

  final int highestCleared;
  final bool muted;
  final bool l1HintShown;
  final bool moveHintShown;
  final bool undoHintShown;
  final bool shuffleHintShown;

  static const empty = PlayerProgress(
    highestCleared: 0,
    muted: false,
    l1HintShown: false,
    moveHintShown: false,
    undoHintShown: false,
    shuffleHintShown: false,
  );

  int currentLevel({int totalLevels = 50}) {
    if (highestCleared >= totalLevels) return totalLevels;
    return highestCleared + 1;
  }

  bool get clearedAll => highestCleared >= 50;

  PlayerProgress copyWith({
    int? highestCleared,
    bool? muted,
    bool? l1HintShown,
    bool? moveHintShown,
    bool? undoHintShown,
    bool? shuffleHintShown,
  }) {
    return PlayerProgress(
      highestCleared: highestCleared ?? this.highestCleared,
      muted: muted ?? this.muted,
      l1HintShown: l1HintShown ?? this.l1HintShown,
      moveHintShown: moveHintShown ?? this.moveHintShown,
      undoHintShown: undoHintShown ?? this.undoHintShown,
      shuffleHintShown: shuffleHintShown ?? this.shuffleHintShown,
    );
  }
}

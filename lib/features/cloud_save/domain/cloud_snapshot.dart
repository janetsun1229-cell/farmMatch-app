class CloudSnapshot {
  const CloudSnapshot({
    required this.accountId,
    required this.highestCleared,
    required this.move,
    required this.undo,
    required this.shuffle,
    required this.removeAds,
    required this.barnBundle,
    required this.harvestBundle,
    required this.updatedAt,
  });

  final String accountId;
  final int highestCleared;
  final int move;
  final int undo;
  final int shuffle;
  final bool removeAds;
  final bool barnBundle;
  final bool harvestBundle;
  final DateTime updatedAt;

  CloudSnapshot copyWith({
    int? highestCleared,
    int? move,
    int? undo,
    int? shuffle,
    bool? removeAds,
    bool? barnBundle,
    bool? harvestBundle,
    DateTime? updatedAt,
  }) {
    return CloudSnapshot(
      accountId: accountId,
      highestCleared: highestCleared ?? this.highestCleared,
      move: move ?? this.move,
      undo: undo ?? this.undo,
      shuffle: shuffle ?? this.shuffle,
      removeAds: removeAds ?? this.removeAds,
      barnBundle: barnBundle ?? this.barnBundle,
      harvestBundle: harvestBundle ?? this.harvestBundle,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'accountId': accountId,
      'highestCleared': highestCleared,
      'move': move,
      'undo': undo,
      'shuffle': shuffle,
      'removeAds': removeAds,
      'barnBundle': barnBundle,
      'harvestBundle': harvestBundle,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  static CloudSnapshot fromJson(Map<String, dynamic> json) {
    return CloudSnapshot(
      accountId: json['accountId'] as String,
      highestCleared: (json['highestCleared'] as num).toInt(),
      move: (json['move'] as num).toInt(),
      undo: (json['undo'] as num).toInt(),
      shuffle: (json['shuffle'] as num).toInt(),
      removeAds: json['removeAds'] as bool,
      barnBundle: json['barnBundle'] as bool,
      harvestBundle: json['harvestBundle'] as bool,
      updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
    );
  }
}

class CloudSaveException implements Exception {
  const CloudSaveException(this.message);

  final String message;
}

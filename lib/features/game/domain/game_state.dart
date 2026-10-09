import 'tile_card.dart';

enum GameStatus { play, fail, win }

class GameState {
  const GameState({
    required this.level,
    required this.board,
    required this.tray,
    required this.hold,
    required this.undoIds,
    required this.status,
    this.trayCapacity = 7,
    this.holdCapacity = 6,
    this.moveTake = 3,
  });

  final int level;
  final List<TileCard> board;
  final List<TileCard> tray;
  final List<TileCard> hold;
  final List<String> undoIds;
  final GameStatus status;
  final int trayCapacity;
  final int holdCapacity;
  final int moveTake;

  factory GameState.opening({
    required int level,
    required List<TileCard> board,
    int trayCapacity = 7,
    int holdCapacity = 6,
    int moveTake = 3,
  }) {
    return GameState(
      level: level,
      board: List<TileCard>.from(board),
      tray: const [],
      hold: const [],
      undoIds: const [],
      status: GameStatus.play,
      trayCapacity: trayCapacity,
      holdCapacity: holdCapacity,
      moveTake: moveTake,
    );
  }

  bool get isClear => board.isEmpty && tray.isEmpty && hold.isEmpty;

  GameState copyWith({
    List<TileCard>? board,
    List<TileCard>? tray,
    List<TileCard>? hold,
    List<String>? undoIds,
    GameStatus? status,
  }) {
    return GameState(
      level: level,
      board: board ?? this.board,
      tray: tray ?? this.tray,
      hold: hold ?? this.hold,
      undoIds: undoIds ?? this.undoIds,
      status: status ?? this.status,
      trayCapacity: trayCapacity,
      holdCapacity: holdCapacity,
      moveTake: moveTake,
    );
  }
}

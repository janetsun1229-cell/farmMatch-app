import '../../game/domain/power.dart';

class ToolInventory {
  const ToolInventory(
      {required this.move, required this.undo, required this.shuffle});

  final int move;
  final int undo;
  final int shuffle;

  static const empty = ToolInventory(move: 0, undo: 0, shuffle: 0);

  int of(Power power) {
    switch (power) {
      case Power.move:
        return move;
      case Power.undo:
        return undo;
      case Power.shuffle:
        return shuffle;
    }
  }

  ToolInventory copyWith({int? move, int? undo, int? shuffle}) {
    return ToolInventory(
      move: move ?? this.move,
      undo: undo ?? this.undo,
      shuffle: shuffle ?? this.shuffle,
    );
  }

  ToolInventory grant(
      {required int move, required int undo, required int shuffle}) {
    return ToolInventory(
      move: this.move + move,
      undo: this.undo + undo,
      shuffle: this.shuffle + shuffle,
    );
  }

  ToolInventory consume(Power power) {
    switch (power) {
      case Power.move:
        return copyWith(move: move > 0 ? move - 1 : 0);
      case Power.undo:
        return copyWith(undo: undo > 0 ? undo - 1 : 0);
      case Power.shuffle:
        return copyWith(shuffle: shuffle > 0 ? shuffle - 1 : 0);
    }
  }
}

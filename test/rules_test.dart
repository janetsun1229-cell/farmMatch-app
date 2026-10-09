import 'package:farm_match/features/game/domain/game_state.dart';
import 'package:farm_match/features/game/domain/item_type.dart';
import 'package:farm_match/features/game/domain/rules/cover.dart';
import 'package:farm_match/features/game/domain/rules/game_rules.dart';
import 'package:farm_match/features/game/domain/tile_card.dart';
import 'package:flutter_test/flutter_test.dart';

TileCard tile(String id, ItemType type,
    {double x = 0, double y = 0, int layer = 0, bool pile = false}) {
  return TileCard(
      id: id,
      type: type,
      x: x,
      y: y,
      w: 0.88,
      h: 0.88,
      layer: layer,
      pile: pile,
      rot: 0);
}

void main() {
  test('three of a kind clear and compact the tray', () {
    final board = [
      tile('a', ItemType.apple, x: 0),
      tile('b', ItemType.apple, x: 2),
      tile('c', ItemType.apple, x: 4),
      tile('d', ItemType.boots, x: 6),
    ];
    var state = GameState.opening(level: 1, board: board);
    state = GameRules.tap(state, 'd');
    state = GameRules.tap(state, 'a');
    state = GameRules.tap(state, 'b');
    state = GameRules.tap(state, 'c');
    expect(state.tray.map((card) => card.id), ['d']);
    expect(state.status, GameStatus.play);
    expect(state.undoIds, ['d']);
  });

  test('a full tray with no triple fails', () {
    final board = [
      for (var i = 0; i < 7; i++) tile('c$i', ItemType.values[i], x: i * 2),
    ];
    var state = GameState.opening(level: 4, board: board);
    for (var i = 0; i < 7; i++) {
      state = GameRules.tap(state, 'c$i');
    }
    expect(state.status, GameStatus.fail);
    expect(state.tray, hasLength(7));
  });

  test('clearing the table, tray, and hold wins', () {
    final board = [
      tile('a', ItemType.corn, x: 0),
      tile('b', ItemType.corn, x: 2),
      tile('c', ItemType.corn, x: 4),
    ];
    var state = GameState.opening(level: 1, board: board);
    state = GameRules.tap(state, 'a');
    state = GameRules.tap(state, 'b');
    state = GameRules.tap(state, 'c');
    expect(state.status, GameStatus.win);
    expect(state.isClear, isTrue);
  });

  test('covered cards cannot be tapped and carry a veil', () {
    final board = [
      tile('low', ItemType.hay, x: 0, y: 0, layer: 0),
      tile('high', ItemType.hay, x: 0.2, y: 0.2, layer: 1),
    ];
    final state = GameState.opening(level: 3, board: board);
    expect(isCovered(board.first, board), isTrue);
    expect(coverDepth(board.first, board), 1);
    expect(veilOpacityForDepth(coverDepth(board.first, board)), 0.25);
    expect(GameRules.canTap(state, 'low'), isFalse);
    expect(GameRules.tap(state, 'low').board, hasLength(2));
  });

  test(
      'move takes up to three leftmost cards and undo returns the last tray card',
      () {
    final board = [
      for (var i = 0; i < 4; i++) tile('c$i', ItemType.values[i], x: i * 2),
    ];
    var state = GameState.opening(level: 9, board: board);
    state = GameRules.tap(state, 'c0');
    state = GameRules.tap(state, 'c1');
    final moved = GameRules.move(state)!;
    expect(moved.hold.map((card) => card.id), ['c0', 'c1']);
    expect(moved.tray, isEmpty);
    expect(moved.undoIds, isEmpty);
    var back = GameRules.takeHold(moved, 'c1');
    expect(back.tray.single.id, 'c1');
    back = GameRules.undo(back)!;
    expect(back.tray, isEmpty);
    expect(back.board.any((card) => card.id == 'c1'), isTrue);
  });

  test('shuffle changes faces and keeps positions', () {
    final board = [
      tile('a', ItemType.apple, x: 0, y: 1),
      tile('b', ItemType.boots, x: 2, y: 1),
      tile('c', ItemType.carrot, x: 4, y: 1),
    ];
    final state = GameState.opening(level: 12, board: board);
    final shuffled = GameRules.shuffle(state, 99)!;
    expect(shuffled.board.map((card) => card.id), ['a', 'b', 'c']);
    expect(shuffled.board.map((card) => card.x), [0, 2, 4]);
    expect(
      shuffled.board.map((card) => card.type.id).toList(),
      isNot(equals(['apple', 'boots', 'carrot'])),
    );
    expect(shuffled.tray, isEmpty);
  });

  test('hold cards block a win until they return', () {
    final board = [
      tile('a', ItemType.milk, x: 0),
      tile('b', ItemType.milk, x: 2),
      tile('c', ItemType.milk, x: 4),
      tile('d', ItemType.wool, x: 6),
    ];
    var state = GameState.opening(level: 6, board: board);
    state = GameRules.tap(state, 'd');
    state = GameRules.move(state)!;
    state = GameRules.tap(state, 'a');
    state = GameRules.tap(state, 'b');
    state = GameRules.tap(state, 'c');
    expect(state.hold, hasLength(1));
    expect(state.status, GameStatus.play);
  });
}

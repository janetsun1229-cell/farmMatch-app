import '../game_state.dart';
import '../item_type.dart';
import '../tile_card.dart';
import '../level/js_rng.dart';
import 'cover.dart';

class MatchPlan {
  const MatchPlan({required this.type, required this.ids});

  final ItemType type;
  final List<String> ids;
}

class GameRules {
  const GameRules._();

  static TileCard? findOnBoard(GameState state, String id) {
    for (final card in state.board) {
      if (card.id == id) return card;
    }
    return null;
  }

  static bool canTap(GameState state, String id) {
    if (state.status != GameStatus.play) return false;
    final card = findOnBoard(state, id);
    if (card == null) return false;
    return !isCovered(card, state.board);
  }

  /// Removes [id] from the board. The card is not in the tray yet.
  static ({GameState state, TileCard card})? lift(GameState state, String id) {
    if (!canTap(state, id)) return null;
    final card = findOnBoard(state, id)!;
    final board = state.board.where((item) => item.id != id).toList();
    return (state: state.copyWith(board: board), card: card);
  }

  static ({GameState state, TileCard card})? liftHold(
      GameState state, String id) {
    if (state.status != GameStatus.play) return null;
    if (state.tray.length >= state.trayCapacity) return null;
    TileCard? card;
    for (final item in state.hold) {
      if (item.id == id) card = item;
    }
    if (card == null) return null;
    final hold = state.hold.where((item) => item.id != id).toList();
    return (state: state.copyWith(hold: hold), card: card);
  }

  static GameState placeInTray(GameState state, TileCard card) {
    return state.copyWith(
      tray: [...state.tray, card],
      undoIds: [...state.undoIds, card.id],
    );
  }

  static MatchPlan? peekMatch(GameState state, {ItemType? prefer}) {
    int countOf(ItemType type) {
      var n = 0;
      for (final card in state.tray) {
        if (card.type == type) n += 1;
      }
      return n;
    }

    ItemType? type;
    if (prefer != null && countOf(prefer) >= 3) {
      type = prefer;
    } else {
      for (final card in state.tray) {
        if (countOf(card.type) >= 3) {
          type = card.type;
          break;
        }
      }
    }
    if (type == null) return null;
    final ids = <String>[];
    for (final card in state.tray) {
      if (card.type == type && ids.length < 3) ids.add(card.id);
    }
    return MatchPlan(type: type, ids: ids);
  }

  static GameState stripMatch(GameState state, MatchPlan plan) {
    final remove = plan.ids.toSet();
    return state.copyWith(
      tray: state.tray.where((card) => !remove.contains(card.id)).toList(),
      undoIds: state.undoIds.where((id) => !remove.contains(id)).toList(),
    );
  }

  static GameState judge(GameState state) {
    if (state.tray.length >= state.trayCapacity) {
      return state.copyWith(status: GameStatus.fail);
    }
    if (state.isClear) return state.copyWith(status: GameStatus.win);
    return state.copyWith(status: GameStatus.play);
  }

  /// Instant path used by tests and the scripted solution.
  static GameState tap(GameState state, String id) {
    final lifted = lift(state, id);
    if (lifted == null) return state;
    return _dropAndResolve(lifted.state, lifted.card);
  }

  static GameState takeHold(GameState state, String id) {
    final lifted = liftHold(state, id);
    if (lifted == null) return state;
    return _dropAndResolve(lifted.state, lifted.card);
  }

  static GameState _dropAndResolve(GameState state, TileCard card) {
    var next = placeInTray(state, card);
    final plan = peekMatch(next, prefer: card.type);
    if (plan != null) next = stripMatch(next, plan);
    return judge(next);
  }

  static int moveCount(GameState state) {
    if (state.tray.isEmpty) return 0;
    final n =
        state.tray.length < state.moveTake ? state.tray.length : state.moveTake;
    if (state.hold.length + n > state.holdCapacity) return 0;
    return n;
  }

  static GameState? move(GameState state) {
    if (state.status != GameStatus.play) return null;
    final n = moveCount(state);
    if (n <= 0) return null;
    final taken = state.tray.sublist(0, n);
    final moved = taken.map((card) => card.id).toSet();
    return state.copyWith(
      tray: state.tray.sublist(n),
      hold: [...state.hold, ...taken],
      undoIds: state.undoIds.where((id) => !moved.contains(id)).toList(),
    );
  }

  static GameState? undo(GameState state) {
    if (state.status != GameStatus.play || state.undoIds.isEmpty) return null;
    final id = state.undoIds.last;
    TileCard? card;
    for (final item in state.tray) {
      if (item.id == id) card = item;
    }
    if (card == null) return null;
    return state.copyWith(
      board: [...state.board, card],
      tray: state.tray.where((item) => item.id != id).toList(),
      undoIds: state.undoIds.sublist(0, state.undoIds.length - 1),
    );
  }

  static GameState? shuffle(GameState state, int seed) {
    if (state.status != GameStatus.play || state.board.length < 2) return null;
    final rand = JsRng(seed);
    final types = state.board.map((card) => card.type).toList();
    final before = types.map((type) => type.id).join();
    jsShuffle(types, rand.next);
    if (types.map((type) => type.id).join() == before) {
      final tmp = types[0];
      types[0] = types[1];
      types[1] = tmp;
    }
    final board = <TileCard>[
      for (var i = 0; i < state.board.length; i++)
        state.board[i].copyWith(type: types[i]),
    ];
    return state.copyWith(board: board);
  }

  /// Soft-help: no free board card or held card can finish a triple.
  static bool stuck(GameState state) {
    final pool = <TileCard>[...freeCards(state.board), ...state.hold];
    if (pool.isEmpty) return true;
    final trayCount = <ItemType, int>{};
    for (final card in state.tray) {
      trayCount[card.type] = (trayCount[card.type] ?? 0) + 1;
    }
    final poolCount = <ItemType, int>{};
    for (final card in pool) {
      poolCount[card.type] = (poolCount[card.type] ?? 0) + 1;
    }
    for (final entry in poolCount.entries) {
      if (entry.value >= 3) return false;
      if ((trayCount[entry.key] ?? 0) + entry.value >= 3) return false;
    }
    return true;
  }
}

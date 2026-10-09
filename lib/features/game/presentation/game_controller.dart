import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/domain/game_config.dart';
import '../../inventory/domain/tool_inventory.dart';
import '../application/enter_level.dart';
import '../domain/game_state.dart';
import '../domain/level/dealer.dart';
import '../domain/power.dart';
import '../domain/rules/game_rules.dart';
import '../domain/tile_card.dart';
import '../../../app/providers.dart';

const _unset = Object();

class GameVm {
  const GameVm({
    required this.level,
    this.loading = false,
    this.error,
    this.lockedSku,
    this.game,
    this.pending,
    this.freeMove = 0,
    this.freeUndo = 0,
    this.freeShuffle = 0,
    this.showL1Hint = false,
    this.powerHint,
    this.stuckFlashed = false,
    this.flashToken = 0,
    this.shuffleSerial = 1,
  });

  final int level;
  final bool loading;
  final String? error;
  final String? lockedSku;
  final GameState? game;
  final TileCard? pending;
  final int freeMove;
  final int freeUndo;
  final int freeShuffle;
  final bool showL1Hint;
  final Power? powerHint;
  final bool stuckFlashed;
  final int flashToken;
  final int shuffleSerial;

  factory GameVm.loading(int level) => GameVm(level: level, loading: true);

  bool get locked =>
      lockedSku != null ||
      (error == null && !loading && game == null && lockedSku != null);

  int freeFor(Power power) {
    switch (power) {
      case Power.move:
        return freeMove;
      case Power.undo:
        return freeUndo;
      case Power.shuffle:
        return freeShuffle;
    }
  }

  GameVm copyWith({
    bool? loading,
    Object? error = _unset,
    Object? lockedSku = _unset,
    Object? game = _unset,
    Object? pending = _unset,
    int? freeMove,
    int? freeUndo,
    int? freeShuffle,
    bool? showL1Hint,
    Object? powerHint = _unset,
    bool? stuckFlashed,
    int? flashToken,
    int? shuffleSerial,
  }) {
    return GameVm(
      level: level,
      loading: loading ?? this.loading,
      error: error == _unset ? this.error : error as String?,
      lockedSku: lockedSku == _unset ? this.lockedSku : lockedSku as String?,
      game: game == _unset ? this.game : game as GameState?,
      pending: pending == _unset ? this.pending : pending as TileCard?,
      freeMove: freeMove ?? this.freeMove,
      freeUndo: freeUndo ?? this.freeUndo,
      freeShuffle: freeShuffle ?? this.freeShuffle,
      showL1Hint: showL1Hint ?? this.showL1Hint,
      powerHint: powerHint == _unset ? this.powerHint : powerHint as Power?,
      stuckFlashed: stuckFlashed ?? this.stuckFlashed,
      flashToken: flashToken ?? this.flashToken,
      shuffleSerial: shuffleSerial ?? this.shuffleSerial,
    );
  }
}

final gameControllerProvider =
    NotifierProvider.autoDispose.family<GameController, GameVm, int>(
  GameController.new,
);

class GameController extends AutoDisposeFamilyNotifier<GameVm, int> {
  bool _winSaved = false;
  var _alive = true;

  GameVm get snapshot => state;

  @override
  GameVm build(int level) {
    ref.onDispose(() => _alive = false);
    Future<void>.microtask(() => _open(level));
    return GameVm.loading(level);
  }

  Future<void> _open(int level) async {
    await Future<void>.delayed(Duration.zero);
    if (!_alive) return;
    final config = ref.read(configProvider);
    final entry = const EnterLevel().call(
      level: level,
      progress: ref.read(progressProvider),
      entitlements: ref.read(entitlementsProvider),
      config: config,
    );
    if (!entry.allowed) {
      state = GameVm(level: level, lockedSku: entry.lockedSku ?? 'barn_bundle');
      return;
    }
    try {
      final dealt = Dealer.deal(level);
      if (!_alive) return;
      state = GameVm(
        level: level,
        game: GameState.opening(
          level: level,
          board: dealt.cards,
          trayCapacity: config.traySlots,
          holdCapacity: config.holdMax,
          moveTake: config.moveTakeMax,
        ),
        freeMove: entry.freeMove,
        freeUndo: entry.freeUndo,
        freeShuffle: entry.freeShuffle,
        showL1Hint: entry.showL1Hint,
        powerHint: entry.powerHint,
      );
    } catch (_) {
      if (!_alive) return;
      state = GameVm(level: level, error: 'Could not lay out this level.');
    }
  }

  Future<void> retry() async {
    _winSaved = false;
    final level = state.level;
    state = GameVm.loading(level);
    await _open(level);
  }

  Future<void> acknowledgeHints() async {
    if (state.showL1Hint) {
      await ref.read(progressProvider.notifier).markL1Hint();
    }
    final hint = state.powerHint;
    if (hint != null) {
      await ref.read(progressProvider.notifier).markPowerHint(hint);
    }
  }

  void dismissL1Hint() {
    if (!state.showL1Hint) return;
    state = state.copyWith(showL1Hint: false);
  }

  TileCard? liftBoard(String id) {
    final game = state.game;
    if (game == null || state.pending != null) return null;
    final lifted = GameRules.lift(game, id);
    if (lifted == null) return null;
    state = state.copyWith(
        game: lifted.state, pending: lifted.card, showL1Hint: false);
    return lifted.card;
  }

  TileCard? liftHold(String id) {
    final game = state.game;
    if (game == null || state.pending != null) return null;
    final lifted = GameRules.liftHold(game, id);
    if (lifted == null) return null;
    state = state.copyWith(game: lifted.state, pending: lifted.card);
    return lifted.card;
  }

  void finishDrop() {
    final pending = state.pending;
    final game = state.game;
    if (pending == null || game == null) return;
    state = state.copyWith(
        game: GameRules.placeInTray(game, pending), pending: null);
  }

  MatchPlan? peek() {
    final game = state.game;
    if (game == null) return null;
    final prefer = game.tray.isEmpty ? null : game.tray.last.type;
    return GameRules.peekMatch(game, prefer: prefer);
  }

  void commitStrip(MatchPlan plan) {
    final game = state.game;
    if (game == null) return;
    state =
        state.copyWith(game: GameRules.judge(GameRules.stripMatch(game, plan)));
  }

  void commitJudge() {
    final game = state.game;
    if (game == null) return;
    state = state.copyWith(game: GameRules.judge(game));
  }

  bool canUse(Power power, ToolInventory bank) {
    final game = state.game;
    final config = ref.read(configProvider);
    if (game == null || game.status != GameStatus.play || state.pending != null) {
      return false;
    }
    if (!_unlocked(power, game.level, config)) return false;
    if (state.freeFor(power) + bank.of(power) <= 0) return false;
    switch (power) {
      case Power.move:
        return GameRules.moveCount(game) > 0;
      case Power.undo:
        return game.undoIds.isNotEmpty;
      case Power.shuffle:
        return game.board.length >= 2;
    }
  }

  bool _unlocked(Power power, int level, GameConfig config) {
    switch (power) {
      case Power.move:
        return level >= config.powers.moveUnlockLevel;
      case Power.undo:
        return level >= config.powers.undoUnlockLevel;
      case Power.shuffle:
        return level >= config.powers.shuffleUnlockLevel;
    }
  }

  int unlockLevel(Power power) {
    final powers = ref.read(configProvider).powers;
    switch (power) {
      case Power.move:
        return powers.moveUnlockLevel;
      case Power.undo:
        return powers.undoUnlockLevel;
      case Power.shuffle:
        return powers.shuffleUnlockLevel;
    }
  }

  bool _spend(Power power, ToolInventory bank) {
    if (state.freeFor(power) > 0) {
      state = state.copyWith(
        freeMove: power == Power.move ? state.freeMove - 1 : null,
        freeUndo: power == Power.undo ? state.freeUndo - 1 : null,
        freeShuffle: power == Power.shuffle ? state.freeShuffle - 1 : null,
      );
      return true;
    }
    if (bank.of(power) <= 0) return false;
    ref.read(inventoryProvider.notifier).consume(power);
    return true;
  }

  bool useMove(ToolInventory bank) {
    if (!canUse(Power.move, bank)) return false;
    if (!_spend(Power.move, bank)) return false;
    final next = GameRules.move(state.game!);
    if (next == null) return false;
    state = state.copyWith(
      game: next,
      powerHint: state.powerHint == Power.move ? null : state.powerHint,
    );
    onSettled(bank);
    return true;
  }

  bool useUndo(ToolInventory bank) {
    if (!canUse(Power.undo, bank)) return false;
    if (!_spend(Power.undo, bank)) return false;
    final next = GameRules.undo(state.game!);
    if (next == null) return false;
    state = state.copyWith(
      game: next,
      powerHint: state.powerHint == Power.undo ? null : state.powerHint,
    );
    onSettled(bank);
    return true;
  }

  bool useShuffle(ToolInventory bank) {
    if (!canUse(Power.shuffle, bank)) return false;
    final game = state.game!;
    final seed =
        game.level * 100003 + game.board.length * 17 + state.shuffleSerial;
    final next = GameRules.shuffle(game, seed);
    if (next == null) return false;
    if (!_spend(Power.shuffle, bank)) return false;
    state = state.copyWith(
      game: next,
      shuffleSerial: state.shuffleSerial + 1,
      powerHint: state.powerHint == Power.shuffle ? null : state.powerHint,
    );
    onSettled(bank);
    return true;
  }

  void onSettled(ToolInventory bank) {
    final game = state.game;
    if (game == null || game.status != GameStatus.play || state.stuckFlashed) {
      return;
    }
    final config = ref.read(configProvider);
    if (game.tray.length < config.softHelp.deadBoardTrayMin) return;
    if (!GameRules.stuck(game)) return;
    final canHelp = canUse(Power.move, bank) || canUse(Power.shuffle, bank);
    state = state.copyWith(
        stuckFlashed: true,
        flashToken: canHelp ? state.flashToken + 1 : state.flashToken);
  }

  Future<void> persistWin() async {
    if (_winSaved) return;
    final game = state.game;
    if (game == null || game.status != GameStatus.win) return;
    _winSaved = true;
    await ref.read(progressProvider.notifier).clearLevel(game.level);
  }
}

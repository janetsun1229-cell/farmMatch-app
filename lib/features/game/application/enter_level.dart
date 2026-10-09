import '../../config/domain/game_config.dart';
import '../../entitlements/domain/entitlements.dart';
import '../../entitlements/domain/level_gate.dart';
import '../../progress/domain/player_progress.dart';
import '../domain/power.dart';

class LevelEntry {
  const LevelEntry({
    required this.allowed,
    required this.freeMove,
    required this.freeUndo,
    required this.freeShuffle,
    required this.showL1Hint,
    this.powerHint,
    this.lockedSku,
  });

  final bool allowed;
  final int freeMove;
  final int freeUndo;
  final int freeShuffle;
  final bool showL1Hint;
  final Power? powerHint;
  final String? lockedSku;
}

class EnterLevel {
  const EnterLevel();

  LevelEntry call({
    required int level,
    required PlayerProgress progress,
    required Entitlements entitlements,
    required GameConfig config,
  }) {
    final access = LevelGate(config).check(level, entitlements);
    if (!access.allowed) {
      return LevelEntry(
        allowed: false,
        freeMove: 0,
        freeUndo: 0,
        freeShuffle: 0,
        showL1Hint: false,
        lockedSku: access.sku,
      );
    }
    final powers = config.powers;
    final uses = powers.perLevelUses;
    Power? hint;
    if (level == powers.moveUnlockLevel && !progress.moveHintShown) {
      hint = Power.move;
    } else if (level == powers.undoUnlockLevel && !progress.undoHintShown) {
      hint = Power.undo;
    } else if (level == powers.shuffleUnlockLevel &&
        !progress.shuffleHintShown) {
      hint = Power.shuffle;
    }
    return LevelEntry(
      allowed: true,
      freeMove: level >= powers.moveUnlockLevel ? uses : 0,
      freeUndo: level >= powers.undoUnlockLevel ? uses : 0,
      freeShuffle: level >= powers.shuffleUnlockLevel ? uses : 0,
      showL1Hint: level == 1 && !progress.l1HintShown,
      powerHint: hint,
    );
  }
}

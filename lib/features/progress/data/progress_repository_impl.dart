import 'package:shared_preferences/shared_preferences.dart';

import '../domain/player_progress.dart';
import '../domain/repositories/progress_repository.dart';

class ProgressRepositoryImpl implements ProgressRepository {
  ProgressRepositoryImpl(this._preferences);

  final SharedPreferences _preferences;

  static const clearedKey = 'progress_cleared';
  static const mutedKey = 'progress_muted';
  static const l1Key = 'progress_l1_hint';
  static const moveKey = 'progress_hint_move';
  static const undoKey = 'progress_hint_undo';
  static const shuffleKey = 'progress_hint_shuffle';

  @override
  PlayerProgress load() {
    return PlayerProgress(
      highestCleared: _preferences.getInt(clearedKey) ?? 0,
      muted: _preferences.getBool(mutedKey) ?? false,
      l1HintShown: _preferences.getBool(l1Key) ?? false,
      moveHintShown: _preferences.getBool(moveKey) ?? false,
      undoHintShown: _preferences.getBool(undoKey) ?? false,
      shuffleHintShown: _preferences.getBool(shuffleKey) ?? false,
    );
  }

  @override
  Future<void> save(PlayerProgress progress) async {
    await _preferences.setInt(clearedKey, progress.highestCleared);
    await _preferences.setBool(mutedKey, progress.muted);
    await _preferences.setBool(l1Key, progress.l1HintShown);
    await _preferences.setBool(moveKey, progress.moveHintShown);
    await _preferences.setBool(undoKey, progress.undoHintShown);
    await _preferences.setBool(shuffleKey, progress.shuffleHintShown);
  }
}

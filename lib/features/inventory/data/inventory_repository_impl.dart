import 'package:shared_preferences/shared_preferences.dart';

import '../../game/domain/power.dart';
import '../domain/repositories/inventory_repository.dart';
import '../domain/tool_inventory.dart';

class InventoryRepositoryImpl implements InventoryRepository {
  InventoryRepositoryImpl(this._preferences);

  final SharedPreferences _preferences;

  static const moveKey = 'inv_move';
  static const undoKey = 'inv_undo';
  static const shuffleKey = 'inv_shuffle';

  @override
  ToolInventory load() {
    return ToolInventory(
      move: _preferences.getInt(moveKey) ?? 0,
      undo: _preferences.getInt(undoKey) ?? 0,
      shuffle: _preferences.getInt(shuffleKey) ?? 0,
    );
  }

  @override
  Future<ToolInventory> save(ToolInventory inventory) async {
    await _preferences.setInt(moveKey, inventory.move);
    await _preferences.setInt(undoKey, inventory.undo);
    await _preferences.setInt(shuffleKey, inventory.shuffle);
    return inventory;
  }

  @override
  Future<ToolInventory> grant(
      {required int move, required int undo, required int shuffle}) {
    return save(load().grant(move: move, undo: undo, shuffle: shuffle));
  }

  @override
  Future<ToolInventory> consume(Power power) => save(load().consume(power));
}

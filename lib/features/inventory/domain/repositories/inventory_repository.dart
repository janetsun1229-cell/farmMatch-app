import '../../../game/domain/power.dart';
import '../tool_inventory.dart';

abstract class InventoryRepository {
  ToolInventory load();
  Future<ToolInventory> save(ToolInventory inventory);
  Future<ToolInventory> grant(
      {required int move, required int undo, required int shuffle});
  Future<ToolInventory> consume(Power power);
}

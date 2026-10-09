import '../../game/domain/power.dart';
import '../domain/repositories/inventory_repository.dart';
import '../domain/tool_inventory.dart';

class ConsumeTool {
  const ConsumeTool(this._repository);

  final InventoryRepository _repository;

  Future<ToolInventory> call(Power power) => _repository.consume(power);
}

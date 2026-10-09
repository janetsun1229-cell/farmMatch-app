import '../domain/repositories/inventory_repository.dart';
import '../domain/tool_inventory.dart';

class GrantTools {
  const GrantTools(this._repository);

  final InventoryRepository _repository;

  Future<ToolInventory> call(
      {required int move, required int undo, required int shuffle}) {
    return _repository.grant(move: move, undo: undo, shuffle: shuffle);
  }
}

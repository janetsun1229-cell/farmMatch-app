import '../../game/domain/power.dart';
import '../../inventory/domain/repositories/inventory_repository.dart';
import '../../inventory/domain/tool_inventory.dart';
import '../domain/ports/gift_port.dart';

class ClaimDailyGift {
  const ClaimDailyGift({
    required GiftPort port,
    required InventoryRepository inventory,
  }) : _port = port,
       _inventory = inventory;

  final GiftPort _port;
  final InventoryRepository _inventory;

  Future<ToolInventory?> call({
    required String accountId,
    required String giftId,
  }) async {
    final gift = await _port.claim(accountId: accountId, giftId: giftId);
    if (gift == null) return null;
    return _inventory.grant(
      move: gift.tool == Power.move ? 1 : 0,
      undo: gift.tool == Power.undo ? 1 : 0,
      shuffle: gift.tool == Power.shuffle ? 1 : 0,
    );
  }
}

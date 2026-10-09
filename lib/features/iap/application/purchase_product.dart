import '../../config/domain/game_config.dart';
import '../../entitlements/domain/repositories/entitlement_repository.dart';
import '../../inventory/domain/repositories/inventory_repository.dart';
import '../domain/iap_verifier.dart';
import '../domain/store_client.dart';
import '../domain/store_receipt.dart';

class PurchaseProduct {
  const PurchaseProduct({
    required StoreClient store,
    required IapVerifier verifier,
    required EntitlementRepository entitlements,
    required InventoryRepository inventory,
    required this.platform,
    this.packageName,
  })  : _store = store,
        _verifier = verifier,
        _entitlements = entitlements,
        _inventory = inventory;

  final StoreClient _store;
  final IapVerifier _verifier;
  final EntitlementRepository _entitlements;
  final InventoryRepository _inventory;
  final String platform;
  final String? packageName;

  Future<PurchaseOutcome> call(IapSku sku) async {
    final StoreReceipt receipt;
    try {
      receipt = await _store.buy(sku);
    } on IapException catch (error) {
      return PurchaseOutcome.failure(error.code, error.message);
    } catch (_) {
      return PurchaseOutcome.failure('STORE_ERROR', 'Purchase failed.');
    }
    final verified = await _verifier.verify(
      platform: platform,
      productId: sku.id,
      receipt: receipt.receipt,
      packageName: packageName,
    );
    if (!verified.ok) {
      return PurchaseOutcome.failure(verified.code, verified.message);
    }
    if (sku.isTools) {
      await _inventory.grant(move: sku.each, undo: sku.each, shuffle: sku.each);
    } else if (sku.id == 'remove_ads' ||
        sku.id == 'barn_bundle' ||
        sku.id == 'harvest_bundle') {
      await _entitlements.applySku(sku.id);
    }
    return PurchaseOutcome.success(sku.id);
  }
}

import '../../entitlements/application/restore_entitlements.dart';
import '../domain/iap_verifier.dart';
import '../domain/store_client.dart';
import '../domain/store_receipt.dart';

class RestorePurchases {
  const RestorePurchases({
    required StoreClient store,
    required IapVerifier verifier,
    required RestoreEntitlements restoreEntitlements,
    required this.platform,
    this.packageName,
  })  : _store = store,
        _verifier = verifier,
        _restoreEntitlements = restoreEntitlements;

  final StoreClient _store;
  final IapVerifier _verifier;
  final RestoreEntitlements _restoreEntitlements;
  final String platform;
  final String? packageName;

  Future<RestoreOutcome> call() async {
    final List<StoreReceipt> receipts;
    try {
      receipts = await _store.restoreNonConsumables();
    } on IapException catch (error) {
      return RestoreOutcome(restoredSkus: const [], message: error.message);
    } catch (_) {
      return const RestoreOutcome(
          restoredSkus: [], message: 'Could not restore purchases.');
    }
    final accepted = <String>[];
    for (final receipt in receipts) {
      if (receipt.consumable) continue;
      if (receipt.productId != 'remove_ads' &&
          receipt.productId != 'barn_bundle' &&
          receipt.productId != 'harvest_bundle') {
        continue;
      }
      final verified = await _verifier.verify(
        platform: platform,
        productId: receipt.productId,
        receipt: receipt.receipt,
        packageName: packageName,
      );
      if (!verified.ok) continue;
      accepted.add(receipt.productId);
    }
    await _restoreEntitlements(accepted);
    if (accepted.isEmpty) {
      return const RestoreOutcome(
          restoredSkus: [], message: 'Nothing to restore.');
    }
    return RestoreOutcome(
        restoredSkus: accepted, message: 'Purchases restored.');
  }
}

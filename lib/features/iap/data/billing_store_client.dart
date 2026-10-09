import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import '../../config/domain/game_config.dart';
import '../domain/store_client.dart';
import '../domain/store_receipt.dart';

/// Prepared StoreKit 2 / Play Billing wiring via `in_app_purchase`.
/// Selected when the app is built with `--dart-define=USE_FAKE_STORE=false`.
class BillingStoreClient implements StoreClient {
  BillingStoreClient({InAppPurchase? iap})
      : _iap = iap ?? InAppPurchase.instance;

  final InAppPurchase _iap;

  @override
  Future<StoreReceipt> buy(IapSku sku) async {
    final available = await _iap.isAvailable();
    if (!available) {
      throw const IapException(
          'STORE_UNAVAILABLE', 'The store is not available.');
    }
    final response = await _iap.queryProductDetails({sku.id});
    if (response.productDetails.isEmpty) {
      throw const IapException(
          'PRODUCT_NOT_FOUND', 'This item is not in the store.');
    }
    final details = response.productDetails.first;
    final completer = Completer<StoreReceipt>();
    late final StreamSubscription<List<PurchaseDetails>> subscription;
    subscription = _iap.purchaseStream.listen((purchases) async {
      for (final purchase in purchases) {
        if (purchase.productID != sku.id) continue;
        if (purchase.status == PurchaseStatus.pending) continue;
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
        if (completer.isCompleted) continue;
        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          final token = purchase.verificationData.serverVerificationData;
          completer.complete(
            StoreReceipt(
              productId: sku.id,
              receipt: token,
              transactionId: purchase.purchaseID ?? token,
              consumable: sku.consumable,
            ),
          );
        } else if (purchase.status == PurchaseStatus.canceled) {
          completer.completeError(
              const IapException('USER_CANCELED', 'Purchase canceled.'));
        } else if (purchase.status == PurchaseStatus.error) {
          completer.completeError(
            IapException(
                'STORE_ERROR', purchase.error?.message ?? 'Purchase failed.'),
          );
        }
      }
    });
    try {
      final param = PurchaseParam(productDetails: details);
      final started = sku.consumable
          ? await _iap.buyConsumable(purchaseParam: param)
          : await _iap.buyNonConsumable(purchaseParam: param);
      if (!started) {
        throw const IapException(
            'STORE_ERROR', 'Could not start the purchase.');
      }
      return await completer.future.timeout(const Duration(minutes: 2));
    } on TimeoutException {
      throw const IapException('STORE_ERROR', 'The purchase timed out.');
    } finally {
      await subscription.cancel();
    }
  }

  @override
  Future<List<StoreReceipt>> restoreNonConsumables() async {
    final available = await _iap.isAvailable();
    if (!available) {
      throw const IapException(
          'STORE_UNAVAILABLE', 'The store is not available.');
    }
    final found = <String, StoreReceipt>{};
    final subscription = _iap.purchaseStream.listen((purchases) async {
      for (final purchase in purchases) {
        final id = purchase.productID;
        if (id != 'remove_ads' &&
            id != 'barn_bundle' &&
            id != 'harvest_bundle') {
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          continue;
        }
        if (purchase.status == PurchaseStatus.restored ||
            purchase.status == PurchaseStatus.purchased) {
          final token = purchase.verificationData.serverVerificationData;
          found[id] = StoreReceipt(
            productId: id,
            receipt: token,
            transactionId: purchase.purchaseID ?? token,
            consumable: false,
          );
        }
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      }
    });
    try {
      await _iap.restorePurchases();
      await Future<void>.delayed(const Duration(seconds: 3));
      return found.values.toList();
    } finally {
      await subscription.cancel();
    }
  }
}

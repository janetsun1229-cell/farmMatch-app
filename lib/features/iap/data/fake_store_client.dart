import 'package:shared_preferences/shared_preferences.dart';

import '../../config/domain/game_config.dart';
import '../domain/store_client.dart';
import '../domain/store_receipt.dart';

/// CI and local stand-in. Non-consumables are remembered so Restore Purchases
/// can put them back. Tool packs are not remembered.
class FakeStoreClient implements StoreClient {
  FakeStoreClient(this._preferences, {this.latency = Duration.zero});

  static const ledgerKey = 'iap_fake_owned';

  final SharedPreferences _preferences;
  final Duration latency;

  @override
  Future<StoreReceipt> buy(IapSku sku) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    final txn = 'fake:${sku.id}:${DateTime.now().microsecondsSinceEpoch}';
    if (!sku.consumable) {
      final owned = _preferences.getStringList(ledgerKey) ?? <String>[];
      if (!owned.contains(sku.id)) {
        await _preferences.setStringList(ledgerKey, [...owned, sku.id]);
      }
    }
    return StoreReceipt(
      productId: sku.id,
      receipt: txn,
      transactionId: txn,
      consumable: sku.consumable,
    );
  }

  @override
  Future<List<StoreReceipt>> restoreNonConsumables() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    final owned = _preferences.getStringList(ledgerKey) ?? const <String>[];
    return [
      for (final id in owned)
        if (id == 'remove_ads' || id == 'barn_bundle' || id == 'harvest_bundle')
          StoreReceipt(
            productId: id,
            receipt: 'fake:$id:restore',
            transactionId: 'fake:$id:restore',
            consumable: false,
          ),
    ];
  }
}

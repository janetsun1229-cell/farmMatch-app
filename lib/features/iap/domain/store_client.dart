import '../../config/domain/game_config.dart';
import 'store_receipt.dart';

/// StoreKit 2 / Play Billing boundary. UI and game code never call a store SDK.
abstract class StoreClient {
  Future<StoreReceipt> buy(IapSku sku);
  Future<List<StoreReceipt>> restoreNonConsumables();
}

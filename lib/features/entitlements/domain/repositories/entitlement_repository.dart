import '../entitlements.dart';

abstract class EntitlementRepository {
  Entitlements load();
  Future<Entitlements> save(Entitlements entitlements);
  Future<Entitlements> applySku(String sku);
}

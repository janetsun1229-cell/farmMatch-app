import '../domain/entitlements.dart';
import '../domain/repositories/entitlement_repository.dart';

class ApplyPurchase {
  const ApplyPurchase(this._repository);

  final EntitlementRepository _repository;

  Future<Entitlements> call(String sku) => _repository.applySku(sku);
}

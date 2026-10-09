import '../domain/entitlements.dart';
import '../domain/repositories/entitlement_repository.dart';

/// Applies only non-consumable SKUs. Callers must not pass tool packs.
class RestoreEntitlements {
  const RestoreEntitlements(this._repository);

  final EntitlementRepository _repository;

  Future<Entitlements> call(Iterable<String> skus) async {
    var current = _repository.load();
    for (final sku in skus) {
      if (sku != 'remove_ads' &&
          sku != 'barn_bundle' &&
          sku != 'harvest_bundle') {
        continue;
      }
      current = current.applySku(sku);
    }
    return _repository.save(current);
  }
}

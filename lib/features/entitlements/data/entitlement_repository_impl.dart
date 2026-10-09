import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entitlements.dart';
import '../domain/repositories/entitlement_repository.dart';

class EntitlementRepositoryImpl implements EntitlementRepository {
  EntitlementRepositoryImpl(this._preferences);

  final SharedPreferences _preferences;

  static const adsKey = 'ent_remove_ads';
  static const barnKey = 'ent_barn';
  static const harvestKey = 'ent_harvest';

  @override
  Entitlements load() {
    return Entitlements(
      removeAds: _preferences.getBool(adsKey) ?? false,
      barnBundle: _preferences.getBool(barnKey) ?? false,
      harvestBundle: _preferences.getBool(harvestKey) ?? false,
    );
  }

  @override
  Future<Entitlements> save(Entitlements entitlements) async {
    await _preferences.setBool(adsKey, entitlements.removeAds);
    await _preferences.setBool(barnKey, entitlements.barnBundle);
    await _preferences.setBool(harvestKey, entitlements.harvestBundle);
    return entitlements;
  }

  @override
  Future<Entitlements> applySku(String sku) => save(load().applySku(sku));
}

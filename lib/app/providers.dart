import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/config/application/refresh_config.dart';
import '../features/config/data/config_repository_impl.dart';
import '../features/config/data/remote_config_api.dart';
import '../features/config/domain/game_config.dart';
import '../features/entitlements/application/restore_entitlements.dart';
import '../features/entitlements/data/entitlement_repository_impl.dart';
import '../features/entitlements/domain/entitlements.dart';
import '../features/entitlements/domain/repositories/entitlement_repository.dart';
import '../features/game/domain/power.dart';
import '../features/iap/application/purchase_product.dart';
import '../features/iap/application/restore_purchases.dart';
import '../features/iap/data/billing_store_client.dart';
import '../features/iap/data/fake_store_client.dart';
import '../features/iap/data/iap_api.dart';
import '../features/iap/domain/iap_verifier.dart';
import '../features/iap/domain/store_client.dart';
import '../features/identity/application/bootstrap_identity.dart';
import '../features/identity/application/update_nickname.dart';
import '../features/identity/data/identity_repository_impl.dart';
import '../features/identity/domain/local_user.dart';
import '../features/identity/domain/repositories/identity_repository.dart';
import '../features/inventory/data/inventory_repository_impl.dart';
import '../features/inventory/domain/repositories/inventory_repository.dart';
import '../features/inventory/domain/tool_inventory.dart';
import '../features/progress/application/clear_level.dart';
import '../features/progress/data/progress_repository_impl.dart';
import '../features/progress/domain/player_progress.dart';
import '../features/progress/domain/repositories/progress_repository.dart';

const kUseFakeStore =
    bool.fromEnvironment('USE_FAKE_STORE', defaultValue: true);
const kApiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
const kPackageName = 'com.farmmatch.farm_match';

final prefsProvider =
    Provider<SharedPreferences>((ref) => throw UnimplementedError());

final initialConfigProvider =
    Provider<GameConfig>((ref) => throw UnimplementedError());

final configProvider =
    NotifierProvider<ConfigController, GameConfig>(ConfigController.new);

class ConfigController extends Notifier<GameConfig> {
  @override
  GameConfig build() => ref.watch(initialConfigProvider);

  Future<void> refresh() async {
    final base = kApiBaseUrl.isNotEmpty ? kApiBaseUrl : state.api.baseUrl;
    final repository = ConfigRepositoryImpl(
      preferences: ref.read(prefsProvider),
      initial: state,
      remote: RemoteConfigApi(baseUrl: base, configPath: state.api.configPath),
    );
    final next = await const _Refresh().call(repository);
    state = next;
  }
}

class _Refresh {
  const _Refresh();

  Future<GameConfig> call(ConfigRepositoryImpl repository) {
    return RefreshConfig(repository).call(
      appVersion: '1.0.0',
      platform: Platform.isIOS ? 'ios' : 'android',
    );
  }
}

final identityRepoProvider = Provider<IdentityRepository>(
  (ref) => IdentityRepositoryImpl(ref.watch(prefsProvider)),
);

final progressRepoProvider = Provider<ProgressRepository>(
  (ref) => ProgressRepositoryImpl(ref.watch(prefsProvider)),
);

final inventoryRepoProvider = Provider<InventoryRepository>(
  (ref) => InventoryRepositoryImpl(ref.watch(prefsProvider)),
);

final entitlementRepoProvider = Provider<EntitlementRepository>(
  (ref) => EntitlementRepositoryImpl(ref.watch(prefsProvider)),
);

final identityProvider =
    NotifierProvider<IdentityController, LocalUser>(IdentityController.new);

class IdentityController extends Notifier<LocalUser> {
  @override
  LocalUser build() => BootstrapIdentity(ref.read(identityRepoProvider)).call();

  Future<String?> rename(String raw) async {
    final result =
        await UpdateNickname(ref.read(identityRepoProvider)).call(raw);
    if (!result.ok) return result.error;
    state = result.user!;
    return null;
  }
}

final progressProvider = NotifierProvider<ProgressController, PlayerProgress>(
    ProgressController.new);

class ProgressController extends Notifier<PlayerProgress> {
  @override
  PlayerProgress build() => ref.read(progressRepoProvider).load();

  Future<void> _write(PlayerProgress next) async {
    await ref.read(progressRepoProvider).save(next);
    state = next;
  }

  Future<void> setMuted(bool muted) => _write(state.copyWith(muted: muted));

  Future<void> markL1Hint() => _write(state.copyWith(l1HintShown: true));

  Future<void> markPowerHint(Power power) {
    switch (power) {
      case Power.move:
        return _write(state.copyWith(moveHintShown: true));
      case Power.undo:
        return _write(state.copyWith(undoHintShown: true));
      case Power.shuffle:
        return _write(state.copyWith(shuffleHintShown: true));
    }
  }

  Future<void> clearLevel(int level) async {
    state = await ClearLevel(ref.read(progressRepoProvider)).call(level);
  }

  void reload() => state = ref.read(progressRepoProvider).load();
}

final inventoryProvider = NotifierProvider<InventoryController, ToolInventory>(
    InventoryController.new);

class InventoryController extends Notifier<ToolInventory> {
  @override
  ToolInventory build() => ref.read(inventoryRepoProvider).load();

  Future<void> consume(Power power) async {
    state = await ref.read(inventoryRepoProvider).consume(power);
  }

  void reload() => state = ref.read(inventoryRepoProvider).load();
}

final entitlementsProvider =
    NotifierProvider<EntitlementsController, Entitlements>(
  EntitlementsController.new,
);

class EntitlementsController extends Notifier<Entitlements> {
  @override
  Entitlements build() => ref.read(entitlementRepoProvider).load();

  void reload() => state = ref.read(entitlementRepoProvider).load();
}

final storeClientProvider = Provider<StoreClient>((ref) {
  final prefs = ref.watch(prefsProvider);
  if (kUseFakeStore) {
    return FakeStoreClient(prefs, latency: const Duration(milliseconds: 180));
  }
  return BillingStoreClient();
});

final verifierProvider = Provider<IapVerifier>((ref) {
  final config = ref.watch(configProvider);
  final base = kApiBaseUrl.isNotEmpty ? kApiBaseUrl : config.api.baseUrl;
  return IapApi(
      baseUrl: base,
      verifyPath: config.api.verifyPath,
      allowOfflineStub: base.isEmpty);
});

final purchaseProductProvider = Provider<PurchaseProduct>((ref) {
  return PurchaseProduct(
    store: ref.watch(storeClientProvider),
    verifier: ref.watch(verifierProvider),
    entitlements: ref.watch(entitlementRepoProvider),
    inventory: ref.watch(inventoryRepoProvider),
    platform: Platform.isIOS ? 'ios' : 'android',
    packageName: kPackageName,
  );
});

final restorePurchasesProvider = Provider<RestorePurchases>((ref) {
  return RestorePurchases(
    store: ref.watch(storeClientProvider),
    verifier: ref.watch(verifierProvider),
    restoreEntitlements:
        RestoreEntitlements(ref.watch(entitlementRepoProvider)),
    platform: Platform.isIOS ? 'ios' : 'android',
    packageName: kPackageName,
  );
});

String get storePlatform => Platform.isIOS ? 'ios' : 'android';

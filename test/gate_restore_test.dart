import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:farm_match/features/config/data/remote_config_api.dart';
import 'package:farm_match/features/config/domain/game_config.dart';
import 'package:farm_match/features/entitlements/application/restore_entitlements.dart';
import 'package:farm_match/features/entitlements/data/entitlement_repository_impl.dart';
import 'package:farm_match/features/entitlements/domain/entitlements.dart';
import 'package:farm_match/features/entitlements/domain/level_gate.dart';
import 'package:farm_match/features/iap/application/purchase_product.dart';
import 'package:farm_match/features/iap/application/restore_purchases.dart';
import 'package:farm_match/features/iap/data/fake_store_client.dart';
import 'package:farm_match/features/iap/data/iap_api.dart';
import 'package:farm_match/features/identity/data/identity_repository_impl.dart';
import 'package:farm_match/features/identity/domain/nickname_factory.dart';
import 'package:farm_match/features/inventory/data/inventory_repository_impl.dart';
import 'package:farm_match/features/progress/data/progress_repository_impl.dart';
import 'package:farm_match/features/store_ui/domain/store_copy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled config matches the param table', () {
    final config = parseConfig(
        File('assets/config/default_config.json').readAsStringSync());
    expect(config.freeLevelCap, 20);
    expect(config.totalLevels, 50);
    expect(config.traySlots, 7);
    expect(config.holdMax, 6);
    expect(config.cardScaleVsL1, 0.85);
    expect(config.rotationDeg, 0);
    expect(config.powers.moveUnlockLevel, 5);
    expect(config.powers.undoUnlockLevel, 8);
    expect(config.powers.shuffleUnlockLevel, 12);
    expect(config.powers.perLevelUses, 3);
    expect(config.timing.flySeconds, 0.22);
    expect(config.veilOpacity(1), 0.25);
    expect(config.veilOpacity(4), 0.55);
    expect(config.sku('pack_small')!.each, 5);
    expect(config.sku('pack_medium')!.priceUsd, 4.99);
    expect(config.sku('pack_large')!.each, 30);
    expect(config.sku('barn_bundle')!.levelFrom, 21);
    expect(config.sku('harvest_bundle')!.levelTo, 50);
    expect(config.sku('remove_ads')!.consumable, isFalse);
    final fallback = GameConfig.fallback();
    expect(fallback.traySlots, 7);
    expect(
        jsonDecode(
            File('assets/config/default_config.json').readAsStringSync()),
        isA<Map>());
  });

  test('level gate follows free, barn, and harvest bands', () {
    final gate = LevelGate(GameConfig.fallback());
    expect(gate.check(1, Entitlements.none).allowed, isTrue);
    expect(gate.check(20, Entitlements.none).allowed, isTrue);
    expect(gate.check(21, Entitlements.none).allowed, isFalse);
    expect(gate.check(21, Entitlements.none).sku, 'barn_bundle');
    expect(
        gate
            .check(
                35,
                const Entitlements(
                    removeAds: false, barnBundle: true, harvestBundle: false))
            .allowed,
        isTrue);
    expect(
        gate
            .check(
                36,
                const Entitlements(
                    removeAds: false, barnBundle: true, harvestBundle: false))
            .sku,
        'harvest_bundle');
    expect(
        gate
            .check(
                50,
                const Entitlements(
                    removeAds: true, barnBundle: true, harvestBundle: true))
            .allowed,
        isTrue);
  });

  test('restore puts back ads and bundles only', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = FakeStoreClient(prefs);
    final inventory = InventoryRepositoryImpl(prefs);
    final entitlements = EntitlementRepositoryImpl(prefs);
    final progress = ProgressRepositoryImpl(prefs);
    final identity = IdentityRepositoryImpl(prefs, random: Random(1));
    final verifier = IapApi(allowOfflineStub: true);
    final config = GameConfig.fallback();

    await inventory.grant(move: 4, undo: 1, shuffle: 0);
    await progress.save(progress.load().copyWith(highestCleared: 7));
    final user = identity.loadOrCreate();

    final purchase = PurchaseProduct(
      store: store,
      verifier: verifier,
      entitlements: entitlements,
      inventory: inventory,
      platform: 'android',
    );
    await purchase.call(config.sku('barn_bundle')!);
    await purchase.call(config.sku('remove_ads')!);
    await purchase.call(config.sku('pack_small')!);
    expect(inventory.load().move, 9);

    await entitlements.save(Entitlements.none);
    expect(entitlements.load().barnBundle, isFalse);

    final outcome = await RestorePurchases(
      store: store,
      verifier: verifier,
      restoreEntitlements: RestoreEntitlements(entitlements),
      platform: 'android',
    ).call();

    expect(outcome.restoredSkus, containsAll(['barn_bundle', 'remove_ads']));
    expect(entitlements.load().barnBundle, isTrue);
    expect(entitlements.load().removeAds, isTrue);
    expect(entitlements.load().harvestBundle, isFalse);
    expect(inventory.load().move, 9);
    expect(inventory.load().undo, 6);
    expect(inventory.load().shuffle, 5);
    expect(progress.load().highestCleared, 7);
    expect(identity.current()!.nickname, user.nickname);
    expect(identity.current()!.id, user.id);
  });

  test('store lead does not talk about matching', () {
    final text = StoreCopy.allText.toLowerCase();
    expect(text.contains('match'), isFalse);
    expect(StoreCopy.allText.contains('消除'), isFalse);
    expect(NicknameFactory.validate(''), isNotNull);
    expect(NicknameFactory.validate('Sunny Barn'), isNull);
  });
}

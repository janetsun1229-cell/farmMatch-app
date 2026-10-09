import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/auth/domain/account_link.dart';
import '../features/auth/application/bind_account.dart';
import '../features/auth/data/auth_repository_impl.dart';
import '../features/auth/data/fake_auth_adapter.dart';
import '../features/auth/domain/auth_provider_kind.dart';
import '../features/auth/domain/auth_repository.dart';
import '../features/auth/domain/ports/auth_port.dart';
import '../features/auth/presentation/auth_state.dart';
import '../features/cloud_save/application/sync_cloud_save.dart';
import '../features/cloud_save/data/fake_cloud_save_adapter.dart';
import '../features/cloud_save/data/local_revision_store.dart';
import '../features/cloud_save/data/prefs_cloud_store.dart';
import '../features/cloud_save/domain/ports/cloud_save_port.dart';
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
import '../features/deeplink/application/open_deep_link.dart';
import '../features/deeplink/data/deferred_link_store.dart';
import '../features/entitlements/domain/level_gate.dart';
import '../features/gift/data/fake_gift_adapter.dart';
import '../features/gift/domain/daily_gift_policy.dart';
import '../features/gift/domain/friend_profile.dart';
import '../features/gift/domain/ports/gift_port.dart';
import '../features/gift_remind/application/receive_friend_gift.dart';
import '../features/gift_remind/application/remind_daily_gift.dart';
import '../features/gift_remind/data/fake_notification_adapter.dart';
import '../features/gift_remind/data/gift_remind_store.dart';
import '../features/gift_remind/domain/gift_remind_policy.dart';
import '../features/gift_remind/domain/ports/notification_port.dart';
import '../features/invite/application/capture_invite.dart';
import '../features/invite/application/claim_inviter_rewards.dart';
import '../features/invite/application/settle_invite.dart';
import '../features/invite/data/invite_directory_store.dart';
import '../features/invite/data/invite_local_store.dart';
import '../features/invite/domain/ports/invite_directory.dart';
import '../features/rate_prompt/data/fake_store_review.dart';
import '../features/rate_prompt/data/review_ledger_store.dart';
import '../features/rate_prompt/domain/ports/store_review_port.dart';
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

const kUseFakeStore = bool.fromEnvironment(
  'USE_FAKE_STORE',
  defaultValue: true,
);
const kApiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
const kPackageName = 'com.farmmatch.farm_match';

final prefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(),
);

final initialConfigProvider = Provider<GameConfig>(
  (ref) => throw UnimplementedError(),
);

final configProvider = NotifierProvider<ConfigController, GameConfig>(
  ConfigController.new,
);

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
    return RefreshConfig(
      repository,
    ).call(appVersion: '1.0.0', platform: Platform.isIOS ? 'ios' : 'android');
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

final identityProvider = NotifierProvider<IdentityController, LocalUser>(
  IdentityController.new,
);

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
  ProgressController.new,
);

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

  /// Highest cleared level before the latest [clearLevel] write.
  /// Invite settlement uses it to tell a new player from someone past level 1.
  int lastClearBefore = 0;

  Future<void> clearLevel(int level) async {
    lastClearBefore = state.highestCleared;
    await ref.read(localRevisionProvider).touch();
    await ClearLevel(ref.read(progressRepoProvider)).call(level);
    await ref.read(authStateProvider.notifier).syncFromCloud();
  }

  void reload() => state = ref.read(progressRepoProvider).load();
}

final inventoryProvider = NotifierProvider<InventoryController, ToolInventory>(
  InventoryController.new,
);

class InventoryController extends Notifier<ToolInventory> {
  @override
  ToolInventory build() => ref.read(inventoryRepoProvider).load();

  Future<void> consume(Power power) async {
    await ref.read(localRevisionProvider).touch();
    state = await ref.read(inventoryRepoProvider).consume(power);
    await ref.read(authStateProvider.notifier).syncFromCloud();
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
    allowOfflineStub: base.isEmpty,
  );
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
    restoreEntitlements: RestoreEntitlements(
      ref.watch(entitlementRepoProvider),
    ),
    platform: Platform.isIOS ? 'ios' : 'android',
    packageName: kPackageName,
  );
});

String get storePlatform => Platform.isIOS ? 'ios' : 'android';

final localRevisionProvider = Provider<LocalRevisionStore>(
  (ref) => LocalRevisionStore(ref.watch(prefsProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(ref.watch(prefsProvider)),
);

final authPortProvider = Provider<AuthPort>((ref) => FakeAuthAdapter());

final cloudSavePortProvider = Provider<CloudSavePort>(
  (ref) => FakeCloudSaveAdapter(PrefsCloudStore(ref.watch(prefsProvider))),
);

final giftPortProvider = Provider<GiftPort>(
  (ref) => FakeGiftAdapter(preferences: ref.watch(prefsProvider)),
);

final syncCloudSaveProvider = Provider<SyncCloudSave>((ref) {
  return SyncCloudSave(
    auth: ref.watch(authRepositoryProvider),
    cloud: ref.watch(cloudSavePortProvider),
    progress: ref.watch(progressRepoProvider),
    inventory: ref.watch(inventoryRepoProvider),
    entitlements: ref.watch(entitlementRepoProvider),
    revision: ref.watch(localRevisionProvider),
  );
});

final authStateProvider = NotifierProvider<AuthController, AuthViewState>(
  AuthController.new,
);

class AuthController extends Notifier<AuthViewState> {
  @override
  AuthViewState build() => _read();

  AuthViewState _read() {
    final repository = ref.read(authRepositoryProvider);
    return AuthViewState(
      link: repository.loadLink(),
      cloudSaveDismissed: repository.cloudSaveDismissed,
      inviteDismissed: repository.inviteDismissed,
    );
  }

  Future<String?> bind(AuthProviderKind provider) async {
    try {
      await BindAccount(
        port: ref.read(authPortProvider),
        repository: ref.read(authRepositoryProvider),
      ).call(provider);
      state = _read();
      await syncFromCloud();
      return null;
    } catch (error) {
      if (error is AuthFailure) return error.message;
      return 'Could not link right now. You can keep playing.';
    }
  }

  Future<void> dismissCloudSave() async {
    await ref.read(authRepositoryProvider).dismissCloudSavePrompt();
    state = _read();
  }

  Future<void> dismissInvite() async {
    await ref.read(authRepositoryProvider).dismissInvitePrompt();
    state = _read();
  }

  Future<void> syncFromCloud() async {
    await ref.read(syncCloudSaveProvider).call();
    ref.read(progressProvider.notifier).reload();
    ref.read(inventoryProvider.notifier).reload();
    ref.read(entitlementsProvider.notifier).reload();
  }
}

final inviteDirectoryProvider = Provider<InviteDirectory>(
  (ref) => InviteDirectoryStore(preferences: ref.watch(prefsProvider)),
);

final inviteLocalProvider = Provider<InviteLocalStore>(
  (ref) => InviteLocalStore(ref.watch(prefsProvider)),
);

final captureInviteProvider = Provider<CaptureInvite>((ref) {
  return CaptureInvite(
    directory: ref.watch(inviteDirectoryProvider),
    local: ref.watch(inviteLocalProvider),
    identity: ref.watch(identityRepoProvider),
  );
});

final settleInviteProvider = Provider<SettleInvite>((ref) {
  return SettleInvite(
    directory: ref.watch(inviteDirectoryProvider),
    local: ref.watch(inviteLocalProvider),
    identity: ref.watch(identityRepoProvider),
    inventory: ref.watch(inventoryRepoProvider),
  );
});

final claimInviterRewardsProvider = Provider<ClaimInviterRewards>((ref) {
  return ClaimInviterRewards(
    directory: ref.watch(inviteDirectoryProvider),
    inventory: ref.watch(inventoryRepoProvider),
  );
});

final deferredLinkProvider = Provider<DeferredLinkStore>(
  (ref) => DeferredLinkStore(ref.watch(prefsProvider), readClipboard: true),
);

final openDeepLinkProvider = Provider<OpenDeepLink>((ref) {
  return OpenDeepLink(
    deferred: ref.watch(deferredLinkProvider),
    capture: ref.watch(captureInviteProvider),
    gate: LevelGate(ref.watch(configProvider)),
    entitlements: () => ref.read(entitlementsProvider),
  );
});

final reviewLedgerProvider = Provider<ReviewLedgerStore>(
  (ref) => ReviewLedgerStore(ref.watch(prefsProvider)),
);

final storeReviewProvider = Provider<StoreReviewPort>(
  (ref) => FakeStoreReview(),
);

final growthToastProvider = NotifierProvider<GrowthToastController, String?>(
  GrowthToastController.new,
);

class GrowthToastController extends Notifier<String?> {
  @override
  String? build() => null;

  void show(String message) {
    if (message.isEmpty) return;
    state = message;
  }

  void clear() => state = null;
}

final inviteBannerProvider = NotifierProvider<InviteBannerController, bool>(
  InviteBannerController.new,
);

class InviteBannerController extends Notifier<bool> {
  @override
  bool build() {
    final local = ref.watch(inviteLocalProvider).load();
    return local.pendingCode != null && !local.attributed;
  }

  void refresh() {
    final local = ref.read(inviteLocalProvider).load();
    state = local.pendingCode != null && !local.attributed;
  }
}

final giftRemindStoreProvider = Provider<GiftRemindStore>(
  (ref) => GiftRemindStore(ref.watch(prefsProvider)),
);

final notificationPortProvider = Provider<NotificationPort>(
  (ref) => FakeNotificationAdapter(),
);

final remindPromptProvider =
    NotifierProvider<RemindPromptController, RemindAsk>(
  RemindPromptController.new,
);

class RemindPromptController extends Notifier<RemindAsk> {
  @override
  RemindAsk build() => RemindAsk.none;

  void request(RemindAsk ask) {
    if (ask == RemindAsk.none || state != RemindAsk.none) return;
    state = ask;
  }

  void clear() => state = RemindAsk.none;
}

class GiftBadge {
  const GiftBadge({required this.unclaimed, required this.showDot});

  final int unclaimed;
  final bool showDot;

  static const clear = GiftBadge(unclaimed: 0, showDot: false);
}

final giftRemindProvider = NotifierProvider<GiftRemindController, GiftBadge>(
  GiftRemindController.new,
);

class GiftRemindController extends Notifier<GiftBadge> {
  var _wasBackground = false;
  var _deferredAsk = false;

  @override
  GiftBadge build() => _badge(ref.watch(giftRemindStoreProvider).load());

  GiftBadge _badge(GiftRemindSnapshot snapshot) {
    final today = DailyGiftPolicy.dayKey(DateTime.now());
    return GiftBadge(
      unclaimed: snapshot.unclaimed,
      showDot: snapshot.showDot(today),
    );
  }

  void backgrounded() => _wasBackground = true;

  Future<void> resumed(DateTime now) async {
    final fromBackground = _wasBackground;
    _wasBackground = false;
    await postDaily(now);
    if (fromBackground && _deferredAsk) {
      _deferredAsk = false;
      ref.read(remindPromptProvider.notifier).request(RemindAsk.afterFirstGift);
    }
  }

  Future<void> refresh() async {
    final link = ref.read(authStateProvider).link;
    final store = ref.read(giftRemindStoreProvider);
    if (link == null) {
      await store.setUnclaimed(0);
    } else {
      final inbox = await ref.read(giftPortProvider).inbox(link.accountId);
      final count = inbox.where((gift) => !gift.claimed).length;
      await store.setUnclaimed(count);
    }
    state = _badge(store.load());
  }

  Future<void> postDaily(DateTime now) async {
    final link = ref.read(authStateProvider).link;
    if (link == null) return;
    await RemindDailyGift(
      gifts: ref.read(giftPortProvider),
      store: ref.read(giftRemindStoreProvider),
      notifications: ref.read(notificationPortProvider),
    ).call(accountId: link.accountId, bound: true, now: now);
    state = _badge(ref.read(giftRemindStoreProvider).load());
  }

  Future<void> afterInviteFlow() async {
    final snapshot = ref.read(giftRemindStoreProvider).load();
    final ask = GiftRemindPolicy.permissionAsk(
      granted: snapshot.granted,
      askedAfterInvite: snapshot.askedInvite,
      askedAfterGift: snapshot.askedGift,
      inviteFlowFinished: true,
      firstGiftArrived: false,
    );
    ref.read(remindPromptProvider.notifier).request(ask);
  }

  Future<void> noteForegroundGift() async {
    await refresh();
    final store = ref.read(giftRemindStoreProvider);
    final snapshot = store.load();
    if (snapshot.unclaimed == 0) return;
    final ask = GiftRemindPolicy.permissionAsk(
      granted: snapshot.granted,
      askedAfterInvite: snapshot.askedInvite,
      askedAfterGift: snapshot.askedGift,
      inviteFlowFinished: false,
      firstGiftArrived: !snapshot.everReceived,
    );
    await store.markEverReceived();
    if (ask == RemindAsk.afterFirstGift) {
      ref.read(remindPromptProvider.notifier).request(ask);
    }
  }

  Future<ReceiveGiftResult> receive({
    required String friendId,
    required String friendName,
    required Power tool,
    required String dayKey,
    required DateTime now,
    required bool inForeground,
  }) async {
    final link = ref.read(authStateProvider).link;
    if (link == null) return ReceiveGiftResult.empty;
    final result = await ReceiveFriendGift(
      gifts: ref.read(giftPortProvider),
      store: ref.read(giftRemindStoreProvider),
      notifications: ref.read(notificationPortProvider),
    ).call(
      accountId: link.accountId,
      friend: FriendProfile(id: friendId, name: friendName),
      tool: tool,
      dayKey: dayKey,
      now: now,
      inForeground: inForeground,
    );
    await refresh();
    if (result.askPermission) {
      if (inForeground) {
        ref
            .read(remindPromptProvider.notifier)
            .request(RemindAsk.afterFirstGift);
      } else {
        _deferredAsk = true;
      }
    }
    return result;
  }

  Future<void> markFriendsOpened(DateTime now) async {
    final store = ref.read(giftRemindStoreProvider);
    await store.markDailySeen(DailyGiftPolicy.dayKey(now));
    state = _badge(store.load());
  }
}

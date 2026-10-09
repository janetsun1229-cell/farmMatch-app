import 'package:farm_match/app/providers.dart';
import 'package:farm_match/features/auth/data/auth_repository_impl.dart';
import 'package:farm_match/features/auth/data/fake_auth_adapter.dart';
import 'package:farm_match/features/auth/domain/auth_provider_kind.dart';
import 'package:farm_match/features/auth/domain/bind_prompt.dart';
import 'package:farm_match/features/auth/presentation/bind_offer_sheet.dart';
import 'package:farm_match/features/cloud_save/application/sync_cloud_save.dart';
import 'package:farm_match/features/cloud_save/data/local_revision_store.dart';
import 'package:farm_match/features/cloud_save/data/memory_cloud_store.dart';
import 'package:farm_match/features/cloud_save/domain/cloud_snapshot.dart';
import 'package:farm_match/features/cloud_save/domain/merge_policy.dart';
import 'package:farm_match/features/cloud_save/domain/ports/cloud_save_port.dart';
import 'package:farm_match/features/entitlements/data/entitlement_repository_impl.dart';
import 'package:farm_match/features/gift/application/claim_daily_gift.dart';
import 'package:farm_match/features/gift/application/send_daily_gift.dart';
import 'package:farm_match/features/gift/data/fake_gift_adapter.dart';
import 'package:farm_match/features/gift/domain/daily_gift_policy.dart';
import 'package:farm_match/features/gift/domain/friend_profile.dart';
import 'package:farm_match/features/inventory/data/inventory_repository_impl.dart';
import 'package:farm_match/features/progress/data/progress_repository_impl.dart';
import 'package:farm_match/features/progress/domain/player_progress.dart';
import 'package:farm_match/features/settings/presentation/settings_page.dart';
import 'package:farm_match/features/game/domain/power.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('bind prompts', () {
    BindPromptKind gate({
      required int level,
      bool bound = false,
      bool cloudSaveDismissed = false,
      bool inviteDismissed = false,
    }) {
      return BindPromptGate.evaluate(
        clearedLevel: level,
        bound: bound,
        cloudSaveDismissed: cloudSaveDismissed,
        inviteDismissed: inviteDismissed,
      );
    }

    test('level 5 offers a skippable cloud save prompt', () {
      expect(gate(level: 5), BindPromptKind.cloudSave);
      expect(BindPromptGate.cloudSaveLevel, 5);
    });

    test('level 5 stays quiet once skipped or already linked', () {
      expect(gate(level: 5, cloudSaveDismissed: true), BindPromptKind.none);
      expect(gate(level: 5, bound: true), BindPromptKind.none);
    });

    test('level 8 offers bind and friends when still a guest', () {
      expect(
        gate(level: 8, cloudSaveDismissed: true),
        BindPromptKind.inviteFriends,
      );
      expect(BindCopy.inviteBody.contains('Please log in'), isFalse);
      expect(BindCopy.cloudSaveBody.contains('skip'), isTrue);
    });

    test('level 8 stays quiet once skipped or already linked', () {
      expect(gate(level: 8, inviteDismissed: true), BindPromptKind.none);
      expect(gate(level: 8, bound: true), BindPromptKind.none);
    });

    test('other levels do not nag, including level 10', () {
      for (final level in [1, 4, 6, 7, 9, 10, 12, 50]) {
        expect(gate(level: level), BindPromptKind.none, reason: 'level $level');
      }
    });
  });

  group('daily gifts', () {
    const day = '2026-10-09';
    const nextDay = '2026-10-10';

    test('one tool type, three sends, one per friend, free pool', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final inventory = InventoryRepositoryImpl(preferences);
      await inventory.grant(move: 5, undo: 5, shuffle: 5);
      final port = FakeGiftAdapter(seedGiftOnInvite: false);
      final friends = <FriendProfile>[];
      for (var i = 0; i < 4; i++) {
        friends.add((await port.invite('me')).friend);
      }
      final send = SendDailyGift(port);

      for (var i = 0; i < 3; i++) {
        final result = await send.call(
          accountId: 'me',
          friendId: friends[i].id,
          tool: Power.move,
          dayKey: day,
        );
        expect(result.ok, isTrue, reason: 'send $i');
      }

      final fourth = await send.call(
        accountId: 'me',
        friendId: friends[3].id,
        tool: Power.move,
        dayKey: day,
      );
      expect(fourth.deny, GiftDeny.poolEmpty);

      final repeat = await send.call(
        accountId: 'me',
        friendId: friends[0].id,
        tool: Power.move,
        dayKey: day,
      );
      expect(repeat.deny, GiftDeny.alreadyReceived);

      final otherType = await send.call(
        accountId: 'me',
        friendId: friends[3].id,
        tool: Power.undo,
        dayKey: nextDay,
      );
      expect(otherType.ok, isTrue);

      final switched = await send.call(
        accountId: 'me',
        friendId: friends[2].id,
        tool: Power.shuffle,
        dayKey: nextDay,
      );
      expect(switched.deny, GiftDeny.differentTool);

      final bank = inventory.load();
      expect(bank.move, 5);
      expect(bank.undo, 5);
      expect(bank.shuffle, 5);
    });

    test('the same friend can deliver at most one gift per day', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final inventory = InventoryRepositoryImpl(preferences);
      final port = FakeGiftAdapter(seedGiftOnInvite: false);
      final friend = (await port.invite('me')).friend;
      final other = const FriendProfile(id: 'pal-other', name: 'Other');

      final first = port.offerIncoming(
        accountId: 'me',
        friend: friend,
        tool: Power.move,
        dayKey: day,
      );
      final second = port.offerIncoming(
        accountId: 'me',
        friend: friend,
        tool: Power.shuffle,
        dayKey: day,
      );
      final fromOther = port.offerIncoming(
        accountId: 'me',
        friend: other,
        tool: Power.undo,
        dayKey: day,
      );
      expect(first, isNotNull);
      expect(second, isNull);
      expect(fromOther, isNotNull);
      expect(
        DailyGiftPolicy.acceptIncoming(alreadyFromThisFriendToday: true),
        isFalse,
      );

      final claimed = await ClaimDailyGift(
        port: port,
        inventory: inventory,
      ).call(accountId: 'me', giftId: first!.id);
      expect(claimed!.move, 1);
      expect(claimed.undo, 0);
      final again = await ClaimDailyGift(
        port: port,
        inventory: inventory,
      ).call(accountId: 'me', giftId: first.id);
      expect(again, isNull);
      expect(inventory.load().move, 1);
    });
  });

  group('cloud merge', () {
    CloudSnapshot snap({
      required int level,
      required DateTime updatedAt,
      int move = 0,
      int undo = 0,
      int shuffle = 0,
      bool removeAds = false,
      bool barn = false,
      bool harvest = false,
    }) {
      return CloudSnapshot(
        accountId: 'stub-x',
        highestCleared: level,
        move: move,
        undo: undo,
        shuffle: shuffle,
        removeAds: removeAds,
        barnBundle: barn,
        harvestBundle: harvest,
        updatedAt: updatedAt,
      );
    }

    test('no cloud row keeps the local snapshot', () {
      final local = snap(level: 3, updatedAt: DateTime.utc(2026, 10, 2));
      expect(
        CloudMergePolicy.merge(local: local, cloud: null).highestCleared,
        3,
      );
    });

    test('cleared level is the max and newer tools win', () {
      final local = snap(
        level: 4,
        move: 2,
        updatedAt: DateTime.utc(2026, 10, 9),
      );
      final cloud = snap(
        level: 9,
        move: 7,
        undo: 1,
        removeAds: true,
        updatedAt: DateTime.utc(2026, 10, 1),
      );
      final merged = CloudMergePolicy.merge(local: local, cloud: cloud);
      expect(merged.highestCleared, 9);
      expect(merged.move, 2);
      expect(merged.undo, 0);
      expect(merged.removeAds, isTrue);
      expect(merged.updatedAt, local.updatedAt);
    });

    test('an older local clock restores cloud tools on reinstall', () {
      final local = snap(level: 0, updatedAt: LocalRevisionStore.epoch);
      final cloud = snap(
        level: 12,
        move: 4,
        undo: 1,
        shuffle: 2,
        barn: true,
        updatedAt: DateTime.utc(2026, 10, 8),
      );
      final merged = CloudMergePolicy.merge(local: local, cloud: cloud);
      expect(merged.highestCleared, 12);
      expect(merged.move, 4);
      expect(merged.undo, 1);
      expect(merged.shuffle, 2);
      expect(merged.barnBundle, isTrue);
    });

    test('equal timestamps keep the larger tool count', () {
      final when = DateTime.utc(2026, 10, 8, 12);
      final local = snap(level: 6, move: 3, undo: 0, updatedAt: when);
      final cloud = snap(
        level: 5,
        move: 1,
        undo: 4,
        harvest: true,
        updatedAt: when,
      );
      final merged = CloudMergePolicy.merge(local: local, cloud: cloud);
      expect(merged.highestCleared, 6);
      expect(merged.move, 3);
      expect(merged.undo, 4);
      expect(merged.harvestBundle, isTrue);
    });
  });

  group('sync through the port', () {
    test('a guest never calls the cloud', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final cloud = _CountingCloud(MemoryCloudStore());
      final sync = SyncCloudSave(
        auth: AuthRepositoryImpl(preferences),
        cloud: cloud,
        progress: ProgressRepositoryImpl(preferences),
        inventory: InventoryRepositoryImpl(preferences),
        entitlements: EntitlementRepositoryImpl(preferences),
        revision: LocalRevisionStore(preferences),
      );
      expect(await sync.call(), isNull);
      expect(cloud.pulls, 0);
      expect(cloud.pushes, 0);
    });

    test('binding restores progress, tools, and entitlements', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final auth = AuthRepositoryImpl(preferences);
      await auth.saveLink(
        await FakeAuthAdapter(clock: () => DateTime.utc(2026, 10, 9))
            .bind(AuthProviderKind.x),
      );
      final progress = ProgressRepositoryImpl(preferences);
      await progress.save(PlayerProgress.empty.copyWith(muted: true));
      final store = MemoryCloudStore();
      final cloudSnap = CloudSnapshot(
        accountId: 'stub-x',
        highestCleared: 12,
        move: 4,
        undo: 1,
        shuffle: 2,
        removeAds: true,
        barnBundle: true,
        harvestBundle: false,
        updatedAt: DateTime.utc(2026, 10, 8),
      );
      await store.write('stub-x', cloudSnap);
      final cloud = _CountingCloud(store);
      final sync = SyncCloudSave(
        auth: auth,
        cloud: cloud,
        progress: progress,
        inventory: InventoryRepositoryImpl(preferences),
        entitlements: EntitlementRepositoryImpl(preferences),
        revision: LocalRevisionStore(preferences),
      );
      final merged = await sync.call();
      expect(merged!.highestCleared, 12);
      expect(merged.move, 4);
      expect(merged.removeAds, isTrue);
      expect(merged.barnBundle, isTrue);
      expect(progress.load().highestCleared, 12);
      expect(progress.load().muted, isTrue);
      expect(InventoryRepositoryImpl(preferences).load().shuffle, 2);
      expect(EntitlementRepositoryImpl(preferences).load().removeAds, isTrue);
      expect(cloud.pulls, 1);
      expect(cloud.pushes, 1);
      expect(store.read('stub-x')!.highestCleared, 12);
    });
  });

  testWidgets('level 5 sheet is skippable and does not demand login', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BindOfferSheet(
            kind: BindPromptKind.cloudSave,
            onSkip: () {},
            onBind: (_) async => null,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('bind-sheet')), findsOneWidget);
    expect(find.text(BindCopy.cloudSaveBody), findsOneWidget);
    expect(find.byKey(const Key('bind-skip')), findsOneWidget);
    expect(find.byKey(const Key('bind-x')), findsOneWidget);
    expect(find.byKey(const Key('bind-facebook')), findsOneWidget);
    expect(find.textContaining('Please log in'), findsNothing);
  });

  testWidgets('level 8 sheet invites friends to gift tools', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BindOfferSheet(
            kind: BindPromptKind.inviteFriends,
            onSkip: () {},
            onBind: (_) async => null,
          ),
        ),
      ),
    );
    expect(find.text(BindCopy.inviteBody), findsOneWidget);
    expect(find.textContaining('Please log in'), findsNothing);
  });

  testWidgets('settings shows guest status, friends, and restore', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [prefsProvider.overrideWithValue(preferences)],
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pump();
    expect(find.text('Playing as a guest'), findsOneWidget);
    expect(find.byKey(const Key('open-friends')), findsOneWidget);
    expect(find.byKey(const Key('restore-purchases')), findsOneWidget);
    expect(find.text('Restore Purchases'), findsOneWidget);
    expect(find.textContaining('Please log in'), findsNothing);
    expect(find.textContaining('no cloud save'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _CountingCloud implements CloudSavePort {
  _CountingCloud(this.store);

  final CloudStore store;
  var pulls = 0;
  var pushes = 0;

  @override
  Future<CloudSnapshot?> pull(String accountId) async {
    pulls += 1;
    return store.read(accountId);
  }

  @override
  Future<void> push(CloudSnapshot snapshot) async {
    pushes += 1;
    await store.write(snapshot.accountId, snapshot);
  }
}

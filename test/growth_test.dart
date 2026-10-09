import 'dart:convert';

import 'package:farm_match/app/farm_match_app.dart';
import 'package:farm_match/app/providers.dart';
import 'package:farm_match/features/config/domain/game_config.dart';
import 'package:farm_match/features/deeplink/application/open_deep_link.dart';
import 'package:farm_match/features/deeplink/data/deferred_link_store.dart';
import 'package:farm_match/features/deeplink/domain/deep_link.dart';
import 'package:farm_match/features/deeplink/domain/deep_link_parser.dart';
import 'package:farm_match/features/entitlements/domain/entitlements.dart';
import 'package:farm_match/features/entitlements/domain/level_gate.dart';
import 'package:farm_match/features/identity/data/identity_repository_impl.dart';
import 'package:farm_match/features/inventory/data/inventory_repository_impl.dart';
import 'package:farm_match/features/invite/application/capture_invite.dart';
import 'package:farm_match/features/invite/application/claim_inviter_rewards.dart';
import 'package:farm_match/features/invite/application/settle_invite.dart';
import 'package:farm_match/features/invite/data/invite_directory_store.dart';
import 'package:farm_match/features/invite/data/invite_local_store.dart';
import 'package:farm_match/features/invite/domain/invite_code.dart';
import 'package:farm_match/features/invite/domain/invite_reward_policy.dart';
import 'package:farm_match/features/rate_prompt/data/review_ledger_store.dart';
import 'package:farm_match/features/rate_prompt/domain/review_prompt_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const day = '2026-10-09';
  final now = DateTime.utc(2026, 10, 9, 15);

  group('invite rewards', () {
    test('a new player qualifies with no progress even if the account is old',
        () {
      expect(
        InviteRewardPolicy.qualifiesAsNew(
          highestClearedBefore: 0,
          accountCreatedAt: DateTime.utc(2026, 10, 1),
          now: now,
        ),
        isTrue,
      );
      expect(
        InviteRewardPolicy.qualifiesAsNew(
          highestClearedBefore: 1,
          accountCreatedAt: now.subtract(const Duration(hours: 1)),
          now: now,
        ),
        isFalse,
      );
    });

    test('unbound share has no code and pays nobody', () async {
      final harness = await _InviteHarness.open();
      final issued = await harness.directory.issue(
        accountId: 'guest',
        displayName: 'Guest',
        bound: false,
      );
      expect(issued.link, 'farmmatch://');
      expect(issued.rewards, isFalse);
      expect(DeepLinkParser.parse(issued.link), isNull);
      final plan = InviteRewardPolicy.plan(
        clearedLevel: 1,
        highestClearedBefore: 0,
        accountCreatedAt: now,
        now: now,
        alreadyDevice: false,
        alreadyAccount: false,
        inviterBound: false,
        codeKnown: true,
        inviterToday: 0,
        inviterLifetime: 0,
      );
      expect(plan.deny, InviteDeny.inviterUnbound);
      expect(plan.payInvitee, isFalse);
      expect(plan.payInviter, isFalse);
    });

    test('level 1 pays both once, then the same device and account are spent',
        () async {
      final harness = await _InviteHarness.open();
      final code = await harness.issueSunny();
      final device = harness.local.load().deviceId;
      expect(await harness.capture.call(code), isTrue);

      final first = await harness.settle.call(
        clearedLevel: 1,
        highestClearedBefore: 0,
        now: now,
      );
      expect(first.plan.payInvitee, isTrue);
      expect(first.plan.payInviter, isTrue);
      expect(first.message, 'You and Sunny got boosts!');
      expect(harness.inventory.load().move, 2);
      expect(harness.inventory.load().undo, 2);
      expect(harness.inventory.load().shuffle, 2);
      expect(harness.directory.counts('stub-x', day).today, 1);
      expect(harness.directory.pendingBundles('stub-x'), 1);

      final again = await harness.settle.call(
        clearedLevel: 1,
        highestClearedBefore: 0,
        now: now,
      );
      expect(again.plan.deny, InviteDeny.alreadyAttributed);
      expect(harness.inventory.load().move, 2);

      await harness.prefs.remove(InviteLocalStore.deviceKey);
      await harness.prefs.remove(InviteLocalStore.attributedKey);
      await harness.prefs.remove(InviteLocalStore.pendingKey);
      expect(await harness.capture.call(code), isFalse);

      await harness.prefs.setString(InviteLocalStore.deviceKey, device);
      await harness.prefs.setString(IdentityRepositoryImpl.idKey, 'other');
      await harness.prefs
          .setString(IdentityRepositoryImpl.nicknameKey, 'Other');
      await harness.prefs.setString(
        IdentityRepositoryImpl.createdKey,
        now.toIso8601String(),
      );
      expect(await harness.capture.call(code), isFalse);
    });

    test('someone already past level 1 is not a new invitee', () async {
      final harness = await _InviteHarness.open();
      final code = await harness.issueSunny();
      expect(await harness.capture.call(code), isTrue);
      final result = await harness.settle.call(
        clearedLevel: 1,
        highestClearedBefore: 1,
        now: now,
      );
      expect(result.plan.deny, InviteDeny.notNewUser);
      expect(harness.inventory.load().move, 0);
      expect(harness.local.load().attributed, isFalse);
    });

    test('an inviter at the daily cap still attributes and pays the invitee',
        () async {
      final harness = await _InviteHarness.open();
      final code = await harness.issueSunny();
      for (var i = 0; i < InviteRewardPolicy.dailyMax; i++) {
        await harness.directory.markAttributed(
          deviceId: 'dev-$i',
          accountId: 'acct-$i',
          inviterAccountId: 'stub-x',
          dayKey: day,
          payInviter: true,
        );
      }
      expect(await harness.capture.call(code), isTrue);
      final result = await harness.settle.call(
        clearedLevel: 1,
        highestClearedBefore: 0,
        now: now,
      );
      expect(result.plan.payInvitee, isTrue);
      expect(result.plan.payInviter, isFalse);
      expect(result.message, 'You got free boosts!');
      expect(harness.directory.counts('stub-x', day).today, 5);
      expect(harness.directory.counts('stub-x', day).lifetime, 5);
      expect(harness.directory.pendingBundles('stub-x'), 5);
      expect(harness.inventory.load().move, 2);
      expect(harness.local.load().attributed, isTrue);
    });

    test('lifetime cap stops inviter pay and still grants the invitee',
        () async {
      final harness = await _InviteHarness.open();
      final code = await harness.issueSunny();
      for (var i = 0; i < InviteRewardPolicy.lifetimeMax; i++) {
        await harness.directory.markAttributed(
          deviceId: 'life-$i',
          accountId: 'life-acct-$i',
          inviterAccountId: 'stub-x',
          dayKey: '2020-01-${(i % 28) + 1}',
          payInviter: true,
        );
      }
      expect(await harness.capture.call(code), isTrue);
      final result = await harness.settle.call(
        clearedLevel: 1,
        highestClearedBefore: 0,
        now: now,
      );
      expect(result.plan.payInviter, isFalse);
      expect(result.plan.payInvitee, isTrue);
      expect(harness.directory.counts('stub-x', day).lifetime, 50);
      expect(harness.directory.counts('stub-x', day).today, 0);
      expect(harness.inventory.load().shuffle, 2);
    });

    test('the inviter collects each pending bundle once', () async {
      final harness = await _InviteHarness.open();
      await harness.directory.issue(
        accountId: 'stub-x',
        displayName: 'Sunny',
        bound: true,
      );
      await harness.directory.markAttributed(
        deviceId: 'dev',
        accountId: 'acct',
        inviterAccountId: 'stub-x',
        dayKey: day,
        payInviter: true,
      );
      final claim = ClaimInviterRewards(
        directory: harness.directory,
        inventory: harness.inventory,
      );
      expect(await claim.call('stub-x'), 1);
      expect(harness.inventory.load().move, InviteRewardPolicy.rewardEach);
      expect(await claim.call('stub-x'), 0);
      expect(harness.inventory.load().undo, InviteRewardPolicy.rewardEach);
    });

    test('a player cannot attribute their own code', () async {
      final harness = await _InviteHarness.open();
      final user = harness.identity.loadOrCreate();
      await harness.directory.issue(
        accountId: user.id,
        displayName: user.nickname,
        bound: true,
      );
      expect(await harness.capture.call(inviteCodeFor(user.id)), isFalse);
      expect(harness.local.load().pendingCode, isNull);
    });
  });

  group('deep links', () {
    test('parses invite, gift, challenge, shop, https, and path-only', () {
      final invite = DeepLinkParser.parse('farmmatch://invite?code=FARM-1000');
      expect(invite?.kind.name, 'invite');
      expect(invite?.code, 'FARM-1000');

      final gift = DeepLinkParser.parse(
        'farmmatch://gift?from=Sunny&type=undo',
      );
      expect(gift?.kind.name, 'gift');
      expect(gift?.from, 'Sunny');
      expect(gift?.type, 'undo');

      final challenge = DeepLinkParser.parse('farmmatch://challenge?level=12');
      expect(challenge?.level, 12);

      final shop = DeepLinkParser.parse('farmmatch://shop?sku=barn_bundle');
      expect(shop?.sku, 'barn_bundle');

      final https = DeepLinkParser.parse(
        'https://farmmatch.app/invite?code=FARM-2222',
      );
      expect(https?.code, 'FARM-2222');

      final path = DeepLinkParser.parse('/challenge?level=4');
      expect(path?.level, 4);

      expect(DeepLinkParser.parse('farmmatch://'), isNull);
      expect(DeepLinkParser.parse('https://example.com/invite?code=1'), isNull);
      expect(DeepLinkParser.parse('not a link'), isNull);
      expect(DeepLinkParser.parse('/'), isNull);
    });

    test('routes a challenge only when that level is open', () {
      final gate = LevelGate(GameConfig.fallback());
      DeepLinkTarget go(String raw, Entitlements entitlements) {
        final intent = DeepLinkParser.parse(raw)!;
        return DeepLinkNavigator.resolve(
          intent: intent,
          canPlay: (level) => gate.check(level, entitlements).allowed,
        );
      }

      expect(
        go('farmmatch://challenge?level=12', Entitlements.none).location,
        '/play/12',
      );
      final locked = go('farmmatch://challenge?level=21', Entitlements.none);
      expect(locked.location, '/');
      expect(locked.notice, contains('shut'));
      expect(
        go('farmmatch://shop?sku=barn_bundle', Entitlements.none).location,
        '/store?focus=barn_bundle',
      );
      expect(
        go('farmmatch://gift?from=Sunny&type=undo', Entitlements.none).location,
        '/friends',
      );
    });

    test('deferred referrer is consumed once', () async {
      SharedPreferences.setMockInitialValues({
        DeferredLinkStore.referrerKey: 'farmmatch://invite?code=FARM-1000',
      });
      final prefs = await SharedPreferences.getInstance();
      final store = DeferredLinkStore(prefs);
      expect(await store.takeOnce(), 'farmmatch://invite?code=FARM-1000');
      await prefs.setString(
        DeferredLinkStore.referrerKey,
        'farmmatch://invite?code=FARM-9999',
      );
      expect(await store.takeOnce(), isNull);
    });

    test('cold start routes the saved referrer', () async {
      Future<GrowthLaunch?> open(String raw) async {
        SharedPreferences.setMockInitialValues({
          DeferredLinkStore.referrerKey: raw,
        });
        final prefs = await SharedPreferences.getInstance();
        final directory = InviteDirectoryStore(preferences: prefs);
        final local = InviteLocalStore(prefs);
        final identity = IdentityRepositoryImpl(prefs);
        return OpenDeepLink(
          deferred: DeferredLinkStore(prefs),
          capture: CaptureInvite(
            directory: directory,
            local: local,
            identity: identity,
          ),
          gate: LevelGate(GameConfig.fallback()),
          entitlements: () => Entitlements.none,
        ).call();
      }

      final openLevel = await open('farmmatch://challenge?level=12');
      expect(openLevel?.location, '/play/12');

      final shut = await open('farmmatch://challenge?level=36');
      expect(shut?.location, '/');
      expect(shut?.notice, contains('shut'));

      final shop = await open('farmmatch://shop?sku=harvest_bundle');
      expect(shop?.location, '/store?focus=harvest_bundle');

      expect(await open('hello farm'), isNull);
    });
  });

  group('review prompt', () {
    bool allow({
      required int streak,
      bool failed = false,
      bool firstL10 = false,
      bool firstL20 = false,
      DateTime? lastShownAt,
      DateTime? at,
      bool rated = false,
      bool blockedByAuthSheet = false,
    }) {
      return ReviewPromptGate.allow(
        failed: failed,
        streak: streak,
        firstClearL10: firstL10,
        firstClearL20: firstL20,
        lastShownAt: lastShownAt,
        now: at ?? DateTime.utc(2026, 6, 1, 12),
        rated: rated,
        blockedByAuthSheet: blockedByAuthSheet,
      );
    }

    test('streak, fail, milestones, cooldown, and auth sheets', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final ledger = ReviewLedgerStore(prefs);

      await ledger.noteClear(1);
      final two = await ledger.noteClear(2);
      expect(allow(streak: two.streak), isFalse);

      final three = await ledger.noteClear(3);
      expect(allow(streak: three.streak), isTrue);

      await ledger.noteFail();
      expect(ledger.load().streak, 0);
      expect(allow(streak: 3, failed: true), isFalse);

      final firstTen = await ledger.noteClear(10);
      expect(firstTen.firstL10, isTrue);
      expect(allow(streak: firstTen.streak, firstL10: true), isTrue);
      final secondTen = await ledger.noteClear(10);
      expect(secondTen.firstL10, isFalse);
      expect(allow(streak: 2, firstL10: secondTen.firstL10), isFalse);

      final firstTwenty = await ledger.noteClear(20);
      expect(firstTwenty.firstL20, isTrue);
      expect(allow(streak: 1, firstL20: true), isTrue);
      final secondTwenty = await ledger.noteClear(20);
      expect(secondTwenty.firstL20, isFalse);

      final shown = DateTime.utc(2026, 6, 1, 8);
      await ledger.markShown(shown);
      expect(
        allow(streak: 3, lastShownAt: shown, at: DateTime.utc(2026, 6, 1, 20)),
        isFalse,
      );
      expect(
        allow(
          streak: 3,
          lastShownAt: DateTime.utc(2026, 1, 1),
          at: DateTime.utc(2026, 3, 31),
        ),
        isFalse,
      );
      expect(
        allow(
          streak: 3,
          lastShownAt: DateTime.utc(2026, 1, 1),
          at: DateTime.utc(2026, 4, 1),
        ),
        isTrue,
      );

      await ledger.markRated();
      expect(allow(streak: 9, rated: true), isFalse);
      expect(ledger.load().rated, isTrue);
      expect(allow(streak: 9, blockedByAuthSheet: true), isFalse);
    });
  });

  testWidgets('invite cold start stays on home with the level 1 prompt', (
    tester,
  ) async {
    final code = inviteCodeFor('stub-x');
    SharedPreferences.setMockInitialValues({
      DeferredLinkStore.referrerKey: 'farmmatch://invite?code=$code',
      InviteDirectoryStore.bookKey: jsonEncode({
        'codes': {
          code: {
            'accountId': 'stub-x',
            'displayName': 'Sunny',
            'bound': true,
          },
        },
      }),
    });
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsProvider.overrideWithValue(preferences),
          initialConfigProvider.overrideWithValue(GameConfig.fallback()),
        ],
        child: const FarmMatchApp(),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byKey(const Key('invite-banner')), findsOneWidget);
    expect(find.byKey(const Key('home-play')), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });
}

class _InviteHarness {
  _InviteHarness({
    required this.prefs,
    required this.directory,
    required this.local,
    required this.identity,
    required this.inventory,
    required this.capture,
    required this.settle,
  });

  final SharedPreferences prefs;
  final InviteDirectoryStore directory;
  final InviteLocalStore local;
  final IdentityRepositoryImpl identity;
  final InventoryRepositoryImpl inventory;
  final CaptureInvite capture;
  final SettleInvite settle;

  static Future<_InviteHarness> open() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final directory = InviteDirectoryStore(preferences: prefs);
    final local = InviteLocalStore(prefs);
    final identity = IdentityRepositoryImpl(prefs);
    final inventory = InventoryRepositoryImpl(prefs);
    return _InviteHarness(
      prefs: prefs,
      directory: directory,
      local: local,
      identity: identity,
      inventory: inventory,
      capture: CaptureInvite(
        directory: directory,
        local: local,
        identity: identity,
      ),
      settle: SettleInvite(
        directory: directory,
        local: local,
        identity: identity,
        inventory: inventory,
        dayKey: (_) => '2026-10-09',
      ),
    );
  }

  Future<String> issueSunny() async {
    final issued = await directory.issue(
      accountId: 'stub-x',
      displayName: 'Sunny',
      bound: true,
    );
    return issued.code!;
  }
}

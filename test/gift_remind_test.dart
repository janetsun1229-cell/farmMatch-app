import 'package:farm_match/app/farm_match_app.dart';
import 'package:farm_match/app/providers.dart';
import 'package:farm_match/features/config/domain/game_config.dart';
import 'package:farm_match/features/game/domain/power.dart';
import 'package:farm_match/features/gift/application/send_daily_gift.dart';
import 'package:farm_match/features/gift/data/fake_gift_adapter.dart';
import 'package:farm_match/features/gift/domain/daily_gift_policy.dart';
import 'package:farm_match/features/gift/domain/friend_profile.dart';
import 'package:farm_match/features/gift_remind/application/open_gift_notice.dart';
import 'package:farm_match/features/gift_remind/application/receive_friend_gift.dart';
import 'package:farm_match/features/gift_remind/application/remind_daily_gift.dart';
import 'package:farm_match/features/gift_remind/data/fake_notification_adapter.dart';
import 'package:farm_match/features/gift_remind/data/gift_remind_store.dart';
import 'package:farm_match/features/gift_remind/domain/gift_remind_policy.dart';
import 'package:farm_match/features/gift_remind/presentation/remind_permission_sheet.dart';
import 'package:farm_match/features/settings/presentation/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const day = '2026-10-09';
  final before = DateTime(2026, 10, 9, 18, 59);
  final open = DateTime(2026, 10, 9, 19, 0);
  final mid = DateTime(2026, 10, 9, 19, 30);
  final late = DateTime(2026, 10, 9, 20, 59);
  final closed = DateTime(2026, 10, 9, 21, 0);

  bool due({
    required DateTime now,
    bool bound = true,
    int friendCount = 1,
    bool sentToday = false,
    int sendsLeft = 3,
    String? alreadyRemindedDay,
    int slotMinute = 0,
  }) {
    return GiftRemindPolicy.dailyDue(
      now: now,
      bound: bound,
      friendCount: friendCount,
      sentToday: sentToday,
      sendsLeft: sendsLeft,
      alreadyRemindedDay: alreadyRemindedDay,
      dayKey: day,
      slotMinute: slotMinute,
    );
  }

  group('evening window', () {
    test('fires once inside 19:00–21:00 when a send is still left', () {
      expect(due(now: before), isFalse);
      expect(due(now: open), isTrue);
      expect(due(now: late), isTrue);
      expect(due(now: closed), isFalse);
      expect(due(now: DateTime(2026, 10, 9, 19, 10), slotMinute: 30), isFalse);
      expect(due(now: mid, slotMinute: 30), isTrue);
    });

    test('skips a send already made, an empty pool, no friends, or a repeat',
        () {
      expect(due(now: mid, sentToday: true), isFalse);
      expect(due(now: mid, sendsLeft: 0), isFalse);
      expect(due(now: mid, friendCount: 0), isFalse);
      expect(due(now: mid, bound: false), isFalse);
      expect(due(now: mid, alreadyRemindedDay: day), isFalse);
      expect(
        GiftRemindPolicy.dailyDue(
          now: DateTime(2026, 10, 10, 19, 15),
          bound: true,
          friendCount: 1,
          sentToday: false,
          sendsLeft: 3,
          alreadyRemindedDay: day,
          dayKey: '2026-10-10',
          slotMinute: 0,
        ),
        isTrue,
      );
    });
  });

  group('receive push', () {
    final t0 = DateTime.utc(2026, 10, 9, 12);

    test('same friend waits an hour and another friend does not', () {
      expect(
        GiftRemindPolicy.receivePush(
          inForeground: false,
          notificationsEnabled: true,
          lastForFriend: null,
          now: t0,
        ),
        isTrue,
      );
      expect(
        GiftRemindPolicy.receivePush(
          inForeground: false,
          notificationsEnabled: true,
          lastForFriend: t0,
          now: t0.add(const Duration(minutes: 59)),
        ),
        isFalse,
      );
      expect(
        GiftRemindPolicy.receivePush(
          inForeground: false,
          notificationsEnabled: true,
          lastForFriend: t0,
          now: t0.add(const Duration(hours: 1)),
        ),
        isTrue,
      );
      expect(
        GiftRemindPolicy.receivePush(
          inForeground: true,
          notificationsEnabled: true,
          lastForFriend: null,
          now: t0,
        ),
        isFalse,
      );
      expect(
        GiftRemindPolicy.receivePush(
          inForeground: false,
          notificationsEnabled: false,
          lastForFriend: null,
          now: t0,
        ),
        isFalse,
      );
    });

    test('background delivery pushes, cools down, and can be returned',
        () async {
      final harness = await _RemindHarness.open(granted: true);
      final sunny = await harness.addFriend();
      final first = await harness.receive(
        friend: sunny,
        now: t0,
        dayKey: '2026-10-09',
        inForeground: false,
      );
      expect(first.notice?.body, 'Sunny sent you Undo! Tap to send one back.');
      expect(first.badge, isTrue);
      expect(first.askPermission, isFalse);
      final target = const OpenGiftNotice().call(first.notice!);
      expect(target.location, '/friends');
      expect(target.notice, contains('Sunny'));

      final cooled = await harness.receive(
        friend: sunny,
        now: t0.add(const Duration(minutes: 30)),
        dayKey: '2026-10-10',
        inForeground: false,
      );
      expect(cooled.notice, isNull);
      expect(harness.notifications.posted, hasLength(1));

      final later = await harness.receive(
        friend: sunny,
        now: t0.add(const Duration(hours: 1)),
        dayKey: '2026-10-11',
        inForeground: false,
      );
      expect(later.notice, isNotNull);

      final brook = await harness.addFriend();
      final other = await harness.receive(
        friend: brook,
        now: t0.add(const Duration(minutes: 5)),
        dayKey: '2026-10-09',
        inForeground: false,
      );
      expect(other.notice?.body, contains('Brook'));

      final sent = await SendDailyGift(harness.gifts).call(
        accountId: 'stub-x',
        friendId: sunny.id,
        tool: Power.undo,
        dayKey: '2026-10-09',
      );
      expect(sent.ok, isTrue);
    });

    test('a foreground or unpermitted gift keeps the dot and does not push',
        () async {
      final quiet = await _RemindHarness.open(granted: false);
      final friend = await quiet.addFriend();
      final result = await quiet.receive(
        friend: friend,
        now: t0,
        dayKey: day,
        inForeground: false,
      );
      expect(result.notice, isNull);
      expect(result.badge, isTrue);
      expect(result.askPermission, isTrue);
      expect(quiet.notifications.posted, isEmpty);
      expect(quiet.notifications.permissionRequests, 0);

      final front = await _RemindHarness.open(granted: true);
      final pal = await front.addFriend();
      final seen = await front.receive(
        friend: pal,
        now: t0,
        dayKey: day,
        inForeground: true,
      );
      expect(seen.notice, isNull);
      expect(seen.badge, isTrue);
    });
  });

  group('permission timing', () {
    RemindAsk ask({
      bool granted = false,
      bool askedAfterInvite = false,
      bool askedAfterGift = false,
      bool inviteFlowFinished = false,
      bool firstGiftArrived = false,
    }) {
      return GiftRemindPolicy.permissionAsk(
        granted: granted,
        askedAfterInvite: askedAfterInvite,
        askedAfterGift: askedAfterGift,
        inviteFlowFinished: inviteFlowFinished,
        firstGiftArrived: firstGiftArrived,
      );
    }

    test('launch asks for nothing', () {
      expect(ask(), RemindAsk.none);
    });

    test('level 8 invite asks once, then a first gift can ask if still needed',
        () {
      expect(ask(inviteFlowFinished: true), RemindAsk.afterInvite);
      expect(
        ask(inviteFlowFinished: true, askedAfterInvite: true),
        RemindAsk.none,
      );
      expect(
        ask(askedAfterInvite: true, firstGiftArrived: true),
        RemindAsk.afterFirstGift,
      );
      expect(
        ask(
            askedAfterInvite: true,
            askedAfterGift: true,
            firstGiftArrived: true),
        RemindAsk.none,
      );
      expect(ask(granted: true, inviteFlowFinished: true), RemindAsk.none);
    });
  });

  group('daily reminder use case', () {
    test(
        'posts one reminder in the window and a dot when notifications are off',
        () async {
      final harness = await _RemindHarness.open(granted: true);
      await harness.addFriend();
      final now = DateTime(2026, 10, 9, 19, 15);
      final first = await harness.daily(now);
      expect(first.notice?.body, GiftRemindPolicy.dailyBody);
      expect(first.notice?.link, 'farmmatch://gift');
      expect(const OpenGiftNotice().call(first.notice!).location, '/friends');
      final again = await harness.daily(now);
      expect(again.notice, isNull);
      expect(harness.notifications.posted, hasLength(1));

      final nextDay = await harness.daily(DateTime(2026, 10, 10, 19, 15));
      expect(nextDay.notice, isNotNull);

      final early = await _RemindHarness.open(granted: true);
      await early.addFriend();
      expect((await early.daily(DateTime(2026, 10, 9, 18, 59))).notice, isNull);

      final shut = await _RemindHarness.open(granted: false);
      await shut.addFriend();
      final dotOnly = await shut.daily(DateTime(2026, 10, 9, 19, 15));
      expect(dotOnly.notice, isNull);
      expect(dotOnly.badge, isTrue);
      expect(shut.notifications.posted, isEmpty);
      expect(shut.notifications.permissionRequests, 0);
    });

    test('does not remind after today\'s send or when the pool is empty',
        () async {
      final sent = await _RemindHarness.open(granted: true);
      final friend = await sent.addFriend();
      final dayKey = DailyGiftPolicy.dayKey(DateTime(2026, 10, 9, 19, 15));
      await sent.gifts.send(
        accountId: 'stub-x',
        friendId: friend.id,
        tool: Power.move,
        dayKey: dayKey,
      );
      expect((await sent.daily(DateTime(2026, 10, 9, 19, 15))).notice, isNull);

      final empty = await _RemindHarness.open(granted: true);
      for (var i = 0; i < 3; i++) {
        final pal = await empty.addFriend();
        await empty.gifts.send(
          accountId: 'stub-x',
          friendId: pal.id,
          tool: Power.shuffle,
          dayKey: dayKey,
        );
      }
      expect((await empty.daily(DateTime(2026, 10, 9, 19, 15))).badge, isFalse);
    });
  });

  testWidgets('cold start does not ask for notification permission',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
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
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byKey(const Key('remind-sheet')), findsNothing);
    expect(find.byKey(const Key('open-friends-home')), findsOneWidget);
    expect(find.byKey(const Key('gift-dot')), findsNothing);
    final context = tester.element(find.byType(FarmMatchApp));
    final port =
        ProviderScope.containerOf(context).read(notificationPortProvider);
    expect(port.permissionRequests, 0);
    expect(port.posted, isEmpty);
  });

  testWidgets('home and settings show a red dot for an unread gift',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      GiftRemindStore.unclaimedKey: 2,
    });
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [prefsProvider.overrideWithValue(preferences)],
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('open-friends')), findsOneWidget);
    expect(find.byKey(const Key('gift-dot')), findsOneWidget);
    expect(find.text('Friends & gifts'), findsOneWidget);
  });

  testWidgets('permission sheet is skippable', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RemindPermissionSheet(onAllow: () {}, onLater: () {}),
        ),
      ),
    );
    expect(find.text('Allow reminders?'), findsOneWidget);
    expect(find.byKey(const Key('remind-allow')), findsOneWidget);
    expect(find.byKey(const Key('remind-skip')), findsOneWidget);
    expect(find.textContaining('Please log in'), findsNothing);
  });
}

class _RemindHarness {
  _RemindHarness({
    required this.gifts,
    required this.store,
    required this.notifications,
  });

  final FakeGiftAdapter gifts;
  final GiftRemindStore store;
  final FakeNotificationAdapter notifications;

  static Future<_RemindHarness> open({required bool granted}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = GiftRemindStore(prefs);
    if (granted) await store.setGranted(true);
    return _RemindHarness(
      gifts: FakeGiftAdapter(preferences: prefs, seedGiftOnInvite: false),
      store: store,
      notifications: FakeNotificationAdapter(),
    );
  }

  Future<FriendProfile> addFriend() async {
    final result = await gifts.invite('stub-x');
    return result.friend;
  }

  Future<ReceiveGiftResult> receive({
    required FriendProfile friend,
    required DateTime now,
    required String dayKey,
    required bool inForeground,
  }) {
    return ReceiveFriendGift(
      gifts: gifts,
      store: store,
      notifications: notifications,
    ).call(
      accountId: 'stub-x',
      friend: friend,
      tool: Power.undo,
      dayKey: dayKey,
      now: now,
      inForeground: inForeground,
    );
  }

  Future<DailyRemindResult> daily(DateTime now) {
    return RemindDailyGift(
      gifts: gifts,
      store: store,
      notifications: notifications,
    ).call(
      accountId: 'stub-x',
      bound: true,
      now: now,
      slotMinute: 0,
    );
  }
}

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../game/domain/power.dart';
import '../domain/daily_gift_policy.dart';
import '../domain/friend_profile.dart';
import '../domain/incoming_gift.dart';
import '../domain/ports/gift_port.dart';

class _Book {
  final Map<String, List<FriendProfile>> friends = {};
  final Map<String, OutboundDay> outbound = {};
  final Map<String, List<IncomingGift>> inbox = {};
  final Map<String, List<String>> receivedKeys = {};
}

/// In-process friends graph. Invite adds a neighbor and, by default, one
/// incoming gift so the receive path is playable without a second device.
class FakeGiftAdapter implements GiftPort {
  FakeGiftAdapter({
    SharedPreferences? preferences,
    this.seedGiftOnInvite = true,
  }) : _preferences = preferences;

  final SharedPreferences? _preferences;
  final bool seedGiftOnInvite;
  final _Book _book = _Book();
  var _loaded = false;

  static const _prefsKey = 'gift_book_v1';
  static const _names = ['Sunny', 'Brook', 'Maple', 'Clover', 'Daisy', 'Heath'];

  void _ensure() {
    if (_loaded) return;
    _loaded = true;
    final raw = _preferences?.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return;
    final friends = decoded['friends'];
    if (friends is Map) {
      for (final entry in friends.entries) {
        final rows = entry.value;
        if (rows is! List) continue;
        _book.friends['${entry.key}'] = [
          for (final row in rows)
            if (row is Map)
              FriendProfile(id: '${row['id']}', name: '${row['name']}'),
        ];
      }
    }
    final outbound = decoded['outbound'];
    if (outbound is Map) {
      for (final entry in outbound.entries) {
        final row = entry.value;
        if (row is! Map) continue;
        final toolName = row['tool'] as String?;
        _book.outbound['${entry.key}'] = OutboundDay(
          dayKey: '${row['dayKey']}',
          tool: _power(toolName),
          sentFriendIds: [
            for (final id in (row['sent'] as List? ?? const [])) '$id',
          ],
        );
      }
    }
    final inbox = decoded['inbox'];
    if (inbox is Map) {
      for (final entry in inbox.entries) {
        final rows = entry.value;
        if (rows is! List) continue;
        _book.inbox['${entry.key}'] = [
          for (final row in rows)
            if (row is Map)
              IncomingGift(
                id: '${row['id']}',
                fromFriendId: '${row['fromFriendId']}',
                fromName: '${row['fromName']}',
                tool: _power('${row['tool']}') ?? Power.move,
                dayKey: '${row['dayKey']}',
                claimed: row['claimed'] == true,
              ),
        ];
      }
    }
    final received = decoded['received'];
    if (received is Map) {
      for (final entry in received.entries) {
        final rows = entry.value;
        if (rows is! List) continue;
        _book.receivedKeys['${entry.key}'] = [for (final id in rows) '$id'];
      }
    }
  }

  Future<void> _save() async {
    final prefs = _preferences;
    if (prefs == null) return;
    final payload = {
      'friends': {
        for (final entry in _book.friends.entries)
          entry.key: [
            for (final friend in entry.value)
              {'id': friend.id, 'name': friend.name},
          ],
      },
      'outbound': {
        for (final entry in _book.outbound.entries)
          entry.key: {
            'dayKey': entry.value.dayKey,
            'tool': entry.value.tool?.name,
            'sent': entry.value.sentFriendIds,
          },
      },
      'inbox': {
        for (final entry in _book.inbox.entries)
          entry.key: [
            for (final gift in entry.value)
              {
                'id': gift.id,
                'fromFriendId': gift.fromFriendId,
                'fromName': gift.fromName,
                'tool': gift.tool.name,
                'dayKey': gift.dayKey,
                'claimed': gift.claimed,
              },
          ],
      },
      'received': _book.receivedKeys,
    };
    await prefs.setString(_prefsKey, jsonEncode(payload));
  }

  List<FriendProfile> _friendsOf(String accountId) =>
      _book.friends.putIfAbsent(accountId, () => []);

  @override
  Future<List<FriendProfile>> listFriends(String accountId) async {
    _ensure();
    return List<FriendProfile>.unmodifiable(_friendsOf(accountId));
  }

  @override
  Future<InviteResult> invite(String accountId) async {
    _ensure();
    final friends = _friendsOf(accountId);
    final index = friends.length;
    final friend = FriendProfile(
      id: 'pal-$index',
      name: _names[index % _names.length],
    );
    friends.add(friend);
    final code = 'FARM-${(1000 + index).toString()}';
    if (seedGiftOnInvite) {
      offerIncoming(
        accountId: accountId,
        friend: friend,
        tool: Power.undo,
        dayKey: DailyGiftPolicy.dayKey(DateTime.now().toUtc()),
      );
    }
    await _save();
    return InviteResult(friend: friend, code: code);
  }

  @override
  Future<OutboundDay> outbound(String accountId, String dayKey) async {
    _ensure();
    return DailyGiftPolicy.forDay(_book.outbound[accountId], dayKey);
  }

  @override
  Future<List<IncomingGift>> inbox(String accountId) async {
    _ensure();
    return List<IncomingGift>.unmodifiable(
      _book.inbox[accountId] ?? const <IncomingGift>[],
    );
  }

  @override
  Future<SendGiftResult> send({
    required String accountId,
    required String friendId,
    required Power tool,
    required String dayKey,
  }) async {
    _ensure();
    final friends = _friendsOf(accountId);
    final isFriend = friends.any((friend) => friend.id == friendId);
    final receipt = '$friendId|$dayKey';
    final already = _book.receivedKeys[accountId]?.contains(receipt) ?? false;
    final stored = _book.outbound[accountId];
    final plan = DailyGiftPolicy.planSend(
      stored: stored,
      dayKey: dayKey,
      friendId: friendId,
      tool: tool,
      isFriend: isFriend,
      friendAlreadyReceivedToday: already,
    );
    if (!plan.ok || plan.next == null) {
      final today = DailyGiftPolicy.forDay(stored, dayKey);
      return SendGiftResult(
        deny: plan.deny,
        ledger: today,
        lockedTool: today.tool,
      );
    }
    _book.outbound[accountId] = plan.next!;
    _book.receivedKeys.putIfAbsent(accountId, () => []).add(receipt);
    await _save();
    return SendGiftResult(
      deny: GiftDeny.ok,
      ledger: plan.next,
      lockedTool: tool,
    );
  }

  @override
  Future<IncomingGift?> claim({
    required String accountId,
    required String giftId,
  }) async {
    _ensure();
    final rows = _book.inbox[accountId];
    if (rows == null) return null;
    final index = rows.indexWhere((gift) => gift.id == giftId);
    if (index < 0 || rows[index].claimed) return null;
    final claimed = rows[index].copyWith(claimed: true);
    rows[index] = claimed;
    await _save();
    return claimed;
  }

  /// Stub delivery from a friend onto this account. Returns null when that
  /// friend already sent a gift on [dayKey].
  IncomingGift? offerIncoming({
    required String accountId,
    required FriendProfile friend,
    required Power tool,
    required String dayKey,
  }) {
    _ensure();
    final rows = _book.inbox.putIfAbsent(accountId, () => []);
    final already = rows.any(
      (gift) => gift.fromFriendId == friend.id && gift.dayKey == dayKey,
    );
    if (!DailyGiftPolicy.acceptIncoming(alreadyFromThisFriendToday: already)) {
      return null;
    }
    final gift = IncomingGift(
      id: 'in-${friend.id}-$dayKey-${rows.length}',
      fromFriendId: friend.id,
      fromName: friend.name,
      tool: tool,
      dayKey: dayKey,
      claimed: false,
    );
    rows.add(gift);
    return gift;
  }

  Power? _power(String? name) {
    if (name == null || name == 'null') return null;
    for (final power in Power.values) {
      if (power.name == name) return power;
    }
    return null;
  }
}

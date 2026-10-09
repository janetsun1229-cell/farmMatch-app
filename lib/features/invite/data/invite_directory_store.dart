import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/invite_code.dart';
import '../domain/ports/invite_directory.dart';

class _InviterRow {
  _InviterRow({this.lifetime = 0, Map<String, int>? days, this.pending = 0})
      : days = days ?? <String, int>{};

  int lifetime;
  final Map<String, int> days;
  int pending;
}

/// Shared stub book. The same prefs record is what a second open on this
/// install reads, so the inviter can collect a pending bundle.
class InviteDirectoryStore implements InviteDirectory {
  InviteDirectoryStore({SharedPreferences? preferences})
      : _preferences = preferences;

  final SharedPreferences? _preferences;
  final Map<String, InviteCodeRecord> _codes = {};
  final Set<String> _devices = {};
  final Set<String> _accounts = {};
  final Map<String, _InviterRow> _rows = {};
  var _loaded = false;

  static const bookKey = 'invite_book_v1';

  void _ensure() {
    if (_loaded) return;
    _loaded = true;
    final raw = _preferences?.getString(bookKey);
    if (raw == null || raw.isEmpty) return;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return;
    final codes = decoded['codes'];
    if (codes is Map) {
      for (final entry in codes.entries) {
        final row = entry.value;
        if (row is! Map) continue;
        _codes['${entry.key}'] = InviteCodeRecord(
          code: '${entry.key}',
          accountId: '${row['accountId']}',
          displayName: '${row['displayName']}',
          bound: row['bound'] == true,
        );
      }
    }
    final devices = decoded['devices'];
    if (devices is List) {
      _devices.addAll(devices.map((id) => '$id'));
    }
    final accounts = decoded['accounts'];
    if (accounts is List) {
      _accounts.addAll(accounts.map((id) => '$id'));
    }
    final rows = decoded['rows'];
    if (rows is Map) {
      for (final entry in rows.entries) {
        final row = entry.value;
        if (row is! Map) continue;
        final daysRaw = row['days'];
        final days = <String, int>{};
        if (daysRaw is Map) {
          for (final day in daysRaw.entries) {
            days['${day.key}'] = (day.value as num).toInt();
          }
        }
        _rows['${entry.key}'] = _InviterRow(
          lifetime: (row['lifetime'] as num?)?.toInt() ?? 0,
          days: days,
          pending: (row['pending'] as num?)?.toInt() ?? 0,
        );
      }
    }
  }

  Future<void> _save() async {
    final prefs = _preferences;
    if (prefs == null) return;
    final payload = {
      'codes': {
        for (final record in _codes.values)
          record.code: {
            'accountId': record.accountId,
            'displayName': record.displayName,
            'bound': record.bound,
          },
      },
      'devices': _devices.toList(),
      'accounts': _accounts.toList(),
      'rows': {
        for (final entry in _rows.entries)
          entry.key: {
            'lifetime': entry.value.lifetime,
            'pending': entry.value.pending,
            'days': entry.value.days,
          },
      },
    };
    await prefs.setString(bookKey, jsonEncode(payload));
  }

  _InviterRow _row(String accountId) =>
      _rows.putIfAbsent(accountId, _InviterRow.new);

  @override
  Future<IssuedInvite> issue({
    required String accountId,
    required String displayName,
    required bool bound,
  }) async {
    _ensure();
    if (!bound) {
      return const IssuedInvite(link: 'farmmatch://', rewards: false);
    }
    final code = inviteCodeFor(accountId);
    _codes[code] = InviteCodeRecord(
      code: code,
      accountId: accountId,
      displayName: displayName,
      bound: true,
    );
    await _save();
    return IssuedInvite(link: inviteLinkFor(code), rewards: true, code: code);
  }

  @override
  InviteCodeRecord? lookup(String code) {
    _ensure();
    return _codes[code];
  }

  @override
  bool deviceUsed(String deviceId) {
    _ensure();
    return _devices.contains(deviceId);
  }

  @override
  bool accountUsed(String accountId) {
    _ensure();
    return _accounts.contains(accountId);
  }

  @override
  InviterCount counts(String accountId, String dayKey) {
    _ensure();
    final row = _rows[accountId];
    if (row == null) return const InviterCount(today: 0, lifetime: 0);
    return InviterCount(today: row.days[dayKey] ?? 0, lifetime: row.lifetime);
  }

  @override
  int pendingBundles(String accountId) {
    _ensure();
    return _rows[accountId]?.pending ?? 0;
  }

  @override
  Future<void> markAttributed({
    required String deviceId,
    required String accountId,
    required String inviterAccountId,
    required String dayKey,
    required bool payInviter,
  }) async {
    _ensure();
    _devices.add(deviceId);
    _accounts.add(accountId);
    if (payInviter) {
      final row = _row(inviterAccountId);
      row.lifetime += 1;
      row.days[dayKey] = (row.days[dayKey] ?? 0) + 1;
      row.pending += 1;
    }
    await _save();
  }

  @override
  Future<int> takePendingBundles(String accountId) async {
    _ensure();
    final row = _rows[accountId];
    if (row == null || row.pending == 0) return 0;
    final taken = row.pending;
    row.pending = 0;
    await _save();
    return taken;
  }
}

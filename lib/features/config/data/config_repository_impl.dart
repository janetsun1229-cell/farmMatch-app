import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/game_config.dart';
import '../domain/repositories/config_repository.dart';
import 'remote_config_api.dart';

class ConfigRepositoryImpl implements ConfigRepository {
  ConfigRepositoryImpl({
    required SharedPreferences preferences,
    required GameConfig initial,
    RemoteConfigApi? remote,
  })  : _preferences = preferences,
        _current = initial,
        _remote = remote ??
            RemoteConfigApi(
                baseUrl: initial.api.baseUrl,
                configPath: initial.api.configPath);

  static const cacheKey = 'config_cache';

  final SharedPreferences _preferences;
  GameConfig _current;
  final RemoteConfigApi _remote;

  @override
  GameConfig get current => _current;

  static Future<GameConfig> loadInitial(SharedPreferences preferences) async {
    GameConfig bundled = GameConfig.fallback();
    try {
      final raw =
          await rootBundle.loadString('assets/config/default_config.json');
      bundled = parseConfig(raw);
    } catch (_) {
      bundled = GameConfig.fallback();
    }
    final cached = preferences.getString(cacheKey);
    if (cached != null) {
      try {
        return parseConfig(cached);
      } catch (_) {
        return bundled;
      }
    }
    return bundled;
  }

  @override
  Future<GameConfig> refresh(
      {required String appVersion, required String platform}) async {
    final raw =
        await _remote.fetchRaw(appVersion: appVersion, platform: platform);
    if (raw == null) return _current;
    try {
      final parsed = parseConfig(raw);
      await _preferences.setString(cacheKey, jsonEncode(jsonDecode(raw)));
      _current = parsed;
      return parsed;
    } catch (_) {
      return _current;
    }
  }
}

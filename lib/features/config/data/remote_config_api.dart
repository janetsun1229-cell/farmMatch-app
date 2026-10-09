import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/game_config.dart';

class RemoteConfigApi {
  RemoteConfigApi(
      {http.Client? client, this.baseUrl = '', this.configPath = '/v1/config'})
      : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;
  final String configPath;

  Future<String?> fetchRaw(
      {required String appVersion, required String platform}) async {
    if (baseUrl.isEmpty) return null;
    try {
      final root = Uri.parse(baseUrl);
      final uri = root.replace(
        path: _join(root.path, configPath),
        queryParameters: {'appVersion': appVersion, 'platform': platform},
      );
      final response =
          await _client.get(uri).timeout(const Duration(seconds: 6));
      if (response.statusCode != 200 || response.body.isEmpty) return null;
      jsonDecode(response.body);
      return response.body;
    } catch (_) {
      return null;
    }
  }

  String _join(String rootPath, String configPath) {
    if (configPath.startsWith('/')) return configPath;
    final prefix = rootPath.endsWith('/')
        ? rootPath.substring(0, rootPath.length - 1)
        : rootPath;
    return '$prefix/$configPath';
  }
}

GameConfig parseConfig(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Config payload must be an object');
  }
  return GameConfig.fromJson(decoded);
}

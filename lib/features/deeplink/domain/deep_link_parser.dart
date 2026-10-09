import 'deep_link.dart';

/// Parses `farmmatch://`, `https://farmmatch.app`, and path-only cold-start
/// routes (`/invite?code=`).
class DeepLinkParser {
  const DeepLinkParser._();

  static const scheme = 'farmmatch';
  static const webHost = 'farmmatch.app';

  static const kinds = {'invite', 'gift', 'challenge', 'shop'};

  static bool looksLike(String raw) {
    return parse(raw) != null;
  }

  static DeepLinkIntent? parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed == '/') return null;
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;
    final name = _kind(uri);
    if (name == null) return null;
    final kind = DeepLinkKind.values.firstWhere((value) => value.name == name);
    return DeepLinkIntent(
      kind: kind,
      code: _query(uri, 'code'),
      from: _query(uri, 'from'),
      type: _query(uri, 'type'),
      level: int.tryParse(_query(uri, 'level') ?? ''),
      sku: _query(uri, 'sku'),
    );
  }

  static String? _kind(Uri uri) {
    if (uri.scheme == scheme) {
      if (kinds.contains(uri.host)) return uri.host;
      if (uri.pathSegments.isNotEmpty &&
          kinds.contains(uri.pathSegments.first)) {
        return uri.pathSegments.first;
      }
      return null;
    }
    final host = uri.host.toLowerCase();
    if (host == webHost || host == 'www.$webHost') {
      if (uri.pathSegments.isNotEmpty &&
          kinds.contains(uri.pathSegments.first)) {
        return uri.pathSegments.first;
      }
      return null;
    }
    if (uri.scheme.isEmpty &&
        uri.pathSegments.isNotEmpty &&
        kinds.contains(uri.pathSegments.first)) {
      return uri.pathSegments.first;
    }
    return null;
  }

  static String? _query(Uri uri, String key) {
    final value = uri.queryParameters[key];
    if (value == null || value.isEmpty) return null;
    return value;
  }
}

class DeepLinkNavigator {
  const DeepLinkNavigator._();

  static DeepLinkTarget resolve({
    required DeepLinkIntent intent,
    required bool Function(int level) canPlay,
  }) {
    switch (intent.kind) {
      case DeepLinkKind.invite:
        return const DeepLinkTarget(
          location: '/',
          notice: 'Invite saved. Clear level 1 — you both get free boosts.',
        );
      case DeepLinkKind.gift:
        final from = intent.from;
        final type = intent.type;
        final notice = from == null
            ? null
            : type == null
                ? '$from sent you a tool.'
                : '$from sent you $type.';
        return DeepLinkTarget(location: '/friends', notice: notice);
      case DeepLinkKind.challenge:
        final level = intent.level;
        if (level == null || !canPlay(level)) {
          return const DeepLinkTarget(
            location: '/',
            notice: 'That part of the farm is still shut.',
          );
        }
        return DeepLinkTarget(location: '/play/$level');
      case DeepLinkKind.shop:
        final sku = intent.sku;
        final query = sku == null ? '' : '?focus=$sku';
        return DeepLinkTarget(location: '/store$query');
    }
  }
}

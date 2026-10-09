enum DeepLinkKind { invite, gift, challenge, shop }

class DeepLinkIntent {
  const DeepLinkIntent({
    required this.kind,
    this.code,
    this.from,
    this.type,
    this.level,
    this.sku,
  });

  final DeepLinkKind kind;
  final String? code;
  final String? from;
  final String? type;
  final int? level;
  final String? sku;
}

class DeepLinkTarget {
  const DeepLinkTarget({required this.location, this.notice});

  final String location;
  final String? notice;
}

class GrowthLaunch {
  const GrowthLaunch({
    required this.intent,
    required this.location,
    this.notice,
  });

  final DeepLinkIntent intent;
  final String location;
  final String? notice;
}

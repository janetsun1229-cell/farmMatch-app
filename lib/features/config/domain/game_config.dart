class PowerConfig {
  const PowerConfig({
    required this.moveUnlockLevel,
    required this.undoUnlockLevel,
    required this.shuffleUnlockLevel,
    required this.unlockGrantUses,
    required this.perLevelUses,
  });

  final int moveUnlockLevel;
  final int undoUnlockLevel;
  final int shuffleUnlockLevel;
  final int unlockGrantUses;
  final int perLevelUses;

  static const fallback = PowerConfig(
    moveUnlockLevel: 5,
    undoUnlockLevel: 8,
    shuffleUnlockLevel: 12,
    unlockGrantUses: 3,
    perLevelUses: 3,
  );
}

class TimingConfig {
  const TimingConfig({
    required this.flySeconds,
    required this.trayBounceScale,
    required this.matchPopScale,
    required this.sparkSeconds,
    required this.sparkCountMin,
    required this.sparkCountMax,
    required this.confettiSeconds,
  });

  final double flySeconds;
  final double trayBounceScale;
  final double matchPopScale;
  final double sparkSeconds;
  final int sparkCountMin;
  final int sparkCountMax;
  final double confettiSeconds;

  static const fallback = TimingConfig(
    flySeconds: 0.22,
    trayBounceScale: 1.08,
    matchPopScale: 1.4,
    sparkSeconds: 0.35,
    sparkCountMin: 6,
    sparkCountMax: 8,
    confettiSeconds: 1.5,
  );
}

class DifficultyBand {
  const DifficultyBand({
    required this.from,
    required this.to,
    required this.types,
    required this.cards,
    required this.piles,
    required this.pileSize,
  });

  final int from;
  final int to;
  final int types;
  final int cards;
  final int piles;
  final int pileSize;

  bool contains(int level) => level >= from && level <= to;
}

class SoftHelpConfig {
  const SoftHelpConfig({
    required this.trayWarnSlotsLeft,
    required this.deadBoardTrayMin,
  });

  final int trayWarnSlotsLeft;
  final int deadBoardTrayMin;

  static const fallback =
      SoftHelpConfig(trayWarnSlotsLeft: 1, deadBoardTrayMin: 5);
}

class IapSku {
  const IapSku({
    required this.id,
    required this.title,
    required this.priceUsd,
    required this.consumable,
    this.each = 0,
    this.levelFrom,
    this.levelTo,
  });

  final String id;
  final String title;
  final double priceUsd;
  final bool consumable;
  final int each;
  final int? levelFrom;
  final int? levelTo;

  bool get isTools => each > 0;

  bool get isRestorable => !consumable;

  String get priceLabel => '\$${priceUsd.toStringAsFixed(2)}';
}

class ApiConfig {
  const ApiConfig({
    required this.baseUrl,
    required this.configPath,
    required this.verifyPath,
  });

  final String baseUrl;
  final String configPath;
  final String verifyPath;

  static const fallback = ApiConfig(
    baseUrl: '',
    configPath: '/v1/config',
    verifyPath: '/v1/iap/verify',
  );
}

class GameConfig {
  const GameConfig({
    required this.freeLevelCap,
    required this.totalLevels,
    required this.traySlots,
    required this.holdMax,
    required this.moveTakeMax,
    required this.cardScaleVsL1,
    required this.boardMaxColumns,
    required this.rotationDeg,
    required this.copiesPerType,
    required this.pileInternalShiftW,
    required this.neighborGapMaxW,
    required this.pileMinDistinctTypes,
    required this.adsEnabled,
    required this.powerChargeMode,
    required this.powers,
    required this.timing,
    required this.veilByDepth,
    required this.bands,
    required this.softHelp,
    required this.products,
    required this.api,
  });

  final int freeLevelCap;
  final int totalLevels;
  final int traySlots;
  final int holdMax;
  final int moveTakeMax;
  final double cardScaleVsL1;
  final int boardMaxColumns;
  final double rotationDeg;
  final int copiesPerType;
  final double pileInternalShiftW;
  final double neighborGapMaxW;
  final int pileMinDistinctTypes;
  final bool adsEnabled;
  final String powerChargeMode;
  final PowerConfig powers;
  final TimingConfig timing;
  final Map<String, double> veilByDepth;
  final List<DifficultyBand> bands;
  final SoftHelpConfig softHelp;
  final List<IapSku> products;
  final ApiConfig api;

  DifficultyBand bandFor(int level) {
    for (final band in bands) {
      if (band.contains(level)) return band;
    }
    return bands.last;
  }

  IapSku? sku(String id) {
    for (final product in products) {
      if (product.id == id) return product;
    }
    return null;
  }

  IapSku? bundleForLevel(int level) {
    if (level <= freeLevelCap) return null;
    for (final product in products) {
      final from = product.levelFrom;
      final to = product.levelTo;
      if (from != null && to != null && level >= from && level <= to) {
        return product;
      }
    }
    return null;
  }

  double veilOpacity(int depth) {
    if (depth <= 0) return 0;
    if (depth == 1) return veilByDepth['1'] ?? 0.25;
    if (depth == 2) return veilByDepth['2'] ?? 0.35;
    if (depth == 3) return veilByDepth['3'] ?? 0.45;
    return veilByDepth['4_plus'] ?? 0.55;
  }

  static GameConfig fallback() => GameConfig.fromJson(const {});

  factory GameConfig.fromJson(Map<String, dynamic> json) {
    final base = _defaults;
    final powers = json['powers'];
    final timing = json['timing'];
    final soft = json['soft_help'];
    final api = json['api'];
    final veil = json['veil_opacity_by_depth'];
    final bands = json['difficulty_bands'];
    final iap = json['iap'];
    return GameConfig(
      freeLevelCap: _asInt(json['free_level_cap'], base.freeLevelCap),
      totalLevels: _asInt(json['total_levels'], base.totalLevels),
      traySlots: _asInt(json['tray_slots'], base.traySlots),
      holdMax: _asInt(json['hold_max'], base.holdMax),
      moveTakeMax: _asInt(json['move_take_max'], base.moveTakeMax),
      cardScaleVsL1: _asDouble(json['card_scale_vs_l1'], base.cardScaleVsL1),
      boardMaxColumns: _asInt(json['board_max_columns'], base.boardMaxColumns),
      rotationDeg: _asDouble(json['rotation_deg'], base.rotationDeg),
      copiesPerType: _asInt(json['copies_per_type'], base.copiesPerType),
      pileInternalShiftW:
          _asDouble(json['pile_internal_shift_w'], base.pileInternalShiftW),
      neighborGapMaxW:
          _asDouble(json['neighbor_gap_max_w'], base.neighborGapMaxW),
      pileMinDistinctTypes:
          _asInt(json['pile_min_distinct_types'], base.pileMinDistinctTypes),
      adsEnabled: json['ads_enabled'] is bool
          ? json['ads_enabled'] as bool
          : base.adsEnabled,
      powerChargeMode:
          json['power_charge_mode'] as String? ?? base.powerChargeMode,
      powers: powers is Map<String, dynamic>
          ? PowerConfig(
              moveUnlockLevel: _asInt(powers['move_unlock_level'],
                  PowerConfig.fallback.moveUnlockLevel),
              undoUnlockLevel: _asInt(powers['undo_unlock_level'],
                  PowerConfig.fallback.undoUnlockLevel),
              shuffleUnlockLevel: _asInt(
                powers['shuffle_unlock_level'],
                PowerConfig.fallback.shuffleUnlockLevel,
              ),
              unlockGrantUses: _asInt(powers['unlock_grant_uses'],
                  PowerConfig.fallback.unlockGrantUses),
              perLevelUses: _asInt(
                  powers['per_level_uses'], PowerConfig.fallback.perLevelUses),
            )
          : PowerConfig.fallback,
      timing: timing is Map<String, dynamic>
          ? TimingConfig(
              flySeconds: _asDouble(
                  timing['fly_seconds'], TimingConfig.fallback.flySeconds),
              trayBounceScale: _asDouble(
                timing['tray_bounce_scale'],
                TimingConfig.fallback.trayBounceScale,
              ),
              matchPopScale: _asDouble(timing['match_pop_scale'],
                  TimingConfig.fallback.matchPopScale),
              sparkSeconds: _asDouble(
                  timing['spark_seconds'], TimingConfig.fallback.sparkSeconds),
              sparkCountMin: _asInt(timing['spark_count_min'],
                  TimingConfig.fallback.sparkCountMin),
              sparkCountMax: _asInt(timing['spark_count_max'],
                  TimingConfig.fallback.sparkCountMax),
              confettiSeconds: _asDouble(
                timing['confetti_seconds'],
                TimingConfig.fallback.confettiSeconds,
              ),
            )
          : TimingConfig.fallback,
      veilByDepth: veil is Map
          ? veil.map(
              (key, value) => MapEntry(key.toString(), _asDouble(value, 0)))
          : base.veilByDepth,
      bands: bands is List
          ? bands
              .whereType<Map>()
              .map(
                (raw) => DifficultyBand(
                  from: _asInt(raw['from'], 1),
                  to: _asInt(raw['to'], 1),
                  types: _asInt(raw['types'], 4),
                  cards: _asInt(raw['cards'], 24),
                  piles: _asInt(raw['piles'], 0),
                  pileSize: _asInt(raw['pile_size'], 0),
                ),
              )
              .toList()
          : base.bands,
      softHelp: soft is Map<String, dynamic>
          ? SoftHelpConfig(
              trayWarnSlotsLeft: _asInt(soft['tray_warn_slots_left'], 1),
              deadBoardTrayMin: _asInt(soft['dead_board_tray_min'], 5),
            )
          : SoftHelpConfig.fallback,
      products: iap is Map<String, dynamic> ? _products(iap) : base.products,
      api: api is Map<String, dynamic>
          ? ApiConfig(
              baseUrl: api['base_url'] as String? ?? '',
              configPath: api['config_path'] as String? ??
                  ApiConfig.fallback.configPath,
              verifyPath: api['verify_path'] as String? ??
                  ApiConfig.fallback.verifyPath,
            )
          : ApiConfig.fallback,
    );
  }

  static List<IapSku> _products(Map<String, dynamic> iap) {
    const order = [
      'barn_bundle',
      'harvest_bundle',
      'pack_small',
      'pack_medium',
      'pack_large',
      'remove_ads',
    ];
    final products = <IapSku>[];
    for (final id in order) {
      final raw = iap[id];
      if (raw is! Map) continue;
      final levels = raw['levels'];
      products.add(
        IapSku(
          id: id,
          title: raw['title'] as String? ?? id,
          priceUsd: _asDouble(raw['price_usd'], 0),
          consumable: raw['consumable'] == true,
          each: _asInt(raw['each'], 0),
          levelFrom: levels is List && levels.isNotEmpty
              ? _asInt(levels.first, 0)
              : null,
          levelTo:
              levels is List && levels.length > 1 ? _asInt(levels[1], 0) : null,
        ),
      );
    }
    return products;
  }
}

int _asInt(Object? value, int fallback) {
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

double _asDouble(Object? value, double fallback) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

final GameConfig _defaults = GameConfig(
  freeLevelCap: 20,
  totalLevels: 50,
  traySlots: 7,
  holdMax: 6,
  moveTakeMax: 3,
  cardScaleVsL1: 0.85,
  boardMaxColumns: 6,
  rotationDeg: 0,
  copiesPerType: 6,
  pileInternalShiftW: 0.1,
  neighborGapMaxW: 0.125,
  pileMinDistinctTypes: 3,
  adsEnabled: false,
  powerChargeMode: 'per_level_plus_bank',
  powers: PowerConfig.fallback,
  timing: TimingConfig.fallback,
  veilByDepth: const {'1': 0.25, '2': 0.35, '3': 0.45, '4_plus': 0.55},
  bands: const [
    DifficultyBand(from: 1, to: 2, types: 4, cards: 24, piles: 0, pileSize: 0),
    DifficultyBand(from: 3, to: 5, types: 4, cards: 24, piles: 2, pileSize: 4),
    DifficultyBand(from: 6, to: 10, types: 6, cards: 36, piles: 2, pileSize: 4),
    DifficultyBand(
        from: 11, to: 15, types: 8, cards: 48, piles: 3, pileSize: 5),
    DifficultyBand(
        from: 16, to: 25, types: 10, cards: 60, piles: 3, pileSize: 5),
    DifficultyBand(
        from: 26, to: 40, types: 12, cards: 72, piles: 4, pileSize: 6),
    DifficultyBand(
        from: 41, to: 50, types: 15, cards: 90, piles: 5, pileSize: 7),
  ],
  softHelp: SoftHelpConfig.fallback,
  products: const [
    IapSku(
        id: 'barn_bundle',
        title: 'Barn Bundle',
        priceUsd: 1.99,
        consumable: false,
        levelFrom: 21,
        levelTo: 35),
    IapSku(
      id: 'harvest_bundle',
      title: 'Harvest Bundle',
      priceUsd: 2.99,
      consumable: false,
      levelFrom: 36,
      levelTo: 50,
    ),
    IapSku(
        id: 'pack_small',
        title: 'Small kit',
        priceUsd: 2.99,
        consumable: true,
        each: 5),
    IapSku(
        id: 'pack_medium',
        title: 'Mid kit',
        priceUsd: 4.99,
        consumable: true,
        each: 12),
    IapSku(
        id: 'pack_large',
        title: 'Large kit',
        priceUsd: 9.99,
        consumable: true,
        each: 30),
    IapSku(
        id: 'remove_ads',
        title: 'Remove Ads',
        priceUsd: 2.99,
        consumable: false),
  ],
  api: ApiConfig.fallback,
);

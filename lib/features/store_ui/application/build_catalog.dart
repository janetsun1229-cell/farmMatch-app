import '../../config/domain/game_config.dart';
import '../../entitlements/domain/entitlements.dart';
import '../domain/store_copy.dart';

class StoreListing {
  const StoreListing(
      {required this.sku,
      required this.blurb,
      required this.owned,
      required this.section});

  final IapSku sku;
  final String blurb;
  final bool owned;
  final String section;
}

class BuildCatalog {
  const BuildCatalog();

  List<StoreListing> call(GameConfig config, Entitlements entitlements) {
    return [
      for (final sku in config.products)
        StoreListing(
          sku: sku,
          blurb: StoreCopy.blurb(sku.id),
          owned: !sku.consumable && entitlements.owns(sku.id),
          section: _section(sku.id),
        ),
    ];
  }

  String _section(String id) {
    if (id == 'barn_bundle' || id == 'harvest_bundle') return StoreCopy.room;
    if (id == 'remove_ads') return StoreCopy.quiet;
    return StoreCopy.tools;
  }
}

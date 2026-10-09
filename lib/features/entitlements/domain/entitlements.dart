class Entitlements {
  const Entitlements({
    required this.removeAds,
    required this.barnBundle,
    required this.harvestBundle,
  });

  final bool removeAds;
  final bool barnBundle;
  final bool harvestBundle;

  static const none =
      Entitlements(removeAds: false, barnBundle: false, harvestBundle: false);

  bool owns(String sku) {
    switch (sku) {
      case 'remove_ads':
        return removeAds;
      case 'barn_bundle':
        return barnBundle;
      case 'harvest_bundle':
        return harvestBundle;
      default:
        return false;
    }
  }

  Entitlements applySku(String sku) {
    switch (sku) {
      case 'remove_ads':
        return Entitlements(
            removeAds: true,
            barnBundle: barnBundle,
            harvestBundle: harvestBundle);
      case 'barn_bundle':
        return Entitlements(
            removeAds: removeAds,
            barnBundle: true,
            harvestBundle: harvestBundle);
      case 'harvest_bundle':
        return Entitlements(
            removeAds: removeAds, barnBundle: barnBundle, harvestBundle: true);
      default:
        return this;
    }
  }
}

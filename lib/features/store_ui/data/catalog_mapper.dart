import '../../config/domain/game_config.dart';
import '../../entitlements/domain/entitlements.dart';
import '../application/build_catalog.dart';

class CatalogMapper {
  const CatalogMapper();

  List<StoreListing> map(GameConfig config, Entitlements entitlements) {
    return const BuildCatalog().call(config, entitlements);
  }
}

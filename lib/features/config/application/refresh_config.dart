import '../domain/game_config.dart';
import '../domain/repositories/config_repository.dart';

class RefreshConfig {
  const RefreshConfig(this._repository);

  final ConfigRepository _repository;

  Future<GameConfig> call(
      {required String appVersion, required String platform}) {
    return _repository.refresh(appVersion: appVersion, platform: platform);
  }
}

import '../game_config.dart';

abstract class ConfigRepository {
  GameConfig get current;
  Future<GameConfig> refresh(
      {required String appVersion, required String platform});
}

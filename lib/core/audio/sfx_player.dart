import 'package:audioplayers/audioplayers.dart';

class SfxPlayer {
  SfxPlayer() : _player = AudioPlayer();

  final AudioPlayer _player;
  bool muted = false;

  Future<void> play(String name) async {
    if (muted) return;
    try {
      await _player.stop();
      await _player.play(AssetSource('audio/$name.wav'));
    } catch (_) {}
  }

  Future<void> dispose() async {
    try {
      await _player.dispose();
    } catch (_) {}
  }
}

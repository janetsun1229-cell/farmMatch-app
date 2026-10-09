import 'package:flutter/widgets.dart';

import '../../entitlements/domain/entitlements.dart';
import '../../entitlements/domain/level_gate.dart';
import '../../invite/application/capture_invite.dart';
import '../data/deferred_link_store.dart';
import '../domain/deep_link.dart';
import '../domain/deep_link_parser.dart';

class OpenDeepLink {
  const OpenDeepLink({
    required DeferredLinkStore deferred,
    required CaptureInvite capture,
    required LevelGate gate,
    required Entitlements Function() entitlements,
  })  : _deferred = deferred,
        _capture = capture,
        _gate = gate,
        _entitlements = entitlements;

  final DeferredLinkStore _deferred;
  final CaptureInvite _capture;
  final LevelGate _gate;
  final Entitlements Function() _entitlements;

  Future<GrowthLaunch?> call() async {
    final platform = _platformRaw();
    if (platform != null) {
      // A live link wins. Drop any saved referrer so it cannot attribute later.
      await _deferred.consume();
    }
    final raw = platform ?? await _deferred.takeOnce();
    if (raw == null) return null;
    final intent = DeepLinkParser.parse(raw);
    if (intent == null) return null;
    if (intent.kind == DeepLinkKind.invite && intent.code != null) {
      final saved = await _capture.call(intent.code!);
      if (!saved && intent.code != null) {
        return GrowthLaunch(
          intent: intent,
          location: '/',
          notice: null,
        );
      }
    }
    final target = DeepLinkNavigator.resolve(
      intent: intent,
      canPlay: (level) => _gate.check(level, _entitlements()).allowed,
    );
    return GrowthLaunch(
      intent: intent,
      location: target.location,
      notice: target.notice,
    );
  }

  String? _platformRaw() {
    final name = WidgetsBinding.instance.platformDispatcher.defaultRouteName;
    if (name.isEmpty || name == '/') return null;
    if (DeepLinkParser.parse(name) == null) return null;
    return name;
  }
}

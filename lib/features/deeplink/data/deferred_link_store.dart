import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/deep_link_parser.dart';

/// First-open deferred link.
///
/// Firebase Dynamic Links is retired. This stub reads a Play Install Referrer
/// stand-in (`install_referrer`) once, then the clipboard once, and then
/// forgets both so a later launch does not attribute again.
class DeferredLinkStore {
  DeferredLinkStore(
    this._preferences, {
    this.readClipboard = false,
  });

  final SharedPreferences _preferences;
  final bool readClipboard;

  static const referrerKey = 'install_referrer';
  static const consumedKey = 'deferred_link_consumed';

  Future<void> consume() async {
    await _preferences.setBool(consumedKey, true);
  }

  Future<String?> takeOnce() async {
    if (_preferences.getBool(consumedKey) ?? false) return null;
    await _preferences.setBool(consumedKey, true);
    final referrer = _preferences.getString(referrerKey)?.trim();
    if (referrer != null && referrer.isNotEmpty) return referrer;
    if (!readClipboard) return null;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();
      if (text != null && DeepLinkParser.looksLike(text)) return text;
    } catch (_) {
      return null;
    }
    return null;
  }
}

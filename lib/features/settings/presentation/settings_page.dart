import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/farm_theme.dart';
import '../../entitlements/presentation/ads_status_line.dart';
import '../../iap/presentation/restore_purchases_button.dart';
import '../../identity/presentation/nickname_field.dart';
import '../../progress/presentation/mute_button.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final TextEditingController _nickname;
  String? _error;
  var _restoring = false;

  @override
  void initState() {
    super.initState();
    _nickname =
        TextEditingController(text: ref.read(identityProvider).nickname);
  }

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final error =
        await ref.read(identityProvider.notifier).rename(_nickname.text);
    if (!mounted) return;
    setState(() => _error = error);
    if (error == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Nickname saved.')));
    }
  }

  Future<void> _restore() async {
    setState(() => _restoring = true);
    final outcome = await ref.read(restorePurchasesProvider).call();
    ref.read(entitlementsProvider.notifier).reload();
    if (!mounted) return;
    setState(() => _restoring = false);
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(outcome.message ?? 'Purchases restored.')));
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(progressProvider);
    final entitlements = ref.watch(entitlementsProvider);
    return SkyBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: FarmColors.ink,
          title: const Text('Settings',
              style: TextStyle(fontWeight: FontWeight.w900)),
          actions: [
            MuteButton(
              muted: progress.muted,
              onPressed: () =>
                  ref.read(progressProvider.notifier).setMuted(!progress.muted),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
            children: [
              NicknameField(
                  controller: _nickname, onSave: _save, error: _error),
              const SizedBox(height: 12),
              RestorePurchasesButton(busy: _restoring, onPressed: _restore),
              const SizedBox(height: 12),
              AdsStatusLine(removeAds: entitlements.removeAds),
              const SizedBox(height: 18),
              const Text(
                'This game keeps a guest profile on this device only. There is no login and no cloud save. Uninstalling the app removes your progress, tools, and nickname.',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600, height: 1.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

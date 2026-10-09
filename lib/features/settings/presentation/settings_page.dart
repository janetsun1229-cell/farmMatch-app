import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/theme/farm_theme.dart';
import '../../auth/domain/auth_provider_kind.dart';
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
    _nickname = TextEditingController(
      text: ref.read(identityProvider).nickname,
    );
  }

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final error = await ref
        .read(identityProvider.notifier)
        .rename(_nickname.text);
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
    if (outcome.restoredSkus.isNotEmpty) {
      await ref.read(authStateProvider.notifier).syncFromCloud();
    }
    if (!mounted) return;
    setState(() => _restoring = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(outcome.message ?? 'Purchases restored.')),
    );
  }

  Future<void> _bind(AuthProviderKind provider) async {
    final error = await ref.read(authStateProvider.notifier).bind(provider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Progress saved to your account.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(progressProvider);
    final entitlements = ref.watch(entitlementsProvider);
    final auth = ref.watch(authStateProvider);
    final link = auth.link;
    return SkyBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: FarmColors.ink,
          title: const Text(
            'Settings',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
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
                controller: _nickname,
                onSave: _save,
                error: _error,
              ),
              const SizedBox(height: 12),
              _AccountCard(
                linkedLabel: link == null
                    ? null
                    : 'Linked with ${link.displayName}',
                onLinkX: link == null ? () => _bind(AuthProviderKind.x) : null,
                onLinkFacebook: link == null
                    ? () => _bind(AuthProviderKind.facebook)
                    : null,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                key: const Key('open-friends'),
                onPressed: () => context.push('/friends'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: FarmColors.ink,
                  side: const BorderSide(color: Color(0xFF8A6340), width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                child: const Text('Friends & gifts'),
              ),
              const SizedBox(height: 12),
              RestorePurchasesButton(busy: _restoring, onPressed: _restore),
              const SizedBox(height: 12),
              AdsStatusLine(removeAds: entitlements.removeAds),
              const SizedBox(height: 18),
              const Text(
                'Play as a guest with no connection. Link X or Facebook when you want progress, tools, and purchases kept on your account. Friends can send one free tool a day. Restore Purchases only brings back Remove Ads, Barn Bundle, and Harvest Bundle from the store.',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.linkedLabel,
    required this.onLinkX,
    required this.onLinkFacebook,
  });

  final String? linkedLabel;
  final VoidCallback? onLinkX;
  final VoidCallback? onLinkFacebook;

  @override
  Widget build(BuildContext context) {
    final linked = linkedLabel != null;
    return Container(
      key: const Key('account-status'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FarmColors.cream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF8A6340), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            linked ? linkedLabel! : 'Playing as a guest',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            linked ? 'Progress, tools, and purchases sync to this account.' : 'Link X or Facebook to save progress. You can skip and keep playing.',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          if (!linked) ...[
            const SizedBox(height: 10),
            FilledButton(
              key: const Key('settings-bind-x'),
              onPressed: onLinkX,
              child: const Text('Link X'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: const Key('settings-bind-facebook'),
              onPressed: onLinkFacebook,
              child: const Text('Link Facebook'),
            ),
          ],
        ],
      ),
    );
  }
}

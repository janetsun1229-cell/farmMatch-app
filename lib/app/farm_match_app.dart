import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/farm_theme.dart';
import '../features/deeplink/domain/deep_link.dart';
import 'providers.dart';
import 'router.dart';

class FarmMatchApp extends ConsumerStatefulWidget {
  const FarmMatchApp({super.key});

  @override
  ConsumerState<FarmMatchApp> createState() => _FarmMatchAppState();
}

class _FarmMatchAppState extends ConsumerState<FarmMatchApp> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    Future<void>.microtask(() async {
      await ref.read(configProvider.notifier).refresh();
      if (!mounted) return;
      await ref.read(authStateProvider.notifier).syncFromCloud();
      if (!mounted) return;
      final launch = await ref.read(openDeepLinkProvider).call();
      if (!mounted) return;
      if (launch != null) {
        _applyLaunch(launch);
      }
      final link = ref.read(authStateProvider).link;
      if (link != null) {
        final bundles =
            await ref.read(claimInviterRewardsProvider).call(link.accountId);
        if (bundles > 0) {
          await ref.read(localRevisionProvider).touch();
          await ref.read(authStateProvider.notifier).syncFromCloud();
        }
      }
    });
  }

  void _applyLaunch(GrowthLaunch launch) {
    final notice = launch.notice;
    if (launch.intent.kind == DeepLinkKind.invite && notice != null) {
      ref.read(inviteBannerProvider.notifier).refresh();
    } else if (notice != null) {
      ref.read(growthToastProvider.notifier).show(notice);
    }
    if (launch.location != '/') {
      ref.read(routerProvider).go(launch.location);
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Farm Match',
      debugShowCheckedModeBanner: false,
      theme: buildFarmTheme(),
      scrollBehavior: const FarmScrollBehavior(),
      routerConfig: router,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/farm_theme.dart';
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
    Future<void>.microtask(() => ref.read(configProvider.notifier).refresh());
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/farm_match_app.dart';
import 'app/providers.dart';
import 'features/config/data/config_repository_impl.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final preferences = await SharedPreferences.getInstance();
  final config = await ConfigRepositoryImpl.loadInitial(preferences);
  runApp(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(preferences),
        initialConfigProvider.overrideWithValue(config),
      ],
      child: const FarmMatchApp(),
    ),
  );
}

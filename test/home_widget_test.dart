import 'package:farm_match/app/farm_match_app.dart';
import 'package:farm_match/app/providers.dart';
import 'package:farm_match/features/config/domain/game_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('home opens on the current level', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsProvider.overrideWithValue(preferences),
          initialConfigProvider.overrideWithValue(GameConfig.fallback()),
        ],
        child: const FarmMatchApp(),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('home-play')), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.byKey(const Key('open-settings')), findsOneWidget);
    expect(find.textContaining('Hello,'), findsOneWidget);
  });
}

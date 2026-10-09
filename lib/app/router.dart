import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/game/presentation/game_page.dart';
import '../features/gift/presentation/friends_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/store_ui/presentation/store_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    overridePlatformDefaultLocation: true,
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomePage()),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/friends',
        builder: (context, state) => const FriendsPage(),
      ),
      GoRoute(
        path: '/store',
        builder: (context, state) =>
            StorePage(focusSku: state.uri.queryParameters['focus']),
      ),
      GoRoute(
        path: '/play/:level',
        builder: (context, state) {
          final level = int.tryParse(state.pathParameters['level'] ?? '') ?? 1;
          return GamePage(level: level);
        },
      ),
    ],
  );
});

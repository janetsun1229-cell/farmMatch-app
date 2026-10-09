import 'package:flutter/material.dart';

class FarmColors {
  static const skyTop = Color(0xFF8ED4F5);
  static const sky = Color(0xFF87C4EA);
  static const grass = Color(0xFF7FBF55);
  static const grassDark = Color(0xFF4E9A32);
  static const wood = Color(0xFF6E3F1C);
  static const woodDark = Color(0xFF5A3214);
  static const woodEdge = Color(0xFF8A5A32);
  static const cream = Color(0xFFFFF6E4);
  static const creamDeep = Color(0xFFFFE9C4);
  static const ink = Color(0xFF3D2914);
  static const gold = Color(0xFFE8C76A);
  static const warn = Color(0xFFC65A12);
  static const leaf = Color(0xFF2F9E44);
  static const wool = Color(0xFFD7EFC4);
  static const veil = Color(0xFF2A200E);
}

class FarmScrollBehavior extends MaterialScrollBehavior {
  const FarmScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();
}

ThemeData buildFarmTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
        seedColor: FarmColors.leaf, brightness: Brightness.light),
    scaffoldBackgroundColor: FarmColors.sky,
  );
  return base.copyWith(
    textTheme: base.textTheme
        .apply(bodyColor: FarmColors.ink, displayColor: FarmColors.ink),
    splashFactory: InkRipple.splashFactory,
  );
}

class SkyBackdrop extends StatelessWidget {
  const SkyBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            FarmColors.skyTop,
            FarmColors.sky,
            Color(0xFFB7E38A),
            FarmColors.grass
          ],
          stops: [0, 0.42, 0.72, 1],
        ),
      ),
      child: child,
    );
  }
}

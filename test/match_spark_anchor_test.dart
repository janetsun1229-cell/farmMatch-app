import 'package:farm_match/features/game/presentation/game_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sparks sit on the box around the three clearing slots', () {
    final center = matchSparkAnchor(const [
      Rect.fromLTWH(10, 400, 48, 48),
      Rect.fromLTWH(62, 400, 48, 48),
      Rect.fromLTWH(114, 400, 48, 48),
    ]);
    expect(center, const Offset(86, 424));
  });

  test('a single slot still anchors on that slot', () {
    final center = matchSparkAnchor(const [
      Rect.fromLTWH(20, 30, 40, 40),
    ]);
    expect(center, const Offset(40, 50));
  });

  test('no slots means no spark anchor', () {
    expect(matchSparkAnchor(const []), isNull);
  });

  test('landing bounce peaks at the configured scale and returns to 1', () {
    expect(trayLandScale(0, 1.08), 1);
    expect(trayLandScale(0.45, 1.08), closeTo(1.08, 0.001));
    expect(trayLandScale(1, 1.08), 1);
  });
}

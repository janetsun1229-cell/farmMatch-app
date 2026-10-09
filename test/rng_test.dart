import 'package:farm_match/features/game/domain/level/js_rng.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rng matches the HTML prototype', () {
    final first = JsRng(1);
    expect(first.next(), closeTo(0.6270739405881613, 1e-12));
    expect(first.next(), closeTo(0.002735721180215478, 1e-12));
    expect(first.next(), closeTo(0.5274470399599522, 1e-12));
    expect(first.next(), closeTo(0.9810509674716741, 1e-12));
    final level50 = JsRng(50);
    expect(level50.next(), closeTo(0.5425962486770004, 1e-12));
    expect(level50.next(), closeTo(0.1095753195695579, 1e-12));
  });
}

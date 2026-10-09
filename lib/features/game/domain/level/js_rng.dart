/// JavaScript `Math.imul` and the prototype's RNG, bit-for-bit.
int jsToInt32(int value) {
  final bits = value & 0xFFFFFFFF;
  if (bits >= 0x80000000) return bits - 0x100000000;
  return bits;
}

int jsToUint32(int value) => value & 0xFFFFFFFF;

int jsImul(int a, int b) {
  final a0 = jsToUint32(a);
  final b0 = jsToUint32(b);
  final ah = (a0 >> 16) & 0xffff;
  final al = a0 & 0xffff;
  final bh = (b0 >> 16) & 0xffff;
  final bl = b0 & 0xffff;
  return jsToInt32(al * bl + ((ah * bl + al * bh) << 16));
}

int jsRound(double value) => (value + 0.5).floor();

class JsRng {
  JsRng(int seed) : _a = jsToUint32(seed);

  int _a;

  double next() {
    _a = jsToInt32(jsToUint32(_a) + 0x6d2b79f5);
    var t = jsImul(
      jsToInt32(jsToUint32(_a) ^ (jsToUint32(_a) >> 15)),
      jsToInt32(1 | jsToUint32(_a)),
    );
    final inner = jsImul(
      jsToInt32(jsToUint32(t) ^ (jsToUint32(t) >> 7)),
      jsToInt32(61 | jsToUint32(t)),
    );
    final sum32 = jsToInt32(jsToUint32(t) + jsToUint32(inner));
    t = jsToInt32(jsToUint32(sum32) ^ jsToUint32(t));
    return (jsToUint32(t) ^ (jsToUint32(t) >> 14)) / 4294967296.0;
  }
}

void jsShuffle<T>(List<T> items, double Function() rand) {
  for (var i = items.length - 1; i > 0; i--) {
    final j = (rand() * (i + 1)).floor();
    final tmp = items[i];
    items[i] = items[j];
    items[j] = tmp;
  }
}

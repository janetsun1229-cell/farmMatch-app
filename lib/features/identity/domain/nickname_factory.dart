import 'dart:math';

class NicknameFactory {
  NicknameFactory({Random? random}) : _random = random ?? Random();

  static const adjectives = [
    'Sunny',
    'Kind',
    'Merry',
    'Rusty',
    'Golden',
    'Quiet',
    'Brisk',
    'Happy',
    'Gentle',
    'Cozy',
  ];

  static const nouns = [
    'Barn',
    'Harvest',
    'Meadow',
    'Tractor',
    'Pumpkin',
    'Clover',
    'Pasture',
    'Orchard',
    'Lantern',
    'Sparrow',
  ];

  final Random _random;

  String next() {
    final name = '${adjectives[_random.nextInt(adjectives.length)]}'
        '${nouns[_random.nextInt(nouns.length)]}';
    return name.length > 16 ? name.substring(0, 16) : name;
  }

  static String? validate(String raw) {
    final nickname = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (nickname.isEmpty) return 'Enter a nickname.';
    if (nickname.length > 16) return 'Use 16 characters or fewer.';
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9 ]*$').hasMatch(nickname)) {
      return 'Use letters, numbers, and spaces.';
    }
    return null;
  }

  static String normalize(String raw) =>
      raw.trim().replaceAll(RegExp(r'\s+'), ' ');
}

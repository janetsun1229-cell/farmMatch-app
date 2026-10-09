enum Power { move, undo, shuffle }

extension PowerLabel on Power {
  String get label {
    switch (this) {
      case Power.move:
        return 'Move';
      case Power.undo:
        return 'Undo';
      case Power.shuffle:
        return 'Shuffle';
    }
  }
}

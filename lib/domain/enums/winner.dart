enum Winner {
  draw,
  white,
  black;

  int get code => index;

  static Winner? fromCode(int code) {
    if (code < 0 || code >= values.length) return null;
    return values[code];
  }

  String get displayName {
    switch (this) {
      case Winner.draw:
      return 'Draw';
      case Winner.white:
      return 'White';
      case Winner.black:
      return 'Black';
    }
  }
}
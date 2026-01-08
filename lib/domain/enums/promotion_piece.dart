enum PromotionPiece {
  queen,
  rook,
  bishop,
  knight;

  String get letter {
    switch (this) {
      case PromotionPiece.queen:
      return 'q';
      case PromotionPiece.rook:
      return 'r';
      case PromotionPiece.bishop:
      return 'b';
      case PromotionPiece.knight:
      return 'n';
    }
  }

  int get code => index + 1;

  static PromotionPiece? fromCode(int code) {
    if (code < 1 || code > values.length) return null;
    return values[code - 1];
  }

  static PromotionPiece? fromLetter(String letter) {
    switch (letter.toLowerCase()) {
      case 'q':
      return queen;
      case 'r':
      return rook;
      case 'b':
      return bishop;
      case 'n':
      return knight;
      default:
      return null;
    }
  }
}
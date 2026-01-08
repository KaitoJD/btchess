import 'package:equatable/equatable.dart';

enum PieceType {
  king('k', 'King'),
  queen('q', 'Queen'),
  rook('r', 'Rook'),
  bishop('b', 'Bishop'),
  knight('n', 'Knight'),
  pawn('p', 'Pawn');

  final String letter;
  final String displayName;

  const PieceType(this.letter, this.displayName);

  static PieceType? fromLetter(String letter) {
    final lower = letter.toLowerCase();

    for (final type in values) {
      if (type.letter == lower) {
        return type;
      }
    }

    return null;
  }
}

enum PieceColor {
  white,
  black;

  PieceColor get opposite => this == white ? black : white;

  String get fenChar => this == white ? 'w' : 'b';

  static PieceColor? fromFenChar(String char) {
    switch (char.toLowerCase()) {
      case 'w':
      return white;
      case 'b':
      return black;
      default:
      return null;
    }
  }
}

class Piece extends Equatable {
  final PieceType type;
  final PieceColor color;

  const Piece({
    required this.type,
    required this.color,
  });

  static Piece? fromFenChar(String char) {
    if (char.isEmpty) return null;

    final type = PieceType.fromLetter(char);
    if (type == null) return null;

    final color = char == char.toUpperCase() ? PieceColor.white : PieceColor.black;

    return Piece(type: type, color: color);
  }

  String get fenChar {
    final letter = type.letter;
    return color == PieceColor.white ? letter.toUpperCase() : letter;
  }

  String get symbol {
    const symbols = {
      (PieceType.king, PieceColor.white): '♔',
      (PieceType.queen, PieceColor.white): '♕',
      (PieceType.rook, PieceColor.white): '♖',
      (PieceType.bishop, PieceColor.white): '♗',
      (PieceType.knight, PieceColor.white): '♘',
      (PieceType.pawn, PieceColor.white): '♙',
      (PieceType.king, PieceColor.black): '♚',
      (PieceType.queen, PieceColor.black): '♛',
      (PieceType.rook, PieceColor.black): '♜',
      (PieceType.bishop, PieceColor.black): '♝',
      (PieceType.knight, PieceColor.black): '♞',
      (PieceType.pawn, PieceColor.black): '♟',
    };

    return symbols[(type, color)] ?? '?';
  }

  bool get isWhite => color == PieceColor.white;

  bool get isBlack => color == PieceColor.black;

  @override
  List<Object?> get props => [type, color];

  @override
  String toString() => '${color.name} ${type.displayName}';

  factory Piece.whiteKing() => const Piece(type: PieceType.king, color: PieceColor.white);
  factory Piece.whiteQueen() => const Piece(type: PieceType.queen, color: PieceColor.white);
  factory Piece.whiteRook() => const Piece(type: PieceType.rook, color: PieceColor.white);
  factory Piece.whiteBishop() => const Piece(type: PieceType.bishop, color: PieceColor.white);
  factory Piece.whiteKnight() => const Piece(type: PieceType.knight, color: PieceColor.white);
  factory Piece.whitePawn() => const Piece(type: PieceType.pawn, color: PieceColor.white);

  factory Piece.blackKing() => const Piece(type: PieceType.king, color: PieceColor.black);
  factory Piece.blackQueen() => const Piece(type: PieceType.queen, color: PieceColor.black);
  factory Piece.blackRook() => const Piece(type: PieceType.rook, color: PieceColor.black);
  factory Piece.blackBishop() => const Piece(type: PieceType.bishop, color: PieceColor.black);
  factory Piece.blackKnight() => const Piece(type: PieceType.knight, color: PieceColor.black);
  factory Piece.blackPawn() => const Piece(type: PieceType.pawn, color: PieceColor.black);
}
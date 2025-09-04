enum PieceType {
  pawn,
  rook,
  knight,
  bishop,
  queen,
  king,
}

enum PieceColor {
  white,
  black,
}

class ChessPiece {
  final PieceType type;
  final PieceColor color;
  bool hasMoved;

  ChessPiece({
    required this.type,
    required this.color,
    this.hasMoved = false,
  });

  String get symbol {
    const symbols = {
      PieceType.pawn: {'white': '♙', 'black': '♟'},
      PieceType.rook: {'white': '♖', 'black': '♜'},
      PieceType.knight: {'white': '♘', 'black': '♞'},
      PieceType.bishop: {'white': '♗', 'black': '♝'},
      PieceType.queen: {'white': '♕', 'black': '♛'},
      PieceType.king: {'white': '♔', 'black': '♚'},
    };
    return symbols[type]![color.name]!;
  }

  ChessPiece copyWith({
    PieceType? type,
    PieceColor? color,
    bool? hasMoved,
  }) {
    return ChessPiece(
      type: type ?? this.type,
      color: color ?? this.color,
      hasMoved: hasMoved ?? this.hasMoved,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.index,
      'color': color.index,
      'hasMoved': hasMoved,
    };
  }

  factory ChessPiece.fromJson(Map<String, dynamic> json) {
    return ChessPiece(
      type: PieceType.values[json['type']],
      color: PieceColor.values[json['color']],
      hasMoved: json['hasMoved'],
    );
  }
}

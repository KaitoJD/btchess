import 'position.dart';
import 'chess_piece.dart';

class Move {
  final Position from;
  final Position to;
  final ChessPiece? capturedPiece;
  final ChessPiece? promotedTo;
  final bool isEnPassant;
  final bool isCastling;

  const Move({
    required this.from,
    required this.to,
    this.capturedPiece,
    this.promotedTo,
    this.isEnPassant = false,
    this.isCastling = false,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Move &&
        other.from == from &&
        other.to == to &&
        other.capturedPiece == capturedPiece &&
        other.promotedTo == promotedTo &&
        other.isEnPassant == isEnPassant &&
        other.isCastling == isCastling;
  }

  @override
  int get hashCode {
    return from.hashCode ^
        to.hashCode ^
        capturedPiece.hashCode ^
        promotedTo.hashCode ^
        isEnPassant.hashCode ^
        isCastling.hashCode;
  }

  @override
  String toString() {
    return '${from.toAlgebraic()}-${to.toAlgebraic()}';
  }

  Map<String, dynamic> toJson() {
    return {
      'from': from.toJson(),
      'to': to.toJson(),
      'capturedPiece': capturedPiece?.toJson(),
      'promotedTo': promotedTo?.toJson(),
      'isEnPassant': isEnPassant,
      'isCastling': isCastling,
    };
  }

  factory Move.fromJson(Map<String, dynamic> json) {
    return Move(
      from: Position.fromJson(json['from']),
      to: Position.fromJson(json['to']),
      capturedPiece: json['capturedPiece'] != null
          ? ChessPiece.fromJson(json['capturedPiece'])
          : null,
      promotedTo: json['promotedTo'] != null
          ? ChessPiece.fromJson(json['promotedTo'])
          : null,
      isEnPassant: json['isEnPassant'],
      isCastling: json['isCastling'],
    );
  }
}

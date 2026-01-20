import 'package:equatable/equatable.dart';
import 'piece.dart';
import 'square.dart';
import '../enums/promotion_piece.dart';

// Represents a chess move

class Move extends Equatable {
  final Square from;
  final Square to;
  final PromotionPiece? promotion;
  final String? san; // The Standard Algebraic Notation of the move("e4", "Nf3", ..)
  final Piece? capturedPiece;
  final Piece? movedPiece;
  final bool isCastling;
  final bool isEnPassant;
  final bool isCheck;
  final bool isCheckmate;

  const Move({
    required this.from,
    required this.to,
    this.promotion,
    this.san,
    this.capturedPiece,
    this.movedPiece,
    this.isCastling = false,
    this.isEnPassant = false,
    this.isCheck = false,
    this.isCheckmate = false,
  });

  factory Move.fromIndices({
    required int fromIndex,
    required int toIndex,
    PromotionPiece? promotion,
  }) {
    return Move(
      from: Square.fromIndex(fromIndex),
      to: Square.fromIndex(toIndex),
      promotion: promotion,
    );
  }

  factory Move.fromAlgebraic({
    required String from,
    required String to,
    PromotionPiece? promotion,
  }) {
    return Move(
      from: Square.fromAlgebraic(from),
      to: Square.fromAlgebraic(to),
      promotion: promotion,
    );
  }

  // Returns the Universal Chess Interface notation
  String get uci {
    final promoSuffix = promotion?.letter ?? '';
    return '${from.algebraic}${to.algebraic}$promoSuffix';
  }

  bool get isPromotion => promotion != null;
  bool get isCapture => capturedPiece != null;

  Move copyWith({
    Square? from,
    Square? to,
    PromotionPiece? promotion,
    String? san,
    Piece? capturedPiece,
    Piece? movedPiece,
    bool? isCastling,
    bool? isEnPassant,
    bool? isCheck,
    bool? isCheckmate,
  }) {
    return Move(
      from: from ?? this.from,
      to: to ?? this.to,
      promotion: promotion ?? this.promotion,
      san: san ?? this.san,
      capturedPiece: capturedPiece ?? this.capturedPiece,
      movedPiece: movedPiece ?? this.movedPiece,
      isCastling: isCastling ?? this.isCastling,
      isEnPassant: isEnPassant ?? this.isEnPassant,
      isCheck: isCheck ?? this.isCheck,
      isCheckmate: isCheckmate ?? this.isCheckmate,
    );
  }

  @override
  List<Object?> get props => [from, to, promotion];

  @override
  String toString() => san ?? uci;
}
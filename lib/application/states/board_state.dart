import 'package:equatable/equatable.dart';
import '../../domain/models/move.dart';
import '../../domain/models/piece.dart';
import '../../domain/models/square.dart';

class BoardState extends Equatable {
  final Square? selectedSquare;
  final List<Square> legalMoves;
  final Move? lastMove;
  final Square? checkSquare;
  final bool showPromotionDialog;
  final (Square, Square)? pendingPromotion;
  final bool isFlipped;
  final Map<int, Piece> pieces;
  final PieceColor currentTurn;

  const BoardState({
    this.selectedSquare,
    this.legalMoves = const [],
    this.lastMove,
    this.checkSquare,
    this.showPromotionDialog = false,
    this.pendingPromotion,
    this.isFlipped = false,
    this.pieces = const {},
    this.currentTurn = PieceColor.white,
  });

  factory BoardState.initial() => const BoardState();

  BoardState copyWith({
    Square? selectedSquare,
    List<Square>? legalMoves,
    Move? lastMove,
    Square? checkSquare,
    bool? showPromotionDialog,
    (Square, Square)? pendingPromotion,
    bool? isFlipped,
    Map<int, Piece>? pieces,
    PieceColor? currentTurn,
    bool clearSelection = false,
    bool clearLastMove = false,
    bool clearCheck = false,
    bool clearPendingPromotion = false,
  }) {
    return BoardState(
      selectedSquare: clearSelection ? null : (selectedSquare ?? this.selectedSquare),
      legalMoves: legalMoves ?? this.legalMoves,
      lastMove: clearLastMove ? null : (lastMove ?? this.lastMove),
      checkSquare: clearCheck ? null : (checkSquare ?? this.checkSquare),
      showPromotionDialog: showPromotionDialog ?? this.showPromotionDialog,
      pendingPromotion: clearPendingPromotion ? null : (pendingPromotion ?? this.pendingPromotion),
      isFlipped: isFlipped ?? this.isFlipped,
      pieces: pieces ?? this.pieces,
      currentTurn: currentTurn ?? this.currentTurn,
    );
  }

  @override
  List<Object?> get props => [
    selectedSquare, legalMoves, lastMove, checkSquare, showPromotionDialog, pendingPromotion, isFlipped, pieces, currentTurn
  ];
}
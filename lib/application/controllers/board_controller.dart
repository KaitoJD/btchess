import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/enums/promotion_piece.dart';
import '../../domain/models/move.dart';
import '../../domain/models/piece.dart';
import '../../domain/models/square.dart';
import '../../domain/services/chess_service.dart';
import '../states/board_state.dart';

class BoardController extends StateNotifier<BoardState> {
  final ChessService _chessService;
  String _currentFen;

  BoardController({
    required ChessService chessService,
    required String initialFen,
  })  : _chessService = chessService,
        _currentFen = initialFen,
        super(const BoardState()) {
    _updateBoardFromFen();
  }

  void updateFromFen(String fen, {Move? lastMove}) {
    _currentFen = fen;
    _updateBoardFromFen(lastMove: lastMove);
  }

  void _updateBoardFromFen({Move? lastMove}) {
    final allPieces = _chessService.getAllPieces(_currentFen);
    final pieces = <int, Piece>{};

    for (final entry in allPieces.entries) {
      pieces[entry.key.index] = entry.value;
    }

    final isCheck = _chessService.isCheck(_currentFen);
    final turn = _chessService.getCurrentTurn(_currentFen);
    Square? checkSquare;

    if (isCheck) {
      checkSquare = _chessService.getKingSquare(_currentFen, turn);
    }

    state = state.copyWith(
      pieces: pieces,
      currentTurn: turn,
      checkSquare: checkSquare,
      lastMove: lastMove,
      clearSelection: true,
      legalMoves: [],
      clearCheck: !isCheck,
    );
  }

  void selectSquare(Square square) {
    final piece = state.pieces[square.index];

    if (piece != null && piece.color == state.currentTurn) {
      final legalMoves = _chessService.getLegalMoves(_currentFen, square);
      state = state.copyWith(
        selectedSquare: square,
        legalMoves: legalMoves,
      );

      return;
    }

    if (state.selectedSquare != null && state.legalMoves.contains(square)) {
      state = state.copyWith(clearSelection: true, legalMoves: []);

      return;
    }

    state = state.copyWith(clearSelection: true, legalMoves: []);
  }

  bool requiresPromotion(Square from, Square to) {
    return _chessService.requiresPromotion(_currentFen, from, to);
  }

  bool tryMove(Square from, Square to) {
    if (requiresPromotion(from, to)) {
      state = state.copyWith(
        showPromotionDialog: true,
        pendingPromotion: (from, to),
      );

      return true;
    }

    return false;
  }

  void completePromotion(PromotionPiece promotionPiece) {
    state = state.copyWith(
      showPromotionDialog: false,
      clearPendingPromotion: true,
    );
  }

  void cancelPromotion() {
    state = state.copyWith(
      showPromotionDialog: false,
      clearPendingPromotion: true,
      clearSelection: true,
      legalMoves: [],
    );
  }

  void toggleFlip() {
    state = state.copyWith(isFlipped: !state.isFlipped);
  }

  void setFlipped(bool flipped) {
    state = state.copyWith(isFlipped: flipped);
  }

  void clearSelection() {
    state = state.copyWith(clearSelection: true, legalMoves: []);
  }

  String get currentFen => _currentFen;
}
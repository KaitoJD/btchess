import '../enums/promotion_piece.dart';
import '../models/move.dart';
import '../models/piece.dart';
import '../models/square.dart';
import 'chess_service.dart';

/// The result of move validation.
enum MoveValidationError {
  none,
  noPieceOnSquare,
  wrongColorPiece,
  notYourTurn,
  illegalMove,
  promotionRequired,
  invalidPromotion,
  gameEnded,
}

class MoveValidationResult {
  final bool isValid;
  final MoveValidationError error;
  final String? message;
  final Piece? piece;
  final bool requiresPromotion;

  const MoveValidationResult._({
    required this.isValid,
    required this.error,
    this.message,
    this.piece,
    this.requiresPromotion = false,
  });

  factory MoveValidationResult.valid({Piece? piece}) {
    return MoveValidationResult._(
      isValid: true,
      error: MoveValidationError.none,
      piece: piece,
    );
  }

  factory MoveValidationResult.needsPromotion({required Piece piece}) {
    return MoveValidationResult._(
      isValid: false,
      error: MoveValidationError.promotionRequired,
      message: 'Please select a piece for promotion',
      piece: piece,
      requiresPromotion: true,
    );
  }

  factory MoveValidationResult.invalid(MoveValidationError error, String message) {
    return MoveValidationResult._(
      isValid: false,
      error: error,
      message: message,
    );
  }
}

class MoveValidator {
  final ChessService _chessService;
  const MoveValidator(this._chessService);

  MoveValidationResult validateMove({
    required String fen,
    required Square from,
    required Square to,
    required PieceColor playerColor,
    PromotionPiece? promotion,
    bool isGameOver = false,
  }) {
    if (isGameOver) {
      return MoveValidationResult.invalid(MoveValidationError.gameEnded, 'The game has already ended');
    }

    final currentTurn = _chessService.getCurrentTurn(fen);
    if (currentTurn != playerColor) {
      return MoveValidationResult.invalid(MoveValidationError.notYourTurn, "It's not your turn");
    }

    final piece = _chessService.getPieceAt(fen, from);
    if (piece == null) {
      return MoveValidationResult.invalid(MoveValidationError.noPieceOnSquare, 'No piece on ${from.algebraic}');
    }

    if (piece.color != playerColor) {
      return MoveValidationResult.invalid(MoveValidationError.wrongColorPiece, 'That piece belongs to your opponent');
    }

    final needsPromotion = _chessService.requiresPromotion(fen, from, to);
    if (needsPromotion && promotion == null) {
      return MoveValidationResult.needsPromotion(piece: piece);
    }

    if (!needsPromotion && promotion != null) {
      return MoveValidationResult.invalid(MoveValidationError.invalidPromotion, 'This move does not require promotion');
    }

    final isLegal = _chessService.isLegalMove(fen, from, to, promotion: promotion);
    if (!isLegal) {
      return MoveValidationResult.invalid(MoveValidationError.illegalMove, 'Illegal move');
    }

    return MoveValidationResult.valid(piece: piece);
  }

  bool canSelectPiece({
    required String fen,
    required Square square,
    required PieceColor playerColor,
  }) {
    final currentTurn = _chessService.getCurrentTurn(fen);
    if (currentTurn != playerColor) return false;

    final piece = _chessService.getPieceAt(fen, square);
    if (piece == null) return false;

    return piece.color == playerColor;
  }

  List<Square> getValidDestinations({
    required String fen,
    required Square from,
    required PieceColor playerColor,
  }) {
    if (!canSelectPiece(fen: fen, square: from, playerColor: playerColor)) {
      return [];
    }

    return _chessService.getLegalMoves(fen, from);
  }

  MoveValidationResult validateMoveObject({
    required String fen,
    required Move move,
    required PieceColor playerColor,
    bool isGameOver = false,
  }) {
    return validateMove(
      fen: fen,
      from: move.from,
      to: move.to,
      playerColor: playerColor,
      promotion: move.promotion,
      isGameOver: isGameOver,
    );
  }
}
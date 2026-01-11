import 'package:dartchess/dartchess.dart' as dc;
import '../enums/game_status.dart';
import '../enums/promotion_piece.dart';
import '../models/move.dart';
import '../models/piece.dart';
import '../models/square.dart';

class MoveResult {
  final bool success;
  final String? fen;
  final Move? move;
  final String? error;
  final GameStatus? status;

  const MoveResult._({
    required this.success,
    this.fen,
    this.move,
    this.error,
    this.status,
  });

  factory MoveResult.success({
    required String fen,
    required Move move,
    required GameStatus status,
  }) {
    return MoveResult._(
      success: true,
      fen: fen,
      move: move,
      status: status,
    );
  }

  factory MoveResult.failure(String error) {
    return MoveResult._(
      success: false,
      error: error,
    );
  }
}

class ChessService {
  const ChessService();

  List<Square> getLegalMoves(String fen, Square square) {
    try {
      final position = dc.Chess.fromSetup(dc.Setup.parseFen(fen));
      final dcSquare = _toDartchessSquare(square);
      final legalMoves = position.legalMoves;
      final moves = <Square>[];

      for (final entry in legalMoves.entries) {
        if (entry.key == dcSquare) {
          for (final toSquare in entry.value.squares) {
            moves.add(_fromDartchessSquare(toSquare));
          }
        }
      }

      return moves;
    } catch (e) {
      return [];
    }
  }

  Map<Square, List<Square>> getAllLegalMoves(String fen) {
    try {
      final position = dc.Chess.fromSetup(dc.Setup.parseFen(fen));
      final legalMoves = position.legalMoves;
      final result = <Square, List<Square>>{};

      for (final entry in legalMoves.entries) {
        final fromSquare = _fromDartchessSquare(entry.key);
        final toSquares = <Square>[];

        for (final toSquare in entry.value.squares) {
          toSquares.add(_fromDartchessSquare(toSquare));
        }

        if (toSquares.isNotEmpty) {
          result[fromSquare] = toSquares;
        }
      }

      return result;
    } catch (e) {
      return {};
    }
  }

  bool isLegalMove(
    String fen,
    Square from,
    Square to, 
    {
      PromotionPiece? promotion,
    }
  ) {
    try {
      final position = dc.Chess.fromSetup(dc.Setup.parseFen(fen));
      final move = _createDartchessMove(from, to, promotion);

      return position.isLegal(move);
    } catch (e) {
      return false;
    }
  }

  MoveResult makeMove(
    String fen,
    Square from,
    Square to,
    {
      PromotionPiece? promotion,
    }
  ) {
    try {
      final position = dc.Chess.fromSetup(dc.Setup.parseFen(fen));
      final dcMove = _createDartchessMove(from, to, promotion);

      if (!position.isLegal(dcMove)) {
        return MoveResult.failure('Illegal move');
      }

      final movedPiece = _getPieceAt(position, from);
      final capturedPiece = _getCapturedPiece(position, from, to);
      final isCastling = _isCastlingMove(position, from, to);
      final isEnPassant = _isEnPassantMove(position, from, to);
      final newPosition = position.play(dcMove);
      final newFen = newPosition.fen;
      final (_, san) = position.makeSan(dcMove);
      final status = _getGameStatus(newPosition);
      final move = Move(
        from: from,
        to: to,
        promotion: promotion,
        san: san,
        movedPiece: movedPiece,
        capturedPiece: capturedPiece,
        isCastling: isCastling,
        isEnPassant: isEnPassant,
        isCheck: newPosition.isCheck,
        isCheckmate: newPosition.isCheckmate,
      );

      return MoveResult.success(
        fen: newFen,
        move: move,
        status: status,
      );
    } catch (e) {
      return MoveResult.failure('Failed to make move: $e');
    }
  }

  GameStatus getGameStatus(String fen) {
    try {
      final position = dc.Chess.fromSetup(dc.Setup.parseFen(fen));
      
      return _getGameStatus(position);
    } catch (e) {
      return GameStatus.playing;
    }
  }

  bool isCheck(String fen) {
    try {
      final position = dc.Chess.fromSetup(dc.Setup.parseFen(fen));

      return position.isCheck;
    } catch (e) {
      return false;
    }
  }

  bool isCheckmate(String fen) {
    try {
      final position = dc.Chess.fromSetup(dc.Setup.parseFen(fen));
      
      return position.isCheckmate;
    } catch (e) {
      return false;
    }
  }

  bool isStalemate(String fen) {
    try {
      final position = dc.Chess.fromSetup(dc.Setup.parseFen(fen));

      return position.isStalemate;
    } catch (e) {
      return false;
    }
  }

  bool isInsufficientMaterial(String fen) {
    try {
      final position = dc.Chess.fromSetup(dc.Setup.parseFen(fen));

      return position.isInsufficientMaterial;
    } catch (e) {
      return false;
    }
  }

  bool isGameOver(String fen) {
    try {
      final position = dc.Chess.fromSetup(dc.Setup.parseFen(fen));

      return position.isGameOver;
    } catch (e) {
      return false;
    }
  }

  PieceColor getCurrentTurn(String fen) {
    try {
      final parts = fen.split(' ');

      if (parts.length > 1) {
        return parts[1] == 'b' ? PieceColor.black : PieceColor.white;
      }

      return PieceColor.white;
    } catch (e) {
      return PieceColor.white;
    }
  }

  Piece? getPieceAt(String fen, Square square) {
    try {
      final position = dc.Chess.fromSetup(dc.Setup.parseFen(fen));

      return _getPieceAt(position, square);
    } catch (e) {
      return null;
    }
  }

  Map<Square, Piece> getAllPieces(String fen) {
    try {
      final position = dc.Chess.fromSetup(dc.Setup.parseFen(fen));
      final result = <Square, Piece>{};

      for (int i = 0; i < 64; i++) {
        final dcSquare = dc.Square(i);
        final dcPiece = position.board.pieceAt(dcSquare);

        if (dcPiece != null) {
          result[Square.fromIndex(i)] = _fromDartchessPiece(dcPiece);
        }
      }

      return result;
    } catch (e) {
      return {};
    }
  }

  bool requiresPromotion(String fen, Square from, Square to) {
    try {
      final position = dc.Chess.fromSetup(dc.Setup.parseFen(fen));
      final piece = position.board.pieceAt(_toDartchessSquare(from));

      if (piece == null || piece.role != dc.Role.pawn) {
        return false;
      }

      final isWhitePawn = piece.color == dc.Side.white;
      final targetRank = to.rank;

      return (isWhitePawn && targetRank == 7) || (!isWhitePawn && targetRank == 0);
    } catch (e) {
      return false;
    }
  }

  Square? getKingSquare(String fen, PieceColor color) {
    try {
      final position = dc.Chess.fromSetup(dc.Setup.parseFen(fen));
      final side = color == PieceColor.white ? dc.Side.white : dc.Side.black;
      final kingSquare = position.board.kingOf(side);

      if (kingSquare != null) {
        return _fromDartchessSquare(kingSquare);
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  bool isValidFen(String fen) {
    try {
      dc.Setup.parseFen(fen);

      return true;
    } catch (e) {
      return false;
    }
  }

  int getHalfMoveClock(String fen) {
    try {
      final parts = fen.split(' ');

      if (parts.length >= 5) {
        return int.tryParse(parts[4]) ?? 0;
      }

      return 0;
    } catch (e) {
      return 0;
    }
  }

  int getFullMoveNumber(String fen) {
    try {
      final parts = fen.split(' ');

      if (parts.length >= 6) {
        return int.tryParse(parts[5]) ?? 1;
      }

      return 1;
    } catch (e) {
      return 1;
    }
  }

  dc.Square _toDartchessSquare(Square square) {
    return dc.Square(square.index);
  }

  Square _fromDartchessSquare(dc.Square square) {
    return Square.fromIndex(square);
  }

  dc.Move _createDartchessMove(Square from, Square to, PromotionPiece? promotion) {
    final dcFrom = _toDartchessSquare(from);
    final dcTo = _toDartchessSquare(to);

    dc.Role? promoRole;

    if (promotion != null) {
      promoRole = _toDartchessRole(promotion);
    }

    return dc.NormalMove(
      from: dcFrom,
      to: dcTo,
      promotion: promoRole,
    );
  }

  dc.Role _toDartchessRole(PromotionPiece piece) {
    switch (piece) {
      case PromotionPiece.queen:
      return dc.Role.queen;
      case PromotionPiece.rook:
      return dc.Role.rook;
      case PromotionPiece.bishop:
      return dc.Role.bishop;
      case PromotionPiece.knight:
      return dc.Role.knight;
    }
  }

  Piece _fromDartchessPiece(dc.Piece piece) {
    final type = _fromDartchessRole(piece.role);
    final color = piece.color == dc.Side.white ? PieceColor.white : PieceColor.black;

    return Piece(
      type: type,
      color: color,
    );
  }

  PieceType _fromDartchessRole(dc.Role role) {
    switch (role) {
      case dc.Role.king:
      return PieceType.king;
      case dc.Role.queen:
      return PieceType.queen;
      case dc.Role.rook:
      return PieceType.rook;
      case dc.Role.bishop:
      return PieceType.bishop;
      case dc.Role.knight:
      return PieceType.knight;
      case dc.Role.pawn:
      return PieceType.pawn;
    }
  }

  Piece? _getPieceAt(dc.Position position, Square square) {
    final dcSquare = _toDartchessSquare(square);
    final dcPiece = position.board.pieceAt(dcSquare);

    if (dcPiece == null) return null;

    return _fromDartchessPiece(dcPiece);
  }

  Piece? _getCapturedPiece(dc.Position position, Square from, Square to) {
    final movingPiece = position.board.pieceAt(_toDartchessSquare(from));

    if (movingPiece?.role == dc.Role.pawn) {
      final epSquare = position.epSquare;

      if (epSquare != null && _toDartchessSquare(to) == epSquare) {
        final capturedColor = movingPiece!.color == dc.Side.white ? PieceColor.black : PieceColor.white;

        return Piece(
          type: PieceType.pawn,
          color: capturedColor,
        );
      }
    }

    final targetPiece = position.board.pieceAt(_toDartchessSquare(to));

    if (targetPiece == null) return null;

    return _fromDartchessPiece(targetPiece);
  }

  bool _isCastlingMove(dc.Position position, Square from, Square to) {
    final piece = position.board.pieceAt(_toDartchessSquare(from));

    if (piece?.role != dc.Role.king) return false;

    final fileDiff = (to.file - from.file).abs();

    return fileDiff > 1;
  }

  bool _isEnPassantMove(dc.Position position, Square from, Square to) {
    final piece = position.board.pieceAt(_toDartchessSquare(from));

    if (piece?.role != dc.Role.pawn) return false;

    final epSquare = position.epSquare;

    if (epSquare == null) return false;

    return _toDartchessSquare(to) == epSquare;
  }

  GameStatus _getGameStatus(dc.Position position) {
    if (position.isCheckmate) {
      return GameStatus.checkmate;
    }

    if (position.isStalemate) {
      return GameStatus.stalemate;
    }

    if (position.isInsufficientMaterial) {
      return GameStatus.draw;
    }

    if (position.isCheck) {
      return GameStatus.check;
    }

    return GameStatus.playing;
  }
}
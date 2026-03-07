import 'package:flutter_test/flutter_test.dart';
import 'package:btchess/domain/services/chess_service.dart';
import 'package:btchess/domain/models/square.dart';
import 'package:btchess/domain/models/piece.dart';
import 'package:btchess/domain/enums/promotion_piece.dart';
import 'package:btchess/domain/enums/game_status.dart';
import '../../fixtures/fen_fixtures.dart';

void main() {
  const service = ChessService();

  group('ChessService', () {
    group('getLegalMoves', () {
      test('returns legal moves for e2 pawn at start', () {
        final moves = service.getLegalMoves(
          FenFixtures.startingPosition,
          Square.fromAlgebraic('e2'),
        );
        expect(moves.length, 2); // e3 and e4
        expect(moves.map((s) => s.algebraic), containsAll(['e3', 'e4']));
      });

      test('returns empty for empty square', () {
        final moves = service.getLegalMoves(
          FenFixtures.startingPosition,
          Square.fromAlgebraic('e4'),
        );
        expect(moves, isEmpty);
      });

      test('returns empty for opponent piece', () {
        final moves = service.getLegalMoves(
          FenFixtures.startingPosition,
          Square.fromAlgebraic('e7'), // black pawn, white to move
        );
        expect(moves, isEmpty);
      });
    });

    group('getAllLegalMoves', () {
      test('returns 20 legal moves from starting position', () {
        final allMoves = service.getAllLegalMoves(FenFixtures.startingPosition);
        final totalMoves = allMoves.values.fold<int>(0, (sum, list) => sum + list.length);
        expect(totalMoves, 20);
      });
    });

    group('isLegalMove', () {
      test('returns true for legal pawn push', () {
        expect(
          service.isLegalMove(
            FenFixtures.startingPosition,
            Square.fromAlgebraic('e2'),
            Square.fromAlgebraic('e4'),
          ),
          isTrue,
        );
      });

      test('returns false for illegal move', () {
        expect(
          service.isLegalMove(
            FenFixtures.startingPosition,
            Square.fromAlgebraic('e2'),
            Square.fromAlgebraic('e5'),
          ),
          isFalse,
        );
      });
    });

    group('makeMove', () {
      test('makes a legal move and returns new FEN', () {
        final result = service.makeMove(
          FenFixtures.startingPosition,
          Square.fromAlgebraic('e2'),
          Square.fromAlgebraic('e4'),
        );
        expect(result.success, isTrue);
        expect(result.fen, isNotNull);
        expect(result.move, isNotNull);
        // After e4, it should be black's turn
        expect(result.fen!.contains(' b '), isTrue);
      });

      test('fails for illegal move', () {
        final result = service.makeMove(
          FenFixtures.startingPosition,
          Square.fromAlgebraic('e2'),
          Square.fromAlgebraic('e5'),
        );
        expect(result.success, isFalse);
        expect(result.error, isNotNull);
      });

      test('handles promotion move', () {
        final result = service.makeMove(
          FenFixtures.promotionReady,
          Square.fromAlgebraic('e7'),
          Square.fromAlgebraic('e8'),
          promotion: PromotionPiece.queen,
        );
        expect(result.success, isTrue);
      });
    });

    group('game status detection', () {
      test('detects check', () {
        expect(service.isCheck(FenFixtures.whiteInCheck), isTrue);
        expect(service.isCheck(FenFixtures.startingPosition), isFalse);
      });

      test('detects checkmate', () {
        expect(service.isCheckmate(FenFixtures.scholarsMate), isTrue);
        expect(service.isCheckmate(FenFixtures.startingPosition), isFalse);
      });

      test('detects stalemate', () {
        expect(service.isStalemate(FenFixtures.stalemate), isTrue);
        expect(service.isStalemate(FenFixtures.startingPosition), isFalse);
      });

      test('detects game over', () {
        expect(service.isGameOver(FenFixtures.scholarsMate), isTrue);
        expect(service.isGameOver(FenFixtures.stalemate), isTrue);
        expect(service.isGameOver(FenFixtures.startingPosition), isFalse);
      });

      test('getGameStatus returns correct status', () {
        expect(
          service.getGameStatus(FenFixtures.startingPosition),
          GameStatus.playing,
        );
        expect(
          service.getGameStatus(FenFixtures.scholarsMate),
          GameStatus.checkmate,
        );
        expect(
          service.getGameStatus(FenFixtures.stalemate),
          GameStatus.stalemate,
        );
      });
    });

    group('getCurrentTurn', () {
      test('returns white for starting position', () {
        expect(
          service.getCurrentTurn(FenFixtures.startingPosition),
          PieceColor.white,
        );
      });

      test('returns black after white moves', () {
        expect(
          service.getCurrentTurn(FenFixtures.blackToMove),
          PieceColor.black,
        );
      });
    });

    group('getPieceAt', () {
      test('returns white king at e1', () {
        final piece = service.getPieceAt(
          FenFixtures.startingPosition,
          Square.fromAlgebraic('e1'),
        );
        expect(piece, isNotNull);
        expect(piece!.type, PieceType.king);
        expect(piece.color, PieceColor.white);
      });

      test('returns null for empty square', () {
        final piece = service.getPieceAt(
          FenFixtures.startingPosition,
          Square.fromAlgebraic('e4'),
        );
        expect(piece, isNull);
      });
    });

    group('getAllPieces', () {
      test('returns 32 pieces at starting position', () {
        final pieces = service.getAllPieces(FenFixtures.startingPosition);
        expect(pieces.length, 32);
      });
    });

    group('requiresPromotion', () {
      test('returns true for pawn reaching last rank', () {
        expect(
          service.requiresPromotion(
            FenFixtures.promotionReady,
            Square.fromAlgebraic('e7'),
            Square.fromAlgebraic('e8'),
          ),
          isTrue,
        );
      });

      test('returns false for normal pawn move', () {
        expect(
          service.requiresPromotion(
            FenFixtures.startingPosition,
            Square.fromAlgebraic('e2'),
            Square.fromAlgebraic('e4'),
          ),
          isFalse,
        );
      });
    });

    group('getKingSquare', () {
      test('finds white king at e1 in starting position', () {
        final sq = service.getKingSquare(
          FenFixtures.startingPosition,
          PieceColor.white,
        );
        expect(sq, isNotNull);
        expect(sq!.algebraic, 'e1');
      });

      test('finds black king at e8 in starting position', () {
        final sq = service.getKingSquare(
          FenFixtures.startingPosition,
          PieceColor.black,
        );
        expect(sq, isNotNull);
        expect(sq!.algebraic, 'e8');
      });
    });

    group('isValidFen', () {
      test('returns true for valid FEN', () {
        expect(service.isValidFen(FenFixtures.startingPosition), isTrue);
        expect(service.isValidFen(FenFixtures.midGame), isTrue);
      });

      test('returns false for invalid FEN', () {
        expect(service.isValidFen(FenFixtures.invalidEmpty), isFalse);
        expect(service.isValidFen(FenFixtures.invalidTooFewParts), isFalse);
      });
    });

    group('castling', () {
      test('king can castle kingside when available', () {
        final moves = service.getLegalMoves(
          FenFixtures.whiteCanCastleKingside,
          Square.fromAlgebraic('e1'),
        );
        final destinations = moves.map((s) => s.algebraic).toList();
        expect(destinations, contains('h1')); // kingside castle (dartchess uses king-captures-rook)
      });
    });

    group('en passant', () {
      test('en passant capture is legal when available', () {
        final moves = service.getLegalMoves(
          FenFixtures.enPassantAvailable,
          Square.fromAlgebraic('e5'),
        );
        final destinations = moves.map((s) => s.algebraic).toList();
        expect(destinations, contains('d6')); // en passant capture
      });
    });
  });
}


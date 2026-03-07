import 'package:flutter_test/flutter_test.dart';
import 'package:btchess/domain/services/fen_service.dart';
import 'package:btchess/domain/models/piece.dart';
import 'package:btchess/domain/models/square.dart';
import '../../fixtures/fen_fixtures.dart';

void main() {
  const service = FenService();

  group('FenService', () {
    group('parse', () {
      test('parses starting position', () {
        final components = service.parse(FenFixtures.startingPosition);
        expect(components.activeColor, 'w');
        expect(components.castling, 'KQkq');
        expect(components.enPassant, '-');
        expect(components.halfMoveClock, 0);
        expect(components.fullMoveNumber, 1);
        expect(components.isWhiteTurn, isTrue);
      });

      test('parses position with black to move', () {
        final components = service.parse(FenFixtures.blackToMove);
        expect(components.activeColor, 'b');
        expect(components.isBlackTurn, isTrue);
      });

      test('parses en passant square', () {
        final components = service.parse(FenFixtures.enPassantAvailable);
        expect(components.hasEnPassant, isTrue);
        expect(components.enPassantSquare, isNotNull);
        expect(components.enPassantSquare!.algebraic, 'd6');
      });

      test('parses castling rights', () {
        final components = service.parse(FenFixtures.startingPosition);
        expect(components.whiteCanCastleKingside, isTrue);
        expect(components.whiteCanCastleQueenside, isTrue);
        expect(components.blackCanCastleKingside, isTrue);
        expect(components.blackCanCastleQueenside, isTrue);
      });

      test('throws on invalid FEN', () {
        expect(
          () => service.parse(FenFixtures.invalidEmpty),
          throwsA(isA<FormatException>()),
        );
      });
    });

    group('tryParse', () {
      test('returns components for valid FEN', () {
        expect(service.tryParse(FenFixtures.startingPosition), isNotNull);
      });

      test('returns null for invalid FEN', () {
        expect(service.tryParse(FenFixtures.invalidEmpty), isNull);
      });
    });

    group('validate', () {
      test('returns valid for correct FEN', () {
        final result = service.validate(FenFixtures.startingPosition);
        expect(result.isValid, isTrue);
        expect(result.error, isNull);
      });

      test('returns invalid for empty string', () {
        final result = service.validate(FenFixtures.invalidEmpty);
        expect(result.isValid, isFalse);
        expect(result.error, isNotNull);
      });

      test('returns invalid for too few parts', () {
        final result = service.validate(FenFixtures.invalidTooFewParts);
        expect(result.isValid, isFalse);
      });
    });

    group('isValid', () {
      test('returns true for valid FEN', () {
        expect(service.isValid(FenFixtures.startingPosition), isTrue);
        expect(service.isValid(FenFixtures.midGame), isTrue);
      });

      test('returns false for invalid FEN', () {
        expect(service.isValid(FenFixtures.invalidEmpty), isFalse);
      });
    });

    group('getPieces', () {
      test('returns 32 pieces for starting position', () {
        final pieces = service.getPieces(FenFixtures.startingPosition);
        expect(pieces.length, 32);
      });

      test('returns correct piece at specific square', () {
        final pieces = service.getPieces(FenFixtures.startingPosition);
        final e1 = Square.fromAlgebraic('e1');
        expect(pieces[e1], isNotNull);
        expect(pieces[e1]!.type, PieceType.king);
        expect(pieces[e1]!.color, PieceColor.white);
      });
    });

    group('getPieceAt', () {
      test('returns piece at occupied square', () {
        final piece = service.getPieceAt(
          FenFixtures.startingPosition,
          Square.fromAlgebraic('e1'),
        );
        expect(piece, isNotNull);
        expect(piece!.type, PieceType.king);
      });

      test('returns null at empty square', () {
        final piece = service.getPieceAt(
          FenFixtures.startingPosition,
          Square.fromAlgebraic('e4'),
        );
        expect(piece, isNull);
      });
    });

    group('getTurn', () {
      test('returns white for starting position', () {
        expect(service.getTurn(FenFixtures.startingPosition), PieceColor.white);
      });

      test('returns black when black to move', () {
        expect(service.getTurn(FenFixtures.blackToMove), PieceColor.black);
      });
    });

    group('getHalfMoveClock and getFullMoveNumber', () {
      test('returns correct values from starting position', () {
        expect(service.getHalfMoveClock(FenFixtures.startingPosition), 0);
        expect(service.getFullMoveNumber(FenFixtures.startingPosition), 1);
      });
    });

    group('FenComponents.toFen', () {
      test('round-trips starting position', () {
        final components = service.parse(FenFixtures.startingPosition);
        expect(components.toFen(), FenFixtures.startingPosition);
      });
    });

    group('FenComponents.copyWith', () {
      test('creates copy with changed fields', () {
        final components = service.parse(FenFixtures.startingPosition);
        final copy = components.copyWith(activeColor: 'b');
        expect(copy.activeColor, 'b');
        expect(copy.piecePlacement, components.piecePlacement);
      });
    });

    group('getBoard', () {
      test('returns 8x8 grid', () {
        final board = service.getBoard(FenFixtures.startingPosition);
        expect(board.length, 8);
        for (final row in board) {
          expect(row.length, 8);
        }
      });
    });
  });
}


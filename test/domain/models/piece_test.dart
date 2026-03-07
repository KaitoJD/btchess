import 'package:flutter_test/flutter_test.dart';
import 'package:btchess/domain/models/piece.dart';

void main() {
  group('PieceType', () {
    test('fromLetter returns correct type', () {
      expect(PieceType.fromLetter('k'), PieceType.king);
      expect(PieceType.fromLetter('q'), PieceType.queen);
      expect(PieceType.fromLetter('r'), PieceType.rook);
      expect(PieceType.fromLetter('b'), PieceType.bishop);
      expect(PieceType.fromLetter('n'), PieceType.knight);
      expect(PieceType.fromLetter('p'), PieceType.pawn);
    });

    test('fromLetter is case-insensitive', () {
      expect(PieceType.fromLetter('K'), PieceType.king);
      expect(PieceType.fromLetter('Q'), PieceType.queen);
    });

    test('fromLetter returns null for invalid letter', () {
      expect(PieceType.fromLetter('x'), isNull);
      expect(PieceType.fromLetter(''), isNull);
    });

    test('letter property matches enum', () {
      expect(PieceType.king.letter, 'k');
      expect(PieceType.queen.letter, 'q');
      expect(PieceType.pawn.letter, 'p');
    });
  });

  group('PieceColor', () {
    test('fromFenChar parses w and b', () {
      expect(PieceColor.fromFenChar('w'), PieceColor.white);
      expect(PieceColor.fromFenChar('b'), PieceColor.black);
    });

    test('fromFenChar returns null for invalid', () {
      expect(PieceColor.fromFenChar('x'), isNull);
    });

    test('opposite returns the other color', () {
      expect(PieceColor.white.opposite, PieceColor.black);
      expect(PieceColor.black.opposite, PieceColor.white);
    });

    test('fenChar returns correct character', () {
      expect(PieceColor.white.fenChar, 'w');
      expect(PieceColor.black.fenChar, 'b');
    });
  });

  group('Piece', () {
    test('constructor creates piece with correct properties', () {
      const piece = Piece(type: PieceType.king, color: PieceColor.white);
      expect(piece.type, PieceType.king);
      expect(piece.color, PieceColor.white);
      expect(piece.isWhite, isTrue);
      expect(piece.isBlack, isFalse);
    });

    group('fromFenChar', () {
      test('parses white pieces (uppercase)', () {
        final king = Piece.fromFenChar('K');
        expect(king, isNotNull);
        expect(king!.type, PieceType.king);
        expect(king.color, PieceColor.white);

        final queen = Piece.fromFenChar('Q');
        expect(queen!.type, PieceType.queen);
        expect(queen.color, PieceColor.white);
      });

      test('parses black pieces (lowercase)', () {
        final king = Piece.fromFenChar('k');
        expect(king, isNotNull);
        expect(king!.type, PieceType.king);
        expect(king.color, PieceColor.black);

        final pawn = Piece.fromFenChar('p');
        expect(pawn!.type, PieceType.pawn);
        expect(pawn.color, PieceColor.black);
      });

      test('returns null for invalid char', () {
        expect(Piece.fromFenChar('x'), isNull);
        expect(Piece.fromFenChar(''), isNull);
      });
    });

    group('fenChar', () {
      test('returns uppercase for white', () {
        const piece = Piece(type: PieceType.king, color: PieceColor.white);
        expect(piece.fenChar, 'K');
      });

      test('returns lowercase for black', () {
        const piece = Piece(type: PieceType.king, color: PieceColor.black);
        expect(piece.fenChar, 'k');
      });

      test('round-trips through fromFenChar', () {
        for (final type in PieceType.values) {
          for (final color in PieceColor.values) {
            final piece = Piece(type: type, color: color);
            final parsed = Piece.fromFenChar(piece.fenChar);
            expect(parsed, equals(piece));
          }
        }
      });
    });

    group('symbol', () {
      test('returns Unicode chess symbol', () {
        const whiteKing = Piece(type: PieceType.king, color: PieceColor.white);
        expect(whiteKing.symbol, '♔');

        const blackQueen = Piece(type: PieceType.queen, color: PieceColor.black);
        expect(blackQueen.symbol, '♛');
      });
    });

    group('equality', () {
      test('same type and color are equal', () {
        const p1 = Piece(type: PieceType.pawn, color: PieceColor.white);
        const p2 = Piece(type: PieceType.pawn, color: PieceColor.white);
        expect(p1, equals(p2));
      });

      test('different type or color are not equal', () {
        const p1 = Piece(type: PieceType.pawn, color: PieceColor.white);
        const p2 = Piece(type: PieceType.pawn, color: PieceColor.black);
        expect(p1, isNot(equals(p2)));
      });
    });
  });
}


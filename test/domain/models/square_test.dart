import 'package:flutter_test/flutter_test.dart';
import 'package:btchess/domain/models/square.dart';

void main() {
  group('Square', () {
    group('constructor', () {
      test('creates square with valid file and rank', () {
        final square = Square(0, 0);
        expect(square.file, 0);
        expect(square.rank, 0);
      });

      test('throws for invalid file', () {
        expect(() => Square(-1, 0), throwsArgumentError);
        expect(() => Square(8, 0), throwsArgumentError);
      });

      test('throws for invalid rank', () {
        expect(() => Square(0, -1), throwsArgumentError);
        expect(() => Square(0, 8), throwsArgumentError);
      });
    });

    group('fromIndex', () {
      test('a1 = index 0', () {
        final square = Square.fromIndex(0);
        expect(square.file, 0);
        expect(square.rank, 0);
        expect(square.algebraic, 'a1');
      });

      test('h1 = index 7', () {
        final square = Square.fromIndex(7);
        expect(square.file, 7);
        expect(square.rank, 0);
        expect(square.algebraic, 'h1');
      });

      test('a2 = index 8', () {
        final square = Square.fromIndex(8);
        expect(square.file, 0);
        expect(square.rank, 1);
        expect(square.algebraic, 'a2');
      });

      test('e2 = index 12', () {
        final square = Square.fromIndex(12);
        expect(square.algebraic, 'e2');
      });

      test('e4 = index 28', () {
        final square = Square.fromIndex(28);
        expect(square.algebraic, 'e4');
      });

      test('h8 = index 63', () {
        final square = Square.fromIndex(63);
        expect(square.file, 7);
        expect(square.rank, 7);
        expect(square.algebraic, 'h8');
      });

      test('throws for negative index', () {
        expect(() => Square.fromIndex(-1), throwsArgumentError);
      });

      test('throws for index > 63', () {
        expect(() => Square.fromIndex(64), throwsArgumentError);
      });
    });

    group('fromAlgebraic', () {
      test('parses a1', () {
        final square = Square.fromAlgebraic('a1');
        expect(square.file, 0);
        expect(square.rank, 0);
        expect(square.index, 0);
      });

      test('parses h8', () {
        final square = Square.fromAlgebraic('h8');
        expect(square.file, 7);
        expect(square.rank, 7);
        expect(square.index, 63);
      });

      test('parses e4', () {
        final square = Square.fromAlgebraic('e4');
        expect(square.file, 4);
        expect(square.rank, 3);
        expect(square.index, 28);
      });

      test('throws for invalid notation', () {
        expect(() => Square.fromAlgebraic(''), throwsArgumentError);
        expect(() => Square.fromAlgebraic('a'), throwsArgumentError);
        expect(() => Square.fromAlgebraic('i1'), throwsArgumentError);
        expect(() => Square.fromAlgebraic('a9'), throwsArgumentError);
        expect(() => Square.fromAlgebraic('a0'), throwsArgumentError);
      });
    });

    group('tryFromAlgebraic', () {
      test('returns square for valid notation', () {
        final square = Square.tryFromAlgebraic('e4');
        expect(square, isNotNull);
        expect(square!.algebraic, 'e4');
      });

      test('returns null for invalid notation', () {
        expect(Square.tryFromAlgebraic('z9'), isNull);
        expect(Square.tryFromAlgebraic(''), isNull);
      });
    });

    group('properties', () {
      test('index round-trips with fromIndex', () {
        for (int i = 0; i < 64; i++) {
          final square = Square.fromIndex(i);
          expect(square.index, i);
        }
      });

      test('fileLetter is correct', () {
        expect(Square(0, 0).fileLetter, 'a');
        expect(Square(4, 0).fileLetter, 'e');
        expect(Square(7, 0).fileLetter, 'h');
      });

      test('rankNumber is correct', () {
        expect(Square(0, 0).rankNumber, '1');
        expect(Square(0, 3).rankNumber, '4');
        expect(Square(0, 7).rankNumber, '8');
      });

      test('isLight and isDark are correct', () {
        // a1 (0,0) -> dark
        expect(Square(0, 0).isDark, isTrue);
        expect(Square(0, 0).isLight, isFalse);
        // b1 (1,0) -> light
        expect(Square(1, 0).isLight, isTrue);
      });
    });

    group('offset', () {
      test('returns new square within bounds', () {
        final e4 = Square.fromAlgebraic('e4');
        final result = e4.offset(1, 1);
        expect(result, isNotNull);
        expect(result!.algebraic, 'f5');
      });

      test('returns null when out of bounds', () {
        final a1 = Square.fromAlgebraic('a1');
        expect(a1.offset(-1, 0), isNull);
        expect(a1.offset(0, -1), isNull);
      });
    });

    group('equality', () {
      test('same file and rank are equal', () {
        expect(Square(4, 3), equals(Square(4, 3)));
        expect(Square.fromIndex(28), equals(Square.fromAlgebraic('e4')));
      });

      test('different squares are not equal', () {
        expect(Square(0, 0), isNot(equals(Square(1, 0))));
      });
    });

    group('toString', () {
      test('returns algebraic notation', () {
        expect(Square.fromAlgebraic('e4').toString(), 'e4');
        expect(Square(0, 0).toString(), 'a1');
      });
    });
  });
}


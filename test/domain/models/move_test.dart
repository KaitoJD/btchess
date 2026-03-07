import 'package:flutter_test/flutter_test.dart';
import 'package:btchess/domain/models/move.dart';
import 'package:btchess/domain/models/square.dart';
import 'package:btchess/domain/models/piece.dart';
import 'package:btchess/domain/enums/promotion_piece.dart';

void main() {
  group('Move', () {
    group('constructor', () {
      test('creates move with required fields', () {
        final move = Move(
          from: Square.fromAlgebraic('e2'),
          to: Square.fromAlgebraic('e4'),
        );
        expect(move.from.algebraic, 'e2');
        expect(move.to.algebraic, 'e4');
        expect(move.promotion, isNull);
        expect(move.isCastling, isFalse);
        expect(move.isEnPassant, isFalse);
        expect(move.isCheck, isFalse);
        expect(move.isCheckmate, isFalse);
      });

      test('creates move with all optional fields', () {
        final move = Move(
          from: Square.fromAlgebraic('e7'),
          to: Square.fromAlgebraic('e8'),
          promotion: PromotionPiece.queen,
          san: 'e8=Q',
          movedPiece: const Piece(type: PieceType.pawn, color: PieceColor.white),
          isCastling: false,
          isCheck: true,
        );
        expect(move.isPromotion, isTrue);
        expect(move.san, 'e8=Q');
        expect(move.isCheck, isTrue);
      });
    });

    group('fromIndices', () {
      test('creates move from square indices', () {
        // e2=12, e4=28
        final move = Move.fromIndices(fromIndex: 12, toIndex: 28);
        expect(move.from.algebraic, 'e2');
        expect(move.to.algebraic, 'e4');
      });

      test('creates move with promotion', () {
        final move = Move.fromIndices(
          fromIndex: 52, // e7
          toIndex: 60,   // e8
          promotion: PromotionPiece.queen,
        );
        expect(move.isPromotion, isTrue);
        expect(move.promotion, PromotionPiece.queen);
      });
    });

    group('fromAlgebraic', () {
      test('creates move from algebraic notation', () {
        final move = Move.fromAlgebraic(from: 'e2', to: 'e4');
        expect(move.from.index, 12);
        expect(move.to.index, 28);
      });
    });

    group('uci', () {
      test('returns UCI notation without promotion', () {
        final move = Move.fromAlgebraic(from: 'e2', to: 'e4');
        expect(move.uci, 'e2e4');
      });

      test('returns UCI notation with promotion', () {
        final move = Move.fromAlgebraic(
          from: 'e7',
          to: 'e8',
          promotion: PromotionPiece.queen,
        );
        expect(move.uci, 'e7e8q');
      });

      test('returns UCI with knight promotion', () {
        final move = Move.fromAlgebraic(
          from: 'e7',
          to: 'e8',
          promotion: PromotionPiece.knight,
        );
        expect(move.uci, 'e7e8n');
      });
    });

    group('isPromotion', () {
      test('returns true when promotion set', () {
        final move = Move.fromAlgebraic(
          from: 'e7',
          to: 'e8',
          promotion: PromotionPiece.queen,
        );
        expect(move.isPromotion, isTrue);
      });

      test('returns false when no promotion', () {
        final move = Move.fromAlgebraic(from: 'e2', to: 'e4');
        expect(move.isPromotion, isFalse);
      });
    });

    group('isCapture', () {
      test('returns true when captured piece exists', () {
        final move = Move(
          from: Square.fromAlgebraic('e4'),
          to: Square.fromAlgebraic('d5'),
          capturedPiece: const Piece(type: PieceType.pawn, color: PieceColor.black),
        );
        expect(move.isCapture, isTrue);
      });

      test('returns false when no captured piece', () {
        final move = Move.fromAlgebraic(from: 'e2', to: 'e4');
        expect(move.isCapture, isFalse);
      });
    });

    group('copyWith', () {
      test('copies with new values', () {
        final original = Move.fromAlgebraic(from: 'e2', to: 'e4');
        final copy = original.copyWith(san: 'e4', isCheck: true);
        expect(copy.san, 'e4');
        expect(copy.isCheck, isTrue);
        expect(copy.from, original.from);
        expect(copy.to, original.to);
      });
    });

    group('equality', () {
      test('moves with same from/to/promotion are equal', () {
        final m1 = Move.fromAlgebraic(from: 'e2', to: 'e4');
        final m2 = Move.fromAlgebraic(from: 'e2', to: 'e4');
        expect(m1, equals(m2));
      });

      test('moves with different squares are not equal', () {
        final m1 = Move.fromAlgebraic(from: 'e2', to: 'e4');
        final m2 = Move.fromAlgebraic(from: 'e2', to: 'e3');
        expect(m1, isNot(equals(m2)));
      });
    });

    group('toString', () {
      test('returns SAN if available', () {
        final move = Move(
          from: Square.fromAlgebraic('e2'),
          to: Square.fromAlgebraic('e4'),
          san: 'e4',
        );
        expect(move.toString(), 'e4');
      });

      test('returns UCI if no SAN', () {
        final move = Move.fromAlgebraic(from: 'e2', to: 'e4');
        expect(move.toString(), 'e2e4');
      });
    });
  });
}


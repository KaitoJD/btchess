import 'package:flutter_test/flutter_test.dart';
import 'package:btchess/domain/services/pgn_service.dart';
import 'package:btchess/domain/models/move.dart';
import 'package:btchess/domain/models/game_result.dart';
import 'package:btchess/domain/enums/winner.dart';
import '../../fixtures/pgn_fixtures.dart';

void main() {
  const service = PgnService();

  group('PgnService', () {
    group('generateMovetextFromSan', () {
      test('numbers moves correctly', () {
        final movetext = service.generateMovetextFromSan(PgnFixtures.sampleSanMoves);
        expect(movetext, contains('1. e4 e5'));
        expect(movetext, contains('2. Nf3 Nc6'));
        expect(movetext, contains('3. Bb5 a6'));
      });

      test('handles empty move list', () {
        final movetext = service.generateMovetextFromSan([]);
        expect(movetext, isEmpty);
      });

      test('handles odd number of moves', () {
        final movetext = service.generateMovetextFromSan(['e4', 'e5', 'Nf3']);
        expect(movetext, contains('1. e4 e5'));
        expect(movetext, contains('2. Nf3'));
      });
    });

    group('generate', () {
      test('generates PGN with headers and moves', () {
        final moves = [
          Move.fromAlgebraic(from: 'e2', to: 'e4').copyWith(san: 'e4'),
          Move.fromAlgebraic(from: 'e7', to: 'e5').copyWith(san: 'e5'),
        ];
        final pgn = service.generate(
          moves: moves,
          headers: PgnHeaders.newGame(whiteName: 'Alice', blackName: 'Bob'),
        );
        expect(pgn, contains('[White "Alice"]'));
        expect(pgn, contains('[Black "Bob"]'));
        expect(pgn, contains('1. e4 e5'));
      });

      test('includes result when provided', () {
        final moves = [
          Move.fromAlgebraic(from: 'e2', to: 'e4').copyWith(san: 'e4'),
        ];
        final pgn = service.generate(
          moves: moves,
          result: GameResult.checkmate(Winner.white),
        );
        expect(pgn, contains('1-0'));
      });
    });

    group('parse', () {
      test('parses scholar\'s mate PGN', () {
        final parsed = service.parse(PgnFixtures.scholarsMate);
        expect(parsed.headers.white, 'Player 1');
        expect(parsed.headers.black, 'Player 2');
        expect(parsed.headers.result, '1-0');
        expect(parsed.moves, isNotEmpty);
      });

      test('parses in-progress game', () {
        final parsed = service.parse(PgnFixtures.inProgressGame);
        expect(parsed.headers.white, 'Alice');
        expect(parsed.headers.black, 'Bob');
        expect(parsed.result, '*');
      });

      test('parses draw result', () {
        final parsed = service.parse(PgnFixtures.drawByAgreement);
        expect(parsed.headers.result, '1/2-1/2');
      });
    });

    group('extractMoves', () {
      test('extracts moves from PGN', () {
        final moves = service.extractMoves(PgnFixtures.scholarsMate);
        expect(moves, isNotEmpty);
        expect(moves.first, 'e4');
      });
    });

    group('getResultString', () {
      test('returns 1-0 for white win', () {
        final result = service.getResultString(
          GameResult.checkmate(Winner.white),
        );
        expect(result, '1-0');
      });

      test('returns 0-1 for black win', () {
        final result = service.getResultString(
          GameResult.checkmate(Winner.black),
        );
        expect(result, '0-1');
      });

      test('returns 1/2-1/2 for draw', () {
        final result = service.getResultString(GameResult.drawByAgreement());
        expect(result, '1/2-1/2');
      });

      test('returns * for null result', () {
        final result = service.getResultString(null);
        expect(result, '*');
      });
    });

    group('getResultStringFromWinner', () {
      test('maps winners correctly', () {
        expect(service.getResultStringFromWinner(Winner.white), '1-0');
        expect(service.getResultStringFromWinner(Winner.black), '0-1');
        expect(service.getResultStringFromWinner(Winner.draw), '1/2-1/2');
        expect(service.getResultStringFromWinner(null), '*');
      });
    });

    group('parseResult', () {
      test('parses result strings', () {
        expect(service.parseResult('1-0'), Winner.white);
        expect(service.parseResult('0-1'), Winner.black);
        expect(service.parseResult('1/2-1/2'), Winner.draw);
        expect(service.parseResult('*'), isNull);
      });
    });

    group('isValid', () {
      test('returns true for valid PGN', () {
        expect(service.isValid(PgnFixtures.scholarsMate), isTrue);
      });

      test('returns true for minimal PGN', () {
        expect(service.isValid(PgnFixtures.minimal), isTrue);
      });
    });

    group('PgnHeaders', () {
      test('newGame factory creates headers', () {
        final headers = PgnHeaders.newGame(
          whiteName: 'Alice',
          blackName: 'Bob',
        );
        expect(headers.white, 'Alice');
        expect(headers.black, 'Bob');
        expect(headers.event, isNotNull);
      });

      test('withResult creates copy with result', () {
        final headers = PgnHeaders.newGame();
        final withResult = headers.withResult('1-0');
        expect(withResult.result, '1-0');
      });

      test('format generates bracket notation', () {
        const headers = PgnHeaders(white: 'Alice', black: 'Bob');
        final formatted = headers.format();
        expect(formatted, contains('[White "Alice"]'));
        expect(formatted, contains('[Black "Bob"]'));
      });
    });
  });
}


import 'package:flutter_test/flutter_test.dart';
import 'package:btchess/domain/models/game_state.dart';
import 'package:btchess/domain/models/game_mode.dart';
import 'package:btchess/domain/models/game_result.dart';
import 'package:btchess/domain/models/move.dart';
import 'package:btchess/domain/models/player.dart';
import 'package:btchess/domain/models/piece.dart';
import 'package:btchess/domain/enums/game_status.dart';
import 'package:btchess/domain/enums/winner.dart';
import 'package:btchess/core/constants/app_constants.dart';
import '../../fixtures/fen_fixtures.dart';

void main() {
  group('GameState', () {
    group('newGame factory', () {
      test('creates game with starting FEN', () {
        final state = GameState.newGame(
          id: 'test-1',
          mode: GameMode.hotseat,
        );
        expect(state.fen, AppConstants.standardStartFen);
        expect(state.id, 'test-1');
        expect(state.mode, GameMode.hotseat);
        expect(state.status, GameStatus.playing);
        expect(state.currentTurn, PieceColor.white);
        expect(state.moves, isEmpty);
        expect(state.result, isNull);
      });

      test('creates game with default players', () {
        final state = GameState.newGame(id: 'test-1', mode: GameMode.hotseat);
        expect(state.whitePlayer.name, 'White');
        expect(state.blackPlayer.name, 'Black');
      });

      test('creates game with custom players', () {
        final state = GameState.newGame(
          id: 'test-1',
          mode: GameMode.hotseat,
          whitePlayer: Player.local(name: 'Alice', color: PieceColor.white),
          blackPlayer: Player.local(name: 'Bob', color: PieceColor.black),
        );
        expect(state.whitePlayer.name, 'Alice');
        expect(state.blackPlayer.name, 'Bob');
      });
    });

    group('fromFen factory', () {
      test('creates game from FEN with white to move', () {
        final state = GameState.fromFen(
          id: 'test-1',
          fen: FenFixtures.startingPosition,
          mode: GameMode.hotseat,
        );
        expect(state.currentTurn, PieceColor.white);
        expect(state.fen, FenFixtures.startingPosition);
      });

      test('creates game from FEN with black to move', () {
        final state = GameState.fromFen(
          id: 'test-1',
          fen: FenFixtures.blackToMove,
          mode: GameMode.hotseat,
        );
        expect(state.currentTurn, PieceColor.black);
      });
    });

    group('computed properties', () {
      test('moveCount returns number of moves', () {
        final state = GameState.newGame(id: 'test-1', mode: GameMode.hotseat);
        expect(state.moveCount, 0);
      });

      test('isInProgress is true for playing and check', () {
        final playing = GameState.newGame(id: 't', mode: GameMode.hotseat);
        expect(playing.isInProgress, isTrue);

        final check = playing.copyWith(status: GameStatus.check);
        expect(check.isInProgress, isTrue);
      });

      test('isEnded is true when result is set', () {
        final state = GameState.newGame(id: 't', mode: GameMode.hotseat);
        expect(state.isEnded, isFalse);

        final ended = state.copyWith(
          result: GameResult.checkmate(Winner.white),
          status: GameStatus.checkmate,
        );
        expect(ended.isEnded, isTrue);
      });

      test('isWhiteTurn and isBlackTurn work correctly', () {
        final state = GameState.newGame(id: 't', mode: GameMode.hotseat);
        expect(state.isWhiteTurn, isTrue);
        expect(state.isBlackTurn, isFalse);

        final blackTurn = state.copyWith(currentTurn: PieceColor.black);
        expect(blackTurn.isWhiteTurn, isFalse);
        expect(blackTurn.isBlackTurn, isTrue);
      });

      test('currentPlayer returns white player on white turn', () {
        final state = GameState.newGame(id: 't', mode: GameMode.hotseat);
        expect(state.currentPlayer, state.whitePlayer);
        expect(state.waitingPlayer, state.blackPlayer);
      });

      test('lastMove returns null when no moves', () {
        final state = GameState.newGame(id: 't', mode: GameMode.hotseat);
        expect(state.lastMove, isNull);
      });

      test('lastMove returns last move', () {
        final move = Move.fromAlgebraic(from: 'e2', to: 'e4');
        final state = GameState.newGame(id: 't', mode: GameMode.hotseat)
            .copyWith(moves: [move]);
        expect(state.lastMove, move);
      });

      test('isCheck, isCheckmate, isStalemate reflect status', () {
        final state = GameState.newGame(id: 't', mode: GameMode.hotseat);

        expect(state.copyWith(status: GameStatus.check).isCheck, isTrue);
        expect(state.copyWith(status: GameStatus.checkmate).isCheckmate, isTrue);
        expect(state.copyWith(status: GameStatus.stalemate).isStalemate, isTrue);
      });

      test('isDraw returns true for draw result', () {
        final state = GameState.newGame(id: 't', mode: GameMode.hotseat)
            .copyWith(result: GameResult.drawByAgreement());
        expect(state.isDraw, isTrue);
      });

      test('halfMoveClock and fullMoveNumber parse from FEN', () {
        final state = GameState.fromFen(
          id: 't',
          fen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1',
          mode: GameMode.hotseat,
        );
        expect(state.halfMoveClock, 0);
        expect(state.fullMoveNumber, 1);
      });
    });

    group('copyWith', () {
      test('creates copy with changed fields', () {
        final state = GameState.newGame(id: 't', mode: GameMode.hotseat);
        final copy = state.copyWith(status: GameStatus.check);
        expect(copy.status, GameStatus.check);
        expect(copy.id, state.id);
        expect(copy.fen, state.fen);
      });

      test('original is unchanged after copyWith', () {
        final state = GameState.newGame(id: 't', mode: GameMode.hotseat);
        state.copyWith(status: GameStatus.check);
        expect(state.status, GameStatus.playing);
      });
    });

    group('clearDrawOffer', () {
      test('clears draw offered flag', () {
        final state = GameState.newGame(id: 't', mode: GameMode.hotseat)
            .copyWith(drawOffered: true, drawOfferedBy: PieceColor.white);
        final cleared = state.clearDrawOffer();
        expect(cleared.drawOffered, isFalse);
      });
    });

    group('equality', () {
      test('same state is equal', () {
        final now = DateTime(2026, 1, 1);
        final s1 = GameState(
          id: 't',
          fen: FenFixtures.startingPosition,
          moves: const [],
          currentTurn: PieceColor.white,
          status: GameStatus.playing,
          mode: GameMode.hotseat,
          whitePlayer: Player.white(),
          blackPlayer: Player.black(),
          createdAt: now,
          updatedAt: now,
        );
        final s2 = GameState(
          id: 't',
          fen: FenFixtures.startingPosition,
          moves: const [],
          currentTurn: PieceColor.white,
          status: GameStatus.playing,
          mode: GameMode.hotseat,
          whitePlayer: Player.white(),
          blackPlayer: Player.black(),
          createdAt: now,
          updatedAt: now,
        );
        expect(s1, equals(s2));
      });
    });
  });
}


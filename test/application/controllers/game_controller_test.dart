import 'package:flutter_test/flutter_test.dart';
import 'package:btchess/application/controllers/game_controller.dart';
import 'package:btchess/domain/services/chess_service.dart';
import 'package:btchess/domain/models/game_mode.dart';
import 'package:btchess/domain/models/square.dart';
import 'package:btchess/domain/models/piece.dart';
import 'package:btchess/domain/models/move.dart';
import 'package:btchess/domain/enums/game_status.dart';
import 'package:btchess/domain/enums/promotion_piece.dart';
import 'package:btchess/domain/enums/winner.dart';
import '../../fixtures/fen_fixtures.dart';

void main() {
  late GameController controller;

  setUp(() {
    controller = GameController(chessService: const ChessService());
  });

  group('GameController', () {
    group('newGame', () {
      test('creates a new hotseat game', () {
        controller.newGame(mode: GameMode.hotseat);
        expect(controller.hasActiveGame, isTrue);
        expect(controller.isGameInProgress, isTrue);
        expect(controller.state, isNotNull);
        expect(controller.state!.mode, GameMode.hotseat);
        expect(controller.state!.fen, FenFixtures.startingPosition);
        expect(controller.state!.currentTurn, PieceColor.white);
      });

      test('creates BLE host game with correct player setup', () {
        controller.newGame(
          mode: GameMode.bleHost,
          localPlayerColor: PieceColor.white,
        );
        expect(controller.state!.whitePlayer.isLocal, isTrue);
        expect(controller.state!.blackPlayer.isLocal, isFalse);
      });

      test('creates BLE client game', () {
        controller.newGame(
          mode: GameMode.bleClient,
          localPlayerColor: PieceColor.black,
        );
        expect(controller.state!.blackPlayer.isLocal, isTrue);
        expect(controller.state!.whitePlayer.isLocal, isFalse);
      });
    });

    group('makeMove', () {
      test('makes a legal move and updates state', () {
        controller.newGame(mode: GameMode.hotseat);
        final result = controller.makeMove(
          from: Square.fromAlgebraic('e2'),
          to: Square.fromAlgebraic('e4'),
        );
        expect(result, isTrue);
        expect(controller.state!.moves.length, 1);
        expect(controller.state!.currentTurn, PieceColor.black);
      });

      test('rejects illegal move', () {
        controller.newGame(mode: GameMode.hotseat);
        final result = controller.makeMove(
          from: Square.fromAlgebraic('e2'),
          to: Square.fromAlgebraic('e5'),
        );
        expect(result, isFalse);
        expect(controller.state!.moves.length, 0);
      });

      test('returns false when no active game', () {
        final result = controller.makeMove(
          from: Square.fromAlgebraic('e2'),
          to: Square.fromAlgebraic('e4'),
        );
        expect(result, isFalse);
      });

      test('requires promotion for pawn reaching last rank', () {
        controller.newGame(mode: GameMode.hotseat);
        controller.loadFromFen(
          fen: FenFixtures.promotionReady,
          mode: GameMode.hotseat,
        );
        // Without promotion should fail
        final result = controller.makeMove(
          from: Square.fromAlgebraic('e7'),
          to: Square.fromAlgebraic('e8'),
        );
        expect(result, isFalse);

        // With promotion should succeed
        final result2 = controller.makeMove(
          from: Square.fromAlgebraic('e7'),
          to: Square.fromAlgebraic('e8'),
          promotion: PromotionPiece.queen,
        );
        expect(result2, isTrue);
      });

      test('detects checkmate', () {
        controller.newGame(mode: GameMode.hotseat);
        // Play fool's mate: 1. f3 e5 2. g4 Qh4#
        controller.makeMove(from: Square.fromAlgebraic('f2'), to: Square.fromAlgebraic('f3'));
        controller.makeMove(from: Square.fromAlgebraic('e7'), to: Square.fromAlgebraic('e5'));
        controller.makeMove(from: Square.fromAlgebraic('g2'), to: Square.fromAlgebraic('g4'));
        controller.makeMove(from: Square.fromAlgebraic('d8'), to: Square.fromAlgebraic('h4'));

        expect(controller.state!.status, GameStatus.checkmate);
        expect(controller.state!.result, isNotNull);
        expect(controller.state!.result!.winner, Winner.black);
        expect(controller.isGameEnded, isTrue);
      });
    });

    group('undoMove', () {
      test('undoes last move in hotseat', () {
        controller.newGame(mode: GameMode.hotseat);
        controller.makeMove(
          from: Square.fromAlgebraic('e2'),
          to: Square.fromAlgebraic('e4'),
        );
        expect(controller.state!.moves.length, 1);

        final result = controller.undoMove();
        expect(result, isTrue);
        expect(controller.state!.moves.length, 0);
        expect(controller.state!.currentTurn, PieceColor.white);
      });

      test('fails to undo in BLE mode', () {
        controller.newGame(mode: GameMode.bleHost);
        controller.makeMove(
          from: Square.fromAlgebraic('e2'),
          to: Square.fromAlgebraic('e4'),
        );
        expect(controller.undoMove(), isFalse);
      });

      test('fails to undo with no moves', () {
        controller.newGame(mode: GameMode.hotseat);
        expect(controller.undoMove(), isFalse);
      });

      test('fails to undo after game ended', () {
        controller.newGame(mode: GameMode.hotseat);
        controller.resign(PieceColor.white);
        expect(controller.undoMove(), isFalse);
      });
    });

    group('resign', () {
      test('white resignation gives black the win', () {
        controller.newGame(mode: GameMode.hotseat);
        controller.resign(PieceColor.white);
        expect(controller.state!.status, GameStatus.resigned);
        expect(controller.state!.result!.winner, Winner.black);
      });

      test('black resignation gives white the win', () {
        controller.newGame(mode: GameMode.hotseat);
        controller.resign(PieceColor.black);
        expect(controller.state!.result!.winner, Winner.white);
      });

      test('resign does nothing when game already ended', () {
        controller.newGame(mode: GameMode.hotseat);
        controller.resign(PieceColor.white);
        final result = controller.state!.result;
        controller.resign(PieceColor.black); // should not change
        expect(controller.state!.result, result);
      });
    });

    group('draw offer flow', () {
      test('offerDraw sets draw offered', () {
        controller.newGame(mode: GameMode.hotseat);
        controller.offerDraw(PieceColor.white);
        expect(controller.state!.drawOffered, isTrue);
        expect(controller.state!.drawOfferedBy, PieceColor.white);
      });

      test('acceptDraw ends game as draw', () {
        controller.newGame(mode: GameMode.hotseat);
        controller.offerDraw(PieceColor.white);
        controller.acceptDraw();
        expect(controller.state!.status, GameStatus.draw);
        expect(controller.state!.result!.isDraw, isTrue);
      });

      test('rejectDraw clears the offer', () {
        controller.newGame(mode: GameMode.hotseat);
        controller.offerDraw(PieceColor.white);
        controller.rejectDraw();
        expect(controller.state!.drawOffered, isFalse);
      });

      test('cannot offer draw when already offered', () {
        controller.newGame(mode: GameMode.hotseat);
        controller.offerDraw(PieceColor.white);
        controller.offerDraw(PieceColor.black);
        // Should still be white's offer
        expect(controller.state!.drawOfferedBy, PieceColor.white);
      });
    });

    group('loadFromFen', () {
      test('loads valid FEN', () {
        controller.loadFromFen(
          fen: FenFixtures.midGame,
          mode: GameMode.hotseat,
        );
        expect(controller.state, isNotNull);
        expect(controller.state!.fen, FenFixtures.midGame);
      });

      test('throws for invalid FEN', () {
        expect(
          () => controller.loadFromFen(
            fen: FenFixtures.invalidEmpty,
            mode: GameMode.hotseat,
          ),
          throwsArgumentError,
        );
      });
    });

    group('resetGame', () {
      test('resets to starting position', () {
        controller.newGame(mode: GameMode.hotseat);
        controller.makeMove(
          from: Square.fromAlgebraic('e2'),
          to: Square.fromAlgebraic('e4'),
        );
        controller.resetGame();
        expect(controller.state!.fen, FenFixtures.startingPosition);
        expect(controller.state!.moves, isEmpty);
      });
    });

    group('endSession', () {
      test('clears state', () {
        controller.newGame(mode: GameMode.hotseat);
        controller.endSession();
        expect(controller.hasActiveGame, isFalse);
        expect(controller.state, isNull);
      });
    });

    group('getLegalMoves', () {
      test('returns legal moves for piece', () {
        controller.newGame(mode: GameMode.hotseat);
        final moves = controller.getLegalMoves(Square.fromAlgebraic('e2'));
        expect(moves.length, 2);
      });

      test('returns empty when no game', () {
        expect(controller.getLegalMoves(Square.fromAlgebraic('e2')), isEmpty);
      });
    });

    group('syncState', () {
      test('syncs state from FEN and moves', () {
        controller.newGame(mode: GameMode.bleClient);
        controller.syncState(
          fen: FenFixtures.afterE4E5,
          moves: [
            Move.fromAlgebraic(from: 'e2', to: 'e4'),
            Move.fromAlgebraic(from: 'e7', to: 'e5'),
          ],
        );
        expect(controller.state!.fen, FenFixtures.afterE4E5);
        expect(controller.state!.moves.length, 2);
      });
    });

    group('applyRemoteMove', () {
      test('applies a remote move', () {
        controller.newGame(mode: GameMode.bleHost);
        final move = Move.fromAlgebraic(from: 'e2', to: 'e4');
        final result = controller.applyRemoteMove(move);
        expect(result, isTrue);
        expect(controller.state!.moves.length, 1);
      });
    });

    group('helper methods', () {
      test('getPieceAt returns piece', () {
        controller.newGame(mode: GameMode.hotseat);
        final piece = controller.getPieceAt(Square.fromAlgebraic('e1'));
        expect(piece, isNotNull);
        expect(piece!.type, PieceType.king);
      });

      test('canMove checks turn', () {
        controller.newGame(mode: GameMode.hotseat);
        expect(controller.canMove(PieceColor.white), isTrue);
        expect(controller.canMove(PieceColor.black), isFalse);
      });

      test('isLocalPlayerTurn is true in hotseat', () {
        controller.newGame(mode: GameMode.hotseat);
        expect(controller.isLocalPlayerTurn(), isTrue);
      });
    });
  });
}


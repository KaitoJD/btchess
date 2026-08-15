import 'dart:async';

import 'package:btchess/application/providers/game_provider.dart';
import 'package:btchess/application/providers/persistence_provider.dart';
import 'package:btchess/domain/enums/winner.dart';
import 'package:btchess/domain/models/game_mode.dart';
import 'package:btchess/domain/models/game_state.dart';
import 'package:btchess/domain/models/saved_game.dart';
import 'package:btchess/domain/models/square.dart';
import 'package:btchess/infrastructure/persistence/game_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'refreshes in-progress history when a resumed game is completed',
    () async {
      final repository = _InMemoryGameRepository();
      final resumedGame = GameState.newGame(
        id: 'resumed-game',
        mode: GameMode.hotseat,
      );
      await repository.saveGame(resumedGame);

      final container = ProviderContainer(
        overrides: [
          gameRepositoryProvider.overrideWithValue(repository),
          gameRepositoryInitProvider.overrideWith((ref) async {}),
        ],
      );
      addTearDown(container.dispose);

      final initialInProgress = await container.read(
        inProgressGamesProvider.future,
      );
      expect(initialInProgress, hasLength(1));
      expect(initialInProgress.single.id, 'resumed-game');

      final controller = container.read(gameControllerProvider.notifier);
      controller.loadGame(resumedGame);

      // Fool's mate: 1. f3 e5 2. g4 Qh4#
      controller.makeMove(
        from: Square.fromAlgebraic('f2'),
        to: Square.fromAlgebraic('f3'),
      );
      controller.makeMove(
        from: Square.fromAlgebraic('e7'),
        to: Square.fromAlgebraic('e5'),
      );
      controller.makeMove(
        from: Square.fromAlgebraic('g2'),
        to: Square.fromAlgebraic('g4'),
      );
      controller.makeMove(
        from: Square.fromAlgebraic('d8'),
        to: Square.fromAlgebraic('h4'),
      );

      await repository.completedGameSaved.future;
      await Future<void>.delayed(Duration.zero);

      final inProgress = await container.read(inProgressGamesProvider.future);
      final completed = await container.read(completedGamesProvider.future);

      expect(inProgress, isEmpty);
      expect(completed, hasLength(1));
      expect(completed.single.id, 'resumed-game');
      expect(completed.single.moves, hasLength(4));
      expect(completed.single.result!.winner, Winner.black);
    },
  );
}

class _InMemoryGameRepository extends GameRepository {
  final _games = <String, GameState>{};
  final completedGameSaved = Completer<void>();

  @override
  Future<void> init() async {}

  @override
  Future<void> saveGame(GameState gameState) async {
    _games[gameState.id] = gameState;
    if (gameState.isEnded && !completedGameSaved.isCompleted) {
      completedGameSaved.complete();
    }
  }

  @override
  Future<List<SavedGame>> getInProgressGames() async {
    return _games.values
        .where((gameState) => gameState.isInProgress)
        .map(_toSavedGame)
        .toList();
  }

  @override
  Future<List<SavedGame>> getCompletedGames() async {
    return _games.values
        .where((gameState) => gameState.isEnded)
        .map(_toSavedGame)
        .toList();
  }

  SavedGame _toSavedGame(GameState gameState) {
    return SavedGame.fromDomain(
      id: gameState.id,
      fen: gameState.fen,
      moves: gameState.moves.map((move) => move.san ?? move.uci).toList(),
      createdAt: gameState.createdAt,
      updatedAt: gameState.updatedAt,
      mode: gameState.mode,
      result: gameState.result,
      uciMoves: gameState.moves.map((move) => move.uci).toList(),
    );
  }
}

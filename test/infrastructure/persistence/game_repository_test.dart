import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:btchess/domain/models/saved_game.dart';
import 'package:btchess/domain/models/game_mode.dart';
import 'package:btchess/domain/models/game_state.dart';
import 'package:btchess/domain/models/game_result.dart';
import 'package:btchess/domain/enums/game_end_reason.dart';
import 'package:btchess/domain/enums/winner.dart';
import 'package:btchess/infrastructure/persistence/game_repository.dart';
import '../../fixtures/fen_fixtures.dart';

void main() {
  late GameRepository repository;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('btchess_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(SavedGameAdapter().typeId)) {
      Hive.registerAdapter(SavedGameAdapter());
    }
    repository = GameRepository();
    await repository.init();
  });

  tearDown(() async {
    await repository.close();
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('GameRepository', () {
    group('saveGame and getGame', () {
      test('saves and retrieves a game', () async {
        final gameState = GameState.newGame(
          id: 'test-1',
          mode: GameMode.hotseat,
        );

        await repository.saveGame(gameState);
        final saved = await repository.getGame('test-1');

        expect(saved, isNotNull);
        expect(saved!.id, 'test-1');
        expect(saved.fen, FenFixtures.startingPosition);
        expect(saved.mode, GameMode.hotseat);
        expect(saved.isInProgress, isTrue);
      });

      test('returns null for non-existent game', () async {
        final saved = await repository.getGame('non-existent');
        expect(saved, isNull);
      });

      test('saves completed game with result', () async {
        final result = GameResult.checkmate(Winner.white, finalFen: FenFixtures.scholarsMate);
        final gameState = GameState.newGame(
          id: 'test-2',
          mode: GameMode.hotseat,
        ).copyWith(
          fen: FenFixtures.scholarsMate,
          result: result,
        );

        await repository.saveGame(gameState);
        final saved = await repository.getGame('test-2');

        expect(saved, isNotNull);
        expect(saved!.isCompleted, isTrue);
        expect(saved.result, isNotNull);
        expect(saved.result!.winner, Winner.white);
        expect(saved.result!.reason, GameEndReason.checkmate);
      });
    });

    group('getAllGames', () {
      test('returns all games sorted by updatedAt', () async {
        final state1 = GameState.newGame(id: 'game-1', mode: GameMode.hotseat);
        await repository.saveGame(state1);

        await Future.delayed(const Duration(milliseconds: 10));

        final state2 = GameState.newGame(id: 'game-2', mode: GameMode.hotseat);
        await repository.saveGame(state2);

        final games = await repository.getAllGames();
        expect(games.length, 2);
        // Most recent first
        expect(games.first.id, 'game-2');
        expect(games.last.id, 'game-1');
      });

      test('returns empty list when no games', () async {
        final games = await repository.getAllGames();
        expect(games, isEmpty);
      });
    });

    group('getInProgressGames', () {
      test('returns only in-progress games', () async {
        final inProgress = GameState.newGame(id: 'ip-1', mode: GameMode.hotseat);
        final completed = GameState.newGame(id: 'done-1', mode: GameMode.hotseat).copyWith(
          result: GameResult.checkmate(Winner.white),
        );

        await repository.saveGame(inProgress);
        await repository.saveGame(completed);

        final games = await repository.getInProgressGames();
        expect(games.length, 1);
        expect(games.first.id, 'ip-1');
      });
    });

    group('getCompletedGames', () {
      test('returns only completed games', () async {
        final inProgress = GameState.newGame(id: 'ip-1', mode: GameMode.hotseat);
        final completed = GameState.newGame(id: 'done-1', mode: GameMode.hotseat).copyWith(
          result: GameResult.checkmate(Winner.white),
        );

        await repository.saveGame(inProgress);
        await repository.saveGame(completed);

        final games = await repository.getCompletedGames();
        expect(games.length, 1);
        expect(games.first.id, 'done-1');
      });
    });

    group('getMostRecentGame', () {
      test('returns most recent in-progress game', () async {
        final state1 = GameState.newGame(id: 'older', mode: GameMode.hotseat);
        await repository.saveGame(state1);

        await Future.delayed(const Duration(milliseconds: 10));

        final state2 = GameState.newGame(id: 'newer', mode: GameMode.hotseat);
        await repository.saveGame(state2);

        final recent = await repository.getMostRecentGame();
        expect(recent, isNotNull);
        expect(recent!.id, 'newer');
      });

      test('returns null when no in-progress games', () async {
        final completed = GameState.newGame(id: 'done', mode: GameMode.hotseat).copyWith(
          result: GameResult.stalemate(),
        );
        await repository.saveGame(completed);

        final recent = await repository.getMostRecentGame();
        expect(recent, isNull);
      });
    });

    group('deleteGame', () {
      test('deletes a game', () async {
        final state = GameState.newGame(id: 'del-1', mode: GameMode.hotseat);
        await repository.saveGame(state);

        await repository.deleteGame('del-1');
        final saved = await repository.getGame('del-1');
        expect(saved, isNull);
      });
    });

    group('deleteAllGames', () {
      test('clears all games', () async {
        await repository.saveGame(
          GameState.newGame(id: 'g1', mode: GameMode.hotseat),
        );
        await repository.saveGame(
          GameState.newGame(id: 'g2', mode: GameMode.hotseat),
        );

        await repository.deleteAllGames();

        final count = await repository.getGameCount();
        expect(count, 0);
      });
    });

    group('getGameCount', () {
      test('returns correct count', () async {
        expect(await repository.getGameCount(), 0);

        await repository.saveGame(
          GameState.newGame(id: 'c1', mode: GameMode.hotseat),
        );
        expect(await repository.getGameCount(), 1);

        await repository.saveGame(
          GameState.newGame(id: 'c2', mode: GameMode.hotseat),
        );
        expect(await repository.getGameCount(), 2);
      });
    });

    group('savedGameToState', () {
      test('converts SavedGame back to GameState', () async {
        final original = GameState.newGame(id: 'convert-1', mode: GameMode.hotseat);
        await repository.saveGame(original);

        final saved = await repository.getGame('convert-1');
        final restored = repository.savedGameToState(saved!);

        expect(restored.id, 'convert-1');
        expect(restored.fen, FenFixtures.startingPosition);
        expect(restored.mode, GameMode.hotseat);
      });
    });

    group('update existing game', () {
      test('overwriting a game ID updates it', () async {
        final state1 = GameState.newGame(id: 'upd-1', mode: GameMode.hotseat);
        await repository.saveGame(state1);

        final updated = state1.copyWith(
          fen: FenFixtures.afterE4,
        );
        await repository.saveGame(updated);

        final saved = await repository.getGame('upd-1');
        expect(saved!.fen, FenFixtures.afterE4);

        // Count should still be 1
        expect(await repository.getGameCount(), 1);
      });
    });
  });
}


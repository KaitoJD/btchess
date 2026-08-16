import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:btchess/domain/models/saved_game.dart';
import 'package:btchess/domain/models/game_mode.dart';
import 'package:btchess/domain/models/game_state.dart';
import 'package:btchess/domain/models/game_result.dart';
import 'package:btchess/domain/models/square.dart';
import 'package:btchess/domain/services/chess_service.dart';
import 'package:btchess/domain/enums/game_status.dart';
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
        final result = GameResult.checkmate(
          Winner.white,
          finalFen: FenFixtures.scholarsMate,
        );
        final gameState = GameState.newGame(
          id: 'test-2',
          mode: GameMode.hotseat,
        ).copyWith(fen: FenFixtures.scholarsMate, result: result);

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
        final inProgress = GameState.newGame(
          id: 'ip-1',
          mode: GameMode.hotseat,
        );
        final completed = GameState.newGame(
          id: 'done-1',
          mode: GameMode.hotseat,
        ).copyWith(result: GameResult.checkmate(Winner.white));

        await repository.saveGame(inProgress);
        await repository.saveGame(completed);

        final games = await repository.getInProgressGames();
        expect(games.length, 1);
        expect(games.first.id, 'ip-1');
      });
    });

    group('getCompletedGames', () {
      test('returns only completed games', () async {
        final inProgress = GameState.newGame(
          id: 'ip-1',
          mode: GameMode.hotseat,
        );
        final completed = GameState.newGame(
          id: 'done-1',
          mode: GameMode.hotseat,
        ).copyWith(result: GameResult.checkmate(Winner.white));

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
        final completed = GameState.newGame(
          id: 'done',
          mode: GameMode.hotseat,
        ).copyWith(result: GameResult.stalemate());
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

    group('deleteGames', () {
      test('deletes only the selected games', () async {
        await repository.saveGame(
          GameState.newGame(id: 'selected-1', mode: GameMode.hotseat),
        );
        await repository.saveGame(
          GameState.newGame(id: 'selected-2', mode: GameMode.hotseat),
        );
        await repository.saveGame(
          GameState.newGame(id: 'remaining', mode: GameMode.hotseat),
        );

        await repository.deleteGames(['selected-1', 'selected-2']);

        expect(await repository.getGame('selected-1'), isNull);
        expect(await repository.getGame('selected-2'), isNull);
        expect(await repository.getGame('remaining'), isNotNull);
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
        final original = GameState.newGame(
          id: 'convert-1',
          mode: GameMode.hotseat,
        );
        await repository.saveGame(original);

        final saved = await repository.getGame('convert-1');
        final restored = repository.savedGameToState(saved!);

        expect(restored.id, 'convert-1');
        expect(restored.fen, FenFixtures.startingPosition);
        expect(restored.mode, GameMode.hotseat);
      });

      test(
        'restores replayed move history and captured-piece metadata',
        () async {
          const chessService = ChessService();
          var gameState = GameState.newGame(
            id: 'restore-moves',
            mode: GameMode.hotseat,
          );

          for (final (from, to) in [('e2', 'e4'), ('d7', 'd5'), ('e4', 'd5')]) {
            final result = chessService.makeMove(
              gameState.fen,
              Square.fromAlgebraic(from),
              Square.fromAlgebraic(to),
            );
            gameState = gameState.copyWith(
              fen: result.fen,
              moves: [...gameState.moves, result.move!],
              currentTurn: chessService.getCurrentTurn(result.fen!),
              status: result.status,
            );
          }

          await repository.saveGame(gameState);
          final saved = await repository.getGame('restore-moves');
          final restored = repository.savedGameToState(saved!);

          expect(saved.uciMoves, ['e2e4', 'd7d5', 'e4d5']);
          expect(restored.fen, gameState.fen);
          expect(restored.moves.map((move) => move.uci), saved.uciMoves);
          expect(restored.moves.last.capturedPiece, isNotNull);
          expect(restored.moves.last.san, 'exd5');
        },
      );

      test('restores completed game status from result', () async {
        final gameState =
            GameState.newGame(
              id: 'restore-status',
              mode: GameMode.hotseat,
            ).copyWith(
              fen: FenFixtures.scholarsMate,
              result: GameResult.checkmate(
                Winner.white,
                finalFen: FenFixtures.scholarsMate,
              ),
            );

        await repository.saveGame(gameState);
        final saved = await repository.getGame('restore-status');
        final restored = repository.savedGameToState(saved!);

        expect(restored.result, isNotNull);
        expect(restored.status, GameStatus.checkmate);
      });
    });

    group('legacy Hive compatibility', () {
      test('reads saved games written before uciMoves existed', () async {
        await repository.close();
        await Hive.close();

        Hive.resetAdapters();
        Hive.init(tempDir.path);
        _registerDefaultHiveAdaptersForTest();
        Hive.registerAdapter<SavedGame>(_LegacySavedGameAdapter());
        final legacyBox = await Hive.openBox<SavedGame>('games');
        final legacySavedGame = SavedGame(
          id: 'legacy-without-uci',
          fen: FenFixtures.afterE4,
          moves: const ['e4'],
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
          modeIndex: GameMode.hotseat.index,
        );

        await legacyBox.put(legacySavedGame.id, legacySavedGame);
        await legacyBox.close();
        await Hive.close();

        Hive.resetAdapters();
        Hive.init(tempDir.path);
        _registerDefaultHiveAdaptersForTest();
        Hive.registerAdapter(SavedGameAdapter());

        repository = GameRepository();
        await repository.init();

        final savedGame = await repository.getGame(legacySavedGame.id);
        expect(savedGame, isNotNull);
        expect(savedGame!.uciMoves, isEmpty);

        expect(() => repository.savedGameToState(savedGame), returnsNormally);
      });
    });

    group('safe enum decoding', () {
      test('falls back to hotseat for invalid saved mode index', () {
        final savedGame = SavedGame(
          id: 'bad-mode',
          fen: FenFixtures.startingPosition,
          moves: const [],
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          modeIndex: 999,
        );

        expect(savedGame.mode, GameMode.hotseat);
      });

      test('ignores invalid saved result indexes', () {
        final savedGame = SavedGame(
          id: 'bad-result',
          fen: FenFixtures.startingPosition,
          moves: const [],
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          modeIndex: GameMode.hotseat.index,
          winnerIndex: 99,
          endReasonIndex: GameEndReason.checkmate.index,
        );

        expect(savedGame.result, isNull);
        expect(savedGame.isCompleted, isFalse);
      });
    });

    group('update existing game', () {
      test('overwriting a game ID updates it', () async {
        final state1 = GameState.newGame(id: 'upd-1', mode: GameMode.hotseat);
        await repository.saveGame(state1);

        final updated = state1.copyWith(fen: FenFixtures.afterE4);
        await repository.saveGame(updated);

        final saved = await repository.getGame('upd-1');
        expect(saved!.fen, FenFixtures.afterE4);

        // Count should still be 1
        expect(await repository.getGameCount(), 1);
      });
    });
  });
}

void _registerDefaultHiveAdaptersForTest() {
  // Hive.resetAdapters() also clears Hive's built-in DateTime/BigInt adapters.
  Hive
    ..registerAdapter<DateTime>(
      _DateTimeWithTimezoneAdapterForTest(),
      internal: true,
    )
    ..registerAdapter<_DateTimeWithoutTimezoneForTest>(
      _DateTimeAdapterForTest(),
      internal: true,
    )
    ..registerAdapter<BigInt>(_BigIntAdapterForTest(), internal: true);
}

class _LegacySavedGameAdapter extends TypeAdapter<SavedGame> {
  @override
  final int typeId = 0;

  @override
  SavedGame read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return SavedGame(
      id: fields[0] as String,
      fen: fields[1] as String,
      moves: (fields[2] as List).cast<String>(),
      createdAt: fields[3] as DateTime,
      updatedAt: fields[4] as DateTime,
      modeIndex: fields[5] as int,
      winnerIndex: fields[6] as int?,
      endReasonIndex: fields[7] as int?,
      opponentName: fields[8] as String?,
      pgn: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, SavedGame obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.fen)
      ..writeByte(2)
      ..write(obj.moves)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.updatedAt)
      ..writeByte(5)
      ..write(obj.modeIndex)
      ..writeByte(6)
      ..write(obj.winnerIndex)
      ..writeByte(7)
      ..write(obj.endReasonIndex)
      ..writeByte(8)
      ..write(obj.opponentName)
      ..writeByte(9)
      ..write(obj.pgn);
  }
}

class _DateTimeWithTimezoneAdapterForTest extends TypeAdapter<DateTime> {
  @override
  final int typeId = 18;

  @override
  DateTime read(BinaryReader reader) {
    final millis = reader.readInt();
    final isUtc = reader.readBool();

    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: isUtc);
  }

  @override
  void write(BinaryWriter writer, DateTime obj) {
    writer
      ..writeInt(obj.millisecondsSinceEpoch)
      ..writeBool(obj.isUtc);
  }
}

class _DateTimeWithoutTimezoneForTest extends DateTime {
  _DateTimeWithoutTimezoneForTest.fromMillisecondsSinceEpoch(
    super.millisecondsSinceEpoch,
  ) : super.fromMillisecondsSinceEpoch();
}

class _DateTimeAdapterForTest
    extends TypeAdapter<_DateTimeWithoutTimezoneForTest> {
  @override
  final int typeId = 16;

  @override
  _DateTimeWithoutTimezoneForTest read(BinaryReader reader) {
    final millis = reader.readInt();

    return _DateTimeWithoutTimezoneForTest.fromMillisecondsSinceEpoch(millis);
  }

  @override
  void write(BinaryWriter writer, _DateTimeWithoutTimezoneForTest obj) {
    writer.writeInt(obj.millisecondsSinceEpoch);
  }
}

class _BigIntAdapterForTest extends TypeAdapter<BigInt> {
  @override
  final int typeId = 17;

  @override
  BigInt read(BinaryReader reader) {
    final length = reader.readByte();
    final intString = reader.readString(length);

    return BigInt.parse(intString);
  }

  @override
  void write(BinaryWriter writer, BigInt obj) {
    final intString = obj.toString();
    writer
      ..writeByte(intString.length)
      ..writeString(intString, writeByteCount: false);
  }
}

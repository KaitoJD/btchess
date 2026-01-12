import 'package:hive/hive.dart';
import '../../domain/models/game_mode.dart';
import '../../domain/models/game_state.dart';
// import '../../domain/models/move.dart';
import '../../domain/models/saved_game.dart';
import '../../domain/services/pgn_service.dart';

class GameRepository {
  static const String _boxName = 'games';
  static const int _maxSavedGames = 100;
  final PgnService _pgnService;
  Box<SavedGame>? _box;

  GameRepository({PgnService? pgnService}) : _pgnService = pgnService ?? const PgnService();

  Future<void> init() async {
    if (_box != null && _box!.isOpen) return;

    _box = await Hive.openBox<SavedGame>(_boxName);
  }

  Future<Box<SavedGame>> _getBox() async {
    if (_box == null || !_box!.isOpen) await init();

    return _box!;
  }

  Future<void> saveGame(GameState gameState) async {
    final box = await _getBox();

    final sanMoves = gameState.moves.map((m) => m.san ?? m.uci).toList();

    String? pgn;

    if (gameState.isEnded) {
      pgn = _pgnService.generate(moves: gameState.moves, result: gameState.result);
    }

    final savedGame = SavedGame.fromDomain(
      id: gameState.id,
      fen: gameState.fen,
      moves: sanMoves,
      createdAt: gameState.createdAt,
      updatedAt: DateTime.now(),
      mode: gameState.mode,
      result: gameState.result,
      opponentName: _getOpponentName(gameState),
      pgn: pgn,
    );

    await box.put(gameState.id, savedGame);

    await _cleanupOldGames();
  }

  Future<SavedGame?> getGame(String id) async {
    final box = await _getBox();

    return box.get(id);
  }

  Future<List<SavedGame>> getAllGames() async {
    final box = await _getBox();
    final games = box.values.toList();

    games.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return games;
  }

  Future<List<SavedGame>> getInProgressGames() async {
    final games = await getAllGames();

    return games.where((g) => g.isInProgress).toList();
  }

  Future<List<SavedGame>> getCompletedGames() async {
    final games = await getAllGames();

    return games.where((g) => g.isCompleted).toList();
  }

  Future<SavedGame?> getMostRecentGame() async {
    final games = await getInProgressGames();

    return games.isNotEmpty ? games.first : null;
  }

  Future<void> deleteGame(String id) async {
    final box = await _getBox();

    await box.delete(id);
  }

  Future<void> deleteAllGames() async {
    final box = await _getBox();

    await box.clear();
  }

  Future<int> getGameCount() async {
    final box = await _getBox();

    return box.length;
  }

  GameState savedGameToState(SavedGame savedGame) {
    return GameState.fromFen(
      id: savedGame.id,
      fen: savedGame.fen,
      mode: savedGame.mode,
      moves: const [],
    ).copyWith(
      createdAt: savedGame.createdAt,
      updatedAt: savedGame.updatedAt,
      result: savedGame.result,
      status: savedGame.result != null ? _statusFromResult(savedGame) : null,
    );
  }

  String? _getOpponentName(GameState gameState) {
    if (gameState.mode == GameMode.hotseat) return null;

    if (gameState.whitePlayer.isLocal) {
      return gameState.blackPlayer.name;
    } else {
      return gameState.whitePlayer.name;
    }
  }

  Future<void> _cleanupOldGames() async {
    final box = await _getBox();

    if (box.length <= _maxSavedGames) return;

    final games = box.values.toList();
    games.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));

    final toDelete = games.take(games.length - _maxSavedGames);
    for (final game in toDelete) {
      await box.delete(game.id);
    }
  }

  dynamic _statusFromResult(SavedGame savedGame) {
    return null;
  }

  Future<void> close() async {
    await _box?.close();

    _box = null;
  }
}

import 'package:hive/hive.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';
import '../../domain/enums/game_end_reason.dart';
import '../../domain/enums/game_status.dart';
import '../../domain/enums/promotion_piece.dart';
import '../../domain/models/game_mode.dart';
import '../../domain/models/game_state.dart';
import '../../domain/models/move.dart';
import '../../domain/models/saved_game.dart';
import '../../domain/services/chess_service.dart';
import '../../domain/services/pgn_service.dart';

class GameRepository {
  GameRepository({PgnService? pgnService, ChessService? chessService})
    : _pgnService = pgnService ?? const PgnService(),
      _chessService = chessService ?? const ChessService();

  static const String _boxName = 'games';
  final PgnService _pgnService;
  final ChessService _chessService;
  Box<SavedGame>? _box;

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

    final notationMoves = gameState.moves.map((m) => m.san ?? m.uci).toList();
    final uciMoves = gameState.moves.map((m) => m.uci).toList(growable: false);

    String? pgn;

    if (gameState.isEnded) {
      pgn = _pgnService.generate(
        moves: gameState.moves,
        result: gameState.result,
      );
    }

    final savedGame = SavedGame.fromDomain(
      id: gameState.id,
      fen: gameState.fen,
      moves: notationMoves,
      createdAt: gameState.createdAt,
      updatedAt: DateTime.now(),
      mode: gameState.mode,
      result: gameState.result,
      opponentName: _getOpponentName(gameState),
      pgn: pgn,
      uciMoves: uciMoves,
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
    final restoredMoves = _restoreMoves(savedGame);

    return GameState.fromFen(
      id: savedGame.id,
      fen: savedGame.fen,
      mode: savedGame.mode,
      moves: restoredMoves,
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

    if (box.length <= AppConstants.maxSavedGames) return;

    final games = box.values.toList();
    games.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));

    final toDelete = games.take(games.length - AppConstants.maxSavedGames);
    for (final game in toDelete) {
      await box.delete(game.id);
    }
  }

  List<Move> _restoreMoves(SavedGame savedGame) {
    final uciMoves = savedGame.uciMoves.isNotEmpty
        ? savedGame.uciMoves
        : _legacyUciMoves(savedGame.moves);

    if (uciMoves.isEmpty) return const [];

    var fen = AppConstants.standardStartFen;
    final moves = <Move>[];

    for (final uci in uciMoves) {
      final move = _moveFromUci(uci);
      if (move == null) return const [];

      final result = _chessService.makeMove(
        fen,
        move.from,
        move.to,
        promotion: move.promotion,
      );

      if (!result.success || result.fen == null || result.move == null) {
        Logger.warn(
          'Could not restore saved move history for game ${savedGame.id}',
          tag: 'GameRepository',
        );
        return const [];
      }

      fen = result.fen!;
      moves.add(result.move!);
    }

    if (fen != savedGame.fen) {
      Logger.warn(
        'Restored move history does not match saved FEN for game ${savedGame.id}',
        tag: 'GameRepository',
      );
      return const [];
    }

    return moves;
  }

  List<String> _legacyUciMoves(List<String> moves) {
    final legacyMoves = <String>[];

    for (final move in moves) {
      if (_moveFromUci(move) == null) return const [];
      legacyMoves.add(move);
    }

    return legacyMoves;
  }

  Move? _moveFromUci(String uci) {
    final normalized = uci.trim().toLowerCase();
    if (normalized.length != 4 && normalized.length != 5) return null;

    final from = normalized.substring(0, 2);
    final to = normalized.substring(2, 4);
    final promotion = normalized.length == 5
        ? PromotionPiece.fromLetter(normalized.substring(4))
        : null;

    if (normalized.length == 5 && promotion == null) return null;
    if (!_isSquareName(from) || !_isSquareName(to)) return null;

    return Move.fromAlgebraic(from: from, to: to, promotion: promotion);
  }

  bool _isSquareName(String value) {
    if (value.length != 2) return false;
    final file = value.codeUnitAt(0);
    final rank = value.codeUnitAt(1);
    return file >= 97 && file <= 104 && rank >= 49 && rank <= 56;
  }

  GameStatus _statusFromResult(SavedGame savedGame) {
    final result = savedGame.result;
    if (result == null) return GameStatus.playing;

    switch (result.reason) {
      case GameEndReason.checkmate:
        return GameStatus.checkmate;
      case GameEndReason.stalemate:
        return GameStatus.stalemate;
      case GameEndReason.resign:
        return GameStatus.resigned;
      default:
        return GameStatus.draw;
    }
  }

  Future<void> close() async {
    await _box?.close();

    _box = null;
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/enums/game_end_reason.dart';
import '../../domain/enums/game_status.dart';
import '../../domain/enums/promotion_piece.dart';
import '../../domain/enums/winner.dart';
import '../../domain/models/game_mode.dart';
import '../../domain/models/game_result.dart';
import '../../domain/models/game_state.dart';
import '../../domain/models/move.dart';
import '../../domain/models/piece.dart';
import '../../domain/models/player.dart';
import '../../domain/models/square.dart';
import '../../domain/services/chess_service.dart';
import '../../infrastructure/persistence/game_repository.dart';

class GameController extends StateNotifier<GameState?> {
  final ChessService _chessService;
  final GameRepository? _gameRepository;
  final Uuid _uuid = const Uuid();

  GameController({
    required ChessService chessService,
    GameRepository? gameRepository,
  }) : _chessService = chessService,
       _gameRepository = gameRepository,
       super(null);

  bool get hasActiveGame => state != null;
  bool get isGameInProgress => state?.isInProgress ?? false;
  bool get isGameEnded => state?.isEnded ?? false;

  void newGame({
    required GameMode mode,
    Player? whitePlayer,
    Player? blackPlayer,
    PieceColor? localPlayerColor,
  }) {
    final id = _uuid.v4();

    Player white = whitePlayer ?? Player.white();
    Player black = blackPlayer ?? Player.black();

    if (mode == GameMode.bleHost) {
      if (localPlayerColor == PieceColor.black) {
        white = Player.remote(id: 'remote_white', name: 'Opponent', color: PieceColor.white);
        black = Player.local(name: 'You', color: PieceColor.black, isHost: true);
      } else {
        white = Player.local(name: 'You', color: PieceColor.white, isHost: true);
        black = Player.remote(id: 'remote_black', name: 'Opponent', color: PieceColor.black);
      }
    } else if (mode == GameMode.bleClient) {
      if (localPlayerColor == PieceColor.white) {
        white = Player.local(name: 'You', color: PieceColor.white);
        black = Player.remote(id: 'remote_black', name: 'Host', color: PieceColor.black);
      } else {
        white = Player.remote(id: 'remote_white', name: 'Host', color: PieceColor.white);
        black = Player.local(name: 'You', color: PieceColor.black);
      }
    }

    state = GameState.newGame(id: id, mode: mode, whitePlayer: whitePlayer, blackPlayer: blackPlayer);

    _autoSave();
  }

  void loadGame(GameState gameState) {
    state = gameState;
  }

  void loadFromFen({
    required String fen,
    required GameMode mode,
    List<Move> moves = const [],
  }) {
    if (!_chessService.isValidFen(fen)) {
      throw ArgumentError('Invalid FEN: $fen');
    }

    final id = _uuid.v4();
    state = GameState.fromFen(id: id, fen: fen, mode: mode, moves: moves);

    _autoSave();
  }

  void resetGame() {
    if (state == null) return;

    state = GameState.newGame(id: state!.id, mode: state!.mode, whitePlayer: state!.whitePlayer, blackPlayer: state!.blackPlayer);

    _autoSave();
  }

  void endSession() {
    state = null;
  }

  bool makeMove({
    required Square from,
    required Square to,
    PromotionPiece? promotion,
  }) {
    if (state == null || !state!.isInProgress) {
      return false;
    }

    if (_chessService.requiresPromotion(state!.fen, from, to) && promotion == null) {
      return false;
    }

    final result = _chessService.makeMove(state!.fen, from, to, promotion: promotion);
  
    if (!result.success || result.move == null || result.fen == null) {
      return false;
    }

    final newMoves = [...state!.moves, result.move!];
    final newStatus = result.status ?? GameStatus.playing;

    GameResult? gameResult;

    if (newStatus == GameStatus.checkmate) {
      final winner = state!.currentTurn == PieceColor.white ? Winner.white : Winner.black;
      gameResult = GameResult.checkmate(winner, finalFen: result.fen);
    } else if (newStatus == GameStatus.stalemate) {
      gameResult = GameResult.stalemate(finalFen: result.fen);
    } else if (newStatus == GameStatus.draw) {
      if (_chessService.isInsufficientMaterial(result.fen!)) {
        gameResult = GameResult.insufficientMaterial(finalFen: result.fen);
      }
    }

    if (gameResult == null && _chessService.getHalfMoveClock(result.fen!) >= 100) {
      gameResult = GameResult.fiftyMoveRule(finalFen: result.fen);
      state = state!.copyWith(status: GameStatus.draw);
    }

    state = state!.copyWith(
      fen: result.fen,
      moves: newMoves,
      currentTurn: state!.currentTurn.opposite,
      status: gameResult != null ? _statusFromResult(gameResult) : newStatus,
      result: gameResult,
      drawOffered: false,
      drawOfferedBy: null,
    );

    _autoSave();

    return true;
  }

  bool undoMove() {
    if (state == null) return false;
    if (!state!.mode.allowsUndo) return false;
    if (state!.moves.isEmpty) return false;
    if (state!.isEnded) return false;

    final movesToReplay = state!.moves.sublist(0, state!.moves.length - 1);

    String fen = initialFen;
    final replayedMoves = <Move>[];

    for (final move in movesToReplay) {
      final result = _chessService.makeMove(fen, move.from, move.to, promotion: move.promotion);

      if (!result.success || result.fen == null || result.move == null) {
        return false;
      }

      fen = result.fen!;
      replayedMoves.add(result.move!);
    }

    final status = _chessService.getGameStatus(fen);

    state = state!.copyWith(
      fen: fen,
      moves: replayedMoves,
      currentTurn: _chessService.getCurrentTurn(fen),
      status: status,
      result: null,
    );

    _autoSave();

    return true;
  }

  List<Square> getLegalMoves(Square square) {
    if (state == null) return [];

    return _chessService.getLegalMoves(state!.fen, square);
  }

  bool requiresPromotion(Square from, Square to) {
    if (state == null) return false;

    return _chessService.requiresPromotion(state!.fen, from, to);
  }

  void resign(PieceColor resigningColor) {
    if (state == null || state!.isEnded) return;

    final winner = resigningColor == PieceColor.white? Winner.black : Winner.white;
    final result = GameResult.resignation(winner, finalFen: state!.fen);

    state = state!.copyWith(
      status: GameStatus.resigned,
      result: result,
    );

    _autoSave();
  }

  void offerDraw(PieceColor offeringColor) {
    if (state == null || state!.isEnded) return;
    if (state!.drawOffered) return;

    state = state!.copyWith(
      drawOffered: true,
      drawOfferedBy: offeringColor,
    ); 
  }

  void acceptDraw() {
    if (state == null || !state!.drawOffered) return;

    final result = GameResult.drawByAgreement(finalFen: state!.fen);

    state = state!.copyWith(
      status: GameStatus.draw,
      result: result,
      drawOffered: false,
      drawOfferedBy: null,
    );

    _autoSave();
  }

  void rejectDraw() {
    if (state == null || !state!.drawOffered) return;

    state = state!.clearDrawOffer();
  }

  void syncState({
    required String fen,
    required List<Move> moves,
    GameStatus? status,
    GameResult? result,
  }) {
    if (state == null) return;

    final actualStatus = status ?? _chessService.getGameStatus(fen);

    state = state!.copyWith(
      fen: fen,
      moves: moves,
      currentTurn: _chessService.getCurrentTurn(fen),
      status: actualStatus,
      result: result,
    );
  }

  bool applyRemoteMove(Move move) {
    return makeMove(from: move.from, to: move.to, promotion: move.promotion);
  }

  Piece? getPieceAt(Square square) {
    if (state == null) return null;

    return _chessService.getPieceAt(state!.fen, square);
  }

  Map<Square, Piece> getAllPieces() {
    if (state == null) return {};

    return _chessService.getAllPieces(state!.fen);
  }

  Square? getKingSquare(PieceColor color) {
    if (state == null) return null;

    return _chessService.getKingSquare(state!.fen, color);
  }

  bool canMove(PieceColor color) {
    if (state == null) return false;
    if (!state!.isInProgress) return false;

    return state!.currentTurn == color;
  }

  bool isLocalPlayerTurn() {
    if (state == null) return false;
    if (state!.mode == GameMode.hotseat) return true;

    final localColor = state!.whitePlayer.isLocal ? PieceColor.white : PieceColor.black;

    return state!.currentTurn == localColor;
  }

  GameStatus _statusFromResult(GameResult result) {
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

  Future<void> _autoSave() async {
    if (state == null || _gameRepository == null) return;

    try {
      await _gameRepository.saveGame(state!);
    } catch (e) {
      assert(() {
        print('GameController: Failed to auto-save game: $e');

        return true;
      }());
    }
  }
}


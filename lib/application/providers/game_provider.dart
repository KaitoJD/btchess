import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/enums/game_status.dart';
import '../../domain/models/game_mode.dart';
import '../../domain/models/game_state.dart';
import '../../domain/models/move.dart';
import '../../domain/models/piece.dart';
import '../../domain/models/player.dart';
import '../../domain/models/square.dart';
import '../controllers/game_controller.dart';
import 'persistence_provider.dart';
import 'services_provider.dart';

final gameControllerProvider = StateNotifierProvider<GameController, GameState?>((ref) {
  final chessService = ref.watch(chessServiceProvider);
  final gameRepository = ref.watch(gameRepositoryProvider);

  return GameController(chessService: chessService, gameRepository: gameRepository);
});

final gameStateProvider = Provider<GameState?>((ref) {
  return ref.watch(gameControllerProvider);
});

final hasActiveGameProvider = Provider<bool>((ref) {
  return ref.watch(gameControllerProvider) != null;
});

final isGameInProgressProvider = Provider<bool>((ref) {
  return ref.watch(gameControllerProvider)?.isInProgress ?? false;
});

final gameStatusProvider = Provider<GameStatus?>((ref) {
  return ref.watch(gameControllerProvider)?.status;
});

final currentTurnProvider = Provider<PieceColor?>((ref) {
  return ref.watch(gameControllerProvider)?.currentTurn;
});

final currentPlayerProvider = Provider<Player?>((ref) {
  return ref.watch(gameControllerProvider)?.currentPlayer;
});

final moveHistoryProvider = Provider<List<Move>>((ref) {
  return ref.watch(gameControllerProvider)?.moves ?? [];
});

final lastMoveProvider = Provider<Move?>((ref) {
  return ref.watch(gameControllerProvider)?.lastMove;
});

final isCheckProvider = Provider<bool>((ref) {
  return ref.watch(gameControllerProvider)?.isCheck ?? false;
});

final isDrawOfferedProvider = Provider<bool>((ref) {
  return ref.watch(gameControllerProvider)?.drawOffered ?? false;
});

final drawOfferedByProvider = Provider<PieceColor?>((ref) {
  return ref.watch(gameControllerProvider)?.drawOfferedBy;
});

final gameModeProvider = Provider<GameMode?>((ref) {
  return ref.watch(gameControllerProvider)?.mode;
});

final whitePlayerProvider = Provider<Player?>((ref) {
  return ref.watch(gameControllerProvider)?.whitePlayer;
});

final blackPlayerProvider = Provider<Player?>((ref) {
  return ref.watch(gameControllerProvider)?.blackPlayer;
});

final isLocalPlayerTurnProvider = Provider<bool>((ref) {
  final controller = ref.read(gameControllerProvider.notifier);

  return controller.isLocalPlayerTurn();
});

final currentFenProvider = Provider<String?>((ref) {
  return ref.watch(gameControllerProvider)?.fen;
});

final allPiecesProvider = Provider<Map<Square, Piece>>((ref) {
  final controller = ref.read(gameControllerProvider.notifier);

  return controller.getAllPieces();
});

final legalMovesProvider = Provider.family<List<Square>, Square>((ref, square) {
  final controller = ref.read(gameControllerProvider.notifier);

  return controller.getLegalMoves(square);
});

final pieceAtProvider = Provider.family<Piece?, Square>((ref, square) {
  final controller = ref.read(gameControllerProvider.notifier);

  return controller.getPieceAt(square);
});

final canUndoProvider = Provider<bool>((ref) {
  final state = ref.watch(gameControllerProvider);

  if (state == null) return false;
  if (!state.mode.allowsUndo) return false;
  if (state.moves.isEmpty) return false;
  if (state.isEnded) return false;

  return true;
});
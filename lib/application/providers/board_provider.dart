import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/game_state.dart';
import '../controllers/board_controller.dart';
import '../states/board_state.dart';
import 'services_provider.dart';

final boardControllerProvider = StateNotifierProvider<BoardController, BoardState>((ref) {
  final chessService = ref.watch(chessServiceProvider);

  return BoardController(chessService: chessService, initialFen: initialFen);
});

final selectedSquareProvider = Provider((ref) {
  return ref.watch(boardControllerProvider).selectedSquare;
});

final legalMovesProvider = Provider((ref) {
  return ref.watch(boardControllerProvider).legalMoves;
});

final lastMoveProvider = Provider((ref) {
  return ref.watch(boardControllerProvider).lastMove;
});

final boardFlippedProvider = Provider((ref) {
  return ref.watch(boardControllerProvider).isFlipped;
});

final boardPiecesProvider = Provider((ref) {
  return ref.watch(boardControllerProvider).pieces;
});

final showPromotionDialogProvider = Provider((ref) {
  return ref.watch(boardControllerProvider).showPromotionDialog;
});

final pendingPromotionProvider = Provider((ref) {
  return ref.watch(boardControllerProvider).pendingPromotion;
});
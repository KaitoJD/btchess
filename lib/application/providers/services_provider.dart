import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/services/chess_service.dart';
import '../../domain/services/fen_service.dart';
import '../../domain/services/move_validator.dart';
import '../../domain/services/pgn_service.dart';

final chessServiceProvider = Provider<ChessService>((ref) {
  return const ChessService();
});

final fenServiceProvider = Provider<FenService>((ref) {
  return const FenService();
});

final pgnServiceProvider = Provider<PgnService>((ref) {
  return const PgnService();
});

final moveValidatorProvider = Provider<MoveValidator>((ref) {
  final chessService = ref.watch(chessServiceProvider);

  return MoveValidator(chessService);
});



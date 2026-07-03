import 'package:hive/hive.dart';
import 'game_mode.dart';
import 'game_result.dart';
import '../enums/game_end_reason.dart';
import '../enums/winner.dart';
part 'saved_game.g.dart';

@HiveType(typeId: 0)
class SavedGame extends HiveObject {
  SavedGame({
    required this.id,
    required this.fen,
    required this.moves,
    required this.createdAt,
    required this.updatedAt,
    required this.modeIndex,
    this.winnerIndex,
    this.endReasonIndex,
    this.opponentName,
    this.pgn,
    this.uciMoves = const [],
  });

  factory SavedGame.fromDomain({
    required String id,
    required String fen,
    required List<String> moves,
    required DateTime createdAt,
    required DateTime updatedAt,
    required GameMode mode,
    GameResult? result,
    String? opponentName,
    String? pgn,
    List<String> uciMoves = const [],
  }) {
    return SavedGame(
      id: id,
      fen: fen,
      moves: moves,
      createdAt: createdAt,
      updatedAt: updatedAt,
      modeIndex: mode.index,
      winnerIndex: result?.winner.index,
      endReasonIndex: result?.reason.index,
      opponentName: opponentName,
      pgn: pgn,
      uciMoves: uciMoves,
    );
  }

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String fen;

  @HiveField(2)
  final List<String> moves;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  final DateTime updatedAt;

  @HiveField(5)
  final int modeIndex;

  @HiveField(6)
  final int? winnerIndex;

  @HiveField(7)
  final int? endReasonIndex;

  @HiveField(8)
  final String? opponentName;

  @HiveField(9)
  final String? pgn;

  @HiveField(10, defaultValue: <String>[])
  final List<String> uciMoves;

  GameMode get mode =>
      _safeEnumValue(GameMode.values, modeIndex) ?? GameMode.hotseat;
  bool get isCompleted => result != null;
  bool get isInProgress => !isCompleted;

  GameResult? get result {
    if (winnerIndex == null || endReasonIndex == null) return null;
    final winner = _safeEnumValue(Winner.values, winnerIndex!);
    final reason = _safeEnumValue(GameEndReason.values, endReasonIndex!);
    if (winner == null || reason == null) return null;

    return GameResult(winner: winner, reason: reason, finalFen: fen, pgn: pgn);
  }

  SavedGame copyWith({
    String? id,
    String? fen,
    List<String>? moves,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? modeIndex,
    int? winnerIndex,
    int? endReasonIndex,
    String? opponentName,
    String? pgn,
    List<String>? uciMoves,
  }) {
    return SavedGame(
      id: id ?? this.id,
      fen: fen ?? this.fen,
      moves: moves ?? this.moves,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      modeIndex: modeIndex ?? this.modeIndex,
      winnerIndex: winnerIndex ?? this.winnerIndex,
      endReasonIndex: endReasonIndex ?? this.endReasonIndex,
      opponentName: opponentName ?? this.opponentName,
      pgn: pgn ?? this.pgn,
      uciMoves: uciMoves ?? this.uciMoves,
    );
  }

  @override
  String toString() =>
      'SavedGame(id: $id, mode: ${mode.name}, completed: $isCompleted)';

  T? _safeEnumValue<T>(List<T> values, int index) {
    if (index < 0 || index >= values.length) return null;
    return values[index];
  }
}

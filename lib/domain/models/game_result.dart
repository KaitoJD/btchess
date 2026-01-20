import 'package:equatable/equatable.dart';
import '../enums/game_end_reason.dart';
import '../enums/winner.dart';

class GameResult extends Equatable {
  final Winner winner;
  final GameEndReason reason;
  final String? finalFen;
  final String? pgn;

  const GameResult({
    required this.winner,
    required this.reason,
    this.finalFen,
    this.pgn,
  });

  factory GameResult.checkmate(Winner winner, {String? finalFen, String? pgn}) {
    return GameResult(
      winner: winner,
      reason: GameEndReason.checkmate,
      finalFen: finalFen,
      pgn: pgn,
    );
  }

  factory GameResult.stalemate({String? finalFen, String? pgn}) {
    return GameResult(
      winner: Winner.draw,
      reason: GameEndReason.stalemate,
      finalFen: finalFen,
      pgn: pgn,
    );
  }

  factory GameResult.resignation(Winner winner, {String? finalFen, String? pgn}) {
    return GameResult(
      winner: winner,
      reason: GameEndReason.resign,
      finalFen: finalFen,
      pgn: pgn,
    );
  }

  factory GameResult.drawByAgreement({String? finalFen, String? pgn}) {
    return GameResult(
      winner: Winner.draw,
      reason: GameEndReason.drawAgreement,
      finalFen: finalFen,
      pgn: pgn,
    );
  }

  factory GameResult.fiftyMoveRule({String? finalFen, String? pgn}) {
    return GameResult(
      winner: Winner.draw,
      reason: GameEndReason.fiftyMoveRule,
      finalFen: finalFen,
      pgn: pgn,
    );
  }

  factory GameResult.threefoldRepetition({String? finalFen, String? pgn}) {
    return GameResult(
      winner: Winner.draw,
      reason: GameEndReason.threefoldRepetition,
      finalFen: finalFen,
      pgn: pgn,
    );
  }

  factory GameResult.insufficientMaterial({String? finalFen, String? pgn}) {
    return GameResult(
      winner: Winner.draw,
      reason: GameEndReason.insufficientMaterial,
      finalFen: finalFen,
      pgn: pgn,
    );
  }

  factory GameResult.disconnect(Winner winner, {String? finalFen, String? pgn}) {
    return GameResult(
      winner: winner,
      reason: GameEndReason.disconnect,
      finalFen: finalFen,
      pgn: pgn,
    );
  }

  bool get isDraw => winner == Winner.draw;
  bool get whiteWon => winner == Winner.white;
  bool get blackWon => winner == Winner.black;

  String get description {
    switch (reason) {
      case GameEndReason.checkmate:
        return '${winner.displayName} wins by checkmate';
      case GameEndReason.stalemate:
        return 'Draw by stalemate';
      case GameEndReason.resign:
        return '${winner.displayName} wins by resignation';
      case GameEndReason.drawAgreement:
        return 'Draw by agreement';
      case GameEndReason.fiftyMoveRule:
        return 'Draw by fifty-move rule';
      case GameEndReason.threefoldRepetition:
        return 'Draw by threefold repetition';
      case GameEndReason.insufficientMaterial:
        return 'Draw by insufficient material';
      case GameEndReason.timeout:
        return '${winner.displayName} wins on time';
      case GameEndReason.disconnect:
        return '${winner.displayName} wins by disconnection';
    }
  }

  String get pgnResult {
    switch (winner) {
      case Winner.white:
        return '1-0';
      case Winner.black:
        return '0-1';
      case Winner.draw:
        return '1/2-1/2';
    }
  }

  @override
  List<Object?> get props => [winner, reason, finalFen, pgn];

  @override
  String toString() => description;
}
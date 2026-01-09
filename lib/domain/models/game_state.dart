import 'package:equatable/equatable.dart';
import 'game_mode.dart';
import 'game_result.dart';
import 'move.dart';
import 'piece.dart';
import 'player.dart';
import '../enums/game_status.dart';

const String initialFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

class GameState extends Equatable {
  final String id;
  final String fen;
  final List<Move> moves;
  final PieceColor currentTurn;
  final GameStatus status;
  final GameResult? result;
  final GameMode mode;
  final Player whitePlayer;
  final Player blackPlayer;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool drawOffered;
  final PieceColor? drawOfferedBy;

  const GameState({
    required this.id,
    required this.fen,
    required this.moves,
    required this.currentTurn,
    required this.status,
    this.result,
    required this.mode,
    required this.whitePlayer,
    required this.blackPlayer,
    required this.createdAt,
    required this.updatedAt,
    this.drawOffered = false,
    this.drawOfferedBy,
  });

  factory GameState.newGame({
    required String id,
    required GameMode mode,
    Player? whitePlayer,
    Player? blackPlayer,
  }) {
    final now = DateTime.now();

    return GameState(
      id: id,
      fen: initialFen,
      moves: const [],
      currentTurn: PieceColor.white,
      status: GameStatus.playing,
      result: null,
      mode: mode,
      whitePlayer: whitePlayer ?? Player.white(),
      blackPlayer: blackPlayer ?? Player.black(),
      createdAt: now,
      updatedAt: now,
    );
  }

  factory GameState.fromFen({
    required String id,
    required String fen,
    required GameMode mode,
    List<Move> moves = const [],
    Player? whitePlayer,
    Player? blackPlayer,
  }) {
    final parts = fen.split(' ');
    final turn = parts.length > 1 && parts[1] == 'b' ? PieceColor.black : PieceColor.white;
    final now = DateTime.now();

    return GameState(
      id: id,
      fen: fen,
      moves: moves,
      currentTurn: turn,
      status: GameStatus.playing,
      result: null,
      mode: mode,
      whitePlayer: whitePlayer ?? Player.white(),
      blackPlayer: blackPlayer ?? Player.black(),
      createdAt: now,
      updatedAt: now,
    );
  }

  int get moveCount => moves.length;

  int get fullMoveNumber {
    final parts = fen.split(' ');
    if (parts.length >= 6) {
      return int.tryParse(parts[5]) ?? 1;
    }
    return (moveCount ~/ 2) + 1;
  }

  int get halfMoveClock {
    final parts = fen.split(' ');
    if (parts.length >= 5) {
      return int.tryParse(parts[4]) ?? 0;
    }
    return 0;
  }

  bool get isInProgress => status == GameStatus.playing || status == GameStatus.check;

  bool get isEnded => result != null;

  bool get isWhiteTurn => currentTurn == PieceColor.white;

  bool get isBlackTurn => currentTurn == PieceColor.black;

  Player get currentPlayer => isWhiteTurn ? whitePlayer : blackPlayer;

  Player get waitingPlayer => isWhiteTurn ? blackPlayer : whitePlayer;

  Move? get lastMove => moves.isNotEmpty ? moves.last : null;

  bool get isCheck => status == GameStatus.check;

  bool get isCheckmate => status == GameStatus.checkmate;

  bool get isStalemate => status == GameStatus.stalemate;

  bool get isDraw => result?.isDraw ?? false;

  GameState copyWith({
    String? id,
    String? fen,
    List<Move>? moves,
    PieceColor? currentTurn,
    GameStatus? status,
    GameResult? result,
    GameMode? mode,
    Player? whitePlayer,
    Player? blackPlayer,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? drawOffered,
    PieceColor? drawOfferedBy,
  }) {
    return GameState(
      id: id ?? this.id,
      fen: fen ?? this.fen,
      moves: moves ?? this.moves,
      currentTurn: currentTurn ?? this.currentTurn,
      status: status ?? this.status,
      result: result ?? this.result,
      mode: mode ?? this.mode,
      whitePlayer: whitePlayer ?? this.whitePlayer,
      blackPlayer: blackPlayer ?? this.blackPlayer,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      drawOffered: drawOffered ?? this.drawOffered,
      drawOfferedBy: drawOfferedBy ?? this.drawOfferedBy,
    );
  }

  GameState clearDrawOffer() {
    return copyWith(
      drawOffered: false,
      drawOfferedBy: null,
    );
  }

  @override
  List<Object?> get props => [
    id,
    fen,
    moves,
    currentTurn,
    status,
    result,
    mode,
    whitePlayer,
    blackPlayer,
    createdAt,
    updatedAt,
    drawOffered,
    drawOfferedBy,
  ];

  @override
  String toString() => 'GameState(id: $id, status: $status, turn: ${currentTurn.name})';
}
import 'package:equatable/equatable.dart';
import '../../domain/models/piece.dart';

enum LobbyStatus {
  idle,
  creating,
  joining,
  waitingForOpponent,
  ready,
  starting,
  inGame,
  error,
}

class LobbyState extends Equatable {
  const LobbyState({
    this.status = LobbyStatus.idle,
    this.lobbyName = '',
    this.hostPlayerName = '',
    this.clientPlayerName = '',
    this.isHost = false,
    this.hostColor = PieceColor.white,
    this.lastError,
  });

  factory LobbyState.initial() => const LobbyState();

  final LobbyStatus status;
  final String lobbyName;
  final String hostPlayerName;
  final String clientPlayerName;
  final bool isHost;
  final PieceColor hostColor;
  final String? lastError;

  bool get isActive => status != LobbyStatus.idle && status != LobbyStatus.error;
  bool get isWaitingForOpponent => status == LobbyStatus.waitingForOpponent;
  bool get isReady => status == LobbyStatus.ready;
  bool get isInGame => status == LobbyStatus.inGame;
  PieceColor get localColor => isHost ? hostColor : hostColor.opposite;
  String get opponentName => isHost ? clientPlayerName : hostPlayerName;
  String get localPlayerName => isHost ? hostPlayerName : clientPlayerName;

  LobbyState copyWith({
    LobbyStatus? status,
    String? lobbyName,
    String? hostPlayerName,
    String? clientPlayerName,
    bool? isHost,
    PieceColor? hostColor,
    String? lastError,
    bool clearError = false,
  }) {
    return LobbyState(
      status: status ?? this.status,
      lobbyName: lobbyName ?? this.lobbyName,
      hostPlayerName: hostPlayerName ?? this.hostPlayerName,
      clientPlayerName: clientPlayerName ?? this.clientPlayerName,
      isHost: isHost ?? this.isHost,
      hostColor: hostColor ?? this.hostColor,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }

  @override
  List<Object?> get props => [
    status,
    lobbyName,
    hostPlayerName,
    clientPlayerName,
    isHost,
    hostColor,
    lastError,
  ];

  @override
  String toString() => 'LobbyState(status: $status, isHost: $isHost, name: $lobbyName)';
}
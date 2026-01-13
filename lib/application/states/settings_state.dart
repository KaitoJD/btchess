import 'package:equatable/equatable.dart';
import '../../infrastructure/persistence/settings_repository.dart';

class SettingsState extends Equatable {
  final bool soundEnabled;
  final bool showLegalMoves;
  final bool showCoordinates;
  final BoardTheme boardTheme;
  final PieceTheme pieceTheme;
  final bool debugMode;
  final String playerName;
  final bool autoFlipBoard;
  final bool isLoaded;

  const SettingsState({
    this.soundEnabled = true,
    this.showLegalMoves = true,
    this.showCoordinates = true,
    this.boardTheme = BoardTheme.classic,
    this.pieceTheme = PieceTheme.standard,
    this.debugMode = false,
    this.playerName = 'Player',
    this.autoFlipBoard = false,
    this.isLoaded = false,
  });

  factory SettingsState.defaults() => const SettingsState(isLoaded: true);

  SettingsState copyWith({
    bool? soundEnabled,
    bool? showLegalMoves,
    bool? showCoordinates,
    BoardTheme? boardTheme,
    PieceTheme? pieceTheme,
    bool? debugMode,
    String? playerName,
    bool? autoFlipBoard,
    bool? isLoaded,
  }) {
    return SettingsState(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      showLegalMoves: showLegalMoves ?? this.showLegalMoves,
      showCoordinates: showCoordinates ?? this.showCoordinates,
      boardTheme: boardTheme ?? this.boardTheme,
      pieceTheme: pieceTheme ?? this.pieceTheme,
      debugMode: debugMode ?? this.debugMode,
      playerName: playerName ?? this.playerName,
      autoFlipBoard: autoFlipBoard ?? this.autoFlipBoard,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }

  @override
  List<Object?> get props => [
    soundEnabled,
    showLegalMoves,
    showCoordinates,
    boardTheme,
    pieceTheme,
    debugMode,
    playerName,
    autoFlipBoard,
    isLoaded,
  ];

  @override
  String toString() => 'SettingsState(sound: $soundEnabled, legalMoves: $showLegalMoves, theme: $boardTheme)';
}


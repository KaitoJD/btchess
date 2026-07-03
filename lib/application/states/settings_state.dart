import 'package:equatable/equatable.dart';
import '../../domain/models/settings_models.dart';

class SettingsState extends Equatable {
  const SettingsState({
    this.soundEnabled = true,
    this.showLegalMoves = true,
    this.showCoordinates = true,
    this.boardTheme = BoardTheme.classic,
    this.pieceTheme = PieceTheme.standard,
    this.debugMode = false,
    this.autoFlipBoard = false,
    this.isLoaded = false,
    this.lastError,
  });

  factory SettingsState.defaults() => const SettingsState(isLoaded: true);

  final bool soundEnabled;
  final bool showLegalMoves;
  final bool showCoordinates;
  final BoardTheme boardTheme;
  final PieceTheme pieceTheme;
  final bool debugMode;
  final bool autoFlipBoard;
  final bool isLoaded;
  final String? lastError;

  SettingsState copyWith({
    bool? soundEnabled,
    bool? showLegalMoves,
    bool? showCoordinates,
    BoardTheme? boardTheme,
    PieceTheme? pieceTheme,
    bool? debugMode,
    bool? autoFlipBoard,
    bool? isLoaded,
    String? lastError,
    bool clearLastError = false,
  }) {
    return SettingsState(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      showLegalMoves: showLegalMoves ?? this.showLegalMoves,
      showCoordinates: showCoordinates ?? this.showCoordinates,
      boardTheme: boardTheme ?? this.boardTheme,
      pieceTheme: pieceTheme ?? this.pieceTheme,
      debugMode: debugMode ?? this.debugMode,
      autoFlipBoard: autoFlipBoard ?? this.autoFlipBoard,
      isLoaded: isLoaded ?? this.isLoaded,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
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
    autoFlipBoard,
    isLoaded,
    lastError,
  ];

  @override
  String toString() =>
      'SettingsState(sound: $soundEnabled, legalMoves: $showLegalMoves, theme: $boardTheme)';
}

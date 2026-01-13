import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../infrastructure/persistence/settings_repository.dart';
import '../states/settings_state.dart';

class SettingsController extends StateNotifier<SettingsState> {
  final SettingsRepository _repository;

  SettingsController({required SettingsRepository repository}) : _repository = repository, super(const SettingsState());

  Future<void> loadSettings() async {
    try {
      await _repository.init();

      final soundEnabled = await _repository.getSoundEnabled();
      final showLegalMoves = await _repository.getShowLegalMoves();
      final showCoordinates = await _repository.getShowCoordinates();
      final boardTheme = await _repository.getBoardTheme();
      final pieceTheme = await _repository.getPieceTheme();
      final debugMode = await _repository.getDebugMode();
      final playerName = await _repository.getPlayerName();
      final autoFlipBoard = await _repository.getAutoFlipBoard();

      state = SettingsState(
        soundEnabled: soundEnabled,
        showLegalMoves: showLegalMoves,
        showCoordinates: showCoordinates,
        boardTheme: boardTheme,
        pieceTheme: pieceTheme,
        debugMode: debugMode,
        playerName: playerName,
        autoFlipBoard: autoFlipBoard,
        isLoaded: true,
      );
    } catch (e) {
      state = SettingsState.defaults();
    }
  }

  Future<void> toggleSound() async {
    final newValue = !state.soundEnabled;
    state = state.copyWith(soundEnabled: newValue);

    await _repository.setSoundEnabled(newValue);
  }

  Future<void> setSoundEnabled(bool value) async {
    state = state.copyWith(soundEnabled: value);

    await _repository.setSoundEnabled(value);
  }

  Future<void> toggleShowLegalMoves() async {
    final newValue = !state.showLegalMoves;
    state = state.copyWith(showLegalMoves: newValue);

    await _repository.setShowLegalMoves(newValue);
  }

  Future<void> setShowLegalMoves(bool value) async {
    state = state.copyWith(showLegalMoves: value);

    await _repository.setShowLegalMoves(value);
  }

  Future<void> toggleShowCoordinates() async {
    final newValue = !state.showCoordinates;
    state = state.copyWith(showCoordinates: newValue);

    await _repository.setShowCoordinates(newValue);
  }

  Future<void> setShowCoordinates(bool value) async {
    state = state.copyWith(showCoordinates: value);

    await _repository.setShowCoordinates(value);
  }

  Future<void> setBoardTheme(BoardTheme theme) async {
    state = state.copyWith(boardTheme: theme);

    await _repository.setBoardTheme(theme);
  }

  Future<void> setPieceTheme(PieceTheme theme) async {
    state = state.copyWith(pieceTheme: theme);

    await _repository.setPieceTheme(theme);
  }

  Future<void> toggleDebugMode() async {
    final newValue = !state.debugMode;
    state = state.copyWith(debugMode: newValue);

    await _repository.setDebugMode(newValue);
  }

  Future<void> setDebugMode(bool value) async {
    state = state.copyWith(debugMode: value);

    await _repository.setDebugMode(value);
  }

  Future<void> setPlayerName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    state = state.copyWith(playerName: trimmed);

    await _repository.setPlayerName(trimmed);
  }

  Future<void> toggleAutoFlipBoard() async {
    final newValue = !state.autoFlipBoard;
    state = state.copyWith(autoFlipBoard: newValue);

    await _repository.setAutoFlipBoard(newValue);
  }

  Future<void> setAutoFlipBoard(bool value) async {
    state = state.copyWith(autoFlipBoard: value);

    await _repository.setAutoFlipBoard(value);
  }

  Future<void> resetToDefaults() async {
    await _repository.resetAll();

    state = SettingsState.defaults();
  }
}
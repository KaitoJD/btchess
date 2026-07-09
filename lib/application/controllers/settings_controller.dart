import 'package:flutter_riverpod/legacy.dart' show StateNotifier;
import '../../core/utils/logger.dart';
import '../../domain/models/settings_models.dart';
import '../../infrastructure/persistence/settings_repository.dart';
import '../states/settings_state.dart';

class SettingsController extends StateNotifier<SettingsState> {
  SettingsController({required SettingsRepository repository})
    : _repository = repository,
      super(const SettingsState());

  final SettingsRepository _repository;

  Future<void> loadSettings() async {
    try {
      await _repository.init();

      final soundEnabled = await _repository.getSoundEnabled();
      final showLegalMoves = await _repository.getShowLegalMoves();
      final showCoordinates = await _repository.getShowCoordinates();
      final boardTheme = await _repository.getBoardTheme();
      final pieceTheme = await _repository.getPieceTheme();
      final debugMode = await _repository.getDebugMode();
      final autoFlipBoard = await _repository.getAutoFlipBoard();

      state = SettingsState(
        soundEnabled: soundEnabled,
        showLegalMoves: showLegalMoves,
        showCoordinates: showCoordinates,
        boardTheme: boardTheme,
        pieceTheme: pieceTheme,
        debugMode: debugMode,
        autoFlipBoard: autoFlipBoard,
        isLoaded: true,
      );
    } catch (e) {
      Logger.error(
        'Failed to load settings; using defaults',
        tag: 'SettingsController',
        error: e,
      );
      state = SettingsState.defaults().copyWith(lastError: e.toString());
    }
  }

  Future<void> toggleSound() async {
    final newValue = !state.soundEnabled;
    state = state.copyWith(soundEnabled: newValue);

    await _repository.setSoundEnabled(value: newValue);
  }

  Future<void> setSoundEnabled({required bool value}) async {
    state = state.copyWith(soundEnabled: value);

    await _repository.setSoundEnabled(value: value);
  }

  Future<void> toggleShowLegalMoves() async {
    final newValue = !state.showLegalMoves;
    state = state.copyWith(showLegalMoves: newValue);

    await _repository.setShowLegalMoves(value: newValue);
  }

  Future<void> setShowLegalMoves({required bool value}) async {
    state = state.copyWith(showLegalMoves: value);

    await _repository.setShowLegalMoves(value: value);
  }

  Future<void> toggleShowCoordinates() async {
    final newValue = !state.showCoordinates;
    state = state.copyWith(showCoordinates: newValue);

    await _repository.setShowCoordinates(value: newValue);
  }

  Future<void> setShowCoordinates({required bool value}) async {
    state = state.copyWith(showCoordinates: value);

    await _repository.setShowCoordinates(value: value);
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

    await _repository.setDebugMode(value: newValue);
  }

  Future<void> setDebugMode({required bool value}) async {
    state = state.copyWith(debugMode: value);

    await _repository.setDebugMode(value: value);
  }

  Future<void> toggleAutoFlipBoard() async {
    final newValue = !state.autoFlipBoard;
    state = state.copyWith(autoFlipBoard: newValue);

    await _repository.setAutoFlipBoard(value: newValue);
  }

  Future<void> setAutoFlipBoard({required bool value}) async {
    state = state.copyWith(autoFlipBoard: value);

    await _repository.setAutoFlipBoard(value: value);
  }

  Future<void> resetToDefaults() async {
    await _repository.resetAll();

    state = SettingsState.defaults();
  }
}

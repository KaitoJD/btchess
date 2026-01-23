import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../infrastructure/persistence/settings_repository.dart';
import '../controllers/settings_controller.dart';
import '../states/settings_state.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

final settingsControllerProvider = StateNotifierProvider<SettingsController, SettingsState>((ref) {
  final repository = ref.watch(settingsRepositoryProvider);

  return SettingsController(repository: repository);
});

final settingsLoadedProvider = Provider<bool>((ref) {
  return ref.watch(settingsControllerProvider).isLoaded;
});

final soundEnabledProvider = Provider<bool>((ref) {
  return ref.watch(settingsControllerProvider).soundEnabled;
});

final showLegalMovesProvider = Provider<bool>((ref) {
  return ref.watch(settingsControllerProvider).showLegalMoves;
});

final showCoordinatesProvider = Provider<bool>((ref) {
  return ref.watch(settingsControllerProvider).showCoordinates;
});

final boardThemeProvider = Provider<BoardTheme>((ref) {
  return ref.watch(settingsControllerProvider).boardTheme;
});

final pieceThemeProvider = Provider<PieceTheme>((ref) {
  return ref.watch(settingsControllerProvider).pieceTheme;
});

final debugModeProvider = Provider<bool>((ref) {
  return ref.watch(settingsControllerProvider).debugMode;
});

final playerNameProvider = Provider<String>((ref) {
  return ref.watch(settingsControllerProvider).playerName;
});

final autoFlipBoardProvider = Provider<bool>((ref) {
  return ref.watch(settingsControllerProvider).autoFlipBoard;
});
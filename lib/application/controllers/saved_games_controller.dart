import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/logger.dart';
import '../../domain/models/saved_game.dart';
import '../../infrastructure/persistence/game_repository.dart';
import 'game_controller.dart';

class SavedGamesController extends StateNotifier<AsyncValue<void>> {
  SavedGamesController({
    required GameRepository gameRepository,
    required GameController gameController,
    required void Function() onChanged,
  }) : _gameRepository = gameRepository,
       _gameController = gameController,
       _onChanged = onChanged,
       super(const AsyncData(null));

  final GameRepository _gameRepository;
  final GameController _gameController;
  final void Function() _onChanged;

  void resumeGame(SavedGame savedGame) {
    try {
      final gameState = _gameRepository.savedGameToState(savedGame);
      _gameController.loadGame(gameState);
      state = const AsyncData(null);
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to resume saved game ${savedGame.id}',
        tag: 'SavedGamesController',
        error: e,
        stackTrace: stackTrace,
      );
      state = AsyncError(e, stackTrace);
      rethrow;
    }
  }

  Future<void> deleteGame(String id) async {
    state = const AsyncLoading();

    try {
      await _gameRepository.deleteGame(id);
      _onChanged();
      state = const AsyncData(null);
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to delete saved game $id',
        tag: 'SavedGamesController',
        error: e,
        stackTrace: stackTrace,
      );
      state = AsyncError(e, stackTrace);
      rethrow;
    }
  }
}

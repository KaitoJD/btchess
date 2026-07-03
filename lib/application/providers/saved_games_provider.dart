import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/saved_games_controller.dart';
import 'game_provider.dart';
import 'persistence_provider.dart';

final savedGamesControllerProvider =
    StateNotifierProvider<SavedGamesController, AsyncValue<void>>((ref) {
      final gameRepository = ref.watch(gameRepositoryProvider);
      final gameController = ref.read(gameControllerProvider.notifier);

      return SavedGamesController(
        gameRepository: gameRepository,
        gameController: gameController,
        onChanged: () {
          ref.invalidate(savedGamesProvider);
          ref.invalidate(inProgressGamesProvider);
          ref.invalidate(completedGamesProvider);
          ref.invalidate(mostRecentGameProvider);
          ref.invalidate(savedGameCountProvider);
        },
      );
    });

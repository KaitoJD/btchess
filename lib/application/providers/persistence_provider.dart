import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/saved_game.dart';
import '../../infrastructure/persistence/game_repository.dart';
import '../../application/providers/services_provider.dart';

final gameRepositoryProvider = Provider<GameRepository>((ref) {
  final pgnService = ref.watch(pgnServiceProvider);

  return GameRepository(pgnService: pgnService);
});

final gameRepositoryInitProvider = FutureProvider<void>((ref) async {
  final repository = ref.read(gameRepositoryProvider);

  await repository.init();
});

final savedGamesProvider = FutureProvider<List<SavedGame>>((ref) async {
  await ref.watch(gameRepositoryInitProvider.future);

  final repository = ref.read(gameRepositoryProvider);

  return repository.getAllGames();
});

final inProgressGamesProvider = FutureProvider<List<SavedGame>>((ref) async {
  await ref.watch(gameRepositoryInitProvider.future);

  final repository = ref.read(gameRepositoryProvider);

  return repository.getInProgressGames();
});

final completedGamesProvider = FutureProvider<List<SavedGame>>((ref) async {
  await ref.watch(gameRepositoryInitProvider.future);

  final repository = ref.read(gameRepositoryProvider);

  return repository.getCompletedGames();
});

final mostRecentGameProvider = FutureProvider<SavedGame?>((ref) async {
  await ref.watch(gameRepositoryInitProvider.future);

  final repository = ref.read(gameRepositoryProvider);

  return repository.getMostRecentGame();
});

final savedGameProvider = FutureProvider.family<SavedGame?, String>((ref, id) async {
  await ref.watch(gameRepositoryInitProvider.future);

  final repository = ref.read(gameRepositoryProvider);

  return repository.getGame(id);
});

final savedGameCountProvider = FutureProvider<int>((ref) async {
  await ref.watch(gameRepositoryInitProvider.future);

  final repository = ref.read(gameRepositoryProvider);

  return repository.getGameCount();
});
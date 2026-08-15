import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/persistence_provider.dart';
import '../../application/providers/saved_games_provider.dart';
import '../../core/extensions/datetime_extensions.dart';
import '../../domain/enums/winner.dart';
import '../../domain/models/saved_game.dart';
import '../routes/app_router.dart';
import 'game_over_screen.dart';

class GameHistoryScreen extends ConsumerStatefulWidget {
  const GameHistoryScreen({super.key});

  @override
  ConsumerState<GameHistoryScreen> createState() => _GameHistoryScreenState();
}

class _GameHistoryScreenState extends ConsumerState<GameHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Game History'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'In Progress'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _GameList(
            games: ref.watch(inProgressGamesProvider),
            emptyMessage: 'No games in progress',
            onGameTap: (game) => _resumeGame(game),
            onGameDelete: (game) => _deleteGame(game),
          ),
          _GameList(
            games: ref.watch(completedGamesProvider),
            emptyMessage: 'No completed games',
            onGameTap: (game) => _viewGame(game),
            onGameDelete: (game) => _deleteGame(game),
          ),
        ],
      ),
    );
  }

  void _resumeGame(SavedGame game) {
    ref.read(savedGamesControllerProvider.notifier).resumeGame(game);
    AppRouter.navigateAndReplace(context, AppRoutes.game);
  }

  void _viewGame(SavedGame game) {
    final pgn = game.pgn ?? 'No PGN available for this game.';
    AppRouter.navigateTo(
      context,
      AppRoutes.pgnViewer,
      arguments: PgnViewerScreenArgs(pgn: pgn),
    );
  }

  Future<void> _deleteGame(SavedGame game) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Game'),
        content: const Text('Are you sure you want to delete this game?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(savedGamesControllerProvider.notifier).deleteGame(game.id);
    }
  }
}

class _GameList extends StatelessWidget {
  const _GameList({
    required this.games,
    required this.emptyMessage,
    required this.onGameTap,
    required this.onGameDelete,
  });

  final AsyncValue<List<SavedGame>> games;
  final String emptyMessage;
  final void Function(SavedGame) onGameTap;
  final Future<void> Function(SavedGame) onGameDelete;

  @override
  Widget build(BuildContext context) {
    return games.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
      data: (games) {
        if (games.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  emptyMessage,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: games.length,
          itemBuilder: (context, index) {
            final game = games[index];
            return _GameTile(
              game: game,
              onTap: () => onGameTap(game),
              onDelete: () => onGameDelete(game),
            );
          },
        );
      },
    );
  }
}

class _GameTile extends StatelessWidget {
  const _GameTile({
    required this.game,
    required this.onTap,
    required this.onDelete,
  });

  final SavedGame game;
  final VoidCallback onTap;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dismissible(
      key: Key(game.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: Icon(Icons.delete, color: colorScheme.onError),
      ),
      confirmDismiss: (_) async {
        await onDelete();
        return false;
      },
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: game.isInProgress
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            game.isInProgress ? Icons.play_arrow : Icons.check,
            color: game.isInProgress
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurfaceVariant,
          ),
        ),
        title: Text(
          game.opponentName ?? game.mode.displayName,
          style: theme.textTheme.titleMedium,
        ),
        subtitle: Text(
          '${game.moves.length} moves - ${game.updatedAt.toRelative()}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: game.isCompleted
            ? _buildResultBadge(context)
            : const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  Widget _buildResultBadge(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final text = switch (game.result?.winner) {
      Winner.white => 'White',
      Winner.black => 'Black',
      Winner.draw || null => 'Draw',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.inverseSurface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colorScheme.inversePrimary),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: colorScheme.onInverseSurface,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

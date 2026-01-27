import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/game_provider.dart';
import '../../application/providers/persistence_provider.dart';
import '../../domain/models/saved_game.dart';
import '../routes/app_router.dart';

class GameHistoryScreen extends ConsumerStatefulWidget {
  const GameHistoryScreen({super.key});

  @override
  ConsumerState<GameHistoryScreen> createState() => _GameHistoryScreenState();
}

class _GameHistoryScreenState extends ConsumerState<GameHistoryScreen> with SingleTickerProviderStateMixin {
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
            futureGames: ref.read(gameRepositoryProvider).getInProgressGames(),
            emptyMessage: 'No games in progress',
            onGameTap: (game) => _resumeGame(game),
            onGameDelete: (game) => _deleteGame(game),
          ),
          _GameList(
            futureGames: ref.read(gameRepositoryProvider).getCompletedGames(),
            emptyMessage: 'No completed games',
            onGameTap: (game) => _viewGame(game),
            onGameDelete: (game) => _deleteGame(game),
          ),
        ],
      ),
    );
  }

  void _resumeGame(SavedGame game) {
    // TODO: Load saved game state
  }

  void _viewGame(SavedGame game) {
    // TODO: Navigate to PGN viewer
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
      await ref.read(gameRepositoryProvider).deleteGame(game.id);
      setState(() {});
    }
  }
}

class _GameList extends StatelessWidget {
  const _GameList({
    required this.futureGames,
    required this.emptyMessage,
    required this.onGameTap,
    required this.onGameDelete,
  });

  final Future<List<SavedGame>> futureGames;
  final String emptyMessage;
  final void Function(SavedGame) onGameTap;
  final void Function(SavedGame) onGameDelete;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SavedGame>>(
      future: futureGames,
      builder: (content, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final games = snapshot.data ?? [];
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
          itemBuilder:(context, index) {
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
  final VoidCallback onDelete;

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
        onDelete();
        return false;
      },
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: game.isInProgress ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            game.isInProgress ? Icons.play_arrow : Icons.check,
            color: game.isInProgress ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
          ),
        ),
        title: Text(
          game.opponentName ?? game.mode.displayName,
          style: theme.textTheme.titleMedium,
        ),
        subtitle: Text(
          '${game.moves.length} moves - ${_formatDate(game.updatedAt)}',
          style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        trailing: game.isCompleted ? _buildResultBadge(context) : const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  Widget _buildResultBadge(BuildContext context) {
    final theme = Theme.of(context);
    String text;
    Color color;

    if (game.winnerIndex == null) {
      text = 'Draw';
      color = theme.colorScheme.secondary;
    } else if (game.winnerIndex == 0) {
      text = 'White';
      color = Colors.grey;
    } else {
      text = 'Black';
      color = Colors.black87;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${date.day}/${date.month}/${date.year}';
  }
}
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
  final Set<String> _selectedGameIds = <String>{};

  bool get _isSelectionMode => _selectedGameIds.isNotEmpty;

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
    final allGames = ref.watch(savedGamesProvider).when(
      loading: () => const <SavedGame>[],
      error: (_, _) => const <SavedGame>[],
      data: (games) => games,
    );

    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isSelectionMode) _cancelSelection();
      },
      child: Scaffold(
        appBar: _buildAppBar(allGames),
        body: TabBarView(
          controller: _tabController,
          children: [
            _GameList(
              games: ref.watch(inProgressGamesProvider),
              emptyMessage: 'No games in progress',
              isSelectionMode: _isSelectionMode,
              selectedGameIds: _selectedGameIds,
              onGameTap: (game) => _resumeGame(game),
              onGameLongPress: (game) => _startSelection(game),
              onGameSelectionToggle: (game) => _toggleSelection(game.id),
              onGameDelete: (game) => _deleteGame(game),
            ),
            _GameList(
              games: ref.watch(completedGamesProvider),
              emptyMessage: 'No completed games',
              isSelectionMode: _isSelectionMode,
              selectedGameIds: _selectedGameIds,
              onGameTap: (game) => _viewGame(game),
              onGameLongPress: (game) => _startSelection(game),
              onGameSelectionToggle: (game) => _toggleSelection(game.id),
              onGameDelete: (game) => _deleteGame(game),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(List<SavedGame> allGames) {
    final areAllGamesSelected =
        allGames.isNotEmpty &&
        allGames.every((game) => _selectedGameIds.contains(game.id));

    return AppBar(
      leading: _isSelectionMode
          ? IconButton(
              tooltip: 'Cancel selection',
              onPressed: _cancelSelection,
              icon: const Icon(Icons.close),
            )
          : null,
      title: Text(
        _isSelectionMode
            ? '${_selectedGameIds.length} selected'
            : 'Game History',
      ),
      centerTitle: true,
      actions: _isSelectionMode
          ? [
              IconButton(
                tooltip: 'Select all',
                onPressed: areAllGamesSelected
                    ? null
                    : () => _selectAllGames(allGames),
                icon: const Icon(Icons.select_all),
              ),
              IconButton(
                tooltip: 'Delete selected games',
                onPressed: _deleteSelectedGames,
                icon: const Icon(Icons.delete),
              ),
            ]
          : null,
      bottom: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'In Progress'),
          Tab(text: 'Completed'),
        ],
      ),
    );
  }

  void _startSelection(SavedGame game) {
    if (_isSelectionMode) {
      _toggleSelection(game.id);
      return;
    }

    setState(() {
      _selectedGameIds.add(game.id);
    });
  }

  void _toggleSelection(String gameId) {
    setState(() {
      if (!_selectedGameIds.add(gameId)) {
        _selectedGameIds.remove(gameId);
      }
    });
  }

  void _selectAllGames(List<SavedGame> games) {
    setState(() {
      _selectedGameIds.addAll(games.map((game) => game.id));
    });
  }

  void _cancelSelection() {
    setState(_selectedGameIds.clear);
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

  Future<void> _deleteSelectedGames() async {
    final selectedGameIds = _selectedGameIds.toList(growable: false);
    final count = selectedGameIds.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Games'),
        content: Text(
          'Are you sure you want to delete $count selected ${count == 1 ? 'game' : 'games'}?',
        ),
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

    if (confirmed != true || !mounted) return;

    await ref
        .read(savedGamesControllerProvider.notifier)
        .deleteGames(selectedGameIds);

    if (mounted) _cancelSelection();
  }
}

class _GameList extends StatelessWidget {
  const _GameList({
    required this.games,
    required this.emptyMessage,
    required this.isSelectionMode,
    required this.selectedGameIds,
    required this.onGameTap,
    required this.onGameLongPress,
    required this.onGameSelectionToggle,
    required this.onGameDelete,
  });

  final AsyncValue<List<SavedGame>> games;
  final String emptyMessage;
  final bool isSelectionMode;
  final Set<String> selectedGameIds;
  final void Function(SavedGame) onGameTap;
  final void Function(SavedGame) onGameLongPress;
  final void Function(SavedGame) onGameSelectionToggle;
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
              isSelectionMode: isSelectionMode,
              isSelected: selectedGameIds.contains(game.id),
              onTap: () {
                if (isSelectionMode) {
                  onGameSelectionToggle(game);
                } else {
                  onGameTap(game);
                }
              },
              onLongPress: () => onGameLongPress(game),
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
    required this.isSelectionMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.onDelete,
  });

  final SavedGame game;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final tile = ListTile(
      selected: isSelected,
      selectedTileColor: colorScheme.secondaryContainer,
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
      trailing: isSelectionMode
          ? Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            )
          : game.isCompleted
          ? _buildResultBadge(context)
          : const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
      onLongPress: onLongPress,
    );

    if (isSelectionMode) return tile;

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
      child: tile,
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
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colorScheme.inverseSurface),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: colorScheme.inverseSurface,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

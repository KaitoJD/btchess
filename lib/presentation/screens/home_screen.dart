import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/game_provider.dart';
import '../../application/providers/persistence_provider.dart';
import '../../application/providers/saved_games_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/extensions/datetime_extensions.dart';
import '../../domain/models/game_mode.dart';
import '../../domain/models/saved_game.dart';
import '../routes/app_router.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Spacer(),
              _buildHeader(context),
              const Spacer(flex: 2),
              _buildMainActions(context, ref),
              const Spacer(),
              _buildResumeGameCard(context, ref),
              const Spacer(flex: 2),
              _buildBottomNav(context),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.grid_on,
            size: 50,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          AppConstants.appName,
          style: theme.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Bluetooth Chess',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildMainActions(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.modeSelection);
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('New Game'),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton.icon(
            onPressed: () => _startQuickGame(context, ref),
            icon: const Icon(Icons.people),
            label: const Text('Quick Play (Local)'),
          ),
        ),
      ],
    );
  }

  Widget _buildResumeGameCard(BuildContext context, WidgetRef ref) {
    final recentGame = ref.watch(mostRecentGameProvider);

    return recentGame.maybeWhen(
      data: (savedGame) {
        if (savedGame == null) return const SizedBox.shrink();

        final theme = Theme.of(context);

        return Card(
          child: InkWell(
            onTap: () => _resumeGame(context, ref, savedGame),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.history,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Resume Game',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${savedGame.moves.length} moves - ${savedGame.updatedAt.toRelative()}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _NavButton(
          icon: Icons.history,
          label: 'History',
          onTap: () => Navigator.of(context).pushNamed(AppRoutes.history),
        ),
        _NavButton(
          icon: Icons.settings,
          label: 'Settings',
          onTap: () => Navigator.of(context).pushNamed(AppRoutes.settings),
        ),
      ],
    );
  }

  void _startQuickGame(BuildContext context, WidgetRef ref) {
    ref.read(gameControllerProvider.notifier).newGame(mode: GameMode.hotseat);
    Navigator.of(context).pushNamed(AppRoutes.game);
  }

  void _resumeGame(BuildContext context, WidgetRef ref, SavedGame savedGame) {
    ref.read(savedGamesControllerProvider.notifier).resumeGame(savedGame);
    Navigator.of(context).pushNamed(AppRoutes.game);
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

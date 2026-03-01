import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/game_provider.dart';
import '../../domain/enums/game_end_reason.dart';
import '../../domain/enums/winner.dart';
import '../../domain/models/game_mode.dart';
import '../../domain/models/game_result.dart';
import '../routes/app_router.dart';

// Arguments passed to the [GameOverScreen] via route navigation.
class GameOverScreenArgs {
  const GameOverScreenArgs({
    required this.result,
    required this.mode,
    required this.moveCount,
    this.pgn,
    this.whitePlayerName,
    this.blackPlayerName,
  });

  final GameResult result;
  final GameMode mode;
  final int moveCount;
  final String? pgn;
  final String? whitePlayerName;
  final String? blackPlayerName;
}

class GameOverScreen extends ConsumerWidget {
  const GameOverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = ModalRoute.of(context)!.settings.arguments as GameOverScreenArgs;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleHome(context, ref);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Game Over'),
          centerTitle: true,
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 16),
                          _buildResultIcon(args.result, colorScheme),
                          const SizedBox(height: 24),
                          _buildResultTitle(args.result, theme),
                          const SizedBox(height: 8),
                          _buildResultSubtitle(args.result, theme, colorScheme),
                          const SizedBox(height: 24),
                          _buildGameInfo(args, theme, colorScheme),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
                _buildActionButtons(context, ref, args, theme, colorScheme),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultIcon(GameResult result, ColorScheme colorScheme) {
    IconData icon;
    Color color;

    if (result.isDraw) {
      icon = Icons.handshake_outlined;
      color = colorScheme.tertiary;
    } else {
      icon = Icons.emoji_events_outlined;
      color = colorScheme.primary;
    }

    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 48, color: color),
    );
  }

  Widget _buildResultTitle(GameResult result, ThemeData theme) {
    final title = switch (result.winner) {
      Winner.white => 'White Wins!',
      Winner.black => 'Black Wins!',
      Winner.draw => 'Draw',
    };

    return Text(
      title,
      style: theme.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.bold,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildResultSubtitle(GameResult result, ThemeData theme, ColorScheme colorScheme) {
    final subtitle = switch (result.reason) {
      GameEndReason.checkmate => 'by Checkmate',
      GameEndReason.resign => 'by Resignation',
      GameEndReason.timeout => 'on Time',
      GameEndReason.stalemate => 'by Stalemate',
      GameEndReason.drawAgreement => 'by Agreement',
      GameEndReason.insufficientMaterial => 'Insufficient Material',
      GameEndReason.fiftyMoveRule => '50-Move Rule',
      GameEndReason.threefoldRepetition => 'Threefold Repetition',
      GameEndReason.disconnect => 'Opponent Disconnected',
    };

    return Text(
      subtitle,
      style: theme.textTheme.titleMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildGameInfo(GameOverScreenArgs args, ThemeData theme, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInfoRow(
              icon: Icons.swap_vert,
              label: 'Total Moves',
              value: '${args.moveCount}',
              theme: theme,
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.scoreboard_outlined,
              label: 'Result',
              value: args.result.pgnResult,
              theme: theme,
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.videogame_asset_outlined,
              label: 'Mode',
              value: args.mode.displayName,
              theme: theme,
              colorScheme: colorScheme,
            ),
            if (args.whitePlayerName != null || args.blackPlayerName != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                icon: Icons.people_outline,
                label: 'Players',
                value: '${args.whitePlayerName ?? 'White'} vs ${args.blackPlayerName ?? 'Black'}',
                theme: theme,
                colorScheme: colorScheme,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    WidgetRef ref,
    GameOverScreenArgs args,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: () => _handleRematch(context, ref),
          icon: const Icon(Icons.replay),
          label: const Text('Rematch'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => _handleNewGame(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('New Game'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 10),
        if (args.pgn != null && args.pgn!.isNotEmpty)
          TextButton.icon(
            onPressed: () => _handleViewPgn(context, args.pgn!),
            icon: const Icon(Icons.description_outlined),
            label: const Text('View PGN'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        TextButton.icon(
          onPressed: () => _handleHome(context, ref),
          icon: const Icon(Icons.home_outlined),
          label: const Text('Home'),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  void _handleRematch(BuildContext context, WidgetRef ref) {
    ref.read(gameControllerProvider.notifier).resetGame();
    AppRouter.navigateAndReplace(context, AppRoutes.game);
  }

  void _handleNewGame(BuildContext context, WidgetRef ref) {
    ref.read(gameControllerProvider.notifier).endSession();
    AppRouter.navigateAndReplace(context, AppRoutes.modeSelection);
  }

  void _handleViewPgn(BuildContext context, String pgn) {
    AppRouter.navigateTo(context, AppRoutes.pgnViewer, arguments: PgnViewerScreenArgs(pgn: pgn));
  }

  void _handleHome(BuildContext context, WidgetRef ref) {
    ref.read(gameControllerProvider.notifier).endSession();
    AppRouter.navigateAndClear(context, AppRoutes.home);
  }
}

// Arguments passed to the PGN Viewer screen via route navigation.
class PgnViewerScreenArgs {
  const PgnViewerScreenArgs({
    required this.pgn,
    this.title,
  });

  final String pgn;
  final String? title;
}

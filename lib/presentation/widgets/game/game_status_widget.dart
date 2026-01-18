import 'package:flutter/material.dart';
import '../../../domain/enums/game_end_reason.dart';
import '../../../domain/enums/game_status.dart';
import '../../../domain/enums/winner.dart';
import '../../../domain/models/game_result.dart';
import '../../../domain/models/piece.dart';

class GameStatusWidget extends StatelessWidget {
  final GameStatus status;
  final GameResult? result;
  final PieceColor currentTurn;
  final bool asBanner;

  const GameStatusWidget({
    super.key,
    required this.status,
    this.result,
    required this.currentTurn,
    this.asBanner = false,
  });

  @override
  Widget build(BuildContext context) {
    if (result != null) {
      return _buildEndedStatus(context);
    }

    return _buildInProgressStatus(context);
  }

  Widget _buildInProgressStatus(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    String statusText;
    Color? backgroundColor;
    Color? textColor;

    switch (status) {
      case GameStatus.check:
        statusText = '${currentTurn.name.toUpperCase()} is in CHECK';
        backgroundColor = colorScheme.errorContainer;
        textColor = colorScheme.onErrorContainer;
        break;
      case GameStatus.playing:
        statusText = "${currentTurn.name.toUpperCase()}'s turn";
        break;
      default:
        statusText = status.name;
    }

    if (asBanner && status == GameStatus.check) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8),
        color: backgroundColor,
        child: Text(
          statusText,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Text(
      statusText,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: textColor,
        fontWeight: status == GameStatus.check ? FontWeight.bold : null
      ),
    );
  }

  Widget _buildEndedStatus(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final (title, subtitle) = _getResultText();

    if (asBanner) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        color: colorScheme.surfaceContainerHighest,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        if (subtitle.isNotEmpty)
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }

  (String title, String subtitle) _getResultText() {
    if (result == null) return ('Game Over', '');

    String title;
    String subtitle = '';

    switch (result!.winner) {
      case Winner.white:
        title = 'White Wins!';
        break;
      case Winner.black:
        title = 'Black Wins!';
        break;
      default:
        title = 'Draw';
        break;
    }

    switch (result!.reason) {
      case GameEndReason.checkmate:
        subtitle = 'by Checkmate';
        break;
      case GameEndReason.resign:
        subtitle = 'by Resination';
        break;
      case GameEndReason.timeout:
        subtitle = 'on Time';
        break;
      case GameEndReason.stalemate:
        subtitle = 'by Stalemate';
        break;
      case GameEndReason.drawAgreement:
        subtitle = 'by Agreement';
        break;
      case GameEndReason.insufficientMaterial:
        subtitle = 'Insufficient Material';
        break;
      case GameEndReason.fiftyMoveRule:
        subtitle = '50-Move Rule';
        break;
      case GameEndReason.threefoldRepetition:
        subtitle = 'Threefold Repetition';
        break;
      case GameEndReason.disconnect:
        subtitle = 'Opponent Disconnected';
        break;
    }

    return (title, subtitle);
  }
}
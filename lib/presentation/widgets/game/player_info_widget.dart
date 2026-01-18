import 'package:flutter/material.dart';
import '../../../domain/models/piece.dart';
import '../../../domain/models/player.dart';

class PlayerInfoWidget extends StatelessWidget {
  final Player player;
  final bool isActive;
  final bool isInCheck;
  final List<Piece> capturedPieces;
  final int materialAdvantage;
  final bool isTopPlayer;

  const PlayerInfoWidget({
    super.key,
    required this.player,
    this.isActive = false,
    this.isInCheck = false,
    this.capturedPieces = const [],
    this.materialAdvantage = 0,
    this.isTopPlayer = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? colorScheme.primaryContainer.withValues(alpha: 0.3) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isActive ? Border.all(color: colorScheme.primary, width: 2) : Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          _buildColorIndicator(colorScheme),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        player.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isInCheck) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.error,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'CHECK',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onError,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (capturedPieces.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _buildCapturedPieces(theme),
                ],
              ],
            ),
          ),
          if (materialAdvantage > 0) ...[
            const SizedBox(width: 8),
            Text(
              '+$materialAdvantage',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              )
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildColorIndicator(ColorScheme colorScheme) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: player.color == PieceColor.white ? Colors.white : Colors.black,
        border: Border.all(
          color: colorScheme.outline,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }

  Widget _buildCapturedPieces(ThemeData theme) {
    final pieceSymbols = capturedPieces.map((p) => p.symbol).join();

    return Text(
      pieceSymbols,
      style: theme.textTheme.bodySmall?.copyWith(
        fontSize: 14,
        letterSpacing: -1,
      ),
    );
  }
}
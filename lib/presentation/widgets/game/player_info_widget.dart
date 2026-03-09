import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../domain/models/piece.dart';
import '../../../domain/models/player.dart';
import '../../../infrastructure/persistence/settings_repository.dart';
import '../../themes/piece_themes.dart';

class PlayerInfoWidget extends StatelessWidget {

  const PlayerInfoWidget({
    required this.player, super.key,
    this.isActive = false,
    this.isInCheck = false,
    this.capturedPieces = const [],
    this.materialAdvantage = 0,
    this.isTopPlayer = false,
    this.pieceTheme = PieceTheme.standard,
  });
  final Player player;
  final bool isActive;
  final bool isInCheck;
  final List<Piece> capturedPieces;
  final int materialAdvantage;
  final bool isTopPlayer;
  final PieceTheme pieceTheme;

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
                const SizedBox(height: 4),
                capturedPieces.isNotEmpty
                    ? _buildCapturedPieces(theme)
                    : SizedBox(height: theme.textTheme.bodySmall?.fontSize ?? 14),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Opacity(
            opacity: materialAdvantage > 0 ? 1.0 : 0.0,
            child: Text(
              '+$materialAdvantage',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
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

  static const _pieceOrder = {
    PieceType.pawn: 0,
    PieceType.knight: 1,
    PieceType.bishop: 2,
    PieceType.rook: 3,
    PieceType.queen: 4,
  };

  Widget _buildCapturedPieces(ThemeData theme) {
    final sorted = List<Piece>.from(capturedPieces)
      ..sort((a, b) => (_pieceOrder[a.type] ?? 0) - (_pieceOrder[b.type] ?? 0));

    final groups = <List<Piece>>[];
    for (final piece in sorted) {
      if (groups.isEmpty || groups.last.first.type != piece.type) {
        groups.add([piece]);
      } else {
        groups.last.add(piece);
      }
    }

    const double pieceSize = 16;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < groups.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          for (final piece in groups[i])
            SvgPicture.asset(
              PieceThemes.getAssetPath(pieceTheme, piece),
              width: pieceSize,
              height: pieceSize,
            ),
        ],
      ],
    );
  }
}
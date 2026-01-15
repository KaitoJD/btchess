import 'package:flutter/material.dart';
import '../../../domain/models/piece.dart';
import '../../../domain/models/square.dart';
import '../../themes/board_themes.dart';
import 'piece_widget.dart';

class SquareDragData {
  final Square square;
  final Piece piece;

  const SquareDragData({
    required this.square,
    required this.piece,
  });
}

class SquareWidget extends StatelessWidget {
  final Square square;
  final Piece? piece;
  final double size;
  final BoardThemesColors theme;
  final bool isSelected;
  final bool isLegalMove;
  final bool isLastMove;
  final bool isCheck;
  final bool canDrag;
  final bool showFileCoordinate;
  final bool showRankCoordinate;
  final bool isFlipped;
  final VoidCallback? onTap;
  final VoidCallback? onDragStarted;
  final VoidCallback? onDragEnd;
  final void Function(SquareDragData)? onPieceDropped;

  const SquareWidget({
    super.key,
    required this.square,
    required this.size,
    required this.theme,
    this.piece,
    this.isSelected = false,
    this.isLegalMove = false,
    this.isLastMove = false,
    this.isCheck = false,
    this.canDrag = false,
    this.showFileCoordinate = false,
    this.showRankCoordinate = false,
    this.isFlipped = false,
    this.onTap,
    this.onDragStarted,
    this.onDragEnd,
    this.onPieceDropped,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<SquareDragData>(
      onWillAcceptWithDetails: (details) => onPieceDropped != null,
      onAcceptWithDetails: (details) => onPieceDropped?.call(details.data),
      builder: (context, candidateData, rejectedData) {
        final isDropTarget = candidateData.isNotEmpty;

        return GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: _getBackgroundColor(isDropTarget),
            ),
            child: Stack(
              children: [
                if (isSelected || isLastMove || isCheck || isDropTarget) _buildHighlightOverlay(isDropTarget),
                if (isLegalMove) _buildLegalMoveIndicator(),
                if (piece != null) _buildPiece(),
                if (showFileCoordinate || showRankCoordinate) _buildCoordinates(),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getBackgroundColor(bool isDropTarget) {
    final baseColor = theme.squareColor(square.file, square.rank);

    if (isDropTarget) {
      return Color.alphaBlend(theme.legalMove, baseColor);
    }

    return baseColor;
  }

  Widget _buildHighlightOverlay(bool isDropTarget) {
    Color overlayColor;

    if (isCheck) {
      overlayColor = theme.check;
    } else if (isSelected) {
      overlayColor = theme.selection;
    } else if (isLastMove) {
      overlayColor = theme.lastMove;
    } else if (isDropTarget) {
      overlayColor = theme.legalMove;
    } else {
      overlayColor = Colors.transparent;
    }

    return Container(
      width: size,
      height: size,
      color: overlayColor,
    );
  }

  Widget _buildLegalMoveIndicator() {
    if (piece != null) {
      return Center(
        child: Container(
          width: size * 0.9,
          height: size * 0.9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: theme.legalMove.withValues(alpha: 0.8),
              width: size * 0.08,
            ),
          ),
        ),
      );
    } else {
      return Center(
        child: Container(
          width: size * 0.3,
          height: size * 0.3,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.legalMove.withValues(alpha: 0.8),
          ),
        ),
      );
    }
  }

  Widget _buildPiece() {
    if (piece == null) return const SizedBox.shrink();

    if (canDrag) {
      return DraggablePieceWidget(
        piece: piece!,
        size: size,
        canDrag: true,
        dragData: SquareDragData(square: square, piece: piece!),
        onDragStarted: onDragStarted,
        onDragEnd: onDragEnd,
      );
    }

    return PieceWidget(piece: piece!, size: size);
  }

  Widget _buildCoordinates() {
    return Stack(
      children: [
        if (showFileCoordinate) 
          Positioned(
            right: 2,
            bottom: 1,
            child: Text(
              square.fileLetter,
              style: TextStyle(
                fontSize: size * 0.15,
                fontWeight: FontWeight.bold,
                color: square.isLight ? theme.darkSquare.withValues(alpha: 0.8) : theme.lightSquare.withValues(alpha: 0.8),
              ),
            ),
          ),
        if (showRankCoordinate) 
          Positioned(
            left: 2,
            top: 1,
            child: Text(
              square.fileLetter,
              style: TextStyle(
                fontSize: size * 0.15,
                fontWeight: FontWeight.bold,
                color: square.isLight ? theme.darkSquare.withValues(alpha: 0.8) : theme.lightSquare.withValues(alpha: 0.8),
              ),
            ),
          ),
      ],
    );
  }
}
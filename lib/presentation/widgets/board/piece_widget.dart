import 'package:flutter/material.dart';
import '../../../domain/models/piece.dart';
import '../../themes/piece_themes.dart';

class PieceWidget extends StatelessWidget {
  final Piece piece;
  final double size;
  final bool isDragging;
  final double opacity;

  const PieceWidget({
    super.key,
    required this.piece,
    required this.size,
    this.isDragging = false,
    this.opacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isDragging ? 0.3 : opacity,
      duration: const Duration(milliseconds: 150),
      child: Center(
        child: Text(
          PieceThemes.getSymbol(piece),
          style: PieceThemes.getSymbolStyle(size: size, color: piece.color),
        ),
      ),
    );
  }
}

class DraggablePieceWidget extends StatelessWidget {
  final Piece piece;
  final double size;
  final bool canDrag;
  final VoidCallback? onDragStarted;
  final VoidCallback? onDragEnd;
  final VoidCallback? onDraggableCanceled;
  final Object? dragData;

  const DraggablePieceWidget({
    super.key,
    required this.piece,
    required this.size,
    this.canDrag = true,
    this.onDragStarted,
    this.onDragEnd,
    this.onDraggableCanceled,
    this.dragData,
  });

  @override
  Widget build(BuildContext context) {
    if (!canDrag) {
      return PieceWidget(piece: piece, size: size);
    }

    return Draggable<Object>(
      data: dragData ?? piece,
      onDragStarted: onDragStarted,
      onDragEnd: (_) => onDragEnd?.call(),
      onDraggableCanceled: (_, __) => onDraggableCanceled?.call(),
      feedback: Material(
        color: Colors.transparent,
        child: Transform.scale(
          scale: 1.2,
          child: PieceWidget(piece: piece, size: size),
        ),
      ),
      childWhenDragging: PieceWidget(piece: piece, size: size, isDragging: true),
      child: PieceWidget(piece: piece, size: size),
    );
  }
}
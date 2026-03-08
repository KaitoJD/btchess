import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../domain/models/piece.dart';
import '../../../infrastructure/persistence/settings_repository.dart';
import '../../themes/piece_themes.dart';

class PieceWidget extends StatelessWidget {

  const PieceWidget({
    required this.piece, required this.size, required this.pieceTheme, super.key,
    this.isDragging = false,
    this.opacity = 1.0,
  });
  final Piece piece;
  final double size;
  final PieceTheme pieceTheme;
  final bool isDragging;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final assetPath = PieceThemes.getAssetPath(pieceTheme, piece);
    return AnimatedOpacity(
      opacity: isDragging ? 0.3 : opacity,
      duration: const Duration(milliseconds: 150),
      child: Center(
        child: SvgPicture.asset(
          assetPath,
          width: size * 0.85,
          height: size * 0.85,
        ),
      ),
    );
  }
}

class DraggablePieceWidget extends StatelessWidget {

  const DraggablePieceWidget({
    required this.piece, required this.size, required this.pieceTheme, super.key,
    this.canDrag = true,
    this.onDragStarted,
    this.onDragEnd,
    this.onDraggableCanceled,
    this.dragData,
  });
  final Piece piece;
  final double size;
  final PieceTheme pieceTheme;
  final bool canDrag;
  final VoidCallback? onDragStarted;
  final VoidCallback? onDragEnd;
  final VoidCallback? onDraggableCanceled;
  final Object? dragData;

  @override
  Widget build(BuildContext context) {
    if (!canDrag) {
      return PieceWidget(piece: piece, size: size, pieceTheme: pieceTheme);
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
          child: PieceWidget(piece: piece, size: size, pieceTheme: pieceTheme),
        ),
      ),
      childWhenDragging: PieceWidget(piece: piece, size: size, pieceTheme: pieceTheme, isDragging: true),
      child: PieceWidget(piece: piece, size: size, pieceTheme: pieceTheme),
    );
  }
}
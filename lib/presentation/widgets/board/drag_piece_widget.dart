import 'package:flutter/material.dart';
import '../../../domain/models/piece.dart';
import '../../../domain/models/square.dart';
import 'piece_widget.dart';
import 'square_widget.dart';

class DragPieceOverlay extends StatelessWidget {
  final Piece piece;
  final Offset position;
  final double size;

  const DragPieceOverlay({
    super.key,
    required this.piece,
    required this.position,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx - size / 2,
      top: position.dy - size / 2,
      child: IgnorePointer(
        child: Transform.scale(
          scale: 1.2,
          child: PieceWidget(
            piece: piece,
            size: size,
          ),
        ),
      ),
    );
  }
}

class DragState {
  final Square fromSquare;
  final Piece piece;
  final Offset position;

  const DragState({
    required this.fromSquare,
    required this.piece,
    required this.position,
  });

  DragState copyWith({
    Square? fromSquare,
    Piece? piece,
    Offset? position,
  }) {
    return DragState(
      fromSquare: fromSquare ?? this.fromSquare,
      piece: piece ?? this.piece,
      position: position ?? this.position,
    );
  }

  SquareDragData toDragData() {
    return SquareDragData(square: fromSquare, piece: piece);
  }
}
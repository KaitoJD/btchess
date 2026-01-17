import 'package:flutter/material.dart';
import '../../../domain/enums/promotion_piece.dart';
import '../../../domain/models/piece.dart';
import '../../themes/piece_themes.dart';

class PromotionDialog extends StatelessWidget {
  final PieceColor color;
  final void Function(PromotionPiece) onPieceSelected;
  final VoidCallback? onCancelled;

  const PromotionDialog({
    super.key,
    required this.color,
    required this.onPieceSelected,
    this.onCancelled,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Promote to'),
      contentPadding: const EdgeInsets.all(16),
      content: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: PromotionPiece.values.map((promotionPiece) {
          return _PromotionOption(
            piece: Piece(type: _getPieceType(promotionPiece), color: color),
            onTap: () => onPieceSelected(promotionPiece),
          );
        }).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onCancelled?.call();
          },
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  PieceType _getPieceType(PromotionPiece promotionPiece) {
    switch (promotionPiece) {
      case PromotionPiece.queen:
      return PieceType.queen;
      case PromotionPiece.rook:
      return PieceType.rook;
      case PromotionPiece.bishop:
      return PieceType.bishop;
      case PromotionPiece.knight:
      return PieceType.knight;
    }
  }
}

class _PromotionOption extends StatelessWidget {
  final Piece piece;
  final VoidCallback onTap;
  
  const _PromotionOption({
    required this.piece,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Text(
          PieceThemes.getSymbol(piece),
          style: PieceThemes.getSymbolStyle(size: 60, color: piece.color),
        ),
      ),
    );
  }
}

Future<PromotionPiece?> showPromotionDialog(BuildContext context, {required PieceColor color}) async {
  PromotionPiece? selected;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PromotionDialog(
      color: color,
      onPieceSelected: (piece) => {
        selected = piece,
        Navigator.of(context).pop,
      },
      onCancelled: () {
        selected = null;
      },
    ),
  );

  return selected;
}
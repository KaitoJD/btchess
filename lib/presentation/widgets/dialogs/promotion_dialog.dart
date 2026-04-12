import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../domain/enums/promotion_piece.dart';
import '../../../domain/models/piece.dart';
import '../../../infrastructure/persistence/settings_repository.dart';
import '../../themes/piece_themes.dart';

class PromotionDialog extends StatelessWidget {

  const PromotionDialog({
    required this.color, required this.onPieceSelected, required this.pieceTheme, super.key,
    this.onCancelled,
  });
  final PieceColor color;
  final PieceTheme pieceTheme;
  final void Function(PromotionPiece) onPieceSelected;
  final VoidCallback? onCancelled;

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
            pieceTheme: pieceTheme,
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
  
  const _PromotionOption({
    required this.piece,
    required this.pieceTheme,
    required this.onTap,
  });
  final Piece piece;
  final PieceTheme pieceTheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final assetPath = PieceThemes.getAssetPath(pieceTheme, piece);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        child: SvgPicture.asset(
          assetPath,
          width: 48,
          height: 48,
        ),
      ),
    );
  }
}

Future<PromotionPiece?> showPromotionDialog(BuildContext context, {required PieceColor color, required PieceTheme pieceTheme}) async {
  PromotionPiece? selected;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PromotionDialog(
      color: color,
      pieceTheme: pieceTheme,
      onPieceSelected: (piece) => {
        selected = piece,
        Navigator.of(context).pop(),
      },
      onCancelled: () {
        selected = null;
      },
    ),
  );

  return selected;
}
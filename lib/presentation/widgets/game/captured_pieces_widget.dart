import 'package:flutter/material.dart';
import '../../../domain/models/move.dart';
import '../../../domain/models/piece.dart';

class CapturedPiecesWidget extends StatelessWidget {
  final List<Move> moves;
  final PieceColor capturedByColor;
  final double pieceSize;

  const CapturedPiecesWidget({
    super.key,
    required this.moves,
    required this.capturedByColor,
    this.pieceSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    final capturedPieces = _getCapturedPieces();

    if (capturedPieces.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: -2,
      children: capturedPieces.map((piece) {
        return Text(
          piece.symbol,
          style: TextStyle(fontSize: pieceSize),
        );
      }).toList(),
    );
  }

  List<Piece> _getCapturedPieces() {
    final captured = <Piece>[];

    for (final move in moves) {
      if (move.capturedPiece != null) {
        if (move.capturedPiece!.color != capturedByColor) {
          captured.add(move.capturedPiece!);
        }
      }
    }

    captured.sort((a, b) => _pieceValue(b.type) - _pieceValue(a.type));

    return captured;
  }

  int _pieceValue(PieceType type) {
    switch (type) {
      case PieceType.queen:
      return 9;
      case PieceType.rook:
      return 5;
      case PieceType.bishop:
      case PieceType.knight:
      return 3;
      case PieceType.pawn:
      return 1;
      case PieceType.king:
      return 0;
    }
  }
}

int caculateMaterialBalance(List<Move> moves) {
  int balance = 0;

  for (final move in moves) {
    if (move.capturedPiece != null) {
      final value = _pieceValueStatic(move.capturedPiece!.type);
      if (move.capturedPiece!.color == PieceColor.black) {
        balance += value;
      } else {
        balance -= value;
      }
    }
  }

  return balance;
}

int _pieceValueStatic(PieceType type) {
  switch (type) {
    case PieceType.queen:
    return 9;
    case PieceType.rook:
    return 5;
    case PieceType.bishop:
    case PieceType.knight:
    return 3;
    case PieceType.pawn:
    return 1;
    case PieceType.king:
    return 0;
  } 
}
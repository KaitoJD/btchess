import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chess_piece.dart';
import '../models/position.dart';
import '../providers/game_provider.dart';

class ChessBoardWidget extends StatelessWidget {
  const ChessBoardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, gameProvider, child) {
        return AspectRatio(
          aspectRatio: 1.0,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.brown, width: 4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
              ),
              itemCount: 64,
              itemBuilder: (context, index) {
                int row = index ~/ 8;
                int col = index % 8;
                Position position = Position(row, col);
                
                return _buildSquare(context, position, gameProvider);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildSquare(BuildContext context, Position position, GameProvider gameProvider) {
    bool isLightSquare = (position.row + position.col) % 2 == 0;
    bool isSelected = gameProvider.selectedPosition == position;
    bool isValidMove = gameProvider.validMoves.contains(position);
    bool isInCheck = false;
    
    ChessPiece? piece = gameProvider.chessBoard.getPieceAt(position);
    
    // Check if this square contains a king in check
    if (piece != null && piece.type == PieceType.king) {
      isInCheck = gameProvider.chessBoard.isInCheck(piece.color);
    }

    Color squareColor = _getSquareColor(isLightSquare, isSelected, isValidMove, isInCheck);

    return GestureDetector(
      onTap: () => gameProvider.selectSquare(position),
      child: Container(
        decoration: BoxDecoration(
          color: squareColor,
          border: isValidMove 
              ? Border.all(color: Colors.green, width: 3)
              : null,
        ),
        child: Stack(
          children: [
            // Coordinate labels
            if (position.col == 0) // Left edge - row labels
              Positioned(
                left: 2,
                top: 2,
                child: Text(
                  '${8 - position.row}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isLightSquare ? Colors.brown[700] : Colors.brown[200],
                  ),
                ),
              ),
            if (position.row == 7) // Bottom edge - column labels
              Positioned(
                right: 2,
                bottom: 2,
                child: Text(
                  String.fromCharCode(97 + position.col),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isLightSquare ? Colors.brown[700] : Colors.brown[200],
                  ),
                ),
              ),
            // Chess piece
            if (piece != null)
              Center(
                child: Text(
                  piece.symbol,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            // Valid move indicator
            if (isValidMove && piece == null)
              Center(
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.7),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            // Capture indicator
            if (isValidMove && piece != null)
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.red, width: 4),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getSquareColor(bool isLightSquare, bool isSelected, bool isValidMove, bool isInCheck) {
    if (isInCheck) {
      return Colors.red.withOpacity(0.8);
    }
    if (isSelected) {
      return Colors.blue.withOpacity(0.6);
    }
    if (isValidMove) {
      return isLightSquare 
          ? Colors.green.withOpacity(0.3)
          : Colors.green.withOpacity(0.4);
    }
    return isLightSquare ? Colors.brown[200]! : Colors.brown[600]!;
  }
}

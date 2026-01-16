import 'package:flutter/material.dart';
import '../../../domain/models/move.dart';
import '../../../domain/models/piece.dart';
import '../../../domain/models/square.dart';
import '../../themes/board_themes.dart';
import 'board_coordinates_widget.dart';
import 'square_widget.dart';

typedef OnMoveCallBack = void Function(Square from, Square to);
typedef OnSquareSelectedCallBack = void Function(Square square);

class BoardWidget extends StatefulWidget {
  final Map<int, Piece> pieces;
  final Square? selectedSquare;
  final List<Square> legalMoves;
  final Move? lastMove;
  final Square? checkSquare;
  final bool isFlipped;
  final bool showCoordinates;
  final bool interactive;
  final PieceColor? interactiveColor;
  final BoardThemesColors theme;
  final OnMoveCallBack? onMove;
  final OnSquareSelectedCallBack? onSquareSelected;
  final double? size;

  const BoardWidget({
    super.key,
    required this.pieces,
    this.selectedSquare,
    this.legalMoves = const [],
    this.lastMove,
    this.checkSquare,
    this.isFlipped = false,
    this.showCoordinates = true,
    this.interactive = true,
    this.interactiveColor,
    this.theme = BoardThemesColors.classic,
    this.onMove,
    this.onSquareSelected,
    this.size,
  });

  @override
  State<BoardWidget> createState() => _BoardWidgetState();
}

class _BoardWidgetState extends State<BoardWidget> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constrains) {
        final availableSize = widget.size ?? (constrains.maxWidth < constrains.maxHeight ? constrains.maxWidth : constrains.maxHeight);
        final coordinatePadding = widget.showCoordinates ? 20.0 : 0.0;
        final boardSize = availableSize - coordinatePadding;
        final squareSize = boardSize / 8;
        final board = _buildBoard(squareSize);

        if (widget.showCoordinates) {
          return BoardCoordinatesWidget(
            squareSize: squareSize,
            isFlipped: widget.isFlipped,
            theme: widget.theme,
            coordinatePadding: coordinatePadding,
            child: board,
          );
        }

        return board;
      },
    );
  }

  Widget _buildBoard(double squareSize) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: widget.theme.border,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(8, (rowIndex) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(8, (colIndex) {
              final file = widget.isFlipped ? 7 - colIndex : colIndex;
              final rank = widget.isFlipped ? rowIndex : 7 - rowIndex;
              final square = Square(file, rank);

              return _buildSquare(square, squareSize, file, rank);
            }),
          );
        }),
      ),
    );
  }

  Widget _buildSquare(Square square, double squareSize, int file, int rank) {
    final piece = widget.pieces[square.index];
    final isSelected = widget.selectedSquare == square;
    final isLegalmove = widget.legalMoves.contains(square);
    final isLastMoveFrom = widget.lastMove?.from == square;
    final isLastMoveTo = widget.lastMove?.to == square;
    final isCheck = widget.checkSquare == square;
    final canDrag = widget.interactive && piece != null && (widget.interactiveColor == null || piece.color == widget.interactiveColor);
    final showFileCoord = widget.isFlipped ? rank == 7 : rank == 0;
    final showRankCoord = widget.isFlipped ? file == 7 : file == 0;

    return SquareWidget(
      square: square,
      size: squareSize,
      theme: widget.theme,
      piece: piece,
      isSelected: isSelected,
      isLegalMove: isLegalmove,
      isLastMove: isLastMoveFrom || isLastMoveTo,
      isCheck: isCheck,
      canDrag: canDrag,
      showFileCoordinate: !widget.showCoordinates && showFileCoord,
      showRankCoordinate: !widget.showCoordinates && showRankCoord,
      isFlipped: widget.isFlipped,
      onTap: () => _handleSquareTap(square),
      onPieceDropped: (data) => _handlePieceDrop(data, square),
      onDragStarted: () => _handleDragStart(square),
      onDragEnd: _handleDragEnd,
    );
  }

  void _handleSquareTap(Square square) {
    widget.onSquareSelected?.call(square);

    if (widget.selectedSquare != null && widget.legalMoves.contains(square) && widget.selectedSquare != square) {
      widget.onMove?.call(widget.selectedSquare!, square);
    }
  }

  void _handlePieceDrop(SquareDragData data, Square toSquare) {
    if (data.square != toSquare) {
      widget.onMove?.call(data.square, toSquare);
    }
  }

  void _handleDragStart(Square square) {
    widget.onSquareSelected?.call(square);
  }

  void _handleDragEnd() {
    widget.onSquareSelected?.call(widget.selectedSquare ?? Square(0, 0));
  }
}
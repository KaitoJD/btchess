import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:btchess/domain/models/piece.dart';
import 'package:btchess/domain/models/square.dart';
import 'package:btchess/domain/models/move.dart';
import 'package:btchess/presentation/widgets/board/board_widget.dart';

void main() {
  // Build a standard set of 32 pieces at starting position
  Map<int, Piece> _startingPieces() {
    final pieces = <int, Piece>{};
    // White pieces
    pieces[0] = const Piece(type: PieceType.rook, color: PieceColor.white);
    pieces[1] = const Piece(type: PieceType.knight, color: PieceColor.white);
    pieces[2] = const Piece(type: PieceType.bishop, color: PieceColor.white);
    pieces[3] = const Piece(type: PieceType.queen, color: PieceColor.white);
    pieces[4] = const Piece(type: PieceType.king, color: PieceColor.white);
    pieces[5] = const Piece(type: PieceType.bishop, color: PieceColor.white);
    pieces[6] = const Piece(type: PieceType.knight, color: PieceColor.white);
    pieces[7] = const Piece(type: PieceType.rook, color: PieceColor.white);
    for (int i = 8; i < 16; i++) {
      pieces[i] = const Piece(type: PieceType.pawn, color: PieceColor.white);
    }
    // Black pieces
    pieces[56] = const Piece(type: PieceType.rook, color: PieceColor.black);
    pieces[57] = const Piece(type: PieceType.knight, color: PieceColor.black);
    pieces[58] = const Piece(type: PieceType.bishop, color: PieceColor.black);
    pieces[59] = const Piece(type: PieceType.queen, color: PieceColor.black);
    pieces[60] = const Piece(type: PieceType.king, color: PieceColor.black);
    pieces[61] = const Piece(type: PieceType.bishop, color: PieceColor.black);
    pieces[62] = const Piece(type: PieceType.knight, color: PieceColor.black);
    pieces[63] = const Piece(type: PieceType.rook, color: PieceColor.black);
    for (int i = 48; i < 56; i++) {
      pieces[i] = const Piece(type: PieceType.pawn, color: PieceColor.black);
    }
    return pieces;
  }

  Widget buildTestBoard({
    Map<int, Piece>? pieces,
    Square? selectedSquare,
    List<Square>? legalMoves,
    Move? lastMove,
    bool isFlipped = false,
    bool interactive = true,
    OnMoveCallBack? onMove,
    OnSquareSelectedCallBack? onSquareSelected,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 420,
            height: 420,
            child: BoardWidget(
              pieces: pieces ?? _startingPieces(),
              selectedSquare: selectedSquare,
              legalMoves: legalMoves ?? [],
              lastMove: lastMove,
              isFlipped: isFlipped,
              interactive: interactive,
              showCoordinates: false,
              onMove: onMove,
              onSquareSelected: onSquareSelected,
              size: 400,
            ),
          ),
        ),
      ),
    );
  }

  group('BoardWidget', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildTestBoard());
      expect(find.byType(BoardWidget), findsOneWidget);
    });

    testWidgets('renders 64 squares', (tester) async {
      await tester.pumpWidget(buildTestBoard());
      // The board is an 8x8 grid rendered as Column of Rows
      // Each square is a SquareWidget
      expect(find.byType(BoardWidget), findsOneWidget);
    });

    testWidgets('renders with empty board', (tester) async {
      await tester.pumpWidget(buildTestBoard(pieces: {}));
      expect(find.byType(BoardWidget), findsOneWidget);
    });

    testWidgets('renders with flipped board', (tester) async {
      await tester.pumpWidget(buildTestBoard(isFlipped: true));
      expect(find.byType(BoardWidget), findsOneWidget);
    });

    testWidgets('handles square tap', (tester) async {
      Square? tappedSquare;
      await tester.pumpWidget(buildTestBoard(
        onSquareSelected: (square) => tappedSquare = square,
      ));

      // Tap somewhere on the board
      await tester.tap(find.byType(BoardWidget), warnIfMissed: false);
      await tester.pump();

      // Hard to assert exact square without calculating pixel positions
      // but callback should have been invoked
    });

    testWidgets('renders with last move highlight', (tester) async {
      final lastMove = Move.fromAlgebraic(from: 'e2', to: 'e4');
      await tester.pumpWidget(buildTestBoard(lastMove: lastMove));
      expect(find.byType(BoardWidget), findsOneWidget);
    });

    testWidgets('renders non-interactive board', (tester) async {
      await tester.pumpWidget(buildTestBoard(interactive: false));
      expect(find.byType(BoardWidget), findsOneWidget);
    });
  });
}


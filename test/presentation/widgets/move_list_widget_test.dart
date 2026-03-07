import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:btchess/domain/models/move.dart';
import 'package:btchess/domain/models/square.dart';
import 'package:btchess/presentation/widgets/game/move_list_widget.dart';

void main() {
  Widget buildTestWidget({
    List<Move> moves = const [],
    int? selectedMoveIndex,
    void Function(int)? onMoveTap,
    bool showMoveNumbers = true,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          height: 200,
          child: MoveListWidget(
            moves: moves,
            selectedMoveIndex: selectedMoveIndex,
            onMoveTap: onMoveTap,
            showMoveNumbers: showMoveNumbers,
          ),
        ),
      ),
    );
  }

  group('MoveListWidget', () {
    testWidgets('shows "No moves yet" when empty', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      expect(find.text('No moves yet'), findsOneWidget);
    });

    testWidgets('renders moves', (tester) async {
      final moves = [
        Move(
          from: Square.fromAlgebraic('e2'),
          to: Square.fromAlgebraic('e4'),
          san: 'e4',
        ),
        Move(
          from: Square.fromAlgebraic('e7'),
          to: Square.fromAlgebraic('e5'),
          san: 'e5',
        ),
      ];

      await tester.pumpWidget(buildTestWidget(moves: moves));

      expect(find.text('e4'), findsOneWidget);
      expect(find.text('e5'), findsOneWidget);
    });

    testWidgets('shows move numbers when enabled', (tester) async {
      final moves = [
        Move(
          from: Square.fromAlgebraic('e2'),
          to: Square.fromAlgebraic('e4'),
          san: 'e4',
        ),
      ];

      await tester.pumpWidget(buildTestWidget(
        moves: moves,
        showMoveNumbers: true,
      ));

      expect(find.text('1.'), findsOneWidget);
    });

    testWidgets('hides move numbers when disabled', (tester) async {
      final moves = [
        Move(
          from: Square.fromAlgebraic('e2'),
          to: Square.fromAlgebraic('e4'),
          san: 'e4',
        ),
      ];

      await tester.pumpWidget(buildTestWidget(
        moves: moves,
        showMoveNumbers: false,
      ));

      expect(find.text('1.'), findsNothing);
    });

    testWidgets('handles move tap callback', (tester) async {
      int? tappedIndex;
      final moves = [
        Move(
          from: Square.fromAlgebraic('e2'),
          to: Square.fromAlgebraic('e4'),
          san: 'e4',
        ),
      ];

      await tester.pumpWidget(buildTestWidget(
        moves: moves,
        onMoveTap: (index) => tappedIndex = index,
      ));

      await tester.tap(find.text('e4'));
      await tester.pump();

      expect(tappedIndex, 0);
    });

    testWidgets('displays UCI when no SAN', (tester) async {
      final moves = [
        Move(
          from: Square.fromAlgebraic('e2'),
          to: Square.fromAlgebraic('e4'),
        ),
      ];

      await tester.pumpWidget(buildTestWidget(moves: moves));

      expect(find.text('e2e4'), findsOneWidget);
    });

    testWidgets('renders multiple move pairs', (tester) async {
      final moves = [
        Move(from: Square.fromAlgebraic('e2'), to: Square.fromAlgebraic('e4'), san: 'e4'),
        Move(from: Square.fromAlgebraic('e7'), to: Square.fromAlgebraic('e5'), san: 'e5'),
        Move(from: Square.fromAlgebraic('g1'), to: Square.fromAlgebraic('f3'), san: 'Nf3'),
        Move(from: Square.fromAlgebraic('b8'), to: Square.fromAlgebraic('c6'), san: 'Nc6'),
      ];

      await tester.pumpWidget(buildTestWidget(moves: moves));

      expect(find.text('1.'), findsOneWidget);
      expect(find.text('2.'), findsOneWidget);
      expect(find.text('e4'), findsOneWidget);
      expect(find.text('e5'), findsOneWidget);
      expect(find.text('Nf3'), findsOneWidget);
      expect(find.text('Nc6'), findsOneWidget);
    });

    testWidgets('renders with selected move', (tester) async {
      final moves = [
        Move(from: Square.fromAlgebraic('e2'), to: Square.fromAlgebraic('e4'), san: 'e4'),
      ];

      await tester.pumpWidget(buildTestWidget(
        moves: moves,
        selectedMoveIndex: 0,
      ));

      // Widget renders without error with a selection
      expect(find.text('e4'), findsOneWidget);
    });
  });

  group('CompactMoveListWidget', () {
    testWidgets('shows dash when no moves', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: CompactMoveListWidget(moves: []),
        ),
      ));
      expect(find.text('-'), findsOneWidget);
    });
  });
}


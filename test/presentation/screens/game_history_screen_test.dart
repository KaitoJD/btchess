import 'package:btchess/application/providers/persistence_provider.dart';
import 'package:btchess/domain/enums/game_end_reason.dart';
import 'package:btchess/domain/enums/winner.dart';
import 'package:btchess/domain/models/game_mode.dart';
import 'package:btchess/domain/models/game_state.dart';
import 'package:btchess/domain/models/saved_game.dart';
import 'package:btchess/presentation/screens/game_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mock_game_repository.dart';

void main() {
  group('GameHistoryScreen', () {
    testWidgets('selects and deletes multiple games', (tester) async {
      final repository = MockGameRepository();
      final games = [
        _savedGame(id: 'game-1', opponentName: 'Game one'),
        _savedGame(id: 'game-2', opponentName: 'Game two'),
        _savedGame(
          id: 'game-3',
          opponentName: 'Completed game',
          isCompleted: true,
        ),
      ];

      when(() => repository.init()).thenAnswer((_) async {});
      when(() => repository.getAllGames()).thenAnswer((_) async => games);
      when(() => repository.getInProgressGames()).thenAnswer(
        (_) async => games.where((game) => game.isInProgress).toList(),
      );
      when(() => repository.getCompletedGames()).thenAnswer(
        (_) async => games.where((game) => game.isCompleted).toList(),
      );
      when(() => repository.deleteGames(any())).thenAnswer((invocation) async {
        final ids =
            invocation.positionalArguments.single as Iterable<String>;
        games.removeWhere((game) => ids.contains(game.id));
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gameRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(home: GameHistoryScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Game one'));
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsOneWidget);
      expect(find.text('Select all'), findsOneWidget);

      final selectAllCheckbox = find.byWidgetPredicate(
        (widget) => widget is Checkbox && widget.tristate,
      );
      await tester.tap(selectAllCheckbox);
      await tester.pumpAndSettle();

      expect(find.text('2 selected'), findsOneWidget);

      await tester.tap(find.byTooltip('Delete selected games'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Games'), findsOneWidget);
      expect(
        find.text('Are you sure you want to delete 2 selected games?'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      final deletedIds = verify(
        () => repository.deleteGames(captureAny()),
      ).captured.single as Iterable<String>;
      expect(deletedIds, unorderedEquals(['game-1', 'game-2']));
      expect(find.text('Game History'), findsOneWidget);
      expect(find.text('No games in progress'), findsOneWidget);
    });
  });
}

SavedGame _savedGame({
  required String id,
  required String opponentName,
  bool isCompleted = false,
}) {
  final timestamp = DateTime(2026, 8, 16, 12);

  return SavedGame(
    id: id,
    fen: initialFen,
    moves: const [],
    createdAt: timestamp,
    updatedAt: timestamp,
    modeIndex: GameMode.hotseat.index,
    opponentName: opponentName,
    winnerIndex: isCompleted ? Winner.draw.index : null,
    endReasonIndex: isCompleted ? GameEndReason.drawAgreement.index : null,
  );
}

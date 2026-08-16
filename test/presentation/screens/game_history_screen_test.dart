import 'package:btchess/application/providers/persistence_provider.dart';
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
      ];

      when(() => repository.init()).thenAnswer((_) async {});
      when(() => repository.getAllGames()).thenAnswer((_) async => games);
      when(
        () => repository.getInProgressGames(),
      ).thenAnswer((_) async => games);
      when(() => repository.getCompletedGames()).thenAnswer((_) async => []);
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
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      await tester.tap(find.byTooltip('Select all'));
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

SavedGame _savedGame({required String id, required String opponentName}) {
  final timestamp = DateTime(2026, 8, 16, 12);

  return SavedGame(
    id: id,
    fen: initialFen,
    moves: const [],
    createdAt: timestamp,
    updatedAt: timestamp,
    modeIndex: GameMode.hotseat.index,
    opponentName: opponentName,
  );
}

import 'package:btchess/application/providers/persistence_provider.dart';
import 'package:btchess/domain/models/game_mode.dart';
import 'package:btchess/domain/models/game_state.dart';
import 'package:btchess/domain/models/saved_game.dart';
import 'package:btchess/presentation/routes/app_router.dart';
import 'package:btchess/presentation/screens/game_screen.dart';
import 'package:btchess/presentation/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mock_game_repository.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(GameState.newGame(id: 'fallback', mode: GameMode.hotseat));
  });

  Widget buildApp(MockGameRepository repository) {
    return ProviderScope(
      overrides: [
        gameRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: const HomeScreen(),
      ),
    );
  }

  SavedGame savedHotseatGame() {
    final now = DateTime(2026, 6, 19, 12);
    return SavedGame(
      id: 'saved-game',
      fen: initialFen,
      moves: const [],
      createdAt: now,
      updatedAt: now,
      modeIndex: GameMode.hotseat.index,
    );
  }

  group('Home to game navigation', () {
    testWidgets('exiting a resumed local game returns to Home', (tester) async {
      final repository = MockGameRepository();
      final savedGame = savedHotseatGame();
      final gameState = GameState.fromFen(
        id: savedGame.id,
        fen: savedGame.fen,
        mode: savedGame.mode,
      );

      when(() => repository.getMostRecentGame()).thenAnswer((_) async => savedGame);
      when(() => repository.savedGameToState(savedGame)).thenReturn(gameState);
      when(() => repository.saveGame(any())).thenAnswer((_) async {});

      await tester.pumpWidget(buildApp(repository));
      await tester.pumpAndSettle();

      expect(find.text('Resume Game'), findsOneWidget);

      await tester.tap(find.text('Resume Game'));
      await tester.pumpAndSettle();

      expect(find.byType(GameScreen), findsOneWidget);
      expect(find.text('Local Game'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Exit'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('New Game'), findsOneWidget);
      expect(find.text('Resume Game'), findsOneWidget);
      expect(find.byType(GameScreen), findsNothing);
    });

    testWidgets('exiting a quick local game returns to Home', (tester) async {
      final repository = MockGameRepository();

      when(() => repository.getMostRecentGame()).thenAnswer((_) async => null);
      when(() => repository.saveGame(any())).thenAnswer((_) async {});

      await tester.pumpWidget(buildApp(repository));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Quick Play (Local)'));
      await tester.pumpAndSettle();

      expect(find.byType(GameScreen), findsOneWidget);
      expect(find.text('Local Game'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Exit'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('New Game'), findsOneWidget);
      expect(find.text('Quick Play (Local)'), findsOneWidget);
      expect(find.byType(GameScreen), findsNothing);
    });
  });
}

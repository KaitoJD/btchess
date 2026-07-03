import 'package:btchess/application/controllers/settings_controller.dart';
import 'package:btchess/domain/models/settings_models.dart';
import 'package:btchess/infrastructure/persistence/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  late _MockSettingsRepository repository;
  late SettingsController controller;

  setUp(() {
    repository = _MockSettingsRepository();
    controller = SettingsController(repository: repository);
  });

  group('SettingsController', () {
    test('loads settings from repository', () async {
      when(() => repository.init()).thenAnswer((_) async {});
      when(() => repository.getSoundEnabled()).thenAnswer((_) async => false);
      when(() => repository.getShowLegalMoves()).thenAnswer((_) async => false);
      when(() => repository.getShowCoordinates()).thenAnswer((_) async => true);
      when(
        () => repository.getBoardTheme(),
      ).thenAnswer((_) async => BoardTheme.green);
      when(
        () => repository.getPieceTheme(),
      ).thenAnswer((_) async => PieceTheme.neo);
      when(() => repository.getDebugMode()).thenAnswer((_) async => true);
      when(() => repository.getAutoFlipBoard()).thenAnswer((_) async => true);

      await controller.loadSettings();

      expect(controller.state.isLoaded, isTrue);
      expect(controller.state.soundEnabled, isFalse);
      expect(controller.state.showLegalMoves, isFalse);
      expect(controller.state.boardTheme, BoardTheme.green);
      expect(controller.state.pieceTheme, PieceTheme.neo);
      expect(controller.state.debugMode, isTrue);
      expect(controller.state.autoFlipBoard, isTrue);
      expect(controller.state.lastError, isNull);
    });

    test(
      'falls back to defaults and stores error when loading fails',
      () async {
        when(
          () => repository.init(),
        ).thenThrow(Exception('settings unavailable'));

        await controller.loadSettings();

        expect(controller.state.isLoaded, isTrue);
        expect(controller.state.soundEnabled, isTrue);
        expect(controller.state.boardTheme, BoardTheme.classic);
        expect(controller.state.lastError, contains('settings unavailable'));
      },
    );

    test('setSoundEnabled persists the updated value', () async {
      when(
        () => repository.setSoundEnabled(value: any(named: 'value')),
      ).thenAnswer((_) async {});

      await controller.setSoundEnabled(value: false);

      expect(controller.state.soundEnabled, isFalse);
      verify(() => repository.setSoundEnabled(value: false)).called(1);
    });
  });
}

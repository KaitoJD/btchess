import 'package:btchess/domain/models/settings_models.dart';
import 'package:btchess/infrastructure/persistence/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SettingsRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = SettingsRepository();
  });

  group('SettingsRepository', () {
    test('loads default values when preferences are empty', () async {
      expect(await repository.getSoundEnabled(), isTrue);
      expect(await repository.getShowLegalMoves(), isTrue);
      expect(await repository.getShowCoordinates(), isTrue);
      expect(await repository.getBoardTheme(), BoardTheme.classic);
      expect(await repository.getPieceTheme(), PieceTheme.standard);
      expect(await repository.getAppThemeMode(), AppThemeMode.system);
      expect(await repository.getDebugMode(), isFalse);
      expect(await repository.getAutoFlipBoard(), isFalse);
    });

    test('saves and loads theme selections', () async {
      await repository.setBoardTheme(BoardTheme.green);
      await repository.setPieceTheme(PieceTheme.neo);
      await repository.setAppThemeMode(AppThemeMode.dark);

      expect(await repository.getBoardTheme(), BoardTheme.green);
      expect(await repository.getPieceTheme(), PieceTheme.neo);
      expect(await repository.getAppThemeMode(), AppThemeMode.dark);
    });

    test('clamps invalid saved theme indexes to valid values', () async {
      SharedPreferences.setMockInitialValues({
        SettingsKeys.boardTheme: 99,
        SettingsKeys.pieceTheme: -4,
        SettingsKeys.appThemeMode: 99,
      });
      repository = SettingsRepository();

      expect(await repository.getBoardTheme(), BoardTheme.gray);
      expect(await repository.getPieceTheme(), PieceTheme.standard);
      expect(await repository.getAppThemeMode(), AppThemeMode.system);
    });

    test('resetAll removes stored settings', () async {
      await repository.setSoundEnabled(value: false);
      await repository.setShowCoordinates(value: false);
      await repository.setBoardTheme(BoardTheme.blue);
      await repository.setAppThemeMode(AppThemeMode.dark);

      await repository.resetAll();

      expect(await repository.getSoundEnabled(), isTrue);
      expect(await repository.getShowCoordinates(), isTrue);
      expect(await repository.getBoardTheme(), BoardTheme.classic);
      expect(await repository.getAppThemeMode(), AppThemeMode.system);
    });
  });
}

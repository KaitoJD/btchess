import 'package:shared_preferences/shared_preferences.dart';

abstract class SettingsKeys {
  static const String soundEnabled = 'sound_enabled';
  static const String showLegalMoves = 'show_legal_moves';
  static const String showCoordinates = 'show_coordinates';
  static const String boardTheme = 'board_theme';
  static const String pieceTheme = 'piece_theme';
  static const String debugMode = 'debug_mode';
  static const String playerName = 'player_name';
  static const String autoFlipBoard = 'auto_flip_board';
}

enum BoardTheme {
  classic,
  wood,
  blue,
  green,
  gray;

  String get displayName {
    switch (this) {
      case BoardTheme.classic:
      return 'Classic';
      case BoardTheme.wood:
      return 'Wood';
      case BoardTheme.blue:
      return 'Blue';
      case BoardTheme.green:
      return 'Green';
      case BoardTheme.gray:
      return 'Gray';
    }
  }
}

enum PieceTheme {
  standard,
  neo,
  alpha,
  chess24;

  String get displayName {
    switch (this) {
      case PieceTheme.standard:
      return 'Standard';
      case PieceTheme.neo:
      return 'Neo';
      case PieceTheme.alpha:
      return 'Alpha';
      case PieceTheme.chess24:
      return 'Chess24';
    }
  }
}

class SettingsRepository {
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<SharedPreferences> _getPrefs() async {
    if (_prefs == null) {
      await init();
    }

    return _prefs!;
  }

  Future<bool> getSoundEnabled() async {
    final prefs = await _getPrefs();

    return prefs.getBool(SettingsKeys.soundEnabled) ?? true;
  }

  Future<void> setSoundEnabled(bool value) async {
    final prefs = await _getPrefs();

    await prefs.setBool(SettingsKeys.soundEnabled, value);
  }

  Future<bool> getShowLegalMoves() async {
    final prefs = await _getPrefs();

    return prefs.getBool(SettingsKeys.showLegalMoves) ?? true;
  }

  Future<void> setShowLegalMoves(bool value) async {
    final prefs = await _getPrefs();

    await prefs.setBool(SettingsKeys.showLegalMoves, value);
  }

  Future<bool> getShowCoordinates() async {
    final prefs = await _getPrefs();

    return prefs.getBool(SettingsKeys.showCoordinates) ?? true;
  }

  Future<void> setShowCoordinates(bool value) async {
    final prefs = await _getPrefs();

    await prefs.setBool(SettingsKeys.showCoordinates, value);
  }

  Future<BoardTheme> getBoardTheme() async {
    final prefs = await _getPrefs();
    final index = prefs.getInt(SettingsKeys.boardTheme) ?? 0;

    return BoardTheme.values[index.clamp(0, BoardTheme.values.length - 1)];
  }

  Future<void> setBoardTheme(BoardTheme theme) async {
    final prefs = await _getPrefs();

    await prefs.setInt(SettingsKeys.boardTheme, theme.index);
  }

  Future<PieceTheme> getPieceTheme() async {
    final prefs = await _getPrefs();
    final index = prefs.getInt(SettingsKeys.pieceTheme) ?? 0;
    
    return PieceTheme.values[index.clamp(0, PieceTheme.values.length - 1)]; 
  }

  Future<void> setPieceTheme(PieceTheme theme) async {
    final prefs = await _getPrefs();

    await prefs.setInt(SettingsKeys.pieceTheme, theme.index);
  }

  Future<bool> getDebugMode() async {
    final prefs = await _getPrefs();

    return prefs.getBool(SettingsKeys.debugMode) ?? false;
  }

  Future<void> setDebugMode(bool value) async {
    final prefs = await _getPrefs();

    await prefs.setBool(SettingsKeys.debugMode, value);
  }

  Future<String> getPlayerName() async {
    final prefs = await _getPrefs();

    return prefs.getString(SettingsKeys.playerName) ?? 'Player';
  }

  Future<void> setPlayerName(String name) async {
    final prefs = await _getPrefs();

    await prefs.setString(SettingsKeys.playerName, name);
  }

  Future<bool> getAutoFlipBoard() async {
    final prefs = await _getPrefs();

    return prefs.getBool(SettingsKeys.autoFlipBoard) ?? false;
  }

  Future<void> setAutoFlipBoard(bool value) async {
    final prefs = await _getPrefs();

    await prefs.setBool(SettingsKeys.autoFlipBoard, value);
  }

  Future<Map<String, dynamic>> loadAll() async {
    return {
      SettingsKeys.soundEnabled: await getSoundEnabled(),
      SettingsKeys.showLegalMoves: await getShowLegalMoves(),
      SettingsKeys.showCoordinates: await getShowCoordinates(),
      SettingsKeys.boardTheme: await getBoardTheme(),
      SettingsKeys.pieceTheme: await getPieceTheme(),
      SettingsKeys.debugMode: await getDebugMode(),
      SettingsKeys.playerName: await getPlayerName(),
      SettingsKeys.autoFlipBoard: await getAutoFlipBoard(),
    };
  }

  Future<void> resetAll() async {
    final prefs = await _getPrefs();

    await prefs.remove(SettingsKeys.soundEnabled);
    await prefs.remove(SettingsKeys.showLegalMoves);
    await prefs.remove(SettingsKeys.showCoordinates);
    await prefs.remove(SettingsKeys.boardTheme);
    await prefs.remove(SettingsKeys.pieceTheme);
    await prefs.remove(SettingsKeys.debugMode);
    await prefs.remove(SettingsKeys.playerName);
    await prefs.remove(SettingsKeys.autoFlipBoard);
  }
}
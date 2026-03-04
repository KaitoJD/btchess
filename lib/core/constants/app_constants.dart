// Application-wide constants

abstract class AppConstants {
  // App Identity

  static const String appName = 'BTChess';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'Bluetooth Chess';

  // Storage Limits

  static const int maxSavedGames = 100;
  static const int maxGameHistory = 50;

  // Default Values

  static const String defaultGameName = 'BTChess_Game';
  static const String defaultPlayerName = 'Player';

  // Chess

  static const String standardStartFen =
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
}

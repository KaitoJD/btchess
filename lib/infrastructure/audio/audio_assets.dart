// Defines asset paths for all chess game audio files.
//
// All paths are relative to the `assets/` directory and are used
// with the `audioplayers` package's `AssetSource`.
//
// Place corresponding `.mp3` files in `assets/audio/`.
abstract class AudioAssets {
  // Base directory for audio assets.
  static const String _basePath = 'audio';

  // Standard piece movement sound.
  static const String move = '$_basePath/move.mp3';

  // Piece capture sound.
  static const String capture = '$_basePath/capture.mp3';

  // Check notification sound.
  static const String check = '$_basePath/check.mp3';

  // Castling sound.
  static const String castle = '$_basePath/castle.mp3';

  // Game start sound.
  static const String gameStart = '$_basePath/game_start.mp3';

  // Game end sound (checkmate, stalemate, draw, resign).
  static const String gameEnd = '$_basePath/game_end.mp3';

  // Illegal move attempt sound.
  static const String illegal = '$_basePath/illegal.mp3';

  // All asset paths for preloading.
  static const List<String> all = [
    move,
    capture,
    check,
    castle,
    gameStart,
    gameEnd,
    illegal,
  ];
}

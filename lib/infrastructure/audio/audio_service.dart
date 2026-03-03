import 'package:audioplayers/audioplayers.dart';

import 'audio_assets.dart';

// Service responsible for playing chess game sound effects.
//
// Respects the user's sound preference via [soundEnabled].
// All playback methods are fire-and-forget and gracefully handle
// errors (e.g. missing asset files) without crashing.
class AudioService {
  AudioService({this.soundEnabled = true});

  final AudioPlayer _player = AudioPlayer();

  // Whether sound effects are enabled. Updated from settings.
  bool soundEnabled;

  // Play the standard piece-move sound.
  Future<void> playMove() => _play(AudioAssets.move);

  // Play the piece-capture sound.
  Future<void> playCapture() => _play(AudioAssets.capture);

  // Play the check notification sound.
  Future<void> playCheck() => _play(AudioAssets.check);

  // Play the castling sound.
  Future<void> playCastle() => _play(AudioAssets.castle);

  // Play the game-start sound.
  Future<void> playGameStart() => _play(AudioAssets.gameStart);

  // Play the game-end sound (checkmate, stalemate, draw, resign).
  Future<void> playGameEnd() => _play(AudioAssets.gameEnd);

  // Play the illegal-move sound.
  Future<void> playIllegal() => _play(AudioAssets.illegal);

  // Play sound for a move based on its characteristics.
  //
  // Priority: game end > check > capture > castle > normal move.
  Future<void> playMoveSound({
    bool isCheckmate = false,
    bool isGameEnd = false,
    bool isCheck = false,
    bool isCapture = false,
    bool isCastling = false,
  }) async {
    if (isCheckmate || isGameEnd) {
      await playGameEnd();
    } else if (isCheck) {
      await playCheck();
    } else if (isCapture) {
      await playCapture();
    } else if (isCastling) {
      await playCastle();
    } else {
      await playMove();
    }
  }

  // Release audio resources.
  Future<void> dispose() async {
    await _player.dispose();
  }

  Future<void> _play(String assetPath) async {
    if (!soundEnabled) return;

    try {
      await _player.stop();
      await _player.play(AssetSource(assetPath));
    } catch (_) {
      // Gracefully ignore errors (missing files, platform issues, etc.)
    }
  }
}

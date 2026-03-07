/// FEN string fixtures for testing.
class FenFixtures {
  FenFixtures._();

  /// Starting position
  static const String startingPosition =
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  /// After 1. e4
  static const String afterE4 =
      'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1';

  /// After 1. e4 e5
  static const String afterE4E5 =
      'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2';

  /// Scholar's mate position (checkmate)
  static const String scholarsMate =
      'r1bqkb1r/pppp1Qpp/2n2n2/4p3/2B1P3/8/PPPP1PPP/RNB1K1NR b KQkq - 0 4';

  /// Stalemate position — black to move, no legal moves, not in check
  static const String stalemate =
      'k7/8/1Q6/8/8/8/8/4K3 b - - 0 1';

  /// En passant available — white pawn on e5, black just played d7-d5
  static const String enPassantAvailable =
      'rnbqkbnr/ppp1pppp/8/3pP3/8/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 3';

  /// White can castle kingside
  static const String whiteCanCastleKingside =
      'r1bqk2r/ppppbppp/2n2n2/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4';

  /// Promotion position — white pawn on e7, ready to promote (e8 is empty)
  static const String promotionReady =
      '8/4P3/2k5/8/8/8/8/4K3 w - - 0 1';

  /// Mid-game position
  static const String midGame =
      'r1bq1rk1/ppp2ppp/2np1n2/2b1p3/2B1P3/2NP1N2/PPP2PPP/R1BQ1RK1 w - - 4 7';

  /// Check position — white king in check
  static const String whiteInCheck =
      'rnb1kbnr/pppp1ppp/8/4p3/7q/5P2/PPPPP1PP/RNBQKBNR w KQkq - 1 3';

  /// Empty board with kings only
  static const String kingsOnly =
      '4k3/8/8/8/8/8/8/4K3 w - - 0 1';

  /// Insufficient material — king vs king
  static const String insufficientMaterialKvK =
      '4k3/8/8/8/8/8/8/4K3 w - - 0 1';

  /// Insufficient material — king + bishop vs king
  static const String insufficientMaterialKBvK =
      '4k3/8/8/8/8/8/8/2B1K3 w - - 0 1';

  /// Black to move
  static const String blackToMove =
      'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1';

  /// Invalid FEN strings for validation testing
  static const String invalidEmpty = '';
  static const String invalidTooFewParts = 'not/a/valid/fen';
  static const String invalidBadPiecePlacement = 'rnbqkbnr/ppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
  static const String invalidBadTurn = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR x KQkq - 0 1';
}

/// PGN string fixtures for testing.
class PgnFixtures {
  PgnFixtures._();

  /// Scholar's Mate PGN
  static const String scholarsMate = '''[Event "BTChess Game"]
[Site "Local"]
[Date "2026.01.15"]
[Round "1"]
[White "Player 1"]
[Black "Player 2"]
[Result "1-0"]

1. e4 e5 2. Bc4 Nc6 3. Qh5 Nf6 4. Qxf7# 1-0''';

  /// Simple game with a few moves (no result)
  static const String inProgressGame = '''[Event "BTChess Game"]
[Site "Local"]
[Date "2026.01.15"]
[White "Alice"]
[Black "Bob"]
[Result "*"]

1. e4 e5 2. Nf3 Nc6 *''';

  /// Draw by agreement
  static const String drawByAgreement = '''[Event "BTChess Game"]
[Site "Local"]
[Date "2026.01.15"]
[White "Alice"]
[Black "Bob"]
[Result "1/2-1/2"]

1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 1/2-1/2''';

  /// Black wins
  static const String blackWins = '''[Event "BTChess Game"]
[Site "Local"]
[Date "2026.01.15"]
[White "Alice"]
[Black "Bob"]
[Result "0-1"]

1. f3 e5 2. g4 Qh4# 0-1''';

  /// Minimal PGN (no headers)
  static const String minimal = '1. e4 e5 2. Nf3 *';

  /// Sample SAN moves list
  static const List<String> sampleSanMoves = [
    'e4', 'e5', 'Nf3', 'Nc6', 'Bb5', 'a6',
  ];
}

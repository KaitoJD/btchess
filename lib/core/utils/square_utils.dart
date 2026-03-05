// Standalone square conversion utilities for use without Square model instantiation.
//
// Square index mapping (0-63):
//    a  b  c  d  e  f  g  h
// 8 [56][57][58][59][60][61][62][63]
// 7 [48][49][50][51][52][53][54][55]
// 6 [40][41][42][43][44][45][46][47]
// 5 [32][33][34][35][36][37][38][39]
// 4 [24][25][26][27][28][29][30][31]
// 3 [16][17][18][19][20][21][22][23]
// 2 [ 8][ 9][10][11][12][13][14][15]
// 1 [ 0][ 1][ 2][ 3][ 4][ 5][ 6][ 7]

abstract class SquareUtils {
  static const int _aCodeUnit = 97; // 'a'.codeUnitAt(0)

  // Converts algebraic notation (e.g. 'e4') to a 0-63 square index.
  static int algebraicToIndex(String algebraic) {
    if (!isValidAlgebraic(algebraic)) {
      throw ArgumentError('Invalid algebraic notation: $algebraic');
    }
    final file = algebraic.codeUnitAt(0) - _aCodeUnit;
    final rank = int.parse(algebraic[1]) - 1;
    return rank * 8 + file;
  }

  // Converts a 0-63 square index to algebraic notation (e.g. 28 → 'e4').
  static String indexToAlgebraic(int index) {
    if (!isValidIndex(index)) {
      throw ArgumentError('Index must be between 0 and 63, got $index');
    }
    final (file, rank) = indexToFileRank(index);
    final fileLetter = String.fromCharCode(_aCodeUnit + file);
    final rankNumber = rank + 1;
    return '$fileLetter$rankNumber';
  }

  // Converts a 0-63 index to (file, rank) where both are 0-7.
  static (int file, int rank) indexToFileRank(int index) {
    if (!isValidIndex(index)) {
      throw ArgumentError('Index must be between 0 and 63, got $index');
    }
    return (index % 8, index ~/ 8);
  }

  // Converts (file, rank) each 0-7 to a 0-63 square index.
  static int fileRankToIndex(int file, int rank) {
    if (file < 0 || file > 7) {
      throw ArgumentError('File must be between 0 and 7, got $file');
    }
    if (rank < 0 || rank > 7) {
      throw ArgumentError('Rank must be between 0 and 7, got $rank');
    }
    return rank * 8 + file;
  }

  // Returns the file letter ('a'-'h') for a 0-63 square index.
  static String fileLetter(int index) {
    if (!isValidIndex(index)) {
      throw ArgumentError('Index must be between 0 and 63, got $index');
    }
    return String.fromCharCode(_aCodeUnit + index % 8);
  }

  // Returns the rank number (1-8) for a 0-63 square index.
  static int rankNumber(int index) {
    if (!isValidIndex(index)) {
      throw ArgumentError('Index must be between 0 and 63, got $index');
    }
    return (index ~/ 8) + 1;
  }

  // Returns true if the index is a valid square (0-63).
  static bool isValidIndex(int index) => index >= 0 && index <= 63;

  // Returns true if the string is valid algebraic notation (e.g. 'a1'-'h8').
  static bool isValidAlgebraic(String algebraic) {
    if (algebraic.length != 2) return false;
    final file = algebraic.codeUnitAt(0) - _aCodeUnit;
    final rank = int.tryParse(algebraic[1]);
    if (rank == null) return false;
    return file >= 0 && file <= 7 && rank >= 1 && rank <= 8;
  }
}

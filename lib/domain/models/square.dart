import 'package:equatable/equatable.dart';

// Represents a square on the chess board. Uses 0-63 indexing
// Index mapping: a1 = 0, b1 = 1, .. , h1 = 7, a2 = 8, .. , h8 = 63

class Square extends Equatable {
  final int file;
  final int rank;
  
  const Square._({required this.file, required this.rank})
      : assert(file >= 0 && file <= 7, 'File must be between 0 and 7'),
        assert(rank >= 0 && file <= 7, 'Rank must be between 0 and 7');

  factory Square(int file, int rank) {
    if (file < 0 || file > 7) {
      throw ArgumentError('File must be between 0 and 7, got $file');
    }
    if (rank < 0 || rank > 7) {
      throw ArgumentError('Rank must be between 0 and 7, got $rank');
    }
    return Square._(file: file, rank: rank);
  }

  factory Square.fromIndex(int index) {
    if (index < 0 || index > 63) {
      throw ArgumentError('Index must be between 0 and 63, got $index');
    }
    
    final file = index % 8;
    final rank = index ~/ 8;

    return Square._(file: file, rank: rank);
  }

  factory Square.fromAlgebraic(String algebraic) {
    if (algebraic.length != 2) {
      throw ArgumentError('Invalid algebraic notation: $algebraic');
    }

    final fileLetter = algebraic[0].toLowerCase();
    final rankDigit = algebraic[1];

    final file = fileLetter.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = int.tryParse(rankDigit);

    if (file < 0 || file > 7) {
      throw ArgumentError('Invalid file in algebraic notation: $algebraic');
    }
    if (rank == null || rank < 1 || rank > 8) {
      throw ArgumentError('Invalid rank in algebraic notation: $algebraic');
    }

    return Square._(file: file, rank: rank - 1);
  }

  static Square? tryFromAlgebraic(String algebraic) {
    try {
      return Square.fromAlgebraic(algebraic);
    } catch (_) {
      return null;
    }
  }

  Square? offset(int fileDelta, int rankDelta) {
    final newFile = file + fileDelta;
    final newRank = rank + rankDelta;

    if (newFile < 0 || newFile > 7 || newRank < 0 || newRank > 7) {
      return null;
    }

    return Square._(file: newFile, rank: newRank);
  }

  int get index => rank * 8 + file;
  String get fileLetter => String.fromCharCode('a'.codeUnitAt(0) + file);
  String get rankNumber => (rank + 1).toString();
  bool get isLight => (file + rank) % 2 == 1;
  bool get isDark => !isLight;
  String get algebraic => '$fileLetter$rankNumber';

  @override
  List<Object?> get props => [file, rank];

  @override
  String toString() => algebraic;
}
class Position {
  final int row;
  final int col;

  const Position(this.row, this.col);

  bool get isValid => row >= 0 && row < 8 && col >= 0 && col < 8;

  Position operator +(Position other) {
    return Position(row + other.row, col + other.col);
  }

  Position operator -(Position other) {
    return Position(row - other.row, col - other.col);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Position && other.row == row && other.col == col;
  }

  @override
  int get hashCode => row.hashCode ^ col.hashCode;

  @override
  String toString() => '($row, $col)';

  String toAlgebraic() {
    return '${String.fromCharCode(97 + col)}${8 - row}';
  }

  factory Position.fromAlgebraic(String algebraic) {
    final col = algebraic.codeUnitAt(0) - 97;
    final row = 8 - int.parse(algebraic[1]);
    return Position(row, col);
  }

  Map<String, dynamic> toJson() {
    return {
      'row': row,
      'col': col,
    };
  }

  factory Position.fromJson(Map<String, dynamic> json) {
    return Position(json['row'], json['col']);
  }
}

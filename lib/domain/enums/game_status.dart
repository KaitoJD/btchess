enum GameStatus {
  idle,
  playing,
  check,
  checkmate,
  stalemate,
  draw,
  resigned;

  bool get isActive => this == playing || this == check;

  bool get isEnded => this == checkmate || this == stalemate || this == draw || this == resigned;
}
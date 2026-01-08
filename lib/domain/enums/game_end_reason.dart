enum GameEndReason {
  checkmate,
  stalemate,
  resign,
  drawAgreement,
  fiftyMoveRule,
  threefoldRepetition,
  insufficientMaterial,
  timeout,
  disconnect;

  int get code => index + 1;

  static GameEndReason? fromCode(int code) {
    if (code < 1 || code > values.length) return null;
    return values[code - 1]; 
  }
}
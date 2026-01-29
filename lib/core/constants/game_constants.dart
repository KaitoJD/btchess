enum GameEndReason {
  checkmate(0x01),
  stalemate(0x02),
  resign(0x03),
  drawAgreement(0x04),
  fiftyMoveRule(0x05),
  threefoldRepetition(0x06),
  insufficientMaterial(0x07),
  timeout(0x08),
  disconnect(0x09);

  const GameEndReason(this.value);

  final int value;

  static GameEndReason? fromValue(int value) {
    for (final reason in values) {
      if (reason.value == value) return reason;
    }
    return null;
  }
}

enum WinnerCode {
  draw(0x00),
  white(0x01),
  black(0x02);

  const WinnerCode(this.value);

  final int value;

  static WinnerCode? fromValue(int value) {
    for (final code in values) {
      if (code.value == value) return code;
    }
    return null;
  }
}

enum PromotionCode {
  none(0x00),
  queen(0x01),
  rook(0x02),
  bishop(0x03),
  knight(0x04);

  const PromotionCode(this.value);

  final int value;

  static PromotionCode fromValue(int value) {
    for (final code in values) {
      if (code.value == value) return code;
    }
    return none;
  }
}
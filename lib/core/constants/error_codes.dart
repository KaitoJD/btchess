enum BleErrorCode {
  success(0x00),
  invalidMove(0x01),
  notYourTurn(0x02),
  gameEnded(0x03),
  syncRequired(0x04),
  unknownMessageType(0x05),
  malformedMessage(0x06),
  duplicateMessage(0x07),
  rateLimited(0x08),
  versionMismatch(0x10),
  sessionExpired(0x11),
  internalError(0xFF);

  const BleErrorCode(this.value);

  final int value;

  static BleErrorCode fromValue(int value) {
    for (final code in values) {
      if (code.value == value) return code;
    }
    return internalError;
  }

  bool get isSuccess => this == success;
  bool get isError => this != success;
}
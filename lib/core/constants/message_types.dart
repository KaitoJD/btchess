// These are 1-byte message type indentifiers used in the protocol

enum MessageTypes {
  handshake(0x00),
  move(0x01),
  ack(0x02),
  syncRequest(0x03),
  syncResponse(0x04),
  chunk(0x05),
  gameEnd(0x06),
  drawOffer(0x07),
  drawResponse(0x08),
  resign(0x09),
  ping(0x0A),
  pong(0x0B);

  const MessageTypes(this.value);

  final int value;

  static MessageTypes? fromValue(int value) {
    for (final type in values) {
      if (type.value == value) return type;
    }
    return null;
  }
}
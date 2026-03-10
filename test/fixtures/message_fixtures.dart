import 'dart:typed_data';
import 'package:btchess/infrastructure/bluetooth/message_models.dart';

/// Binary message fixtures for testing BLE protocol.
/// Byte layouts match PRD section 5.5.
class MessageFixtures {
  MessageFixtures._();

  // --- Handshake ---

  static const handshakeClient = HandshakeMessage(
    messageId: 1,
    protocolVersion: 0x01,
    role: 0x02, // CLIENT
    hostColor: 0x00, // unspecified (client doesn't set this)
  );

  static const handshakeHost = HandshakeMessage(
    messageId: 1,
    protocolVersion: 0x01,
    role: 0x01, // HOST
    hostColor: 0x01, // white
  );

  static const handshakeHostBlack = HandshakeMessage(
    messageId: 1,
    protocolVersion: 0x01,
    role: 0x01, // HOST
    hostColor: 0x02, // black
  );

  /// HANDSHAKE client: [0x00, 0x00, 0x01, 0x01, 0x02, 0x00]
  static final handshakeClientBytes = Uint8List.fromList([0x00, 0x00, 0x01, 0x01, 0x02, 0x00]);

  /// HANDSHAKE host (white): [0x00, 0x00, 0x01, 0x01, 0x01, 0x01]
  static final handshakeHostBytes = Uint8List.fromList([0x00, 0x00, 0x01, 0x01, 0x01, 0x01]);

  /// HANDSHAKE host (black): [0x00, 0x00, 0x01, 0x01, 0x01, 0x02]
  static final handshakeHostBlackBytes = Uint8List.fromList([0x00, 0x00, 0x01, 0x01, 0x01, 0x02]);

  // --- Move ---

  /// MOVE e2→e4: from=12 (e2), to=28 (e4), promo=0
  static const moveE2E4 = MoveMessage(
    messageId: 1,
    from: 12,  // e2
    to: 28,    // e4
    promotion: 0,
  );

  /// MOVE e2→e4 bytes: [0x01, 0x00, 0x01, 0x0C, 0x1C, 0x00]
  static final moveE2E4Bytes = Uint8List.fromList([0x01, 0x00, 0x01, 0x0C, 0x1C, 0x00]);

  /// MOVE with promotion: e7→e8=Q, from=52 (e7), to=60 (e8), promo=1 (queen)
  static const moveWithPromotion = MoveMessage(
    messageId: 2,
    from: 52,  // e7
    to: 60,    // e8
    promotion: 1, // Queen
  );

  static final moveWithPromotionBytes = Uint8List.fromList([0x01, 0x00, 0x02, 0x34, 0x3C, 0x01]);

  // --- ACK ---

  /// ACK OK for msg_id=1
  static const ackOk = AckMessage(
    messageId: 1,
    status: 0x00,
    errorCode: 0x00,
  );

  /// ACK OK bytes: [0x02, 0x00, 0x01, 0x00, 0x00]
  static final ackOkBytes = Uint8List.fromList([0x02, 0x00, 0x01, 0x00, 0x00]);

  /// ACK ERROR invalid move
  static const ackErrorInvalidMove = AckMessage(
    messageId: 1,
    status: 0x01,
    errorCode: 0x01, // INVALID_MOVE
  );

  static final ackErrorBytes = Uint8List.fromList([0x02, 0x00, 0x01, 0x01, 0x01]);

  // --- Sync Request ---

  static const syncRequest = SyncRequestMessage(messageId: 5);
  static final syncRequestBytes = Uint8List.fromList([0x03, 0x00, 0x05]);

  // --- Sync Response (single chunk) ---

  static final syncResponseSingle = SyncResponseMessage(
    messageId: 5,
    sequence: 1,
    total: 1,
    payload: Uint8List.fromList('test-fen-data'.codeUnits),
  );

  // --- Game End ---

  /// GAME_END: checkmate, white wins
  static const gameEndCheckmate = GameEndMessage(
    messageId: 10,
    reason: 0x01,  // checkmate
    winner: 0x01,  // white
  );

  static final gameEndCheckmateBytes = Uint8List.fromList([0x06, 0x00, 0x0A, 0x01, 0x01]);

  // --- Draw Offer ---

  static const drawOffer = DrawOfferMessage(messageId: 7);
  static final drawOfferBytes = Uint8List.fromList([0x07, 0x00, 0x07]);

  // --- Draw Response ---

  static const drawResponseAccepted = DrawResponseMessage(messageId: 7, accepted: true);
  static final drawResponseAcceptedBytes = Uint8List.fromList([0x08, 0x00, 0x07, 0x01]);

  static const drawResponseRejected = DrawResponseMessage(messageId: 7, accepted: false);
  static final drawResponseRejectedBytes = Uint8List.fromList([0x08, 0x00, 0x07, 0x00]);

  // --- Resign ---

  static const resign = ResignMessage(messageId: 3);
  static final resignBytes = Uint8List.fromList([0x09, 0x00, 0x03]);

  // --- Ping / Pong ---

  static const ping = PingMessage(messageId: 1, timestamp: 1700000000);
  static const pong = PongMessage(messageId: 1, timestamp: 1700000000);

  /// Timestamp 1700000000 = 0x6553F100 in big-endian
  static final pingBytes = Uint8List.fromList([0x0A, 0x00, 0x01, 0x65, 0x53, 0xF1, 0x00]);
  static final pongBytes = Uint8List.fromList([0x0B, 0x00, 0x01, 0x65, 0x53, 0xF1, 0x00]);

  // --- Malformed / Edge cases ---

  /// Empty data
  static final emptyBytes = Uint8List.fromList([]);

  /// Unknown message type
  static final unknownTypeBytes = Uint8List.fromList([0xFF, 0x00, 0x01]);

  /// Truncated MOVE (only 4 bytes instead of 6)
  static final truncatedMoveBytes = Uint8List.fromList([0x01, 0x00, 0x01, 0x0C]);
}

import 'dart:typed_data';
import '../../core/constants/message_types.dart';
import '../../core/errors/ble_exception.dart';
import '../../core/utils/binary_utils.dart';
import 'message_models.dart';

// Encodes and decodes BLE protocol messages
class MessageCodec {
  const MessageCodec();

  // - Encode

  // Encodes a message to bytes
  Uint8List encode(BleMessage message) {
    return switch(message) {
      HandshakeMessage m => _encodeHandshake(m),
      MoveMessage m => _encodeMove(m),
      AckMessage m => _encodeAck(m),
      SyncRequestMessage m => _encodeSyncRequest(m),
      SyncResponseMessage m => _encodeSyncResponse(m),
      GameEndMessage m => _encodeGameEnd(m),
      DrawOfferMessage m => _encodeDrawOffer(m),
      DrawResponseMessage m => _encodeDrawResponse(m),
      ResignMessage m => _encodeResign(m),
      PingMessage m => _encodePing(m),
      PongMessage m => _encodePong(m),
    };
  }

  Uint8List _encodeHandshake(HandshakeMessage m) {
    return ByteBufferBuilder()
            .addByte(MessageType.handshake.value)
            .addUint16(m.messageId)
            .addByte(m.protocolVersion)
            .addByte(m.role)
            .build();
  }

  Uint8List _encodeMove(MoveMessage m) {
    return ByteBufferBuilder()
            .addByte(MessageType.move.value)
            .addUint16(m.messageId)
            .addByte(m.from)
            .addByte(m.to)
            .addByte(m.promotion)
            .build();
  }

  Uint8List _encodeAck(AckMessage m) {
    return ByteBufferBuilder()
            .addByte(MessageType.ack.value)
            .addUint16(m.messageId)
            .addByte(m.status)
            .addByte(m.errorCode)
            .build();
  }

  Uint8List _encodeSyncRequest(SyncRequestMessage m) {
    return ByteBufferBuilder()
            .addByte(MessageType.syncRequest.value)
            .addUint16(m.messageId)
            .build();
  }

  Uint8List _encodeSyncResponse(SyncResponseMessage m) {
    return ByteBufferBuilder()
            .addByte(MessageType.syncResponse.value)
            .addUint16(m.messageId)
            .addByte(m.sequence)
            .addByte(m.total)
            .addBytes(m.payload)
            .build();
  }

  Uint8List _encodeGameEnd(GameEndMessage m) {
    return ByteBufferBuilder()
            .addByte(MessageType.gameEnd.value)
            .addUint16(m.messageId)
            .addByte(m.reason)
            .addByte(m.winner)
            .build();
  }

  Uint8List _encodeDrawOffer(DrawOfferMessage m) {
    return ByteBufferBuilder()
            .addByte(MessageType.drawOffer.value)
            .addUint16(m.messageId)
            .build();
  }

  Uint8List _encodeDrawResponse(DrawResponseMessage m) {
    return ByteBufferBuilder()
            .addByte(MessageType.drawResponse.value)
            .addUint16(m.messageId)
            .addByte(m.accepted ? 0x01 : 0x00)
            .build();
  }

  Uint8List _encodeResign(ResignMessage m) {
    return ByteBufferBuilder()
            .addByte(MessageType.resign.value)
            .addUint16(m.messageId)
            .build();
  }

  Uint8List _encodePing(PingMessage m) {
    return ByteBufferBuilder()
            .addByte(MessageType.ping.value)
            .addUint16(m.messageId)
            .addUint32(m.timestamp)
            .build();
  }

  Uint8List _encodePong(PongMessage m) {
    return ByteBufferBuilder()
            .addByte(MessageType.pong.value)
            .addUint16(m.messageId)
            .addUint32(m.timestamp)
            .build();
  }


  // - Decoding

  // Decodes bytes to a message
  BleMessage decode(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw const BleMessageException('Empty message');
    }

    final reader = ByteBufferReader(bytes);
    final typeValue = reader.readByte();
    final type = MessageType.fromValue(typeValue);

    if (type == null) {
      throw BleMessageException('Unknown message type: 0x${typeValue.toRadixString(16)}');
    }

    return switch (type) {
      MessageType.handshake => _decodeHandshake(reader),
      MessageType.move => _decodeMove(reader),
      MessageType.ack => _decodeAck(reader),
      MessageType.syncRequest => _decodeSyncRequest(reader),
      MessageType.syncResponse => _decodeSyncResponse(reader),
      MessageType.chunk => _decodeSyncResponse(reader), // Same format
      MessageType.gameEnd => _decodeGameEnd(reader),
      MessageType.drawOffer => _decodeDrawOffer(reader),
      MessageType.drawResponse => _decodeDrawResponse(reader),
      MessageType.resign => _decodeResign(reader),
      MessageType.ping => _decodePing(reader),
      MessageType.pong => _decodePong(reader),
    };
  }

  HandshakeMessage _decodeHandshake(ByteBufferReader reader) {
    _ensureRemaining(reader, 4); // messageId(2) + version(1) + role(1)

    return HandshakeMessage(
      messageId: reader.readUint16(),
      protocolVersion: reader.readByte(),
      role: reader.readByte(),
    );
  }

  MoveMessage _decodeMove(ByteBufferReader reader) {
    _ensureRemaining(reader, 5); // messageId(2) + from(1) + to(1) + promo(1)

    return MoveMessage(
      messageId: reader.readUint16(),
      from: reader.readByte(),
      to: reader.readByte(),
      promotion: reader.readByte(),
    );
  }

  AckMessage _decodeAck(ByteBufferReader reader) {
    _ensureRemaining(reader, 4); // messageId(2) + status(1) + errorCode(1)

    return AckMessage(
      messageId: reader.readUint16(),
      status: reader.readByte(),
      errorCode: reader.readByte(),
    );
  }

  SyncRequestMessage _decodeSyncRequest(ByteBufferReader reader) {
    _ensureRemaining(reader, 2); // messageId(2)

    return SyncRequestMessage(messageId: reader.readUint16());
  }

  SyncResponseMessage _decodeSyncResponse(ByteBufferReader reader) {
    _ensureRemaining(reader, 4); // messageId(2) + seq(1) + total(1)

    final messageId = reader.readUint16();
    final sequence = reader.readByte();
    final total = reader.readByte();
    final payload = reader.readRemaining();

    return SyncResponseMessage(
      messageId: messageId,
      sequence: sequence,
      total: total,
      payload: payload,
    );
  }

  GameEndMessage _decodeGameEnd(ByteBufferReader reader) {
    _ensureRemaining(reader, 4); // messageId(2) + reason(1) + winner(1)

    return GameEndMessage(
      messageId: reader.readUint16(),
      reason: reader.readByte(),
      winner: reader.readByte(),
    );
  }

  DrawOfferMessage _decodeDrawOffer(ByteBufferReader reader) {
    _ensureRemaining(reader, 2); // messageId(2)

    return DrawOfferMessage(messageId: reader.readUint16());
  }

  DrawResponseMessage _decodeDrawResponse(ByteBufferReader reader) {
    _ensureRemaining(reader, 3); // messageId(2) + accepted(1)

    return DrawResponseMessage(
      messageId: reader.readUint16(),
      accepted: reader.readByte() == 0x01,
    );
  }

  ResignMessage _decodeResign(ByteBufferReader reader) {
    _ensureRemaining(reader, 2); // messageId(2)

    return ResignMessage(messageId: reader.readUint16());
  }

  PingMessage _decodePing(ByteBufferReader reader) {
    _ensureRemaining(reader, 6); // messageId(2) + timestamp(4)

    return PingMessage(
      messageId: reader.readUint16(),
      timestamp: reader.readUint32(),
    );
  }

  PongMessage _decodePong(ByteBufferReader reader) {
    _ensureRemaining(reader, 6); // messageId(2) + timestamp(4)

    return PongMessage(
      messageId: reader.readUint16(),
      timestamp: reader.readUint32(),
    );
  }

  void _ensureRemaining(ByteBufferReader reader, int count) {
    if (reader.remaining < count) {
      throw BleMessageException(
        'Malformed message: expected $count bytes, got ${reader.remaining}'
      );
    }
  }

}
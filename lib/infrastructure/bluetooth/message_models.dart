import 'dart:typed_data';
import '../../core/constants/error_codes.dart';
import '../../core/constants/game_constants.dart';
import '../../core/constants/message_types.dart';

sealed class BleMessage {
  const BleMessage({required this.messageId});

  final int messageId;

  MessageType get type;
}

class HandshakeMessage extends BleMessage {
  const HandshakeMessage({
    required super.messageId,
    required this.protocolVersion,
    required this.role,
  });

  final int protocolVersion;
  final int role;
  
  bool get isHost => role == 0x01;
  bool get isClient => role == 0x02;

  @override
  MessageType get type => MessageType.handshake;

  @override
  String toString() => 'Handshake(id: $messageId, version: $protocolVersion, role: ${isHost ? "HOST" : "CLIENT"})';
}

class MoveMessage extends BleMessage {
  const MoveMessage({
    required super.messageId,
    required this.from,
    required this.to,
    this.promotion = 0,
  });

  final int from;
  final int to;
  final int promotion;

  bool get hasPromotion => promotion > 0;
  PromotionCode get promotionCode => PromotionCode.fromValue(promotion);

  @override
  MessageType get type => MessageType.move;

  @override
  String toString() => 'Move(id: $messageId, from: $from, to: $to, promo: $promotion)';
}

class AckMessage extends BleMessage {
  const AckMessage({
    required super.messageId,
    required this.status,
    this.errorCode = 0,
  });

  final int status;
  final int errorCode;

  bool get isSuccess => status == 0x00;
  bool get isError => status == 0x01;

  BleErrorCode get error => BleErrorCode.fromValue(errorCode);

  @override
  MessageType get type => MessageType.ack;

  @override
  String toString() => 'Ack(id: $messageId, status: ${isSuccess ? "OK" : "ERROR"}, error: 0x${errorCode.toRadixString(16)})';
}

class SyncRequestMessage extends BleMessage {
  const SyncRequestMessage({required super.messageId});

  @override
  MessageType get type => MessageType.syncRequest;

  @override
  String toString() => 'SyncRequest(id: $messageId)';
}

class SyncResponseMessage extends BleMessage {
  const SyncResponseMessage({
    required super.messageId,
    required this.sequence,
    required this.total,
    required this.payload,
  });

  final int sequence;
  final int total;
  final Uint8List payload;

  bool get isComplete => sequence == total;
  bool get isChunked => total > 1;

  String get payloadAsString => String.fromCharCodes(payload);

  @override
  MessageType get type => MessageType.syncResponse;

  @override
  String toString() => 'SyncResponse(id: $messageId, seq: $sequence/$total, payload: ${payload.length} bytes)';
}

class GameEndMessage extends BleMessage {
  const GameEndMessage({
    required super.messageId,
    required this.reason,
    required this.winner,
  });

  final int reason;
  final int winner;

  GameEndReason? get endReason => GameEndReason.fromValue(reason);
  WinnerCode? get winnerCode => WinnerCode.fromValue(winner);

  @override
  MessageType get type => MessageType.gameEnd;

  @override
  String toString() => 'GameEnd(id: $messageId, reason: $reason, winner: $winner)';
}

class DrawOfferMessage extends BleMessage {
  const DrawOfferMessage({required super.messageId});
  
  @override
  MessageType get type => MessageType.drawOffer;

  @override
  String toString() => 'DrawOffer(id: $messageId)';
}

class DrawResponseMessage extends BleMessage {
  const DrawResponseMessage({
    required super.messageId,
    required this.accepted,
  });

  final bool accepted;

  @override
  MessageType get type => MessageType.drawResponse;

  @override
  String toString() => 'DrawResponse(id: $messageId, accepted: $accepted)';
}

class ResignMessage extends BleMessage {
  const ResignMessage({required super.messageId});

  @override
  MessageType get type => MessageType.resign;

  @override
  String toString() => 'Resign(id: $messageId)';
}

class PingMessage extends BleMessage {
  const PingMessage({
    required super.messageId,
    required this.timestamp,
  });

  final int timestamp;

  @override
  MessageType get type => MessageType.ping;

  @override
  String toString() => 'Ping(id: $messageId, timestamp: $timestamp)';
}

class PongMessage extends BleMessage {
  const PongMessage({
    required super.messageId,
    required this.timestamp,
  });

  final int timestamp;

  @override
  MessageType get type => MessageType.pong;

  @override
  String toString() => 'Pong(id: $messageId, timestamp: $timestamp)';
}
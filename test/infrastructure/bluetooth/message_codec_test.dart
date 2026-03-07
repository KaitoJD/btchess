import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:btchess/infrastructure/bluetooth/message_codec.dart';
import 'package:btchess/infrastructure/bluetooth/message_models.dart';
import '../../fixtures/message_fixtures.dart';

void main() {
  const codec = MessageCodec();

  group('MessageCodec', () {
    group('Handshake', () {
      test('encodes client handshake to correct bytes', () {
        final bytes = codec.encode(MessageFixtures.handshakeClient);
        expect(bytes, MessageFixtures.handshakeClientBytes);
      });

      test('encodes host handshake to correct bytes', () {
        final bytes = codec.encode(MessageFixtures.handshakeHost);
        expect(bytes, MessageFixtures.handshakeHostBytes);
      });

      test('decodes client handshake from bytes', () {
        final msg = codec.decode(MessageFixtures.handshakeClientBytes);
        expect(msg, isA<HandshakeMessage>());
        final handshake = msg as HandshakeMessage;
        expect(handshake.messageId, 1);
        expect(handshake.protocolVersion, 0x01);
        expect(handshake.role, 0x02);
        expect(handshake.isClient, isTrue);
      });

      test('round-trips handshake', () {
        final encoded = codec.encode(MessageFixtures.handshakeHost);
        final decoded = codec.decode(encoded) as HandshakeMessage;
        expect(decoded.messageId, MessageFixtures.handshakeHost.messageId);
        expect(decoded.protocolVersion, MessageFixtures.handshakeHost.protocolVersion);
        expect(decoded.role, MessageFixtures.handshakeHost.role);
      });
    });

    group('Move', () {
      test('encodes MOVE e2→e4 to correct bytes', () {
        final bytes = codec.encode(MessageFixtures.moveE2E4);
        expect(bytes, MessageFixtures.moveE2E4Bytes);
      });

      test('decodes MOVE e2→e4 from bytes', () {
        final msg = codec.decode(MessageFixtures.moveE2E4Bytes);
        expect(msg, isA<MoveMessage>());
        final move = msg as MoveMessage;
        expect(move.messageId, 1);
        expect(move.from, 12);   // e2
        expect(move.to, 28);     // e4
        expect(move.promotion, 0);
        expect(move.hasPromotion, isFalse);
      });

      test('encodes MOVE with promotion', () {
        final bytes = codec.encode(MessageFixtures.moveWithPromotion);
        expect(bytes, MessageFixtures.moveWithPromotionBytes);
      });

      test('decodes MOVE with promotion', () {
        final msg = codec.decode(MessageFixtures.moveWithPromotionBytes) as MoveMessage;
        expect(msg.from, 52);    // e7
        expect(msg.to, 60);      // e8
        expect(msg.promotion, 1); // Queen
        expect(msg.hasPromotion, isTrue);
      });

      test('round-trips move message', () {
        final encoded = codec.encode(MessageFixtures.moveE2E4);
        final decoded = codec.decode(encoded) as MoveMessage;
        expect(decoded.from, MessageFixtures.moveE2E4.from);
        expect(decoded.to, MessageFixtures.moveE2E4.to);
        expect(decoded.promotion, MessageFixtures.moveE2E4.promotion);
      });
    });

    group('ACK', () {
      test('encodes ACK OK to correct bytes', () {
        final bytes = codec.encode(MessageFixtures.ackOk);
        expect(bytes, MessageFixtures.ackOkBytes);
      });

      test('decodes ACK OK from bytes', () {
        final msg = codec.decode(MessageFixtures.ackOkBytes);
        expect(msg, isA<AckMessage>());
        final ack = msg as AckMessage;
        expect(ack.messageId, 1);
        expect(ack.status, 0x00);
        expect(ack.errorCode, 0x00);
        expect(ack.isSuccess, isTrue);
        expect(ack.isError, isFalse);
      });

      test('encodes ACK ERROR to correct bytes', () {
        final bytes = codec.encode(MessageFixtures.ackErrorInvalidMove);
        expect(bytes, MessageFixtures.ackErrorBytes);
      });

      test('decodes ACK ERROR', () {
        final msg = codec.decode(MessageFixtures.ackErrorBytes) as AckMessage;
        expect(msg.isError, isTrue);
        expect(msg.errorCode, 0x01); // INVALID_MOVE
      });
    });

    group('SyncRequest', () {
      test('encodes sync request to correct bytes', () {
        final bytes = codec.encode(MessageFixtures.syncRequest);
        expect(bytes, MessageFixtures.syncRequestBytes);
      });

      test('decodes sync request from bytes', () {
        final msg = codec.decode(MessageFixtures.syncRequestBytes);
        expect(msg, isA<SyncRequestMessage>());
        expect((msg as SyncRequestMessage).messageId, 5);
      });
    });

    group('SyncResponse', () {
      test('round-trips sync response with payload', () {
        final encoded = codec.encode(MessageFixtures.syncResponseSingle);
        final decoded = codec.decode(encoded) as SyncResponseMessage;
        expect(decoded.messageId, 5);
        expect(decoded.sequence, 1);
        expect(decoded.total, 1);
        expect(decoded.payloadAsString, 'test-fen-data');
      });
    });

    group('GameEnd', () {
      test('encodes game end to correct bytes', () {
        final bytes = codec.encode(MessageFixtures.gameEndCheckmate);
        expect(bytes, MessageFixtures.gameEndCheckmateBytes);
      });

      test('decodes game end from bytes', () {
        final msg = codec.decode(MessageFixtures.gameEndCheckmateBytes);
        expect(msg, isA<GameEndMessage>());
        final gameEnd = msg as GameEndMessage;
        expect(gameEnd.reason, 0x01);  // checkmate
        expect(gameEnd.winner, 0x01);  // white
      });
    });

    group('DrawOffer', () {
      test('encodes draw offer to correct bytes', () {
        final bytes = codec.encode(MessageFixtures.drawOffer);
        expect(bytes, MessageFixtures.drawOfferBytes);
      });

      test('decodes draw offer from bytes', () {
        final msg = codec.decode(MessageFixtures.drawOfferBytes);
        expect(msg, isA<DrawOfferMessage>());
        expect((msg as DrawOfferMessage).messageId, 7);
      });
    });

    group('DrawResponse', () {
      test('encodes accepted draw response', () {
        final bytes = codec.encode(MessageFixtures.drawResponseAccepted);
        expect(bytes, MessageFixtures.drawResponseAcceptedBytes);
      });

      test('encodes rejected draw response', () {
        final bytes = codec.encode(MessageFixtures.drawResponseRejected);
        expect(bytes, MessageFixtures.drawResponseRejectedBytes);
      });

      test('decodes accepted draw response', () {
        final msg = codec.decode(MessageFixtures.drawResponseAcceptedBytes) as DrawResponseMessage;
        expect(msg.accepted, isTrue);
      });

      test('decodes rejected draw response', () {
        final msg = codec.decode(MessageFixtures.drawResponseRejectedBytes) as DrawResponseMessage;
        expect(msg.accepted, isFalse);
      });
    });

    group('Resign', () {
      test('encodes resign to correct bytes', () {
        final bytes = codec.encode(MessageFixtures.resign);
        expect(bytes, MessageFixtures.resignBytes);
      });

      test('decodes resign from bytes', () {
        final msg = codec.decode(MessageFixtures.resignBytes);
        expect(msg, isA<ResignMessage>());
        expect((msg as ResignMessage).messageId, 3);
      });
    });

    group('Ping/Pong', () {
      test('encodes ping to correct bytes', () {
        final bytes = codec.encode(MessageFixtures.ping);
        expect(bytes, MessageFixtures.pingBytes);
      });

      test('encodes pong to correct bytes', () {
        final bytes = codec.encode(MessageFixtures.pong);
        expect(bytes, MessageFixtures.pongBytes);
      });

      test('decodes ping from bytes', () {
        final msg = codec.decode(MessageFixtures.pingBytes);
        expect(msg, isA<PingMessage>());
        expect((msg as PingMessage).timestamp, 1700000000);
      });

      test('decodes pong from bytes', () {
        final msg = codec.decode(MessageFixtures.pongBytes);
        expect(msg, isA<PongMessage>());
        expect((msg as PongMessage).timestamp, 1700000000);
      });
    });

    group('Error handling', () {
      test('throws on empty bytes', () {
        expect(
          () => codec.decode(MessageFixtures.emptyBytes),
          throwsA(anything),
        );
      });

      test('throws on unknown message type', () {
        expect(
          () => codec.decode(MessageFixtures.unknownTypeBytes),
          throwsA(anything),
        );
      });

      test('throws on truncated move bytes', () {
        expect(
          () => codec.decode(MessageFixtures.truncatedMoveBytes),
          throwsA(anything),
        );
      });
    });

    group('Round-trip all message types', () {
      final allMessages = <BleMessage>[
        MessageFixtures.handshakeClient,
        MessageFixtures.handshakeHost,
        MessageFixtures.moveE2E4,
        MessageFixtures.moveWithPromotion,
        MessageFixtures.ackOk,
        MessageFixtures.ackErrorInvalidMove,
        MessageFixtures.syncRequest,
        MessageFixtures.syncResponseSingle,
        MessageFixtures.gameEndCheckmate,
        MessageFixtures.drawOffer,
        MessageFixtures.drawResponseAccepted,
        MessageFixtures.drawResponseRejected,
        MessageFixtures.resign,
        MessageFixtures.ping,
        MessageFixtures.pong,
      ];

      for (final msg in allMessages) {
        test('round-trips ${msg.runtimeType}', () {
          final encoded = codec.encode(msg);
          final decoded = codec.decode(encoded);
          expect(decoded.runtimeType, msg.runtimeType);
          expect(decoded.messageId, msg.messageId);
        });
      }
    });
  });
}


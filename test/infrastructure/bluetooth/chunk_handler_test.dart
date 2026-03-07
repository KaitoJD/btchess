import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:btchess/infrastructure/bluetooth/chunk_handler.dart';
import 'package:btchess/infrastructure/bluetooth/message_models.dart';

void main() {
  group('ChunkHandler', () {
    late ChunkHandler handler;

    setUp(() {
      handler = ChunkHandler(maxChunkPayload: 10);
    });

    group('chunkPayload', () {
      test('returns single chunk for small payload', () {
        final chunks = handler.chunkPayload(messageId: 1, payload: 'hello');
        expect(chunks.length, 1);
        expect(chunks.first.sequence, 1);
        expect(chunks.first.total, 1);
        expect(chunks.first.payloadAsString, 'hello');
        expect(chunks.first.isComplete, isTrue);
      });

      test('splits large payload into multiple chunks', () {
        final payload = 'a' * 25; // 25 bytes, maxChunkPayload=10
        final chunks = handler.chunkPayload(messageId: 1, payload: payload);
        expect(chunks.length, 3); // 10 + 10 + 5
        expect(chunks.first.sequence, 1);
        expect(chunks.first.total, 3);
        expect(chunks.last.sequence, 3);
        expect(chunks.last.total, 3);
      });

      test('all chunks share same messageId', () {
        final payload = 'a' * 25;
        final chunks = handler.chunkPayload(messageId: 42, payload: payload);
        for (final chunk in chunks) {
          expect(chunk.messageId, 42);
        }
      });

      test('reassembled chunks equal original payload', () {
        const original = 'Hello, this is a test FEN string that is long enough to chunk!';
        final chunks = handler.chunkPayload(messageId: 1, payload: original);

        String? result;
        for (final chunk in chunks) {
          result = handler.addChunk(chunk);
        }
        expect(result, original);
      });
    });

    group('addChunk', () {
      test('returns null for incomplete reassembly', () {
        final chunk = SyncResponseMessage(
          messageId: 1,
          sequence: 1,
          total: 3,
          payload: Uint8List.fromList('abc'.codeUnits),
        );
        expect(handler.addChunk(chunk), isNull);
      });

      test('returns complete payload when all chunks received', () {
        final chunk1 = SyncResponseMessage(
          messageId: 1,
          sequence: 1,
          total: 2,
          payload: Uint8List.fromList('hello'.codeUnits),
        );
        final chunk2 = SyncResponseMessage(
          messageId: 1,
          sequence: 2,
          total: 2,
          payload: Uint8List.fromList('world'.codeUnits),
        );

        expect(handler.addChunk(chunk1), isNull);
        final result = handler.addChunk(chunk2);
        expect(result, 'helloworld');
      });

      test('handles out-of-order chunks', () {
        final chunk1 = SyncResponseMessage(
          messageId: 1,
          sequence: 1,
          total: 2,
          payload: Uint8List.fromList('hello'.codeUnits),
        );
        final chunk2 = SyncResponseMessage(
          messageId: 1,
          sequence: 2,
          total: 2,
          payload: Uint8List.fromList('world'.codeUnits),
        );

        // Receive chunk 2 first, then chunk 1
        expect(handler.addChunk(chunk2), isNull);
        final result = handler.addChunk(chunk1);
        expect(result, 'helloworld');
      });

      test('returns payload immediately for single-chunk message', () {
        final chunk = SyncResponseMessage(
          messageId: 1,
          sequence: 1,
          total: 1,
          payload: Uint8List.fromList('data'.codeUnits),
        );
        final result = handler.addChunk(chunk);
        expect(result, 'data');
      });
    });

    group('hasPendingReassembly', () {
      test('returns false when no reassembly in progress', () {
        expect(handler.hasPendingReassembly(99), isFalse);
      });

      test('returns true when reassembly in progress', () {
        final chunk = SyncResponseMessage(
          messageId: 1,
          sequence: 1,
          total: 3,
          payload: Uint8List.fromList('abc'.codeUnits),
        );
        handler.addChunk(chunk);
        expect(handler.hasPendingReassembly(1), isTrue);
      });
    });

    group('getReassemblyProgress', () {
      test('returns null when no reassembly for messageId', () {
        expect(handler.getReassemblyProgress(99), isNull);
      });

      test('returns progress tuple', () {
        final chunk = SyncResponseMessage(
          messageId: 1,
          sequence: 1,
          total: 3,
          payload: Uint8List.fromList('abc'.codeUnits),
        );
        handler.addChunk(chunk);
        final progress = handler.getReassemblyProgress(1);
        expect(progress, isNotNull);
        expect(progress!.$1, 1); // received
        expect(progress.$2, 3); // total
      });
    });

    group('cancelReassembly', () {
      test('cancels pending reassembly', () {
        final chunk = SyncResponseMessage(
          messageId: 1,
          sequence: 1,
          total: 3,
          payload: Uint8List.fromList('abc'.codeUnits),
        );
        handler.addChunk(chunk);
        expect(handler.hasPendingReassembly(1), isTrue);
        handler.cancelReassembly(1);
        expect(handler.hasPendingReassembly(1), isFalse);
      });
    });

    group('clear', () {
      test('clears all buffers', () {
        final chunk = SyncResponseMessage(
          messageId: 1,
          sequence: 1,
          total: 3,
          payload: Uint8List.fromList('abc'.codeUnits),
        );
        handler.addChunk(chunk);
        handler.clear();
        expect(handler.hasPendingReassembly(1), isFalse);
      });
    });
  });
}


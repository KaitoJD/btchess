import 'dart:typed_data';
import '../../core/constants/ble_constants.dart';
import '../../core/constants/timing_constants.dart';
import '../../core/utils/binary_utils.dart';
import 'message_models.dart';

// Handles chunking and reassembly of large messages
class ChunkHandler {
  ChunkHandler({this.maxChunkPayload = BleConstants.defaultPayloadSize - 5});

  // Maximum payload size per chunk
  final int maxChunkPayload;

  // Reassembly state
  final Map<int, _ReassemblyState> _reassemblyBuffers = {};

  // - Chunking (for sending)

  // Chunks a payload into multiple SyncResponseMessage objects
  List<SyncResponseMessage> chunkPayload({
    required int messageId,
    required String payload
  }) {
    final payloadBytes = Uint8List.fromList(payload.codeUnits);

    if (payloadBytes.length <= maxChunkPayload) {
      return [
        SyncResponseMessage(
          messageId: messageId,
          sequence: 1,
          total: 1,
          payload: payloadBytes,
        ),
      ];
    }

    final chunks = <SyncResponseMessage>[];
    final totalChunks = (payloadBytes.length / maxChunkPayload).ceil();

    for (var i = 0; i < totalChunks; i++) {
      final start = i * maxChunkPayload;
      final end = (start + maxChunkPayload).clamp(0, payloadBytes.length);
      final chunkPayload = payloadBytes.sublist(start, end);

      chunks.add(SyncResponseMessage(
        messageId: messageId,
        sequence: i + 1,
        total: totalChunks,
        payload: chunkPayload,
      ));
    }

    return chunks;
  }

  // - Reassembly (for receiving)

  // Adds a chunk to the reassembly buffer
  // Returns the complete payload if all chunks received, null otherwise
  String? addChunk(SyncResponseMessage chunk) {
    final messageId = chunk.messageId;

    if (chunk.total == 1) {
      return chunk.payloadAsString;
    }

    var state = _reassemblyBuffers[messageId];
    if (state == null) {
      state = _ReassemblyState(
        messageId: messageId,
        totalChunks: chunk.total,
        startTime: DateTime.now(),
      );
      _reassemblyBuffers[messageId] = state;
    }

    if (chunk.total != state.totalChunks) {
      _reassemblyBuffers.remove(messageId);
      return null;
    }

    state.chunks[chunk.sequence] = chunk.payload;

    if (state.chunks.length == state.totalChunks) {
      _reassemblyBuffers.remove(messageId);
      return _assembleChunks(state);
    }

    return null;
  }

  // Assembles chunks into the complete payload
  String _assembleChunks(_ReassemblyState state) {
    final builder = ByteBufferBuilder();

    for (var i = 1; i <= state.totalChunks; i++) {
      final chunk = state.chunks[i];
      if (chunk != null) {
        builder.addBytes(chunk);
      }
    }

    return String.fromCharCodes(builder.build());
  }

  // Checks for and remove timed-out reassembly operations
  void cleanupTimedOut() {
    final timeout = Duration(milliseconds: TimingConstants.chunkReassemblyTimeoutMs);
    final now = DateTime.now();

    _reassemblyBuffers.removeWhere((_, state) {
      return now.difference(state.startTime) > timeout;
    });
  }

  // Cancels a specific reassembly operation
  void cancelReassembly(int messageId) {
    _reassemblyBuffers.remove(messageId);
  }

  // Clears all reassembly buffers
  void clear() {
    _reassemblyBuffers.clear();
  }

  // Returns true if there's a pending reassembly for the given message
  bool hasPendingReassembly(int messageId) {
    return _reassemblyBuffers.containsKey(messageId);
  }

  // Returns progress info for a pending reassembly
  (int recieved, int total)? getReassemblyProgress(int messageId) {
    final state = _reassemblyBuffers[messageId];
    if (state == null) return null;
    return (state.chunks.length, state.totalChunks);
  }
}

// Internal state for chunk reassembly
class _ReassemblyState {
  _ReassemblyState({
    required this.messageId,
    required this.totalChunks,
    required this.startTime,
  });

  final int messageId;
  final int totalChunks;
  final DateTime startTime;
  final Map<int, Uint8List> chunks = {};
}
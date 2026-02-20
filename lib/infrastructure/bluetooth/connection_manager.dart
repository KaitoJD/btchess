import 'dart:async';
import '../../core/constants/ble_constants.dart';
import '../../core/constants/error_codes.dart';
import '../../core/constants/timing_constants.dart';
import '../../core/errors/ble_exception.dart';
import 'ble_connection.dart';
import 'chunk_handler.dart';
import 'message_codec.dart';
import 'message_models.dart';
import 'message_queue.dart';
import 'rate_limiter.dart';

enum ConnectionState {
  disconnected,
  connecting,
  handshaking,
  connected,
  reconnecting,
  error,
}

class ConnectionManager {
  // The active connection
  BleConnection? _connection;

  // Current connection state
  ConnectionState _state = ConnectionState.disconnected;

  // Message codec
  final MessageCodec _codec = const MessageCodec();

  // Chunk handler for large messages
  final ChunkHandler _chunkHandler = ChunkHandler();

  // Rate limiter
  final RateLimiter _rateLimiter = RateLimiter();

  // Pending ACKs by message ID
  final Map<int, Completer<AckMessage>> _pendingAcks = {};

  // Message ID dedup cache (for host)
  final Map<int, AckMessage> _dedupCache = {};

  // Current message ID counter
  int _nextMessageId = 0;

  // Stream controller for connection state
  final StreamController<ConnectionState> _stateController = StreamController<ConnectionState>.broadcast();

  // Stream controller for incoming game messages
  final StreamController<BleMessage> _messageController = StreamController<BleMessage>.broadcast();

  // Message subscription
  StreamSubscription<BleMessage>? _messageSubscription;

  // Ping timer
  Timer? _pingTimer;

  // Last pong received time
  DateTime? _lastPongTime;

  // Stream of connection state changes
  Stream<ConnectionState> get stateStream => _stateController.stream;

  // Stream of incoming game messages
  Stream<BleMessage> get messages => _messageController.stream;

  // Current connection state
  ConnectionState get state => _state;

  // Whether connected
  bool get isConnected => _state == ConnectionState.connected;

  // Whether this is the host
  bool get isHost => _connection?.isHost ?? false;

  // The connected device name
  String? get connectedDeviceName => _connection?.deviceName;

  // Sets up connection with an existing BleConnection
  Future<void> setupConnection(BleConnection connection) async {
    _connection = connection;
    _updateState(ConnectionState.handshaking);

    _messageSubscription = connection.messages.listen(
      _handleMessage,
      onError: _handleError,
      onDone: _handleDisconnect,
    );

    try {
      await _performHandshake();
      _updateState(ConnectionState.connected);
      _startPingTimer();
    } catch (e) {
      _updateState(ConnectionState.error);
      rethrow;
    }
  }

  Future<void> _performHandshake() async {
    final messageId = _getNextMessageId();
    final handshake = HandshakeMessage(
      messageId: messageId,
      protocolVersion: BleConstants.protocolVersion,
      role: isHost ? BleConstants.roleHost : BleConstants.roleClient,
    );

    await _connection!.sendControl(handshake);

    final response = await _waitForMessage<HandshakeMessage>(
      timeout: const Duration(milliseconds: TimingConstants.handshakeTimeoutMs),
    );

    if (response.protocolVersion != BleConstants.protocolVersion) {
      throw BleProtocolException(
        'Protocol version mismatch: expected ${BleConstants.protocolVersion}, got ${response.protocolVersion}',
        errorCode: BleErrorCode.versionMismatch.value,
      );
    }
  }

  Future<T> _waitForMessage<T extends BleMessage>({required Duration timeout}) async {
    final completer = Completer<T>();
    StreamSubscription<BleMessage>? subscription;

    subscription = _messageController.stream.listen((message) {
      if (message is T) {
        subscription?.cancel();
        completer.complete(message);
      }
    });

    try {
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      subscription.cancel();
      throw BleTimeoutException(
        'Timeout waiting for ${T.toString()}',
        timeout: timeout,
      );
    }
  }

  void _handleMessage(BleMessage message) {
    switch (message) {
      case final AckMessage ack:
        _handleAck(ack);
        break;
      case final PongMessage pong:
        _handlePong(pong);
        break;
      case final PingMessage ping:
        _handlePing(ping);
        break;
      case final SyncResponseMessage sync:
        _handleSyncResponse(sync);
        break;
      default:
        // Forward to game logic
        _messageController.add(message);
    }
  }

  void _handleAck(AckMessage ack) {
    final completer = _pendingAcks.remove(ack.messageId);
    if (completer != null && !completer.isCompleted) {
      completer.complete(ack);
    }
  }

  void _handlePong(PongMessage pong) {
    _lastPongTime = DateTime.now();
  }

  void _handlePing(PingMessage ping) {
    final pong = PongMessage(
      messageId: ping.messageId,
      timestamp: ping.timestamp,
    );
    _connection?.sendControl(pong);
  }

  void _handleSyncResponse(SyncResponseMessage sync) {
    final payload = _chunkHandler.addChunk(sync);
    if (payload != null) {
      // Complete sync received - create a synthetic message
      // The actual parsing of the payload happens in the game controller
      _messageController.add(sync);
    }
  }

  void _handleError(Object error) {
    print('ConnectionManager: Error: $error');
    _updateState(ConnectionState.error);
  }

  void _handleDisconnect() {
    _updateState(ConnectionState.disconnected);
    _stopPingTimer();
  }

  // Sends a move and waits for ACK
  Future<AckMessage> sendMove(MoveMessage move) async {
    if (!isConnected) {
      throw const BleDisconnectedException('Not connected');
    }

    if (!_rateLimiter.tryAcquire('move')) {
      throw const BleProtocolException('Rate limited');
    }

    return _sendWithRetry(move);
  }
  
  Future<AckMessage> _sendWithRetry(BleMessage message) async {
    for (var attempt = 0; attempt < TimingConstants.totalMoveAttempts; attempt++) {
      try {
        final completer = Completer<AckMessage>();
        _pendingAcks[message.messageId] = completer;

        if (message is MoveMessage) {
          await _connection!.sendMove(message);
        } else {
          await _connection!.sendControl(message);
        }

        final ack = await completer.future.timeout(
          const Duration(milliseconds: TimingConstants.ackTimeoutMs),
        );

        return ack;
      } on TimeoutException {
        _pendingAcks.remove(message.messageId);

        if (attempt < TimingConstants.maxMoveRetries) {
          await Future.delayed(
            Duration(milliseconds: TimingConstants.retryBackoffMs[attempt]),
          );
        }
      }
    }

    throw const BleTimeoutException(
      'No ACK received after ${TimingConstants.totalMoveAttempts} attempts',
      timeout: Duration(milliseconds: TimingConstants.ackTimeoutMs * TimingConstants.totalMoveAttempts),
    );
  }

  // Send an ACK (for host)
  Future<void> sendAck(int messageId, {BleErrorCode error = BleErrorCode.success}) async {
    final ack = AckMessage(
      messageId: messageId,
      status: error.isSuccess ? 0x00 : 0x01,
      errorCode: error.value,
    );

    _dedupCache[messageId] = ack;
    await _connection!.sendStateNotification(ack);
  }

  // Sends a sync request (for client)
  Future<void> sendSyncRequest() async {
    if (!_rateLimiter.tryAcquire('syncRequest')) {
      throw const BleProtocolException('Rate limited');
    }

    final request = SyncRequestMessage(messageId: _getNextMessageId());
    await _connection!.sendControl(request);
  }

  // Sends a sync response (for host)
  Future<void> sendSyncResponse(String payload) async {
    final messageId = _getNextMessageId();
    final chunks = _chunkHandler.chunkPayload(
      messageId: messageId,
      payload: payload,
    );

    for (final chunk in chunks) {
      await _connection!.sendStateNotification(chunk);
    }
  }

  // Sends a draw offer
  Future<void> sendDrawOffer() async {
    if (!_rateLimiter.tryAcquire('drawOffer')) {
      throw const BleProtocolException('Rate limited');
    }

    final offer = DrawOfferMessage(messageId: _getNextMessageId());
    await _connection!.sendControl(offer);
  }

  // Sends a draw response
  Future<void> sendDrawResponse(bool accepted) async {
    final response = DrawResponseMessage(
      messageId: _getNextMessageId(),
      accepted: accepted,
    );
    await _connection!.sendControl(response);
  }

  // Sends a resign message
  Future<void> sendResign() async {
    final resign = ResignMessage(messageId: _getNextMessageId());
    await _connection!.sendControl(resign);
  }

  // Sends a game end notification (for host)
  Future<void> sendGameEnd(int reason, int winner) async {
    final gameEnd = GameEndMessage(
      messageId: _getNextMessageId(),
      reason: reason,
      winner: winner,
    );
    await _connection!.sendStateNotification(gameEnd);
  }

  void _startPingTimer() {
    _lastPongTime = DateTime.now();
    _pingTimer = Timer.periodic(
      const Duration(milliseconds: TimingConstants.pingIntervalMs),
      (_) => _sendPing(),
    );
  }

  void _stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  Future<void> _sendPing() async {
    if (!isConnected) return;

    if (_lastPongTime != null) {
      final elapsed = DateTime.now().difference(_lastPongTime!);
      if (elapsed.inMilliseconds > TimingConstants.disconnectTimeoutMs) {
        _handleDisconnect();
        return;
      }
    }

    final ping = PingMessage(
      messageId: _getNextMessageId(),
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    try {
      await _connection!.sendControl(ping);
    } catch (e) {
      // Ignore ping errors
    }
  }

  // Returns the next message ID (public accessor for controllers that build messages externally).
  int getNextPublicMessageId() => _getNextMessageId();

  int _getNextMessageId() {
    _nextMessageId = (_nextMessageId + 1) % 65536;
    return _nextMessageId;
  }

  void _updateState(ConnectionState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  // Disconnects from the current connection
  Future<void> disconnect() async {
    _stopPingTimer();
    _messageSubscription?.cancel();
    await _connection?.disconnect();
    _connection = null;
    _updateState(ConnectionState.disconnected);
    _pendingAcks.clear();
    _dedupCache.clear();
    _chunkHandler.clear();
    _rateLimiter.reset();
  }

  // Disposes resources
  void dispose() {
    disconnect();
    _stateController.close();
    _messageController.close();
  }
}

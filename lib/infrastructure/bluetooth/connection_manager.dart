import 'dart:async';
import 'dart:collection';
import '../../core/constants/ble_constants.dart';
import '../../core/constants/error_codes.dart';
import '../../core/constants/timing_constants.dart';
import '../../core/errors/ble_exception.dart';
import '../../core/utils/logger.dart';
import 'ble_transport.dart';
import 'chunk_handler.dart';
import 'message_models.dart';
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
  // The active transport (client or host)
  BleTransport? _connection;

  // Current connection state
  ConnectionState _state = ConnectionState.disconnected;

  // Last error message for diagnostics
  String? _lastError;

  // Chunk handler for large messages
  final ChunkHandler _chunkHandler = ChunkHandler();

  // Rate limiter
  final RateLimiter _rateLimiter = RateLimiter();

  // Pending ACKs by message ID
  final Map<int, Completer<AckMessage>> _pendingAcks = {};

  // Message ID dedup cache (for host)
  final Map<int, AckMessage> _dedupCache = {};

  // Host MOVE message IDs currently being processed by game logic.
  // This closes a race where duplicate MOVE writes arrive before ACK is sent.
  final Set<int> _inFlightHostMoveIds = <int>{};

  // Current message ID counter
  int _nextMessageId = 0;

  // Stream controller for connection state
  final StreamController<ConnectionState> _stateController = StreamController<ConnectionState>.broadcast();

  // Stream controller for incoming game messages
  final StreamController<BleMessage> _messageController = StreamController<BleMessage>.broadcast();

  // Message subscription
  StreamSubscription<BleMessage>? _messageSubscription;

  // Completes when the underlying transport stream closes or errors.
  Completer<void>? _connectionClosedCompleter;

  // Buffers handshake messages that can arrive before _waitForMessage
  // attaches its own stream listener during the handshaking phase.
  final Queue<HandshakeMessage> _handshakeBuffer = Queue<HandshakeMessage>();

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

  // Last error message (readable by controllers for UI surfacing)
  String? get lastError => _lastError;

  // Host color received during handshake (client only)
  int _receivedHostColor = 0x00;

  /// The host's chosen color code received during handshake.
  /// 0x00 = unspecified, 0x01 = white, 0x02 = black.
  int get receivedHostColor => _receivedHostColor;

  // Host color to include in handshake response (host only)
  int _hostColorCode = 0x00;

  /// Sets the host color code to send during handshake.
  void setHostColor(int colorCode) {
    _hostColorCode = colorCode;
  }

  // Maximum number of entries in the dedup cache before eviction
  static const int _maxDedupCacheSize = 64;

  // Sets up connection with an existing BleTransport (client or host)
  Future<void> setupConnection(BleTransport connection) async {
    // Cancel any existing subscription to prevent duplicate listeners on reconnect
    _messageSubscription?.cancel();

    _connection = connection;
    _updateState(ConnectionState.handshaking);
    _handshakeBuffer.clear();
    _connectionClosedCompleter = Completer<void>();

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
      _lastError = e.toString();
      _updateState(ConnectionState.error);
      rethrow;
    }
  }

  Future<void> _performHandshake() async {
    if (isHost) {
      Logger.debug(
        'Handshake(host) waiting for client handshake (timeout=${TimingConstants.handshakeTimeoutMs}ms, transport=${_connection.runtimeType})',
        tag: 'ConnectionManager',
      );
      // Host waits for client handshake first, then responds
      final clientHandshake = await _waitForMessage<HandshakeMessage>(
        timeout: const Duration(milliseconds: TimingConstants.handshakeTimeoutMs),
      );

      if (clientHandshake.protocolVersion != BleConstants.protocolVersion) {
        throw BleProtocolException(
          'Protocol version mismatch: expected ${BleConstants.protocolVersion}, got ${clientHandshake.protocolVersion}',
          errorCode: BleErrorCode.versionMismatch.value,
        );
      }

      final messageId = _getNextMessageId();
      final response = HandshakeMessage(
        messageId: messageId,
        protocolVersion: BleConstants.protocolVersion,
        role: BleConstants.roleHost,
        hostColor: _hostColorCode,
      );
      Logger.debug(
        'Handshake(host) sending response msgId=${response.messageId}',
        tag: 'ConnectionManager',
      );
      await _connection!.sendControl(response);
    } else {
      Logger.debug(
        'Handshake(client) preparing response listener (timeout=${TimingConstants.handshakeTimeoutMs}ms, transport=${_connection.runtimeType})',
        tag: 'ConnectionManager',
      );
      // Client sends handshake first, then waits for host response
      final messageId = _getNextMessageId();
      final handshake = HandshakeMessage(
        messageId: messageId,
        protocolVersion: BleConstants.protocolVersion,
        role: BleConstants.roleClient,
      );

      // Subscribe for the handshake response before sending to avoid
      // dropping an immediate host response on broadcast streams.
      final responseFuture = _waitForMessage<HandshakeMessage>(
        timeout: const Duration(milliseconds: TimingConstants.handshakeTimeoutMs),
      );

      Logger.debug(
        'Handshake(client) sending request msgId=${handshake.messageId}',
        tag: 'ConnectionManager',
      );
      await _connection!.sendControl(handshake);

      final response = await responseFuture;

      if (response.protocolVersion != BleConstants.protocolVersion) {
        throw BleProtocolException(
          'Protocol version mismatch: expected ${BleConstants.protocolVersion}, got ${response.protocolVersion}',
          errorCode: BleErrorCode.versionMismatch.value,
        );
      }

      // Store the host's color choice for the client to read
      _receivedHostColor = response.hostColor;
    }
  }

  Future<T> _waitForMessage<T extends BleMessage>({required Duration timeout}) async {
    // Consume buffered handshake messages first to avoid races where
    // handshakes arrive before this method's listener is attached.
    if (T == HandshakeMessage && _handshakeBuffer.isNotEmpty) {
      final buffered = _handshakeBuffer.removeFirst();
      return buffered as T;
    }

    final completer = Completer<T>();
    StreamSubscription<BleMessage>? subscription;

    subscription = _messageController.stream.listen((message) {
      if (message is T) {
        subscription?.cancel();
        completer.complete(message);
      }
    });

    try {
      final candidateFutures = <Future<T>>[
        completer.future,
      ];

      if (_connectionClosedCompleter != null) {
        candidateFutures.add(
          _connectionClosedCompleter!.future.then<T>(
            (_) => throw const BleDisconnectedException(
              'Connection closed while waiting for message',
            ),
          ),
        );
      }

      return await Future.any<T>(candidateFutures).timeout(timeout);
    } on TimeoutException {
      Logger.error(
        'Timed out waiting for ${T.toString()} after ${timeout.inMilliseconds}ms',
        tag: 'ConnectionManager',
      );
      throw BleTimeoutException(
        'Timeout waiting for ${T.toString()}',
        timeout: timeout,
      );
    } finally {
      await subscription.cancel();
    }
  }

  void _handleMessage(BleMessage message) {
    if (_state == ConnectionState.handshaking && message is HandshakeMessage) {
      _handshakeBuffer.addLast(message);
    }

    if (isHost && message is MoveMessage) {
      // 1) If we already ACKed this MOVE, replay the ACK
      // 2) If the same MOVE is already in-flight, drop this duplicate copy
      // 3) Otherwise mark it in-flight and forward once
      final msgId = message.messageId;
      final cachedAck = _dedupCache[msgId];
      if (cachedAck != null) {
        Logger.debug(
          'Dedup hit: msgId=$msgId, resending cached ACK (error=0x${cachedAck.errorCode.toRadixString(16)})',
          tag: 'ConnectionManager',
        );
        _connection?.sendStateNotification(cachedAck);
        return;
      }

      if (_inFlightHostMoveIds.contains(msgId)) {
        Logger.debug(
          'Dedup in-flight hit: msgId=$msgId, dropping duplicate MOVE before ACK',
          tag: 'ConnectionManager',
        );
        return;
      }

      _inFlightHostMoveIds.add(msgId);
    }

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
    Logger.error('Error: $error', tag: 'ConnectionManager');
    if (!(_connectionClosedCompleter?.isCompleted ?? true)) {
      _connectionClosedCompleter?.complete();
    }
    _lastError = error.toString();
    _updateState(ConnectionState.error);
  }

  void _handleDisconnect() {
    if (!(_connectionClosedCompleter?.isCompleted ?? true)) {
      _connectionClosedCompleter?.complete();
    }
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

  // Sends a move notification to the client (for host, fire-and-forget, no ACK)
  Future<void> sendMoveNotification(MoveMessage move) async {
    if (!isConnected) {
      throw const BleDisconnectedException('Not connected');
    }
    await _connection!.sendStateNotification(move);
  }

  // Send an ACK
  //
  // Host sends via STATE_NOTIFY characteristic; client sends via CONTROL.
  Future<void> sendAck(int messageId, {BleErrorCode error = BleErrorCode.success}) async {
    final ack = AckMessage(
      messageId: messageId,
      status: error.isSuccess ? 0x00 : 0x01,
      errorCode: error.value,
    );

    if (isHost) {
      _inFlightHostMoveIds.remove(messageId);
      _dedupCache[messageId] = ack;
      _trimDedupCache();
    }

    Logger.debug(
      'Sending ACK: msgId=$messageId, error=0x${error.value.toRadixString(16)}',
      tag: 'ConnectionManager',
    );

    if (isHost) {
      await _connection!.sendStateNotification(ack);
    } else {
      await _connection!.sendControl(ack);
    }
  }

  // Evicts oldest entries when the dedup cache exceeds the size limit
  void _trimDedupCache() {
    if (_dedupCache.length <= _maxDedupCacheSize) return;
    final excess = _dedupCache.length - _maxDedupCacheSize;
    final keysToRemove = _dedupCache.keys.take(excess).toList();
    for (final key in keysToRemove) {
      _dedupCache.remove(key);
    }
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
  Future<void> sendDrawResponse({required bool accepted}) async {
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

  // Sends a game start signal and waits for ACK (for host)
  Future<AckMessage> sendGameStart() async {
    if (!isConnected) {
      throw const BleDisconnectedException('Not connected');
    }

    final msg = GameStartMessage(messageId: _getNextMessageId());
    return _sendWithRetry(msg);
  }

  // Sends a rematch request
  Future<void> sendRematchRequest() async {
    final request = RematchRequestMessage(messageId: _getNextMessageId());
    await _connection!.sendControl(request);
  }

  // Sends a rematch response
  Future<void> sendRematchResponse({required bool accepted}) async {
    final response = RematchResponseMessage(
      messageId: _getNextMessageId(),
      accepted: accepted,
    );
    await _connection!.sendControl(response);
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
    _inFlightHostMoveIds.clear();
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

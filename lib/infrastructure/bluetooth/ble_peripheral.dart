import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:ble_peripheral/ble_peripheral.dart';
import '../../core/constants/ble_constants.dart';
import '../../core/constants/timing_constants.dart';
import '../../core/errors/ble_exception.dart';
import '../../core/utils/logger.dart';
import 'ble_setup.dart';
import 'message_codec.dart';
import 'message_models.dart';

// Callback type for when a client connects to the peripheral
typedef OnClientConnected = void Function(String deviceId);

// Callback type for when a client disconnects from the peripheral
typedef OnClientDisconnected = void Function(String deviceId);

/* Manages BLE peripheral (GATT server) operations for the host device
 *
 * Sets up a GATT server with the Chess Game Service containing three characteristics:
 * MOVE (write), STATE_NOTIFY (notify), and CONTROL (write + notify)
 */
class BlePeripheralManager {
  BlePeripheralManager();

  final MessageCodec _codec = const MessageCodec();
  bool _isAdvertising = false;
  bool _acceptingPeers = false;
  String? _advertisingGameName;

  // A peer is deliberately kept separate from a protocol-ready client.  A
  // system pairing prompt can tear down GATT, so treating the first raw
  // connection callback as a game connection races the bond lifecycle.
  String? _pendingClientId;
  String? _connectedClientId;
  bool _pendingLinkConnected = false;
  bool _pendingBonded = false;
  bool _pendingStateNotifySubscribed = false;
  bool _bondingObserved = false;
  BleSetupPhase? _setupPhase;
  int _setupAttemptId = 0;
  Timer? _setupDeadlineTimer;
  HandshakeMessage? _earlyHandshake;

  // Stream controller for incoming messages from the client
  final StreamController<BleMessage> _messageController =
      StreamController<BleMessage>.broadcast();

  // Stream controller for client connection events
  final StreamController<String> _clientConnectedController =
      StreamController<String>.broadcast();

  // Stream controller for client disconnection events
  final StreamController<String> _clientDisconnectedController =
      StreamController<String>.broadcast();

  // Fine-grained host setup transitions.  The controller uses these to keep
  // the lobby open while the OS owns pairing and a reconnect is in progress.
  final StreamController<PeerSetupEvent> _setupEventsController =
      StreamController<PeerSetupEvent>.broadcast();

  // Whether the GATT server has been initialized
  bool _isInitialized = false;

  // iOS can deliver the first handshake write before the peer has fully
  // settled notify subscriptions; defer forwarding once per session.
  bool _didDeferInitialHandshakeForward = false;

  // Diagnostic counters for runtime triage.
  int _controlUpdateFailureCount = 0;
  int _controlToStateFallbackCount = 0;

  bool get isAdvertising => _isAdvertising;
  String? get connectedClientId => _connectedClientId;
  bool get hasConnectedClient => _connectedClientId != null;
  Stream<BleMessage> get messages => _messageController.stream;
  Stream<String> get clientConnected => _clientConnectedController.stream;
  Stream<String> get clientDisconnected =>
      _clientDisconnectedController.stream;
  Stream<PeerSetupEvent> get setupEvents => _setupEventsController.stream;
  BleSetupPhase? get setupPhase => _setupPhase;
  int get activeSetupAttemptId => _setupAttemptId;

  static const String _serviceUuid = BleConstants.serviceUuid;
  static const String _moveCharUuid = BleConstants.moveCharacteristicUuid;
  static const String _stateNotifyCharUuid =
      BleConstants.stateNotifyCharacteristicUuid;
  static const String _controlCharUuid =
      BleConstants.controlCharacteristicUuid;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await BlePeripheral.initialize();
      await _setupGattServer();

      // Register every raw setup callback before advertising.  Android emits
      // bond state independently from GATT connection state, and iOS exposes
      // readiness through characteristic subscriptions instead.
      BlePeripheral.setWriteRequestCallback(_handleWriteRequest);
      BlePeripheral.setReadRequestCallback(_handleReadRequest);
      BlePeripheral.setConnectionStateChangeCallback(
          _handleConnectionStateChange);
      BlePeripheral.setBondStateChangeCallback(_handleBondStateChange);
      BlePeripheral.setCharacteristicSubscriptionChangeCallback(
        _handleCharacteristicSubscriptionChange,
      );

      _isInitialized = true;
    } catch (e) {
      throw BleConnectionException(
        'Failed to initialize BLE peripheral: $e',
        originalError: e,
      );
    }
  }

  Future<void> _setupGattServer() async {
    if (Platform.isIOS) {
      // iOS peripheral manager can need a short settle period after initialize.
      await Future.delayed(
        const Duration(milliseconds: TimingConstants.peripheralInitSettleDelayMs),
      );
    }

    var firstError = true;
    for (;;) {
      try {
        await _addService().timeout(
          const Duration(milliseconds: TimingConstants.peripheralServiceAddTimeoutMs),
        );
        if (Platform.isIOS) {
          // Give CoreBluetooth time to materialize all service attributes
          // before accepting client interactions.
          await Future.delayed(
            const Duration(milliseconds: TimingConstants.peripheralServiceReadyDelayMs),
          );
        }
        return;
      } catch (e) {
        if (!Platform.isIOS || !firstError) {
          rethrow;
        }

        firstError = false;
        Logger.warn(
          'Initial GATT service setup failed on iOS, retrying once: $e',
          tag: 'BlePeripheralManager',
        );
        await Future.delayed(
          const Duration(milliseconds: TimingConstants.peripheralServiceAddRetryDelayMs),
        );
      }
    }
  }

  Future<void> _addService() {
    return BlePeripheral.addService(
      _buildChessService(),
    );
  }

  BleService _buildChessService() {
    final controlProperties = Platform.isIOS
        ? <int>[
            CharacteristicProperties.write.index,
            CharacteristicProperties.writeWithoutResponse.index,
          ]
        : <int>[
            CharacteristicProperties.write.index,
            CharacteristicProperties.writeWithoutResponse.index,
            CharacteristicProperties.notify.index,
            CharacteristicProperties.read.index,
          ];

    final controlPermissions = Platform.isIOS
        ? <int>[
            AttributePermissions.writeable.index,
          ]
        : <int>[
            AttributePermissions.readable.index,
            AttributePermissions.writeable.index,
          ];

    return BleService(
      uuid: _serviceUuid,
      primary: true,
      characteristics: [
        BleCharacteristic(
          uuid: _moveCharUuid,
          properties: [
            CharacteristicProperties.write.index,
            CharacteristicProperties.writeWithoutResponse.index,
          ],
          permissions: [
            AttributePermissions.writeable.index,
          ],
        ),
        BleCharacteristic(
          uuid: _stateNotifyCharUuid,
          properties: [
            CharacteristicProperties.notify.index,
            CharacteristicProperties.read.index,
          ],
          permissions: [
            AttributePermissions.readable.index,
          ],
        ),
        BleCharacteristic(
          uuid: _controlCharUuid,
          properties: controlProperties,
          permissions: controlPermissions,
        ),
      ],
    );
  }

  Future<void> startAdvertising(String gameName) async {
    if (!_isInitialized) {
      throw const BleConnectionException(
        'BLE peripheral not initialized. Call initialize() first',
      );
    }

    if (_isAdvertising) return;

    try {
      final advertisingName =
          '${BleConstants.deviceNamePrefix}-$gameName';
      _advertisingGameName = gameName;
      // Native start is asynchronous; accept setup callbacks that arrive as
      // soon as the advertiser becomes connectable.
      _acceptingPeers = true;
      await BlePeripheral.startAdvertising(
        services: [_serviceUuid],
        localName: advertisingName,
      );
      Logger.debug(
        'Advertising started (platform=${Platform.operatingSystem}, service=$_serviceUuid, '
        'stateChar=$_stateNotifyCharUuid, controlChar=$_controlCharUuid)',
        tag: 'BlePeripheralManager',
      );
      _isAdvertising = true;
      _acceptingPeers = true;
    } catch (e) {
      _acceptingPeers = false;
      throw BleConnectionException(
        'Failed to start advertising: $e',
        originalError: e,
      );
    }
  }

  Future<void> stopAdvertising() async {
    if (!_isAdvertising) {
      _acceptingPeers = false;
      _resetSetupState(emitCancelled: true);
      _resetSendDiagnostics();
      return;
    }

    try {
      await BlePeripheral.stopAdvertising();
      _isAdvertising = false;
      _acceptingPeers = false;
      _resetSetupState(emitCancelled: true);
      _resetSendDiagnostics();
    } catch (_) {
      _isAdvertising = false;
      _acceptingPeers = false;
      _resetSetupState(emitCancelled: true);
      _resetSendDiagnostics();
    }
  }

  // Stops only the advertiser after a peer is protocol-ready.  Unlike the
  // public [stopAdvertising], this must not invalidate the ready session or
  // its delayed initial-handshake forwarding callback.
  Future<void> _stopAdvertisingForReadyPeer() async {
    if (!_isAdvertising) return;

    try {
      await BlePeripheral.stopAdvertising();
    } catch (_) {
      // A failed stop is harmless: the peer is already reserved and the
      // native implementation rejects a second raw client.
    } finally {
      _isAdvertising = false;
      _acceptingPeers = false;
    }
  }

  void _resetSendDiagnostics() {
    _didDeferInitialHandshakeForward = false;
    _controlUpdateFailureCount = 0;
    _controlToStateFallbackCount = 0;
  }

  /* Handles write requests from the client
   *
   * Returns a [WriteRequestResult] with status 0 (GATT_SUCCESS) on success, or a non-zero status on failure
   */
  WriteRequestResult? _handleWriteRequest(
    String deviceId,
    String characteristicId,
    int offset,
    Uint8List? value,
  ) {
    Logger.debug(
      'Write request: peer=${_redactedPeer(deviceId)}, char=$characteristicId, '
      'offset=$offset, bytes=${value?.length ?? 0}',
      tag: 'BlePeripheralManager',
    );

    try {
      final data = value ?? Uint8List(0);
      if (data.isEmpty) {
        return WriteRequestResult(status: 0);
      }

      final message = _codec.decode(data);

      // iOS can deliver an initial write before its subscription callback,
      // while Android normally sends a raw connection callback first.  Begin
      // a provisional setup in either case, but never treat that write as a
      // game-ready connection.
      _ensurePendingPeer(deviceId, inferredLinkConnected: true);

      if (!_isActivePeer(deviceId)) {
        Logger.warn(
          'Rejected write from a second peer while attempt=$_setupAttemptId is active',
          tag: 'BlePeripheralManager',
        );
        return WriteRequestResult(status: 0x0D);
      }

      if (_connectedClientId != deviceId) {
        // A client can optimistically send its first HELLO before the Android
        // bond callback or the CCCD write reaches us.  Buffer exactly one
        // handshake and reject every other protocol message until readiness.
        if (message is HandshakeMessage && _earlyHandshake == null) {
          _earlyHandshake = message;
          Logger.debug(
            'Buffered early handshake (attempt=$_setupAttemptId, '
            'phase=${_setupPhase?.name ?? 'unknown'})',
            tag: 'BlePeripheralManager',
          );
          return WriteRequestResult(status: 0);
        }

        Logger.warn(
          'Rejected ${message.runtimeType} before protocol readiness '
          '(attempt=$_setupAttemptId, phase=${_setupPhase?.name ?? 'unknown'})',
          tag: 'BlePeripheralManager',
        );
        return WriteRequestResult(status: 0x0D);
      }

      if (Platform.isIOS &&
          !_didDeferInitialHandshakeForward &&
          message is HandshakeMessage) {
        _didDeferInitialHandshakeForward = true;
        Future.delayed(
          const Duration(milliseconds: TimingConstants.peripheralHandshakeForwardDelayMs),
          () {
            if (!_messageController.isClosed) {
              _messageController.add(message);
            }
          },
        );
      } else {
        _messageController.add(message);
      }

      return WriteRequestResult(status: 0); // GATT_SUCCESS
    } catch (e) {
      Logger.error(
        'Failed to handle write request on char=$characteristicId: $e',
        tag: 'BlePeripheralManager',
      );
      return WriteRequestResult(status: 0x0D); // error
    }
  }

  /* Handles read requests from the client
   * 
   * Returns empty data since actual data is sent via notifications
   */
  ReadRequestResult? _handleReadRequest(
    String _,
    String _,
    int _,
    Uint8List? _,
  ) {
    return ReadRequestResult(value: Uint8List(0), status: 0);
  }

  // Handles connection state changes for connected devices
  void _handleConnectionStateChange(String deviceId, bool connected) {
    if (connected) {
      _handleRawLinkConnected(deviceId);
    } else {
      _handleRawLinkDisconnected(deviceId);
    }
  }

  Future<void> sendStateNotification(BleMessage message) async {
    if (!hasConnectedClient) {
      throw const BleDisconnectedException(
        'No client connected to send state notification',
      );
    }

    final bytes = _codec.encode(message);
    Logger.debug(
      'sendStateNotification type=${message.type.value} msgId=${message.messageId} '
      'bytes=${bytes.length} peer=${_redactedPeer(_connectedClientId!)}',
      tag: 'BlePeripheralManager',
    );
    await BlePeripheral.updateCharacteristic(
      characteristicId: _stateNotifyCharUuid,
      value: bytes,
      deviceId: _connectedClientId,
    );
  }

  Future<void> sendControl(BleMessage message) async {
    if (!hasConnectedClient) {
      throw const BleDisconnectedException(
        'No client connected to send control message',
      );
    }

    final bytes = _codec.encode(message);
    if (Platform.isIOS) {
      _controlToStateFallbackCount++;
      Logger.warn(
        'iOS sendControl rerouted to state notify '
        '(type=${message.type.value}, msgId=${message.messageId}, bytes=${bytes.length}, '
        'fallbackCount=$_controlToStateFallbackCount)',
        tag: 'BlePeripheralManager',
      );

      await BlePeripheral.updateCharacteristic(
        characteristicId: _stateNotifyCharUuid,
        value: bytes,
        deviceId: _connectedClientId,
      );
      return;
    }

    try {
      Logger.debug(
        'sendControl type=${message.type.value} msgId=${message.messageId} '
        'bytes=${bytes.length} peer=${_redactedPeer(_connectedClientId!)}',
        tag: 'BlePeripheralManager',
      );
      await BlePeripheral.updateCharacteristic(
        characteristicId: _controlCharUuid,
        value: bytes,
        deviceId: _connectedClientId,
      );
    } catch (e) {
      // iOS peripheral implementations can fail to resolve CONTROL
      // characteristic updates in some sessions. Fallback to STATE_NOTIFY
      // keeps protocol bytes intact while avoiding connection failure.
      if (!Platform.isIOS) rethrow;

      _controlUpdateFailureCount++;

      Logger.warn(
        'sendControl failed on iOS, falling back to state notification '
        '(failureCount=$_controlUpdateFailureCount): $e',
        tag: 'BlePeripheralManager',
      );

      await BlePeripheral.updateCharacteristic(
        characteristicId: _stateNotifyCharUuid,
        value: bytes,
        deviceId: _connectedClientId,
      );
    }
  }

  /// Handles a raw GATT link.  This is intentionally not the public
  /// `clientConnected` event: a peer still has to finish pairing and subscribe
  /// to STATE_NOTIFY before game protocol traffic is allowed.
  void _handleRawLinkConnected(String deviceId) {
    _ensurePendingPeer(deviceId, inferredLinkConnected: true);
    if (!_isActivePeer(deviceId)) return;

    _pendingLinkConnected = true;
    if (_pendingBonded) {
      _emitSetupPhase(BleSetupPhase.subscribing);
    } else {
      _emitSetupPhase(BleSetupPhase.pairing);
    }
    _promotePeerWhenReady();
  }

  void _handleRawLinkDisconnected(String deviceId) {
    if (!_isActivePeer(deviceId)) return;

    _pendingLinkConnected = false;
    _pendingStateNotifySubscribed = false;

    if (_connectedClientId == deviceId) {
      // A disconnect after protocol readiness is a real game disconnect and
      // must retain the existing transport error behavior.
      _connectedClientId = null;
      _didDeferInitialHandshakeForward = false;
      _clientDisconnectedController.add(deviceId);
      _clearPreReadyState();
      return;
    }

    // Bonding commonly drops the original GATT link.  Keep the attempt and
    // its deadline alive; BOND_BONDED followed by a fresh connection and CCCD
    // subscription will resume it without a Retry tap.
    _emitSetupPhase(BleSetupPhase.awaitingReconnect);
  }

  void _handleBondStateChange(String deviceId, BondState bondState) {
    // Android can broadcast unrelated bond changes.  Only consume events for
    // the peer that opened the current GATT setup attempt.
    if (!_isActivePeer(deviceId)) return;

    switch (bondState) {
      case BondState.bonding:
        _bondingObserved = true;
        _pendingBonded = false;
        _emitSetupPhase(BleSetupPhase.pairing);
        break;
      case BondState.bonded:
        _pendingBonded = true;
        if (_pendingLinkConnected) {
          _emitSetupPhase(BleSetupPhase.subscribing);
        } else {
          _emitSetupPhase(BleSetupPhase.awaitingReconnect);
        }
        _promotePeerWhenReady();
        break;
      case BondState.none:
        if (_bondingObserved) {
          _failPendingSetup('Pairing was cancelled or rejected');
        } else {
          // This is the initial BOND_NONE emitted by Android just before
          // createBond().  It is not a user rejection yet.
          _pendingBonded = false;
          _emitSetupPhase(BleSetupPhase.pairing);
        }
        break;
    }
  }

  void _handleCharacteristicSubscriptionChange(
    String deviceId,
    String characteristicId,
    bool isSubscribed,
    String? _,
  ) {
    if (!_isStateNotifyCharacteristic(characteristicId)) return;

    // On Apple platforms a subscription is the first dependable signal that
    // a central is interacting with our peripheral.  It also implies an
    // active link and CoreBluetooth has completed any required pairing.
    _ensurePendingPeer(
      deviceId,
      inferredLinkConnected: true,
      inferredBonded: !Platform.isAndroid,
    );
    if (!_isActivePeer(deviceId)) return;

    _pendingStateNotifySubscribed = isSubscribed;
    if (isSubscribed) {
      if (_pendingBonded) {
        _emitSetupPhase(BleSetupPhase.subscribing);
      } else {
        _emitSetupPhase(BleSetupPhase.pairing);
      }
      _promotePeerWhenReady();
      return;
    }

    if (_connectedClientId == deviceId) {
      // Losing the required subscription after readiness makes the transport
      // unusable even if Android has not delivered its disconnect callback.
      _connectedClientId = null;
      _didDeferInitialHandshakeForward = false;
      _clientDisconnectedController.add(deviceId);
      _clearPreReadyState();
    } else if (_pendingLinkConnected) {
      _emitSetupPhase(BleSetupPhase.subscribing);
    } else {
      _emitSetupPhase(BleSetupPhase.awaitingReconnect);
    }
  }

  void _ensurePendingPeer(
    String deviceId, {
    required bool inferredLinkConnected,
    bool inferredBonded = false,
  }) {
    if (_pendingClientId == deviceId || _connectedClientId == deviceId) {
      if (inferredLinkConnected) _pendingLinkConnected = true;
      if (inferredBonded) _pendingBonded = true;
      return;
    }

    if (_pendingClientId != null || _connectedClientId != null) {
      Logger.warn(
        'Ignoring second peer during active BLE setup '
        '(attempt=$_setupAttemptId, phase=${_setupPhase?.name ?? 'ready'})',
        tag: 'BlePeripheralManager',
      );
      return;
    }

    if (!_acceptingPeers) {
      Logger.debug(
        'Ignored stale peer callback after setup was cancelled',
        tag: 'BlePeripheralManager',
      );
      return;
    }

    _setupAttemptId++;
    _pendingClientId = deviceId;
    _pendingLinkConnected = inferredLinkConnected;
    _pendingBonded = inferredBonded || !Platform.isAndroid;
    _pendingStateNotifySubscribed = false;
    _bondingObserved = false;
    _earlyHandshake = null;
    _emitSetupPhase(BleSetupPhase.connecting, force: true);
    _armSetupDeadline(_setupAttemptId);

    Logger.debug(
      'Started host BLE setup attempt=$_setupAttemptId '
      '(role=host, platform=${Platform.operatingSystem}, '
      'link=${_pendingLinkConnected ? 'connected' : 'waiting'}, '
      'bond=${_pendingBonded ? 'bonded' : 'pending'})',
      tag: 'BlePeripheralManager',
    );
  }

  bool _isActivePeer(String deviceId) =>
      deviceId == _pendingClientId || deviceId == _connectedClientId;

  bool _isStateNotifyCharacteristic(String characteristicId) =>
      characteristicId.toLowerCase() == _stateNotifyCharUuid.toLowerCase();

  void _promotePeerWhenReady() {
    final peerId = _pendingClientId;
    if (peerId == null ||
        _connectedClientId != null ||
        !_pendingBonded ||
        !_pendingLinkConnected ||
        !_pendingStateNotifySubscribed) {
      return;
    }

    _setupDeadlineTimer?.cancel();
    _setupDeadlineTimer = null;
    _connectedClientId = peerId;
    _emitSetupPhase(BleSetupPhase.ready);
    _clientConnectedController.add(peerId);
    unawaited(_stopAdvertisingForReadyPeer());
    _forwardEarlyHandshakeWhenReady(peerId, _setupAttemptId);
  }

  void _forwardEarlyHandshakeWhenReady(String peerId, int attemptId) {
    final handshake = _earlyHandshake;
    _earlyHandshake = null;
    if (handshake == null) return;

    void forward() {
      if (_connectedClientId != peerId ||
          _setupAttemptId != attemptId ||
          _messageController.isClosed) {
        return;
      }
      _messageController.add(handshake);
    }

    if (Platform.isIOS) {
      _didDeferInitialHandshakeForward = true;
      Future.delayed(
        const Duration(
          milliseconds: TimingConstants.peripheralHandshakeForwardDelayMs,
        ),
        forward,
      );
    } else {
      forward();
    }
  }

  void _armSetupDeadline(int attemptId) {
    _setupDeadlineTimer?.cancel();
    _setupDeadlineTimer = Timer(
      const Duration(milliseconds: TimingConstants.pairingSetupTimeoutMs),
      () {
        if (_setupAttemptId != attemptId || _connectedClientId != null) return;
        _failPendingSetup('Pairing and reconnect timed out');
      },
    );
  }

  void _failPendingSetup(String reason) {
    if (_pendingClientId == null || _connectedClientId != null) return;

    Logger.warn(
      'Host BLE setup failed (attempt=$_setupAttemptId, role=host, '
      'platform=${Platform.operatingSystem}, phase=${_setupPhase?.name ?? 'unknown'}, '
      'reason=$reason)',
      tag: 'BlePeripheralManager',
    );
    _emitSetupPhase(BleSetupPhase.failed, reason: reason, force: true);
    // Invalidate native peer generation before accepting the next opponent.
    // Merely keeping the advertiser running would allow a late BOND_BONDED or
    // reconnect callback from this failed attempt to become a fresh session.
    _acceptingPeers = false;
    _clearPreReadyState();
    unawaited(_restartAdvertisingAfterSetupFailure());
  }

  Future<void> _restartAdvertisingAfterSetupFailure() async {
    final gameName = _advertisingGameName;
    if (gameName == null || !_isInitialized) return;

    try {
      if (_isAdvertising) {
        await BlePeripheral.stopAdvertising();
        _isAdvertising = false;
      }
      await startAdvertising(gameName);
    } catch (error) {
      Logger.warn(
        'Failed to restart host advertising after setup failure: $error',
        tag: 'BlePeripheralManager',
      );
    }
  }

  void _clearPreReadyState() {
    _setupDeadlineTimer?.cancel();
    _setupDeadlineTimer = null;
    _pendingClientId = null;
    _pendingLinkConnected = false;
    _pendingBonded = false;
    _pendingStateNotifySubscribed = false;
    _bondingObserved = false;
    _earlyHandshake = null;
  }

  void _resetSetupState({required bool emitCancelled}) {
    if (emitCancelled && _pendingClientId != null && _connectedClientId == null) {
      _emitSetupPhase(
        BleSetupPhase.cancelled,
        reason: 'Setup cancelled',
        force: true,
      );
    }
    _clearPreReadyState();
    _connectedClientId = null;
    _setupPhase = null;
    _setupAttemptId++;
  }

  void _emitSetupPhase(
    BleSetupPhase phase, {
    String? reason,
    bool force = false,
  }) {
    if (!force && _setupPhase == phase) return;
    _setupPhase = phase;
    if (_setupEventsController.isClosed) return;

    final event = PeerSetupEvent(
      attemptId: _setupAttemptId,
      phase: phase,
      isHost: true,
      platform: Platform.operatingSystem,
      occurredAt: DateTime.now(),
      reason: reason,
    );
    Logger.debug(event.toString(), tag: 'BlePeripheralManager');
    _setupEventsController.add(event);
  }

  String _redactedPeer(String deviceId) {
    if (deviceId.length <= 4) return 'peer';
    return '...${deviceId.substring(deviceId.length - 4)}';
  }

  Future<void> dispose() async {
    await stopAdvertising();
    _setupDeadlineTimer?.cancel();
    _setupDeadlineTimer = null;
    _connectedClientId = null;
    _pendingClientId = null;
    _didDeferInitialHandshakeForward = false;
    _controlUpdateFailureCount = 0;
    _controlToStateFallbackCount = 0;
    _isInitialized = false;
    await _messageController.close();
    await _clientConnectedController.close();
    await _clientDisconnectedController.close();
    await _setupEventsController.close();
  }
}

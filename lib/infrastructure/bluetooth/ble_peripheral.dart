import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:ble_peripheral/ble_peripheral.dart';
import '../../core/constants/ble_constants.dart';
import '../../core/constants/timing_constants.dart';
import '../../core/errors/ble_exception.dart';
import '../../core/utils/logger.dart';
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
  String? _connectedClientId;

  // Stream controller for incoming messages from the client
  final StreamController<BleMessage> _messageController =
      StreamController<BleMessage>.broadcast();

  // Stream controller for client connection events
  final StreamController<String> _clientConnectedController =
      StreamController<String>.broadcast();

  // Stream controller for client disconnection events
  final StreamController<String> _clientDisconnectedController =
      StreamController<String>.broadcast();

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

      // Register callbacks for read/write requests and connection changes
      BlePeripheral.setWriteRequestCallback(_handleWriteRequest);
      BlePeripheral.setReadRequestCallback(_handleReadRequest);
      BlePeripheral.setConnectionStateChangeCallback(
          _handleConnectionStateChange);

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
    } catch (e) {
      throw BleConnectionException(
        'Failed to start advertising: $e',
        originalError: e,
      );
    }
  }

  Future<void> stopAdvertising() async {
    if (!_isAdvertising) return;

    try {
      await BlePeripheral.stopAdvertising();
      _isAdvertising = false;
      _didDeferInitialHandshakeForward = false;
      _controlUpdateFailureCount = 0;
      _controlToStateFallbackCount = 0;
    } catch (e) {
      _isAdvertising = false;
      _didDeferInitialHandshakeForward = false;
      _controlUpdateFailureCount = 0;
      _controlToStateFallbackCount = 0;
    }
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
      'Write request: device=$deviceId, char=$characteristicId, '
      'offset=$offset, bytes=${value?.length ?? 0}',
      tag: 'BlePeripheralManager',
    );

    try {
      final data = value ?? Uint8List(0);
      if (data.isEmpty) {
        return WriteRequestResult(status: 0);
      }

      final message = _codec.decode(data);

      // Track connected client from first write
      if (_connectedClientId == null) {
        _connectedClientId = deviceId;
        _clientConnectedController.add(deviceId);
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
    String deviceId,
    String characteristicId,
    int offset,
    Uint8List? value,
  ) {
    return ReadRequestResult(value: Uint8List(0), status: 0);
  }

  // Handles connection state changes for connected devices
  void _handleConnectionStateChange(String deviceId, bool connected) {
    if (connected) {
      handleClientConnected(deviceId);
    } else {
      handleClientDisconnected(deviceId);
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
      'bytes=${bytes.length} device=$_connectedClientId',
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
        'bytes=${bytes.length} device=$_connectedClientId',
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

  void handleClientConnected(String deviceId) {
    if (_connectedClientId == deviceId) return;
    _connectedClientId = deviceId;
    _clientConnectedController.add(deviceId);
    stopAdvertising();
  }

  void handleClientDisconnected(String deviceId) {
    if (_connectedClientId == deviceId) {
      _connectedClientId = null;
      _didDeferInitialHandshakeForward = false;
      _clientDisconnectedController.add(deviceId);
    }
  }

  Future<void> dispose() async {
    await stopAdvertising();
    _connectedClientId = null;
    _didDeferInitialHandshakeForward = false;
    _controlUpdateFailureCount = 0;
    _controlToStateFallbackCount = 0;
    _isInitialized = false;
    await _messageController.close();
    await _clientConnectedController.close();
    await _clientDisconnectedController.close();
  }
}
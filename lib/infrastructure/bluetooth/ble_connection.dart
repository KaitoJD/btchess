import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../core/constants/ble_constants.dart';
import '../../core/errors/ble_exception.dart';
import '../../core/utils/logger.dart';
import 'ble_transport.dart';
import 'message_codec.dart';
import 'message_models.dart';

class BleConnection implements BleTransport {
  BleConnection({
    required this.device,
    required this.isHost,
  });

  // The connected device
  final BluetoothDevice device;
  
  // Whether this device is the host
  @override
  final bool isHost;

  // Message codec
  final MessageCodec _codec = const MessageCodec();

  // Stream controller for incoming messages
  final StreamController<BleMessage> _messageController = StreamController<BleMessage>.broadcast();
  
  // The GATT service
  BluetoothService? _service;

  // Characteristic for sending moves (client -> host)
  BluetoothCharacteristic? _moveCharacteristic;

  // Characteristic for state notifications (host -> client)
  BluetoothCharacteristic? _stateNotifyCharacteristic;

  // Characteristic for control messages
  BluetoothCharacteristic? _controlCharacteristic;

  // Subscription to state notifications
  StreamSubscription<List<int>>? _stateSubscription;

  // Subscription to control notifications
  StreamSubscription<List<int>>? _controlSubscription;

  // Connection state
  bool _isConnected = false;

  @override
  Stream<BleMessage> get messages => _messageController.stream;
  bool get isConnected => _isConnected;
  @override
  String get deviceName => device.platformName;
  String get deviceId => device.remoteId.str;

  Future<void> initialize() async {
    try {
      // Clear Android GATT cache to force fresh service discovery.
      // Without this, Android may return a stale cached service list from
      // a previous connection that didn't have the chess service registered.
      Logger.debug('Clearing GATT cache...', tag: 'BleConnection');
      try {
        await device.clearGattCache();
        await Future.delayed(const Duration(milliseconds: 300));
      } catch (e) {
        Logger.debug('clearGattCache not supported or failed: $e', tag: 'BleConnection');
      }

      // Discover services
      Logger.debug('Discovering services...', tag: 'BleConnection');
      final services = await device.discoverServices();
      Logger.debug('Found ${services.length} services', tag: 'BleConnection');

      // Find our chess service (use str128 for full 128-bit UUID comparison
      // since Guid.toString() returns shortened form for Bluetooth Base UUIDs)
      _service = services.firstWhere(
        (s) => s.uuid.str128.toLowerCase() == BleConstants.serviceUuid.toLowerCase(),
        orElse: () => throw const BleConnectionException('Chess service not found on device'),
      );
      Logger.debug('Chess service found with ${_service!.characteristics.length} characteristics', tag: 'BleConnection');

      // Find characteristic
      for (final char in _service!.characteristics) {
        final uuid = char.uuid.str128.toLowerCase();
        Logger.debug('  Characteristic: $uuid, properties: ${char.properties}', tag: 'BleConnection');

        if (uuid == BleConstants.moveCharacteristicUuid.toLowerCase()) {
          _moveCharacteristic = char;
        } else if (uuid == BleConstants.stateNotifyCharacteristicUuid.toLowerCase()) {
          _stateNotifyCharacteristic = char;
        } else if (uuid == BleConstants.controlCharacteristicUuid.toLowerCase()) {
          _controlCharacteristic = char;
        }
      }

      if (_moveCharacteristic == null || _stateNotifyCharacteristic == null || _controlCharacteristic == null) {
        Logger.error(
          'Missing characteristics - move: ${_moveCharacteristic != null}, '
          'stateNotify: ${_stateNotifyCharacteristic != null}, '
          'control: ${_controlCharacteristic != null}',
          tag: 'BleConnection',
        );
        throw const BleConnectionException('Required characteristics not found');
      }

      // Subscribe to notifications
      Logger.debug('Setting up notifications...', tag: 'BleConnection');
      await _setupNotifications();
      Logger.debug('Notifications set up successfully', tag: 'BleConnection');

      _isConnected = true;
    } catch (e) {
      Logger.error('initialize() failed: $e', tag: 'BleConnection');
      throw BleConnectionException('Failed to initialize connection: $e', originalError: e);
    }
  }

  Future<void> _setupNotifications() async {
    // Enable notifications on state characteristic
    if (_stateNotifyCharacteristic != null) {
      _stateSubscription = await _enableNotificationSubscription(
        characteristic: _stateNotifyCharacteristic!,
        label: 'STATE_NOTIFY',
        requiredSubscription: true,
      );
    }

    // Enable notifications on control characteristic
    if (_controlCharacteristic != null) {
      _controlSubscription = await _enableNotificationSubscription(
        characteristic: _controlCharacteristic!,
        label: 'CONTROL',
        requiredSubscription: false,
      );
    }
  }

  Future<StreamSubscription<List<int>>?> _enableNotificationSubscription({
    required BluetoothCharacteristic characteristic,
    required String label,
    required bool requiredSubscription,
  }) async {
    final supportsNotify =
        characteristic.properties.notify || characteristic.properties.indicate;
    final uuid = characteristic.uuid.str128;

    Logger.debug(
      'Notification capability [$label] uuid=$uuid '
      'notify=${characteristic.properties.notify} '
      'indicate=${characteristic.properties.indicate}',
      tag: 'BleConnection',
    );

    if (!supportsNotify) {
      final message =
          'Skipping notification subscription for $label ($uuid): '
          'NOTIFY/INDICATE not supported by discovered characteristic properties';
      if (requiredSubscription) {
        throw BleConnectionException(message);
      }

      Logger.warn(message, tag: 'BleConnection');
      return null;
    }

    try {
      await characteristic.setNotifyValue(true);
      return characteristic.onValueReceived.listen(
        _handleIncomingData,
        onError: _handleError,
      );
    } catch (e) {
      final message =
          'Failed to enable notifications for $label ($uuid): $e';
      if (requiredSubscription) {
        throw BleConnectionException(message, originalError: e);
      }

      Logger.warn(message, tag: 'BleConnection');
      return null;
    }
  }

  void _handleIncomingData(List<int> data) {
    try {
      final bytes = Uint8List.fromList(data);
      final message = _codec.decode(bytes);
      _messageController.add(message);
    } catch (e) {
      Logger.error('Failed to decode message: $e', tag: 'BleConnection');
    }
  }

  void _handleError(Object error) {
    Logger.error('Stream error: $error', tag: 'BleConnection');
  }

  // Sends a move messge (for clients)
  @override
  Future<void> sendMove(MoveMessage message) async {
    if (!isConnected) {
      throw const BleDisconnectedException('Not connected');
    }

    if (_moveCharacteristic == null) {
      throw const BleConnectionException('Move characteristic not available');
    }

    final bytes = _codec.encode(message);
    await _moveCharacteristic!.write(bytes.toList());
  }

  // Sends a control message (handshake, sync, etc.)
  @override
  Future<void> sendControl(BleMessage message) async {
    if (!isConnected) {
      throw const BleDisconnectedException('Not connected');
    }

    if (_controlCharacteristic == null) {
      throw const BleConnectionException('Control characteristic not available');
    }

    final bytes = _codec.encode(message);
    await _controlCharacteristic!.write(bytes.toList());
  }
  
  // Sends a state notification (for host)
  @override
  Future<void> sendStateNotification(BleMessage message) async {
    if (!isConnected) {
      throw const BleDisconnectedException('Not connected');
    }

    if (_stateNotifyCharacteristic == null) {
      throw const BleConnectionException('State characteristic not available');
    }

    final bytes = _codec.encode(message);

    await _stateNotifyCharacteristic!.write(bytes.toList());
  }

  // Disconnects from the device
  @override
  Future<void> disconnect() async {
    _isConnected = false;

    await _stateSubscription?.cancel();
    await _controlSubscription?.cancel();

    try {
      await device.disconnect();
    } catch (e) {
      // Ignore disconnect errors
    }

    await _messageController.close();
  }
}

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../core/constants/ble_constants.dart';
import '../../core/errors/ble_exception.dart';
import 'message_codec.dart';
import 'message_models.dart';

class BleConnection {
  BleConnection({
    required this.device,
    required this.isHost,
  });

  // The connected device
  final BluetoothDevice device;
  
  // Whether this device is the host
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

  Stream<BleMessage> get messages => _messageController.stream;
  bool get isConnected => _isConnected;
  String get deviceName => device.platformName;
  String get deviceId => device.remoteId.str;

  Future<void> initialize() async {
    try {
      // Discover services
      final services = await device.discoverServices();

      // Find our chess service
      _service = services.firstWhere(
        (s) => s.uuid.toString().toLowerCase() == BleConstants.serviceUuid.toLowerCase(),
        orElse: () => throw const BleConnectionException('Chess service not found on device'),
      );

      // Find characteristic
      for (final char in _service!.characteristics) {
        final uuid = char.uuid.toString().toLowerCase();

        if (uuid == BleConstants.moveCharacteristicUuid.toLowerCase()) {
          _moveCharacteristic = char;
        } else if (uuid == BleConstants.stateNotifyCharacteristicUuid.toLowerCase()) {
          _stateNotifyCharacteristic = char;
        } else if (uuid == BleConstants.controlCharacteristicUuid.toLowerCase()) {
          _controlCharacteristic = char;
        }
      }

      if (_moveCharacteristic == null || _stateNotifyCharacteristic == null || _controlCharacteristic == null) {
        throw const BleConnectionException('Required characteristics not found');
      }

      // Subscribe to notifications
      await _setupNotifications();

      _isConnected = true;
    } catch (e) {
      throw BleConnectionException('Failed to initialize connection: $e', originalError: e);
    }
  }

  Future<void> _setupNotifications() async {
    // Enable notifications on state characteristic
    if (_stateNotifyCharacteristic != null) {
      await _stateNotifyCharacteristic!.setNotifyValue(true);
      _stateSubscription = _stateNotifyCharacteristic!.onValueReceived.listen(
        _handleIncomingData,
        onError: _handleError,
      );
    }

    // Enable notifications on control characteristic
    if (_controlCharacteristic != null) {
      await _controlCharacteristic!.setNotifyValue(true);
      _controlSubscription = _controlCharacteristic!.onValueReceived.listen(
        _handleIncomingData,
        onError: _handleError,
      );
    }
  }

  void _handleIncomingData(List<int> data) {
    try {
      final bytes = Uint8List.fromList(data);
      final message = _codec.decode(bytes);
      _messageController.add(message);
    } catch (e) {
      print('BleConnection: Failed to decode message: $e');
    }
  }

  void _handleError(Object error) {
    print('BleConnection: Stream error: $error');
  }

  // Sends a move messge (for clients)
  Future<void> sendMove(MoveMessage message) async {
    if (!isConnected) {
      throw const BleDisconnectedException('Not connected');
    }

    if (_moveCharacteristic == null) {
      throw const BleConnectionException('Move characteristic not available');
    }

    final bytes = _codec.encode(message);
    await _moveCharacteristic!.write(bytes.toList(), withoutResponse: false);
  }

  // Sends a control message (handshake, sync, etc.)
  Future<void> sendControl(BleMessage message) async {
    if (!isConnected) {
      throw const BleDisconnectedException('Not connected');
    }

    if (_controlCharacteristic == null) {
      throw const BleConnectionException('Control characteristic not available');
    }

    final bytes = _codec.encode(message);
    await _controlCharacteristic!.write(bytes.toList(), withoutResponse: false);
  }
  
  // Sends a state notification (for host)
  Future<void> sendStateNotification(BleMessage message) async {
    if (!isConnected) {
      throw const BleDisconnectedException('Not connected');
    }

    if (_stateNotifyCharacteristic == null) {
      throw const BleConnectionException('State characteristic not available');
    }

    final bytes = _codec.encode(message);

    await _stateNotifyCharacteristic!.write(bytes.toList(), withoutResponse: false);
  }

  // Disconnects from the device
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

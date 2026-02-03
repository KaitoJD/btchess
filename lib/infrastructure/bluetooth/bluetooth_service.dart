import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../core/constants/ble_constants.dart';
import '../../core/constants/timing_constants.dart';
import '../../core/errors/ble_exception.dart';
import 'ble_connection.dart';

class BleDeviceInfo {
  const BleDeviceInfo({
    required this.id,
    required this.name,
    required this.rssi,
    required this.device,
  });

  final String id;
  final String name;
  final int rssi;
  final BluetoothDevice device;
}

class BluetoothService {
  // Stream controller for scanned devices
  final StreamController<List<BleDeviceInfo>> _devicesController = StreamController<List<BleDeviceInfo>>.broadcast();

  // Currently discovered devices
  final Map<String, BleDeviceInfo> _discoveredDevices = {};

  // Scan subscription
  StreamSubscription<List<ScanResult>>? _scanSubscription;

  // Whether currently scanning
  bool _isScanning = false;

  // Stream of discovered devices
  Stream<List<BleDeviceInfo>> get discoveredDevices => _devicesController.stream;

  // Whether BLE is supported on this device
  Future<bool> get isSupported async{
    return await FlutterBluePlus.isSupported;
  }

  // Whether Bluetooth is currently on
  Future<bool> get isBluetoothOn async {
    final state = await FlutterBluePlus.adapterState.first;
    return state == BluetoothAdapterState.on;
  }

  // Stream of Bluetooth adapter state changes
  Stream<BluetoothAdapterState> get adapterState => FlutterBluePlus.adapterState;

  // Whether currently scanning
  bool get isScanning => _isScanning;

  // Checks if all required permission are granted
  Future<bool> checkPermissions() async {
    // flutter_blue_plus handles permission requests internally
    // This is a simplified check
    try {
      final isSupported = await FlutterBluePlus.isSupported;
      if (!isSupported) return false;

      final state = await FlutterBluePlus.adapterState.first;
      return state == BluetoothAdapterState.on;
    } catch (e) {
      return false;
    }
  }

  // Request Bluetooth to be turned on
  Future<void> requestBluetoothOn() async {
    await FlutterBluePlus.turnOn();
  }

  // Starts scanning for BTChess devices
  Future<void> startScanning() async {
    if (_isScanning) return;

    final isOn = await isBluetoothOn;
    if (!isOn) {
      throw const BleNotAvailableException('Bluetooth is not enabled');
    }

    _isScanning = true;
    _discoveredDevices.clear();

    _scanSubscription = FlutterBluePlus.scanResults.listen(
      _handleScanResults,
      onError: _handleScanError,
    );

    await FlutterBluePlus.startScan(
      withServices: [Guid(BleConstants.serviceUuid)],
      timeout: const Duration(seconds: BleConstants.scanTimeoutSeconds),
    );
  }

  void _handleScanResults(List<ScanResult> results) {
    for (final result in results) {
      final device = result.device;
      final name = device.platformName;

      if (name.startsWith(BleConstants.deviceNamePrefix)) {
        _discoveredDevices[device.remoteId.str] = BleDeviceInfo(
          id: device.remoteId.str,
          name: name,
          rssi: result.rssi,
          device: device,
        );
      }
    }

    _devicesController.add(_discoveredDevices.values.toList());
  }

  void _handleScanError(Object error) {
    print('BluetoothService: Scan error: $error');
    _isScanning = false;
  }

  // Stops scanning
  Future<void> stopScanning() async {
    if (!_isScanning) return;

    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    _isScanning = false;
  }

  // Connects to a device
  Future<BleConnection> connect(BleDeviceInfo deviceInfo, {bool asHost = false}) async {
    await stopScanning();

    try {
      await deviceInfo.device.connect(
        timeout: const Duration(milliseconds: TimingConstants.connectionTimeoutMs),
      );

      await deviceInfo.device.requestMtu(BleConstants.maxMtu);

      final connection = BleConnection(
        device: deviceInfo.device,
        isHost: asHost,
      );

      await connection.initialize();

      return connection;
    } catch (e) {
      throw BleConnectionException('Failed to connect to device: $e', originalError: e);
    }
  }

  /* Starts advertising as a host
   * 
   * Note: flutter_blue_plus doesn't support peripheral mode
   * This requires platform-specific implementation or additional package
   */
  Future<void> startAdvertising(String gameName) async {
    // TODO: Implement advertising using platform channels or ble_peripheral package
    throw UnimplementedError('Advertising requires additional platform-specific implementation');
  }

  // Stops advertising
  Future<void> stopAdvertising() async {
    // TODO: Implement
  }

  // Gets currently connected devices
  Future<List<BluetoothDevice>> getConnectedDevices() async {
    return await FlutterBluePlus.connectedDevices;
  }

  // Disposes resources
  void dispose() {
    stopScanning();
    _devicesController.close();
  }
}
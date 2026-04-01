import 'dart:async';
import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../core/constants/ble_constants.dart';
import '../../core/constants/timing_constants.dart';
import '../../core/errors/ble_exception.dart';
import '../../core/utils/logger.dart';
import 'ble_connection.dart';
import 'ble_peripheral.dart';

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
  // BLE peripheral manager for host advertising mode
  final BlePeripheralManager _peripheralManager = BlePeripheralManager();

  // Stream controller for scanned devices
  final StreamController<List<BleDeviceInfo>> _devicesController = StreamController<List<BleDeviceInfo>>.broadcast();

  // Currently discovered devices
  final Map<String, BleDeviceInfo> _discoveredDevices = {};

  // Scan subscription
  StreamSubscription<List<ScanResult>>? _scanSubscription;

  // Optional timer for switching from service-filter scan to broad scan
  Timer? _scanFallbackTimer;

  // Tracks scan timing and mode for diagnostics.
  DateTime? _scanStartedAt;
  bool _isFallbackScanActive = false;
  bool _hasLoggedFirstDevice = false;

  // Whether currently scanning
  bool _isScanning = false;

  // Stream of discovered devices
  Stream<List<BleDeviceInfo>> get discoveredDevices => _devicesController.stream;

  // Whether BLE is supported on this device
  Future<bool> get isSupported async{
    return FlutterBluePlus.isSupported;
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
    _scanStartedAt = DateTime.now();
    _isFallbackScanActive = Platform.isIOS;
    _hasLoggedFirstDevice = false;

    _scanSubscription = FlutterBluePlus.scanResults.listen(
      _handleScanResults,
      onError: _handleScanError,
    );

    if (Platform.isIOS) {
      Logger.debug(
        'Starting compatibility-first broad scan on iOS',
        tag: 'BluetoothService',
      );
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: BleConstants.scanTimeoutSeconds),
      );
      _scanFallbackTimer?.cancel();
      _scanFallbackTimer = null;
    } else {
      Logger.debug(
        'Starting service-filtered scan (fallback in ${BleConstants.scanFallbackDelaySeconds}s)',
        tag: 'BluetoothService',
      );
      await FlutterBluePlus.startScan(
        withServices: [Guid(BleConstants.serviceUuid)],
        timeout: const Duration(seconds: BleConstants.scanTimeoutSeconds),
      );

      _scheduleScanFallback();
    }
  }

  void _scheduleScanFallback() {
    _scanFallbackTimer?.cancel();
    _scanFallbackTimer = Timer(
      const Duration(seconds: BleConstants.scanFallbackDelaySeconds),
      () async {
        if (!_isScanning || _discoveredDevices.isNotEmpty) {
          return;
        }

        try {
          final elapsed = _scanStartedAt == null
              ? null
              : DateTime.now().difference(_scanStartedAt!).inMilliseconds;
          Logger.debug(
            'No devices found with service-filtered scan, retrying without service filter '
            '(elapsed=${elapsed ?? -1}ms)',
            tag: 'BluetoothService',
          );
          _isFallbackScanActive = true;
          await FlutterBluePlus.stopScan();
          await FlutterBluePlus.startScan(
            timeout: const Duration(seconds: BleConstants.scanTimeoutSeconds),
          );
        } catch (e) {
          Logger.warn('Failed to switch to scan fallback mode: $e', tag: 'BluetoothService');
        }
      },
    );
  }

  void _handleScanResults(List<ScanResult> results) {
    for (final result in results) {
      final device = result.device;
      final extracted = _extractDeviceName(result);
      final name = extracted.name;

      if (name.startsWith(BleConstants.deviceNamePrefix)) {
        _discoveredDevices[device.remoteId.str] = BleDeviceInfo(
          id: device.remoteId.str,
          name: name,
          rssi: result.rssi,
          device: device,
        );

        if (!_hasLoggedFirstDevice) {
          _hasLoggedFirstDevice = true;
          final elapsed = _scanStartedAt == null
              ? null
              : DateTime.now().difference(_scanStartedAt!).inMilliseconds;
          Logger.debug(
            'First BTChess device discovered in ${elapsed ?? -1}ms '
            '(scanMode=${_isFallbackScanActive ? 'fallback' : 'service-filtered'}, '
            'nameSource=${extracted.source})',
            tag: 'BluetoothService',
          );
        }
      }
    }

    _devicesController.add(_discoveredDevices.values.toList());
  }

  ({String name, String source}) _extractDeviceName(ScanResult result) {
    String? fromLocalName;
    String? fromAdvName;

    // Access advertisement fields dynamically so we remain compatible
    // across minor plugin API differences.
    final advData = result.advertisementData as dynamic;
    try {
      fromLocalName = advData.localName as String?;
    } catch (_) {}
    try {
      fromAdvName = advData.advName as String?;
    } catch (_) {}

    final localName = (fromLocalName ?? '').trim();
    if (localName.isNotEmpty) {
      return (name: localName, source: 'advertisement.localName');
    }

    final advName = (fromAdvName ?? '').trim();
    if (advName.isNotEmpty) {
      return (name: advName, source: 'advertisement.advName');
    }

    final platformName = result.device.platformName.trim();
    return (name: platformName, source: 'device.platformName');
  }

  void _handleScanError(Object error) {
    Logger.error('Scan error: $error', tag: 'BluetoothService');
    _isScanning = false;
  }

  // Stops scanning
  Future<void> stopScanning() async {
    if (!_isScanning) return;

    await FlutterBluePlus.stopScan();
    _scanFallbackTimer?.cancel();
    _scanFallbackTimer = null;
    _scanStartedAt = null;
    _isFallbackScanActive = false;
    _hasLoggedFirstDevice = false;
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    _isScanning = false;
  }

  // Connects to a device
  Future<BleConnection> connect(BleDeviceInfo deviceInfo, {bool asHost = false}) async {
    await stopScanning();

    bool bleConnected = false;
    try {
      await deviceInfo.device.connect(
        license: License.free,
        timeout: const Duration(milliseconds: TimingConstants.connectionTimeoutMs),
      );
      bleConnected = true;

      if (Platform.isAndroid) {
        try {
          await deviceInfo.device.requestMtu(BleConstants.maxMtu);
        } catch (e) {
          Logger.warn('Failed to request MTU on Android: $e', tag: 'BluetoothService');
        }
      }

      final connection = BleConnection(
        device: deviceInfo.device,
        isHost: asHost,
      );

      await connection.initialize();

      return connection;
    } catch (e) {
      // Tear down the BLE link so the remote side detects disconnect promptly
      if (bleConnected) {
        try {
          await deviceInfo.device.disconnect();
        } catch (_) {}
      }
      throw BleConnectionException('Failed to connect to device: $e', originalError: e);
    }
  }

  // The peripheral manager for host mode
  BlePeripheralManager get peripheralManager => _peripheralManager;

  // Starts advertising as a host using BlePeripheralManager
  Future<void> startAdvertising(String gameName) async {
    await _peripheralManager.initialize();
    await _peripheralManager.startAdvertising(gameName);
  }

  // Stops advertising
  Future<void> stopAdvertising() async {
    await _peripheralManager.stopAdvertising();
  }

  // Gets currently connected devices
  Future<List<BluetoothDevice>> getConnectedDevices() async {
    return FlutterBluePlus.connectedDevices;
  }

  // Disposes resources
  void dispose() {
    _scanFallbackTimer?.cancel();
    _scanFallbackTimer = null;
    stopScanning();
    _peripheralManager.dispose();
    _devicesController.close();
  }
}
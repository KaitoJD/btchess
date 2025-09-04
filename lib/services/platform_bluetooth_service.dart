import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:universal_platform/universal_platform.dart';

// Classic Bluetooth imports (Android/Linux)
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart' as classic;
import 'package:permission_handler/permission_handler.dart';

// BLE imports (iOS/macOS/Windows)
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as ble;

/// Unified Bluetooth service that handles both Classic Bluetooth and BLE
/// depending on the platform capabilities
class PlatformBluetoothService {
  static final PlatformBluetoothService _instance = PlatformBluetoothService._internal();
  factory PlatformBluetoothService() => _instance;
  PlatformBluetoothService._internal();

  // Platform detection
  bool get isClassicBluetoothPlatform => 
      UniversalPlatform.isAndroid || UniversalPlatform.isLinux;
  
  bool get isBlePlatform => 
      UniversalPlatform.isIOS || UniversalPlatform.isMacOS || UniversalPlatform.isWindows;

  // Classic Bluetooth state
  classic.BluetoothConnection? _classicConnection;
  StreamSubscription<Uint8List>? _classicDataSubscription;

  // BLE state
  ble.BluetoothDevice? _bleDevice;
  ble.BluetoothCharacteristic? _bleCharacteristic;
  StreamSubscription<List<int>>? _bleDataSubscription;

  // Common state
  bool _isConnected = false;
  final StreamController<String> _messageController = StreamController<String>.broadcast();
  final StreamController<BluetoothDeviceInfo> _deviceController = StreamController<BluetoothDeviceInfo>.broadcast();

  // Chess service UUID for BLE (custom UUID)
  static const String chessServiceUuid = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E";
  static const String chessCharacteristicUuid = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E";

  Stream<String> get messageStream => _messageController.stream;
  Stream<BluetoothDeviceInfo> get deviceStream => _deviceController.stream;
  bool get isConnected => _isConnected;

  /// Initialize Bluetooth based on platform
  Future<bool> initialize() async {
    try {
      if (isClassicBluetoothPlatform) {
        return await _initializeClassicBluetooth();
      } else if (isBlePlatform) {
        return await _initializeBLE();
      }
      return false;
    } catch (e) {
      debugPrint('Failed to initialize Bluetooth: $e');
      return false;
    }
  }

  /// Initialize Classic Bluetooth (Android/Linux)
  Future<bool> _initializeClassicBluetooth() async {
    if (!await _requestPermissions()) {
      return false;
    }

    try {
      final isEnabled = await classic.FlutterBluetoothSerial.instance.isEnabled;
      if (isEnabled != true) {
        await classic.FlutterBluetoothSerial.instance.requestEnable();
      }
      return true;
    } catch (e) {
      debugPrint('Classic Bluetooth initialization failed: $e');
      return false;
    }
  }

  /// Initialize BLE (iOS/macOS/Windows)
  Future<bool> _initializeBLE() async {
    try {
      // Check if Bluetooth is supported
      if (await ble.FlutterBluePlus.isSupported == false) {
        debugPrint("Bluetooth not supported by this device");
        return false;
      }

      // Turn on Bluetooth if needed (Android only)
      if (UniversalPlatform.isAndroid) {
        await ble.FlutterBluePlus.turnOn();
      }

      return true;
    } catch (e) {
      debugPrint('BLE initialization failed: $e');
      return false;
    }
  }

  /// Request necessary permissions
  Future<bool> _requestPermissions() async {
    if (UniversalPlatform.isAndroid) {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetooth,
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
        Permission.bluetoothAdvertise,
        Permission.location,
      ].request();

      return statuses.values.every((status) => 
          status == PermissionStatus.granted || status == PermissionStatus.limited);
    }
    return true;
  }

  /// Scan for devices
  Future<void> startScanning() async {
    if (isClassicBluetoothPlatform) {
      await _scanClassicDevices();
    } else if (isBlePlatform) {
      await _scanBleDevices();
    }
  }

  /// Scan for Classic Bluetooth devices
  Future<void> _scanClassicDevices() async {
    try {
      final devices = await classic.FlutterBluetoothSerial.instance.getBondedDevices();
      for (final device in devices) {
        _deviceController.add(BluetoothDeviceInfo(
          name: device.name ?? 'Unknown Device',
          address: device.address,
          isClassic: true,
          device: device,
        ));
      }
    } catch (e) {
      debugPrint('Classic device scan failed: $e');
    }
  }

  /// Scan for BLE devices
  Future<void> _scanBleDevices() async {
    try {
      // Listen to scan results
      var subscription = ble.FlutterBluePlus.scanResults.listen((results) {
        for (ble.ScanResult result in results) {
          // Look for devices advertising our chess service
          if (result.device.platformName.isNotEmpty) {
            _deviceController.add(BluetoothDeviceInfo(
              name: result.device.platformName,
              address: result.device.remoteId.toString(),
              isClassic: false,
              device: result.device,
            ));
          }
        }
      });

      // Start scanning
      await ble.FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

      // Stop scanning after timeout
      await Future.delayed(const Duration(seconds: 10));
      await ble.FlutterBluePlus.stopScan();
      subscription.cancel();
    } catch (e) {
      debugPrint('BLE device scan failed: $e');
    }
  }

  /// Connect to a device
  Future<bool> connectToDevice(BluetoothDeviceInfo deviceInfo) async {
    if (deviceInfo.isClassic) {
      return await _connectClassicDevice(deviceInfo.device as classic.BluetoothDevice);
    } else {
      return await _connectBleDevice(deviceInfo.device as ble.BluetoothDevice);
    }
  }

  /// Connect to Classic Bluetooth device
  Future<bool> _connectClassicDevice(classic.BluetoothDevice device) async {
    try {
      _classicConnection = await classic.BluetoothConnection.toAddress(device.address);
      _isConnected = true;

      _classicDataSubscription = _classicConnection!.input!.listen((data) {
        final message = utf8.decode(data);
        _messageController.add(message);
      });

      return true;
    } catch (e) {
      debugPrint('Classic device connection failed: $e');
      return false;
    }
  }

  /// Connect to BLE device
  Future<bool> _connectBleDevice(ble.BluetoothDevice device) async {
    try {
      await device.connect();
      _bleDevice = device;

      // Discover services
      List<ble.BluetoothService> services = await device.discoverServices();
      
      // Find our chess service
      ble.BluetoothService? chessService;
      for (var service in services) {
        if (service.uuid.toString().toUpperCase() == chessServiceUuid.toUpperCase()) {
          chessService = service;
          break;
        }
      }

      if (chessService != null) {
        // Find the characteristic
        for (var characteristic in chessService.characteristics) {
          if (characteristic.uuid.toString().toUpperCase() == chessCharacteristicUuid.toUpperCase()) {
            _bleCharacteristic = characteristic;
            
            // Enable notifications
            await characteristic.setNotifyValue(true);
            
            // Listen for data
            _bleDataSubscription = characteristic.value.listen((data) {
              final message = utf8.decode(data);
              _messageController.add(message);
            });
            
            _isConnected = true;
            return true;
          }
        }
      }

      return false;
    } catch (e) {
      debugPrint('BLE device connection failed: $e');
      return false;
    }
  }

  /// Send a message
  Future<void> sendMessage(String message) async {
    if (!_isConnected) return;

    final data = utf8.encode(message);

    if (isClassicBluetoothPlatform && _classicConnection != null) {
      _classicConnection!.output.add(Uint8List.fromList(data));
      await _classicConnection!.output.allSent;
    } else if (isBlePlatform && _bleCharacteristic != null) {
      await _bleCharacteristic!.write(data);
    }
  }

  /// Disconnect from device
  Future<void> disconnect() async {
    if (isClassicBluetoothPlatform) {
      await _classicDataSubscription?.cancel();
      await _classicConnection?.close();
      _classicConnection = null;
    } else if (isBlePlatform) {
      await _bleDataSubscription?.cancel();
      await _bleDevice?.disconnect();
      _bleDevice = null;
      _bleCharacteristic = null;
    }

    _isConnected = false;
  }

  /// Start advertising (for host mode in BLE)
  Future<bool> startAdvertising() async {
    if (isBlePlatform) {
      try {
        // Note: BLE advertising is complex and platform-specific
        // This is a simplified version - you might need platform-specific implementation
        debugPrint('BLE advertising started (platform-specific implementation needed)');
        return true;
      } catch (e) {
        debugPrint('Failed to start BLE advertising: $e');
        return false;
      }
    } else if (isClassicBluetoothPlatform) {
      // Classic Bluetooth can use server socket
      try {
        debugPrint('Classic Bluetooth server mode (implementation needed)');
        return true;
      } catch (e) {
        debugPrint('Failed to start Classic Bluetooth server: $e');
        return false;
      }
    }
    return false;
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _deviceController.close();
  }
}

/// Device information wrapper
class BluetoothDeviceInfo {
  final String name;
  final String address;
  final bool isClassic;
  final dynamic device; // Either classic.BluetoothDevice or ble.BluetoothDevice

  BluetoothDeviceInfo({
    required this.name,
    required this.address,
    required this.isClassic,
    required this.device,
  });
}

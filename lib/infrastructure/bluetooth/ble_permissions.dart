import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/utils/logger.dart';

class BlePermissions {
  static Future<bool> areGranted() async {
    if (kIsWeb) return false;

    if (Platform.isAndroid) {
      return _checkAndroidPermissions();
    } else if (Platform.isIOS) {
      return _checkIosPermissions();
    }

    return false;
  }

  static Future<bool> request() async {
    if (kIsWeb) return false;

    if (Platform.isAndroid) {
      return _requestAndroidPermission();
    } else if (Platform.isIOS) {
      return _requestIosPermissions();
    }

    return false;
  }

  static Future<bool> isPermanentlyDenied() async {
    if (kIsWeb) return false;

    if (Platform.isIOS) {
      final status = await Permission.bluetooth.status;
      return status.isPermanentlyDenied;
    }

    if (Platform.isAndroid) {
      final statuses = await Future.wait([
        Permission.bluetoothScan.status,
        Permission.bluetoothConnect.status,
        Permission.bluetoothAdvertise.status,
        Permission.locationWhenInUse.status,
      ]);

      return statuses.any((status) => status.isPermanentlyDenied);
    }

    return false;
  }

  static Future<bool> _checkAndroidPermissions() async {
    // Android 12+ requires BLUETOOTH_SCAN and BLUETOOTH_CONNECT
    // Older versions require BLUETOOTH and BLUETOOTH_ADMIN
    final bluetoothScan = await Permission.bluetoothScan.isGranted;
    final bluetoothConnect = await Permission.bluetoothConnect.isGranted;
    final location = await Permission.locationWhenInUse.isGranted;

    return bluetoothScan && bluetoothConnect && location;
  }

  static Future<bool> _requestAndroidPermission() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.locationWhenInUse,
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }

  static Future<bool> _checkIosPermissions() async {
    final status = await Permission.bluetooth.status;
    Logger.debug('iOS Bluetooth permission status (check): $status', tag: 'BlePermissions');

    if (status.isGranted) {
      return true;
    }

    // Defensive fallback: if permission_handler was misconfigured on iOS,
    // adapter authorization still reveals whether BLE access is usable.
    return _isIosAdapterAuthorized();
  }

  static Future<bool> _requestIosPermissions() async {
    final before = await Permission.bluetooth.status;
    Logger.debug('iOS Bluetooth permission status (before request): $before', tag: 'BlePermissions');

    final status = await Permission.bluetooth.request();
    Logger.debug('iOS Bluetooth permission status (request result): $status', tag: 'BlePermissions');

    if (status.isGranted) {
      // Allow iOS to settle authorization state before re-checking.
      await Future.delayed(const Duration(milliseconds: 250));
      final verified = await Permission.bluetooth.status;
      Logger.debug('iOS Bluetooth permission status (post-request verify): $verified', tag: 'BlePermissions');
      if (verified.isGranted) {
        return true;
      }
    }

    return _isIosAdapterAuthorized();
  }

  static Future<bool> _isIosAdapterAuthorized() async {
    try {
      final adapterState = await FlutterBluePlus.adapterState.first;
      Logger.debug('iOS adapter state fallback check: $adapterState', tag: 'BlePermissions');

      switch (adapterState) {
        case BluetoothAdapterState.on:
        case BluetoothAdapterState.off:
          return true;
        case BluetoothAdapterState.unavailable:
        case BluetoothAdapterState.turningOn:
        case BluetoothAdapterState.turningOff:
        case BluetoothAdapterState.unauthorized:
        default:
          return false;
      }
    } catch (e) {
      Logger.warn('iOS adapter fallback check failed: $e', tag: 'BlePermissions');
      return false;
    }
  }

  static Future<void> openSettings() async {
    await openAppSettings();
  }
}
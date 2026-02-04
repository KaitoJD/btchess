import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class BlePermissions {
  static Future<bool> areGranted() async {
    if (kIsWeb) return false;

    if (Platform.isAndroid) {
      return await _checkAndroidPermissions();
    } else if (Platform.isIOS) {
      return await _checkIosPermissions();
    }

    return false;
  }

  static Future<bool> request() async {
    if (kIsWeb) return false;

    if (Platform.isAndroid) {
      return await _requestAndroidPermission();
    } else if (Platform.isIOS) {
      return await _requestIosPermissions();
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
    // iOS uses Bluetooth permission
    return await Permission.bluetooth.isGranted;
  }

  static Future<bool> _requestIosPermissions() async {
    final status = await Permission.bluetooth.request();
    return status.isGranted;
  }

  static Future<void> openSettings() async {
    await openAppSettings();
  }
}
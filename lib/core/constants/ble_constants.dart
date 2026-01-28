// BLE GATT UUIDs and configuration constants

abstract class BleConstants {
  // Service & Characteristic UUIDs

  static const String serviceUuid =                   '0000c0de-0000-1000-8000-00805f9b34fb';
  static const String moveCharacteristicUuid =        '0000c0de-0001-1000-8000-00805f9b34fb';
  static const String stateNotifyCharacteristicUuid = '0000c0de-0002-1000-8000-00805f9b34fb';
  static const String controlCharacteristicUuid =     '0000c0de-0003-1000-8000-00805f9b34fb';

  // Protocol Version

  static const int protocolVersion = 0x01;

  // MTU & Packet Size

  static const int defaultMtu = 23;
  static const int defaultPayloadSize = 20;
  static const int maxMtu = 512;

  // Advertising

  static const int advertisingIntervalMs = 100;
  static const int scanTimeoutSeconds = 30;
  static const String deviceNamePrefix = 'BTChess';

  // Role Codes

  static const int roleHost = 0x01;
  static const int roleClient = 0x02;
}
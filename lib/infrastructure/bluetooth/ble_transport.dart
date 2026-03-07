import 'message_models.dart';

// Abstract transport interface used by [ConnectionManager] to send and receive
// BLE messages regardless of whether this device is a client (flutter_blue_plus)
//  or a host (ble_peripheral).
abstract class BleTransport {
  Stream<BleMessage> get messages;
  bool get isHost;
  String get deviceName;

  Future<void> sendMove(MoveMessage message);
  Future<void> sendControl(BleMessage message);
  Future<void> sendStateNotification(BleMessage message);
  Future<void> disconnect();
}

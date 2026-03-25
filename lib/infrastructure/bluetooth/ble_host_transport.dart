import 'ble_peripheral.dart';
import 'ble_transport.dart';
import '../../core/utils/logger.dart';
import 'message_models.dart';

// Adapter that wraps [BlePeripheralManager] behind the [BleTransport]
//  interface so [ConnectionManager] can operate in host mode without knowing
//   the underlying transport details.
class BleHostTransport implements BleTransport {
  BleHostTransport(this._peripheral);

  final BlePeripheralManager _peripheral;

  @override
  Stream<BleMessage> get messages => _peripheral.messages;

  @override
  bool get isHost => true;

  @override
  String get deviceName => 'Host';

  @override
  Future<void> sendMove(MoveMessage message) async {
    Logger.debug(
      'HostTransport sendMove msgId=${message.messageId} routed=stateNotify',
      tag: 'BleHostTransport',
    );
    await _peripheral.sendStateNotification(message);
  }

  @override
  Future<void> sendControl(BleMessage message) async {
    Logger.debug(
      'HostTransport sendControl type=${message.type.value} msgId=${message.messageId} routed=stateNotify',
      tag: 'BleHostTransport',
    );
    await _peripheral.sendStateNotification(message);
  }

  @override
  Future<void> sendStateNotification(BleMessage message) async {
    Logger.debug(
      'HostTransport sendStateNotification type=${message.type.value} msgId=${message.messageId}',
      tag: 'BleHostTransport',
    );
    await _peripheral.sendStateNotification(message);
  }

  @override
  Future<void> disconnect() async {
    await _peripheral.stopAdvertising();
  }
}

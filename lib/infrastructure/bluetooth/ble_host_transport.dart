import 'dart:async';

import '../../core/errors/ble_exception.dart';
import 'ble_peripheral.dart';
import 'ble_transport.dart';
import '../../core/utils/logger.dart';
import 'message_models.dart';

// Adapter that wraps [BlePeripheralManager] behind the [BleTransport]
//  interface so [ConnectionManager] can operate in host mode without knowing
//   the underlying transport details.
class BleHostTransport implements BleTransport {
  BleHostTransport(this._peripheral) {
    _incomingMessageSubscription = _peripheral.messages.listen(
      (message) {
        if (!_messagesController.isClosed) {
          _messagesController.add(message);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!_messagesController.isClosed) {
          _messagesController.addError(error, stackTrace);
        }
      },
    );

    _clientDisconnectedSubscription = _peripheral.clientDisconnected.listen(
      (deviceId) {
        if (_messagesController.isClosed) {
          return;
        }

        _messagesController.addError(
          BleDisconnectedException(
            'Host transport detected client disconnect: $deviceId',
          ),
        );
      },
    );
  }

  final BlePeripheralManager _peripheral;
  final StreamController<BleMessage> _messagesController =
      StreamController<BleMessage>.broadcast();
  StreamSubscription<BleMessage>? _incomingMessageSubscription;
  StreamSubscription<String>? _clientDisconnectedSubscription;

  @override
  Stream<BleMessage> get messages => _messagesController.stream;

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
    await _incomingMessageSubscription?.cancel();
    await _clientDisconnectedSubscription?.cancel();
    _incomingMessageSubscription = null;
    _clientDisconnectedSubscription = null;

    await _peripheral.stopAdvertising();

    if (!_messagesController.isClosed) {
      await _messagesController.close();
    }
  }
}

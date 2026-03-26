import 'package:btchess/infrastructure/bluetooth/ble_host_transport.dart';
import 'package:btchess/infrastructure/bluetooth/message_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mock_ble_peripheral_manager.dart';

void main() {
  late MockBlePeripheralManager peripheral;
  late BleHostTransport transport;

  setUp(() {
    peripheral = MockBlePeripheralManager();
    transport = BleHostTransport(peripheral);
  });

  test('sendControl routes through state notification on host transport', () async {
    const message = HandshakeMessage(
      messageId: 10,
      protocolVersion: 0x01,
      role: 0x01,
      hostColor: 0x01,
    );

    when(() => peripheral.sendStateNotification(message))
        .thenAnswer((_) async {});

    await transport.sendControl(message);

    verify(() => peripheral.sendStateNotification(message)).called(1);
    verifyNever(() => peripheral.sendControl(message));
  });

  test('sendMove routes through state notification on host transport', () async {
    const message = MoveMessage(
      messageId: 42,
      from: 12,
      to: 28,
    );

    when(() => peripheral.sendStateNotification(message))
        .thenAnswer((_) async {});

    await transport.sendMove(message);

    verify(() => peripheral.sendStateNotification(message)).called(1);
    verifyNever(() => peripheral.sendControl(message));
  });

  test('sendStateNotification remains routed to state notification', () async {
    const message = GameStartMessage(messageId: 99);

    when(() => peripheral.sendStateNotification(message))
        .thenAnswer((_) async {});

    await transport.sendStateNotification(message);

    verify(() => peripheral.sendStateNotification(message)).called(1);
  });
}

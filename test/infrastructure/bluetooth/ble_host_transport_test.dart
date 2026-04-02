import 'dart:async';

import 'package:btchess/core/errors/ble_exception.dart';
import 'package:btchess/infrastructure/bluetooth/ble_host_transport.dart';
import 'package:btchess/infrastructure/bluetooth/message_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mock_ble_peripheral_manager.dart';

void main() {
  late MockBlePeripheralManager peripheral;
  late BleHostTransport transport;
  late StreamController<BleMessage> messageController;
  late StreamController<String> clientDisconnectedController;

  setUp(() {
    peripheral = MockBlePeripheralManager();

    messageController = StreamController<BleMessage>.broadcast();
    clientDisconnectedController = StreamController<String>.broadcast();

    when(() => peripheral.messages).thenAnswer((_) => messageController.stream);
    when(() => peripheral.clientDisconnected)
        .thenAnswer((_) => clientDisconnectedController.stream);
    when(() => peripheral.stopAdvertising()).thenAnswer((_) async {});

    transport = BleHostTransport(peripheral);
  });

  tearDown(() async {
    await transport.disconnect();
    await messageController.close();
    await clientDisconnectedController.close();
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

  test('forwards incoming peripheral messages', () async {
    const message = GameStartMessage(messageId: 77);

    final future = expectLater(
      transport.messages,
      emits(message),
    );

    messageController.add(message);
    await future;
  });

  test('emits BleDisconnectedException when peripheral reports client disconnect', () async {
    final future = expectLater(
      transport.messages,
      emitsError(isA<BleDisconnectedException>()),
    );

    clientDisconnectedController.add('client-1');
    await future;
  });
}

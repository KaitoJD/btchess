import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:btchess/core/constants/ble_constants.dart';
import 'package:btchess/infrastructure/bluetooth/ble_transport.dart';
import 'package:btchess/infrastructure/bluetooth/connection_manager.dart';
import 'package:btchess/infrastructure/bluetooth/message_models.dart';

class _FakeHostTransport implements BleTransport {
  final StreamController<BleMessage> _messages =
      StreamController<BleMessage>.broadcast();

  final List<MoveMessage> sentMoves = <MoveMessage>[];
  final List<BleMessage> sentControl = <BleMessage>[];
  final List<BleMessage> sentStateNotifications = <BleMessage>[];

  @override
  Stream<BleMessage> get messages => _messages.stream;

  @override
  bool get isHost => true;

  @override
  String get deviceName => 'FakeHost';

  void emit(BleMessage message) {
    _messages.add(message);
  }

  @override
  Future<void> sendMove(MoveMessage message) async {
    sentMoves.add(message);
  }

  @override
  Future<void> sendControl(BleMessage message) async {
    sentControl.add(message);
  }

  @override
  Future<void> sendStateNotification(BleMessage message) async {
    sentStateNotifications.add(message);
  }

  @override
  Future<void> disconnect() async {
    if (!_messages.isClosed) {
      await _messages.close();
    }
  }
}

void main() {
  late ConnectionManager manager;
  late _FakeHostTransport transport;

  setUp(() {
    manager = ConnectionManager();
    transport = _FakeHostTransport();
  });

  tearDown(() async {
    await manager.disconnect();
  });

  Future<void> connectHost() async {
    final setupFuture = manager.setupConnection(transport);

    // Host waits for client handshake first.
    transport.emit(
      const HandshakeMessage(
        messageId: 1,
        protocolVersion: BleConstants.protocolVersion,
        role: BleConstants.roleClient,
      ),
    );

    await setupFuture;
    expect(manager.isConnected, isTrue);
  }

  test('drops in-flight duplicate move before ACK is sent', () async {
    await connectHost();

    var forwardedMoveCount = 0;
    final sub = manager.messages.listen((message) {
      if (message is MoveMessage) {
        forwardedMoveCount++;
      }
    });

    const move = MoveMessage(messageId: 77, from: 12, to: 28);

    // Duplicate arrives before host sends ACK.
    transport.emit(move);
    transport.emit(move);
    await Future<void>.delayed(Duration.zero);

    expect(forwardedMoveCount, 1);

    final ackCountBefore =
        transport.sentStateNotifications.whereType<AckMessage>().length;
    expect(ackCountBefore, 0);

    // Host finishes processing and ACKs the move.
    await manager.sendAck(move.messageId);

    final ackCountAfterFirstAck =
        transport.sentStateNotifications.whereType<AckMessage>().length;
    expect(ackCountAfterFirstAck, 1);

    // Any later duplicate replays the cached ACK and does not forward again.
    transport.emit(move);
    await Future<void>.delayed(Duration.zero);

    expect(forwardedMoveCount, 1);
    final ackCountAfterReplay =
        transport.sentStateNotifications.whereType<AckMessage>().length;
    expect(ackCountAfterReplay, 2);

    await sub.cancel();
  });
}

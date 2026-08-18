import 'dart:typed_data';

import 'package:ble_peripheral/ble_peripheral.dart';
import 'package:btchess/core/constants/ble_constants.dart';
import 'package:btchess/infrastructure/bluetooth/ble_peripheral.dart';
import 'package:btchess/infrastructure/bluetooth/ble_setup.dart';
import 'package:btchess/infrastructure/bluetooth/message_codec.dart';
import 'package:btchess/infrastructure/bluetooth/message_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FakePeripheral peripheral;
  late BlePeripheralManager manager;

  setUp(() async {
    peripheral = _FakePeripheral();
    BlePeripheral.setInstance(peripheral);
    manager = BlePeripheralManager();
    await manager.initialize();
    await manager.startAdvertising('pairing-test');
  });

  tearDown(() async {
    await manager.dispose();
  });

  test('does not expose a client until STATE_NOTIFY is subscribed', () async {
    final connected = <String>[];
    final phases = <BleSetupPhase>[];
    final connectedSub = manager.clientConnected.listen(connected.add);
    final phaseSub = manager.setupEvents.listen((event) {
      phases.add(event.phase);
    });

    peripheral.emitConnection('peer-1', isConnected: true);
    await _flushEvents();

    expect(manager.hasConnectedClient, isFalse);
    expect(connected, isEmpty);

    peripheral.emitSubscription(
      'peer-1',
      BleConstants.stateNotifyCharacteristicUuid,
      isSubscribed: true,
    );
    await _flushEvents();

    expect(manager.connectedClientId, 'peer-1');
    expect(connected, ['peer-1']);
    expect(phases, contains(BleSetupPhase.ready));

    await connectedSub.cancel();
    await phaseSub.cancel();
  });

  test('buffers one early handshake until the peer is ready', () async {
    const handshake = HandshakeMessage(
      messageId: 9,
      protocolVersion: BleConstants.protocolVersion,
      role: BleConstants.roleClient,
    );
    final received = manager.messages.first;

    final response = peripheral.emitWrite(
      'peer-1',
      BleConstants.controlCharacteristicUuid,
      const MessageCodec().encode(handshake),
    );

    expect(response?.status, 0);
    expect(manager.hasConnectedClient, isFalse);

    peripheral.emitSubscription(
      'peer-1',
      BleConstants.stateNotifyCharacteristicUuid,
      isSubscribed: true,
    );

    expect(await received, handshake);
  });

  test('keeps a pairing attempt alive across a bonding disconnect', () async {
    final phases = <BleSetupPhase>[];
    final phaseSub = manager.setupEvents.listen((event) {
      phases.add(event.phase);
    });

    peripheral.emitConnection('peer-1', isConnected: true);
    peripheral.emitBond('peer-1', BondState.bonding);
    peripheral.emitConnection('peer-1', isConnected: false);
    peripheral.emitBond('peer-1', BondState.bonded);
    peripheral.emitConnection('peer-1', isConnected: true);
    peripheral.emitSubscription(
      'peer-1',
      BleConstants.stateNotifyCharacteristicUuid,
      isSubscribed: true,
    );
    await _flushEvents();

    expect(manager.hasConnectedClient, isTrue);
    expect(
      phases,
      containsAllInOrder(<BleSetupPhase>[
        BleSetupPhase.connecting,
        BleSetupPhase.pairing,
        BleSetupPhase.awaitingReconnect,
        BleSetupPhase.subscribing,
        BleSetupPhase.ready,
      ]),
    );

    await phaseSub.cancel();
  });

  test(
    'ignores a second peer and stale callbacks after cancellation',
    () async {
      final connected = <String>[];
      final connectedSub = manager.clientConnected.listen(connected.add);

      peripheral.emitConnection('peer-1', isConnected: true);
      peripheral.emitConnection('peer-2', isConnected: true);
      peripheral.emitSubscription(
        'peer-2',
        BleConstants.stateNotifyCharacteristicUuid,
        isSubscribed: true,
      );
      peripheral.emitSubscription(
        'peer-1',
        BleConstants.stateNotifyCharacteristicUuid,
        isSubscribed: true,
      );
      await _flushEvents();

      expect(connected, ['peer-1']);

      await manager.stopAdvertising();
      peripheral.emitConnection('peer-1', isConnected: true);
      peripheral.emitSubscription(
        'peer-1',
        BleConstants.stateNotifyCharacteristicUuid,
        isSubscribed: true,
      );
      await _flushEvents();

      expect(manager.hasConnectedClient, isFalse);
      expect(connected, ['peer-1']);

      await connectedSub.cancel();
    },
  );
}

Future<void> _flushEvents() => Future<void>.delayed(Duration.zero);

class _FakePeripheral extends BlePeripheralInterface {
  bool advertising = false;
  WriteRequestCallback? _writeRequest;
  BondStateCallback? _bondStateChange;
  CharacteristicSubscriptionChangeCallback? _subscriptionChange;
  ConnectionStateChangeCallback? _connectionStateChange;

  @override
  Future<void> addService(BleService service, {Duration? timeout}) async {}

  @override
  Future<bool> askBlePermission() async => true;

  @override
  Future<void> clearServices() async {}

  @override
  Future<List<String>> getServices() async => const <String>[];

  @override
  Future<void> initialize() async {}

  @override
  Future<bool?> isAdvertising() async => advertising;

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<void> removeService(String serviceId) async {}

  @override
  void setAdvertisingStatusUpdateCallback(
    AdvertisementStatusUpdateCallback callback,
  ) {}

  @override
  void setBleStateChangeCallback(BleStateCallback callback) {}

  @override
  void setBondStateChangeCallback(BondStateCallback callback) {
    _bondStateChange = callback;
  }

  @override
  void setCharacteristicSubscriptionChangeCallback(
    CharacteristicSubscriptionChangeCallback callback,
  ) {
    _subscriptionChange = callback;
  }

  @override
  void setConnectionStateChangeCallback(
    ConnectionStateChangeCallback callback,
  ) {
    _connectionStateChange = callback;
  }

  @override
  void setMtuChangeCallback(MtuChangeCallback callback) {}

  @override
  void setReadRequestCallback(ReadRequestCallback _) {}

  @override
  void setServiceAddedCallback(ServiceAddedCallback callback) {}

  @override
  void setWriteRequestCallback(WriteRequestCallback callback) {
    _writeRequest = callback;
  }

  @override
  Future<void> startAdvertising({
    required List<String> services,
    String? localName,
    int? timeout,
    ManufacturerData? manufacturerData,
    bool addManufacturerDataInScanResponse = false,
  }) async {
    advertising = true;
  }

  @override
  Future<void> stopAdvertising() async {
    advertising = false;
  }

  @override
  Future<void> updateCharacteristic({
    required String characteristicId,
    required Uint8List value,
    String? deviceId,
  }) async {}

  void emitConnection(String deviceId, {required bool isConnected}) {
    _connectionStateChange?.call(deviceId, isConnected);
  }

  void emitBond(String deviceId, BondState state) {
    _bondStateChange?.call(deviceId, state);
  }

  void emitSubscription(
    String deviceId,
    String characteristicId, {
    required bool isSubscribed,
  }) {
    _subscriptionChange?.call(deviceId, characteristicId, isSubscribed, null);
  }

  WriteRequestResult? emitWrite(
    String deviceId,
    String characteristicId,
    Uint8List value,
  ) {
    return _writeRequest?.call(deviceId, characteristicId, 0, value);
  }
}

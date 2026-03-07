import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:btchess/application/controllers/bluetooth_controller.dart';
import 'package:btchess/application/controllers/game_controller.dart';
import 'package:btchess/application/states/bluetooth_state.dart';
import 'package:btchess/domain/services/chess_service.dart';
import 'package:btchess/infrastructure/bluetooth/bluetooth_service.dart';
import 'package:btchess/infrastructure/bluetooth/connection_manager.dart' as cm;
import 'package:btchess/infrastructure/bluetooth/message_models.dart';
import '../../mocks/mock_bluetooth_service.dart';
import '../../mocks/mock_connection_manager.dart';

void main() {
  late MockBluetoothService mockBluetoothService;
  late MockConnectionManager mockConnectionManager;
  late GameController gameController;
  late BluetoothController controller;
  late StreamController<cm.ConnectionState> connStateController;
  late StreamController<BleMessage> messageController;

  setUp(() {
    mockBluetoothService = MockBluetoothService();
    mockConnectionManager = MockConnectionManager();
    gameController = GameController(chessService: const ChessService());

    connStateController = StreamController<cm.ConnectionState>.broadcast();
    messageController = StreamController<BleMessage>.broadcast();

    // Stub streams so _init() doesn't crash
    when(() => mockConnectionManager.stateStream)
        .thenAnswer((_) => connStateController.stream);
    when(() => mockConnectionManager.messages)
        .thenAnswer((_) => messageController.stream);
    when(() => mockBluetoothService.discoveredDevices)
        .thenAnswer((_) => const Stream<List<BleDeviceInfo>>.empty());
    when(() => mockBluetoothService.isBluetoothOn)
        .thenAnswer((_) async => true);

    controller = BluetoothController(
      bluetoothService: mockBluetoothService,
      connectionManager: mockConnectionManager,
      gameController: gameController,
    );
  });

  tearDown(() {
    controller.dispose();
    gameController.dispose();
    connStateController.close();
    messageController.close();
  });

  group('BluetoothController', () {
    group('initial state', () {
      test('starts with disconnected state', () {
        expect(controller.state.connectionStatus, BleConnectionStatus.disconnected);
        expect(controller.state.isHost, isFalse);
        expect(controller.state.isScanning, isFalse);
        expect(controller.state.scannedDevices, isEmpty);
      });

      test('checks bluetooth adapter on init', () async {
        // Allow microtask from _checkBluetoothAdapter to complete
        await Future.delayed(Duration.zero);
        verify(() => mockBluetoothService.isBluetoothOn).called(1);
      });
    });

    group('scanning', () {
      // Note: startScanning/stopScanning require BlePermissions which is
      // a static class that can't be mocked. These are better tested as
      // integration tests. Here we test the state management logic.

      test('initial scanning state is false', () {
        expect(controller.state.isScanning, isFalse);
      });
    });

    group('connection state changes', () {
      test('connected state updates controller', () async {
        connStateController.add(cm.ConnectionState.connected);
        await Future.delayed(Duration.zero);
        expect(controller.state.connectionStatus, BleConnectionStatus.connected);
      });

      test('disconnected state resets pending move and device', () async {
        connStateController.add(cm.ConnectionState.connected);
        await Future.delayed(Duration.zero);

        connStateController.add(cm.ConnectionState.disconnected);
        await Future.delayed(Duration.zero);

        expect(controller.state.connectionStatus, BleConnectionStatus.disconnected);
        expect(controller.state.hasPendingMove, isFalse);
      });

      test('error state is propagated', () async {
        connStateController.add(cm.ConnectionState.error);
        await Future.delayed(Duration.zero);
        expect(controller.state.connectionStatus, BleConnectionStatus.error);
      });

      test('reconnecting state transitions', () async {
        connStateController.add(cm.ConnectionState.reconnecting);
        await Future.delayed(Duration.zero);
        expect(controller.state.connectionStatus, BleConnectionStatus.reconnecting);
      });
    });

    group('disconnect', () {
      test('disconnect resets state', () async {
        when(() => mockConnectionManager.disconnect()).thenAnswer((_) async {});
        when(() => mockBluetoothService.stopAdvertising()).thenAnswer((_) async {});

        await controller.disconnect();

        expect(controller.state.connectionStatus, BleConnectionStatus.disconnected);
        expect(controller.state.isHost, isFalse);
      });

      test('disconnect tolerates errors', () async {
        when(() => mockConnectionManager.disconnect()).thenThrow(Exception('error'));
        when(() => mockBluetoothService.stopAdvertising()).thenAnswer((_) async {});

        await controller.disconnect();

        // Should not throw, state is reset regardless
        expect(controller.state.connectionStatus, BleConnectionStatus.disconnected);
      });
    });

    group('createLobby', () {
      // createLobby requires BlePermissions (static), tested as integration
      test('initial isHost is false', () {
        expect(controller.state.isHost, isFalse);
      });
    });

    group('stopScanning state', () {
      test('stopScanning is safe when not scanning', () async {
        when(() => mockBluetoothService.stopScanning()).thenAnswer((_) async {});
        // Should not throw even when not currently scanning
        await controller.stopScanning();
        expect(controller.state.isScanning, isFalse);
      });
    });
  });
}


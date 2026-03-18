import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:btchess/application/controllers/bluetooth_controller.dart';
import 'package:btchess/application/controllers/game_controller.dart';
import 'package:btchess/application/states/bluetooth_state.dart';
import 'package:btchess/core/errors/ble_exception.dart';
import 'package:btchess/domain/services/chess_service.dart';
import 'package:btchess/infrastructure/bluetooth/bluetooth_service.dart';
import 'package:btchess/infrastructure/bluetooth/connection_manager.dart' as cm;
import 'package:btchess/infrastructure/bluetooth/message_models.dart';
import '../../mocks/mock_ble_peripheral_manager.dart';
import '../../mocks/mock_bluetooth_service.dart';
import '../../mocks/mock_connection_manager.dart';

void main() {
  late MockBluetoothService mockBluetoothService;
  late MockBlePeripheralManager mockPeripheralManager;
  late MockConnectionManager mockConnectionManager;
  late GameController gameController;
  late BluetoothController controller;
  late StreamController<cm.ConnectionState> connStateController;
  late StreamController<BleMessage> messageController;
  late bool hasPermission;
  late bool requestGranted;
  late bool permanentlyDenied;

  setUp(() {
    mockBluetoothService = MockBluetoothService();
    mockPeripheralManager = MockBlePeripheralManager();
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
    when(() => mockBluetoothService.peripheralManager)
      .thenReturn(mockPeripheralManager);
    when(() => mockPeripheralManager.clientConnected)
      .thenAnswer((_) => const Stream<String>.empty());

    hasPermission = true;
    requestGranted = true;
    permanentlyDenied = false;

    controller = BluetoothController(
      bluetoothService: mockBluetoothService,
      connectionManager: mockConnectionManager,
      gameController: gameController,
      checkPermissions: () async => hasPermission,
      requestPermissions: () async {
        if (requestGranted) {
          hasPermission = true;
        }
        return requestGranted;
      },
      isPermissionPermanentlyDenied: () async => permanentlyDenied,
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
      test('initial scanning state is false', () {
        expect(controller.state.isScanning, isFalse);
      });

      test('startScanning enters scanning state when permission is granted',
          () async {
        when(() => mockBluetoothService.startScanning()).thenAnswer((_) async {});

        await controller.startScanning();

        expect(controller.state.connectionStatus, BleConnectionStatus.scanning);
        expect(controller.state.isScanning, isTrue);
        verify(() => mockBluetoothService.startScanning()).called(1);
      });

      test('startScanning shows settings guidance when permission permanently denied',
          () async {
        hasPermission = false;
        requestGranted = false;
        permanentlyDenied = true;

        await controller.startScanning();

        expect(controller.state.connectionStatus, BleConnectionStatus.error);
        expect(
          controller.state.lastError,
          'Bluetooth permission is permanently denied. Please enable it in Settings.',
        );
      });

      test('startScanning reports bluetooth off when permission request fails and adapter is off',
          () async {
        hasPermission = false;
        requestGranted = false;
        permanentlyDenied = false;
        when(() => mockBluetoothService.isBluetoothOn).thenAnswer((_) async => false);

        await controller.startScanning();

        expect(controller.state.connectionStatus, BleConnectionStatus.error);
        expect(controller.state.lastError, 'Bluetooth is turned off');
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
      test('initial isHost is false', () {
        expect(controller.state.isHost, isFalse);
      });

      test('createLobby rethrows when advertising setup fails', () async {
        when(() => mockBluetoothService.startAdvertising(any()))
            .thenThrow(const BleConnectionException('boom'));

        await expectLater(
          controller.createLobby('test-game'),
          throwsA(isA<BleConnectionException>()),
        );

        expect(controller.state.connectionStatus, BleConnectionStatus.error);
        expect(controller.state.lastError, contains('Failed to create lobby'));
      });

      test('createLobby keeps host state when advertising succeeds', () async {
        when(() => mockBluetoothService.startAdvertising(any()))
            .thenAnswer((_) async {});

        await controller.createLobby('test-game');

        expect(controller.state.isHost, isTrue);
        expect(controller.state.connectionStatus, BleConnectionStatus.disconnected);
        verify(() => mockBluetoothService.startAdvertising('test-game')).called(1);
      });

      test('createLobby shows settings guidance when permission permanently denied',
          () async {
        hasPermission = false;
        requestGranted = false;
        permanentlyDenied = true;

        await controller.createLobby('test-game');

        expect(controller.state.connectionStatus, BleConnectionStatus.error);
        expect(
          controller.state.lastError,
          'Bluetooth permission is permanently denied. Please enable it in Settings.',
        );
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

    group('game start', () {
      test('sendGameStart does nothing if not connected', () async {
        expect(controller.state.isConnected, isFalse);
        await controller.sendGameStart();
        verifyNever(() => mockConnectionManager.sendGameStart());
      });

      test('incoming GAME_START on client sets gameStartReceived', () async {
        // Simulate client side (isHost is false by default)
        connStateController.add(cm.ConnectionState.connected);
        await Future.delayed(Duration.zero);

        // Stub sendAck to succeed
        when(() => mockConnectionManager.sendAck(any()))
            .thenAnswer((_) async {});

        // Simulate receiving a GAME_START message
        messageController.add(const GameStartMessage(messageId: 42));
        await Future.delayed(Duration.zero);

        expect(controller.state.gameStartReceived, isTrue);
      });

      test('gameStartReceived defaults to false', () {
        expect(controller.state.gameStartReceived, isFalse);
      });

      test('clearGameStartReceived resets one-shot start signal', () async {
        connStateController.add(cm.ConnectionState.connected);
        await Future.delayed(Duration.zero);

        when(() => mockConnectionManager.sendAck(any()))
            .thenAnswer((_) async {});

        messageController.add(const GameStartMessage(messageId: 100));
        await Future.delayed(Duration.zero);
        expect(controller.state.gameStartReceived, isTrue);

        controller.clearGameStartReceived();
        expect(controller.state.gameStartReceived, isFalse);
      });
    });
  });
}


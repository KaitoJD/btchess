import 'package:btchess/application/controllers/bluetooth_controller.dart';
import 'package:btchess/application/controllers/game_controller.dart';
import 'package:btchess/application/controllers/lobby_controller.dart';
import 'package:btchess/application/states/bluetooth_state.dart';
import 'package:btchess/application/states/lobby_state.dart';
import 'package:btchess/domain/models/piece.dart';
import 'package:btchess/domain/services/chess_service.dart';
import 'package:btchess/core/utils/user_error_formatter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBluetoothController extends Mock implements BluetoothController {}

class _BleStateNotifier extends StateNotifier<BluetoothState> {
  _BleStateNotifier() : super(BluetoothState.initial());
}

void main() {
  late _MockBluetoothController mockBluetoothController;
  late GameController gameController;
  late _BleStateNotifier bleStateNotifier;
  late LobbyController controller;

  setUp(() {
    UserErrorFormatter.setDebugMode(enabled: false);

    mockBluetoothController = _MockBluetoothController();
    gameController = GameController(chessService: const ChessService());
    bleStateNotifier = _BleStateNotifier();

    when(() => mockBluetoothController.setHostColor(PieceColor.white)).thenReturn(null);
    when(() => mockBluetoothController.setHostColor(PieceColor.black)).thenReturn(null);

    controller = LobbyController(
      bluetoothController: mockBluetoothController,
      gameController: gameController,
      bluetoothStateNotifier: bleStateNotifier,
    );
  });

  tearDown(() {
    controller.dispose();
    gameController.dispose();
    bleStateNotifier.dispose();
  });

  group('LobbyController.createLobby', () {
    test('transitions to waitingForOpponent when createLobby succeeds', () async {
      when(() => mockBluetoothController.createLobby(any()))
          .thenAnswer((_) async {});

      await controller.createLobby(
        gameName: 'test-game',
        playerName: 'host',
        hostColor: PieceColor.black,
      );

      expect(controller.state.status, LobbyStatus.waitingForOpponent);
      expect(controller.state.isHost, isTrue);
      expect(controller.state.lobbyName, 'test-game');
      expect(controller.state.hostPlayerName, 'host');
      expect(controller.state.hostColor, PieceColor.black);
      verify(() => mockBluetoothController.setHostColor(PieceColor.black)).called(1);
      verify(() => mockBluetoothController.createLobby('test-game')).called(1);
    });

    test('host lobby remains waiting on transient disconnected state', () async {
      when(() => mockBluetoothController.createLobby(any()))
          .thenAnswer((_) async {});

      await controller.createLobby(
        gameName: 'test-game',
        playerName: 'host',
      );

      expect(controller.state.status, LobbyStatus.waitingForOpponent);

      bleStateNotifier.state = bleStateNotifier.state.copyWith(
        connectionStatus: BleConnectionStatus.disconnected,
      );

      expect(controller.state.status, LobbyStatus.waitingForOpponent);
      expect(controller.state.lastError, isNull);
    });

    test('transitions to error when createLobby fails', () async {
      when(() => mockBluetoothController.createLobby(any()))
          .thenThrow(Exception('advertising failed'));

      await controller.createLobby(
        gameName: 'test-game',
        playerName: 'host',
      );

      expect(controller.state.status, LobbyStatus.error);
      expect(controller.state.lastError, UserErrorFormatter.genericErrorMessage);
      verify(() => mockBluetoothController.setHostColor(PieceColor.white)).called(1);
      verify(() => mockBluetoothController.createLobby('test-game')).called(1);
    });
  });
}
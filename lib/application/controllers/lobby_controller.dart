import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/game_mode.dart';
import '../../domain/models/piece.dart';
import '../../domain/models/player.dart';
import '../../infrastructure/bluetooth/bluetooth_service.dart';
import '../../core/utils/user_error_formatter.dart';
import '../controllers/bluetooth_controller.dart';
import '../controllers/game_controller.dart';
import '../states/bluetooth_state.dart';
import '../states/lobby_state.dart';

// Manages the lobby lifecycle for BLE multiplayer games
//
// Coordinates with [BluetoothController] for connection state transitions
//  and [GameController] for starting the actual chess game
class LobbyController extends StateNotifier<LobbyState> {
  LobbyController({
    required BluetoothController bluetoothController,
    required GameController gameController,
    required StateNotifier<BluetoothState> bluetoothStateNotifier,
  })  : _bluetoothController = bluetoothController,
        _gameController = gameController,
        super(LobbyState.initial()) {
    // Listen to Bluetooth state changes to drive lobby transitions
    _bleStateSubscription = bluetoothStateNotifier
        .addListener(_onBluetoothStateChanged);
  }

  final BluetoothController _bluetoothController;
  final GameController _gameController;

  Function? _bleStateSubscription;

  // Creates a lobby as host and starts advertising
  //
  // [gameName] is the advertised device name
  // [playerName] is the host player's display name
  // [hostColor] determines which color the host plays
  Future<void> createLobby({
    required String gameName,
    required String playerName,
    PieceColor hostColor = PieceColor.white,
  }) async {
    if (state.isActive) return;

    state = state.copyWith(
      status: LobbyStatus.creating,
      lobbyName: gameName,
      hostPlayerName: playerName,
      isHost: true,
      hostColor: hostColor,
      clearError: true,
    );

    try {
      // Inform BluetoothController of the host's color choice so it's
      // included in the BLE handshake response to the client.
      _bluetoothController.setHostColor(hostColor);

      await _bluetoothController.createLobby(gameName);

      state = state.copyWith(
        status: LobbyStatus.waitingForOpponent,
      );
    } catch (e) {
      state = state.copyWith(
        status: LobbyStatus.error,
        lastError: UserErrorFormatter.formatError(
          e,
          context: 'Failed to create lobby',
        ),
      );
    }
  }

  // Joins a discovered host game
  //
  // [device] is the BLE device info from scanning
  // [playerName] is the client player's display name
  Future<void> joinGame({
    required BleDeviceInfo device,
    required String playerName,
  }) async {
    if (state.isActive) return;

    state = state.copyWith(
      status: LobbyStatus.joining,
      lobbyName: device.name,
      clientPlayerName: playerName,
      isHost: false,
      clearError: true,
    );

    try {
      await _bluetoothController.joinGame(device);
      // Further transitions are driven by _onBluetoothStateChanged
    } catch (e) {
      state = state.copyWith(
        status: LobbyStatus.error,
        lastError: UserErrorFormatter.formatError(
          e,
          context: 'Failed to join game',
        ),
      );
    }
  }

  // Transitions from the lobby to an active game (host only)
  //
  // Sends GAME_START to the client via BLE, then both sides enter the game.
  Future<void> startGame() async {
    if (state.status != LobbyStatus.ready) return;
    if (!state.isHost) return;

    state = state.copyWith(status: LobbyStatus.starting, clearError: true);

    try {
      await _bluetoothController.sendGameStart();
      _transitionToGame();
    } catch (e) {
      state = state.copyWith(
        status: LobbyStatus.ready,
        lastError: UserErrorFormatter.formatError(
          e,
          context: 'Failed to start game',
        ),
      );
    }
  }

  // Creates players and initializes the game via GameController
  void _transitionToGame() {
    final mode = state.isHost ? GameMode.bleHost : GameMode.bleClient;
    final localColor = state.localColor;

    Player whitePlayer;
    Player blackPlayer;

    if (state.isHost) {
      if (state.hostColor == PieceColor.white) {
        whitePlayer = Player.local(name: state.hostPlayerName, color: PieceColor.white, isHost: true);
        blackPlayer = Player.remote(
          id: 'remote_client',
          name: state.clientPlayerName.isNotEmpty ? state.clientPlayerName : 'Opponent',
          color: PieceColor.black,
        );
      } else {
        whitePlayer = Player.remote(
          id: 'remote_client',
          name: state.clientPlayerName.isNotEmpty ? state.clientPlayerName : 'Opponent',
          color: PieceColor.white,
        );
        blackPlayer = Player.local(name: state.hostPlayerName, color: PieceColor.black, isHost: true);
      }
    } else {
      // Client: host color is known, client gets the opposite
      if (state.hostColor == PieceColor.white) {
        whitePlayer = Player.remote(
          id: 'remote_host',
          name: state.hostPlayerName.isNotEmpty ? state.hostPlayerName : 'Host',
          color: PieceColor.white,
        );
        blackPlayer = Player.local(name: state.clientPlayerName, color: PieceColor.black);
      } else {
        whitePlayer = Player.local(name: state.clientPlayerName, color: PieceColor.white);
        blackPlayer = Player.remote(
          id: 'remote_host',
          name: state.hostPlayerName.isNotEmpty ? state.hostPlayerName : 'Host',
          color: PieceColor.black,
        );
      }
    }

    _gameController.newGame(
      mode: mode,
      whitePlayer: whitePlayer,
      blackPlayer: blackPlayer,
      localPlayerColor: localColor,
    );

    state = state.copyWith(status: LobbyStatus.inGame);
  }

  // Changes the host's color assignment
  void setHostColor(PieceColor color) {
    if (state.isInGame) return;
    state = state.copyWith(hostColor: color);
  }

  // Updates the client player name
  void setClientPlayerName(String name) {
    state = state.copyWith(clientPlayerName: name);
  }

  // Updates the host player name
  void setHostPlayerName(String name) {
    state = state.copyWith(hostPlayerName: name);
  }

  /// Cancels the lobby and disconnects
  Future<void> leaveLobby() async {
    await _bluetoothController.disconnect();
    state = LobbyState.initial();
  }

  // Resets the lobby to idle state
  void reset() {
    state = LobbyState.initial();
  }

  void _onBluetoothStateChanged(BluetoothState bleState) {
    if (!mounted) return;

    final newStatus = bleState.connectionStatus;

    // Drive lobby transitions based on connection state changes
    switch (newStatus) {
      case BleConnectionStatus.handshaking:
        // Connection established, handshake in progress
        if (state.status == LobbyStatus.joining || state.status == LobbyStatus.waitingForOpponent) {
          // Keep current status — handshake is part of the joining/waiting phase
        }

      case BleConnectionStatus.connected:
        // Handshake complete — both sides are ready
        if (state.status == LobbyStatus.joining ||
            state.status == LobbyStatus.waitingForOpponent ||
            state.status == LobbyStatus.creating) {
          // Client: pick up the host's color from the BLE handshake
          if (!state.isHost && bleState.hostColor != null) {
            state = state.copyWith(
              status: LobbyStatus.ready,
              hostColor: bleState.hostColor,
            );
          } else {
            state = state.copyWith(status: LobbyStatus.ready);
          }
        }

        // Client: auto-start when host sends GAME_START signal
        if (!state.isHost &&
            bleState.gameStartReceived &&
            state.status == LobbyStatus.ready) {
          _transitionToGame();
          _bluetoothController.clearGameStartReceived();
        }

      case BleConnectionStatus.disconnected:
        // If we were in an active lobby and got disconnected, go to error
        if (state.isActive && state.status != LobbyStatus.inGame) {
          state = state.copyWith(
            status: LobbyStatus.error,
            lastError: 'Connection lost',
          );
        }

      case BleConnectionStatus.error:
        if (state.isActive) {
          state = state.copyWith(
            status: LobbyStatus.error,
            lastError: bleState.lastError ?? 'Connection error',
          );
        }

      case BleConnectionStatus.reconnecting:
        // During reconnection, keep current lobby state — UI should show reconnecting indicator
        break;

      default:
        break;
    }
  }

  @override
  void dispose() {
    _bleStateSubscription?.call();
    super.dispose();
  }
}

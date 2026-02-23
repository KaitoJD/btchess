import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../infrastructure/bluetooth/ble_permissions.dart';
import '../../infrastructure/bluetooth/bluetooth_service.dart';
import '../../infrastructure/bluetooth/connection_manager.dart';
import '../controllers/bluetooth_controller.dart';
import '../controllers/lobby_controller.dart';
import '../states/bluetooth_state.dart';
import '../states/lobby_state.dart';
import 'game_provider.dart';

// Provides the [BluetoothService] singleton for scanning, connecting, and advertising
final bluetoothServiceProvider = Provider<BluetoothService>((ref) {
  final service = BluetoothService();
  ref.onDispose(() => service.dispose());
  return service;
});

// Provides the [ConnectionManager] singleton that manages BLE connection
//  lifecycle, handshake, ping/pong, ACK tracking, and message routing
final connectionManagerProvider = Provider<ConnectionManager>((ref) {
  final manager = ConnectionManager();
  ref.onDispose(() => manager.dispose());
  return manager;
});

// Provides the [BluetoothController] which orchestrates BLE <-> game logic
//
// Depends on [BluetoothService], [ConnectionManager], and [GameController]
final bluetoothControllerProvider =
    StateNotifierProvider<BluetoothController, BluetoothState>((ref) {
  final bluetoothService = ref.watch(bluetoothServiceProvider);
  final connectionManager = ref.watch(connectionManagerProvider);
  final gameController = ref.read(gameControllerProvider.notifier);

  return BluetoothController(
    bluetoothService: bluetoothService,
    connectionManager: connectionManager,
    gameController: gameController,
  );
});

// Provides the [LobbyController] which manages the lobby lifecycle
//
// Depends on [BluetoothController] and [GameController]
final lobbyControllerProvider =
    StateNotifierProvider<LobbyController, LobbyState>((ref) {
  final bluetoothController = ref.read(bluetoothControllerProvider.notifier);
  final gameController = ref.read(gameControllerProvider.notifier);

  // We need the BluetoothController as a StateNotifier<BluetoothState> for listening
  // Use the notifier directly since it extends StateNotifier<BluetoothState>
  return LobbyController(
    bluetoothController: bluetoothController,
    gameController: gameController,
    bluetoothStateNotifier: bluetoothController,
  );
});

// Current Bluetooth connection status
final bleConnectionStatusProvider = Provider<BleConnectionStatus>((ref) {
  return ref.watch(bluetoothControllerProvider).connectionStatus;
});

// Whether Bluetooth is currently connected
final isBleConnectedProvider = Provider<bool>((ref) {
  return ref.watch(bluetoothControllerProvider).isConnected;
});

// Whether currently scanning for devices
final isScanningProvider = Provider<bool>((ref) {
  return ref.watch(bluetoothControllerProvider).isScanning;
});

// List of discovered BLE devices during scanning
final scannedDevicesProvider = Provider<List<BleDeviceInfo>>((ref) {
  return ref.watch(bluetoothControllerProvider).scannedDevices;
});

// The currently connected BLE device info
final connectedDeviceProvider = Provider<BleDeviceInfo?>((ref) {
  return ref.watch(bluetoothControllerProvider).connectedDevice;
});

// Whether this device is the BLE host
final isHostProvider = Provider<bool>((ref) {
  return ref.watch(bluetoothControllerProvider).isHost;
});

// The last BLE error message, if any
final bleErrorProvider = Provider<String?>((ref) {
  return ref.watch(bluetoothControllerProvider).lastError;
});

// Whether a move is currently pending ACK from the host
final hasPendingMoveProvider = Provider<bool>((ref) {
  return ref.watch(bluetoothControllerProvider).hasPendingMove;
});

// Whether BLE is available and turned on
final isBluetoothOnProvider = Provider<bool>((ref) {
  return ref.watch(bluetoothControllerProvider).isBluetoothOn;
});

// Current lobby status
final lobbyStatusProvider = Provider<LobbyStatus>((ref) {
  return ref.watch(lobbyControllerProvider).status;
});

// Whether the lobby is active
final isLobbyActiveProvider = Provider<bool>((ref) {
  return ref.watch(lobbyControllerProvider).isActive;
});

// Whether waiting for an opponent to join
final isWaitingForOpponentProvider = Provider<bool>((ref) {
  return ref.watch(lobbyControllerProvider).isWaitingForOpponent;
});

// Whether both players are ready to start the game
final isLobbyReadyProvider = Provider<bool>((ref) {
  return ref.watch(lobbyControllerProvider).isReady;
});

// Whether a BLE game is currently in progress
final isBleGameInProgressProvider = Provider<bool>((ref) {
  return ref.watch(lobbyControllerProvider).isInGame;
});

// The opponent's name in the lobby
final opponentNameProvider = Provider<String>((ref) {
  return ref.watch(lobbyControllerProvider).opponentName;
});

// The local player's name in the lobby
final localPlayerNameProvider = Provider<String>((ref) {
  return ref.watch(lobbyControllerProvider).localPlayerName;
});

// The lobby name
final lobbyNameProvider = Provider<String>((ref) {
  return ref.watch(lobbyControllerProvider).lobbyName;
});

// Last lobby error, if any
final lobbyErrorProvider = Provider<String?>((ref) {
  return ref.watch(lobbyControllerProvider).lastError;
});

// Checks if BLE permissions are currently granted
final blePermissionsProvider = FutureProvider<bool>((ref) async {
  return BlePermissions.areGranted();
});

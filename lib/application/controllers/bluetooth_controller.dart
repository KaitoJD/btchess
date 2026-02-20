import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/error_codes.dart';
import '../../domain/enums/game_end_reason.dart';
import '../../domain/enums/game_status.dart';
import '../../domain/enums/promotion_piece.dart';
import '../../domain/enums/winner.dart';
import '../../domain/models/game_result.dart';
import '../../domain/models/move.dart';
import '../../domain/models/piece.dart';
import '../../domain/models/square.dart';
import '../../infrastructure/bluetooth/ble_connection.dart';
import '../../infrastructure/bluetooth/ble_permissions.dart';
import '../../infrastructure/bluetooth/bluetooth_service.dart';
import '../../infrastructure/bluetooth/connection_manager.dart' as cm;
import '../../infrastructure/bluetooth/message_models.dart';
import '../controllers/game_controller.dart';
import '../states/bluetooth_state.dart';

// The critical orchestrator connecting BluetoothService + ConnectionManager + GameController
//
// Handles scanning, connecting, lobby creation/joining, message routing between
//  the BLE layer and game logic, and state transitions for the Bluetooth subsystem
class BluetoothController extends StateNotifier<BluetoothState> {
  BluetoothController({
    required BluetoothService bluetoothService,
    required cm.ConnectionManager connectionManager,
    required GameController gameController,
  })  : _bluetoothService = bluetoothService,
        _connectionManager = connectionManager,
        _gameController = gameController,
        super(BluetoothState.initial()) {
    _init();
  }

  final BluetoothService _bluetoothService;
  final cm.ConnectionManager _connectionManager;
  final GameController _gameController;

  StreamSubscription<cm.ConnectionState>? _connectionStateSubscription;
  StreamSubscription<BleMessage>? _messageSubscription;
  StreamSubscription<List<BleDeviceInfo>>? _deviceScanSubscription;

  void _init() {
    // Listen to infrastructure connection state changes
    _connectionStateSubscription = _connectionManager.stateStream.listen(
      _onConnectionStateChanged,
    );

    // Listen to incoming game messages
    _messageSubscription = _connectionManager.messages.listen(
      _onMessageReceived,
    );

    // Listen to scanned BLE devices
    _deviceScanSubscription = _bluetoothService.discoveredDevices.listen(
      _onDevicesDiscovered,
    );

    // Check initial Bluetooth adapter state
    _checkBluetoothAdapter();
  }

  Future<void> _checkBluetoothAdapter() async {
    try {
      final isOn = await _bluetoothService.isBluetoothOn;
      state = state.copyWith(isBluetoothOn: isOn);
    } catch (_) {
      state = state.copyWith(isBluetoothOn: false);
    }
  }

  // Checks if all BLE permissions are granted
  Future<bool> checkPermissions() async {
    return BlePermissions.areGranted();
  }

  // Requests the required BLE permissions from the user
  Future<bool> requestPermissions() async {
    return BlePermissions.request();
  }

  // Starts scanning for nearby BTChess host devices
  Future<void> startScanning() async {
    if (state.isScanning) return;

    try {
      final hasPermission = await checkPermissions();
      if (!hasPermission) {
        final granted = await requestPermissions();
        if (!granted) {
          state = state.copyWith(
            connectionStatus: BleConnectionStatus.error,
            lastError: 'Bluetooth permissions not granted',
          );
          return;
        }
      }

      state = state.copyWith(
        connectionStatus: BleConnectionStatus.scanning,
        isScanning: true,
        scannedDevices: [],
        clearError: true,
      );

      await _bluetoothService.startScanning();
    } catch (e) {
      state = state.copyWith(
        connectionStatus: BleConnectionStatus.error,
        isScanning: false,
        lastError: 'Failed to start scanning: $e',
      );
    }
  }

  // Stops scanning for devices
  Future<void> stopScanning() async {
    try {
      await _bluetoothService.stopScanning();
      state = state.copyWith(isScanning: false);

      // Only reset connection status if we were scanning
      if (state.connectionStatus == BleConnectionStatus.scanning) {
        state = state.copyWith(connectionStatus: BleConnectionStatus.disconnected);
      }
    } catch (e) {
      state = state.copyWith(isScanning: false);
    }
  }

  void _onDevicesDiscovered(List<BleDeviceInfo> devices) {
    if (!mounted) return;
    state = state.copyWith(scannedDevices: devices);
  }

  // Creates a BLE lobby by starting to advertise as a host
  //
  // Note: Actual advertising requires the peripheral implementation from Sprint 3.1
  Future<void> createLobby(String gameName) async {
    try {
      final hasPermission = await checkPermissions();
      if (!hasPermission) {
        final granted = await requestPermissions();
        if (!granted) {
          state = state.copyWith(
            connectionStatus: BleConnectionStatus.error,
            lastError: 'Bluetooth permissions not granted',
          );
          return;
        }
      }

      state = state.copyWith(
        isHost: true,
        clearError: true,
      );

      await _bluetoothService.startAdvertising(gameName);
    } catch (e) {
      state = state.copyWith(
        connectionStatus: BleConnectionStatus.error,
        lastError: 'Failed to create lobby: $e',
      );
    }
  }

  // Stops advertising (host tears down lobby)
  Future<void> stopAdvertising() async {
    try {
      await _bluetoothService.stopAdvertising();
    } catch (_) {
      // Ignore stop errors
    }
  }

  // Connects to a discovered host device and begins the handshake
  Future<void> joinGame(BleDeviceInfo device) async {
    try {
      state = state.copyWith(
        connectionStatus: BleConnectionStatus.connecting,
        connectedDevice: device,
        isHost: false,
        clearError: true,
      );

      await stopScanning();

      final connection = await _bluetoothService.connect(device);
      await _connectionManager.setupConnection(connection);

      // ConnectionManager handles handshake internally and transitions to connected
    } catch (e) {
      state = state.copyWith(
        connectionStatus: BleConnectionStatus.error,
        lastError: 'Failed to join game: $e',
        clearConnectedDevice: true,
      );
    }
  }

  // Called when the host accepts a client connection
  Future<void> acceptClientConnection(BleConnection connection) async {
    try {
      state = state.copyWith(
        connectionStatus: BleConnectionStatus.connecting,
        isHost: true,
        clearError: true,
      );

      await _connectionManager.setupConnection(connection);
    } catch (e) {
      state = state.copyWith(
        connectionStatus: BleConnectionStatus.error,
        lastError: 'Failed to accept client connection: $e',
      );
    }
  }

  // Fully disconnects from the remote device and resets BLE state
  Future<void> disconnect() async {
    try {
      await stopAdvertising();
      await _connectionManager.disconnect();
    } catch (_) {
      // Ignore disconnect errors
    } finally {
      state = BluetoothState.initial();
    }
  }

  // Sends a move over BLE
  //
  // Sets [pendingMoveId] so the UI can show a spinner while waiting for ACK
  // On ACK OK the game state is updated; on ACK ERROR the error is surfaced
  Future<void> sendMove(Move move) async {
    if (!state.isConnected) return;

    final msgId = _connectionManager.getNextPublicMessageId();
    final promoCode = move.promotion?.code ?? 0;

    final moveMsg = MoveMessage(
      messageId: msgId,
      from: move.from.index,
      to: move.to.index,
      promotion: promoCode,
    );

    state = state.copyWith(pendingMoveId: msgId);

    try {
      final ack = await _connectionManager.sendMove(moveMsg);

      if (ack.isSuccess) {
        // Client applies the move locally only after the host confirms
        _gameController.applyRemoteMove(move);
        state = state.copyWith(clearPendingMove: true, clearError: true);
      } else {
        state = state.copyWith(
          clearPendingMove: true,
          lastError: _errorDescription(ack.error),
        );
      }
    } catch (e) {
      state = state.copyWith(
        clearPendingMove: true,
        lastError: 'Move failed: $e',
      );
    }
  }

  // Sends a draw offer to the remote player
  Future<void> sendDrawOffer() async {
    if (!state.isConnected) return;

    try {
      await _connectionManager.sendDrawOffer();
      _gameController.offerDraw(
        state.isHost
            ? (_gameController.state?.whitePlayer.isHost == true
                ? PieceColor.white
                : PieceColor.black)
            : (_gameController.state?.whitePlayer.isLocal == true
                ? PieceColor.white
                : PieceColor.black),
      );
    } catch (e) {
      state = state.copyWith(lastError: 'Draw offer failed: $e');
    }
  }

  // Responds to an incoming draw offer
  Future<void> sendDrawResponse({required bool accepted}) async {
    if (!state.isConnected) return;

    try {
      await _connectionManager.sendDrawResponse(accepted);

      if (accepted) {
        _gameController.acceptDraw();

        // If we are the host, also notify the client that the game has ended
        if (state.isHost) {
          await _connectionManager.sendGameEnd(
            GameEndReason.drawAgreement.code,
            Winner.draw.code,
          );
        }
      } else {
        _gameController.rejectDraw();
      }
    } catch (e) {
      state = state.copyWith(lastError: 'Draw response failed: $e');
    }
  }

  // Sends a resign message
  Future<void> sendResign() async {
    if (!state.isConnected) return;

    try {
      await _connectionManager.sendResign();

      // Determine resigning color
      final localColor = _localPlayerColor();
      _gameController.resign(localColor);

      // Host notifies the game end
      if (state.isHost) {
        final winner = localColor == PieceColor.white ? Winner.black : Winner.white;
        await _connectionManager.sendGameEnd(
          GameEndReason.resign.code,
          winner.code,
        );
      }
    } catch (e) {
      state = state.copyWith(lastError: 'Resign failed: $e');
    }
  }

  // Requests a full state sync from the host
  Future<void> requestSync() async {
    if (!state.isConnected || state.isHost) return;

    try {
      await _connectionManager.sendSyncRequest();
    } catch (e) {
      state = state.copyWith(lastError: 'Sync request failed: $e');
    }
  }

  void _onConnectionStateChanged(cm.ConnectionState connState) {
    if (!mounted) return;

    state = state.copyWith(
      connectionStatus: connState.toBleStatus(),
    );

    if (connState == cm.ConnectionState.disconnected) {
      state = state.copyWith(
        clearPendingMove: true,
        clearConnectedDevice: true,
      );
    }
  }

  void _onMessageReceived(BleMessage message) {
    if (!mounted) return;

    switch (message) {
      case final MoveMessage move:
        _handleIncomingMove(move);
      case final DrawOfferMessage _:
        _handleIncomingDrawOffer(message);
      case final DrawResponseMessage resp:
        _handleIncomingDrawResponse(resp);
      case final ResignMessage _:
        _handleIncomingResign(message);
      case final GameEndMessage gameEnd:
        _handleIncomingGameEnd(gameEnd);
      case final SyncRequestMessage sync:
        _handleIncomingSyncRequest(sync);
      case final SyncResponseMessage sync:
        _handleIncomingSyncResponse(sync);
      case final HandshakeMessage _:
        // Already handled by ConnectionManager
        break;
      default:
        break;
    }
  }

  void _handleIncomingMove(MoveMessage moveMsg) {
    if (!state.isHost) return;

    final gameState = _gameController.state;
    if (gameState == null || gameState.isEnded) {
      _connectionManager.sendAck(moveMsg.messageId, error: BleErrorCode.gameEnded);
      return;
    }

    // Check it's the remote player's turn
    final remoteTurn = _remotePlayerColor();
    if (gameState.currentTurn != remoteTurn) {
      _connectionManager.sendAck(moveMsg.messageId, error: BleErrorCode.notYourTurn);
      return;
    }

    final from = Square.fromIndex(moveMsg.from);
    final to = Square.fromIndex(moveMsg.to);
    final promotion = moveMsg.hasPromotion
        ? PromotionPiece.fromCode(moveMsg.promotion)
        : null;

    final move = Move(from: from, to: to, promotion: promotion);
    final success = _gameController.applyRemoteMove(move);

    if (success) {
      _connectionManager.sendAck(moveMsg.messageId);

      // Check for game end after applying the move
      _checkAndSendGameEnd();
    } else {
      _connectionManager.sendAck(moveMsg.messageId, error: BleErrorCode.invalidMove);
    }
  }

  void _handleIncomingDrawOffer(BleMessage message) {
    final remoteColor = _remotePlayerColor();
    _gameController.offerDraw(remoteColor);
  }

  void _handleIncomingDrawResponse(DrawResponseMessage response) {
    if (response.accepted) {
      _gameController.acceptDraw();

      // Host broadcasts game end
      if (state.isHost) {
        _connectionManager.sendGameEnd(
          GameEndReason.drawAgreement.code,
          Winner.draw.code,
        );
      }
    } else {
      _gameController.rejectDraw();
    }
  }

  void _handleIncomingResign(BleMessage message) {
    final remoteColor = _remotePlayerColor();
    _gameController.resign(remoteColor);

    // Host broadcasts game end
    if (state.isHost) {
      final winner = remoteColor == PieceColor.white ? Winner.black : Winner.white;
      _connectionManager.sendGameEnd(
        GameEndReason.resign.code,
        winner.code,
      );
    }
  }

  void _handleIncomingGameEnd(GameEndMessage gameEnd) {
    // Client receives game end from host
    final reason = GameEndReason.fromCode(gameEnd.reason);
    final winnerCode = Winner.fromCode(gameEnd.winner);

    if (reason == null || winnerCode == null) return;

    final gameState = _gameController.state;
    if (gameState == null) return;

    late final GameResult result;
    switch (reason) {
      case GameEndReason.checkmate:
        result = GameResult.checkmate(winnerCode, finalFen: gameState.fen);
      case GameEndReason.stalemate:
        result = GameResult.stalemate(finalFen: gameState.fen);
      case GameEndReason.resign:
        result = GameResult.resignation(winnerCode, finalFen: gameState.fen);
      case GameEndReason.drawAgreement:
        result = GameResult.drawByAgreement(finalFen: gameState.fen);
      case GameEndReason.fiftyMoveRule:
        result = GameResult.fiftyMoveRule(finalFen: gameState.fen);
      case GameEndReason.threefoldRepetition:
        result = GameResult.threefoldRepetition(finalFen: gameState.fen);
      case GameEndReason.insufficientMaterial:
        result = GameResult.insufficientMaterial(finalFen: gameState.fen);
      case GameEndReason.disconnect:
        result = GameResult.disconnect(winnerCode, finalFen: gameState.fen);
      case GameEndReason.timeout:
        result = GameResult(
          winner: winnerCode,
          reason: GameEndReason.timeout,
          finalFen: gameState.fen,
        );
    }

    _gameController.syncState(
      fen: gameState.fen,
      moves: gameState.moves,
      status: _statusFromReason(reason),
      result: result,
    );
  }

  void _handleIncomingSyncRequest(SyncRequestMessage request) {
    if (!state.isHost) return;

    final gameState = _gameController.state;
    if (gameState == null) return;

    // Build a JSON payload with the full game state
    final syncPayload = jsonEncode({
      'fen': gameState.fen,
      'moves': gameState.moves.map((m) => m.uci).toList(),
      'status': gameState.status.name,
      'currentTurn': gameState.currentTurn.name,
    });

    _connectionManager.sendSyncResponse(syncPayload);
  }

  void _handleIncomingSyncResponse(SyncResponseMessage sync) {
    if (state.isHost) return;

    try {
      final payload = sync.payloadAsString;
      final data = jsonDecode(payload) as Map<String, dynamic>;

      final fen = data['fen'] as String;
      final moveUcis = (data['moves'] as List).cast<String>();
      final statusName = data['status'] as String?;

      final moves = moveUcis.map((uci) {
        final from = Square.fromAlgebraic(uci.substring(0, 2));
        final to = Square.fromAlgebraic(uci.substring(2, 4));
        PromotionPiece? promo;
        if (uci.length > 4) {
          promo = PromotionPiece.fromLetter(uci.substring(4));
        }
        return Move(from: from, to: to, promotion: promo);
      }).toList();

      GameStatus? status;
      if (statusName != null) {
        status = GameStatus.values.where((s) => s.name == statusName).firstOrNull;
      }

      _gameController.syncState(fen: fen, moves: moves, status: status);
    } catch (e) {
      state = state.copyWith(lastError: 'Failed to process sync: $e');
    }
  }

  void _checkAndSendGameEnd() {
    final gameState = _gameController.state;
    if (gameState == null || !gameState.isEnded) return;

    final result = gameState.result;
    if (result == null) return;

    _connectionManager.sendGameEnd(
      result.reason.code,
      result.winner.code,
    );
  }

  PieceColor _localPlayerColor() {
    final gameState = _gameController.state;
    if (gameState == null) return PieceColor.white;

    if (gameState.whitePlayer.isLocal) return PieceColor.white;
    return PieceColor.black;
  }

  PieceColor _remotePlayerColor() => _localPlayerColor().opposite;

  String _errorDescription(BleErrorCode error) {
    switch (error) {
      case BleErrorCode.invalidMove:
        return 'Invalid move';
      case BleErrorCode.notYourTurn:
        return 'Not your turn';
      case BleErrorCode.gameEnded:
        return 'Game has ended';
      case BleErrorCode.syncRequired:
        return 'Sync required';
      case BleErrorCode.rateLimited:
        return 'Too many requests, please wait';
      case BleErrorCode.duplicateMessage:
        return 'Duplicate message';
      case BleErrorCode.versionMismatch:
        return 'Protocol version mismatch';
      case BleErrorCode.sessionExpired:
        return 'Session expired';
      default:
        return 'An error occurred (0x${error.value.toRadixString(16)})';
    }
  }

  GameStatus _statusFromReason(GameEndReason reason) {
    switch (reason) {
      case GameEndReason.checkmate:
        return GameStatus.checkmate;
      case GameEndReason.stalemate:
        return GameStatus.stalemate;
      case GameEndReason.resign:
        return GameStatus.resigned;
      default:
        return GameStatus.draw;
    }
  }

  @override
  void dispose() {
    _connectionStateSubscription?.cancel();
    _messageSubscription?.cancel();
    _deviceScanSubscription?.cancel();
    _connectionManager.dispose();
    _bluetoothService.dispose();
    super.dispose();
  }
}
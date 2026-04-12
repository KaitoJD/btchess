import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/error_codes.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/user_error_formatter.dart';
import '../../domain/enums/game_end_reason.dart';
import '../../domain/enums/game_status.dart';
import '../../domain/enums/promotion_piece.dart';
import '../../domain/enums/winner.dart';
import '../../domain/models/game_result.dart';
import '../../domain/models/move.dart';
import '../../domain/models/piece.dart';
import '../../domain/models/square.dart';
import '../../infrastructure/bluetooth/ble_connection.dart';
import '../../infrastructure/bluetooth/ble_host_transport.dart';
import '../../infrastructure/bluetooth/ble_permissions.dart';
import '../../infrastructure/bluetooth/bluetooth_service.dart';
import '../../infrastructure/bluetooth/connection_manager.dart' as cm;
import '../../infrastructure/bluetooth/message_models.dart';
import '../controllers/game_controller.dart';
import '../states/bluetooth_state.dart';

typedef PermissionCheckFn = Future<bool> Function();

// The critical orchestrator connecting BluetoothService + ConnectionManager + GameController
//
// Handles scanning, connecting, lobby creation/joining, message routing between
//  the BLE layer and game logic, and state transitions for the Bluetooth subsystem
class BluetoothController extends StateNotifier<BluetoothState> {
  BluetoothController({
    required BluetoothService bluetoothService,
    required cm.ConnectionManager connectionManager,
    required GameController gameController,
    PermissionCheckFn? checkPermissions,
    PermissionCheckFn? requestPermissions,
    PermissionCheckFn? isPermissionPermanentlyDenied,
  })  : _bluetoothService = bluetoothService,
        _connectionManager = connectionManager,
        _gameController = gameController,
        _checkPermissions = checkPermissions ?? BlePermissions.areGranted,
        _requestPermissions = requestPermissions ?? BlePermissions.request,
        _isPermissionPermanentlyDenied =
            isPermissionPermanentlyDenied ?? BlePermissions.isPermanentlyDenied,
        super(BluetoothState.initial()) {
    _init();
  }

  final BluetoothService _bluetoothService;
  final cm.ConnectionManager _connectionManager;
  final GameController _gameController;
  final PermissionCheckFn _checkPermissions;
  final PermissionCheckFn _requestPermissions;
  final PermissionCheckFn _isPermissionPermanentlyDenied;

  // Host color code for BLE protocol: 0x01 = white, 0x02 = black
  int _hostColorCode = 0x00;

  StreamSubscription<cm.ConnectionState>? _connectionStateSubscription;
  StreamSubscription<BleMessage>? _messageSubscription;
  StreamSubscription<List<BleDeviceInfo>>? _deviceScanSubscription;
  StreamSubscription<String>? _clientConnectedSubscription;

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
    return _checkPermissions();
  }

  // Requests the required BLE permissions from the user
  Future<bool> requestPermissions() async {
    return _requestPermissions();
  }

  // Starts scanning for nearby BTChess host devices
  Future<void> startScanning() async {
    if (state.isScanning) return;

    try {
      final hasPermission = await checkPermissions();
      if (!hasPermission) {
        final granted = await requestPermissions();
        if (!granted) {
          await _setPermissionDeniedErrorState();
          return;
        }
      }

      final isOn = await _bluetoothService.isBluetoothOn;
      if (!isOn) {
        state = state.copyWith(
          connectionStatus: BleConnectionStatus.error,
          isScanning: false,
          lastError: UserErrorFormatter.formatMessage('Bluetooth is turned off'),
        );
        return;
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
        lastError: UserErrorFormatter.formatError(
          e,
          context: 'Failed to start scanning',
        ),
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

  // Sets the host color code for BLE handshake
  //
  // [color] is the host's chosen piece color.
  // Must be called before [createLobby].
  void setHostColor(PieceColor color) {
    _hostColorCode = color == PieceColor.black ? 0x02 : 0x01;
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
          await _setPermissionDeniedErrorState();
          return;
        }
      }

      state = state.copyWith(
        isHost: true,
        connectionStatus: BleConnectionStatus.connecting,
        clearError: true,
      );

      // Set host color on ConnectionManager so it's included in handshake
      _connectionManager.setHostColor(_hostColorCode);

      // Listen for client connections from the peripheral manager
      _clientConnectedSubscription?.cancel();
      _clientConnectedSubscription = _bluetoothService.peripheralManager
          .clientConnected
          .listen(_onHostClientConnected);

      await _bluetoothService.startAdvertising(gameName);

      // Advertising is active and waiting for peer connection callbacks.
      state = state.copyWith(
        connectionStatus: BleConnectionStatus.disconnected,
      );
    } catch (e) {
      await _clientConnectedSubscription?.cancel();
      _clientConnectedSubscription = null;
      try {
        await _bluetoothService.stopAdvertising();
      } catch (_) {}

      state = state.copyWith(
        connectionStatus: BleConnectionStatus.error,
        lastError: UserErrorFormatter.formatError(
          e,
          context: 'Failed to create lobby',
        ),
      );
      rethrow;
    }
  }

  // Stops advertising (host tears down lobby)
  Future<void> stopAdvertising() async {
    try {
      _clientConnectedSubscription?.cancel();
      _clientConnectedSubscription = null;
      await _bluetoothService.stopAdvertising();
    } catch (_) {
      // Ignore stop errors
    }
  }

  Future<void> _setPermissionDeniedErrorState() async {
    final message = await _resolvePermissionErrorMessage();
    state = state.copyWith(
      connectionStatus: BleConnectionStatus.error,
      lastError: UserErrorFormatter.formatMessage(message),
    );
  }

  Future<String> _resolvePermissionErrorMessage() async {
    try {
      final permanentlyDenied = await _isPermissionPermanentlyDenied();
      if (permanentlyDenied) {
        return 'Bluetooth permission is permanently denied. Please enable it in Settings.';
      }
    } catch (e) {
      Logger.warn('Failed to check permanent permission denial state: $e', tag: 'BluetoothController');
    }

    try {
      final isOn = await _bluetoothService.isBluetoothOn;
      if (!isOn) {
        return 'Bluetooth is turned off';
      }
    } catch (_) {
      // Keep generic message on adapter state check failure.
    }

    return 'Bluetooth permissions not granted';
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

      // Read host color from handshake and propagate to state
      final hostColorCode = _connectionManager.receivedHostColor;
      final hostColor = hostColorCode == 0x02 ? PieceColor.black : PieceColor.white;
      state = state.copyWith(hostColor: hostColor);
    } catch (e) {
      // Clean up transport/connection on failure
      try {
        await _connectionManager.disconnect();
      } catch (_) {}

      state = state.copyWith(
        connectionStatus: BleConnectionStatus.error,
        lastError: UserErrorFormatter.formatError(
          e,
          context: 'Failed to join game',
        ),
        clearConnectedDevice: true,
      );
    }
  }

  // Called when a client connects to this host's peripheral
  Future<void> _onHostClientConnected(String deviceId) async {
    if (!mounted) return;

    state = state.copyWith(
      connectionStatus: BleConnectionStatus.connecting,
      clearError: true,
    );

    try {
      final transport = BleHostTransport(_bluetoothService.peripheralManager);
      await _connectionManager.setupConnection(transport);
    } catch (e) {
      state = state.copyWith(
        connectionStatus: BleConnectionStatus.error,
        lastError: UserErrorFormatter.formatError(
          e,
          context: 'Client connection failed',
        ),
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
        lastError: UserErrorFormatter.formatError(
          e,
          context: 'Failed to accept client connection',
        ),
      );
    }
  }

  // Fully disconnects from the remote device and resets BLE state
  Future<void> disconnect({bool preserveRematchDeclined = false}) async {
    final keepRematchDeclined = preserveRematchDeclined && state.rematchDeclined;

    try {
      await stopAdvertising();
      await _connectionManager.disconnect();
    } catch (_) {
      // Ignore disconnect errors
    } finally {
      state = BluetoothState.initial().copyWith(
        rematchDeclined: keepRematchDeclined,
      );
    }
  }

  // Sends a move over BLE
  //
  // Host: applies the move locally (authoritative) and notifies the client.
  // Client: sends MOVE to the host, waits for ACK, then applies on success.
  Future<void> sendMove(Move move) async {
    if (!state.isConnected) return;

    if (state.isHost) {
      final gameState = _gameController.state;
      if (gameState == null) {
        Logger.warn(
          'Host attempted move before game initialization: from=${move.from.index}, to=${move.to.index}',
          tag: 'BluetoothController',
        );
        state = state.copyWith(
          lastError: UserErrorFormatter.formatMessage('Game not ready yet'),
        );
        return;
      }

      final localColor = _localPlayerColor();
      Logger.debug(
        'Host sendMove: from=${move.from.index}, to=${move.to.index}, promotion=${move.promotion?.code ?? 0}, '
        'currentTurn=${gameState.currentTurn.name}, localColor=${localColor.name}',
        tag: 'BluetoothController',
      );

      // Host is authoritative – apply locally, then notify client
      if (!_gameController.isLocalPlayerTurn()) {
        state = state.copyWith(
          lastError: UserErrorFormatter.formatMessage('Not your turn'),
        );
        return;
      }

      final success = _gameController.makeMove(
        from: move.from,
        to: move.to,
        promotion: move.promotion,
      );

      if (!success) {
        state = state.copyWith(
          lastError: UserErrorFormatter.formatMessage('Invalid move'),
        );
        return;
      }

      // Notify client of the move (fire-and-forget)
      try {
        final msgId = _connectionManager.getNextPublicMessageId();
        final moveMsg = MoveMessage(
          messageId: msgId,
          from: move.from.index,
          to: move.to.index,
          promotion: move.promotion?.code ?? 0,
        );
        await _connectionManager.sendMoveNotification(moveMsg);
      } catch (e) {
        // Notification failure is non-fatal; client can resync
        Logger.error('Failed to notify client of move: $e',
            tag: 'BluetoothController');
      }

      _checkAndSendGameEnd();
    } else {
      // Client sends MOVE and waits for host ACK
      final msgId = _connectionManager.getNextPublicMessageId();
      final promoCode = move.promotion?.code ?? 0;

      final moveMsg = MoveMessage(
        messageId: msgId,
        from: move.from.index,
        to: move.to.index,
        promotion: promoCode,
      );

      state = state.copyWith(pendingMoveId: msgId, clearError: true);

      try {
        final ack = await _connectionManager.sendMove(moveMsg);

        if (ack.isSuccess) {
          // Client applies the move locally only after the host confirms
          _gameController.applyRemoteMove(move);
          state = state.copyWith(clearPendingMove: true, clearError: true);
        } else {
          state = state.copyWith(
            clearPendingMove: true,
            lastError: UserErrorFormatter.formatMessage(
              _errorDescription(ack.error),
            ),
          );
        }
      } catch (e) {
        state = state.copyWith(
          clearPendingMove: true,
          lastError: UserErrorFormatter.formatError(
            e,
            context: 'Move failed',
          ),
        );
      }
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
      state = state.copyWith(
        lastError: UserErrorFormatter.formatError(
          e,
          context: 'Draw offer failed',
        ),
      );
    }
  }

  // Responds to an incoming draw offer
  Future<void> sendDrawResponse({required bool accepted}) async {
    if (!state.isConnected) return;

    try {
      await _connectionManager.sendDrawResponse(accepted: accepted);

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
      state = state.copyWith(
        lastError: UserErrorFormatter.formatError(
          e,
          context: 'Draw response failed',
        ),
      );
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
      state = state.copyWith(
        lastError: UserErrorFormatter.formatError(
          e,
          context: 'Resign failed',
        ),
      );
    }
  }

  // Sends a game start signal to the client (host only, with ACK+retry)
  Future<void> sendGameStart() async {
    if (!state.isConnected || !state.isHost) return;

    final ack = await _connectionManager.sendGameStart();
    if (!ack.isSuccess) {
      throw Exception('Game start rejected by client');
    }
  }

  // Sends a rematch request to the opponent.
  Future<void> sendRematchRequest() async {
    if (!state.isConnected || state.rematchRequestedByLocal) return;

    state = state.copyWith(
      rematchRequestedByLocal: true,
      rematchDeclined: false,
      clearError: true,
    );

    try {
      await _connectionManager.sendRematchRequest();
    } catch (e) {
      state = state.copyWith(
        rematchRequestedByLocal: false,
        lastError: UserErrorFormatter.formatError(
          e,
          context: 'Rematch request failed',
        ),
      );
    }
  }

  // Responds to an incoming rematch request.
  Future<void> sendRematchResponse({required bool accepted}) async {
    if (accepted) {
      if (state.isConnected) {
        try {
          await _connectionManager.sendRematchResponse(accepted: true);
        } catch (e) {
          state = state.copyWith(
            lastError: UserErrorFormatter.formatError(
              e,
              context: 'Rematch response failed',
            ),
          );
        }
      }

      _startRematch();
      return;
    }

    if (!state.isConnected) {
      state = state.copyWith(
        incomingRematchRequest: false,
        rematchRequestedByLocal: false,
        rematchDeclined: true,
      );
      return;
    }

    try {
      await _connectionManager.sendRematchResponse(accepted: false);
      state = state.copyWith(
        incomingRematchRequest: false,
        rematchRequestedByLocal: false,
        rematchDeclined: true,
      );
      await disconnect(preserveRematchDeclined: true);
    } catch (e) {
      state = state.copyWith(
        lastError: UserErrorFormatter.formatError(
          e,
          context: 'Rematch response failed',
        ),
      );
    }
  }

  // Requests a full state sync from the host
  Future<void> requestSync() async {
    if (!state.isConnected || state.isHost) return;

    try {
      await _connectionManager.sendSyncRequest();
    } catch (e) {
      state = state.copyWith(
        lastError: UserErrorFormatter.formatError(
          e,
          context: 'Sync request failed',
        ),
      );
    }
  }

  void _onConnectionStateChanged(cm.ConnectionState connState) {
    if (!mounted) return;

    final previousStatus = state.connectionStatus;
    final newStatus = connState.toBleStatus();

    state = state.copyWith(
      connectionStatus: newStatus,
      lastError: connState == cm.ConnectionState.error
          ? _connectionManager.lastError
          : null,
    );

    if (connState == cm.ConnectionState.disconnected) {
      state = state.copyWith(
        clearPendingMove: true,
        clearConnectedDevice: true,
        clearRematchState: !state.rematchDeclined,
      );
    }

    // Auto-sync after successful reconnection (client only)
    if (previousStatus == BleConnectionStatus.reconnecting &&
        newStatus == BleConnectionStatus.connected &&
        !state.isHost) {
      Future.microtask(() => requestSync());
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
      case final GameStartMessage gameStart:
        _handleIncomingGameStart(gameStart);
      case final RematchRequestMessage request:
        unawaited(_handleIncomingRematchRequest(request));
      case final RematchResponseMessage response:
        unawaited(_handleIncomingRematchResponse(response));
      case final HandshakeMessage _:
        // Already handled by ConnectionManager
        break;
      default:
        break;
    }
  }

  void _handleIncomingGameStart(GameStartMessage message) {
    // Only the client should process GAME_START
    if (state.isHost) return;

    // Send ACK back to host (best-effort)
    try {
      _connectionManager.sendAck(message.messageId);
    } catch (_) {
      // ACK failure is non-fatal; host will retry GAME_START if needed
    }

    state = state.copyWith(gameStartReceived: true);
  }

  // Clears the one-shot GAME_START signal after the client transitions to game.
  void clearGameStartReceived() {
    if (!state.gameStartReceived) return;
    state = state.copyWith(gameStartReceived: false);
  }

  // Clears rematch UI flags after leaving a completed rematch flow.
  void clearRematchUiState() {
    if (!state.rematchRequestedByLocal &&
        !state.incomingRematchRequest &&
        !state.rematchDeclined) {
      return;
    }

    state = state.copyWith(clearRematchState: true);
  }

  Future<void> _handleIncomingMove(MoveMessage moveMsg) async {
    if (state.isHost) {
      // Host receives a MOVE from the client → validate, apply, ACK
      final gameState = _gameController.state;
      if (gameState == null || gameState.isEnded) {
        await _connectionManager.sendAck(moveMsg.messageId, error: BleErrorCode.gameEnded);
        return;
      }

      // Check it's the remote player's turn
      final remoteTurn = _remotePlayerColor();
      Logger.debug(
        'Incoming move: msgId=${moveMsg.messageId}, from=${moveMsg.from}, to=${moveMsg.to}, promotion=${moveMsg.promotion}, '
        'currentTurn=${gameState.currentTurn.name}, remoteTurn=${remoteTurn.name}',
        tag: 'BluetoothController',
      );

      if (gameState.currentTurn != remoteTurn) {
        await _connectionManager.sendAck(moveMsg.messageId, error: BleErrorCode.notYourTurn);
        return;
      }

      final from = Square.fromIndex(moveMsg.from);
      final to = Square.fromIndex(moveMsg.to);
      final promotion = moveMsg.hasPromotion
          ? PromotionPiece.fromCode(moveMsg.promotion)
          : null;

      if (moveMsg.hasPromotion && promotion == null) {
        Logger.warn(
          'Rejecting malformed promotion code from client: msgId=${moveMsg.messageId}, promotion=${moveMsg.promotion}',
          tag: 'BluetoothController',
        );
        await _connectionManager.sendAck(
          moveMsg.messageId,
          error: BleErrorCode.malformedMessage,
        );
        return;
      }

      final move = Move(from: from, to: to, promotion: promotion);
      final success = _gameController.applyRemoteMove(move);

      if (success) {
        await _connectionManager.sendAck(moveMsg.messageId);

        // Check for game end after applying the move
        _checkAndSendGameEnd();
      } else {
        await _connectionManager.sendAck(moveMsg.messageId, error: BleErrorCode.invalidMove);
      }
    } else {
      // Client receives a MOVE notification from the host → apply directly
      final from = Square.fromIndex(moveMsg.from);
      final to = Square.fromIndex(moveMsg.to);
      final promotion = moveMsg.hasPromotion
          ? PromotionPiece.fromCode(moveMsg.promotion)
          : null;

      if (moveMsg.hasPromotion && promotion == null) {
        Logger.warn(
          'Ignoring malformed promotion code from host: msgId=${moveMsg.messageId}, promotion=${moveMsg.promotion}',
          tag: 'BluetoothController',
        );
        state = state.copyWith(
          lastError: UserErrorFormatter.formatMessage('Received malformed move from host; requesting sync'),
        );
        unawaited(requestSync());
        return;
      }

      final move = Move(from: from, to: to, promotion: promotion);
      _gameController.applyRemoteMove(move);
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

  Future<void> _handleIncomingRematchRequest(RematchRequestMessage _) async {
    // Simultaneous rematch requests should immediately start on both devices.
    if (state.rematchRequestedByLocal) {
      try {
        await _connectionManager.sendRematchResponse(accepted: true);
      } catch (e) {
        state = state.copyWith(
          lastError: UserErrorFormatter.formatError(
            e,
            context: 'Rematch response failed',
          ),
        );
      }

      _startRematch();
      return;
    }

    state = state.copyWith(
      incomingRematchRequest: true,
      rematchDeclined: false,
    );
  }

  Future<void> _handleIncomingRematchResponse(RematchResponseMessage response) async {
    if (!state.rematchRequestedByLocal) return;

    if (response.accepted) {
      _startRematch();
      return;
    }

    state = state.copyWith(
      rematchRequestedByLocal: false,
      incomingRematchRequest: false,
      rematchDeclined: true,
    );

    await disconnect(preserveRematchDeclined: true);
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
      state = state.copyWith(
        lastError: UserErrorFormatter.formatError(
          e,
          context: 'Failed to process sync',
        ),
      );
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

  void _startRematch() {
    _gameController.resetGame(swapPlayerColors: true);
    state = state.copyWith(
      clearRematchState: true,
      rematchStartSignal: state.rematchStartSignal + 1,
      clearError: true,
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
        return UserErrorFormatter.formatMessage(
          'An error occurred (0x${error.value.toRadixString(16)})',
        );
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
    _clientConnectedSubscription?.cancel();
    _connectionManager.dispose();
    _bluetoothService.dispose();
    super.dispose();
  }
}
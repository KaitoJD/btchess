import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/chess_piece.dart';
import '../models/position.dart';
import '../models/move.dart';
import '../services/chess_game.dart';
import '../services/platform_bluetooth_service.dart';

enum GameState {
  menu,
  connecting,
  waitingForPlayer,
  playing,
  gameOver,
}

enum PlayerRole {
  host,
  guest,
  none,
}

enum GameMessageType {
  ping,
  pong,
  gameStart,
  move,
  gameEnd,
  resign,
  draw,
}

class GameMessage {
  final GameMessageType type;
  final Map<String, dynamic> data;

  GameMessage({required this.type, required this.data});

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'data': data,
  };

  static GameMessage fromJson(Map<String, dynamic> json) {
    return GameMessage(
      type: GameMessageType.values.firstWhere((e) => e.name == json['type']),
      data: json['data'] ?? {},
    );
  }

  @override
  String toString() => jsonEncode(toJson());

  static GameMessage? fromString(String message) {
    try {
      final json = jsonDecode(message);
      return fromJson(json);
    } catch (e) {
      debugPrint('Failed to parse message: $e');
      return null;
    }
  }
}

class GameProvider extends ChangeNotifier {
  final ChessBoard _chessBoard = ChessBoard();
  final PlatformBluetoothService _bluetoothService = PlatformBluetoothService();
  
  GameState _gameState = GameState.menu;
  PlayerRole _playerRole = PlayerRole.none;
  PieceColor? _playerColor;
  Position? _selectedPosition;
  List<Position> _validMoves = [];
  String? _gameOverMessage;
  bool _isMyTurn = false;

  StreamSubscription<String>? _messageSubscription;
  StreamSubscription<BluetoothDeviceInfo>? _deviceSubscription;

  // Getters
  ChessBoard get chessBoard => _chessBoard;
  PlatformBluetoothService get bluetoothService => _bluetoothService;
  GameState get gameState => _gameState;
  PlayerRole get playerRole => _playerRole;
  PieceColor? get playerColor => _playerColor;
  Position? get selectedPosition => _selectedPosition;
  List<Position> get validMoves => _validMoves;
  String? get gameOverMessage => _gameOverMessage;
  bool get isMyTurn => _isMyTurn;
  bool get canMakeMove => _gameState == GameState.playing && _isMyTurn;

  // Available devices stream
  Stream<BluetoothDeviceInfo> get deviceStream => _bluetoothService.deviceStream;

  GameProvider() {
    _setupBluetoothListeners();
  }

  void _setupBluetoothListeners() {
    _messageSubscription = _bluetoothService.messageStream.listen(_handleBluetoothMessage);
  }

  void _handleBluetoothMessage(String messageString) {
    final message = GameMessage.fromString(messageString);
    if (message == null) return;

    switch (message.type) {
      case GameMessageType.ping:
        _sendMessage(GameMessage(type: GameMessageType.pong, data: {}));
        break;
      case GameMessageType.pong:
        // Connection confirmed
        break;
      case GameMessageType.gameStart:
        _handleGameStart(message.data);
        break;
      case GameMessageType.move:
        _handleOpponentMove(message.data);
        break;
      case GameMessageType.gameEnd:
        _handleGameEnd(message.data);
        break;
      case GameMessageType.resign:
        _handleResignation();
        break;
      case GameMessageType.draw:
        _handleDrawOffer();
        break;
    }
  }

  void _handleGameStart(Map<String, dynamic> data) {
    if (_gameState == GameState.waitingForPlayer) {
      _gameState = GameState.playing;
      
      // Set player colors based on role
      if (_playerRole == PlayerRole.host) {
        _playerColor = PieceColor.white;
        _isMyTurn = true;
      } else {
        _playerColor = PieceColor.black;
        _isMyTurn = false;
      }
      
      notifyListeners();
    }
  }

  void _handleOpponentMove(Map<String, dynamic> data) {
    try {
      final move = Move.fromJson(data);
      if (_chessBoard.isValidMove(move)) {
        _chessBoard.makeMove(move);
        _isMyTurn = true;
        _clearSelection();
        _checkGameEnd();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to handle opponent move: $e');
    }
  }

  void _handleGameEnd(Map<String, dynamic> data) {
    _gameState = GameState.gameOver;
    _gameOverMessage = data['message'] ?? 'Game ended';
    notifyListeners();
  }

  void _handleResignation() {
    _gameState = GameState.gameOver;
    _gameOverMessage = 'Opponent resigned';
    notifyListeners();
  }

  void _handleDrawOffer() {
    // In a real implementation, you might show a dialog to accept/decline
    _gameState = GameState.gameOver;
    _gameOverMessage = 'Draw offered';
    notifyListeners();
  }

  void _sendMessage(GameMessage message) {
    _bluetoothService.sendMessage(message.toString());
  }

  // Initialize Bluetooth
  Future<bool> initializeBluetooth() async {
    return await _bluetoothService.initialize();
  }

  // Start scanning for devices
  Future<void> scanForDevices() async {
    await _bluetoothService.startScanning();
  }

  // Host a game
  Future<void> hostGame() async {
    _playerRole = PlayerRole.host;
    _playerColor = PieceColor.white;
    _gameState = GameState.waitingForPlayer;
    _resetBoard();
    
    // Start advertising/server mode
    await _bluetoothService.startAdvertising();
    
    notifyListeners();
  }

  // Connect to a device as guest
  Future<bool> connectAsGuest(BluetoothDeviceInfo device) async {
    _gameState = GameState.connecting;
    notifyListeners();

    final connected = await _bluetoothService.connectToDevice(device);
    
    if (connected) {
      _playerRole = PlayerRole.guest;
      _playerColor = PieceColor.black;
      _gameState = GameState.waitingForPlayer;
      _resetBoard();
      
      // Send ping to establish connection
      _sendMessage(GameMessage(type: GameMessageType.ping, data: {}));
      
      notifyListeners();
      return true;
    } else {
      _gameState = GameState.menu;
      notifyListeners();
      return false;
    }
  }

  void _resetBoard() {
    // Reset chess board by creating a new instance
    _chessBoard.fromJson(ChessBoard().toJson());
  }

  // Start the game (called by host when guest connects)
  void startGame() {
    if (_playerRole == PlayerRole.host && _gameState == GameState.waitingForPlayer) {
      _gameState = GameState.playing;
      _isMyTurn = true;
      
      _sendMessage(GameMessage(
        type: GameMessageType.gameStart,
        data: {
          'hostColor': PieceColor.white.index,
          'guestColor': PieceColor.black.index,
        },
      ));
      
      notifyListeners();
    }
  }

  // Handle square selection
  void selectSquare(Position position) {
    if (!canMakeMove) return;

    final piece = _chessBoard.getPieceAt(position);
    
    if (_selectedPosition == null) {
      // First selection - select piece if it belongs to player
      if (piece != null && piece.color == _playerColor) {
        _selectedPosition = position;
        _validMoves = _chessBoard.getValidMovesForPiece(position);
        notifyListeners();
      }
    } else {
      // Second selection - either move or reselect
      if (position == _selectedPosition) {
        // Deselect
        _clearSelection();
      } else if (piece != null && piece.color == _playerColor) {
        // Select different piece
        _selectedPosition = position;
        _validMoves = _chessBoard.getValidMovesForPiece(position);
        notifyListeners();
      } else if (_validMoves.contains(position)) {
        // Make move
        _makeMove(Move(
          from: _selectedPosition!,
          to: position,
        ));
      } else {
        // Invalid selection
        _clearSelection();
      }
    }
  }

  void _makeMove(Move move) {
    if (_chessBoard.isValidMove(move)) {
      _chessBoard.makeMove(move);
      _isMyTurn = false;
      _clearSelection();
      
      // Send move to opponent
      _sendMessage(GameMessage(
        type: GameMessageType.move,
        data: move.toJson(),
      ));
      
      _checkGameEnd();
      notifyListeners();
    }
  }

  void _clearSelection() {
    _selectedPosition = null;
    _validMoves.clear();
    notifyListeners();
  }

  void _checkGameEnd() {
    if (_chessBoard.isCheckmate(_chessBoard.currentPlayer)) {
      final winner = _chessBoard.currentPlayer == PieceColor.white 
          ? PieceColor.black 
          : PieceColor.white;
      
      _gameState = GameState.gameOver;
      _gameOverMessage = winner == _playerColor 
          ? 'You won by checkmate!' 
          : 'You lost by checkmate!';
      
      _sendMessage(GameMessage(
        type: GameMessageType.gameEnd,
        data: {'message': _gameOverMessage!},
      ));
    } else if (_chessBoard.isStalemate(_chessBoard.currentPlayer)) {
      _gameState = GameState.gameOver;
      _gameOverMessage = 'Game ended in stalemate';
      
      _sendMessage(GameMessage(
        type: GameMessageType.gameEnd,
        data: {'message': _gameOverMessage!},
      ));
    }
  }

  // Game actions
  void resign() {
    if (_gameState == GameState.playing) {
      _gameState = GameState.gameOver;
      _gameOverMessage = 'You resigned';
      _sendMessage(GameMessage(type: GameMessageType.resign, data: {}));
      notifyListeners();
    }
  }

  void offerDraw() {
    if (_gameState == GameState.playing) {
      _sendMessage(GameMessage(type: GameMessageType.draw, data: {}));
    }
  }

  // Return to menu
  void returnToMenu() {
    _bluetoothService.disconnect();
    _gameState = GameState.menu;
    _playerRole = PlayerRole.none;
    _playerColor = null;
    _clearSelection();
    _gameOverMessage = null;
    _isMyTurn = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _deviceSubscription?.cancel();
    _bluetoothService.dispose();
    super.dispose();
  }
}

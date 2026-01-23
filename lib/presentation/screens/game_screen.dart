import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/board_provider.dart';
import '../../application/providers/game_provider.dart';
import '../../application/providers/settings_provider.dart';
import '../../domain/enums/promotion_piece.dart';
import '../../domain/models/game_mode.dart';
import '../../domain/models/piece.dart';
import '../../domain/models/square.dart';
import '../themes/board_themes.dart';
import '../widgets/board/board_widget.dart';
import '../widgets/dialogs/exit_game_dialog.dart';
import '../widgets/dialogs/promotion_dialog.dart';
import '../widgets/dialogs/resign_confirmation_dialog.dart';
import '../widgets/dialogs/draw_offer_dialog.dart';
import '../widgets/game/game.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  Square? _selectedSquare;
  List<Square> _legalMoves = [];
  bool _isFlipped = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeBoardOrientation();
    });
  }

  void _initializeBoardOrientation() {
    final gameState = ref.read(gameControllerProvider);
    if (gameState == null) return;

    final settings = ref.read(settingsControllerProvider);
    if (settings.autoFlipBoard) {
      final isBlackPlayer = gameState.blackPlayer.isLocal;
      if (isBlackPlayer) {
        setState(() => _isFlipped = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameControllerProvider);
    final settings = ref.watch(settingsControllerProvider);

    if (gameState == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Game')),
        body: const Center(child: Text('No active game')),
      );
    }

    final gameController = ref.read(gameControllerProvider.notifier);
    final isInProgress = gameState.isInProgress;
    final isBleGame = gameState.mode == GameMode.bleClient || gameState.mode == GameMode.bleHost;
    
    return PopScope(
      canPop: !isInProgress,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && isInProgress) {
          final shouldExit = await showExitGameDialog(context, isBleGame: isBleGame);
          if (shouldExit && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_getTitle(gameState.mode)),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _handleBack(isInProgress, isBleGame),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (gameState.isEnded)
                GameStatusWidget(status: gameState.status, currentTurn: gameState.currentTurn, result: gameState.result, asBanner: true),
              if (gameState.isCheck && !gameState.isEnded)
                GameStatusWidget(status: gameState.status, currentTurn: gameState.currentTurn, asBanner: true),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: PlayerInfoWidget(
                  player: _isFlipped ? gameState.whitePlayer : gameState.blackPlayer,
                  isActive: _isFlipped ? gameState.isWhiteTurn : gameState.isBlackTurn,
                  isInCheck: gameState.isCheck && ((_isFlipped && gameState.isWhiteTurn) || (!_isFlipped && gameState.isBlackTurn)),
                  capturedPieces: _getCapturedPieces(gameState.moves, _isFlipped ? PieceColor.white : PieceColor.black),
                  materialAdvantage: _getMaterialAdvantage(gameState.moves, _isFlipped ? PieceColor.white : PieceColor.black),
                  isTopPlayer: true,
                ),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: BoardWidget(
                      pieces: _getPiecesMap(gameController),
                      selectedSquare: _selectedSquare,
                      legalMoves: _legalMoves,
                      lastMove: gameState.lastMove,
                      checkSquare: _getCheckSquare(gameState, gameController),
                      isFlipped: _isFlipped,
                      showCoordinates: settings.showCoordinates,
                      interactive: isInProgress,
                      interactiveColor: _getInteractiveColor(gameState),
                      theme: BoardThemesColors.fromTheme(settings.boardTheme),
                      onSquareSelected: (square) => _handleSquareSelected(square, gameState, gameController),
                      onMove: (from, to) => _handleMove(from, to, gameState, gameController),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: PlayerInfoWidget(
                  player: _isFlipped ? gameState.blackPlayer : gameState.whitePlayer,
                  isActive: _isFlipped ? gameState.isBlackTurn : gameState.isWhiteTurn,
                  isInCheck: gameState.isCheck && ((_isFlipped && gameState.isBlackTurn) || (!_isFlipped && gameState.isWhiteTurn)),
                  capturedPieces: _getCapturedPieces(gameState.moves, _isFlipped ? PieceColor.black : PieceColor.white),
                  materialAdvantage: _getMaterialAdvantage(gameState.moves, _isFlipped ? PieceColor.black : PieceColor.white),
                  isTopPlayer: false,
                ),
              ),
              Container(
                height: 60,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: MoveListWidget(moves: gameState.moves, showMoveNumbers: true),
              ),
              GameActionBar(
                isGameInProgress: isInProgress,
                canUndo: ref.watch(canUndoProvider),
                isDrawOffered: gameState.drawOffered,
                isLocalPlayerTurn: gameController.isLocalPlayerTurn(),
                isBleGame: isBleGame,
                onResign: () => _handleResign(gameState.currentTurn),
                onOfferDraw: () => _handleOfferDraw(gameState.currentTurn),
                onAcceptDraw: () => gameController.acceptDraw(),
                onRejectDraw: () => gameController.rejectDraw(),
                onUndo: () => gameController.undoMove(),
                onFlipBoard: () => setState(() => _isFlipped = !_isFlipped),
                onNewGame: _handleNewGame,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getTitle(GameMode mode) {
    switch (mode) {
      case GameMode.hotseat:
        return 'Local Game';
      case GameMode.bleHost:
        return 'Bluetooth (Host)';
      case GameMode.bleClient:
        return 'Bluetooth';
    }
  }

  Map<int, Piece> _getPiecesMap(dynamic gameController) {
    final allPieces = gameController.getAllPieces() as Map<Square, Piece>;
    return Map.fromEntries(
      allPieces.entries.map((e) => MapEntry(e.key.index, e.value))
    );
  }

  Square? _getCheckSquare(dynamic gameState, dynamic gameController) {
    if (!gameState.isCheck) return null;
    return gameController.getKingSquare(gameState.currentTurn);
  }

  PieceColor? _getInteractiveColor(dynamic gameState) {
    if (gameState.mode == GameMode.hotseat) return null;
    if (gameState.whitePlayer.isLocal) return PieceColor.white;
    if (gameState.blackPlayer.isLocal) return PieceColor.black;
    return null;
  }

  List<Piece> _getCapturedPieces(List<dynamic> moves, PieceColor capturedByColor) {
    final captured = <Piece>[];
    for (final move in moves) {
      if (move.capturedPiece != null && move.capturedPiece.color != capturedByColor) {
        captured.add(move.capturedPiece as Piece);
      }
    }
    return captured;
  }

  int _getMaterialAdvantage(List<dynamic> moves, PieceColor color) {
    int balance = 0;
    for (final move in moves) {
      if (move.capturedPiece != null) {
        final value = _pieceValue(move.capturedPiece.type);
        if (move.capturedPiece.color != color) {
          balance += value;
        } else {
          balance -= value;
        }
      }
    }
    return balance > 0 ? balance : 0;
  }

  int _pieceValue(PieceType type) {
    switch (type) {
      case PieceType.queen:
        return 9;
      case PieceType.rook:
        return 5;
      case PieceType.bishop:
      case PieceType.knight:
        return 3;
      case PieceType.pawn:
        return 1;
      case PieceType.king:
        return 0;
    }
  }

  void _handleSquareSelected(Square square, dynamic gameState, dynamic gameController) {
    final piece = gameController.getPieceAt(square);
    if (piece != null && piece.color == gameState.currentTurn) {
      setState(() {
        _selectedSquare = square;
        _legalMoves = gameController.getLegalMoves(square);
      });
      return;
    }

    if (_selectedSquare != null && _legalMoves.contains(square)) {
      _handleMove(_selectedSquare!, square, gameState, gameController);
      return;
    }

    setState(() {
      _selectedSquare = null;
      _legalMoves = [];
    });
  }

  Future<void> _handleMove(Square from, Square to, dynamic gameState, dynamic gameController) async {
    if (gameController.requiresPromotion(from, to)) {
      final piece = gameController.getPieceAt(from);
      if (piece != null) {
        final promotion = await showPromotionDialog(context, color: piece.color);
        if (promotion != null) {
          gameController.makeMove(from: from, to: to, promotion: promotion);
        }
      }
    } else {
      gameController.makeMove(from: from, to: to);
    }

    setState(() {
      _selectedSquare = null;
      _legalMoves = [];
    });
  }

  Future<void> _handleResign(PieceColor currentTurn) async {
    final confirmed = await showResignConfirmationDialog(context);
    if (confirmed) {
      ref.read(gameControllerProvider.notifier).resign(currentTurn);
    }
  }

  Future<void> _handleOfferDraw(PieceColor currentTurn) async {
    final confirmed = await showDrawOfferDialog(context);
    if (confirmed) {
      ref.read(gameControllerProvider.notifier).offerDraw(currentTurn);
    }
  }

  Future<void> _handleBack(bool isInProgress, bool isBleGame) async {
    if (isInProgress) {
      final shouldExit = await showExitGameDialog(context, isBleGame: isBleGame);
      if (shouldExit && mounted) {
        Navigator.of(context).pop();
      }
    } else {
      Navigator.of(context).pop();
    }
  }

  void _handleNewGame() {
    Navigator.of(context).pop();
  }
}
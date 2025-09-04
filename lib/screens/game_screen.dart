import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../widgets/chess_board_widget.dart';
import '../models/chess_piece.dart';

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.brown[50],
      body: SafeArea(
        child: Consumer<GameProvider>(
          builder: (context, gameProvider, child) {
            if (gameProvider.gameState == GameState.gameOver) {
              return _buildGameOverView(context, gameProvider);
            }
            
            return Column(
              children: [
                // Top player info
                _buildPlayerInfo(
                  context,
                  gameProvider,
                  isTopPlayer: true,
                ),
                
                // Chess board
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ChessBoardWidget(),
                    ),
                  ),
                ),
                
                // Bottom player info
                _buildPlayerInfo(
                  context,
                  gameProvider,
                  isTopPlayer: false,
                ),
                
                // Game controls
                _buildGameControls(context, gameProvider),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPlayerInfo(BuildContext context, GameProvider gameProvider, {required bool isTopPlayer}) {
    PieceColor? playerColor = gameProvider.playerColor;
    PieceColor? opponentColor = playerColor == PieceColor.white ? PieceColor.black : PieceColor.white;
    
    // Determine which player to show
    bool showingMyself = (isTopPlayer && playerColor == PieceColor.black) || 
                        (!isTopPlayer && playerColor == PieceColor.white);
    
    PieceColor displayColor = showingMyself ? playerColor! : opponentColor;
    String playerName = showingMyself ? 'You' : 'Opponent';
    bool isActive = gameProvider.chessBoard.currentPlayer == displayColor;
    bool isMyTurn = showingMyself && gameProvider.isMyTurn;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? Colors.green[100] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? Colors.green : Colors.grey,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          // Player color indicator
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: displayColor == PieceColor.white ? Colors.white : Colors.black,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.brown, width: 2),
            ),
            child: displayColor == PieceColor.white 
                ? const Icon(Icons.circle_outlined, color: Colors.black)
                : const Icon(Icons.circle, color: Colors.white),
          ),
          
          const SizedBox(width: 16),
          
          // Player info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  playerName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${displayColor.name.toUpperCase()} pieces',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          
          // Turn indicator
          if (isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isMyTurn ? Colors.blue : Colors.orange,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isMyTurn ? 'Your Turn' : 'Thinking...',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGameControls(BuildContext context, GameProvider gameProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Resign button
          ElevatedButton.icon(
            onPressed: gameProvider.canMakeMove 
                ? () => _showResignDialog(context, gameProvider)
                : null,
            icon: const Icon(Icons.flag, color: Colors.white),
            label: const Text('Resign'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
          
          // Draw button
          ElevatedButton.icon(
            onPressed: gameProvider.canMakeMove 
                ? () => _showDrawDialog(context, gameProvider)
                : null,
            icon: const Icon(Icons.handshake, color: Colors.white),
            label: const Text('Draw'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
          
          // Menu button
          ElevatedButton.icon(
            onPressed: () => _showMenuDialog(context, gameProvider),
            icon: const Icon(Icons.menu, color: Colors.white),
            label: const Text('Menu'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.brown,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameOverView(BuildContext context, GameProvider gameProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getGameOverIcon(gameProvider.gameOverMessage),
                  size: 80,
                  color: _getGameOverColor(gameProvider.gameOverMessage),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Game Over',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  gameProvider.gameOverMessage ?? 'Game ended',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () => gameProvider.returnToMenu(),
                      child: const Text('New Game'),
                    ),
                    ElevatedButton(
                      onPressed: () => _returnToMenu(context, gameProvider),
                      child: const Text('Main Menu'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getGameOverIcon(String? message) {
    if (message == null) return Icons.sports_esports;
    if (message.contains('win') || message.contains('Win')) {
      return Icons.emoji_events;
    } else if (message.contains('lose') || message.contains('Lose')) {
      return Icons.sentiment_dissatisfied;
    } else if (message.contains('draw') || message.contains('Draw') || message.contains('Stalemate')) {
      return Icons.handshake;
    }
    return Icons.info;
  }

  Color _getGameOverColor(String? message) {
    if (message == null) return Colors.blue;
    if (message.contains('win') || message.contains('Win')) {
      return Colors.green;
    } else if (message.contains('lose') || message.contains('Lose')) {
      return Colors.red;
    } else if (message.contains('draw') || message.contains('Draw') || message.contains('Stalemate')) {
      return Colors.orange;
    }
    return Colors.blue;
  }

  void _showResignDialog(BuildContext context, GameProvider gameProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resign Game'),
        content: const Text('Are you sure you want to resign? This will end the game.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              gameProvider.resign();
            },
            child: const Text('Resign'),
          ),
        ],
      ),
    );
  }

  void _showDrawDialog(BuildContext context, GameProvider gameProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Offer Draw'),
        content: const Text('Do you want to offer a draw to your opponent?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              gameProvider.offerDraw();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Draw offer sent to opponent'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Offer Draw'),
          ),
        ],
      ),
    );
  }

  void _showMenuDialog(BuildContext context, GameProvider gameProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Game Menu'),
        content: const Text('What would you like to do?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue Playing'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _returnToMenu(context, gameProvider);
            },
            child: const Text('Return to Menu'),
          ),
        ],
      ),
    );
  }

  void _returnToMenu(BuildContext context, GameProvider gameProvider) {
    gameProvider.returnToMenu();
    Navigator.popUntil(context, (route) => route.isFirst);
  }
}

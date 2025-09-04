import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import 'bluetooth_connection_screen.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.brown[50],
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.brown[100]!,
              Colors.brown[50]!,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Title
              const Icon(
                Icons.sports_esports,
                size: 80,
                color: Colors.brown,
              ),
              const SizedBox(height: 20),
              const Text(
                'BT Chess',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.brown,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Bluetooth Chess Game',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.brown,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 60),
              
              // Menu buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildMenuButton(
                      context,
                      'Host Game',
                      'Create a new game and wait for opponent',
                      Icons.wifi_tethering,
                      Colors.blue,
                      () => _startAsHost(context),
                    ),
                    const SizedBox(height: 20),
                    _buildMenuButton(
                      context,
                      'Join Game',
                      'Connect to an existing game',
                      Icons.bluetooth_searching,
                      Colors.green,
                      () => _startAsGuest(context),
                    ),
                    const SizedBox(height: 40),
                    _buildMenuButton(
                      context,
                      'How to Play',
                      'Learn the game rules and controls',
                      Icons.help_outline,
                      Colors.orange,
                      () => _showHowToPlay(context),
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // Footer
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Connect two devices via Bluetooth to play',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.brown,
                    fontWeight: FontWeight.w300,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 30,
                  color: color,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.brown,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.brown[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.brown[400],
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startAsHost(BuildContext context) {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    gameProvider.hostGame();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BluetoothConnectionScreen(isHost: true),
      ),
    );
  }

  void _startAsGuest(BuildContext context) {
    // Navigate to connection screen for guest
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BluetoothConnectionScreen(isHost: false),
      ),
    );
  }

  void _showHowToPlay(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How to Play'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Bluetooth Setup:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('1. Enable Bluetooth on both devices'),
              Text('2. One player hosts, the other joins'),
              Text('3. Grant all requested permissions'),
              SizedBox(height: 16),
              Text(
                'Game Rules:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('• Standard chess rules apply'),
              Text('• Tap a piece to select it'),
              Text('• Tap a highlighted square to move'),
              Text('• White moves first (host player)'),
              Text('• Win by checkmate or opponent resignation'),
              SizedBox(height: 16),
              Text(
                'Controls:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('• Green dots: Valid moves'),
              Text('• Red border: Capture moves'),
              Text('• Blue highlight: Selected piece'),
              Text('• Red background: King in check'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }
}

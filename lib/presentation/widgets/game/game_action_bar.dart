import 'package:flutter/material.dart';

class GameActionBar extends StatelessWidget {
  final bool isGameInProgress;
  final bool canUndo;
  final bool isDrawOffered;
  final bool isLocalPlayerTurn;
  final bool isBleGame;
  final VoidCallback? onResign;
  final VoidCallback? onOfferDraw;
  final VoidCallback? onAcceptDraw;
  final VoidCallback? onRejectDraw;
  final VoidCallback? onUndo;
  final VoidCallback? onFlipBoard;
  final VoidCallback? onNewGame;

  const GameActionBar({
    super.key,
    this.isGameInProgress = true,
    this.canUndo = false,
    this.isDrawOffered = false,
    this.isLocalPlayerTurn = true,
    this.isBleGame = false,
    this.onResign,
    this.onOfferDraw,
    this.onAcceptDraw,
    this.onRejectDraw,
    this.onUndo,
    this.onFlipBoard,
    this.onNewGame,
  });

  @override
  Widget build(BuildContext context) {
    if (isDrawOffered && isLocalPlayerTurn) {
        return _buildDrawOfferBar(context);
    }

    return _buildActionBar(context);
  }

  Widget _buildDrawOfferBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: colorScheme.secondaryContainer,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Draw offered',
            style: TextStyle(
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 16),
          FilledButton.tonal(onPressed: onAcceptDraw, child: const Text('Accept')),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: onRejectDraw, child: const Text('Decline')),
        ],
      ),
    );
  }

  Widget _buildActionBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ActionButton(
            icon: Icons.swap_vert,
            label: 'Flip',
            onPressed: onFlipBoard,
          ),
          if (canUndo)
            _ActionButton(
              icon: Icons.undo,
              label: 'Undo',
              onPressed: onUndo,
            ),
          if (isGameInProgress && isLocalPlayerTurn && !isBleGame)
            _ActionButton(
              icon: Icons.handshake_outlined,
              label: 'Draw',
              onPressed: onOfferDraw,
            ),
          if (isGameInProgress)
            _ActionButton(
              icon: Icons.flag_outlined,
              label: 'Resign',
              onPressed: onResign,
              isDestructive: true,
            ),
          if (!isGameInProgress)
            _ActionButton(
              icon: Icons.add,
              label: 'New Game',
              onPressed: onNewGame,
            ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isDestructive;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.onPressed,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isDestructive ? colorScheme.error : colorScheme.onSurface;

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';

class GameActionBar extends StatelessWidget {

  const GameActionBar({
    super.key,
    this.isGameInProgress = true,
    this.canUndo = false,
    this.isDrawOffered = false,
    this.isDrawOfferedByLocalPlayer = false,
    this.isLocalPlayerTurn = true,
    this.isBleGame = false,
    this.isWaitingForAck = false,
    this.onResign,
    this.onOfferDraw,
    this.onAcceptDraw,
    this.onRejectDraw,
    this.onUndo,
    this.onFlipBoard,
    this.onNewGame,
  });
  final bool isGameInProgress;
  final bool canUndo;
  final bool isDrawOffered;
  final bool isDrawOfferedByLocalPlayer;
  final bool isLocalPlayerTurn;
  final bool isBleGame;
  final bool isWaitingForAck;
  final VoidCallback? onResign;
  final VoidCallback? onOfferDraw;
  final VoidCallback? onAcceptDraw;
  final VoidCallback? onRejectDraw;
  final VoidCallback? onUndo;
  final VoidCallback? onFlipBoard;
  final VoidCallback? onNewGame;

  @override
  Widget build(BuildContext context) {
    if (isDrawOffered && isDrawOfferedByLocalPlayer) {
      return _buildDrawSentBar(context);
    }
    if (isDrawOffered && !isDrawOfferedByLocalPlayer) {
      return _buildDrawOfferBar(context);
    }

    return _buildActionBar(context);
  }

  Widget _buildDrawSentBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: colorScheme.tertiaryContainer,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colorScheme.onTertiaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Draw offer sent — waiting for response',
            style: TextStyle(
              color: colorScheme.onTertiaryContainer,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
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
    final buttons = <Widget>[];

    // Flip is always shown
    buttons.add(_ActionButton(
      icon: Icons.swap_vert,
      label: 'Flip',
      onPressed: onFlipBoard,
    ));

    if (isGameInProgress) {
      // Undo only in local (hotseat) mode
      if (canUndo) {
        buttons.add(_ActionButton(
          icon: Icons.undo,
          label: 'Undo',
          onPressed: onUndo,
        ));
      }

      // Draw only when it's the local player's turn
      if (isLocalPlayerTurn) {
        buttons.add(_ActionButton(
          icon: Icons.handshake_outlined,
          label: 'Draw',
          onPressed: isWaitingForAck ? null : onOfferDraw,
        ));
      }

      // Resign always available during game
      buttons.add(_ActionButton(
        icon: Icons.flag_outlined,
        label: 'Resign',
        onPressed: isWaitingForAck ? null : onResign,
        isDestructive: true,
      ));
    } else {
      // Game ended — show New Game
      buttons.add(_ActionButton(
        icon: Icons.add,
        label: 'New Game',
        onPressed: onNewGame,
      ));
    }

    // Local mode (4 buttons): spread evenly across full width
    // BLE / fewer buttons: center with equal gaps between them
    final useSpaceEvenly = canUndo && buttons.length >= 4;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: useSpaceEvenly
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: buttons,
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _intersperse(buttons, const SizedBox(width: 32)),
            ),
    );
  }

  // Inserts [separator] between each element of [items].
  List<Widget> _intersperse(List<Widget> items, Widget separator) {
    if (items.length <= 1) return items;
    return [
      for (int i = 0; i < items.length; i++) ...[
        if (i > 0) separator,
        items[i],
      ],
    ];
  }
}

class _ActionButton extends StatelessWidget {

  const _ActionButton({
    required this.icon,
    required this.label,
    this.onPressed,
    this.isDestructive = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isDestructive;

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
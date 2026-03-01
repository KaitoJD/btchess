import 'package:flutter/material.dart';

// Dialog shown when the BLE connection is lost during a game or lobby session.
//
// Offers the user the option to attempt reconnection or to exit.
class DisconnectDialog extends StatelessWidget {
  const DisconnectDialog({
    super.key,
    this.isReconnecting = false,
    this.errorMessage,
  });

  // Whether a reconnection attempt is currently in progress.
  final bool isReconnecting;

  // Optional error message providing more context about the disconnect.
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      icon: Icon(
        isReconnecting ? Icons.sync : Icons.bluetooth_disabled,
        size: 48,
        color: isReconnecting ? colorScheme.primary : colorScheme.error,
      ),
      title: Text(isReconnecting ? 'Reconnecting...' : 'Connection Lost'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isReconnecting
                ? 'Attempting to reconnect to your opponent. Please wait...'
                : 'The Bluetooth connection to your opponent was lost.',
            textAlign: TextAlign.center,
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (isReconnecting) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Exit'),
        ),
        if (!isReconnecting)
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Reconnect'),
          ),
      ],
    );
  }
}

// Shows the disconnect dialog and returns the user's choice.
//
// Returns `true` if the user chose to reconnect, `false` if they chose to exit,
// and `null` if the dialog was dismissed (treated as exit).
Future<bool?> showDisconnectDialog(
  BuildContext context, {
  bool isReconnecting = false,
  String? errorMessage,
}) async {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => DisconnectDialog(
      isReconnecting: isReconnecting,
      errorMessage: errorMessage,
    ),
  );
}
